import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../enums/auth_status.dart';
import '../providers/auth_providers.dart';
import 'screens/login_screen.dart';
import '../../cards/presentation/screens/cards_screen.dart';
import '../../../core/logging/logger_service.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startEmailVerificationCheck();
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    _logger.info('Auth status: ${authState.status}');

    switch (authState.status) {
      case AuthStatus.authenticated:
      case AuthStatus.guest:
        return const CardsScreen();
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
