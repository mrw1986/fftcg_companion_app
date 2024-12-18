import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_stats.freezed.dart';
part 'user_stats.g.dart';

@freezed
class UserStats with _$UserStats {
  const factory UserStats({
    @Default(0) int totalCards,
    @Default(0) int foilCards,
    @Default(0) int nonFoilCards,
    @Default(0.0) double totalValue,
    @Default(0) int totalDecks,
    String? mostUsedElement,
    @Default({}) Map<String, int> elementUsageStats,
    DateTime? lastUpdated,
  }) = _UserStats;

  factory UserStats.fromJson(Map<String, dynamic> json) =>
      _$UserStatsFromJson(json);
}
