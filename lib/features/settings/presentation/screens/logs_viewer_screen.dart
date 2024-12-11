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
  final TextEditingController _searchController = TextEditingController();
  String _logs = '';
  bool _showErrorLogsOnly = false;
  bool _isLoading = true;
  String _filterText = '';
  String _selectedLogLevel = 'All';

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _searchController.addListener(() {
      setState(() {
        _filterText = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  String _getFilteredLogs() {
    if (_filterText.isEmpty &&
        _selectedLogLevel == 'All' &&
        !_showErrorLogsOnly) {
      return _logs;
    }

    final List<String> lines = _logs.split('\n');
    return lines.where((line) {
      bool matchesFilter = _filterText.isEmpty ||
          line.toLowerCase().contains(_filterText.toLowerCase());

      bool matchesLevel = _selectedLogLevel == 'All' ||
          line.contains(': ${_selectedLogLevel.toUpperCase()}: ');

      bool matchesErrorOnly =
          !_showErrorLogsOnly || line.contains(': SEVERE: ');

      return matchesFilter && matchesLevel && matchesErrorOnly;
    }).join('\n');
  }

  Future<void> _shareLogs() async {
    try {
      final logs = _getFilteredLogs();
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

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _getFilteredLogs();
    final logEntries =
        filteredLogs.split('\n').where((line) => line.isNotEmpty).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Logs',
            onPressed: _shareLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Clear Logs',
            onPressed: _clearLogs,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload Logs',
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search logs...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedLogLevel,
                        items: ['All', 'Info', 'Warning', 'Severe']
                            .map((level) => DropdownMenuItem(
                                  value: level,
                                  child: Text(level),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedLogLevel = value;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        const Text('Errors Only'),
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
                  ],
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
                      filteredLogs,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$logEntries entries',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton(
                      heroTag: 'scroll_to_top_button',
                      mini: true,
                      tooltip: 'Scroll to Top',
                      onPressed: _scrollToTop,
                      child: const Icon(Icons.arrow_upward),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      heroTag: 'scroll_to_bottom_button',
                      mini: true,
                      tooltip: 'Scroll to Bottom',
                      onPressed: _scrollToBottom,
                      child: const Icon(Icons.arrow_downward),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
