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

  const CardState({
    this.status = CardLoadingStatus.initial,
    this.cards = const [],
    this.errorMessage,
    this.isGridView = true,
    this.searchQuery,
    this.filterOptions,
  });

  CardState copyWith({
    CardLoadingStatus? status,
    List<FFTCGCard>? cards,
    String? errorMessage,
    bool? isGridView,
    String? searchQuery,
    CardFilterOptions? filterOptions,
  }) {
    return CardState(
      status: status ?? this.status,
      cards: cards ?? this.cards,
      errorMessage: errorMessage ?? this.errorMessage,
      isGridView: isGridView ?? this.isGridView,
      searchQuery: searchQuery ?? this.searchQuery,
      filterOptions: filterOptions ?? this.filterOptions,
    );
  }
}
