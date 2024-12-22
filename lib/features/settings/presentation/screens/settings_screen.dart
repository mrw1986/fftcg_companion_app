// lib/features/settings/presentation/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_providers.dart';
import '../../../auth/presentation/screens/account_linking_screen.dart';
import '../screens/logs_viewer_screen.dart';
import '../../../../core/logging/logger_service.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

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
    final logger = LoggerService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Theme Settings Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Appearance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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

          const Divider(),

          // Offline Management Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Data Management',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Persist Filters'),
            value: settings.persistFilters,
            onChanged: (bool value) {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .setPersistFilters(value);
            },
          ),
          SwitchListTile(
            title: const Text('Persist Sort'),
            value: settings.persistSort,
            onChanged: (bool value) {
              ref.read(settingsNotifierProvider.notifier).setPersistSort(value);
            },
          ),

          const Divider(),

          // Account Management Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Account',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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
            onTap: () async {
              // Show confirmation dialog
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

              // If user confirmed and context is still mounted
              if (confirmed == true && context.mounted) {
                try {
                  await ref.read(settingsNotifierProvider.notifier).logout();
                  if (!context.mounted) return;

                  // Pop all routes and replace with login screen
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/', (route) => false);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Successfully logged out')),
                  );

                  handleLogout();
                } catch (e) {
                  logger.severe('Logout failed', e);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to logout: $e')),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          // Wrap ColorPicker in SingleChildScrollView
          child: BlockPicker(
            // Use BlockPicker for better color selection
            pickerColor: ref.watch(themeColorProvider),
            onColorChanged: (color) {
              ref.read(settingsNotifierProvider.notifier).setThemeColor(color);
              Navigator.of(context)
                  .pop(); // Close the dialog after color selection
            },
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
