import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logging/logger_service.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LogsViewerScreen extends ConsumerStatefulWidget {
  const LogsViewerScreen({super.key});

  @override
  ConsumerState<LogsViewerScreen> createState() => _LogsViewerScreenState();
}

class _LogsViewerScreenState extends ConsumerState<LogsViewerScreen> {
  final LoggerService _logger = LoggerService();
  final ScrollController _scrollController = ScrollController();
  String _logs = '';
  bool _showErrorLogsOnly = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await _logger.getLogs(errorLogsOnly: _showErrorLogsOnly);
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  Future<void> _shareLogs() async {
    try {
      final logs = await _logger.getLogs(errorLogsOnly: _showErrorLogsOnly);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/fftcg_companion_logs.txt');
      await file.writeAsString(logs);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'FFTCG Companion Logs',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share logs: $e')),
        );
      }
    }
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text('Are you sure you want to clear all logs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _logger.clearLogs(errorLogsOnly: _showErrorLogsOnly);
      await _loadLogs();
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
            onPressed: _clearLogs,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
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
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          setState(() => _showErrorLogsOnly = value);
                          _loadLogs();
                        },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      _logs,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  key: const Key('scroll_up'),
                  heroTag: 'scroll_up_fab', // Add unique hero tag
                  mini: true,
                  onPressed: () {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                  child: const Icon(Icons.arrow_upward),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  key: const Key('scroll_down'),
                  heroTag: 'scroll_down_fab', // Add unique hero tag
                  mini: true,
                  onPressed: () {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                  child: const Icon(Icons.arrow_downward),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
