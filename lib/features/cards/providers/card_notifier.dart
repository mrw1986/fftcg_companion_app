// lib/features/cards/providers/card_notifier.dart

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
  static const int _pageSize = 20;

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

  Future<void> _initializeCards() async {
    try {
      state = state.copyWith(status: CardLoadingStatus.loading);

      // Initialize Hive
      await _repository.initialize();

      final savedFilters = _cacheService.getFilterOptions();
      if (savedFilters != null) {
        state = state.copyWith(filterOptions: savedFilters);
        _logger.info('Restored saved filters: ${savedFilters.toJson()}');
      }

      // Load initial page
      await loadNextPage(refresh: true);
    } catch (e, stackTrace) {
      _logger.severe('Error initializing cards', e, stackTrace);
      state = state.copyWith(
        status: CardLoadingStatus.error,
        errorMessage: 'Failed to initialize cards storage',
      );
    }
  }

Future<void> loadNextPage({bool refresh = false}) async {
    if (state.isLoading || (state.hasReachedEnd && !refresh)) return;

    try {
      state = state.copyWith(isLoading: true);

      final page = refresh ? 0 : state.currentPage + 1;
      final List<FFTCGCard> cards =
          await _repository.getCardsPage(page); // Add explicit type here

      if (cards.isEmpty && page == 0) {
        state = state.copyWith(
          status: CardLoadingStatus.loaded,
          cards: [],
          hasReachedEnd: true,
          isLoading: false,
          currentPage: 0,
        );
        return;
      }

      if (cards.length < _pageSize) {
        state = state.copyWith(hasReachedEnd: true);
      }

      final updatedCards = refresh ? cards : [...state.cards, ...cards];

      state = state.copyWith(
        status: CardLoadingStatus.loaded,
        cards: updatedCards,
        isLoading: false,
        currentPage: page,
        errorMessage: null,
      );

      _logger.info('Loaded page $page with ${cards.length} cards');
    } catch (e, stackTrace) {
      _logger.severe('Error loading cards page', e, stackTrace);
      state = state.copyWith(
        status: CardLoadingStatus.error,
        errorMessage: 'Failed to load cards: ${e.toString()}',
        isLoading: false,
      );
    }
  }

  Future<void> refreshCards() async {
    await loadNextPage(refresh: true);
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
    refreshCards();
  }

  void updateSearchQuery(String? query) {
    if (query == state.searchQuery) return;

    _logger.info('Updating search query: $query');
    state = state.copyWith(
      searchQuery: query,
      status: CardLoadingStatus.loading,
    );
    refreshCards();
  }

  @override
  void dispose() {
    _logger.info('Disposing CardNotifier');
    _cardsSubscription?.cancel();
    super.dispose();
  }
}
