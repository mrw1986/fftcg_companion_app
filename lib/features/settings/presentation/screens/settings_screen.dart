// lib/features/settings/presentation/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:go_router/go_router.dart';
import '../../../cards/services/card_cache_service.dart';
import '../../providers/settings_providers.dart';
import '../../../auth/presentation/screens/account_linking_screen.dart';
import '../screens/logs_viewer_screen.dart';
import '../../../../core/logging/talker_service.dart';
import '../../../../core/utils/responsive_utils.dart';


class SettingsScreen extends ConsumerWidget {
  final VoidCallback handleLogout;

  const SettingsScreen({
    super.key,
    required this.handleLogout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
    final themeColor = ref.watch(themeColorProvider);
    final size = MediaQuery.of(context).size;
    final isWideScreen = size.width > 900;
    final talker = TalkerService();

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final content = ListView(
            padding: ResponsiveUtils.getScreenPadding(context),
            children: [
              _buildAppearanceSection(context, ref, settings, themeColor),
              const Divider(),
              _buildDataManagementSection(context, ref, settings),
              const Divider(),
              _buildAccountSection(
                  context, ref, themeColor, talker, handleLogout),
            ],
          );

          if (isWideScreen) {
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: 0,
                  onDestinationSelected: (index) {
                    // Handle navigation if needed
                  },
                  labelType: NavigationRailLabelType.selected,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.palette_outlined),
                      selectedIcon: Icon(Icons.palette),
                      label: Text('Appearance'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.storage_outlined),
                      selectedIcon: Icon(Icons.storage),
                      label: Text('Data'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: Text('Account'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: ResponsiveUtils.wrapWithMaxWidth(
                    content,
                    context,
                  ),
                ),
              ],
            );
          }

          return ResponsiveUtils.wrapWithMaxWidth(content, context);
        },
      ),
    );
  }

  Widget _buildAppearanceSection(
    BuildContext context,
    WidgetRef ref,
    SettingsState settings,
    Color themeColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Appearance',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ListTile(
          title: const Text('Theme Mode'),
          trailing: DropdownButton<ThemeMode>(
            value: settings.themeMode,
            onChanged: (ThemeMode? newMode) {
              if (newMode != null) {
                ref
                    .read(settingsNotifierProvider.notifier)
                    .setThemeMode(newMode);
              }
            },
            items: ThemeMode.values.map((mode) {
              return DropdownMenuItem(
                value: mode,
                child: Text(mode.name.capitalize()),
              );
            }).toList(),
          ),
        ),
        ListTile(
          title: const Text('Theme Color'),
          trailing: IconButton(
            icon: Icon(Icons.circle, color: themeColor),
            onPressed: () => _showColorPicker(context, ref),
          ),
        ),
      ],
    );
  }

  Widget _buildDataManagementSection(
    BuildContext context,
    WidgetRef ref,
    SettingsState settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Data Management',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        SwitchListTile(
          title: const Text('Persist Filters'),
          subtitle: const Text('Save filter settings between sessions'),
          value: settings.persistFilters,
          onChanged: (bool value) {
            ref
                .read(settingsNotifierProvider.notifier)
                .setPersistFilters(value);
          },
        ),
        SwitchListTile(
          title: const Text('Persist Sort'),
          subtitle: const Text('Save sort settings between sessions'),
          value: settings.persistSort,
          onChanged: (bool value) {
            ref.read(settingsNotifierProvider.notifier).setPersistSort(value);
          },
        ),
        ListTile(
          leading: Icon(Icons.cleaning_services,
              color: Theme.of(context).colorScheme.primary),
          title: const Text('Clear Image Cache'),
          subtitle: const Text('Free up space used by cached images'),
          onTap: () async {
            try {
              final cacheManager = CardCacheManager();
              await cacheManager.emptyCache();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Image cache cleared')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to clear cache: $e')),
                );
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildAccountSection(
    BuildContext context,
    WidgetRef ref,
    Color themeColor,
    TalkerService talker,
    VoidCallback handleLogout,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Account',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ListTile(
          leading: Icon(Icons.link, color: themeColor),
          title: const Text('Link Account'),
          subtitle: const Text('Connect with another sign-in method'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const AccountLinkingScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: Icon(Icons.bug_report, color: themeColor),
          title: const Text('View Logs'),
          subtitle: const Text('View application logs and diagnostics'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const LogsViewerScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: Icon(Icons.logout, color: themeColor),
          title: const Text('Logout'),
          onTap: () => _handleLogoutTap(context, ref, talker, handleLogout),
        ),
      ],
    );
  }

  Future<void> _handleLogoutTap(
    BuildContext context,
    WidgetRef ref,
    TalkerService talker,
    VoidCallback handleLogout,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(settingsNotifierProvider.notifier).logout();
        if (!context.mounted) return;

        context.go('/auth/login');
        handleLogout();
      } catch (e) {
        talker.severe('Logout failed', e);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to logout: $e')),
          );
        }
      }
    }
  }

  void _showColorPicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ResponsiveUtils.getDialogWidth(context),
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pick a color',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: BlockPicker(
                      pickerColor: ref.watch(themeColorProvider),
                      onColorChanged: (color) {
                        ref
                            .read(settingsNotifierProvider.notifier)
                            .setThemeColor(color);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
