// lib/features/cards/presentation/screens/cards_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/card_providers.dart';
import '../../models/card_filter_options.dart';
import '../widgets/card_grid_item.dart';
import '../widgets/card_list_item.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/search_bar_widget.dart';
import '../../../../core/logging/logger_service.dart';
import '../../providers/card_state.dart';
import '../../../auth/providers/auth_providers.dart';

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
  final _logger = LoggerService();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _logger.info('Cards screen initialized');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showFilterBottomSheet() {
    final currentFilters = ref.read(cardNotifierProvider).filterOptions ??
        const CardFilterOptions();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterBottomSheet(
        currentFilters: currentFilters,
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

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Column(
          children: [
            const CardSearchBar(),
            if (user != null && !user.isGuest)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Welcome, ${user.displayName ?? 'User'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(cardNotifierProvider.notifier).refreshCards(),
        child: switch (cardState.status) {
          CardLoadingStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
          CardLoadingStatus.error => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(cardState.errorMessage ?? 'An error occurred'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        ref.read(cardNotifierProvider.notifier).refreshCards(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          _ => cardState.cards.isEmpty
              ? const Center(child: Text('No cards found'))
              : cardState.isGridView
                  ? GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: cardState.cards.length,
                      itemBuilder: (context, index) {
                        final card = cardState.cards[index];
                        return CardGridItem(
                          card: card,
                          useHighRes: false,
                        );
                      },
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: cardState.cards.length,
                      itemBuilder: (context, index) {
                        final card = cardState.cards[index];
                        return CardListItem(
                          card: card,
                        );
                      },
                    ),
        },
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'view_toggle',
            onPressed: () {
              ref.read(cardNotifierProvider.notifier).toggleViewMode();
            },
            child: Icon(cardState.isGridView ? Icons.list : Icons.grid_view),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            heroTag: 'filter',
            onPressed: _showFilterBottomSheet,
            child: const Icon(Icons.filter_list),
          ),
        ],
      ),
    );
  }
}
