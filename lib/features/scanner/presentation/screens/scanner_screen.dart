import 'package:flutter/material.dart';

import '../../../settings/presentation/screens/settings_screen.dart';

class ScannerScreen extends StatelessWidget {
  final VoidCallback handleLogout;

  const ScannerScreen({
    super.key,
    required this.handleLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    handleLogout: handleLogout,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Scanner Screen - Coming Soon'),
      ),
    );
  }
}
