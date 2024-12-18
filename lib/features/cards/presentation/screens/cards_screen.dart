import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/card_providers.dart';
import '../../models/card_filter_options.dart';
import '../widgets/card_grid_item.dart';
import '../widgets/card_list_item.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/sort_menu_button.dart';
import '../widgets/search_bar_widget.dart';
import '../../../../core/logging/logger_service.dart';
import '../../providers/card_state.dart';
import '../../../settings/presentation/screens/offline_management_screen.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';

class CardsScreen extends ConsumerStatefulWidget {
  final VoidCallback? handleLogout;

  const CardsScreen({
    super.key,
    this.handleLogout,
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
      appBar: AppBar(
        title: const Text('Card Database'),
        actions: [
          const SortMenuButton(),
          IconButton(
            icon: Icon(cardState.isGridView ? Icons.list : Icons.grid_view),
            onPressed: () {
              ref.read(cardNotifierProvider.notifier).toggleViewMode();
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'offline':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OfflineManagementScreen(),
                    ),
                  );
                  break;
                case 'logout':
                  if (widget.handleLogout != null) {
                    widget.handleLogout!();
                  }
                  break;
              }
            },
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
              if (widget.handleLogout != null)
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
          ),
        ],
        bottom: PreferredSize(
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
      ),
      drawer: const AppDrawer(currentRoute: '/cards'),
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
    );
  }
}
