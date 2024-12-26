// lib/features/cards/presentation/screens/cards_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../providers/card_providers.dart';
import '../../models/card_filter_options.dart';
import '../widgets/card_grid_item.dart';
import '../widgets/card_list_item.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/search_bar_widget.dart';
import '../../providers/card_state.dart';

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
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = maxScroll * 0.9; // Load more when 90% scrolled

    if (currentScroll >= threshold && !_isLoadingMore) {
      _loadMoreCards();
    }
  }

  Future<void> _loadMoreCards() async {
    final cardState = ref.read(cardNotifierProvider);
    if (cardState.isLoading || cardState.hasReachedEnd) return;

    setState(() => _isLoadingMore = true);

    try {
      await ref.read(cardNotifierProvider.notifier).loadNextPage();
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _handleRefresh() async {
    return ref.read(cardNotifierProvider.notifier).refreshCards();
  }

  @override
  Widget build(BuildContext context) {
    final cardState = ref.watch(cardNotifierProvider);
    final themeColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: ResponsiveUtils.getScreenPadding(context),
                child: const SearchBarWidget(),
              ),
            ),
            if (cardState.status == CardLoadingStatus.initial)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (cardState.status == CardLoadingStatus.error)
              SliverFillRemaining(
                child: _buildErrorView(cardState),
              )
            else ...[
              if (cardState.cards.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('No cards found')),
                )
              else
                cardState.isGridView
                    ? _buildCardGrid(cardState)
                    : _buildCardList(cardState),
              if (_isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButtons(cardState, themeColor),
    );
  }

  Widget _buildCardGrid(CardState cardState) {
    final crossAxisCount = ResponsiveUtils.getCardGridCrossAxisCount(context);
    final spacing = ResponsiveUtils
        .spacing[ResponsiveUtils.isPhone(context) ? 'sm' : 'md']!;

    return SliverPadding(
      padding: ResponsiveUtils.getScreenPadding(context),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.7,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final card = cardState.cards[index];
            return CardGridItem(
              card: card,
              useHighRes: ResponsiveUtils.isDesktop(context),
            );
          },
          childCount: cardState.cards.length,
        ),
      ),
    );
  }

  Widget _buildCardList(CardState cardState) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final card = cardState.cards[index];
          return CardListItem(
            card: card,
            height: ResponsiveUtils.getListItemHeight(context),
          );
        },
        childCount: cardState.cards.length,
      ),
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
            ElevatedButton.icon(
              onPressed: _handleRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
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
}
