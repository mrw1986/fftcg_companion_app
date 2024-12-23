// lib/main.dart

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'core/logging/logger_service.dart';
import 'core/providers/root_route_history_notifier.dart';
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

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Platform-specific optimizations
    if (Platform.isAndroid) {
      // Enable edge-to-edge on Android
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
      );

      // Update system UI overlay style for edge-to-edge
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          // Light icons for dark nav bar
          systemNavigationBarIconBrightness: Brightness.light,
          // Dark icons for light status bar
          statusBarIconBrightness: Brightness.dark,
        ),
      );
    }

    // Set preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Configure error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      LoggerService().severe('Flutter Error', details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      LoggerService().severe('Platform Error', error, stack);
      return true;
    };

    try {
      final logger = LoggerService();
      final sharedPrefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        ],
        observers: [
          if (kDebugMode) _ProviderLogger(),
        ],
      );

      await _initializeFirebase(logger);

      ErrorWidget.builder = (FlutterErrorDetails details) {
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
      LoggerService().severe('Initialization error', e, stackTrace);
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
    LoggerService().severe('Unhandled error', error, stack);
  });
}

Future<void> _initializeFirebase(LoggerService logger) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Configure App Check
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );

    // Manually refresh the token after activation
    if (kDebugMode) {
      await FirebaseAppCheck.instance.getToken(true);
    }

    logger.info('Firebase initialized successfully');
  } catch (e, stackTrace) {
    logger.severe('Firebase initialization failed', e, stackTrace);
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
    debugPrint('''
{
  "provider": "${provider.name ?? provider.runtimeType}",
  "previousValue": "$previousValue",
  "newValue": "$newValue"
}''');
  }
}

class FFTCGCompanionApp extends ConsumerWidget {
  const FFTCGCompanionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final themeColor = ref.watch(themeColorProvider);

    return MaterialApp(
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
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child!,
        );
      },
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

class _MainTabScreenState extends ConsumerState<MainTabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this)
      ..addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      ref
          .read(rootRouteHistoryProvider.notifier)
          .addHistory(_tabController.index);
    }
  }

  Future<void> _handleBackNavigation(bool didPop, dynamic result) async {
    if (didPop) return;

    final navigator = Navigator.of(context);

    // First check if current route can be popped
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    // Handle tab navigation using history
    final history = ref.read(rootRouteHistoryProvider);
    if (history.length > 1) {
      ref.read(rootRouteHistoryProvider.notifier).removeLastHistory();
      setState(() {
        _tabController.index = ref.read(rootRouteHistoryProvider).last;
      });
      return;
    }

    // Handle app exit (only on home tab)
    if (_tabController.index == 0) {
      final now = DateTime.now();
      if (_lastBackPress == null ||
          now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
        _lastBackPress = now;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      await SystemNavigator.pop();
      return;
    }

    // If on any other tab, go back to home tab
    setState(() {
      ref.read(rootRouteHistoryProvider.notifier).clearHistory();
      _tabController.index = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handleBackNavigation,
      child: DefaultTabController(
        length: 5,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('FFTCG Companion'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SettingsScreen(
                        handleLogout: widget.handleLogout,
                      ),
                    ),
                  );
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                  ),
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(icon: Icon(Icons.grid_view), text: 'Cards'),
                Tab(icon: Icon(Icons.collections_bookmark), text: 'Collection'),
                Tab(icon: Icon(Icons.style), text: 'Decks'),
                Tab(icon: Icon(Icons.camera_alt), text: 'Scanner'),
                Tab(icon: Icon(Icons.person), text: 'Profile'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              CardsScreen(handleLogout: widget.handleLogout),
              const CollectionScreen(),
              const DecksScreen(),
              const ScannerScreen(),
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