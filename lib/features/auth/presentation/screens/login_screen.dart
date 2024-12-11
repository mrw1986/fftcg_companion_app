import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../enums/auth_status.dart';
import '../../providers/auth_providers.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_error_widget.dart';
import '../../../../core/logging/logger_service.dart';
import 'registration_screen.dart';
import '../../../settings/presentation/screens/logs_viewer_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _logger = LoggerService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        _logger.info('Attempting email login for: ${_emailController.text}');
        await ref.read(authNotifierProvider.notifier).signInWithEmailPassword(
              _emailController.text.trim(),
              _passwordController.text,
            );
      } catch (e, stackTrace) {
        _logger.error('Email login failed', e, stackTrace);
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    try {
      _logger.info('Attempting Google sign-in');
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    } catch (e, stackTrace) {
      _logger.error('Google sign-in failed', e, stackTrace);
    }
  }

  Future<void> _handleGuestLogin() async {
    try {
      _logger.info('Attempting guest login');
      await ref.read(authNotifierProvider.notifier).signInAsGuest();
    } catch (e, stackTrace) {
      _logger.error('Guest login failed', e, stackTrace);
    }
  }

  Future<void> _handlePasswordReset() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address'),
        ),
      );
      return;
    }

    try {
      _logger.info('Attempting password reset for: ${_emailController.text}');
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent'),
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Password reset failed', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send password reset email'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'FFTCG Companion',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  AuthTextField(
                    controller: _emailController,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value!)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  AuthTextField(
                    controller: _passwordController,
                    label: 'Password',
                    isPassword: true,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Please enter your password';
                      }
                      if (value!.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _handlePasswordReset,
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (authState.errorMessage != null)
                    AuthErrorWidget(
                      message: authState.errorMessage!,
                    ),
                  AuthButton(
                    text: 'Login',
                    onPressed: _handleEmailLogin,
                    isLoading: authState.status == AuthStatus.loading,
                  ),
                  AuthButton(
                    text: 'Continue with Google',
                    onPressed: _handleGoogleLogin,
                    isLoading: authState.status == AuthStatus.loading,
                    isOutlined: true,
                  ),
                  AuthButton(
                    text: 'Continue as Guest',
                    onPressed: _handleGuestLogin,
                    isLoading: authState.status == AuthStatus.loading,
                    isOutlined: true,
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const RegistrationScreen(),
                        ),
                      );
                    },
                    child: const Text('Create an Account'),
                  ),
                  // After your other buttons
                  IconButton(
                    icon: const Icon(Icons.bug_report),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const LogsViewerScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
