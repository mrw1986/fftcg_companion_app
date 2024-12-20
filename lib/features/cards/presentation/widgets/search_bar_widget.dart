// lib/features/cards/presentation/widgets/search_bar_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/card_providers.dart';
import '../screens/card_detail_screen.dart';
import '../../../../core/logging/logger_service.dart';
import '../../models/fftcg_card.dart';

class CardSearchBar extends ConsumerStatefulWidget {
  const CardSearchBar({super.key});

  @override
  ConsumerState<CardSearchBar> createState() => _CardSearchBarState();
}

class _CardSearchBarState extends ConsumerState<CardSearchBar> {
  final _searchController = TextEditingController();
  final _logger = LoggerService();
  final _debouncer = Debouncer(milliseconds: 500);
  bool _isSearching = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _logger.info('Search bar initialized');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debouncer.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debouncer.run(() {
      if (mounted) {
        setState(() => _isSearching = query.isNotEmpty);
        if (query.isNotEmpty) {
          _showSearchResults(query);
        } else {
          _removeOverlay();
        }
      }
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showSearchResults(String query) {
    _removeOverlay();

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: offset.dy + size.height,
        left: offset.dx,
        width: size.width,
        child: Material(
          elevation: 8,
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: Consumer(
              builder: (context, ref, _) {
                final searchResults = ref.watch(searchResultsProvider(query));

                return searchResults.when(
                  data: (List<FFTCGCard> cards) {
                    if (cards.isEmpty) {
                      return const ListTile(
                        title: Text('No cards found'),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: cards.length,
                      itemBuilder: (context, index) {
                        final card = cards[index];
                        return ListTile(
                          leading: SizedBox(
                            width: 40,
                            height: 56,
                            child: Hero(
                              tag: 'search_${card.cardNumber}',
                              child: Image.network(
                                card.lowResUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  _logger.severe('Error loading card image',
                                      error, stackTrace);
                                  return const Icon(Icons.error);
                                },
                              ),
                            ),
                          ),
                          title: Text(
                            card.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            card.cardNumber ?? '',
                            maxLines: 1,
                          ),
                          trailing: card.elements.isNotEmpty
                              ? Text(
                                  card.elements.first,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                )
                              : null,
                          onTap: () {
                            final nav = Navigator.of(context);
                            _removeOverlay();
                            _searchController.clear();
                            setState(() => _isSearching = false);
                            nav.push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    CardDetailScreen(card: card),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, stackTrace) {
                    _logger.severe('Search error', error, stackTrace);
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Error searching cards'),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          SearchBar(
            controller: _searchController,
            hintText: 'Search cards...',
            leading: const Icon(Icons.search),
            trailing: [
              if (_isSearching)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                    _removeOverlay();
                  },
                ),
            ],
            onChanged: _onSearchChanged,
            padding: const WidgetStatePropertyAll<EdgeInsets>(
              EdgeInsets.symmetric(horizontal: 16.0),
            ),
          ),
        ],
      ),
    );
  }
}

class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
