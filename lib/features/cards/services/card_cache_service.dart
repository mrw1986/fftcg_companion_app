import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
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
            maxNrOfCacheObjects: 1000, // Increased from 500
            repo: JsonCacheInfoRepository(databaseName: key),
            fileSystem: IOFileSystem(key),
            fileService: HttpFileService(),
          ),
        );

  static Future<void> initialize() async {
    final directory = await getTemporaryDirectory();
    await directory.create(recursive: true);

    // Don't clear cache on initialization
    // await _instance.emptyCache();
  }
}

class CardCacheService {
  final SharedPreferences prefs;
  final TalkerService _talker;
  final CacheManager _cacheManager;
  final _storage = FirebaseStorage.instance;

  static const String filterOptionsKey = 'card_filter_options';
  static const String recentCardsKey = 'recent_cards';
  static const int maxRecentCards = 50;

  CardCacheService({
    required this.prefs,
    TalkerService? talker,
    CacheManager? cacheManager,
  })  : _talker = talker ?? TalkerService(),
        _cacheManager = cacheManager ?? CardCacheManager();

  Future<String> _getImageUrl(String url) async {
    try {
      if (!url.contains('firebasestorage')) return url;

      // Extract the path from the URL
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      // Get the path after 'card-images/'
      final cardImagesIndex = pathSegments.indexOf('card-images');
      if (cardImagesIndex == -1 || cardImagesIndex + 1 >= pathSegments.length) {
        return url;
      }

      final storagePath = pathSegments.sublist(cardImagesIndex).join('/');

      // Get download URL using the path
      final ref = _storage.ref(storagePath);
      final downloadUrl = await ref.getDownloadURL();
      _talker.debug('Generated download URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      _talker.severe('Error getting image URL: $e');
      return url;
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

  Future<void> preCacheCard(FFTCGCard card) async {
    const maxRetries = 3;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        final lowResUrl = await _getImageUrl(card.effectiveLowResUrl);
        final highResUrl = await _getImageUrl(card.effectiveHighResUrl);

        await Future.wait([
          _cacheManager.getSingleFile(lowResUrl),
          _cacheManager.getSingleFile(highResUrl),
        ]);

        _talker.info('Pre-cached images for card: ${card.cardNumber}');
        break;
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          _talker.warning(
            'Failed to pre-cache card after $maxRetries attempts: $e',
          );
        } else {
          await Future.delayed(Duration(seconds: retryCount));
        }
      }
    }
  }

  Future<void> preCacheCards(List<FFTCGCard> cards) async {
    try {
      _talker.info('Pre-caching images for ${cards.length} cards');

      // Process in larger batches
      const batchSize = 10; // Increased from 5
      for (var i = 0; i < cards.length; i += batchSize) {
        final end =
            (i + batchSize < cards.length) ? i + batchSize : cards.length;
        final batch = cards.sublist(i, end);

        await Future.wait(
          batch.map((card) async {
            try {
              // Always cache low-res version
              final lowResUrl = await _getImageUrl(card.effectiveLowResUrl);
              await _cacheManager.getSingleFile(
                lowResUrl,
                // Remove options parameter as it's not supported in the base package
              );

              // Cache high-res only for visible cards
              if (cards.indexOf(card) < 15) {
                final highResUrl = await _getImageUrl(card.effectiveHighResUrl);
                await _cacheManager.getSingleFile(
                  highResUrl,
                  // Remove options parameter as it's not supported in the base package
                );
              }
            } catch (e) {
              _talker.warning('Error pre-caching card ${card.cardNumber}: $e');
            }
          }),
        );

        // Shorter delay between batches
        if (end < cards.length) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      _talker.info('Pre-cached images for ${cards.length} cards');
    } catch (e) {
      _talker.warning('Error pre-caching cards: $e');
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
