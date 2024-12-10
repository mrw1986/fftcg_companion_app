import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import '../../../core/logging/logger_service.dart';
import '../../../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LoggerService _logger = LoggerService();

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
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _logger.warning('Google sign in cancelled by user');
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw FirebaseAuthException(
          code: 'google-signin-failed',
          message: 'Failed to get Google authentication tokens',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      if (userCredential.user == null) {
        throw FirebaseAuthException(
          code: 'google-signin-failed',
          message: 'Failed to sign in with Google: No user returned',
        );
      }

      return await _createOrUpdateUser(userCredential.user!);
    } on FirebaseAuthException catch (e, stackTrace) {
      _logger.error('Firebase Auth Error signing in with Google: ${e.message}',
          e, stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      _logger.error('Error signing in with Google', e, stackTrace);
      throw FirebaseAuthException(
        code: 'google-signin-failed',
        message: 'Failed to sign in with Google: ${e.toString()}',
      );
    }
  }

  Future<UserModel?> signInWithEmailPassword(
      String email, String password) async {
    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (userCredential.user == null) {
        throw FirebaseAuthException(
          code: 'email-signin-failed',
          message: 'Failed to sign in with email: No user returned',
        );
      }

      return await _createOrUpdateUser(userCredential.user!);
    } on FirebaseAuthException catch (e, stackTrace) {
      _logger.error('Firebase Auth Error signing in with email: ${e.message}',
          e, stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      _logger.error('Error signing in with email/password', e, stackTrace);
      throw FirebaseAuthException(
        code: 'email-signin-failed',
        message: 'Failed to sign in with email: ${e.toString()}',
      );
    }
  }

  Future<UserModel?> signInAsGuest() async {
    try {
      // Check connectivity first
      final List<ConnectivityResult> connectivityResults =
          await Connectivity().checkConnectivity();
      if (connectivityResults.contains(ConnectivityResult.none) ||
          connectivityResults.isEmpty) {
        throw FirebaseAuthException(
          code: 'network-error',
          message:
              'No internet connection. Please check your connection and try again.',
        );
      }

      // Check App Check initialization
      try {
        await FirebaseAppCheck.instance.getToken(true);
      } catch (e) {
        _logger.error('App Check not properly initialized', e);
        // Continue anyway as we're using debug token
      }

      final UserCredential userCredential = await _auth.signInAnonymously();
      if (userCredential.user == null) {
        throw FirebaseAuthException(
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
      rethrow;
    } catch (e, stackTrace) {
      _logger.error('Error signing in as guest', e, stackTrace);
      throw FirebaseAuthException(
        code: 'guest-signin-failed',
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
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (userCredential.user == null) {
        throw FirebaseAuthException(
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
      rethrow;
    } catch (e, stackTrace) {
      _logger.error('Error registering with email/password', e, stackTrace);
      throw FirebaseAuthException(
        code: 'registration-failed',
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
      isEmailVerified: user.emailVerified,
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
          'isEmailVerified': user.emailVerified,
        });
      }

      return userData;
    } catch (e, stackTrace) {
      _logger.error('Error creating/updating user', e, stackTrace);
      throw FirebaseAuthException(
        code: 'user-update-failed',
        message: 'Failed to update user data: ${e.toString()}',
      );
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
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
      if (user == null) {
        _logger.info('No user to check email verification');
        return;
      }

      // Only reload and check if the user has an email
      if (user.email != null && !user.isAnonymous) {
        await user.reload();
        _logger.info('Email verification status: ${user.emailVerified}');
      }
    } catch (e, stackTrace) {
      _logger.error('Error checking email verification', e, stackTrace);
      // Don't rethrow - this is a background check that shouldn't affect the UI
    }
  }
}
