// lib/features/auth/providers/auth_notifier.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/logging/talker_service.dart';
import '../../../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../enums/auth_status.dart';
import '../services/auth_service.dart';
import 'auth_state.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final TalkerService _talker;
  final AuthService _authService;
  StreamSubscription<UserModel?>? _authStateSubscription;

  AuthNotifier({
    required AuthRepository authRepository,
    TalkerService? talker,
    AuthService? authService,
  })  : _authRepository = authRepository,
        _talker = talker ?? TalkerService(),
        _authService = authService ?? AuthService(),
        super(const AuthState()) {
    _initialize();
  }

  Future<void> signInWithGoogle() async {
    try {
      state = const AuthState(status: AuthStatus.loading);
      _talker.info('Attempting Google sign in');

      final user = await _authRepository.signInWithGoogle();
      if (user != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
        );
        _talker.info('Google sign in completed successfully');
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
        _talker.warning('Google sign in completed but no user returned');
      }
    } catch (e, stackTrace) {
      _talker.severe('Error signing in with Google', e, stackTrace);
      state = const AuthState(status: AuthStatus.unauthenticated);
      rethrow;
    }
  }

  Future<void> signInWithEmailPassword(String email, String password) async {
    try {
      state = const AuthState(status: AuthStatus.loading);
      _talker.info('Attempting email/password sign in');

      await _authRepository.signInWithEmailPassword(email, password);
      _talker.info('Email/password sign in completed successfully');
    } catch (e, stackTrace) {
      _talker.severe('Error signing in with email/password', e, stackTrace);
      state = const AuthState(status: AuthStatus.unauthenticated);
      rethrow;
    }
  }

  Future<void> signInAsGuest() async {
    try {
      state = const AuthState(status: AuthStatus.loading);
      _talker.info('Attempting guest sign in');

      final guestUser = await _authRepository.signInAsGuest();
      if (guestUser != null) {
        state = AuthState(
          status: AuthStatus.guest,
          user: guestUser,
        );
        _talker.info('Guest sign in completed successfully: ${guestUser.id}');
      } else {
        throw Exception('Failed to create guest session');
      }
    } catch (e, stackTrace) {
      _talker.severe('Error signing in as guest', e, stackTrace);
      state = const AuthState(status: AuthStatus.unauthenticated);
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      state = const AuthState(status: AuthStatus.loading);
      _talker.info('Attempting sign out');

      await _authRepository.signOut();
      state = const AuthState(status: AuthStatus.unauthenticated);
      _talker.info('Sign out completed successfully');
    } catch (e, stackTrace) {
      _talker.severe('Error signing out', e, stackTrace);
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
      _talker.info('Attempting user registration');

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
      _talker.severe('Error registering with email/password', e, stackTrace);
      state = const AuthState(status: AuthStatus.unauthenticated);
      rethrow;
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      await _authRepository.sendEmailVerification();
      _talker.info('Email verification sent');
    } catch (e, stackTrace) {
      _talker.severe('Error sending email verification', e, stackTrace);
      rethrow;
    }
  }

  Future<void> linkWithGoogle() async {
    try {
      state = const AuthState(status: AuthStatus.loading);
      final userModel = await _authRepository.linkWithGoogle();
      if (userModel != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: userModel,
        );
      } else {
        state = const AuthState(
          status: AuthStatus.error,
          errorMessage: 'Failed to link Google account',
        );
      }
    } catch (e) {
      _talker.severe('Error linking with Google', e);
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: e is FirebaseAuthException
            ? _authService.getReadableAuthError(e)
            : 'Failed to link Google account',
      );
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
    _talker.info('Disposing AuthNotifier');
    _authStateSubscription?.cancel();
    super.dispose();
  }

  void _initialize() {
    _talker.info('Initializing auth state listener');
    _authStateSubscription?.cancel();
    _authStateSubscription = _authRepository.authStateChanges.listen(
      (user) async {
        _talker.info('Auth state changed: ${user?.id}');
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
        _talker.severe('Auth state change error', error, stackTrace);
        state = const AuthState(status: AuthStatus.error);
      },
    );
  }
}
