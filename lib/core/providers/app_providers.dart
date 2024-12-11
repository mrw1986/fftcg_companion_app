import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../logging/logger_service.dart';
import '../../firebase_options.dart';
import '../error/app_error.dart';
import '../error/error_provider.dart';

final loggerProvider = Provider<LoggerService>((ref) {
  return LoggerService();
});

final initializationProvider = FutureProvider<bool>((ref) async {
  final logger = ref.watch(loggerProvider);

  try {
    logger.info('Initializing Firebase');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    logger.info('Performing initial sync');
    await ref.read(syncServiceProvider).syncPendingChanges();

    logger.info('App initialization completed successfully');
    return true;
  } catch (e, stack) {
    logger.error('App initialization failed', e, stack);
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
    logger.error('Error monitoring connectivity', e, stack);
    yield false;
  }
});

final appStateProvider =
    StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  return AppStateNotifier(ref);
});

class AppState {
  final bool isInitialized;
  final bool isOnline;
  final AppError? error; // Changed from String? to AppError?
  final bool isLoading;

  const AppState({
    this.isInitialized = false,
    this.isOnline = false,
    this.error,
    this.isLoading = false,
  });

  AppState copyWith({
    bool? isInitialized,
    bool? isOnline,
    AppError? error,
    bool? isLoading,
  }) {
    return AppState(
      isInitialized: isInitialized ?? this.isInitialized,
      isOnline: isOnline ?? this.isOnline,
      error: error, // Note: null will clear the error
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool get hasError => error != null;
  String? get errorMessage => error?.message;
}

class AppStateNotifier extends StateNotifier<AppState> {
  final Ref _ref;
  final LoggerService _logger;

  AppStateNotifier(this._ref)
      : _logger = LoggerService(),
        super(const AppState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    final errorHandler = _ref.read(errorHandlerProvider);

    try {
      final result = await errorHandler.handleError(
        () async {
          final initializationStatus =
              await _ref.read(initializationProvider.future);

          if (!initializationStatus) {
            throw InitializationError(
              message: 'Failed to initialize app',
              code: 'initialization_failed',
            );
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

          return true;
        },
        context: 'App initialization',
      );

      if (result) {
        state = state.copyWith(
          isInitialized: true,
          error: null,
        );
        _logger.info('App state initialized successfully');
      }
    } catch (e, stack) {
      final appError = e is AppError
          ? e
          : UnknownError(
              message: e.toString(),
              stackTrace: stack,
            );

      _logger.error('Error initializing app state', appError, stack);
      state = state.copyWith(
        error: appError,
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void setError(AppError error) {
    state = state.copyWith(error: error);
    _logger.error('App error: ${error.message}', error, error.stackTrace);
  }

  Future<T> handleOperation<T>({
    required Future<T> Function() operation,
    required String context,
    bool setLoadingState = true,
  }) async {
    if (setLoadingState) {
      state = state.copyWith(isLoading: true);
    }

    try {
      final result = await _ref.read(errorHandlerProvider).handleError(
            operation,
            context: context,
          );

      if (setLoadingState) {
        state = state.copyWith(isLoading: false);
      }

      return result;
    } catch (e, stack) {
      if (setLoadingState) {
        state = state.copyWith(isLoading: false);
      }

      final appError = e is AppError
          ? e
          : UnknownError(
              message: e.toString(),
              stackTrace: stack,
            );

      setError(appError);
      throw appError;
    }
  }

  Future<void> retryInitialization() async {
    state = const AppState();
    await _initialize();
  }
}

// Add this class to handle initialization errors specifically
class InitializationError extends AppError {
  InitializationError({
    required super.message,
    super.code = 'initialization_error',
    super.originalError,
    super.stackTrace,
  });
}

class UnknownError extends AppError {
  UnknownError({
    super.message = 'An unknown error occurred',
    super.code = 'unknown_error',
    super.originalError,
    super.stackTrace,
  });
}
