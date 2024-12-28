// lib/features/settings/providers/settings_providers.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/logging/talker_service.dart';
import '../../cards/providers/card_providers.dart';

// Constants for SharedPreferences keys
const String _themeModeKey = 'theme_mode';
const String _themeColorKey = 'theme_color';
const String _persistFiltersKey = 'persist_filters';
const String _persistSortKey = 'persist_sort';
const String _logsKey = 'app_logs';

// Log entry class
class LogEntry {
  final String message;
  final DateTime timestamp;
  final String? userId;

  LogEntry({
    required this.message,
    required this.timestamp,
    this.userId,
  });

  Map<String, dynamic> toJson() => {
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'userId': userId,
      };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
        message: json['message'],
        timestamp: DateTime.parse(json['timestamp']),
        userId: json['userId'],
      );
}

// Theme mode provider
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final themeValue = prefs.getInt(_themeModeKey) ?? ThemeMode.system.index;
  return ThemeMode.values[themeValue];
});

// Theme color provider
final themeColorProvider = StateProvider<Color>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final colorValue = prefs.getInt(_themeColorKey) ?? Colors.purple.value;
  return Color(colorValue);
});

// Persist filters provider
final persistFiltersProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(_persistFiltersKey) ?? true;
});

// Persist sort provider
final persistSortProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(_persistSortKey) ?? true;
});

// App logs provider
final logsProvider = StateNotifierProvider<LogsNotifier, List<LogEntry>>((ref) {
  return LogsNotifier(ref);
});

// Logs stream provider
final logsStreamProvider = StreamProvider<String>((ref) async* {
  final talker = TalkerService();
  while (true) {
    yield talker.history.map((log) => log.generateTextMessage()).join('\n');
    await Future.delayed(const Duration(seconds: 1));
  }
});

// Logs notifier
class LogsNotifier extends StateNotifier<List<LogEntry>> {
  final Ref _ref;
  final TalkerService _talker = TalkerService();
  static const int _maxLogEntries = 1000;

  LogsNotifier(this._ref) : super([]) {
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final logsJson = prefs.getStringList(_logsKey) ?? [];
      state = logsJson
          .map((json) =>
              LogEntry.fromJson(Map<String, dynamic>.from(jsonDecode(json))))
          .toList();

      // Trim old logs if exceeding max entries
      if (state.length > _maxLogEntries) {
        state = state.sublist(state.length - _maxLogEntries);
        _saveLogs(); // Save the trimmed state
      }
    } catch (e) {
      // If there's an error loading logs, start fresh
      state = [];
      clearLogs(); // Clear corrupted logs
    }
  }

  Future<void> addLog(String message) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final entry = LogEntry(
        message: message,
        timestamp: DateTime.now(),
        userId: user?.uid,
      );

      // Add new log and trim if necessary
      final newState = [...state, entry];
      if (newState.length > _maxLogEntries) {
        newState.removeAt(0); // Remove oldest entry
      }
      state = newState;

      await _saveLogs();
    } catch (e) {
      _talker.severe('Error adding log', e); // Changed from print
    }
  }

  Future<void> _saveLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _logsKey,
        state.map((log) => jsonEncode(log.toJson())).toList(),
      );
    } catch (e) {
      _talker.severe('Error saving logs', e); // Changed from print
    }
  }

  Future<void> clearLogs() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_logsKey);
  }

  // Add method to get recent logs only
  List<LogEntry> getRecentLogs([int count = 100]) {
    return state.length <= count ? state : state.sublist(state.length - count);
  }
}

// Settings state class
class SettingsState {
  final ThemeMode themeMode;
  final Color themeColor;
  final bool persistFilters;
  final bool persistSort;

  SettingsState({
    this.themeMode = ThemeMode.system,
    this.themeColor = Colors.purple,
    this.persistFilters = true,
    this.persistSort = true,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    Color? themeColor,
    bool? persistFilters,
    bool? persistSort,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
      persistFilters: persistFilters ?? this.persistFilters,
      persistSort: persistSort ?? this.persistSort,
    );
  }
}

// Settings notifier provider
final settingsNotifierProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref);
});

// Settings notifier class
class SettingsNotifier extends StateNotifier<SettingsState> {
  final Ref _ref;

  SettingsNotifier(this._ref) : super(SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = _ref.read(sharedPreferencesProvider);

    final themeModeIndex =
        prefs.getInt(_themeModeKey) ?? ThemeMode.system.index;
    final themeColorValue = prefs.getInt(_themeColorKey) ?? Colors.purple.value;
    final persistFilters = prefs.getBool(_persistFiltersKey) ?? true;
    final persistSort = prefs.getBool(_persistSortKey) ?? true;

    state = SettingsState(
      themeMode: ThemeMode.values[themeModeIndex],
      themeColor: Color(themeColorValue),
      persistFilters: persistFilters,
      persistSort: persistSort,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setInt(_themeModeKey, mode.index);

    state = state.copyWith(themeMode: mode);
    _ref.read(themeModeProvider.notifier).state = mode;
    _ref
        .read(logsProvider.notifier)
        .addLog('Theme mode changed to: ${mode.name}');
  }

  Future<void> setThemeColor(Color color) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setInt(_themeColorKey, color.value);

    state = state.copyWith(themeColor: color);
    _ref.read(themeColorProvider.notifier).state = color;
    _ref.read(logsProvider.notifier).addLog('Theme color updated');
  }

  Future<void> setPersistFilters(bool value) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setBool(_persistFiltersKey, value);

    state = state.copyWith(persistFilters: value);
    _ref.read(persistFiltersProvider.notifier).state = value;
  }

  Future<void> setPersistSort(bool value) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setBool(_persistSortKey, value);

    state = state.copyWith(persistSort: value);
    _ref.read(persistSortProvider.notifier).state = value;
  }

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      _ref.read(logsProvider.notifier).addLog('User logged out');
      // Additional cleanup if needed
    } catch (e) {
      _ref.read(logsProvider.notifier).addLog('Logout failed: $e');
      rethrow;
    }
  }

  Future<void> resetSettings() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await Future.wait([
      prefs.remove(_themeModeKey),
      prefs.remove(_themeColorKey),
      prefs.remove(_persistFiltersKey),
      prefs.remove(_persistSortKey),
    ]);

    state = SettingsState();
    _ref.read(themeModeProvider.notifier).state = ThemeMode.system;
    _ref.read(themeColorProvider.notifier).state = Colors.purple;
    _ref.read(persistFiltersProvider.notifier).state = true;
    _ref.read(persistSortProvider.notifier).state = true;
    _ref.read(logsProvider.notifier).addLog('Settings reset to defaults');
  }
}

// Convenience providers for accessing individual settings
final isDarkModeProvider = Provider<bool>((ref) {
  final themeMode = ref.watch(themeModeProvider);
  if (themeMode == ThemeMode.system) {
    final platformDispatcher = PlatformDispatcher.instance;
    return platformDispatcher.platformBrightness == Brightness.dark;
  }
  return themeMode == ThemeMode.dark;
});

final currentThemeProvider = Provider<ThemeData>((ref) {
  final isDark = ref.watch(isDarkModeProvider);
  final themeColor = ref.watch(themeColorProvider);

  return isDark
      ? ThemeData.dark().copyWith(
          colorScheme:
              ColorScheme.dark(primary: themeColor, secondary: themeColor))
      : ThemeData.light().copyWith(
          colorScheme:
              ColorScheme.light(primary: themeColor, secondary: themeColor));
});
