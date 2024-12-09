import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
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
    _startEmailVerificationCheck();
  }

  void _startEmailVerificationCheck() {
    _emailVerificationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && !user.emailVerified) {
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
