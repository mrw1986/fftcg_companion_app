import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'card_image_metadata.g.dart';

@HiveType(typeId: 3)
class CardImageMetadata {
  @HiveField(0)
  final String contentType;

  @HiveField(1)
  final String hash;

  @HiveField(2)
  final int highResSize;

  @HiveField(3)
  final int lowResSize;

  @HiveField(4)
  final int originalSize;

  @HiveField(5)
  final int size;

  @HiveField(6)
  final DateTime updated;

  const CardImageMetadata({
    required this.contentType,
    required this.hash,
    required this.highResSize,
    required this.lowResSize,
    required this.originalSize,
    required this.size,
    required this.updated,
  });

  factory CardImageMetadata.fromMap(Map<String, dynamic> map) {
    return CardImageMetadata(
      contentType: map['contentType'] as String? ?? '',
      hash: map['hash'] as String? ?? '',
      highResSize: map['highResSize'] as int? ?? 0,
      lowResSize: map['lowResSize'] as int? ?? 0,
      originalSize: map['originalSize'] as int? ?? 0,
      size: map['size'] as int? ?? 0,
      updated: (map['updated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'contentType': contentType,
      'hash': hash,
      'highResSize': highResSize,
      'lowResSize': lowResSize,
      'originalSize': originalSize,
      'size': size,
      'updated': Timestamp.fromDate(updated),
    };
  }

  CardImageMetadata copyWith({
    String? contentType,
    String? hash,
    int? highResSize,
    int? lowResSize,
    int? originalSize,
    int? size,
    DateTime? updated,
  }) {
    return CardImageMetadata(
      contentType: contentType ?? this.contentType,
      hash: hash ?? this.hash,
      highResSize: highResSize ?? this.highResSize,
      lowResSize: lowResSize ?? this.lowResSize,
      originalSize: originalSize ?? this.originalSize,
      size: size ?? this.size,
      updated: updated ?? this.updated,
    );
  }

  @override
  String toString() {
    return 'CardImageMetadata(contentType: $contentType, hash: $hash, highResSize: $highResSize, lowResSize: $lowResSize, originalSize: $originalSize, size: $size, updated: $updated)';
  }
}
