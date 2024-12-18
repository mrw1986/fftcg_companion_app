import 'package:freezed_annotation/freezed_annotation.dart';

part 'collection_stats.freezed.dart';
part 'collection_stats.g.dart';

@freezed
class CollectionStats with _$CollectionStats {
  const factory CollectionStats({
    required String cardNumber,
    required bool isFoil,
    required double value,
    DateTime? acquired,
  }) = _CollectionStats;

  factory CollectionStats.fromJson(Map<String, dynamic> json) =>
      _$CollectionStatsFromJson(json);
}
