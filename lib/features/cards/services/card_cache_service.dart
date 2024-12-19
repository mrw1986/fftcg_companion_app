import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/logging/logger_service.dart';
import '../models/card_filter_options.dart';
import '../models/fftcg_card.dart';

class CardCacheService {
  final SharedPreferences prefs;
  final LoggerService logger;

  static const String filterOptionsKey = 'card_filter_options';
  static const String recentCardsKey = 'recent_cards';
  static const int maxRecentCards = 50;

  CardCacheService({
    required this.prefs,
    LoggerService? logger,
  }) : logger = logger ?? LoggerService();

  Future<void> saveFilterOptions(CardFilterOptions options) async {
    try {
      await prefs.setString(filterOptionsKey, jsonEncode(options.toJson()));
      logger.info('Filter options saved to cache');
    } catch (e, stackTrace) {
      logger.severe('Error saving filter options', e, stackTrace);
    }
  }

  CardFilterOptions? getFilterOptions() {
    try {
      final String? data = prefs.getString(filterOptionsKey);
      if (data == null) return null;
      return CardFilterOptions.fromJson(jsonDecode(data));
    } catch (e, stackTrace) {
      logger.severe('Error loading filter options', e, stackTrace);
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
        logger.info('Added card to recent cards: $cardNumber');
      }
    } catch (e, stackTrace) {
      logger.severe('Error adding recent card', e, stackTrace);
    }
  }

  List<String> getRecentCards() {
    try {
      return prefs.getStringList(recentCardsKey) ?? [];
    } catch (e, stackTrace) {
      logger.severe('Error getting recent cards', e, stackTrace);
      return [];
    }
  }

  Future<void> clearRecentCards() async {
    try {
      await prefs.remove(recentCardsKey);
      logger.info('Recent cards cleared');
    } catch (e, stackTrace) {
      logger.severe('Error clearing recent cards', e, stackTrace);
    }
  }
}
