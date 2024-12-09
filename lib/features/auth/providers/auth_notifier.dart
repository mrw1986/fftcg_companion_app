// lib/features/auth/providers/auth_notifier.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/logging/logger_service.dart';
import '../repositories/auth_repository.dart';
import '../enums/auth_status.dart';
import 'auth_state.dart';
import '../services/auth_service.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final LoggerService _logger;
  StreamSubscription? _authStateSubscription;

  AuthNotifier({
    required AuthRepository authRepository,
    LoggerService? logger,
  })  : _authRepository = authRepository,
        _logger = logger ?? LoggerService(),
        super(AuthState()) {
    _initialize();
  }

  void _initialize() {
    _authStateSubscription?.cancel();
    _authStateSubscription = _authRepository.authStateChanges.listen(
      (user) async {
        if (user != null && user.isGuest) {
          state = state.copyWith(status: AuthStatus.guest, user: user);
        } else if (user != null) {
          state = state.copyWith(status: AuthStatus.authenticated, user: user);
        } else {
          state =
              state.copyWith(status: AuthStatus.unauthenticated, user: null);
        }
      },
      onError: (error, stackTrace) {
        state = state.copyWith(
            status: AuthStatus.error, errorMessage: error.toString());
      },
    );
  }

  Future<void> signInWithGoogle() async {
    try {
      state = state.copyWith(status: AuthStatus.loading);
      _logger.info('Attempting Google sign in');

      await _authRepository.signInWithGoogle();

      // State will be updated by the auth state listener
      _logger.info('Google sign in completed successfully');
    } catch (e, stackTrace) {
      _logger.severe('Error signing in with Google', e, stackTrace);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to sign in with Google',
      );
    }
  }

  Future<void> signInWithEmailPassword(String email, String password) async {
    try {
      state = state.copyWith(status: AuthStatus.loading);
      _logger.info('Attempting email/password sign in');

      await _authRepository.signInWithEmailPassword(email, password);

      _logger.info('Email/password sign in completed successfully');
    } catch (e, stackTrace) {
      _logger.severe('Error signing in with email/password', e, stackTrace);

      if (e is CustomAuthException && e.code == 'email-not-verified') {
        // Pass through the verification error
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: e.message,
        );
        rethrow; // Important to rethrow this specific error
      } else {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Invalid email or password',
        );
      }
    }
  }

  Future<void> registerWithEmailPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      state = state.copyWith(status: AuthStatus.loading);
      _logger.info('Attempting user registration');

      await _authRepository.registerWithEmailPassword(
        email,
        password,
        displayName,
      );

      // State will be updated by the auth state listener
      _logger.info('User registration completed successfully');
    } catch (e, stackTrace) {
      _logger.severe('Error registering with email/password', e, stackTrace);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to create account',
      );
    }
  }

  Future<void> signInAsGuest() async {
    try {
      state = state.copyWith(status: AuthStatus.loading);
      _logger.info('Attempting guest sign in');

      final guestUser = await _authRepository.signInAsGuest();

      if (guestUser != null) {
        state = state.copyWith(
          status: AuthStatus.guest,
          user: guestUser,
          errorMessage: null,
        );
        _logger.info('Guest sign in completed successfully: ${guestUser.id}');
      } else {
        throw CustomAuthException(
          code: 'guest-session-failed',
          message: 'Failed to create guest session',
        );
      }
    } catch (e, stackTrace) {
      _logger.severe('Error signing in as guest', e, stackTrace);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e is CustomAuthException
            ? e.message
            : 'Failed to continue as guest',
      );
    }
  }

  Future<void> signOut() async {
    try {
      state = state.copyWith(status: AuthStatus.loading);
      _logger.info('Attempting sign out');

      await _authRepository.signOut();

      // State will be updated by the auth state listener
      _logger.info('Sign out completed successfully');
    } catch (e, stackTrace) {
      _logger.severe('Error signing out', e, stackTrace);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to sign out',
      );
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      _logger.info('Sending email verification');
      await _authRepository.sendEmailVerification();
      _logger.info('Email verification sent successfully');
    } catch (e, stackTrace) {
      _logger.severe('Error sending email verification', e, stackTrace);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to send verification email',
      );
    }
  }

  Future<void> checkEmailVerification() async {
    try {
      _logger.info('Checking email verification status');
      await _authRepository.checkEmailVerification();
      await _authRepository.updateEmailVerificationStatus(); // Add this line
    } catch (e, stackTrace) {
      _logger.severe('Error checking email verification', e, stackTrace);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to check email verification',
      );
    }
  }

  Future<bool> isEmailVerified() async {
    return await _authRepository.isEmailVerified();
  }

  Future<void> handleEmailVerification(String email) async {
    try {
      await _authRepository.sendEmailVerification();
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: null,
      );
    } catch (e, stackTrace) {
      _logger.severe('Failed to send verification email', e, stackTrace);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to send verification email. Please try again.',
      );
    }
  }

  Future<void> retryInitialization() async {
    _logger.info('Retrying auth initialization');
    state = AuthState();
    _initialize();
  }

    @override
  void dispose() {
    _logger.info('Disposing AuthNotifier');
    _authStateSubscription?.cancel();
    super.dispose();
  }

  void clearError() {
    state = state.copyWith(
      errorMessage: null,
      status: AuthStatus.unauthenticated,
    );
  }
}
