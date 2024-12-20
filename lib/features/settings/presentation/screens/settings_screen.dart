import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/screens/account_linking_screen.dart';
import '../../../auth/providers/auth_providers.dart';
import '../widgets/theme_selector.dart';
import '../widgets/color_picker.dart';
import '../widgets/settings_switch_tile.dart';
import '../screens/offline_management_screen.dart';
import '../../providers/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  final VoidCallback? handleLogout;

  const SettingsScreen({
    super.key,
    this.handleLogout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          actions: [
            IconButton(
              icon: Icon(
                ref.watch(themeModeProvider) == ThemeMode.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
              ),
              onPressed: () {
                ref.read(settingsNotifierProvider.notifier).toggleTheme();
              },
            ),
          ],
        ),
        body: ListView(
          children: [
            const _ThemeSection(),
            const Divider(),
            _AccountSection(handleLogout: handleLogout),
            const _PreferencesSection(),
            const Divider(),
            const _OfflineSection(),
          ],
        ),
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

class _AccountSection extends ConsumerWidget {
  final VoidCallback? handleLogout;

  const _AccountSection({this.handleLogout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null || user.isGuest) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Account',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.link),
          title: const Text('Link Additional Account'),
          subtitle: const Text('Add another sign-in method'),
          onTap: () async {
            try {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccountLinkingScreen(),
                ),
              );

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Account linked successfully'),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error linking account: ${e.toString()}'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Logout'),
          onTap: handleLogout,
        ),
        const Divider(),
      ],
    );
  }
}
