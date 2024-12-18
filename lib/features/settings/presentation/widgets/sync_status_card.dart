import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncStatusCard extends ConsumerWidget {
  final AsyncValue<bool> syncStatus;
  final VoidCallback onSync;

  const SyncStatusCard({
    super.key,
    required this.syncStatus,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync),
                const SizedBox(width: 8),
                const Text(
                  'Sync Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _buildStatusIcon(syncStatus),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatusMessage(syncStatus),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: syncStatus.isLoading ? null : onSync,
                child: const Text('Sync Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(AsyncValue<bool> status) {
    return status.when(
      data: (isSynced) => Icon(
        isSynced ? Icons.check_circle : Icons.warning,
        color: isSynced ? Colors.green : Colors.orange,
      ),
      loading: () => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const Icon(
        Icons.error,
        color: Colors.red,
      ),
    );
  }

  Widget _buildStatusMessage(AsyncValue<bool> status) {
    return status.when(
      data: (isSynced) => Text(
        isSynced
            ? 'All data is synchronized'
            : 'Some changes need to be synced',
        style: TextStyle(
          color: isSynced ? Colors.green : Colors.orange,
        ),
      ),
      loading: () => const Text('Checking sync status...'),
      error: (error, _) => Text(
        'Error checking sync status: $error',
        style: const TextStyle(color: Colors.red),
      ),
    );
  }
}
