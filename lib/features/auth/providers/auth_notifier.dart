// lib/features/auth/providers/auth_notifier.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/logging/logger_service.dart';
import '../repositories/auth_repository.dart';
import '../enums/auth_status.dart';
import 'auth_state.dart';

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
      _logger.error('Error signing in with Google', e, stackTrace);
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

      // State will be updated by the auth state listener
      _logger.info('Email/password sign in completed successfully');
    } catch (e, stackTrace) {
      _logger.error('Error signing in with email/password', e, stackTrace);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Invalid email or password',
      );
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
      _logger.error('Error registering with email/password', e, stackTrace);
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
        _logger.info('Guest sign in completed successfully');
      } else {
        throw Exception('Failed to create guest session');
      }
    } catch (e, stackTrace) {
      _logger.error('Error signing in as guest', e, stackTrace);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to continue as guest',
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
      _logger.error('Error signing out', e, stackTrace);
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
      _logger.error('Error sending email verification', e, stackTrace);
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
    } catch (e, stackTrace) {
      _logger.error('Error checking email verification', e, stackTrace);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to check email verification',
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
}
