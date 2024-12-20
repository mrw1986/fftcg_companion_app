import 'package:flutter/material.dart';

import '../../../settings/presentation/screens/settings_screen.dart';

class CollectionScreen extends StatelessWidget {
  final VoidCallback handleLogout;

  const CollectionScreen({
    super.key,
    required this.handleLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Collection'),
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
        child: Text('Collection Screen - Coming Soon'),
      ),
    );
  }
}
