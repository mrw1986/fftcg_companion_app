import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../enums/auth_status.dart';
import '../providers/auth_providers.dart';
import 'screens/login_screen.dart';
import '../../cards/presentation/screens/cards_screen.dart';
import '../../../core/logging/logger_service.dart';
import '../../cards/providers/card_providers.dart';

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  final _logger = LoggerService();
  Timer? _emailVerificationTimer;

  @override
  void initState() {
    super.initState();
    _logger.info('AuthWrapper initialized');
    _startEmailVerificationCheck();
  }

  void _startEmailVerificationCheck() {
    _emailVerificationTimer?.cancel();
    _emailVerificationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        final authState = ref.read(authNotifierProvider);
        final user = authState.user;

        // Only check if we have a non-guest authenticated user who needs verification
        if (authState.status == AuthStatus.authenticated &&
            user != null &&
            !user.isGuest &&
            !user.isEmailVerified &&
            user.email != null) {
          ref.read(authNotifierProvider.notifier).checkEmailVerification();
        }
      },
    );
  }

  @override
  void dispose() {
    _emailVerificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        // Start loading state
        await ref.read(authNotifierProvider.notifier).signOut();

        // Clear any cached data or state
        ref.invalidate(cardNotifierProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    _logger.info('Auth status: ${authState.status}');

    switch (authState.status) {
      case AuthStatus.authenticated:
      case AuthStatus.guest:
        // Both authenticated and guest users see the CardsScreen
        return CardsScreen(handleLogout: _handleLogout);

      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const LoginScreen();

      case AuthStatus.loading:
      case AuthStatus.initial:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
    }
  }
}
