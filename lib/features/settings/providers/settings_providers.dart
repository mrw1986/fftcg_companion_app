// lib/features/settings/providers/settings_providers.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cards/providers/card_providers.dart';

// Constants for SharedPreferences keys
const String _themeModeKey = 'theme_mode';
const String _themeColorKey = 'theme_color';
const String _persistFiltersKey = 'persist_filters';
const String _persistSortKey = 'persist_sort';

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
  }

  Future<void> setThemeColor(Color color) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setInt(_themeColorKey, color.value);

    state = state.copyWith(themeColor: color);
    _ref.read(themeColorProvider.notifier).state = color;
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

  Future<void> toggleTheme() async {
    final newMode =
        state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
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
  }
}

// Convenience providers for accessing individual settings
final isDarkModeProvider = Provider<bool>((ref) {
  final themeMode = ref.watch(themeModeProvider);
  if (themeMode == ThemeMode.system) {
    // Get system brightness
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
          colorScheme: ColorScheme.dark(
            primary: themeColor,
            secondary: themeColor,
          ),
        )
      : ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(
            primary: themeColor,
            secondary: themeColor,
          ),
        );
});
