import 'package:flutter/material.dart';

class EmailVerificationDialog extends StatelessWidget {
  final String email;
  final VoidCallback onResendEmail;
  final VoidCallback onCancel;

  const EmailVerificationDialog({
    super.key,
    required this.email,
    required this.onResendEmail,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Email Verification Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Please verify your email address: $email'),
            const SizedBox(height: 16),
            const Text(
              'Check your inbox for the verification email and click the link to verify your account.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: onResendEmail,
            child: const Text('Resend Verification Email'),
          ),
        ],
      ),
    );
  }
}
