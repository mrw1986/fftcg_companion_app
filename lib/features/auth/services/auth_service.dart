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
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
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
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: ['email'], // Simplified to just email scope
              signInOption: SignInOption.standard,
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

      // Sign out of any existing sessions first
      await _googleSignIn.signOut();

      // Begin interactive sign in process
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        _logger.warning('Google sign in cancelled by user');
        return null;
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        throw CustomAuthException(
          code: 'null-user',
          message: 'Failed to get user details from Firebase',
        );
      }

      // Clear any existing guest session
      await _clearGuestSession();

      // Create or update user document
      return await _createOrUpdateUser(user);
    } catch (e, stackTrace) {
      _logger.severe('Error signing in with Google', e, stackTrace);

      if (e is FirebaseAuthException) {
        throw CustomAuthException(
          code: e.code,
          message: _getReadableAuthError(e.code),
        );
      } else if (e is CustomAuthException) {
        rethrow;
      } else {
        throw CustomAuthException(
          code: 'unknown',
          message: 'Failed to sign in with Google: ${e.toString()}',
        );
      }
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
        throw CustomAuthException(
          code: 'null-user',
          message: 'Failed to get user details from Firebase',
        );
      }

      await _clearGuestSession();
      return await _createOrUpdateUser(user);
    } on FirebaseAuthException catch (e, stackTrace) {
      _logger.severe('Firebase Auth Error: ${e.message}', e, stackTrace);
      throw CustomAuthException(
        code: e.code,
        message: _getReadableAuthError(e.code),
      );
    } catch (e, stackTrace) {
      _logger.severe('Error signing in with email/password', e, stackTrace);
      throw CustomAuthException(
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
      // Convert timestamps to ISO strings for JSON storage
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
      throw CustomAuthException(
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

      final userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(_timeout);

      final user = userCredential.user;
      if (user == null) {
        throw CustomAuthException(
          code: 'null-user',
          message: 'Failed to create user account',
        );
      }

      await user.updateDisplayName(displayName.trim());
      await user.sendEmailVerification();
      await _clearGuestSession();

      return await _createOrUpdateUser(user);
    } on FirebaseAuthException catch (e, stackTrace) {
      _logger.severe('Firebase Auth Error: ${e.message}', e, stackTrace);
      throw CustomAuthException(
        code: e.code,
        message: _getReadableAuthError(e.code),
      );
    } catch (e, stackTrace) {
      _logger.severe('Error registering with email/password', e, stackTrace);
      throw CustomAuthException(
        code: 'unknown',
        message: 'Registration failed: ${e.toString()}',
      );
    }
  }

  Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload(); // Refresh user info
      return user.emailVerified;
    }
    return false;
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

  Future<void> _verifyConnectivityAndAppCheck() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw CustomAuthException(
        code: 'no-connection',
        message: 'No internet connection available',
      );
    }

    if (!kDebugMode) {
      try {
        final token =
            await FirebaseAppCheck.instance.getToken(true).timeout(_timeout);
        if (token == null) {
          throw CustomAuthException(
            code: 'app-check-failed',
            message: 'Failed to verify app authenticity',
          );
        }
      } catch (e) {
        _logger.severe('App Check verification failed', e);
        throw CustomAuthException(
          code: 'app-check-failed',
          message: 'Failed to verify app authenticity',
        );
      }
    }
  }

  String _getReadableAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account exists with this email. Please create an account first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again or use Reset Password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'An account already exists with this email. Please sign in instead.';
      case 'operation-not-allowed':
        return 'This operation is not allowed';
      case 'weak-password':
        return 'Please enter a stronger password';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'timeout':
        return 'Operation timed out. Please try again';
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
