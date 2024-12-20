// lib/features/auth/presentation/auth_wrapper.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../enums/auth_status.dart';
import '../providers/auth_providers.dart';
import 'screens/login_screen.dart';
import '../../cards/providers/card_providers.dart';
import '../../../main.dart';
import '../presentation/widgets/email_verification_dialog.dart';

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  Timer? _emailVerificationTimer;
  bool _showingDialog = false;

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

    // Set dialog state before showing
    setState(() => _showingDialog = true);

    try {
      await showDialog(
        context: context, // Use current context directly
        barrierDismissible: false,
        builder: (dialogContext) => EmailVerificationDialog(
          email: email,
          onResendEmail: () => _handleResendEmail(
            ScaffoldMessenger.of(context), // Use context for ScaffoldMessenger
            Theme.of(context), // Use context for Theme
          ),
          onCancel: () => _handleCancel(dialogContext),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _showingDialog = false);
      }
    }
  }

  Future<void> _handleResendEmail(
    ScaffoldMessengerState scaffoldMessenger,
    ThemeData theme,
  ) async {
    try {
      await ref.read(authNotifierProvider.notifier).sendEmailVerification();

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Verification email sent'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to send verification email: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleCancel(BuildContext dialogContext) async {
    // Store Navigator before async gap
    final navigator = Navigator.of(dialogContext);
    await ref.read(authNotifierProvider.notifier).signOut();
    if (dialogContext.mounted) {
      navigator.pop();
    }
  }

  Future<void> _handleLogout() async {
    try {
      await ref.read(authNotifierProvider.notifier).signOut();
      ref.invalidate(cardNotifierProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully logged out')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return switch (authState.status) {
      AuthStatus.authenticated || AuthStatus.guest => MainTabScreen(
          handleLogout: _handleLogout,
        ),
      AuthStatus.unauthenticated => const LoginScreen(),
      AuthStatus.loading => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      AuthStatus.error => const LoginScreen(),
      AuthStatus.initial => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
    };
  }
}
