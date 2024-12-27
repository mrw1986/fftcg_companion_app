// lib/features/auth/presentation/auth_wrapper.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../enums/auth_status.dart';
import '../providers/auth_providers.dart';
import '../presentation/widgets/email_verification_dialog.dart';
import '../../../core/logging/logger_service.dart';
import 'package:go_router/go_router.dart';

class AuthWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const AuthWrapper({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  Timer? _emailVerificationTimer;
  bool _showingDialog = false;
  final _logger = LoggerService();

  @override
  void initState() {
    super.initState();
    _startEmailVerificationCheck();
  }

  @override
  void dispose() {
    _emailVerificationTimer?.cancel();
    super.dispose();
  }

  void _startEmailVerificationCheck() {
    _emailVerificationTimer?.cancel();
    _emailVerificationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkEmailVerification(),
    );
  }

  void _checkEmailVerification() {
    if (!mounted) return;

    final authState = ref.read(authNotifierProvider);
    final user = authState.user;

    if (authState.status == AuthStatus.authenticated &&
        user != null &&
        !user.isGuest &&
        !user.isEmailVerified &&
        user.email != null &&
        !_showingDialog) {
      _showVerificationDialog(user.email!);
    }
  }

  Future<void> _showVerificationDialog(String email) async {
    if (!mounted) return;

    setState(() => _showingDialog = true);

    try {
      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => EmailVerificationDialog(
          email: email,
          onResendEmail: () async {
            try {
              await ref
                  .read(authNotifierProvider.notifier)
                  .sendEmailVerification();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Verification email sent')),
              );
            } catch (e) {
              _logger.severe('Failed to send verification email', e);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to send verification email: $e'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          },
          onCancel: () async {
            try {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (!mounted) return;
              context.go('/auth/login');
            } catch (e) {
              _logger.severe('Error during verification cancel/logout', e);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error signing out: $e'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          },
        ),
      );
    } catch (e) {
      _logger.severe('Error showing verification dialog', e);
    } finally {
      if (mounted) {
        setState(() => _showingDialog = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    // Show loading screen while checking auth status
    if (authState.status == AuthStatus.initial) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Handle error state
    if (authState.status == AuthStatus.error) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Authentication Error',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (authState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    authState.errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ElevatedButton(
                onPressed: () => context.go('/auth/login'),
                child: const Text('Return to Login'),
              ),
            ],
          ),
        ),
      );
    }

    // If we get here, we're either authenticated or a guest
    // The router will handle redirecting unauthenticated users
    return widget.child;
  }
}
