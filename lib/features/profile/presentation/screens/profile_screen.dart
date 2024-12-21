// lib/features/profile/presentation/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/profile_header.dart';
import '../widgets/collection_stats.dart';
import '../widgets/deck_stats.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/user_stats_provider.dart';

class ProfileScreen extends ConsumerWidget {
  final VoidCallback handleLogout;

  const ProfileScreen({
    super.key,
    required this.handleLogout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final stats = ref.watch(userStatsProvider);
    final themeColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userStatsProvider);
        },
        child: ListView(
          children: [
            ProfileHeader(
              userName: user?.displayName ?? 'Guest User',
              email: user?.email,
              avatarUrl: user?.photoURL,
              avatarColor: themeColor,
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Collection Stats',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            CollectionStats(
              totalCards: stats.totalCards,
              foilCards: stats.foilCards,
              nonFoilCards: stats.nonFoilCards,
              collectionValue: stats.totalValue,
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Deck Stats',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            DeckStats(
              totalDecks: stats.totalDecks,
              favoriteElement: stats.mostUsedElement,
              elementUsage: stats.elementUsageStats,
            ),
          ],
        ),
      ),
    );
  }
}
