// lib/core/logging/logger_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  static const String _logFileName = 'fftcg_companion.log';
  static const String _errorLogFileName = 'fftcg_companion_error.log';
  static const int _maxLogSizeBytes = 5 * 1024 * 1024; // 5MB
  static const int _maxBackupFiles = 3;

  final Logger _logger = Logger('FFTCGCompanion');
  File? _logFile;
  File? _errorLogFile;

  factory LoggerService() {
    return _instance;
  }

  LoggerService._internal() {
    _initializeLogger();
  }

  Future<void> _initializeLogger() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    _logFile = File('${appDocDir.path}/$_logFileName');
    _errorLogFile = File('${appDocDir.path}/$_errorLogFileName');

    // Perform log rotation on startup
    await _rotateLogsIfNeeded();

    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) async {
      final logMessage =
          '${record.time}: ${record.level.name}: ${record.message}';

      if (kDebugMode) {
        debugPrint(logMessage);
      }

      if (_logFile != null) {
        await _logFile!.writeAsString(
          '$logMessage\n',
          mode: FileMode.append,
        );
        await _rotateLogsIfNeeded();
      }

      // Write severe logs to error log file
      if (record.level >= Level.SEVERE && _errorLogFile != null) {
        final errorMessage = '''
${record.time}: ${record.level.name}: ${record.message}
${record.error ?? ''}
${_formatStackTrace(record.stackTrace)}
----------------------------------------
''';
        await _errorLogFile!.writeAsString(
          errorMessage,
          mode: FileMode.append,
        );
      }
    });
  }

  Future<void> _rotateLogsIfNeeded() async {
    if (_logFile == null || !await _logFile!.exists()) return;

    final fileSize = await _logFile!.length();
    if (fileSize > _maxLogSizeBytes) {
      for (var i = _maxBackupFiles - 1; i >= 0; i--) {
        final backupFile = File('${_logFile!.path}.$i');
        if (await backupFile.exists()) {
          if (i == _maxBackupFiles - 1) {
            await backupFile.delete();
          } else {
            await backupFile.rename('${_logFile!.path}.${i + 1}');
          }
        }
      }

      await _logFile!.rename('${_logFile!.path}.0');
      _logFile = File(_logFile!.path);
      await _logFile!.create();
    }
  }

  String _formatStackTrace(StackTrace? stackTrace) {
    if (stackTrace == null) return '';

    return stackTrace.toString().split('\n').map((line) {
      line = line.trim();
      if (line.startsWith('#')) {
        // Format stack trace lines for better readability
        return '  $line';
      }
      return line;
    }).join('\n');
  }

  void info(String message) => _logger.info(message);
  void warning(String message) => _logger.warning(message);
  void severe(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.severe(message, error, stackTrace);
  }

  void exception(String message, Exception exception,
      [StackTrace? stackTrace]) {
    final formattedMessage = '''
Exception: $message
Type: ${exception.runtimeType}
Details: ${exception.toString()}''';

    _logger.severe(
        formattedMessage, exception, stackTrace ?? StackTrace.current);
  }

  Future<void> shareLogs() async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final File tempFile = File('${tempDir.path}/FFTCG_Companion_Logs.txt');

      final StringBuffer buffer = StringBuffer();

      if (_logFile != null && await _logFile!.exists()) {
        buffer.writeln('=== General Logs ===');
        buffer.writeln(await _logFile!.readAsString());
      }

      if (_errorLogFile != null && await _errorLogFile!.exists()) {
        buffer.writeln('=== Error Logs ===');
        buffer.writeln(await _errorLogFile!.readAsString());
      }

      await tempFile.writeAsString(buffer.toString());

      await Share.shareXFiles(
        [XFile(tempFile.path, mimeType: 'text/plain')],
        subject: 'FFTCG Companion Logs',
      );
    } catch (e, stack) {
      _logger.severe('Error sharing logs', e, stack);
    }
  }

  Future<String> getLogs({bool errorLogsOnly = false}) async {
    final StringBuffer buffer = StringBuffer();

    if (!errorLogsOnly && _logFile != null && await _logFile!.exists()) {
      buffer.writeln('=== General Logs ===');
      buffer.writeln(await _logFile!.readAsString());
    }

    if (_errorLogFile != null && await _errorLogFile!.exists()) {
      buffer.writeln('=== Error Logs ===');
      buffer.writeln(await _errorLogFile!.readAsString());
    }

    return buffer.toString().trim().isNotEmpty
        ? buffer.toString()
        : 'No logs available';
  }

  Future<void> clearLogs({bool errorLogsOnly = false}) async {
    if (!errorLogsOnly && _logFile != null && await _logFile!.exists()) {
      await _logFile!.writeAsString('');
    }

    if (_errorLogFile != null && await _errorLogFile!.exists()) {
      await _errorLogFile!.writeAsString('');
    }
  }
}
