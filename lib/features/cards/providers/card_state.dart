import '../models/card_filter_options.dart';
import '../models/fftcg_card.dart';

enum CardLoadingStatus {
  initial,
  loading,
  loaded,
  error,
}

class CardState {
  final CardLoadingStatus status;
  final List<FFTCGCard> cards;
  final String? errorMessage;
  final bool isGridView;
  final String? searchQuery;
  final CardFilterOptions? filterOptions;
  final bool isLoading;
  final bool hasReachedEnd;
  final int currentPage;

  const CardState({
    this.status = CardLoadingStatus.initial,
    this.cards = const [],
    this.errorMessage,
    this.isGridView = true,
    this.searchQuery,
    this.filterOptions,
    this.isLoading = false,
    this.hasReachedEnd = false,
    this.currentPage = 0,
  });

  CardState copyWith({
    CardLoadingStatus? status,
    List<FFTCGCard>? cards,
    String? errorMessage,
    bool? isGridView,
    String? searchQuery,
    CardFilterOptions? filterOptions,
    bool? isLoading,
    bool? hasReachedEnd,
    int? currentPage,
  }) {
    return CardState(
      status: status ?? this.status,
      cards: cards ?? this.cards,
      errorMessage: errorMessage ?? this.errorMessage,
      isGridView: isGridView ?? this.isGridView,
      searchQuery: searchQuery ?? this.searchQuery,
      filterOptions: filterOptions ?? this.filterOptions,
      isLoading: isLoading ?? this.isLoading,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      currentPage: currentPage ?? this.currentPage,
    );
  }

  @override
  String toString() {
    return '''CardState(
      status: $status,
      cards: ${cards.length} cards,
      errorMessage: $errorMessage,
      isGridView: $isGridView,
      searchQuery: $searchQuery,
      filterOptions: $filterOptions,
      isLoading: $isLoading,
      hasReachedEnd: $hasReachedEnd,
      currentPage: $currentPage
    )''';
  }
}
