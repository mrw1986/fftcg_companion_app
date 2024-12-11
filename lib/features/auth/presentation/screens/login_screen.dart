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
  void initState() {
    super.initState();
    // Use addPostFrameCallback to modify state after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(authNotifierProvider.notifier).clearError();
      }
    });
  }

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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    try {
      _logger.info('Attempting Google sign-in');
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    } catch (e, stackTrace) {
      _logger.error('Google sign-in failed', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _handleGuestLogin() async {
    try {
      _logger.info('Attempting guest login');
      await ref.read(authNotifierProvider.notifier).signInAsGuest();
    } catch (e, stackTrace) {
      _logger.error('Guest login failed', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _showPasswordResetDialog() async {
    final TextEditingController emailController = TextEditingController(
      text: _emailController.text, // Pre-fill with email if entered
    );

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _handlePasswordReset(emailController.text);
    }
  }

  Future<void> _handlePasswordReset(String email) async {
    try {
      _logger.info('Attempting password reset for: $email');
      await ref
          .read(authNotifierProvider.notifier)
          .sendPasswordResetEmail(email);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Reset Link Sent'),
            content: const Text(
              'If an account exists with this email address, '
              'you will receive a password reset link shortly.\n\n'
              'Please check your email and follow the instructions '
              'to reset your password.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Password reset failed', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getPasswordResetErrorMessage(e)),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  String _getPasswordResetErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'The email address is invalid';
        case 'user-not-found':
          return 'If an account exists, you will receive an email shortly';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later';
        default:
          return 'Failed to send reset email. Please try again';
      }
    }
    return 'An error occurred. Please try again';
  }

  void _navigateToRegistration() {
    // Clear any existing errors before navigating
    ref.read(authNotifierProvider.notifier).clearError();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RegistrationScreen(),
      ),
    );
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
                      onPressed: _showPasswordResetDialog,
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (authState.errorMessage != null)
                    AuthErrorWidget(
                      message: authState.errorMessage!,
                    ),
                  AuthButton(
                    text: 'Sign In',
                    onPressed: _handleEmailLogin,
                    isLoading: authState.status == AuthStatus.loading,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Or',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
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
                  AuthButton(
                    text: 'Create New Account',
                    onPressed: _navigateToRegistration,
                    isOutlined: true,
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
