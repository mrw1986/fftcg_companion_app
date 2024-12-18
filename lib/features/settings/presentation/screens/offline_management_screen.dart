import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/logging/logger_service.dart';
import '../widgets/sync_status_card.dart';
import '../widgets/sync_action_card.dart';
import '../widgets/offline_storage_info.dart';
import '../widgets/sync_progress_indicator.dart';

class OfflineManagementScreen extends ConsumerStatefulWidget {
  const OfflineManagementScreen({super.key});

  @override
  ConsumerState<OfflineManagementScreen> createState() => _OfflineManagementScreenState();
}

class _OfflineManagementScreenState extends ConsumerState<OfflineManagementScreen> {
  final LoggerService _logger = LoggerService();
  bool _isSyncing = false;

  Future<void> _handleManualSync() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);
    try {
      _logger.info('Starting manual sync');
      await ref.read(syncServiceProvider).syncPendingChanges();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync completed successfully')),
        );
      }
      _logger.info('Manual sync completed');
    } catch (e) {
      _logger.severe('Manual sync failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Sync failed. Please try again.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _handleManualSync,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _handleResetSync() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Sync Status'),
        content: const Text(
          'This will mark all data for re-sync. Proceed?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        _logger.info('Starting sync reset');
        await ref.read(syncServiceProvider).resetSyncStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sync status reset successfully')),
          );
        }
        _logger.info('Sync reset completed');
      } catch (e) {
        _logger.severe('Sync reset failed', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to reset sync status')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(syncStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About Offline Mode'),
                  content: const Text(
                      'Offline mode allows you to view and modify your collection '
                      'without an internet connection. Changes will be synchronized '
                      'when you\'re back online.\n\n'
                      'Green status indicates all data is synced.\n'
                      'Yellow indicates pending changes.\n'
                      'Red indicates sync errors.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleManualSync,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SyncStatusCard(
              syncStatus: syncStatus,
              onSync: _handleManualSync,
            ),
            const SizedBox(height: 16),
            if (_isSyncing) ...[
              const SyncProgressIndicator(),
              const SizedBox(height: 16),
            ],
            const OfflineStorageInfo(),
            const SizedBox(height: 16),
            SyncActionCard(
              onReset: _handleResetSync,
              onToggleAutoSync: (enabled) {
                if (enabled) {
                  ref.read(syncServiceProvider).startPeriodicSync();
                } else {
                  ref.read(syncServiceProvider).stopPeriodicSync();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}