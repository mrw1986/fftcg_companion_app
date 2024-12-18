import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/logging/logger_service.dart';
import '../repositories/card_repository.dart';
import '../services/card_cache_service.dart';
import '../models/card_filter_options.dart';
import '../models/fftcg_card.dart';
import 'card_state.dart';

class CardNotifier extends StateNotifier<CardState> {
  final CardRepository _repository;
  final CardCacheService _cacheService;
  final LoggerService _logger;
  StreamSubscription? _cardsSubscription;

  CardNotifier({
    required CardRepository repository,
    required CardCacheService cacheService,
    LoggerService? logger,
  })  : _repository = repository,
        _cacheService = cacheService,
        _logger = logger ?? LoggerService(),
        super(const CardState()) {
    _initializeCards();
  }

  void _initializeCards() {
    _logger.info('Initializing cards stream');
    final savedFilters = _cacheService.getFilterOptions();
    if (savedFilters != null) {
      state = state.copyWith(filterOptions: savedFilters);
      _logger.info('Restored saved filters: ${savedFilters.toJson()}');
    }
    _watchCards();
  }

  void _watchCards() {
    state = state.copyWith(status: CardLoadingStatus.loading);

    _cardsSubscription?.cancel();

    try {
      _cardsSubscription = _repository
          .watchCards(
            searchQuery: state.searchQuery,
            elements: state.filterOptions?.elements,
            cardType: state.filterOptions?.cardType,
            cost: state.filterOptions?.costs?.join(','),
          )
          .map((cards) => _applyFiltersAndSort(cards))
          .listen(
        (cards) {
          state = state.copyWith(
            status: CardLoadingStatus.loaded,
            cards: cards,
            errorMessage: null,
          );
          _logger.info('Cards loaded and sorted: ${cards.length}');
        },
        onError: (error, stackTrace) {
          state = state.copyWith(
            status: CardLoadingStatus.error,
            errorMessage: 'Failed to load cards',
          );
          _logger.severe('Error loading cards', error, stackTrace);
        },
      );
    } catch (e, stackTrace) {
      _logger.severe('Error setting up cards stream', e, stackTrace);
      state = state.copyWith(
        status: CardLoadingStatus.error,
        errorMessage: 'Failed to initialize card loading',
      );
    }
  }

  List<FFTCGCard> _applyFiltersAndSort(List<FFTCGCard> cards) {
    var filteredCards = List<FFTCGCard>.from(cards);
    final filters = state.filterOptions;

    if (filters != null) {
      // Apply additional filters
      if (filters.rarities?.isNotEmpty ?? false) {
        filteredCards = filteredCards
            .where((card) => filters.rarities!.contains(card.rarity))
            .toList();
      }

      if (filters.job != null) {
        filteredCards = filteredCards
            .where(
                (card) => card.job?.toLowerCase() == filters.job?.toLowerCase())
            .toList();
      }

      if (filters.category != null) {
        filteredCards = filteredCards
            .where((card) =>
                card.category?.toLowerCase() == filters.category?.toLowerCase())
            .toList();
      }

      if (filters.opus?.isNotEmpty ?? false) {
        filteredCards = filteredCards.where((card) {
          final cardOpus = card.cardNumber?.split('-').first;
          return filters.opus!.contains(cardOpus);
        }).toList();
      }

      if (filters.powerRange != null) {
        final range = filters.powerRange!.split('-');
        if (range.length == 2) {
          final minPower = int.tryParse(range[0]) ?? 0;
          final maxPower = int.tryParse(range[1]) ?? 0;
          filteredCards = filteredCards.where((card) {
            final power = int.tryParse(card.power ?? '') ?? 0;
            return power >= minPower && power <= maxPower;
          }).toList();
        }
      }

      // Apply sorting
      switch (filters.sortOption) {
        case CardSortOption.nameAsc:
        case CardSortOption.nameDesc:
          filteredCards.sort((a, b) => filters.ascending
              ? a.name.compareTo(b.name)
              : b.name.compareTo(a.name));
          break;

        case CardSortOption.costAsc:
        case CardSortOption.costDesc:
          filteredCards.sort((a, b) {
            final aCost = int.tryParse(a.cost ?? '') ?? 0;
            final bCost = int.tryParse(b.cost ?? '') ?? 0;
            return filters.ascending
                ? aCost.compareTo(bCost)
                : bCost.compareTo(aCost);
          });
          break;

        case CardSortOption.powerAsc:
        case CardSortOption.powerDesc:
          filteredCards.sort((a, b) {
            final aPower = int.tryParse(a.power ?? '') ?? 0;
            final bPower = int.tryParse(b.power ?? '') ?? 0;
            return filters.ascending
                ? aPower.compareTo(bPower)
                : bPower.compareTo(aPower);
          });
          break;

        case CardSortOption.setNumber:
          filteredCards.sort((a, b) {
            final aNumber = a.cardNumber ?? '';
            final bNumber = b.cardNumber ?? '';
            return filters.ascending
                ? aNumber.compareTo(bNumber)
                : bNumber.compareTo(aNumber);
          });
          break;

        case CardSortOption.releaseDate:
          filteredCards.sort((a, b) {
            final aDate = a.modifiedOn ?? '';
            final bDate = b.modifiedOn ?? '';
            return filters.ascending
                ? aDate.compareTo(bDate)
                : bDate.compareTo(aDate);
          });
          break;
      }
    }

    return filteredCards;
  }

  void toggleViewMode() {
    state = state.copyWith(isGridView: !state.isGridView);
    _logger.info('View mode changed to: ${state.isGridView ? 'grid' : 'list'}');
  }

  void updateFilters(CardFilterOptions options) {
    _logger.info('Updating filters: ${options.toJson()}');
    state = state.copyWith(
      status: CardLoadingStatus.loading,
      filterOptions: options,
    );
    _cacheService.saveFilterOptions(options);
    _watchCards();
  }

  void updateSearch(String? query) {
    if (query == state.searchQuery) return;

    _logger.info('Updating search query: $query');
    state = state.copyWith(
      searchQuery: query,
      status: CardLoadingStatus.loading,
    );
    _watchCards();
  }

  Future<void> refreshCards() async {
    _logger.info('Manually refreshing cards');
    _watchCards();
  }

  @override
  void dispose() {
    _logger.info('Disposing CardNotifier');
    _cardsSubscription?.cancel();
    super.dispose();
  }
}
