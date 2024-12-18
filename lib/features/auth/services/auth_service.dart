// lib/features/auth/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import '../../../core/logging/logger_service.dart';
import '../../../models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import '../../../firebase_options.dart.bak';

class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;  // Remove initialization here
  final FirebaseFirestore _firestore;
  final LoggerService _logger;

  static const String _guestPrefsKey = 'guest_session';
  static const Duration _timeout = Duration(seconds: 30);

  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
    LoggerService? logger,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(
          scopes: ['email'],
          signInOption: SignInOption.standard,
          clientId: DefaultFirebaseOptions.currentPlatform.androidClientId,
        ),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _logger = logger ?? LoggerService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserModel?> getCurrentUser() async {
    try {
      // Check for guest session first
      final prefs = await SharedPreferences.getInstance();
      final guestData = prefs.getString(_guestPrefsKey);
      if (guestData != null) {
        return UserModel.fromJson(guestData);
      }

      // Check for authenticated user
      final User? user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e, stackTrace) {
      _logger.severe('Error getting current user', e, stackTrace);
      return null;
    }
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      await _verifyConnectivityAndAppCheck();

      // Sign out of any existing Google sessions
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _logger.warning('Google sign in cancelled by user');
        return null;
      }

      try {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);
        if (userCredential.user == null) throw Exception('Failed to get user');

        await _clearGuestSession();
        return await _createOrUpdateUser(userCredential.user!);
      } catch (e) {
        _logger.severe('Error during Google authentication', e);
        await _googleSignIn.signOut(); // Clean up on error
        rethrow;
      }
    } catch (e) {
      _logger.severe('Error signing in with Google', e);
      rethrow;
    }
  }

  Future<UserModel?> signInWithEmailPassword(
      String email, String password) async {
    try {
      await _verifyConnectivityAndAppCheck();

      final userCredential = await _auth
          .signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(_timeout);

      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'null-user',
          message: 'Failed to get user details from Firebase',
        );
      }

      await _clearGuestSession();
      return await _createOrUpdateUser(user);
    } on FirebaseAuthException catch (e) {
      _logger.severe('Firebase Auth Error: ${e.message}', e);
      rethrow;
    } catch (e) {
      _logger.severe('Error signing in with email/password', e);
      throw FirebaseAuthException(
        code: 'unknown',
        message: 'Authentication failed: ${e.toString()}',
      );
    }
  }

  Future<UserModel?> signInAsGuest() async {
    try {
      _logger.info('Creating guest session');

      final timestamp = DateTime.now();
      final guestId = 'guest_${timestamp.millisecondsSinceEpoch}';

      final guestUser = UserModel(
        id: guestId,
        displayName: 'Guest User',
        isGuest: true,
        isEmailVerified: false,
        createdAt: timestamp,
        lastLoginAt: timestamp,
      );

      final prefs = await SharedPreferences.getInstance();
      final guestData = {
        ...guestUser.toMap(),
        'createdAt': guestUser.createdAt.toIso8601String(),
        'lastLoginAt': guestUser.lastLoginAt.toIso8601String(),
      };
      await prefs.setString(_guestPrefsKey, jsonEncode(guestData));

      _logger.info('Guest session created successfully with ID: $guestId');
      return guestUser;
    } catch (e, stackTrace) {
      _logger.severe('Error creating guest session', e, stackTrace);
      throw FirebaseAuthException(
        code: 'guest-session-failed',
        message: 'Failed to create guest session: ${e.toString()}',
      );
    }
  }

  Future<bool> isGuestSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_guestPrefsKey);
    } catch (e, stackTrace) {
      _logger.severe('Error checking guest session', e, stackTrace);
      return false;
    }
  }

  Future<void> _clearGuestSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_guestPrefsKey);
    } catch (e, stackTrace) {
      _logger.severe('Error clearing guest session', e, stackTrace);
    }
  }

  Future<UserModel?> registerWithEmailPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      await _verifyConnectivityAndAppCheck();

      try {
        final userCredential = await _auth
            .createUserWithEmailAndPassword(
              email: email.trim(),
              password: password,
            )
            .timeout(_timeout);

        final user = userCredential.user;
        if (user == null) {
          throw FirebaseAuthException(
            code: 'null-user',
            message: 'Failed to create user account',
          );
        }

        await user.updateDisplayName(displayName.trim());
        await user.sendEmailVerification();
        await _clearGuestSession();

        return await _createOrUpdateUser(user);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          _logger.warning('Email already in use: $email');
          return null;
        }
        rethrow;
      }
    } catch (e) {
      _logger.severe('Error registering with email/password', e);
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      if (await isGuestSession()) {
        await _clearGuestSession();
        _logger.info('Guest session cleared');
        return;
      }

      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      _logger.info('User signed out successfully');
    } catch (e, stackTrace) {
      _logger.severe('Error signing out', e, stackTrace);
      rethrow;
    }
  }

  Future<UserModel> _createOrUpdateUser(User user) async {
    final userDoc = _firestore.collection('users').doc(user.uid);

    final userData = UserModel(
      id: user.uid,
      email: user.email,
      displayName: user.displayName ?? 'User ${user.uid.substring(0, 4)}',
      isGuest: false,
      isEmailVerified: user.emailVerified,
      lastLoginAt: DateTime.now(),
      createdAt: DateTime.now(),
    );

    try {
      final doc = await userDoc.get();
      if (!doc.exists) {
        await userDoc.set(userData.toMap());
        _logger.info('Created new user document for ${user.uid}');
      } else {
        await userDoc.update({
          'lastLoginAt': Timestamp.fromDate(DateTime.now()),
          'email': user.email,
          'displayName': user.displayName,
          'isEmailVerified': user.emailVerified,
        });
        _logger.info('Updated user document for ${user.uid}');
      }

      return userData;
    } catch (e, stackTrace) {
      _logger.severe('Error creating/updating user', e, stackTrace);
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
        await user.sendEmailVerification().timeout(_timeout);
        _logger.info('Verification email sent to ${user.email}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Error sending email verification', e, stackTrace);
      rethrow;
    }
  }

  Future<void> checkEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.reload().timeout(_timeout);
        _logger.info('Email verification status: ${user.emailVerified}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Error checking email verification', e, stackTrace);
      rethrow;
    }
  }

  Future<void> linkWithGoogle() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'no-user',
          message: 'No user is currently signed in',
        );
      }

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _logger.info('Google sign in cancelled');
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      try {
        await user.linkWithCredential(credential);
        _logger.info('Successfully linked Google account');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          throw FirebaseAuthException(
            code: 'account-exists',
            message: 'This Google account is already linked to another user',
          );
        }
        rethrow;
      }
    } catch (e, stackTrace) {
      _logger.severe('Error linking Google account', e, stackTrace);
      rethrow;
    }
  }

  Future<void> linkWithEmailPassword(String email, String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'no-user',
          message: 'No user is currently signed in',
        );
      }

      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      try {
        await user.linkWithCredential(credential);
        _logger.info('Successfully linked email/password account');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          throw FirebaseAuthException(
            code: 'account-exists',
            message: 'This email is already in use by another account',
          );
        }
        rethrow;
      }
    } catch (e, stackTrace) {
      _logger.severe('Error linking email/password account', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _verifyConnectivityAndAppCheck() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw FirebaseAuthException(
        code: 'no-connection',
        message: 'No internet connection available',
      );
    }

    if (!kDebugMode) {
      try {
        final token =
            await FirebaseAppCheck.instance.getToken(true).timeout(_timeout);
        if (token == null) {
          throw FirebaseAuthException(
            code: 'app-check-failed',
            message: 'Failed to verify app authenticity',
          );
        }
      } catch (e) {
        _logger.severe('App Check verification failed', e);
        throw FirebaseAuthException(
          code: 'app-check-failed',
          message: 'Failed to verify app authenticity',
        );
      }
    }
  }

String getReadableAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found with this email. Please check your email or create an account.';
      case 'wrong-password':
        return 'Incorrect password. Please try again or use "Forgot Password?".';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'email-already-in-use':
        return 'An account already exists with this email. Please sign in or use a different email.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please contact support.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }

}
