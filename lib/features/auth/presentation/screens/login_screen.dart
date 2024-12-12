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

  // In LoginScreen
  Future<void> _handleEmailLogin() async {
    if (!mounted) return;
    if (_formKey.currentState?.validate() ?? false) {
      // Store scaffoldMessenger outside try block so it's accessible in catch block
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      try {
        _logger.info('Attempting email login for: ${_emailController.text}');

        final email = _emailController.text.trim();
        final password = _passwordController.text;

        // Attempt sign in
        await ref.read(authNotifierProvider.notifier).signInWithEmailPassword(
              email,
              password,
            );

        // Check if still mounted after async operation
        if (!mounted) return;

        // After successful sign in, check verification status
        final isVerified =
            await ref.read(authNotifierProvider.notifier).isEmailVerified();

        if (!mounted) return;

        if (!isVerified) {
          await _showVerificationDialog(email);

          // Check mounted again after dialog
          if (!mounted) return;

          // Sign out since email isn't verified
          await ref.read(authNotifierProvider.notifier).signOut();

          // Use stored scaffoldMessenger
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Please verify your email before signing in'),
            ),
          );
          return;
        }

        // Only proceed if email is verified
        _logger.info('Email verified, proceeding with login');
      } catch (e, stackTrace) {
        _logger.severe('Email login failed', e, stackTrace);
        if (!mounted) return;

        String errorMessage = 'Login failed';

        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'user-not-found':
              errorMessage = 'No account exists with this email';
              break;
            case 'wrong-password':
              errorMessage = 'Invalid password';
              break;
            case 'invalid-email':
              errorMessage = 'Invalid email format';
              break;
            case 'user-disabled':
              errorMessage = 'This account has been disabled';
              break;
            default:
              errorMessage = e.message ?? 'Authentication failed';
          }
        }

        // Use stored scaffoldMessenger
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    try {
      _logger.info('Attempting Google sign-in');
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    } catch (e, stackTrace) {
      _logger.severe('Google sign-in failed', e, stackTrace);
      if (mounted) {
        // Add mounted check
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
      _logger.severe('Guest login failed', e, stackTrace);
      if (mounted) {
        // Add mounted check
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _handlePasswordReset() async {
    if (_emailController.text.isEmpty) {
      if (mounted) {
        // Add mounted check
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your email address'),
          ),
        );
      }
      return;
    }

    try {
      _logger.info('Attempting password reset for: ${_emailController.text}');
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (mounted) {
        // Add mounted check
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent'),
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.severe('Password reset failed', e, stackTrace);
      if (mounted) {
        // Add mounted check
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send password reset email'),
          ),
        );
      }
    }
  }

  Future<void> _showVerificationDialog(String email) async {
    if (!mounted) return;

    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Email Not Verified'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your email ($email) has not been verified. Please check your email for the verification link.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Didn\'t receive the email?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              // Store the ScaffoldMessenger before async gap
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              await ref
                  .read(authNotifierProvider.notifier)
                  .handleEmailVerification(email);

              if (mounted) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Verification email resent. Please check your inbox.'),
                  ),
                );
              }
            },
            child: const Text('Resend Verification Email'),
          ),
        ],
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
                    text: 'Sign In',
                    onPressed: _handleEmailLogin,
                    isLoading: authState.status == AuthStatus.loading,
                  ),
                  const SizedBox(height: 16),
                  const Text('Or'),
                  const SizedBox(height: 16),
                  AuthButton(
                    text: 'Create New Account',
                    onPressed: () {
                      ref
                          .read(authNotifierProvider.notifier)
                          .clearError(); // Clear error state
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const RegistrationScreen(),
                        ),
                      );
                    },
                    isOutlined: true,
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
                  // Removed duplicate "Create an Account" TextButton
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
