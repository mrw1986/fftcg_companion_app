import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/logging/logger_service.dart';
import '../enums/auth_status.dart';
import '../repositories/auth_repository.dart';
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
      (user) {
        if (user != null) {
          state = state.copyWith(
            status: user.isGuest ? AuthStatus.guest : AuthStatus.authenticated,
            user: user,
            errorMessage: null,
          );
        } else {
          state = state.copyWith(
            status: AuthStatus.unauthenticated,
            user: null,
            errorMessage: null,
          );
        }
      },
      onError: (error) {
        _logger.error('Auth state stream error', error);
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Authentication error occurred',
        );
      },
    );
  }

  Future<void> signInWithGoogle() async {
    try {
      state = state.copyWith(status: AuthStatus.loading);
      await _authRepository.signInWithGoogle();
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
      await _authRepository.signInWithEmailPassword(email, password);
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
      await _authRepository.registerWithEmailPassword(
        email,
        password,
        displayName,
      );
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
      await _authRepository.signInAsGuest();
    } catch (e, stackTrace) {
      _logger.error('Error signing in as guest', e, stackTrace);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to sign in as guest',
      );
    }
  }

  Future<void> signOut() async {
    try {
      state = state.copyWith(status: AuthStatus.loading);
      await _authRepository.signOut();
    } catch (e, stackTrace) {
      _logger.error('Error signing out', e, stackTrace);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to sign out',
      );
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

Future<void> sendEmailVerification() async {
    try {
      await _authRepository.sendEmailVerification();
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
      await _authRepository.checkEmailVerification();
    } catch (e, stackTrace) {
      _logger.error('Error checking email verification', e, stackTrace);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to check email verification',
      );
    }
  }

}
