import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/logging/talker_service.dart';
import '../models/card_filter_options.dart';
import '../models/fftcg_card.dart';

class CardCacheService {
  final SharedPreferences prefs;
  final TalkerService _talker;

  static const String filterOptionsKey = 'card_filter_options';
  static const String recentCardsKey = 'recent_cards';
  static const int maxRecentCards = 50;

  CardCacheService({
    required this.prefs,
    TalkerService? talker,
  }) : _talker = talker ?? TalkerService();

  Future<void> saveFilterOptions(CardFilterOptions options) async {
    try {
      await prefs.setString(filterOptionsKey, jsonEncode(options.toJson()));
      _talker.info('Filter options saved to cache');
    } catch (e, stackTrace) {
      _talker.severe('Error saving filter options', e, stackTrace);
    }
  }

  CardFilterOptions? getFilterOptions() {
    try {
      final String? data = prefs.getString(filterOptionsKey);
      if (data == null) return null;
      return CardFilterOptions.fromJson(jsonDecode(data));
    } catch (e, stackTrace) {
      _talker.severe('Error loading filter options', e, stackTrace);
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
    } catch (e, stackTrace) {
      _talker.severe('Error adding recent card', e, stackTrace);
    }
  }

  List<String> getRecentCards() {
    try {
      return prefs.getStringList(recentCardsKey) ?? [];
    } catch (e, stackTrace) {
      _talker.severe('Error getting recent cards', e, stackTrace);
      return [];
    }
  }

  Future<void> clearRecentCards() async {
    try {
      await prefs.remove(recentCardsKey);
      _talker.info('Recent cards cleared');
    } catch (e, stackTrace) {
      _talker.severe('Error clearing recent cards', e, stackTrace);
    }
  }

  @override
  String toString() {
    final recentCount = getRecentCards().length;
    final hasFilters = getFilterOptions() != null;
    return 'CardCacheService(recentCards: $recentCount, hasStoredFilters: $hasFilters)';
  }
}
