// lib/features/cards/presentation/screens/cards_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../models/user_model.dart';
import '../../providers/card_providers.dart';
import '../../models/card_filter_options.dart';
import '../widgets/card_grid_item.dart';
import '../widgets/card_list_item.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/search_bar_widget.dart';
import '../../providers/card_state.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../settings/providers/settings_providers.dart';

class CardsScreen extends ConsumerStatefulWidget {
  final VoidCallback handleLogout;

  const CardsScreen({
    super.key,
    required this.handleLogout,
  });

  @override
  ConsumerState<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends ConsumerState<CardsScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxWidth: ResponsiveUtils.getDialogWidth(context),
      ),
      builder: (context) => FilterBottomSheet(
        currentFilters: ref.read(cardNotifierProvider).filterOptions ??
            const CardFilterOptions(),
        onFilterChanged: (filters) {
          ref.read(cardNotifierProvider.notifier).updateFilters(filters);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardState = ref.watch(cardNotifierProvider);
    final user = ref.watch(currentUserProvider);
    final themeColor = ref.watch(themeColorProvider);

    return Scaffold(
      body: ResponsiveUtils.buildResponsiveLayout(
        context: context,
        mobile: _buildMobileLayout(cardState, user),
        tablet: _buildTabletLayout(cardState, user),
        desktop: _buildDesktopLayout(cardState, user),
      ),
      floatingActionButton: _buildFloatingActionButtons(cardState, themeColor),
    );
  }

  Widget _buildMobileLayout(CardState cardState, UserModel? user) {
    return Column(
      children: [
        _buildHeader(user),
        Expanded(
          child: _buildCardList(cardState),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(CardState cardState, UserModel? user) {
    final sideNavWidth = ResponsiveUtils.getSideNavWidth(context);

    return Row(
      children: [
        SizedBox(
          width: sideNavWidth,
          child: _buildSidePanel(cardState),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              _buildHeader(user),
              Expanded(
                child: _buildCardList(cardState),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(CardState cardState, UserModel? user) {
    final sideNavWidth = ResponsiveUtils.getSideNavWidth(context);

    return Row(
      children: [
        SizedBox(
          width: sideNavWidth,
          child: _buildSidePanel(cardState),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              _buildHeader(user),
              Expanded(
                child: _buildCardList(cardState),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(UserModel? user) {
    return Padding(
      padding: ResponsiveUtils.getScreenPadding(context),
      child: Column(
        children: [
          const SearchBarWidget(),
          if (user != null && !user.isGuest) ...[
            const SizedBox(height: 8),
            Text(
              'Welcome, ${user.displayName ?? 'User'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize:
                        ResponsiveUtils.getResponsiveFontSize(context, 14),
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidePanel(CardState cardState) {
    return Material(
      child: ListView(
        padding: ResponsiveUtils.getScreenPadding(context),
        children: [
          Text(
            'Filters',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, 20),
                ),
          ),
          const SizedBox(height: 16),
          // Add permanent filter widgets here for tablet/desktop view
        ],
      ),
    );
  }

  Widget _buildCardList(CardState cardState) {
    return ResponsiveUtils.wrapWithMaxWidth(
      RefreshIndicator(
        onRefresh: () => ref.read(cardNotifierProvider.notifier).refreshCards(),
        child: _buildCardContent(cardState),
      ),
      context,
    );
  }

  Widget _buildCardContent(CardState cardState) {
    switch (cardState.status) {
      case CardLoadingStatus.loading:
        return const Center(child: CircularProgressIndicator());

      case CardLoadingStatus.error:
        return _buildErrorView(cardState);

      default:
        if (cardState.cards.isEmpty) {
          return const Center(child: Text('No cards found'));
        }
        return cardState.isGridView
            ? _buildCardGrid(cardState)
            : _buildCardListView(cardState);
    }
  }

  Widget _buildCardGrid(CardState cardState) {
    final crossAxisCount = ResponsiveUtils.getCardGridCrossAxisCount(context);
    final spacing = ResponsiveUtils
        .spacing[ResponsiveUtils.isPhone(context) ? 'sm' : 'md']!;

    return GridView.builder(
      controller: _scrollController,
      padding: ResponsiveUtils.getScreenPadding(context),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.7,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: cardState.cards.length,
      itemBuilder: (context, index) {
        final card = cardState.cards[index];
        return CardGridItem(
          card: card,
          useHighRes: ResponsiveUtils.isDesktop(context),
        );
      },
    );
  }

  Widget _buildCardListView(CardState cardState) {
    return ListView.builder(
      controller: _scrollController,
      padding: ResponsiveUtils.getScreenPadding(context),
      itemCount: cardState.cards.length,
      itemBuilder: (context, index) {
        final card = cardState.cards[index];
        return CardListItem(
          card: card,
          height: ResponsiveUtils.getListItemHeight(context),
        );
      },
    );
  }

  Widget _buildErrorView(CardState cardState) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              cardState.errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 16),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(cardNotifierProvider.notifier).refreshCards(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButtons(CardState cardState, Color themeColor) {
    final buttonSpacing = ResponsiveUtils
        .spacing[ResponsiveUtils.isPhone(context) ? 'sm' : 'md']!;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + buttonSpacing,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'view_toggle',
            onPressed: () {
              ref.read(cardNotifierProvider.notifier).toggleViewMode();
            },
            backgroundColor: themeColor,
            child: Icon(
              cardState.isGridView ? Icons.list : Icons.grid_view,
              color: Colors.white,
            ),
          ),
          SizedBox(width: buttonSpacing),
          FloatingActionButton(
            heroTag: 'filter',
            onPressed: _showFilterBottomSheet,
            backgroundColor: themeColor,
            child: const Icon(
              Icons.filter_list,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
