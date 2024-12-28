import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger.dart';

class TalkerService {
  static final TalkerService _instance = TalkerService._internal();
  late final Talker _talker;
  late final TalkerRiverpodObserver _riverpodObserver;

  Talker get talker => _talker;

  factory TalkerService() {
    return _instance;
  }

  TalkerService._internal() {
    _initialize();
  }

  void _initialize() {
    _talker = TalkerFlutter.init(
      settings: TalkerSettings(
        enabled: true,
        useConsoleLogs: true,
        maxHistoryItems: 1000,
        useHistory: true,
      ),
    );

    _riverpodObserver = TalkerRiverpodObserver(
      talker: _talker,
    );

    if (kDebugMode) {
      _talker.debug('Talker initialized in debug mode');
    }
  }

  void info(String message) => _talker.info(message);
  void warning(String message) => _talker.warning(message);
  void severe(String message, [Object? error, StackTrace? stackTrace]) {
    _talker.error(message, error, stackTrace);
  }

  void debug(String message) => _talker.debug(message);
  void success(String message) => _talker
      .info('[SUCCESS] $message'); // Changed to use info with a SUCCESS prefix

  void handle(Object error, [StackTrace? stack, String? message]) {
    _talker.handle(error, stack, message);
  }

  void exception(String message, Exception exception,
      [StackTrace? stackTrace]) {
    _talker.error(
        'Exception: $message', exception, stackTrace ?? StackTrace.current);
  }

  List<TalkerData> get history => _talker.history;

  Future<void> clearLogs() async {
    _talker.cleanHistory();
  }

  ProviderObserver get riverpodObserver => _riverpodObserver;
}

final talkerServiceProvider = Provider<TalkerService>((ref) {
  return TalkerService();
});
