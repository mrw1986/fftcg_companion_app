import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talker_flutter/talker_flutter.dart';
import '../../../../core/logging/talker_service.dart';
import 'package:share_plus/share_plus.dart';

class LogsViewerScreen extends ConsumerStatefulWidget {
  const LogsViewerScreen({super.key});

  @override
  ConsumerState<LogsViewerScreen> createState() => _LogsViewerScreenState();
}

class _LogsViewerScreenState extends ConsumerState<LogsViewerScreen> {
  late final TalkerService _talkerService;
  bool _showErrorLogsOnly = false;

  @override
  void initState() {
    super.initState();
    _talkerService = ref.read(talkerServiceProvider);
  }

  Future<void> _shareLogs() async {
    if (!mounted) return;

    final logs = _talkerService.history
        .map((log) =>
            '${log.displayTime()} ${log.title}: ${log.generateTextMessage()}')
        .join('\n');

    try {
      await Share.share(logs);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logs shared successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share logs: $e')),
      );
    }
  }

  Future<void> _handleClearLogs() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text('Are you sure you want to clear all logs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      await _talkerService.clearLogs();
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Logs cleared')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _handleClearLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Text('Show Error Logs Only'),
                const SizedBox(width: 8),
                Switch(
                  value: _showErrorLogsOnly,
                  onChanged: (value) {
                    setState(() => _showErrorLogsOnly = value);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: TalkerBuilder(
              talker: _talkerService.talker,
              builder: (context, data) {
                final logs = _showErrorLogsOnly
                    ? data
                        .where((log) => log.logLevel == LogLevel.error)
                        .toList()
                    : data;

                return ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return ListTile(
                      title: Text(log.generateTextMessage()),
                      subtitle: Text(log.displayTime()),
                      leading: _getLogIcon(log.logLevel ?? LogLevel.debug),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _getLogIcon(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return const Icon(Icons.error, color: Colors.red);
      case LogLevel.warning:
        return const Icon(Icons.warning, color: Colors.orange);
      case LogLevel.info:
        return const Icon(Icons.info, color: Colors.blue);
      case LogLevel.debug:
        return const Icon(Icons.bug_report, color: Colors.grey);
      case LogLevel.verbose:
        return const Icon(Icons.chat_bubble, color: Colors.grey);
      default:
        return const Icon(Icons.circle, color: Colors.grey);
    }
  }
}
