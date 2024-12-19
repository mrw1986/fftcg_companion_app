import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/logging/logger_service.dart';
import 'core/theme/app_theme.dart';
import 'features/cards/providers/card_providers.dart';
import 'firebase_options.dart.bak';
import 'core/providers/app_providers.dart';
import 'features/auth/presentation/auth_wrapper.dart';
import 'features/cards/presentation/screens/cards_screen.dart';
import 'features/collection/presentation/screens/collection_screen.dart';
import 'features/decks/presentation/screens/decks_screen.dart';
import 'features/scanner/presentation/screens/scanner_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  // Handle errors not caught by Flutter
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Error: $error');
    debugPrint('Stack trace: $stack');
    return true;
  };

  try {
    final logger = LoggerService();

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

    // Run the app with ProviderScope and ErrorWidget customization
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        child: Container(
          color: Colors.white,
          child: Center(
            child: Text(
              'An error occurred: ${details.exception}',
              style: const TextStyle(color: Colors.red),
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
    debugPrint('Initialization error: $e');
    debugPrint('Stack trace: $stackTrace');
    runApp(
      MaterialApp(
        home: ErrorScreen(
          error: e.toString(),
          onRetry: () => main(),
        ),
      ),
    );
  }
}

// Create a simple error screen widget
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
    return MaterialApp(
      home: Scaffold(
        body: Center(
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

Future<void> _initializeFirebase(LoggerService logger) async {
  try {
    // Initialize Firebase first
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize App Check with debug token in debug mode
    await FirebaseAppCheck.instance.activate(
      // Use debug provider in debug mode
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.appAttest,
    );

    logger.info('Firebase initialized successfully');
  } catch (e, stackTrace) {
    logger.severe('Firebase initialization failed', e, stackTrace);
    rethrow;
  }
}

class FFTCGCompanionApp extends ConsumerWidget {
  const FFTCGCompanionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);

    return MaterialApp(
      title: 'FFTCG Companion',
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const DoubleBackWrapper(child: AuthWrapper()),
        '/cards': (context) => const DoubleBackWrapper(child: CardsScreen()),
        '/collection': (context) =>
            const DoubleBackWrapper(child: CollectionScreen()),
        '/decks': (context) => const DoubleBackWrapper(child: DecksScreen()),
        '/scanner': (context) =>
            const DoubleBackWrapper(child: ScannerScreen()),
        '/profile': (context) =>
            const DoubleBackWrapper(child: ProfileScreen()),
        '/settings': (context) =>
            const DoubleBackWrapper(child: SettingsScreen()),
      },
      builder: (context, child) {
        // Handle null child
        if (child == null) {
          return const Material(
            child: Center(
              child: Text('Loading...'),
            ),
          );
        }

        // Wrap the child with error handling
        return Material(
          child: Column(
            children: [
              if (appState.isOnline == false)
                Container(
                  color: Colors.red,
                  padding: const EdgeInsets.all(4),
                  child: const Text(
                    'Offline Mode',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              Expanded(child: child),
            ],
          ),
        );
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class DoubleBackWrapper extends StatefulWidget {
  final Widget child;

  const DoubleBackWrapper({super.key, required this.child});

  @override
  State<DoubleBackWrapper> createState() => _DoubleBackWrapperState();
}

class _DoubleBackWrapperState extends State<DoubleBackWrapper> {
  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) {
          return;
        }

        final NavigatorState navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
          return;
        }

        final DateTime now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        // Allow the system to handle the back press
        SystemNavigator.pop();
        return;
      },
      child: widget.child,
    );
  }
}
