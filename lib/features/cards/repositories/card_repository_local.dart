import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/logging/logger_service.dart';
import '../../../core/services/hive_service.dart';
import '../models/fftcg_card.dart';
import 'models/repository_models.dart';
import 'base_card_repository.dart';

class CardRepositoryLocal {
  final HiveService _hiveService;
  final LoggerService _logger;
  final StreamController<List<FFTCGCard>> _localCardsController;

  Box<FFTCGCard>? _cardsBox;
  bool _isInitialized = false;

  CardRepositoryLocal({
    HiveService? hiveService,
    LoggerService? logger,
  })  : _hiveService = hiveService ?? HiveService(),
        _logger = logger ?? LoggerService(),
        _localCardsController = StreamController<List<FFTCGCard>>.broadcast();

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (!_hiveService.isInitialized) {
        await _hiveService.initialize();
      }

      _cardsBox = _hiveService.getCardsBox();
      _isInitialized = true;

      // Initial load of cards
      _localCardsController.add(_cardsBox?.values.toList() ?? []);

      // Listen for box changes using ValueListenable
      if (_cardsBox != null) {
        _cardsBox!.listenable().addListener(() {
          if (!_localCardsController.isClosed) {
            _localCardsController.add(_cardsBox?.values.toList() ?? []);
          }
        });
      }

      _logger.info('Local repository initialized successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize local repository', e, stackTrace);
      throw CardRepositoryException(
        'Failed to initialize local storage',
        code: 'local_init_failed',
        originalError: e,
      );
    }
  }

  Future<FFTCGCard?> getCard(String cardNumber) async {
    await _ensureInitialized();

    try {
      return _cardsBox?.get(cardNumber);
    } catch (e, stackTrace) {
      _logger.error('Error getting card from local storage', e, stackTrace);
      throw CardRepositoryException(
        'Failed to get card $cardNumber from local storage',
        code: 'local_get_failed',
        originalError: e,
      );
    }
  }

  Future<List<FFTCGCard>> getCards(CardQueryOptions options) async {
    await _ensureInitialized();

    try {
      List<FFTCGCard> cards = _cardsBox?.values.toList() ?? [];

      // Apply filters
      if (options.searchQuery?.isNotEmpty == true) {
        final query = options.searchQuery!.toLowerCase();
        cards = cards.where((card) {
          return card.name.toLowerCase().contains(query) ||
              (card.cardNumber?.toLowerCase().contains(query) ?? false);
        }).toList();
      }

      if (options.cardType != null) {
        cards =
            cards.where((card) => card.cardType == options.cardType).toList();
      }

      if (options.elements?.isNotEmpty ?? false) {
        cards = cards
            .where((card) => options.elements!
                .any((element) => card.elements.contains(element)))
            .toList();
      }

      if (options.cost != null) {
        cards = cards.where((card) => card.cost == options.cost).toList();
      }

      return cards;
    } catch (e, stackTrace) {
      _logger.error('Error getting cards from local storage', e, stackTrace);
      throw CardRepositoryException(
        'Failed to get cards from local storage',
        code: 'local_get_failed',
        originalError: e,
      );
    }
  }

  Stream<List<FFTCGCard>> watchCards(CardQueryOptions options) {
    return _localCardsController.stream.map((cards) {
      // Apply the same filtering logic as getCards
      List<FFTCGCard> filteredCards = cards;

      if (options.searchQuery?.isNotEmpty == true) {
        final query = options.searchQuery!.toLowerCase();
        filteredCards = filteredCards.where((card) {
          return card.name.toLowerCase().contains(query) ||
              (card.cardNumber?.toLowerCase().contains(query) ?? false);
        }).toList();
      }

      if (options.cardType != null) {
        filteredCards = filteredCards
            .where((card) => card.cardType == options.cardType)
            .toList();
      }

      if (options.elements?.isNotEmpty ?? false) {
        filteredCards = filteredCards
            .where((card) => options.elements!
                .any((element) => card.elements.contains(element)))
            .toList();
      }

      if (options.cost != null) {
        filteredCards =
            filteredCards.where((card) => card.cost == options.cost).toList();
      }

      return filteredCards;
    });
  }

  Future<List<FFTCGCard>> searchCards(String query) async {
    await _ensureInitialized();

    try {
      final cards = _cardsBox?.values.where((card) {
            final searchQuery = query.toLowerCase();
            return card.name.toLowerCase().contains(searchQuery) ||
                (card.cardNumber?.toLowerCase().contains(searchQuery) ?? false);
          }).toList() ??
          [];

      return cards;
    } catch (e, stackTrace) {
      _logger.error('Error searching cards in local storage', e, stackTrace);
      throw CardRepositoryException(
        'Failed to search cards in local storage',
        code: 'local_search_failed',
        originalError: e,
      );
    }
  }

  Future<BatchOperationResult> saveBatch(List<FFTCGCard> cards) async {
    await _ensureInitialized();

    final processedIds = <String>[];
    final failedIds = <String>[];

    try {
      // Process in smaller batches to prevent memory issues
      for (var i = 0;
          i < cards.length;
          i += BaseCardRepository.defaultBatchSize) {
        final end = (i + BaseCardRepository.defaultBatchSize < cards.length)
            ? i + BaseCardRepository.defaultBatchSize
            : cards.length;
        final batch = cards.sublist(i, end);

        for (final card in batch) {
          try {
            if (card.cardNumber == null) {
              failedIds.add('unknown_$i');
              continue;
            }

            await _cardsBox?.put(card.cardNumber, card);
            processedIds.add(card.cardNumber!);
          } catch (e) {
            failedIds.add(card.cardNumber ?? 'unknown_$i');
            _logger.error('Error saving card ${card.cardNumber}', e);
          }
        }
      }

      _logger.info('Batch save completed: ${processedIds.length} cards saved, '
          '${failedIds.length} failed');

      return BatchOperationResult(
        success: failedIds.isEmpty,
        processedIds: processedIds,
        failedIds: failedIds,
      );
    } catch (e, stackTrace) {
      _logger.error('Error saving batch to local storage', e, stackTrace);
      throw CardRepositoryException(
        'Failed to save batch to local storage',
        code: 'local_save_failed',
        originalError: e,
      );
    }
  }

  Future<void> deleteCard(String cardNumber) async {
    await _ensureInitialized();

    try {
      await _cardsBox?.delete(cardNumber);
      _logger.info('Card deleted from local storage: $cardNumber');
    } catch (e, stackTrace) {
      _logger.error('Error deleting card from local storage', e, stackTrace);
      throw CardRepositoryException(
        'Failed to delete card from local storage',
        code: 'local_delete_failed',
        originalError: e,
      );
    }
  }

  Future<List<String>> getUniqueElements() async {
    await _ensureInitialized();

    try {
      return _cardsBox?.values
              .expand((card) => card.elements)
              .where((element) => element.isNotEmpty)
              .toSet()
              .toList() ??
          [];
    } catch (e, stackTrace) {
      _logger.error(
          'Error getting unique elements from local storage', e, stackTrace);
      throw CardRepositoryException(
        'Failed to get unique elements from local storage',
        code: 'local_get_failed',
        originalError: e,
      );
    }
  }

  Future<List<String>> getUniqueCardTypes() async {
    await _ensureInitialized();

    try {
      return _cardsBox?.values
              .map((card) => card.cardType)
              .where((type) => type != null && type.isNotEmpty)
              .toSet()
              .cast<String>()
              .toList() ??
          [];
    } catch (e, stackTrace) {
      _logger.error(
          'Error getting unique card types from local storage', e, stackTrace);
      throw CardRepositoryException(
        'Failed to get unique card types from local storage',
        code: 'local_get_failed',
        originalError: e,
      );
    }
  }

  Future<void> clearAll() async {
    await _ensureInitialized();

    try {
      await _cardsBox?.clear();
      _logger.info('Local storage cleared');
    } catch (e, stackTrace) {
      _logger.error('Error clearing local storage', e, stackTrace);
      throw CardRepositoryException(
        'Failed to clear local storage',
        code: 'local_clear_failed',
        originalError: e,
      );
    }
  }

  Future<int> getCardCount() async {
    await _ensureInitialized();
    return _cardsBox?.length ?? 0;
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  Future<void> compact() async {
    await _ensureInitialized();
    try {
      await _cardsBox?.compact();
      _logger.info('Local storage compacted');
    } catch (e, stackTrace) {
      _logger.error('Error compacting local storage', e, stackTrace);
      throw CardRepositoryException(
        'Failed to compact local storage',
        code: 'local_compact_failed',
        originalError: e,
      );
    }
  }

  Future<bool> isCacheValid() async {
    await _ensureInitialized();
    try {
      if (!_isInitialized) return false;

      // Get the shared preferences instance
      final prefs = await SharedPreferences.getInstance();
      final lastCacheTime = prefs.getInt(BaseCardRepository.lastCacheTimeKey);

      if (lastCacheTime == null) return false;

      final lastCacheDateTime =
          DateTime.fromMillisecondsSinceEpoch(lastCacheTime);
      return DateTime.now().difference(lastCacheDateTime) <
          BaseCardRepository.defaultCacheExpiration;
    } catch (e, stackTrace) {
      _logger.error('Error checking cache validity', e, stackTrace);
      return false;
    }
  }

  Future<void> saveCard(FFTCGCard card) async {
    await _ensureInitialized();
    try {
      if (card.cardNumber == null) {
        throw CardRepositoryException(
          'Cannot save card without card number',
          code: 'invalid_card_data',
        );
      }
      await _cardsBox?.put(card.cardNumber, card);
      _logger.info('Card saved successfully: ${card.cardNumber}');
    } catch (e, stackTrace) {
      _logger.error('Error saving card to local storage', e, stackTrace);
      throw CardRepositoryException(
        'Failed to save card to local storage',
        code: 'local_save_failed',
        originalError: e,
      );
    }
  }

  void dispose() {
    _localCardsController.close();
    _cardsBox?.close();
    _isInitialized = false;
  }
}
