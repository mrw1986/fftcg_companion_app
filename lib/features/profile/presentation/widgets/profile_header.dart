// lib/features/profile/presentation/widgets/profile_header.dart

import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  final String userName;
  final String? email;
  final String? avatarUrl;
  final Color avatarColor;
  final double size;
  final VoidCallback onLogout; // Add this

  const ProfileHeader({
    super.key,
    required this.userName,
    this.email,
    this.avatarUrl,
    required this.avatarColor,
    required this.size,
    required this.onLogout, // Add this
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: size / 2,
            backgroundColor: avatarColor,
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Icon(
                    Icons.person,
                    size: size / 2,
                    color: Colors.white,
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (email != null)
                  Text(
                    email!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
