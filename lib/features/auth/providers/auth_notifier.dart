import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
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
        if (user == null) {
          state = state.copyWith(
            status: AuthStatus.unauthenticated,
            user: null,
            errorMessage: null,
          );
        } else if (user.isGuest) {
          state = state.copyWith(
            status: AuthStatus.guest,
            user: user,
            errorMessage: null,
          );
        } else {
          state = state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
            errorMessage: null,
          );
        }
        _logger.info('Auth status: ${state.status}');
      },
      onError: (error, stackTrace) {
        _logger.error('Auth state error', error, stackTrace);
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: error.toString(),
        );
      },
    );
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  Future<void> signInWithGoogle() async {
    try {
      state = state.copyWith(
        status: AuthStatus.loading,
        errorMessage: null,
      );
      _logger.info('Attempting Google sign in');

      await _authRepository.signInWithGoogle();
      _logger.info('Google sign in completed successfully');
    } catch (e, stackTrace) {
      _logger.error('Error signing in with Google', e, stackTrace);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e),
      );
      rethrow;
    }
  }

  Future<void> signInWithEmailPassword(String email, String password) async {
    try {
      state = state.copyWith(
        status: AuthStatus.loading,
        errorMessage: null,
      );
      _logger.info('Attempting email/password sign in');

      await _authRepository.signInWithEmailPassword(email, password);
      _logger.info('Email/password sign in completed successfully');
    } catch (e, stackTrace) {
      _logger.error('Error signing in with email/password', e, stackTrace);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e),
      );
      rethrow;
    }
  }

  Future<void> registerWithEmailPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      state = state.copyWith(
        status: AuthStatus.loading,
        errorMessage: null,
      );
      _logger.info('Attempting user registration');

      await _authRepository.registerWithEmailPassword(
        email,
        password,
        displayName,
      );
      _logger.info('User registration completed successfully');
    } catch (e, stackTrace) {
      _logger.error('Error registering with email/password', e, stackTrace);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e),
      );
      rethrow;
    }
  }

  Future<void> signInAsGuest() async {
    try {
      state = state.copyWith(
        status: AuthStatus.loading,
        errorMessage: null,
      );
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
        errorMessage: _getErrorMessage(e),
      );
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      state = state.copyWith(
        status: AuthStatus.loading,
        errorMessage: null,
      );
      _logger.info('Attempting sign out');

      await _authRepository.signOut();
      _logger.info('Sign out completed successfully');
    } catch (e, stackTrace) {
      _logger.error('Error signing out', e, stackTrace);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e),
      );
      rethrow;
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
        errorMessage: _getErrorMessage(e),
      );
      rethrow;
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
        errorMessage: _getErrorMessage(e),
      );
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      state = state.copyWith(
        status: AuthStatus.loading,
        errorMessage: null,
      );
      _logger.info('Sending password reset email');

      await _authRepository.sendPasswordResetEmail(email);

      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: null,
      );
      _logger.info('Password reset email sent successfully');
    } catch (e, stackTrace) {
      _logger.error('Error sending password reset email', e, stackTrace);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e),
      );
      rethrow;
    }
  }

  Future<void> retryInitialization() async {
    _logger.info('Retrying auth initialization');
    state = AuthState();
    _initialize();
  }

  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No account exists with this email address';
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
        case 'email-not-verified':
          return 'Please verify your email before signing in';
        default:
          return 'Authentication failed: ${error.message}';
      }
    }
    return 'Authentication failed: ${error.toString()}';
  }

  @override
  void dispose() {
    _logger.info('Disposing AuthNotifier');
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
