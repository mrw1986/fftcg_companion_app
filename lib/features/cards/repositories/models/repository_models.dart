// Shared types and models used across repository files
class CardRepositoryException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  CardRepositoryException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() =>
      'CardRepositoryException: $message${code != null ? ' (Code: $code)' : ''}';
}

enum CardRepositoryOperation {
  fetch,
  save,
  sync,
  delete,
  cache,
  search,
}

class BatchOperationResult {
  final bool success;
  final List<String> processedIds;
  final List<String> failedIds;
  final String? errorMessage;

  BatchOperationResult({
    required this.success,
    this.processedIds = const [],
    this.failedIds = const [],
    this.errorMessage,
  });

  bool get hasErrors => failedIds.isNotEmpty;
  int get totalProcessed => processedIds.length;
  int get totalFailed => failedIds.length;
}

class CardQueryOptions {
  final String? searchQuery;
  final List<String>? elements;
  final String? cardType;
  final String? cost;
  final bool useCache;
  final Duration? cacheTimeout;

  const CardQueryOptions({
    this.searchQuery,
    this.elements,
    this.cardType,
    this.cost,
    this.useCache = true,
    this.cacheTimeout,
  });

  CardQueryOptions copyWith({
    String? searchQuery,
    List<String>? elements,
    String? cardType,
    String? cost,
    bool? useCache,
    Duration? cacheTimeout,
  }) {
    return CardQueryOptions(
      searchQuery: searchQuery ?? this.searchQuery,
      elements: elements ?? this.elements,
      cardType: cardType ?? this.cardType,
      cost: cost ?? this.cost,
      useCache: useCache ?? this.useCache,
      cacheTimeout: cacheTimeout ?? this.cacheTimeout,
    );
  }
}

class CardSortOptions {
  final String field;
  final bool ascending;

  const CardSortOptions({
    required this.field,
    this.ascending = true,
  });

  static const defaultSort = CardSortOptions(field: 'cardNumber');
}

class CardFilterCriteria {
  final Map<String, dynamic> filters;
  final CardSortOptions sortOptions;
  final int? limit;
  final String? startAfter;

  const CardFilterCriteria({
    this.filters = const {},
    this.sortOptions = CardSortOptions.defaultSort,
    this.limit,
    this.startAfter,
  });

  CardFilterCriteria copyWith({
    Map<String, dynamic>? filters,
    CardSortOptions? sortOptions,
    int? limit,
    String? startAfter,
  }) {
    return CardFilterCriteria(
      filters: filters ?? this.filters,
      sortOptions: sortOptions ?? this.sortOptions,
      limit: limit ?? this.limit,
      startAfter: startAfter ?? this.startAfter,
    );
  }
}
