// lib/features/profile/presentation/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../models/user_model.dart';
import '../../models/user_stats.dart';
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
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userStatsProvider);
        },
        child: ResponsiveUtils.buildResponsiveLayout(
          context: context,
          mobile: _buildMobileLayout(context, user, stats, themeColor),
          tablet: _buildTabletLayout(context, user, stats, themeColor),
          desktop: _buildDesktopLayout(context, user, stats, themeColor),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    UserModel? user,
    UserStats stats,
    Color themeColor,
  ) {
    return SingleChildScrollView(
      padding: ResponsiveUtils.getScreenPadding(context),
      child: Column(
        children: [
          ProfileHeader(
            userName: user?.displayName ?? 'Guest User',
            email: user?.email,
            avatarUrl: user?.photoURL,
            avatarColor: themeColor,
            size: ResponsiveUtils.isPhone(context) ? 80 : 100,
          ),
          const Divider(),
          _buildStats(context, stats),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(
    BuildContext context,
    UserModel? user,
    UserStats stats,
    Color themeColor,
  ) {
    return SingleChildScrollView(
      padding: ResponsiveUtils.getScreenPadding(context),
      child: ResponsiveUtils.wrapWithMaxWidth(
        Column(
          children: [
            ProfileHeader(
              userName: user?.displayName ?? 'Guest User',
              email: user?.email,
              avatarUrl: user?.photoURL,
              avatarColor: themeColor,
              size: 120,
            ),
            const Divider(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CollectionStats(
                    totalCards: stats.totalCards,
                    foilCards: stats.foilCards,
                    nonFoilCards: stats.nonFoilCards,
                    collectionValue: stats.totalValue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DeckStats(
                    totalDecks: stats.totalDecks,
                    favoriteElement: stats.mostUsedElement,
                    elementUsage: stats.elementUsageStats,
                  ),
                ),
              ],
            ),
          ],
        ),
        context,
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    UserModel? user,
    UserStats stats,
    Color themeColor,
  ) {
    return SingleChildScrollView(
      padding: ResponsiveUtils.getScreenPadding(context),
      child: ResponsiveUtils.wrapWithMaxWidth(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  ProfileHeader(
                    userName: user?.displayName ?? 'Guest User',
                    email: user?.email,
                    avatarUrl: user?.photoURL,
                    avatarColor: themeColor,
                    size: 150,
                  ),
                  const Divider(),
                ],
              ),
            ),
            const SizedBox(width: 32),
            Expanded(
              flex: 7,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CollectionStats(
                      totalCards: stats.totalCards,
                      foilCards: stats.foilCards,
                      nonFoilCards: stats.nonFoilCards,
                      collectionValue: stats.totalValue,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: DeckStats(
                      totalDecks: stats.totalDecks,
                      favoriteElement: stats.mostUsedElement,
                      elementUsage: stats.elementUsageStats,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        context,
      ),
    );
  }

  Widget _buildStats(BuildContext context, UserStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Collection Stats',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 24),
              ),
        ),
        const SizedBox(height: 16),
        CollectionStats(
          totalCards: stats.totalCards,
          foilCards: stats.foilCards,
          nonFoilCards: stats.nonFoilCards,
          collectionValue: stats.totalValue,
        ),
        const SizedBox(height: 24),
        Text(
          'Deck Stats',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 24),
              ),
        ),
        const SizedBox(height: 16),
        DeckStats(
          totalDecks: stats.totalDecks,
          favoriteElement: stats.mostUsedElement,
          elementUsage: stats.elementUsageStats,
        ),
      ],
    );
  }
}
