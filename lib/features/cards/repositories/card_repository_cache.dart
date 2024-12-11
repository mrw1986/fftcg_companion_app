import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/logging/logger_service.dart';
import '../models/fftcg_card.dart';
import 'models/repository_models.dart';
import 'base_card_repository.dart';

class CardRepositoryCache {
  final LoggerService _logger;
  final Map<String, FFTCGCard> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Map<String, Completer<FFTCGCard?>> _pendingRequests = {};

  static const int _maxMemoryCacheSize = 1000;
  static const Duration _defaultCacheExpiration = Duration(hours: 24);

  CardRepositoryCache({
    LoggerService? logger,
  }) : _logger = logger ?? LoggerService();

  Future<FFTCGCard?> getFromCache(String cardNumber) async {
    try {
      // Check memory cache first
      if (_memoryCache.containsKey(cardNumber)) {
        final cacheTime = _cacheTimestamps[cardNumber];
        if (cacheTime != null &&
            DateTime.now().difference(cacheTime) < _defaultCacheExpiration) {
          _logger.info('Cache hit for card: $cardNumber');
          return _memoryCache[cardNumber];
        } else {
          // Cache expired
          _memoryCache.remove(cardNumber);
          _cacheTimestamps.remove(cardNumber);
        }
      }

      return null;
    } catch (e, stackTrace) {
      _logger.error('Error retrieving from cache', e, stackTrace);
      return null;
    }
  }

  Future<void> addToCache(FFTCGCard card) async {
    try {
      if (card.cardNumber == null) return;

      // Implement LRU cache eviction if needed
      if (_memoryCache.length >= _maxMemoryCacheSize) {
        _evictOldestEntry();
      }

      _memoryCache[card.cardNumber!] = card;
      _cacheTimestamps[card.cardNumber!] = DateTime.now();
      _logger.info('Added to cache: ${card.cardNumber}');
    } catch (e, stackTrace) {
      _logger.error('Error adding to cache', e, stackTrace);
    }
  }

  Future<void> addAllToCache(List<FFTCGCard> cards) async {
    for (final card in cards) {
      await addToCache(card);
    }
  }

  Future<void> removeFromCache(String cardNumber) async {
    _memoryCache.remove(cardNumber);
    _cacheTimestamps.remove(cardNumber);
    _logger.info('Removed from cache: $cardNumber');
  }

  Future<void> clearCache() async {
    _memoryCache.clear();
    _cacheTimestamps.clear();
    _pendingRequests.clear();
    _logger.info('Cache cleared');
  }

  Future<bool> isCacheValid() async {
    try {
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

  Future<void> updateCacheTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final success = await prefs.setInt(
        BaseCardRepository.lastCacheTimeKey,
        timestamp,
      );

      if (!success) {
        throw CardRepositoryException(
          'Failed to update cache timestamp',
          code: 'cache-update-failed',
        );
      }

      _logger.info('Cache timestamp updated successfully');
    } catch (e, stackTrace) {
      _logger.error('Error updating cache timestamp', e, stackTrace);
      throw CardRepositoryException(
        'Failed to update cache timestamp',
        code: 'cache-update-failed',
        originalError: e,
      );
    }
  }

  Future<FFTCGCard?> getWithLoader(
    String cardNumber,
    Future<FFTCGCard?> Function() loader,
  ) async {
    // Check if there's already a pending request for this card
    if (_pendingRequests.containsKey(cardNumber)) {
      return _pendingRequests[cardNumber]!.future;
    }

    // Check cache first
    final cachedCard = await getFromCache(cardNumber);
    if (cachedCard != null) return cachedCard;

    // Create a new completer for this request
    final completer = Completer<FFTCGCard?>();
    _pendingRequests[cardNumber] = completer;

    try {
      // Load the card
      final card = await loader();

      if (card != null) {
        await addToCache(card);
      }

      completer.complete(card);
      return card;
    } catch (e, stackTrace) {
      _logger.error('Error loading card', e, stackTrace);
      completer.completeError(e, stackTrace);
      rethrow;
    } finally {
      _pendingRequests.remove(cardNumber);
    }
  }

  void _evictOldestEntry() {
    if (_cacheTimestamps.isEmpty) return;

    final oldestEntry = _cacheTimestamps.entries
        .reduce((a, b) => a.value.isBefore(b.value) ? a : b);

    _memoryCache.remove(oldestEntry.key);
    _cacheTimestamps.remove(oldestEntry.key);
    _logger.info('Evicted from cache: ${oldestEntry.key}');
  }

  bool hasValidCacheEntry(String cardNumber) {
    return _memoryCache.containsKey(cardNumber) &&
        _cacheTimestamps.containsKey(cardNumber) &&
        DateTime.now().difference(_cacheTimestamps[cardNumber]!) <
            _defaultCacheExpiration;
  }

  int get cacheSize => _memoryCache.length;
  bool get isEmpty => _memoryCache.isEmpty;
  bool get isNotEmpty => _memoryCache.isNotEmpty;

  Set<String> get cachedCardNumbers => _memoryCache.keys.toSet();

  void dispose() {
    clearCache();
  }
}
