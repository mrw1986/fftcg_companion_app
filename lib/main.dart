import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'core/logging/logger_service.dart';
import 'core/theme/app_theme.dart';
import 'features/cards/providers/card_providers.dart';
import 'firebase_options.dart';
import 'core/providers/app_providers.dart';
import 'features/auth/presentation/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final logger = LoggerService();

  try {
    // Initialize SharedPreferences
    final sharedPrefs = await SharedPreferences.getInstance();

    // Create ProviderContainer with overrides
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      ],
    );

    // Initialize Firebase and App Check
    await _initializeFirebase(logger);

    // Run the app with ProviderScope
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const FFTCGCompanionApp(),
      ),
    );
  } catch (e, stackTrace) {
    logger.error('Failed to initialize app', e, stackTrace);
    runApp(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: _buildErrorScreen(e.toString(), () {
          main();
        }),
      ),
    );
  }
}

Future<void> _initializeFirebase(LoggerService logger) async {
  try {
    // Check connectivity first
    final connectivity = Connectivity();
    final connectivityResult = await connectivity.checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      logger.warning('No network connectivity available');
    }

    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize App Check with retry mechanism
    if (!kIsWeb) {
      int retries = 3;
      while (retries > 0) {
        try {
          await FirebaseAppCheck.instance.activate(
            androidProvider: kDebugMode
                ? AndroidProvider.debug
                : AndroidProvider.playIntegrity,
            appleProvider: AppleProvider.appAttest,
          );
          break;
        } catch (e, stackTrace) {
          retries--;
          logger.error(
            'App Check initialization attempt failed. Retries left: $retries',
            e,
            stackTrace,
          );
          if (retries > 0) {
            await Future.delayed(const Duration(seconds: 2));
          } else {
            // In debug mode, continue without App Check
            if (kDebugMode) {
              logger.warning('Continuing without App Check in debug mode');
              break;
            } else {
              rethrow;
            }
          }
        }
      }
    }

    logger.info('Firebase initialized successfully');
  } catch (e, stackTrace) {
    logger.error('Firebase initialization failed', e, stackTrace);
    rethrow;
  }
}

Widget _buildErrorScreen(String error, VoidCallback onRetry) {
  return Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Initialization Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red[300],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    ),
  );
}

class FFTCGCompanionApp extends ConsumerWidget {
  const FFTCGCompanionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);

    // Show error screen if initialization failed
    if (appState.error != null) {
      return MaterialApp(
        theme: AppTheme.darkTheme,
        home: _buildErrorScreen(
          appState.error!,
          () => ref.read(appStateProvider.notifier).retryInitialization(),
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    // Show loading screen while initializing
    if (!appState.isInitialized) {
      return MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Initializing...'),
              ],
            ),
          ),
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    // Show main app
    return MaterialApp(
      title: 'FFTCG Companion',
      theme: AppTheme.darkTheme,
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Add global error boundary and offline indicator
        return Stack(
          children: [
            if (child != null) child,
            if (!appState.isOnline)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Material(
                  child: Container(
                    color: Colors.red,
                    padding: const EdgeInsets.all(4),
                    child: const Text(
                      'Offline Mode',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
