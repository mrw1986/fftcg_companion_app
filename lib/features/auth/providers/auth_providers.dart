import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../enums/auth_status.dart';
import '../services/auth_service.dart';
import 'auth_notifier.dart';
import 'auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    authService: ref.watch(authServiceProvider),
  );
});

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    authRepository: ref.watch(authRepositoryProvider),
    authService: ref.watch(authServiceProvider),
  );
});

final authStatusProvider = Provider<AuthStatus>((ref) {
  return ref.watch(authNotifierProvider).status;
});

final currentUserProvider = Provider((ref) {
  return ref.watch(authNotifierProvider).user;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});
