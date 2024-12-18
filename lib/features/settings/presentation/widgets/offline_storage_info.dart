import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineStorageInfo extends ConsumerStatefulWidget {
  const OfflineStorageInfo({super.key});

  @override
  ConsumerState<OfflineStorageInfo> createState() => _OfflineStorageInfoState();
}

class _OfflineStorageInfoState extends ConsumerState<OfflineStorageInfo> {
  String _lastSyncTime = 'Never';

  @override
  void initState() {
    super.initState();
    _loadLastSyncTime();
  }

  Future<void> _loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt('last_sync_timestamp');
    if (lastSync != null) {
      final date = DateTime.fromMillisecondsSinceEpoch(lastSync);
      setState(() {
        _lastSyncTime = _formatLastSync(date);
      });
    }
  }

  String _formatLastSync(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardCount = ref.watch(syncServiceProvider).getCardCount();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Offline Storage',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              context,
              'Cards Stored',
              '$cardCount cards',
              Icons.storage,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              'Last Sync',
              _lastSyncTime,
              Icons.access_time,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
