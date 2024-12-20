import 'package:flutter/material.dart';

import '../../../settings/presentation/screens/settings_screen.dart';

class DecksScreen extends StatelessWidget {
  final VoidCallback handleLogout;

  const DecksScreen({
    super.key,
    required this.handleLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Decks'),
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
        child: Text('Decks Screen - Coming Soon'),
      ),
    );
  }
}
