// lib/main.dart

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'core/theme/app_theme.dart';
import 'features/cards/providers/card_providers.dart';
import 'features/cards/services/card_cache_service.dart';
import 'firebase_options.dart.bak';
import 'features/settings/providers/settings_providers.dart';
import 'services/app_check_service.dart';
import 'core/routing/app_router.dart';
import 'core/logging/talker_service.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    final talker = TalkerService();

    // Initialize cache manager
    await CardCacheManager.initialize();

    // Configure error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      talker.severe('Flutter Error', details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      talker.severe('Platform Error', error, stack);
      return true;
    };

    // Platform-specific optimizations
    if (Platform.isAndroid) {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
      );

      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
        ),
      );
    }

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    try {
      final sharedPrefs = await SharedPreferences.getInstance();
      final appCheckService = AppCheckService();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        ],
        observers: [
          talker.riverpodObserver,
          if (kDebugMode) _ProviderLogger(),
        ],
      );

      // Initialize Firebase and App Check
      await _initializeFirebase(talker, appCheckService);

      ErrorWidget.builder = (FlutterErrorDetails details) {
        talker.severe('Widget Error', details.exception, details.stack);
        return MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'An error occurred: ${details.exception}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        );
      };

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const FFTCGCompanionApp(),
        ),
      );
    } catch (e, stackTrace) {
      talker.severe('Initialization error', e, stackTrace);
      runApp(
        MaterialApp(
          home: ErrorScreen(
            error: e.toString(),
            onRetry: () => main(),
          ),
        ),
      );
    }
  }, (error, stack) {
    TalkerService().severe('Unhandled error', error, stack);
  });
}

Future<void> _initializeFirebase(
    TalkerService talker, AppCheckService appCheckService) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await appCheckService.initialize();
    talker.info('Firebase initialized successfully with App Check');
  } catch (e, stackTrace) {
    talker.severe('Firebase initialization failed', e, stackTrace);
    rethrow;
  }
}

class _ProviderLogger extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    final talker = TalkerService();
    talker.debug('''
Provider Update:
  provider: ${provider.name ?? provider.runtimeType}
  previousValue: $previousValue
  newValue: $newValue
''');
  }

  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    final talker = TalkerService();
    talker.debug('''
Provider Added:
  provider: ${provider.name ?? provider.runtimeType}
  initialValue: $value
''');
  }

  @override
  void didDisposeProvider(
    ProviderBase<Object?> provider,
    ProviderContainer container,
  ) {
    final talker = TalkerService();
    talker.debug('''
Provider Disposed:
  provider: ${provider.name ?? provider.runtimeType}
''');
  }
}

class FFTCGCompanionApp extends ConsumerWidget {
  const FFTCGCompanionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final themeColor = ref.watch(themeColorProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'FFTCG Companion',
      theme: AppTheme.lightTheme.copyWith(
        colorScheme: AppTheme.lightTheme.colorScheme.copyWith(
          primary: themeColor,
          secondary: themeColor,
        ),
      ),
      darkTheme: AppTheme.darkTheme.copyWith(
        colorScheme: AppTheme.darkTheme.colorScheme.copyWith(
          primary: themeColor,
          secondary: themeColor,
        ),
      ),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child!,
        );
      },
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const ErrorScreen({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
