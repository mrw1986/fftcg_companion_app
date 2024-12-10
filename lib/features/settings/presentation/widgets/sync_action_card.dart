import 'package:flutter/material.dart';

class SyncActionCard extends StatelessWidget {
  final VoidCallback onReset;
  final ValueChanged<bool> onToggleAutoSync;

  const SyncActionCard({
    super.key,
    required this.onReset,
    required this.onToggleAutoSync,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sync Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Auto-sync'),
              subtitle: const Text(
                'Automatically sync changes when online',
              ),
              value: true, // TODO: Get from preferences
              onChanged: onToggleAutoSync,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Reset Sync Status'),
              subtitle: const Text(
                'Mark all data for re-synchronization',
              ),
              onTap: onReset,
            ),
          ],
        ),
      ),
    );
  }
}
