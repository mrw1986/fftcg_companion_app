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

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();
  final _firestore = FirebaseFirestore.instance;
  static const String _guestPrefsKey = 'guest_session';
  final _timeout = const Duration(seconds: 30);
  final _logger = LoggerService();

  // Rate limiting properties
  final _maxAttempts = 5;
  final _cooldownPeriod = const Duration(minutes: 5);
  final Map<String, List<DateTime>> _attemptHistory = {};

  // Authentication state
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> _checkRateLimit(String identifier) async {
    final now = DateTime.now();

    // Initialize or get attempts for this identifier
    _attemptHistory[identifier] = _attemptHistory[identifier] ?? [];
    final attempts = _attemptHistory[identifier]!;

    // Remove attempts older than cooldown period
    attempts
        .removeWhere((attempt) => now.difference(attempt) > _cooldownPeriod);

    // Check if we're over the limit
    if (attempts.length >= _maxAttempts) {
      final oldestAttempt = attempts.first;
      final timeUntilReset = _cooldownPeriod - now.difference(oldestAttempt);

      throw FirebaseAuthException(
        code: 'too-many-requests',
        message:
            'Too many attempts. Please try again in ${timeUntilReset.inMinutes} minutes.',
      );
    }

    // Add current attempt
    attempts.add(now);
    _attemptHistory[identifier] = attempts;
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

  Future<UserModel?> signInWithEmailPassword(
      String email, String password) async {
    try {
      await _verifyConnectivityAndAppCheck();

      final userCredential = await _auth
          .signInWithEmailAndPassword(email: email.trim(), password: password)
          .timeout(_timeout);

      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'null-user',
          message: 'Failed to get user details from Firebase',
        );
      }

      // Force refresh the user to get the latest email verification status
      await user.reload();

      // Create/update the user document regardless of email verification
      final userModel = await _createOrUpdateUser(user);

      // Only check email verification after user document is created/updated
      if (!user.emailVerified) {
        await user.sendEmailVerification();
        throw FirebaseAuthException(
          code: 'email-not-verified',
          message: 'Please verify your email address before signing in.',
        );
      }

      await _clearGuestSession();
      return userModel;
    } catch (e) {
      _logger.severe('Error signing in with email/password', e);
      rethrow;
    }
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      await _verifyConnectivityAndAppCheck();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'google-sign-in-cancelled',
          message: 'Google sign in was cancelled',
        );
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      await _clearGuestSession();
      return await _createOrUpdateUser(userCredential.user!);
    } catch (e) {
      _logger.severe('Error signing in with Google', e);
      rethrow;
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

      // Convert timestamps to ISO string format for JSON serialization
      final jsonData = {
        'id': guestUser.id,
        'displayName': guestUser.displayName,
        'isGuest': guestUser.isGuest,
        'isEmailVerified': guestUser.isEmailVerified,
        'createdAt': guestUser.createdAt.toIso8601String(),
        'lastLoginAt': guestUser.lastLoginAt.toIso8601String(),
      };

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_guestPrefsKey, jsonEncode(jsonData));

      _logger.info('Guest session created successfully with ID: $guestId');
      return guestUser;
    } catch (e) {
      _logger.severe('Error creating guest session', e);
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
    } catch (e) {
      _logger.severe('Error checking guest session', e);
      return false;
    }
  }

  Future<void> _clearGuestSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_guestPrefsKey);
    } catch (e) {
      _logger.severe('Error clearing guest session', e);
    }
  }

  Future<UserModel?> registerWithEmailPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      await _checkRateLimit(email.toLowerCase());
      await _verifyConnectivityAndAppCheck();

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
    } catch (e) {
      _logger.severe('Error signing out', e);
      rethrow;
    }
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      final doc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }

      return null;
    } catch (e) {
      _logger.severe('Error getting current user', e);
      return null;
    }
  }

  Future<UserModel> _createOrUpdateUser(User user) async {
    final userDoc = _firestore.collection('users').doc(user.uid);

    final userData = UserModel(
      id: user.uid,
      email: user.email,
      displayName: user.displayName ?? 'User ${user.uid.substring(0, 4)}',
      photoURL: user.photoURL,
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
          'photoURL': user.photoURL,
          'isEmailVerified': user.emailVerified,
        });
        _logger.info('Updated user document for ${user.uid}');
      }

      return userData;
    } catch (e) {
      _logger.severe('Error creating/updating user', e);
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
    } catch (e) {
      _logger.severe('Error sending email verification', e);
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
    } catch (e) {
      _logger.severe('Error checking email verification', e);
      rethrow;
    }
  }

  String getReadableAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'too-many-requests':
        return e.message ?? 'Too many attempts. Please try again later.';
      case 'email-already-in-use':
        return 'An account already exists with this email. Please sign in or use a different email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please contact support.';
      case 'weak-password':
        return 'Please choose a stronger password (at least 6 characters).';
      case 'wrong-password':
        return 'Incorrect password. Please try again or reset your password.';
      case 'user-not-found':
        return 'No account found with this email. Please check the email or create an account.';
      case 'invalid-credential':
        return 'Invalid login credentials. Please check your email and password.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'email-not-verified':
        return 'Please verify your email address. A verification email has been sent.';
      case 'app-check-failed':
        return 'App verification failed. Please try again or reinstall the app.';
      case 'no-connection':
        return 'No internet connection. Please check your connection and try again.';
      case 'google-sign-in-cancelled':
        return 'Google sign in was cancelled. Please try again.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }

Future<void> linkWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'google-sign-in-cancelled',
          message: 'Google sign in was cancelled',
        );
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.currentUser?.linkWithCredential(credential);
    } catch (e) {
      _logger.severe('Error linking with Google', e);
      rethrow;
    }
  }

  Future<void> linkWithEmailPassword(String email, String password) async {
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await _auth.currentUser?.linkWithCredential(credential);
    } catch (e) {
      _logger.severe('Error linking with email/password', e);
      rethrow;
    }
  }

}
