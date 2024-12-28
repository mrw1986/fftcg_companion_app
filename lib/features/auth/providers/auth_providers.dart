// lib/features/auth/providers/auth_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../enums/auth_status.dart';
import '../services/auth_service.dart';
import '../../../models/user_model.dart';
import 'auth_notifier.dart';
import 'auth_state.dart';

// Service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthRepository(authService: authService);
});

// Main auth state notifier provider
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(
    authRepository: authRepository,
    talker: null, // Optional logger will use default
  );
});

// Convenience providers
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authNotifierProvider).user;
});

final authStatusProvider = Provider<AuthStatus>((ref) {
  return ref.watch(authNotifierProvider).status;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final status = ref.watch(authStatusProvider);
  return status == AuthStatus.authenticated || status == AuthStatus.guest;
});

// Error state provider
final authErrorProvider = Provider<String?>((ref) {
  return ref.watch(authNotifierProvider).errorMessage;
});

// Loading state provider
final isAuthLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authNotifierProvider).status == AuthStatus.loading;
});

// Guest mode provider
final isGuestModeProvider = Provider<bool>((ref) {
  return ref.watch(authNotifierProvider).status == AuthStatus.guest;
});

// Auth action providers
final signOutProvider = Provider<Future<void> Function()>((ref) {
  return () => ref.read(authNotifierProvider.notifier).signOut();
});

final sendVerificationEmailProvider = Provider<Future<void> Function()>((ref) {
  return () => ref.read(authNotifierProvider.notifier).sendEmailVerification();
});
