import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fftcg_card.dart';
import 'models/repository_models.dart';

abstract class BaseCardRepository {
  static const String collectionName = 'cards';
  static const int defaultBatchSize = 50;
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration defaultRetryDelay = Duration(seconds: 2);
  static const int maxRetryAttempts = 3;
  static const Duration defaultCacheExpiration = Duration(hours: 24);
  static const String lastCacheTimeKey = 'last_cache_time';
  static const int maxConcurrentOperations = 3;

  // Core operations
  Future<FFTCGCard?> getCard(String cardNumber);
  Future<List<FFTCGCard>> getCards(CardQueryOptions options);
  Stream<List<FFTCGCard>> watchCards(CardQueryOptions options);
  Future<List<FFTCGCard>> searchCards(String query);

  // Batch operations
  Future<BatchOperationResult> saveBatch(List<FFTCGCard> cards);
  Future<BatchOperationResult> deleteBatch(List<String> cardNumbers);

  // Metadata operations
  Future<List<String>> getUniqueElements();
  Future<List<String>> getUniqueCardTypes();
  Future<int> getTotalCardCount();

  // Cache operations
  Future<bool> isCacheValid();
  Future<void> clearCache();
  Future<void> updateCacheTimestamp();

  // Sync operations
  Future<void> syncCards(List<FFTCGCard> cards);
  Future<bool> needsSync();
  Future<void> markForSync(List<String> cardNumbers);

  // Utility methods
  Future<bool> exists(String cardNumber);
  Future<DateTime?> getLastUpdateTime();

  // Error handling
  Future<T> withErrorHandling<T>({
    required Future<T> Function() operation,
    required CardRepositoryOperation operationType,
    String? context,
    bool shouldRethrow = true,
    T? defaultValue,
    int maxRetries = maxRetryAttempts,
  });
}

abstract class CardRepositoryHelper {
  static bool isValidCardData(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return false;

      // Check required fields
      if (!data.containsKey('name') || !data.containsKey('cleanName')) {
        return false;
      }

      // Check extended data structure
      final extendedData = data['extendedData'];
      if (extendedData == null || extendedData is! List) {
        return false;
      }

      // Basic validation passed
      return true;
    } catch (e) {
      return false;
    }
  }

  static Query buildBaseQuery(
    FirebaseFirestore firestore,
    CardQueryOptions options,
  ) {
    Query query = firestore.collection(BaseCardRepository.collectionName);

    if (options.searchQuery?.isNotEmpty == true) {
      final cleanQuery = options.searchQuery!.toLowerCase().trim();
      query = query
          .where('cleanName', isGreaterThanOrEqualTo: cleanQuery)
          .where('cleanName', isLessThan: '${cleanQuery}z');
    }

    if (options.cardType != null) {
      query = query.where('extendedData', arrayContains: {
        'name': 'CardType',
        'value': options.cardType,
      });
    }

    return query;
  }

  static List<FFTCGCard> filterByElements(
    List<FFTCGCard> cards,
    List<String>? elements,
  ) {
    if (elements?.isEmpty ?? true) return cards;

    return cards
        .where((card) =>
            elements!.any((element) => card.elements.contains(element)))
        .toList();
  }

  static List<FFTCGCard> applySorting(
    List<FFTCGCard> cards,
    CardSortOptions sortOptions,
  ) {
    final sortedCards = List<FFTCGCard>.from(cards);
    sortedCards.sort((a, b) {
      switch (sortOptions.field) {
        case 'name':
          return sortOptions.ascending
              ? a.name.compareTo(b.name)
              : b.name.compareTo(a.name);
        case 'cost':
          final aCost = int.tryParse(a.cost ?? '') ?? 0;
          final bCost = int.tryParse(b.cost ?? '') ?? 0;
          return sortOptions.ascending
              ? aCost.compareTo(bCost)
              : bCost.compareTo(aCost);
        case 'power':
          final aPower = int.tryParse(a.power ?? '') ?? 0;
          final bPower = int.tryParse(b.power ?? '') ?? 0;
          return sortOptions.ascending
              ? aPower.compareTo(bPower)
              : bPower.compareTo(aPower);
        case 'cardNumber':
        default:
          final aNumber = a.cardNumber ?? '';
          final bNumber = b.cardNumber ?? '';
          return sortOptions.ascending
              ? aNumber.compareTo(bNumber)
              : bNumber.compareTo(aNumber);
      }
    });
    return sortedCards;
  }

  static CardRepositoryException wrapError(
    dynamic error,
    String message, {
    String? code,
    StackTrace? stackTrace,
  }) {
    if (error is CardRepositoryException) {
      return error;
    }
    return CardRepositoryException(
      message,
      code: code ?? 'unknown_error',
      originalError: error,
    );
  }
}
