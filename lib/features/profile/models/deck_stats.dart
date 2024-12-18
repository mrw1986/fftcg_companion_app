import 'package:freezed_annotation/freezed_annotation.dart';

part 'deck_stats.freezed.dart';
part 'deck_stats.g.dart';

@freezed
class DeckStats with _$DeckStats {
  const factory DeckStats({
    required String deckId,
    required String name,
    required Map<String, int> elementCount,
    required DateTime created,
    DateTime? lastModified,
  }) = _DeckStats;

  factory DeckStats.fromJson(Map<String, dynamic> json) =>
      _$DeckStatsFromJson(json);
}
