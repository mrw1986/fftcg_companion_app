import 'package:flutter/material.dart';

class AccountExistsDialog extends StatelessWidget {
  final String email;
  final VoidCallback onLogin;
  final VoidCallback onLink;

  const AccountExistsDialog({
    super.key,
    required this.email,
    required this.onLogin,
    required this.onLink,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Account Already Exists'),
      content: Text(
        'An account with email $email already exists. Would you like to sign in with that account or link it to your current account?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onLogin();
          },
          child: const Text('Sign In'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onLink();
          },
          child: const Text('Link Account'),
        ),
      ],
    );
  }
}
