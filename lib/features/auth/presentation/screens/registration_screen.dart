// lib/features/auth/presentation/screens/registration_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../enums/auth_status.dart';
import '../../providers/auth_providers.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_text_field.dart';
import '../../../../core/logging/logger_service.dart';
import 'login_screen.dart';
import 'account_linking_screen.dart';
import '../widgets/account_exists_dialog.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _logger = LoggerService();
  bool _isLoading = false;
  bool _isInputEnabled = true;

  @override
  void initState() {
    super.initState();
    _logger.info('Registration screen initialized');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
      ),
    );
  }

  Future<void> _handleRegistration() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }
    if (_isLoading || !_isInputEnabled) return;

    setState(() => _isLoading = true);

    try {
      _logger.info('Attempting registration for: ${_emailController.text}');

      final result = await ref
          .read(authNotifierProvider.notifier)
          .registerWithEmailPassword(
            _emailController.text.trim(),
            _passwordController.text,
            _displayNameController.text.trim(),
          );

      if (!mounted) return;

      if (result == null) {
        // Show account exists dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AccountExistsDialog(
            email: _emailController.text,
            onLogin: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
              );
            },
            onLink: () {
              final currentUser = ref.read(authNotifierProvider).user;
              if (currentUser?.isGuest ?? true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please sign in first to link accounts'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AccountLinkingScreen(),
                ),
              );
            },
          ),
        );
      } else {
        // Registration successful, show verification email sent message
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const LoginScreen(),
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Account created! Please check your email to verify your account.',
              ),
              duration: Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      _handleError(e);
    } catch (e, stackTrace) {
      _logger.severe('Unexpected error during registration', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
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

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = _isLoading || authState.status == AuthStatus.loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  controller: _displayNameController,
                  label: 'Display Name',
                  enabled: _isInputEnabled && !isLoading,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter a display name';
                    }
                    if (value!.length < 3) {
                      return 'Display name must be at least 3 characters';
                    }
                    return null;
                  },
                ),
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
                  validator: _validatePassword,
                ),
                AuthTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  enabled: _isInputEnabled && !isLoading,
                  isPassword: true,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                AuthButton(
                  text: 'Create Account',
                  onPressed: _isInputEnabled && !isLoading
                      ? () => _handleRegistration()
                      : null,
                  isLoading: isLoading,
                ),
                if (!_isInputEnabled)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      'Registration temporarily disabled. Please try again later.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
