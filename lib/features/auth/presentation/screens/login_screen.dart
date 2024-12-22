// lib/features/auth/presentation/screens/login_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../enums/auth_status.dart';
import '../../providers/auth_providers.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_text_field.dart';
import '../../../../core/logging/logger_service.dart';
import '../widgets/email_verification_dialog.dart';
import 'registration_screen.dart';
import '../../../settings/presentation/screens/logs_viewer_screen.dart';
import 'package:flutter/services.dart' show SystemNavigator;
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
  bool _isInputEnabled = true;
  DateTime? _lastBackPress; // Add this field for back press handling

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

  void _handleError(FirebaseAuthException e) {
    if (!mounted) return;

    final errorMessage = ref.read(authServiceProvider).getReadableAuthError(e);
    _logger.severe('Firebase Auth Error: ${e.message}', e);

    if (e.code == 'too-many-requests') {
      setState(() => _isInputEnabled = false);
      Future.delayed(const Duration(minutes: 5), () {
        if (mounted) {
          setState(() => _isInputEnabled = true);
        }
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: e.code == 'too-many-requests' || e.code == 'wrong-password'
            ? SnackBarAction(
                label: 'Reset Password',
                onPressed: () => _handlePasswordReset(),
              )
            : null,
      ),
    );
  }

  Future<void> _handleEmailLogin() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }
    if (_isLoading || !_isInputEnabled) return;

    setState(() => _isLoading = true);

    // Store Navigator and ScaffoldMessenger before async gap
    final navigator = Navigator.of(context);
    final scaffold = ScaffoldMessenger.of(context);

    try {
      _logger.info('Attempting email login for: ${_emailController.text}');
      await ref.read(authNotifierProvider.notifier).signInWithEmailPassword(
            _emailController.text.trim(),
            _passwordController.text,
          );

      // Check if email is verified
      final user = ref.read(currentUserProvider);
      if (!mounted) return;

      if (user != null && !user.isEmailVerified) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => EmailVerificationDialog(
            email: user.email ?? '',
            onResendEmail: () async {
              try {
                await ref
                    .read(authNotifierProvider.notifier)
                    .sendEmailVerification();
                if (!mounted) return;
                scaffold.showSnackBar(
                  const SnackBar(content: Text('Verification email sent')),
                );
              } catch (e) {
                if (!mounted) return;
                scaffold.showSnackBar(
                  SnackBar(
                      content: Text('Failed to send verification email: $e')),
                );
              }
            },
            onCancel: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (!mounted) return;
              navigator.pop();
            },
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      scaffold.showSnackBar(
        SnackBar(
          content: Text(ref.read(authServiceProvider).getReadableAuthError(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, stackTrace) {
      _logger.severe('Email login failed', e, stackTrace);
      if (!mounted) return;
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Login error: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_isLoading || !_isInputEnabled) return;
    setState(() => _isLoading = true);

    try {
      _logger.info('Attempting Google sign-in');
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      _handleError(e);
    } catch (e, stackTrace) {
      _logger.severe('Google sign-in failed', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred during Google sign-in'),
            behavior: SnackBarBehavior.floating,
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
    if (_isLoading || !_isInputEnabled) return;
    setState(() => _isLoading = true);

    try {
      _logger.info('Attempting guest login');
      await ref.read(authNotifierProvider.notifier).signInAsGuest();
    } catch (e, stackTrace) {
      _logger.severe('Guest login failed', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to continue as guest'),
            behavior: SnackBarBehavior.floating,
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      _logger.info('Attempting password reset for: ${_emailController.text}');
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      _handleError(e);
    } catch (e, stackTrace) {
      _logger.severe('Password reset failed', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send password reset email'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = _isLoading || authState.status == AuthStatus.loading;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;

        final now = DateTime.now();
        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        if (!mounted) return;
        await SystemNavigator.pop(animated: true);
      },
      child: Scaffold(
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
                      enabled: _isInputEnabled && !isLoading,
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
                      enabled: _isInputEnabled && !isLoading,
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
                      onPressed: _isInputEnabled && !isLoading
                          ? () => _handleEmailLogin()
                          : null,
                      isLoading: isLoading,
                    ),
                    AuthButton(
                      text: 'Continue with Google',
                      onPressed: _isInputEnabled && !isLoading
                          ? () => _handleGoogleLogin()
                          : null,
                      isLoading: isLoading,
                      isOutlined: true,
                    ),
                    AuthButton(
                      text: 'Continue as Guest',
                      onPressed: _isInputEnabled && !isLoading
                          ? () => _handleGuestLogin()
                          : null,
                      isLoading: isLoading,
                      isOutlined: true,
                    ),
                    TextButton(
                      onPressed: _isInputEnabled && !isLoading
                          ? () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const RegistrationScreen(),
                                ),
                              );
                            }
                          : null,
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
      ),
    );
  }
}
