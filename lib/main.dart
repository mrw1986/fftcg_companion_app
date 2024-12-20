// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/logging/logger_service.dart';
import 'core/theme/app_theme.dart';
import 'features/cards/providers/card_providers.dart';
import 'firebase_options.dart.bak';
import 'features/auth/presentation/auth_wrapper.dart';
import 'features/cards/presentation/screens/cards_screen.dart';
import 'features/collection/presentation/screens/collection_screen.dart';
import 'features/decks/presentation/screens/decks_screen.dart';
import 'features/scanner/presentation/screens/scanner_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'features/settings/providers/settings_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Error: $error');
    debugPrint('Stack trace: $stack');
    return true;
  };

  try {
    final logger = LoggerService();
    final sharedPrefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      ],
    );

    await _initializeFirebase(logger);

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

Future<void> _initializeFirebase(LoggerService logger) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
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
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'FFTCG Companion',
      theme: AppTheme.lightTheme.copyWith(
        // Apply theme color to light theme
        colorScheme: AppTheme.lightTheme.colorScheme.copyWith(
          primary: ref.watch(themeColorProvider),
          secondary: ref.watch(themeColorProvider),
        ),
      ),
      darkTheme: AppTheme.darkTheme.copyWith(
        // Apply theme color to dark theme
        colorScheme: AppTheme.darkTheme.colorScheme.copyWith(
          primary: ref.watch(themeColorProvider),
          secondary: ref.watch(themeColorProvider),
        ),
      ),
      themeMode: themeMode,
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainTabScreen extends ConsumerStatefulWidget {
  final VoidCallback handleLogout;

  const MainTabScreen({
    super.key,
    required this.handleLogout,
  });

  @override
  ConsumerState<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends ConsumerState<MainTabScreen> {
  DateTime? _lastBackPressTime;

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      if (!mounted) return false;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return false;
    }
    return true;
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          handleLogout: widget.handleLogout,
        ),
      ),
    );
  }

  void _toggleTheme() {
    ref.read(settingsNotifierProvider.notifier).toggleTheme();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeModeProvider) == ThemeMode.dark;

    return DefaultTabController(
      length: 5,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;

          final shouldPop = await _onWillPop();
          if (shouldPop) {
            await SystemNavigator.pop();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('FFTCG Companion'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: _navigateToSettings,
              ),
              IconButton(
                icon: Icon(
                  isDarkMode ? Icons.light_mode : Icons.dark_mode,
                ),
                onPressed: _toggleTheme,
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.grid_view), text: 'Cards'),
                Tab(icon: Icon(Icons.collections_bookmark), text: 'Collection'),
                Tab(icon: Icon(Icons.style), text: 'Decks'),
                Tab(icon: Icon(Icons.camera_alt), text: 'Scanner'),
                Tab(icon: Icon(Icons.person), text: 'Profile'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              CardsScreen(handleLogout: widget.handleLogout),
              CollectionScreen(handleLogout: widget.handleLogout),
              DecksScreen(handleLogout: widget.handleLogout),
              ScannerScreen(handleLogout: widget.handleLogout),
              ProfileScreen(handleLogout: widget.handleLogout),
            ],
          ),
        ),
      ),
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
