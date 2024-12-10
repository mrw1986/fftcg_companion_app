import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/logging/logger_service.dart';
import '../../../core/services/hive_service.dart';
import '../models/fftcg_card.dart';
import '../../../core/models/sync_status.dart';

class CardRepository {
  final FirebaseFirestore _firestore;
  final HiveService _hiveService;
  final LoggerService _logger;
  static const String _collectionName = 'cards';

  CardRepository({
    FirebaseFirestore? firestore,
    HiveService? hiveService,
    LoggerService? logger,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _hiveService = hiveService ?? HiveService(),
        _logger = logger ?? LoggerService();

  Stream<List<FFTCGCard>> watchCards({
    String? searchQuery,
    List<String>? elements,
    String? cardType,
    String? cost,
  }) async* {
    try {
      // First, yield local data
      yield _getLocalCards(
        searchQuery: searchQuery,
        elements: elements,
        cardType: cardType,
        cost: cost,
      );

      // Then, start watching Firestore if online
      Query query = _firestore.collection(_collectionName);

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query
            .where('cleanName',
                isGreaterThanOrEqualTo: searchQuery.toLowerCase())
            .where('cleanName', isLessThan: '${searchQuery.toLowerCase()}z');
      }

      if (cardType != null) {
        query = query.where('extendedData', arrayContains: {
          'name': 'CardType',
          'value': cardType,
        });
      }

      await for (final snapshot in query.snapshots()) {
        final cards = snapshot.docs.map((doc) {
          final card = FFTCGCard.fromFirestore(doc);
          // Preserve sync status of existing local cards
          final existingCard = _hiveService.getCard(card.cardNumber ?? '');
          if (existingCard != null) {
            return card.copyWith(
              syncStatus: existingCard.syncStatus,
              lastModifiedLocally: existingCard.lastModifiedLocally,
            );
          }
          return card;
        }).toList();

        // Filter by elements if specified
        final filteredCards = elements?.isNotEmpty == true
            ? cards.where(
                (card) => elements!.any(
                  (element) => card.elements.contains(element),
                ),
              )
            : cards;

        // Save to local storage
        await _saveCardsLocally(filteredCards.toList());

        yield filteredCards.toList();
      }
    } catch (e, stackTrace) {
      _logger.error('Error watching cards', e, stackTrace);

      // On error, return local data
      yield _getLocalCards(
        searchQuery: searchQuery,
        elements: elements,
        cardType: cardType,
        cost: cost,
      );
    }
  }

  Future<FFTCGCard?> getCardByNumber(String cardNumber) async {
    try {
      // First check local storage
      final localCard = _hiveService.getCard(cardNumber);
      if (localCard != null) {
        return localCard;
      }

      // If not found locally, check Firestore
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('extendedData', arrayContains: {
            'name': 'Number',
            'value': cardNumber,
          })
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        _logger.warning('Card not found: $cardNumber');
        return null;
      }

      final card = FFTCGCard.fromFirestore(querySnapshot.docs.first);
      await _hiveService.saveCard(card);
      return card;
    } catch (e, stackTrace) {
      _logger.error('Error getting card by number', e, stackTrace);
      rethrow;
    }
  }

  Future<List<FFTCGCard>> searchCards(String query) async {
    try {
      // First search locally
      final localCards = _getLocalCards(searchQuery: query);
      if (localCards.isNotEmpty) {
        return localCards;
      }

      // If no local results, search Firestore
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('cleanName', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('cleanName', isLessThan: '${query.toLowerCase()}z')
          .limit(20)
          .get();

      final cards = querySnapshot.docs
          .map((doc) => FFTCGCard.fromFirestore(doc))
          .toList();

      // Save search results locally
      await _saveCardsLocally(cards);

      return cards;
    } catch (e, stackTrace) {
      _logger.error('Error searching cards', e, stackTrace);
      // Return local results on error
      return _getLocalCards(searchQuery: query);
    }
  }

  Future<List<String>> getUniqueElements() async {
    try {
      // First check local storage
      final localCards = _hiveService.getAllCards();
      if (localCards.isNotEmpty) {
        return localCards.expand((card) => card.elements).toSet().toList();
      }

      // If no local data, fetch from Firestore
      final querySnapshot = await _firestore.collection(_collectionName).get();
      final elements = querySnapshot.docs
          .map((doc) => FFTCGCard.fromFirestore(doc))
          .expand((card) => card.elements)
          .toSet()
          .toList();

      _logger.info('Found ${elements.length} unique elements');
      return elements;
    } catch (e, stackTrace) {
      _logger.error('Error getting unique elements', e, stackTrace);
      rethrow;
    }
  }

  Future<List<String>> getUniqueCardTypes() async {
    try {
      // First check local storage
      final localCards = _hiveService.getAllCards();
      if (localCards.isNotEmpty) {
        return localCards
            .map((card) => card.cardType)
            .where((type) => type != null)
            .toSet()
            .cast<String>()
            .toList();
      }

      // If no local data, fetch from Firestore
      final querySnapshot = await _firestore.collection(_collectionName).get();
      final cardTypes = querySnapshot.docs
          .map((doc) => FFTCGCard.fromFirestore(doc))
          .map((card) => card.cardType)
          .where((type) => type != null)
          .toSet()
          .cast<String>()
          .toList();

      _logger.info('Found ${cardTypes.length} unique card types');
      return cardTypes;
    } catch (e, stackTrace) {
      _logger.error('Error getting unique card types', e, stackTrace);
      rethrow;
    }
  }

  Future<List<FFTCGCard>> getAllCards() async {
    try {
      // First check local storage
      final localCards = _hiveService.getAllCards();
      if (localCards.isNotEmpty) {
        return localCards;
      }

      // If no local data, fetch from Firestore
      final querySnapshot = await _firestore.collection(_collectionName).get();
      final cards = querySnapshot.docs
          .map((doc) => FFTCGCard.fromFirestore(doc))
          .toList();

      // Save to local storage
      await _saveCardsLocally(cards);

      return cards;
    } catch (e, stackTrace) {
      _logger.error('Error getting all cards', e, stackTrace);
      rethrow;
    }
  }

  List<FFTCGCard> _getLocalCards({
    String? searchQuery,
    List<String>? elements,
    String? cardType,
    String? cost,
  }) {
    try {
      var cards = _hiveService.getAllCards();

      // Apply filters
      if (searchQuery?.isNotEmpty == true) {
        cards = cards
            .where((card) =>
                card.name.toLowerCase().contains(searchQuery!.toLowerCase()))
            .toList();
      }

      if (elements?.isNotEmpty == true) {
        cards = cards
            .where((card) =>
                elements!.any((element) => card.elements.contains(element)))
            .toList();
      }

      if (cardType != null) {
        cards = cards.where((card) => card.cardType == cardType).toList();
      }

      if (cost != null) {
        cards = cards.where((card) => card.cost == cost).toList();
      }

      return cards;
    } catch (e, stackTrace) {
      _logger.error('Error getting local cards', e, stackTrace);
      return [];
    }
  }

  Future<void> _saveCardsLocally(List<FFTCGCard> cards) async {
    try {
      await _hiveService.saveCards(cards);
      _logger.info('Saved ${cards.length} cards locally');
    } catch (e, stackTrace) {
      _logger.error('Error saving cards locally', e, stackTrace);
    }
  }

  Future<void> saveCardLocally(FFTCGCard card) async {
    try {
      await _hiveService.saveCard(card);
      _logger.info('Card saved locally: ${card.cardNumber}');
    } catch (e, stackTrace) {
      _logger.error('Error saving card locally', e, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteCardLocally(String cardNumber) async {
    try {
      await _hiveService.deleteCard(cardNumber);
      _logger.info('Card deleted locally: $cardNumber');
    } catch (e, stackTrace) {
      _logger.error('Error deleting card locally', e, stackTrace);
      rethrow;
    }
  }

  Future<void> markCardForSync(String cardNumber) async {
    try {
      final card = _hiveService.getCard(cardNumber);
      if (card != null) {
        card.markForSync();
        await _hiveService.saveCard(card);
        _logger.info('Card marked for sync: $cardNumber');
      }
    } catch (e, stackTrace) {
      _logger.error('Error marking card for sync', e, stackTrace);
      rethrow;
    }
  }

  Future<void> syncUserData(String userId) async {
    try {
      _logger.info('Starting user data sync for ID: $userId');

      // Get all locally modified cards
      final localCards = _hiveService
          .getAllCards()
          .where((card) => card.syncStatus == SyncStatus.pending)
          .toList();

      if (localCards.isEmpty) {
        _logger.info('No local changes to sync');
        return;
      }

      // Upload to Firestore
      final batch = _firestore.batch();
      for (final card in localCards) {
        final docRef =
            _firestore.collection(_collectionName).doc(card.cardNumber);
        batch.set(docRef, card.toMap(), SetOptions(merge: true));
      }

      await batch.commit();

      // Mark all synced cards
      for (final card in localCards) {
        card.markSynced();
        await _hiveService.saveCard(card);
      }

      _logger.info('Successfully synced ${localCards.length} cards');
    } catch (e, stackTrace) {
      _logger.error('Error syncing user data', e, stackTrace);
      rethrow;
    }
  }

  Future<void> clearLocalData() async {
    try {
      await _hiveService.clearAll();
      _logger.info('Local data cleared successfully');
    } catch (e, stackTrace) {
      _logger.error('Error clearing local data', e, stackTrace);
      rethrow;
    }
  }
}
