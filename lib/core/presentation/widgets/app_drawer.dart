import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/providers/auth_providers.dart';

class AppDrawer extends ConsumerWidget {
  final String currentRoute;
  final VoidCallback? handleLogout; // Add this

  const AppDrawer({
    super.key,
    required this.currentRoute,
    this.handleLogout, // Add this
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(ref),
          const Divider(),
          _buildNavigationItem(
            context: context,
            title: 'Card Database',
            icon: Icons.grid_view,
            route: '/cards',
            isSelected: currentRoute == '/cards',
          ),
          _buildNavigationItem(
            context: context,
            title: 'My Collection',
            icon: Icons.collections_bookmark,
            route: '/collection',
            isSelected: currentRoute == '/collection',
          ),
          _buildNavigationItem(
            context: context,
            title: 'Decks',
            icon: Icons.style,
            route: '/decks',
            isSelected: currentRoute == '/decks',
          ),
          _buildNavigationItem(
            context: context,
            title: 'Card Scanner',
            icon: Icons.camera_alt,
            route: '/scanner',
            isSelected: currentRoute == '/scanner',
          ),
          const Divider(),
          if (user != null && !user.isGuest)
            _buildNavigationItem(
              context: context,
              title: 'Profile',
              icon: Icons.person,
              route: '/profile',
              isSelected: currentRoute == '/profile',
            ),
          _buildNavigationItem(
            context: context,
            title: 'Settings',
            icon: Icons.settings,
            route: '/settings',
            isSelected: currentRoute == '/settings',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    final email = user?.email ?? '';
    final displayName =
        user?.displayName ?? 'User ${user?.id.substring(0, 4) ?? ''}';

    return UserAccountsDrawerHeader(
      currentAccountPicture: CircleAvatar(
        backgroundColor: Colors.white,
        child: Text(
          displayName[0].toUpperCase(),
          style: const TextStyle(fontSize: 24),
        ),
      ),
      accountName: Text(displayName),
      accountEmail: Text(email),
    );
  }

  Widget _buildNavigationItem({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String route,
    required bool isSelected,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
      selected: isSelected,
      onTap: () {
        if (route == '/cards') {
          Navigator.pushReplacementNamed(
            context,
            route,
            arguments: handleLogout,
          );
        } else {
          Navigator.pushReplacementNamed(
            context,
            route,
            arguments: handleLogout,
          );
        }
      },
    );
  }
}
