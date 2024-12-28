import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/logging/talker_service.dart';
import '../repositories/card_repository.dart';
import '../services/card_cache_service.dart';
import 'card_notifier.dart';
import 'card_state.dart';
import '../models/fftcg_card.dart';
import '../models/card_filter_options.dart';

// Core providers
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in main.dart');
});

// Service providers
final cardCacheServiceProvider = Provider<CardCacheService>((ref) {
  return CardCacheService(
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

final cardRepositoryProvider = Provider<CardRepository>((ref) {
  return CardRepository();
});

// Main card state provider
final cardNotifierProvider =
    StateNotifierProvider<CardNotifier, CardState>((ref) {
  final repository = ref.watch(cardRepositoryProvider);
  final cacheService = ref.watch(cardCacheServiceProvider);
  final talker = TalkerService();

  ref.onDispose(() {
    talker.info('Disposing CardNotifier provider');
  });

  return CardNotifier(
    repository: repository,
    cacheService: cacheService,
    talker: talker,
  );
});

// Convenience providers for card data
final cardsProvider = Provider<List<FFTCGCard>>((ref) {
  return ref.watch(cardNotifierProvider).cards;
});

final filteredCardsProvider = Provider<List<FFTCGCard>>((ref) {
  final state = ref.watch(cardNotifierProvider);
  final filters = state.filterOptions;
  if (filters == null) return state.cards;

  return state.cards.where((card) {
    if (filters.elements?.isNotEmpty ?? false) {
      if (!card.elements
          .any((element) => filters.elements!.contains(element))) {
        return false;
      }
    }
    if (filters.cardType != null && card.cardType != filters.cardType) {
      return false;
    }
    if (filters.costs?.isNotEmpty ?? false) {
      if (!filters.costs!.contains(card.cost)) {
        return false;
      }
    }
    return true;
  }).toList();
});

// Status providers
final cardLoadingStatusProvider = Provider<CardLoadingStatus>((ref) {
  return ref.watch(cardNotifierProvider).status;
});

final isGridViewProvider = Provider<bool>((ref) {
  return ref.watch(cardNotifierProvider).isGridView;
});

// Filter-related providers
final uniqueElementsProvider = FutureProvider<List<String>>((ref) async {
  return ref.read(cardRepositoryProvider).getUniqueElements();
});

final uniqueCardTypesProvider = FutureProvider<List<String>>((ref) async {
  return ref.read(cardRepositoryProvider).getUniqueCardTypes();
});

final uniqueRaritiesProvider = FutureProvider<List<String>>((ref) async {
  final cards = await ref.read(cardRepositoryProvider).getAllCards();
  return cards
      .map((card) => card.rarity)
      .where((rarity) => rarity != null)
      .toSet()
      .cast<String>()
      .toList();
});

final uniqueOpusProvider = FutureProvider<List<String>>((ref) async {
  final cards = await ref.read(cardRepositoryProvider).getAllCards();
  return cards
      .map((card) => card.cardNumber?.split('-').first)
      .where((opus) => opus != null)
      .toSet()
      .cast<String>()
      .toList();
});

// Search providers
final searchResultsProvider = FutureProvider.family<List<FFTCGCard>, String>(
  (ref, query) async {
    if (query.isEmpty) return [];
    return ref.read(cardRepositoryProvider).searchCards(query);
  },
);

// Card detail providers
final cardByNumberProvider = FutureProvider.family<FFTCGCard?, String>(
  (ref, cardNumber) async {
    return ref.read(cardRepositoryProvider).getCardByNumber(cardNumber);
  },
);

// Recent cards provider
final recentCardsProvider = Provider<List<String>>((ref) {
  return ref.read(cardCacheServiceProvider).getRecentCards();
});

// Filter state providers
final selectedFiltersProvider = Provider<CardFilterOptions?>((ref) {
  return ref.watch(cardNotifierProvider).filterOptions;
});

final selectedElementsProvider = Provider<List<String>?>((ref) {
  return ref.watch(selectedFiltersProvider)?.elements;
});

final selectedCardTypeProvider = Provider<String?>((ref) {
  return ref.watch(selectedFiltersProvider)?.cardType;
});

final selectedCostsProvider = Provider<List<String>?>((ref) {
  return ref.watch(selectedFiltersProvider)?.costs;
});

final selectedRaritiesProvider = Provider<List<String>?>((ref) {
  return ref.watch(selectedFiltersProvider)?.rarities;
});

final selectedOpusProvider = Provider<List<String>?>((ref) {
  return ref.watch(selectedFiltersProvider)?.opus;
});

// Error handling provider
final cardErrorMessageProvider = Provider<String?>((ref) {
  return ref.watch(cardNotifierProvider).errorMessage;
});

// Sort-related providers
final currentSortOptionProvider = Provider<CardSortOption>((ref) {
  return ref.watch(selectedFiltersProvider)?.sortOption ??
      CardSortOption.setNumber;
});

final sortAscendingProvider = Provider<bool>((ref) {
  return ref.watch(selectedFiltersProvider)?.ascending ?? true;
});
