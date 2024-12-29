import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager_firebase/flutter_cache_manager_firebase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/logging/talker_service.dart';
import '../models/card_filter_options.dart';
import '../models/fftcg_card.dart';

class CardCacheManager extends CacheManager {
  static const key = 'card_cache';
  static final CardCacheManager _instance = CardCacheManager._();
  factory CardCacheManager() => _instance;

  CardCacheManager._()
      : super(
          Config(
            key,
            stalePeriod: const Duration(days: 30),
            maxNrOfCacheObjects: 500,
            repo: JsonCacheInfoRepository(databaseName: key),
            fileService: FirebaseHttpFileService(),
            fileSystem: IOFileSystem(key),
          ),
        );

  Future<void> initialize() async {
    await emptyCache();
  }
}

class CardCacheService {
  final SharedPreferences prefs;
  final TalkerService _talker;
  final _cacheManager = CardCacheManager();
  final _storage = FirebaseStorage.instance;

  static const String filterOptionsKey = 'card_filter_options';
  static const String recentCardsKey = 'recent_cards';
  static const int maxRecentCards = 50;

  CardCacheService({
    required this.prefs,
    TalkerService? talker,
  }) : _talker = talker ?? TalkerService();

  Future<String> _getDownloadUrl(String url) async {
    try {
      if (!url.contains('firebasestorage')) return url;
      final ref = _storage.refFromURL(url);
      return await ref.getDownloadURL();
    } catch (e) {
      _talker.severe('Error getting download URL: $e');
      rethrow;
    }
  }

  Future<void> saveFilterOptions(CardFilterOptions options) async {
    try {
      await prefs.setString(filterOptionsKey, jsonEncode(options.toJson()));
      _talker.info('Filter options saved to cache');
    } catch (e) {
      _talker.severe('Error saving filter options: $e');
    }
  }

  CardFilterOptions? getFilterOptions() {
    try {
      final String? data = prefs.getString(filterOptionsKey);
      if (data == null) return null;
      return CardFilterOptions.fromJson(jsonDecode(data));
    } catch (e) {
      _talker.severe('Error loading filter options: $e');
      return null;
    }
  }

  Future<void> addRecentCard(FFTCGCard card) async {
    try {
      final List<String> recentCards =
          prefs.getStringList(recentCardsKey) ?? [];
      final String cardNumber = card.cardNumber ?? '';

      if (cardNumber.isNotEmpty) {
        recentCards.remove(cardNumber);
        recentCards.insert(0, cardNumber);

        if (recentCards.length > maxRecentCards) {
          recentCards.removeLast();
        }

        await prefs.setStringList(recentCardsKey, recentCards);
        _talker.info('Added card to recent cards: $cardNumber');
      }
    } catch (e) {
      _talker.severe('Error adding recent card: $e');
    }
  }

  List<String> getRecentCards() {
    try {
      return prefs.getStringList(recentCardsKey) ?? [];
    } catch (e) {
      _talker.severe('Error getting recent cards: $e');
      return [];
    }
  }

  Future<void> clearRecentCards() async {
    try {
      await prefs.remove(recentCardsKey);
      _talker.info('Recent cards cleared');
    } catch (e) {
      _talker.severe('Error clearing recent cards: $e');
    }
  }

  Future<void> clearImageCache() async {
    try {
      await _cacheManager.emptyCache();
      _talker.info('Image cache cleared');
    } catch (e) {
      _talker.severe('Error clearing image cache: $e');
    }
  }

  Future<void> removeFromCache(String url) async {
    try {
      final file = await _cacheManager.getFileFromCache(url);
      if (file != null) {
        await _cacheManager.removeFile(url);
        _talker.info('Removed from cache: $url');
      }
    } catch (e) {
      _talker.severe('Error removing file from cache: $e');
    }
  }

  Future<bool> isInCache(String url) async {
    try {
      final fileInfo = await _cacheManager.getFileFromCache(url);
      return fileInfo != null;
    } catch (e) {
      _talker.severe('Error checking cache for file: $e');
      return false;
    }
  }

  Future<void> preCacheCards(List<FFTCGCard> cards) async {
    try {
      final futures = cards.map((card) async {
        try {
          final lowResUrl = await _getDownloadUrl(card.lowResUrl);
          await _cacheManager.downloadFile(lowResUrl);

          if (cards.indexOf(card) < 5) {
            final highResUrl = await _getDownloadUrl(card.highResUrl);
            await _cacheManager.downloadFile(highResUrl);
          }
        } catch (e) {
          _talker.warning('Error pre-caching card ${card.cardNumber}: $e');
        }
      });

      await Future.wait(futures);
      _talker.info('Pre-cached images for ${cards.length} cards');
    } catch (e) {
      _talker.warning('Error pre-caching cards: $e');
    }
  }

  Future<void> preCacheCard(FFTCGCard card) async {
    try {
      final lowResUrl = await _getDownloadUrl(card.lowResUrl);
      final highResUrl = await _getDownloadUrl(card.highResUrl);

      await Future.wait([
        _cacheManager.downloadFile(lowResUrl),
        _cacheManager.downloadFile(highResUrl),
      ]);
      _talker.info('Pre-cached images for card: ${card.cardNumber}');
    } catch (e) {
      _talker.warning('Error pre-caching card: $e');
    }
  }

  CacheManager get imageCacheManager => _cacheManager;

  @override
  String toString() {
    final recentCount = getRecentCards().length;
    final hasFilters = getFilterOptions() != null;
    return 'CardCacheService(recentCards: $recentCount, hasStoredFilters: $hasFilters)';
  }
}
