// lib/features/auth/presentation/screens/login_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../enums/auth_status.dart';
import '../../providers/auth_providers.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_text_field.dart';
import '../../../../core/logging/logger_service.dart';
import 'registration_screen.dart';
import '../../../settings/presentation/screens/logs_viewer_screen.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _logger.info('Login screen initialized');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _getReadableAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found with this email. Please check your email or create an account.';
      case 'wrong-password':
        return 'Incorrect password. Please try again or use "Forgot Password?".';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with Google Sign-In. Please use Google Sign-In instead.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }

  Future<void> _handleEmailLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        _logger.info('Attempting email login for: ${_emailController.text}');
        await ref.read(authNotifierProvider.notifier).signInWithEmailPassword(
              _emailController.text.trim(),
              _passwordController.text,
            );
      } on FirebaseAuthException catch (e) {
        _logger.severe('Firebase Auth Error: ${e.message}', e);
        if (!mounted) return;

        // This SnackBar can't be const because _getReadableAuthError(e) is dynamic
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getReadableAuthError(e)),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      } catch (e, stackTrace) {
        _logger.severe('Email login failed', e, stackTrace);
        if (!mounted) return;

        // This SnackBar can be const because all its properties are constant
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred. Please try again.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);

    try {
      _logger.info('Attempting Google sign-in');
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      _logger.severe('Firebase Auth Error: ${e.message}', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_getReadableAuthError(e))),
        );
      }
    } catch (e, stackTrace) {
      _logger.severe('Google sign-in failed', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred during Google sign-in'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGuestLogin() async {
    setState(() => _isLoading = true);

    try {
      _logger.info('Attempting guest login');
      await ref.read(authNotifierProvider.notifier).signInAsGuest();
    } catch (e, stackTrace) {
      _logger.severe('Guest login failed', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to continue as guest')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handlePasswordReset() async {
    if (_emailController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your email address')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent')),
        );
      }
    } on FirebaseAuthException catch (e) {
      _logger.severe('Password reset failed: ${e.message}', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_getReadableAuthError(e))),
        );
      }
    } catch (e, stackTrace) {
      _logger.severe('Password reset failed', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send password reset email')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = _isLoading || authState.status == AuthStatus.loading;

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
                      onPressed: isLoading ? null : _handlePasswordReset,
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AuthButton(
                    text: 'Sign In',
                    onPressed: isLoading ? () {} : _handleEmailLogin,
                    isLoading: isLoading,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Or',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  AuthButton(
                    text: 'Continue with Google',
                    onPressed: isLoading ? () {} : _handleGoogleLogin,
                    isLoading: isLoading,
                    isOutlined: true,
                  ),
                  AuthButton(
                    text: 'Continue as Guest',
                    onPressed: isLoading ? () {} : _handleGuestLogin,
                    isLoading: isLoading,
                    isOutlined: true,
                  ),
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const RegistrationScreen(),
                              ),
                            );
                          },
                    child: const Text('Create an Account'),
                  ),
                  if (kDebugMode)
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
