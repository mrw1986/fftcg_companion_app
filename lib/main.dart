// lib/main.dart

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

class _MainTabScreenState extends ConsumerState<MainTabScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    5,
    (index) => GlobalKey<NavigatorState>(),
  );
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this)
      ..addListener(() {
        setState(() {
          _currentIndex = _tabController.index;
        });
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Add the _navigateToSettings method here
  void _navigateToSettings() {
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SettingsScreen(
            handleLogout: widget.handleLogout,
          ),
        ),
      );
    }
  }

  Future<bool> _onWillPop() async {
    final currentNavigatorState = _navigatorKeys[_currentIndex].currentState;

    if (currentNavigatorState?.canPop() ?? false) {
      currentNavigatorState?.pop();
      return false;
    }

    if (_currentIndex != 0) {
      _tabController.animateTo(0);
      return false;
    }

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App?'),
        content: const Text('Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final settingsNotifier = ref.read(settingsNotifierProvider.notifier);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: DefaultTabController(
        length: 5,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('FFTCG Companion'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: _navigateToSettings,
              ),
              IconButton(
                icon: Icon(ref.watch(themeModeProvider) == ThemeMode.dark
                    ? Icons.light_mode
                    : Icons.dark_mode),
                onPressed: settingsNotifier.cycleThemeMode,
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
            physics: const NeverScrollableScrollPhysics(), // Disable swipe
            children: [
              _buildTabNavigator(
                  0, CardsScreen(handleLogout: widget.handleLogout)),
              _buildTabNavigator(1, const CollectionScreen()),
              _buildTabNavigator(2, const DecksScreen()),
              _buildTabNavigator(3, const ScannerScreen()),
              _buildTabNavigator(
                  4, ProfileScreen(handleLogout: widget.handleLogout)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabNavigator(int index, Widget child) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => child,
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
    );
  }
}
