import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/providers/auth_providers.dart';

class AppDrawer extends ConsumerWidget {
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  child: Text(
                    user?.displayName?.substring(0, 1).toUpperCase() ?? 'G',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  user?.displayName ?? 'Guest User',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                ),
                Text(
                  user?.email ?? 'Guest Session',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                ),
              ],
            ),
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.view_list,
            title: 'Card Database',
            route: '/cards',
            currentRoute: currentRoute,
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.collections_bookmark,
            title: 'My Collection',
            route: '/collection',
            currentRoute: currentRoute,
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.style,
            title: 'Decks',
            route: '/decks',
            currentRoute: currentRoute,
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.camera_alt,
            title: 'Card Scanner',
            route: '/scanner',
            currentRoute: currentRoute,
          ),
          const Divider(),
          _buildDrawerItem(
            context: context,
            icon: Icons.person,
            title: 'Profile',
            route: '/profile',
            currentRoute: currentRoute,
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.settings,
            title: 'Settings',
            route: '/settings',
            currentRoute: currentRoute,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String route,
    required String currentRoute,
  }) {
    final isSelected = currentRoute == route;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).primaryColor : null,
      ),
      title: Text(
        title,
        style: isSelected
            ? TextStyle(color: Theme.of(context).primaryColor)
            : null,
      ),
      selected: isSelected,
      onTap: () {
        Navigator.pop(context); // Close drawer
        if (!isSelected) {
          Navigator.pushReplacementNamed(context, route);
        }
      },
    );
  }
}
