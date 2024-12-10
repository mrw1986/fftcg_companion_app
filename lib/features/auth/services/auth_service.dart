import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import '../../../core/logging/logger_service.dart';
import '../../../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;
  final LoggerService _logger;

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
    LoggerService? logger,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _logger = logger ?? LoggerService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> getCurrentUser() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e, stackTrace) {
      _logger.error('Error getting current user', e, stackTrace);
      return null;
    }
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      await _verifyConnectivityAndAppCheck();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _logger.warning('Google sign in cancelled by user');
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw CustomAuthException(
          code: 'google-signin-failed',
          message: 'Failed to get Google authentication tokens',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _retryOperation(
        () => _auth.signInWithCredential(credential),
      );

      if (userCredential.user == null) {
        throw CustomAuthException(
          code: 'google-signin-failed',
          message: 'Failed to sign in with Google: No user returned',
        );
      }

      return await _createOrUpdateUser(userCredential.user!);
    } on FirebaseAuthException catch (e, stackTrace) {
      _logger.error('Firebase Auth Error signing in with Google: ${e.message}',
          e, stackTrace);
      throw CustomAuthException(
        code: e.code,
        message: _getReadableAuthError(e.code),
      );
    } catch (e, stackTrace) {
      _logger.error('Error signing in with Google', e, stackTrace);
      throw CustomAuthException(
        code: 'unknown',
        message: 'Failed to sign in with Google: ${e.toString()}',
      );
    }
  }

  Future<UserModel?> signInWithEmailPassword(
      String email, String password) async {
    try {
      await _verifyConnectivityAndAppCheck();

      final UserCredential userCredential = await _retryOperation(
        () => _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );

      if (userCredential.user == null) {
        throw CustomAuthException(
          code: 'email-signin-failed',
          message: 'Failed to sign in with email: No user returned',
        );
      }

      return await _createOrUpdateUser(userCredential.user!);
    } on FirebaseAuthException catch (e, stackTrace) {
      _logger.error('Firebase Auth Error signing in with email: ${e.message}',
          e, stackTrace);
      throw CustomAuthException(
        code: e.code,
        message: _getReadableAuthError(e.code),
      );
    } catch (e, stackTrace) {
      _logger.error('Error signing in with email/password', e, stackTrace);
      throw CustomAuthException(
        code: 'unknown',
        message: 'Failed to sign in with email: ${e.toString()}',
      );
    }
  }

  Future<UserModel?> signInAsGuest() async {
    try {
      await _verifyConnectivityAndAppCheck();

      final UserCredential userCredential = await _retryOperation(
        () => _auth.signInAnonymously(),
      );

      if (userCredential.user == null) {
        throw CustomAuthException(
          code: 'guest-signin-failed',
          message: 'Failed to sign in as guest: No user returned',
        );
      }

      return await _createOrUpdateUser(
        userCredential.user!,
        isGuest: true,
      );
    } on FirebaseAuthException catch (e, stackTrace) {
      _logger.error('Firebase Auth Error signing in as guest: ${e.message}', e,
          stackTrace);
      throw CustomAuthException(
        code: e.code,
        message: _getReadableAuthError(e.code),
      );
    } catch (e, stackTrace) {
      _logger.error('Error signing in as guest', e, stackTrace);
      throw CustomAuthException(
        code: 'unknown',
        message: 'Failed to sign in as guest: ${e.toString()}',
      );
    }
  }

  Future<UserModel?> registerWithEmailPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      await _verifyConnectivityAndAppCheck();

      final UserCredential userCredential = await _retryOperation(
        () => _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );

      if (userCredential.user == null) {
        throw CustomAuthException(
          code: 'registration-failed',
          message: 'Failed to create account: No user returned',
        );
      }

      await userCredential.user?.updateDisplayName(displayName.trim());
      await userCredential.user?.sendEmailVerification();

      return await _createOrUpdateUser(userCredential.user!);
    } on FirebaseAuthException catch (e, stackTrace) {
      _logger.error(
          'Firebase Auth Error registering user: ${e.message}', e, stackTrace);
      throw CustomAuthException(
        code: e.code,
        message: _getReadableAuthError(e.code),
      );
    } catch (e, stackTrace) {
      _logger.error('Error registering with email/password', e, stackTrace);
      throw CustomAuthException(
        code: 'unknown',
        message: 'Failed to create account: ${e.toString()}',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e, stackTrace) {
      _logger.error('Error signing out', e, stackTrace);
      rethrow;
    }
  }

  Future<UserModel> _createOrUpdateUser(User user,
      {bool isGuest = false}) async {
    final userDoc = _firestore.collection('users').doc(user.uid);

    final UserModel userData = UserModel(
      id: user.uid,
      email: user.email,
      displayName: user.displayName,
      isGuest: isGuest,
      lastLoginAt: DateTime.now(),
    );

    try {
      final doc = await userDoc.get();
      if (!doc.exists) {
        await userDoc.set(userData.toMap());
      } else {
        await userDoc.update({
          'lastLoginAt': Timestamp.fromDate(DateTime.now()),
          'email': user.email,
          'displayName': user.displayName,
        });
      }

      return userData;
    } catch (e, stackTrace) {
      _logger.error('Error creating/updating user', e, stackTrace);
      throw CustomAuthException(
        code: 'user-update-failed',
        message: 'Failed to update user data: ${e.toString()}',
      );
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await _retryOperation(() => user.sendEmailVerification());
        _logger.info('Verification email sent to ${user.email}');
      }
    } catch (e, stackTrace) {
      _logger.error('Error sending email verification', e, stackTrace);
      rethrow;
    }
  }

  Future<void> checkEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _retryOperation(() => user.reload());
        _logger.info('Email verification status: ${user.emailVerified}');
      }
    } catch (e, stackTrace) {
      _logger.error('Error checking email verification', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _verifyConnectivityAndAppCheck() async {
    final List<ConnectivityResult> connectivityResult =
        await Connectivity().checkConnectivity();

    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw CustomAuthException(
        code: 'no-connection',
        message: 'No internet connection available',
      );
    }

    if (!kDebugMode) {
      try {
        final token = await FirebaseAppCheck.instance.getToken(true);
        if (token == null) {
          throw CustomAuthException(
            code: 'app-check-failed',
            message: 'Failed to verify app authenticity',
          );
        }
      } catch (e) {
        _logger.error('App Check verification failed', e);
        throw CustomAuthException(
          code: 'app-check-failed',
          message: 'Failed to verify app authenticity',
        );
      }
    }
  }

  Future<T> _retryOperation<T>(Future<T> Function() operation) async {
    int attempts = 0;
    while (attempts < _maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts >= _maxRetries) rethrow;
        await Future.delayed(_retryDelay);
      }
    }
    throw CustomAuthException(
      code: 'retry-failed',
      message: 'Operation failed after $_maxRetries attempts',
    );
  }

  String _getReadableAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email address';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'operation-not-allowed':
        return 'This operation is not allowed';
      case 'weak-password':
        return 'Please enter a stronger password';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'app-check-failed':
        return 'App verification failed. Please ensure you\'re using an official version';
      case 'no-connection':
        return 'No internet connection available';
      default:
        return 'Authentication failed. Please try again';
    }
  }
}

class CustomAuthException implements Exception {
  final String code;
  final String message;

  CustomAuthException({
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'AuthException: $message (Code: $code)';
}
