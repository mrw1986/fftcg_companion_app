// lib/features/settings/presentation/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/theme_selector.dart';
import '../widgets/color_picker.dart';
import '../widgets/settings_switch_tile.dart';
import '../screens/offline_management_screen.dart';
import '../../providers/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: const [
          _ThemeSection(),
          Divider(),
          _PreferencesSection(),
          Divider(),
          _OfflineSection(),
        ],
      ),
    );
  }
}

class _ThemeSection extends ConsumerWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Appearance',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const ThemeSelector(),
        const ColorPicker(),
      ],
    );
  }
}

class _PreferencesSection extends ConsumerWidget {
  const _PreferencesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Preferences',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        SettingsSwitchTile(
          title: 'Remember Filters',
          subtitle: 'Save filter settings between sessions',
          value: ref.watch(persistFiltersProvider),
          onChanged: (value) {
            ref
                .read(settingsNotifierProvider.notifier)
                .setPersistFilters(value);
          },
        ),
        SettingsSwitchTile(
          title: 'Remember Sort Order',
          subtitle: 'Save sort settings between sessions',
          value: ref.watch(persistSortProvider),
          onChanged: (value) {
            ref.read(settingsNotifierProvider.notifier).setPersistSort(value);
          },
        ),
      ],
    );
  }
}

class _OfflineSection extends ConsumerWidget {
  const _OfflineSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Offline Access',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.offline_bolt),
          title: const Text('Offline Management'),
          subtitle: const Text('Manage offline data and sync settings'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OfflineManagementScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}
