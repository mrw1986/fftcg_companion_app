import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; // Fixed import
import '../../../core/logging/logger_service.dart';
import '../models/card_filter_options.dart';
import '../models/fftcg_card.dart';

class CardCacheService {
  final SharedPreferences _prefs;
  final LoggerService _logger;
  static const String _filterOptionsKey = 'card_filter_options';
  static const String _recentCardsKey = 'recent_cards';
  static const int _maxRecentCards = 50;

  CardCacheService({
    required SharedPreferences prefs,
    LoggerService? logger,
  })  : _prefs = prefs,
        _logger = logger ?? LoggerService();

  Future<void> saveFilterOptions(CardFilterOptions options) async {
    try {
      await _prefs.setString(_filterOptionsKey, jsonEncode(options.toJson()));
      _logger.info('Filter options saved to cache');
    } catch (e, stackTrace) {
      _logger.severe('Error saving filter options', e, stackTrace);
    }
  }

  CardFilterOptions? getFilterOptions() {
    try {
      final String? data = _prefs.getString(_filterOptionsKey);
      if (data == null) return null;
      return CardFilterOptions.fromJson(jsonDecode(data));
    } catch (e, stackTrace) {
      _logger.severe('Error loading filter options', e, stackTrace);
      return null;
    }
  }

  Future<void> addRecentCard(FFTCGCard card) async {
    try {
      final List<String> recentCards =
          _prefs.getStringList(_recentCardsKey) ?? [];
      final String cardNumber = card.cardNumber ?? '';

      if (cardNumber.isNotEmpty) {
        recentCards.remove(cardNumber);
        recentCards.insert(0, cardNumber);

        if (recentCards.length > _maxRecentCards) {
          recentCards.removeLast();
        }

        await _prefs.setStringList(_recentCardsKey, recentCards);
        _logger.info('Added card to recent cards: $cardNumber');
      }
    } catch (e, stackTrace) {
      _logger.severe('Error adding recent card', e, stackTrace);
    }
  }

  List<String> getRecentCards() {
    try {
      return _prefs.getStringList(_recentCardsKey) ?? [];
    } catch (e, stackTrace) {
      _logger.severe('Error getting recent cards', e, stackTrace);
      return [];
    }
  }

  Future<void> clearRecentCards() async {
    try {
      await _prefs.remove(_recentCardsKey);
      _logger.info('Recent cards cleared');
    } catch (e, stackTrace) {
      _logger.severe('Error clearing recent cards', e, stackTrace);
    }
  }
}
