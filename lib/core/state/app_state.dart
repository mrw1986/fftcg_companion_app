// lib/core/state/app_state.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/enums/auth_status.dart';
import '../models/sync_status.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';

// App-wide state
class AppState {
  final bool isInitialized;
  final bool isOnline;
  final SyncStatus syncStatus;
  final String? error;

  const AppState({
    this.isInitialized = false,
    this.isOnline = false,
    this.syncStatus = SyncStatus.synced,
    this.error,
  });

  AppState copyWith({
    bool? isInitialized,
    bool? isOnline,
    SyncStatus? syncStatus,
    String? error,
  }) {
    return AppState(
      isInitialized: isInitialized ?? this.isInitialized,
      isOnline: isOnline ?? this.isOnline,
      syncStatus: syncStatus ?? this.syncStatus,
      error: error,
    );
  }
}

// Main state notifier
class AppStateNotifier extends StateNotifier<AppState> {
  final Ref _ref;

  AppStateNotifier(this._ref) : super(const AppState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    // Listen to auth state changes
    _ref.listen(authNotifierProvider, (previous, next) {
      if (next.status == AuthStatus.error) {
        state = state.copyWith(error: next.errorMessage);
      }
    });

    // Listen to connectivity changes
    _ref.listen(connectivityStatusProvider, (previous, next) {
      next.whenData((isOnline) {
        state = state.copyWith(isOnline: isOnline);
      });
    });

    // Listen to sync status from sync service
    _ref.listen(syncStatusStreamProvider, (previous, next) {
      next.whenData((status) {
        state = state.copyWith(syncStatus: status);
      });
    });

    state = state.copyWith(isInitialized: true);
  }
}

// Main app state provider
final appStateProvider =
    StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  return AppStateNotifier(ref);
});

// Convenience providers
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(appStateProvider).isOnline;
});

final appSyncStatusProvider = Provider<SyncStatus>((ref) {
  return ref.watch(appStateProvider).syncStatus;
});

final isInitializedProvider = Provider<bool>((ref) {
  return ref.watch(appStateProvider).isInitialized;
});

// Connectivity status stream provider
final connectivityStatusProvider = StreamProvider<bool>((ref) {
  final connectivityService = ref.watch(connectivityServiceProvider);
  return connectivityService.connectivityStream;
});

// Sync status stream provider
final syncStatusStreamProvider = StreamProvider<SyncStatus>((ref) async* {
  final syncService = ref.watch(syncServiceProvider);
  while (true) {
    yield await syncService.getSyncStatus();
    await Future.delayed(const Duration(seconds: 30));
  }
});
