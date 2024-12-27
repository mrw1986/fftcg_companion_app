// lib/core/routing/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/auth_wrapper.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/registration_screen.dart';
import '../../features/cards/presentation/screens/cards_screen.dart';
import '../../features/cards/presentation/screens/card_detail_screen.dart';
import '../../features/collection/presentation/screens/collection_screen.dart';
import '../../features/decks/presentation/screens/decks_screen.dart';
import '../../features/scanner/presentation/screens/scanner_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/enums/auth_status.dart';
import '../../features/cards/models/fftcg_card.dart';
import '../../features/settings/providers/settings_providers.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

class ScaffoldWithNavBar extends ConsumerWidget {
  final Widget child;

  const ScaffoldWithNavBar({
    super.key,
    required this.child,
  });

  Widget _getTitle(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    switch (location) {
      case '/':
        return const Text('Cards');
      case '/collection':
        return const Text('Collection');
      case '/decks':
        return const Text('Decks');
      case '/scanner':
        return const Text('Scanner');
      case '/profile':
        return const Text('Profile');
      case '/settings':
        return const Text('Settings');
      default:
        return const Text('FFTCG Companion');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final themeColor = ref.watch(themeColorProvider);
    final isSettingsScreen = location == '/settings';

    final hideSettings = [
      '/settings/logs',
      '/auth/link',
    ].any((path) => location.startsWith(path));

    return Scaffold(
      appBar: AppBar(
        title: _getTitle(context),
        actions: [
          if (!hideSettings && !isSettingsScreen)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => context.push('/settings'),
            ),
          if (isSettingsScreen)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => context.pop(),
            ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Color.alphaBlend(
                themeColor.withAlpha(26), Theme.of(context).colorScheme.surface)
            : Theme.of(context).colorScheme.surface,
        indicatorColor: themeColor.withAlpha(128),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view),
            label: 'Cards',
          ),
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark),
            label: 'Collection',
          ),
          NavigationDestination(
            icon: Icon(Icons.style),
            label: 'Decks',
          ),
          NavigationDestination(
            icon: Icon(Icons.camera_alt),
            label: 'Scanner',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (index) => _onItemTapped(index, context),
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final router = GoRouter.of(context);

    if (location == '/settings') {
      // Get the previous route
      final matches = router.routerDelegate.currentConfiguration.matches;
      if (matches.length > 1) {
        final previousLocation = matches[matches.length - 2].matchedLocation;
        return _getIndexForLocation(previousLocation);
      }
    }

    return _getIndexForLocation(location);
  }

  static int _getIndexForLocation(String location) {
    if (location == '/') return 0;
    if (location.startsWith('/collection')) return 1;
    if (location.startsWith('/decks')) return 2;
    if (location.startsWith('/scanner')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    // If we're in settings, pop it first
    if (location == '/settings') {
      context.pop();
    }

    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/collection');
        break;
      case 2:
        context.go('/decks');
        break;
      case 3:
        context.go('/scanner');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.status == AuthStatus.authenticated ||
          authState.status == AuthStatus.guest;
      final isAuthRoute = state.matchedLocation.startsWith('/auth/');

      if (!isAuthenticated && !isAuthRoute) {
        return '/auth/login';
      }

      if (isAuthenticated && isAuthRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      // Auth routes with fade transition
      GoRoute(
        path: '/auth/login',
        name: 'login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/auth/register',
        name: 'register',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const RegistrationScreen(),
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // Main app shell
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return AuthWrapper(
            child: ScaffoldWithNavBar(child: child),
          );
        },
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const CardsScreen(),
              transitionDuration: const Duration(milliseconds: 200),
              reverseTransitionDuration: const Duration(milliseconds: 200),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOut)),
                  ),
                  child: child,
                );
              },
            ),
            routes: [
              GoRoute(
                path: 'card/:cardId',
                name: 'cardDetail',
                pageBuilder: (context, state) {
                  final card = state.extra as FFTCGCard?;
                  return CustomTransitionPage(
                    key: state.pageKey,
                    child: card != null
                        ? CardDetailScreen(card: card)
                        : const Scaffold(
                            body: Center(child: Text('Card not found')),
                          ),
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration:
                        const Duration(milliseconds: 200),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: animation.drive(
                            Tween(begin: 0.95, end: 1.0)
                                .chain(CurveTween(curve: Curves.easeOutCubic)),
                          ),
                          child: child,
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/collection',
            name: 'collection',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const CollectionScreen(),
              transitionDuration: const Duration(milliseconds: 200),
              reverseTransitionDuration: const Duration(milliseconds: 200),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOut)),
                  ),
                  child: child,
                );
              },
            ),
          ),
          GoRoute(
            path: '/decks',
            name: 'decks',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const DecksScreen(),
              transitionDuration: const Duration(milliseconds: 200),
              reverseTransitionDuration: const Duration(milliseconds: 200),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOut)),
                  ),
                  child: child,
                );
              },
            ),
          ),
          GoRoute(
            path: '/scanner',
            name: 'scanner',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const ScannerScreen(),
              transitionDuration: const Duration(milliseconds: 200),
              reverseTransitionDuration: const Duration(milliseconds: 200),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOut)),
                  ),
                  child: child,
                );
              },
            ),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: ProfileScreen(
                handleLogout: () async {
                  await ref.read(authNotifierProvider.notifier).signOut();
                  if (context.mounted) {
                    context.go('/auth/login');
                  }
                },
              ),
              transitionDuration: const Duration(milliseconds: 200),
              reverseTransitionDuration: const Duration(milliseconds: 200),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOut)),
                  ),
                  child: child,
                );
              },
            ),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: SettingsScreen(
                handleLogout: () async {
                  await ref.read(authNotifierProvider.notifier).signOut();
                  if (context.mounted) {
                    context.go('/auth/login');
                  }
                },
              ),
              transitionDuration: const Duration(milliseconds: 300),
              reverseTransitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(0.0, 1.0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOut)),
                  ),
                  child: child,
                );
              },
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Error: ${state.error}'),
      ),
    ),
  );
});
