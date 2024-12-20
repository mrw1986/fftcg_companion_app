import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

final themeColorProvider = StateProvider<Color>((ref) => Colors.purple);

final persistFiltersProvider = StateProvider<bool>((ref) => true);

final persistSortProvider = StateProvider<bool>((ref) => true);

final settingsNotifierProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

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
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState());

  void setThemeMode(ThemeMode mode) {
    state = SettingsState(
      themeMode: mode,
      themeColor: state.themeColor,
      persistFilters: state.persistFilters,
      persistSort: state.persistSort,
    );
  }

  void setThemeColor(Color color) {
    state = SettingsState(
      themeMode: state.themeMode,
      themeColor: color,
      persistFilters: state.persistFilters,
      persistSort: state.persistSort,
    );
  }

  void setPersistFilters(bool value) {
    state = SettingsState(
      themeMode: state.themeMode,
      themeColor: state.themeColor,
      persistFilters: value,
      persistSort: state.persistSort,
    );
  }

  void setPersistSort(bool value) {
    state = SettingsState(
      themeMode: state.themeMode,
      themeColor: state.themeColor,
      persistFilters: state.persistFilters,
      persistSort: value,
    );
  }

  void toggleTheme() {
    final newMode =
        state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setThemeMode(newMode);
  }
}
