// lib/features/cards/repositories/card_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/logging/logger_service.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../models/fftcg_card.dart';
import '../../../core/models/sync_status.dart';
import '../../auth/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CardRepository {
  final FirebaseFirestore _firestore;
  final HiveService _hiveService;
  final LoggerService _logger;
  final AuthService _authService;
  final ConnectivityService _connectivityService;

  static const String _collectionName = 'cards';
  static const int _batchSize = 20;
  static const Duration _cacheExpiration = Duration(hours: 24);
  static const String _lastCacheTimeKey = 'last_cache_time';
  static const String _lastPageKey = 'last_fetched_page';

  CardRepository({
    FirebaseFirestore? firestore,
    HiveService? hiveService,
    LoggerService? logger,
    AuthService? authService,
    ConnectivityService? connectivityService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _hiveService = hiveService ?? HiveService(),
        _logger = logger ?? LoggerService(),
        _authService = authService ?? AuthService(),
        _connectivityService = connectivityService ?? ConnectivityService();

  Stream<List<FFTCGCard>> watchCards({
    String? searchQuery,
    List<String>? elements,
    String? cardType,
    String? cost,
  }) async* {
    try {
      // First emit cached data
      final cachedCards = _getFilteredLocalCards(
        searchQuery: searchQuery,
        elements: elements,
        cardType: cardType,
        cost: cost,
      );
      yield cachedCards;

      // Check if we should query Firestore
      final isGuest = await _authService.isGuestSession();
      final isConnected = await _connectivityService.hasStableConnection();
      if (isGuest || !isConnected) {
        _logger.info(
            'Using local data only - Guest: $isGuest, Connected: $isConnected');
        return;
      }

      // Build base query
      Query query = _firestore.collection(_collectionName);

      // Apply filters
      if (searchQuery?.isNotEmpty ?? false) {
        query = query
            .where('cleanName',
                isGreaterThanOrEqualTo: searchQuery!.toLowerCase())
            .where('cleanName', isLessThan: '${searchQuery.toLowerCase()}z');
      }

      if (cardType != null) {
        query = query.where('extendedData', arrayContains: {
          'name': 'CardType',
          'value': cardType,
        });
      }

      // Listen to Firestore updates
      await for (final snapshot in query.snapshots()) {
        try {
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

          // Apply element filters if specified
          final filteredCards = elements?.isNotEmpty == true
              ? cards.where((card) =>
                  elements!.any((element) => card.elements.contains(element)))
              : cards;

          final resultsList = filteredCards.toList();

          // Save to local storage
          await _saveCardsLocally(resultsList);
          await _updateCacheTimestamp();

          yield resultsList;
        } catch (e, stackTrace) {
          _logger.severe('Error processing card snapshot', e, stackTrace);
          yield cachedCards;
        }
      }
    } catch (e, stackTrace) {
      _logger.severe('Error watching cards', e, stackTrace);
      yield _getFilteredLocalCards(
        searchQuery: searchQuery,
        elements: elements,
        cardType: cardType,
        cost: cost,
      );
    }
  }

  Future<List<FFTCGCard>> getCardsPage(int page) async {
    try {
      // Check cache first
      if (await _isCacheValid()) {
        final cachedCards = _getLocalCardsPage(page);
        if (cachedCards.isNotEmpty) {
          _logger.info('Returning cached cards for page $page');
          return cachedCards;
        }
      }

      // Check connectivity
      final isConnected = await _connectivityService.hasStableConnection();
      if (!isConnected) {
        _logger.info('No connection, returning local cards for page $page');
        return _getLocalCardsPage(page);
      }

      final query = page == 0
          ? _firestore
              .collection(_collectionName)
              .orderBy('name')
              .limit(_batchSize)
          : await _getLastDocumentName(page - 1).then((lastDocName) =>
              lastDocName != null
                  ? _firestore
                      .collection(_collectionName)
                      .orderBy('name')
                      .startAfter([lastDocName]).limit(_batchSize)
                  : _firestore
                      .collection(_collectionName)
                      .orderBy('name')
                      .limit(_batchSize));

      final snapshot = await query.get();
      final cards =
          snapshot.docs.map((doc) => FFTCGCard.fromFirestore(doc)).toList();

      await _saveCardsLocally(cards);
      await _updateLastFetchedPage(page);
      await _updateCacheTimestamp();

      _logger.info('Fetched ${cards.length} cards for page $page');
      return cards;
    } catch (e, stackTrace) {
      _logger.severe('Error getting cards page $page', e, stackTrace);
      return _getLocalCardsPage(page);
    }
  }

  List<FFTCGCard> _getLocalCardsPage(int page) {
    try {
      final allCards = _hiveService.getAllCards();
      final start = page * _batchSize;
      final end = start + _batchSize;

      if (start >= allCards.length) return [];

      return allCards.sublist(
          start, end > allCards.length ? allCards.length : end);
    } catch (e, stackTrace) {
      _logger.severe('Error getting local cards page', e, stackTrace);
      return [];
    }
  }

  List<FFTCGCard> _getFilteredLocalCards({
    String? searchQuery,
    List<String>? elements,
    String? cardType,
    String? cost,
  }) {
    try {
      var cards = _hiveService.getAllCards();

      if (searchQuery?.isNotEmpty ?? false) {
        cards = cards
            .where((card) =>
                card.name.toLowerCase().contains(searchQuery!.toLowerCase()) ||
                (card.cardNumber
                        ?.toLowerCase()
                        .contains(searchQuery.toLowerCase()) ??
                    false))
            .toList();
      }

      if (elements?.isNotEmpty ?? false) {
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
      _logger.severe('Error getting filtered local cards', e, stackTrace);
      return [];
    }
  }

  Future<void> _saveCardsLocally(List<FFTCGCard> cards) async {
    try {
      await _hiveService.saveCards(cards);
      _logger.info('Saved ${cards.length} cards locally');
    } catch (e, stackTrace) {
      _logger.severe('Error saving cards locally', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _updateCacheTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _lastCacheTimeKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e, stackTrace) {
      _logger.severe('Error updating cache timestamp', e, stackTrace);
    }
  }

  Future<void> _updateLastFetchedPage(int page) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastPageKey, page);
    } catch (e, stackTrace) {
      _logger.severe('Error updating last fetched page', e, stackTrace);
    }
  }

  Future<bool> _isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCacheTime = prefs.getInt(_lastCacheTimeKey);

      if (lastCacheTime == null) return false;

      final lastCacheDateTime =
          DateTime.fromMillisecondsSinceEpoch(lastCacheTime);
      return DateTime.now().difference(lastCacheDateTime) < _cacheExpiration;
    } catch (e, stackTrace) {
      _logger.severe('Error checking cache validity', e, stackTrace);
      return false;
    }
  }

  // Keep existing methods...
  Future<FFTCGCard?> getCardByNumber(String cardNumber) async {
    try {
      final localCard = _hiveService.getCard(cardNumber);
      if (localCard != null) {
        return localCard;
      }

      final isGuest = await _authService.isGuestSession();
      final isConnected = await _connectivityService.hasStableConnection();
      if (isGuest || !isConnected) {
        _logger.info('Using local data only for card lookup');
        return null;
      }

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
      _logger.severe('Error getting card by number', e, stackTrace);
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

      // Check if we should query Firestore
      final isGuest = await _authService.isGuestSession();
      final isConnected = await _connectivityService.hasStableConnection();
      if (isGuest || !isConnected) {
        _logger.info('Using local data only for search');
        return localCards;
      }

      // Query Firestore with retry logic
      final querySnapshot = await _retryOperation(() => _firestore
          .collection(_collectionName)
          .where('cleanName', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('cleanName', isLessThan: '${query.toLowerCase()}z')
          .limit(20)
          .get());

      final cards = querySnapshot.docs
          .map((doc) => FFTCGCard.fromFirestore(doc))
          .toList();

      // Cache search results
      await _saveCardsLocally(cards);

      return cards;
    } catch (e, stackTrace) {
      _logger.severe('Error searching cards', e, stackTrace);
      // Return local results on error
      return _getLocalCards(searchQuery: query);
    }
  }

  Future<List<String>> getUniqueElements() async {
    try {
      // First check local storage
      final localCards = _hiveService.getAllCards();
      if (localCards.isNotEmpty) {
        return localCards
            .expand((card) => card.elements)
            .toSet()
            .toList()
          ..sort();
      }

      // Check if we should query Firestore
      final isGuest = await _authService.isGuestSession();
      final isConnected = await _connectivityService.hasStableConnection();
      if (isGuest || !isConnected) {
        _logger.info('Using local data only for element lookup');
        return [];
      }

      final querySnapshot = await _retryOperation(
        () => _firestore.collection(_collectionName).get(),
      );

      final elements = querySnapshot.docs
          .map((doc) => FFTCGCard.fromFirestore(doc))
          .expand((card) => card.elements)
          .toSet()
          .toList()
        ..sort();

      _logger.info('Found ${elements.length} unique elements');
      return elements;
    } catch (e, stackTrace) {
      _logger.severe('Error getting unique elements', e, stackTrace);
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
            .toList()
          ..sort();
      }

      // Check if we should query Firestore
      final isGuest = await _authService.isGuestSession();
      final isConnected = await _connectivityService.hasStableConnection();
      if (isGuest || !isConnected) {
        _logger.info('Using local data only for card type lookup');
        return [];
      }

      final querySnapshot = await _retryOperation(
        () => _firestore.collection(_collectionName).get(),
      );

      final cardTypes = querySnapshot.docs
          .map((doc) => FFTCGCard.fromFirestore(doc))
          .map((card) => card.cardType)
          .where((type) => type != null)
          .toSet()
          .cast<String>()
          .toList()
        ..sort();

      _logger.info('Found ${cardTypes.length} unique card types');
      return cardTypes;
    } catch (e, stackTrace) {
      _logger.severe('Error getting unique card types', e, stackTrace);
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

      // Check if we should query Firestore
      final isGuest = await _authService.isGuestSession();
      final isConnected = await _connectivityService.hasStableConnection();
      if (isGuest || !isConnected) {
        _logger.info('Using local data only for full card list');
        return localCards;
      }

      // Fetch in batches to handle large datasets
      final List<FFTCGCard> allCards = [];
      DocumentSnapshot? lastDocument;
      bool hasMoreData = true;

      while (hasMoreData) {
        Query query = _firestore
            .collection(_collectionName)
            .orderBy(FieldPath.documentId)
            .limit(_batchSize);

        if (lastDocument != null) {
          query = query.startAfterDocument(lastDocument);
        }

        final querySnapshot = await _retryOperation(() => query.get());
        
        if (querySnapshot.docs.isEmpty) {
          hasMoreData = false;
          continue;
        }

        final batchCards = querySnapshot.docs
            .map((doc) => FFTCGCard.fromFirestore(doc))
            .toList();

        allCards.addAll(batchCards);
        lastDocument = querySnapshot.docs.last;

        // Save batch to local storage
        await _saveCardsLocally(batchCards);
        
        _logger.info('Fetched batch of ${batchCards.length} cards');
      }

      _logger.info('Retrieved total of ${allCards.length} cards');
      return allCards;
    } catch (e, stackTrace) {
      _logger.severe('Error getting all cards', e, stackTrace);
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
                card.name.toLowerCase().contains(searchQuery!.toLowerCase()) ||
                (card.cardNumber?.toLowerCase().contains(searchQuery.toLowerCase()) ??
                    false))
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
      _logger.severe('Error getting local cards', e, stackTrace);
      return [];
    }
  }  

  Future<void> saveCardLocally(FFTCGCard card) async {
    try {
      await _hiveService.saveCard(card);
      _logger.info('Card saved locally: ${card.cardNumber}');
    } catch (e, stackTrace) {
      _logger.severe('Error saving card locally', e, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteCardLocally(String cardNumber) async {
    try {
      await _hiveService.deleteCard(cardNumber);
      _logger.info('Card deleted locally: $cardNumber');
    } catch (e, stackTrace) {
      _logger.severe('Error deleting card locally', e, stackTrace);
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
      _logger.severe('Error marking card for sync', e, stackTrace);
      rethrow;
    }
  }

  Future<void> syncUserData(String userId) async {
    try {
      _logger.info('Starting user data sync for ID: $userId');

      // Check if we're in guest mode
      final isGuest = await _authService.isGuestSession();
      if (isGuest) {
        _logger.info('Skipping sync for guest user');
        return;
      }

      // Check connectivity
      final isConnected = await _connectivityService.hasStableConnection();
      if (!isConnected) {
        throw Exception('No stable connection available for sync');
      }

      // Get all locally modified cards
      final localCards = _hiveService
          .getAllCards()
          .where((card) => card.syncStatus == SyncStatus.pending)
          .toList();

      if (localCards.isEmpty) {
        _logger.info('No local changes to sync');
        return;
      }

      // Process in batches
      for (var i = 0; i < localCards.length; i += _batchSize) {
        final end = (i + _batchSize < localCards.length)
            ? i + _batchSize
            : localCards.length;
        final batch = _firestore.batch();
        final currentBatch = localCards.sublist(i, end);

        for (final card in currentBatch) {
          final docRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('cards')
              .doc(card.cardNumber);

          batch.set(
            docRef,
            {
              ...card.toMap(),
              'lastModified': FieldValue.serverTimestamp(),
              'syncStatus': 'synced',
            },
            SetOptions(merge: true),
          );
        }

        await _retryOperation(() => batch.commit());

        // Update local sync status
        for (final card in currentBatch) {
          card.markSynced();
          await _hiveService.saveCard(card);
        }

        _logger.info(
            'Synced batch of ${currentBatch.length} cards ($end/${localCards.length})');
      }

      _logger.info('Successfully synced ${localCards.length} cards');
    } catch (e, stackTrace) {
      _logger.severe('Error syncing user data', e, stackTrace);
      rethrow;
    }
  }

  Future<void> clearLocalData() async {
    try {
      await _hiveService.clearAll();
      _logger.info('Local data cleared successfully');
    } catch (e, stackTrace) {
      _logger.severe('Error clearing local data', e, stackTrace);
      rethrow;
    }
  }

  Future<T> _retryOperation<T>(Future<T> Function() operation) async {
    int attempts = 0;
    const maxAttempts = 3;
    const retryDelay = Duration(seconds: 2);

    while (attempts < maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts >= maxAttempts) rethrow;

        // Fixed string interpolation
        _logger.warning(
            'Operation failed, attempt $attempts of $maxAttempts. Retrying in $retryDelay.inSeconds s');
        await Future.delayed(retryDelay);
      }
    }

    throw CardRepositoryException(
      'Operation failed after $maxAttempts attempts',
      code: 'retry-exhausted',
    );
  }

  Future<bool> isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCacheTime = prefs.getInt(_lastCacheTimeKey);

      if (lastCacheTime == null) return false;

      final lastCacheDateTime =
          DateTime.fromMillisecondsSinceEpoch(lastCacheTime);
      return DateTime.now().difference(lastCacheDateTime) < _cacheExpiration;
    } catch (e, stackTrace) {
      _logger.severe('Error checking cache validity', e, stackTrace);
      return false;
    }
  }

  Future<void> updateCacheTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final success = await prefs.setInt(_lastCacheTimeKey, timestamp);
      if (!success) {
        throw CardRepositoryException(
          'Failed to update cache timestamp',
          code: 'cache-update-failed',
        );
      }

      _logger.info('Cache timestamp updated successfully');
    } catch (e, stackTrace) {
      _logger.severe('Error updating cache timestamp', e, stackTrace);
      throw CardRepositoryException(
        'Failed to update cache timestamp',
        code: 'cache-update-failed',
        originalError: e,
      );
    }
  }

  Future<void> initialize() async {
    try {
      await _hiveService.initialize();
      _logger.info('Card repository initialized successfully');
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize card repository', e, stackTrace);
      rethrow;
    }
  }

  Future<String?> _getLastDocumentName(int previousPage) async {
    try {
      final lastPageCards = _getLocalCardsPage(previousPage);
      if (lastPageCards.isEmpty) return null;
      return lastPageCards.last.name;
    } catch (e, stackTrace) {
      _logger.severe('Error getting last document name', e, stackTrace);
      return null;
    }
  }
}

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
