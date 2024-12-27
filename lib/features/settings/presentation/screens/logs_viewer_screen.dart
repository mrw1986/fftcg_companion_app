import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    try {
      final logs = await _logger.getLogs(errorLogsOnly: _showErrorLogsOnly);
      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _logs = 'Error loading logs: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _shareLogs() async {
    try {
      final logs = await _logger.getLogs(errorLogsOnly: _showErrorLogsOnly);

      // Verify widget is still mounted before proceeding
      if (!mounted) return;

      final tempDir = await getTemporaryDirectory();
      if (!mounted) return;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'FFTCG_Companion_Logs_$timestamp.txt';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(logs);

      if (!mounted) return;

      final box = context.findRenderObject() as RenderBox?;
      if (!mounted) return;

      // Don't use subject field as it affects Google Drive filename
      final result = await Share.shareXFiles(
        [XFile(file.path, name: fileName)], // Explicitly set the name
        text: fileName, // Use text instead of subject
        sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
      );

      if (!mounted) return;

      if (result.status == ShareResultStatus.success) {
        _logger.info('Logs shared successfully');
      } else if (result.status == ShareResultStatus.dismissed) {
        _logger.info('Share dialog dismissed');
      }

      // Clean up after delay
      Future.delayed(const Duration(seconds: 5), () async {
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          // Ignore cleanup errors
        }
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share logs: $e')),
      );
    }
  }

  Future<void> _copyLogs() async {
    await Clipboard.setData(ClipboardData(text: _logs));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logs copied to clipboard')),
      );
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        automaticallyImplyLeading: false, // Add this
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _logs.isNotEmpty ? _copyLogs : null,
            tooltip: 'Copy logs',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareLogs,
            tooltip: 'Share logs',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Refresh logs',
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context)
                .popUntil((route) => route.isFirst), // Pop to root
            tooltip: 'Close',
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
                  heroTag: 'scroll_up_fab',
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
                  heroTag: 'scroll_down_fab',
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
