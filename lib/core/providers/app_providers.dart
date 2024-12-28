import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logging/talker_service.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../../firebase_options.dart.bak';

final loggerProvider = Provider<TalkerService>((ref) {
  return TalkerService();
});

final initializationProvider = FutureProvider<bool>((ref) async {
  final talker = ref.watch(loggerProvider);

  try {
    talker.info('Initializing Firebase');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    talker.info('Performing initial sync');
    await ref.read(syncServiceProvider).syncPendingChanges();

    talker.info('App initialization completed successfully');
    return true;
  } catch (e, stack) {
    talker.severe('App initialization failed', e, stack);
    return false;
  }
});

final connectivityStatusProvider = StreamProvider<bool>((ref) async* {
  final logger = ref.watch(loggerProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  
  try {
    await for (final status in connectivityService.connectivityStream) {
      logger.info('Connectivity status changed: $status');
      yield status;
    }
  } catch (e, stack) {
    logger.severe('Error monitoring connectivity', e, stack);
    yield false;
  }
});

final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  return AppStateNotifier(ref);
});

class AppState {
  final bool isInitialized;
  final bool? _isOnline; // Make the field private
  final String? error;

  const AppState({
    this.isInitialized = false,
    bool? isOnline, // Change parameter name
    this.error,
  }) : _isOnline = isOnline; // Initialize private field

  // Add a public getter
  bool? get isOnline => _isOnline;

  AppState copyWith({
    bool? isInitialized,
    bool? isOnline,
    String? error,
  }) {
    return AppState(
      isInitialized: isInitialized ?? this.isInitialized,
      isOnline: isOnline ?? _isOnline, // Use private field
      error: error ?? this.error,
    );
  }
}

class AppStateNotifier extends StateNotifier<AppState> {
  final Ref _ref;
  final TalkerService _logger;

  AppStateNotifier(this._ref)
      : _logger = TalkerService(),
        super(const AppState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final initializationStatus = await _ref.read(initializationProvider.future);
      
      if (!initializationStatus) {
        state = state.copyWith(
          error: 'Failed to initialize app',
        );
        return;
      }

      // Start listening to connectivity
      _ref.listen(connectivityStatusProvider, (previous, next) {
        next.whenData((isOnline) {
          state = state.copyWith(isOnline: isOnline);
          if (isOnline) {
            _ref.read(syncServiceProvider).syncPendingChanges();
          }
        });
      });

      state = state.copyWith(
        isInitialized: true,
        error: null,
      );

      _logger.info('App state initialized successfully');
    } catch (e, stack) {
      _logger.severe('Error initializing app state', e, stack);
      state = state.copyWith(
        error: 'Failed to initialize app: ${e.toString()}',
      );
    }
  }

  Future<void> retryInitialization() async {
    state = const AppState();
    await _initialize();
  }
}