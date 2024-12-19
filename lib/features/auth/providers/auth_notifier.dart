// lib/features/auth/providers/auth_notifier.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/logging/logger_service.dart';
import '../../../models/user_model.dart';
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
        super(const AuthState()) {
    _initialize();
  }

  Future<void> signInWithGoogle() async {
    try {
      state = const AuthState(status: AuthStatus.loading);
      _logger.info('Attempting Google sign in');

      final user = await _authRepository.signInWithGoogle();
      if (user != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
        );
        _logger.info('Google sign in completed successfully');
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
        _logger.warning('Google sign in completed but no user returned');
      }
    } catch (e, stackTrace) {
      _logger.severe('Error signing in with Google', e, stackTrace);
      state = const AuthState(status: AuthStatus.unauthenticated);
      rethrow;
    }
  }

  Future<void> signInWithEmailPassword(String email, String password) async {
    try {
      state = const AuthState(status: AuthStatus.loading);
      _logger.info('Attempting email/password sign in');

      await _authRepository.signInWithEmailPassword(email, password);
      _logger.info('Email/password sign in completed successfully');
    } catch (e, stackTrace) {
      _logger.severe('Error signing in with email/password', e, stackTrace);
      state = const AuthState(status: AuthStatus.unauthenticated);
      rethrow;
    }
  }

  Future<void> signInAsGuest() async {
    try {
      state = const AuthState(status: AuthStatus.loading);
      _logger.info('Attempting guest sign in');

      final guestUser = await _authRepository.signInAsGuest();
      if (guestUser != null) {
        state = AuthState(
          status: AuthStatus.guest,
          user: guestUser,
        );
        _logger.info('Guest sign in completed successfully: ${guestUser.id}');
      } else {
        throw Exception('Failed to create guest session');
      }
    } catch (e, stackTrace) {
      _logger.severe('Error signing in as guest', e, stackTrace);
      state = const AuthState(status: AuthStatus.unauthenticated);
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      state = const AuthState(status: AuthStatus.loading);
      _logger.info('Attempting sign out');

      await _authRepository.signOut();
      state = const AuthState(status: AuthStatus.unauthenticated);
      _logger.info('Sign out completed successfully');
    } catch (e, stackTrace) {
      _logger.severe('Error signing out', e, stackTrace);
      state = const AuthState(status: AuthStatus.error);
      rethrow;
    }
  }

  Future<UserModel?> registerWithEmailPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      state = const AuthState(status: AuthStatus.loading);
      _logger.info('Attempting user registration');

      final user = await _authRepository.registerWithEmailPassword(
        email,
        password,
        displayName,
      );

      if (user == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
      return user;
    } catch (e, stackTrace) {
      _logger.severe('Error registering with email/password', e, stackTrace);
      state = const AuthState(status: AuthStatus.unauthenticated);
      rethrow;
    }
  }

  Future<void> checkEmailVerification() async {
    try {
      await _authRepository.checkEmailVerification();
    } catch (e, stackTrace) {
      _logger.severe('Error checking email verification', e, stackTrace);
      state = const AuthState(status: AuthStatus.error);
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      await _authRepository.sendEmailVerification();
      _logger.info('Email verification sent');
    } catch (e, stackTrace) {
      _logger.severe('Error sending email verification', e, stackTrace);
      state = const AuthState(status: AuthStatus.error);
    }
  }

  Future<void> linkWithGoogle() async {
    try {
      state = const AuthState(status: AuthStatus.loading);
      await _authRepository.linkWithGoogle();
    } catch (e) {
      state = const AuthState(status: AuthStatus.error);
      rethrow;
    }
  }

  Future<void> linkWithEmailPassword(String email, String password) async {
    try {
      state = const AuthState(status: AuthStatus.loading);
      await _authRepository.linkWithEmailPassword(email, password);
    } catch (e) {
      state = const AuthState(status: AuthStatus.error);
      rethrow;
    }
  }

  @override
  void dispose() {
    _logger.info('Disposing AuthNotifier');
    _authStateSubscription?.cancel();
    super.dispose();
  }

  void _initialize() {
    _logger.info('Initializing auth state listener');
    _authStateSubscription?.cancel();
    _authStateSubscription = _authRepository.authStateChanges.listen(
      (user) async {
        _logger.info('Auth state changed: ${user?.id}');
        if (user != null) {
          if (user.isGuest) {
            state = AuthState(status: AuthStatus.guest, user: user);
          } else {
            state = AuthState(status: AuthStatus.authenticated, user: user);
          }
        } else {
          state = const AuthState(status: AuthStatus.unauthenticated);
        }
      },
      onError: (error, stackTrace) {
        _logger.severe('Auth state change error', error, stackTrace);
        state = const AuthState(status: AuthStatus.error);
      },
    );
  }
}