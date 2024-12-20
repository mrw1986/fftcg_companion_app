import 'package:flutter/material.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showMenuButton;
  final VoidCallback? handleLogout;
  final PreferredSizeWidget? bottom;

  const CommonAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showMenuButton = true,
    this.handleLogout,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> finalActions = [...?actions];

    if (handleLogout != null) {
      finalActions.add(
        PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'offline',
              child: Row(
                children: [
                  Icon(Icons.offline_bolt),
                  SizedBox(width: 8),
                  Text('Offline Management'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout),
                  SizedBox(width: 8),
                  Text('Logout'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'offline':
                Navigator.pushNamed(context, '/offline');
                break;
              case 'logout':
                handleLogout?.call();
                break;
            }
          },
        ),
      );
    }

    return AppBar(
      title: Text(title),
      leading: showMenuButton
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
      actions: finalActions,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );
}
