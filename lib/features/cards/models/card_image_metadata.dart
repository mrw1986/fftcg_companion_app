import 'package:cloud_firestore/cloud_firestore.dart';

class CardImageMetadata {
  final String contentType;
  final String hash;
  final int highResSize;
  final int lowResSize;
  final int originalSize;
  final int size;
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
      contentType: map['contentType'] as String,
      hash: map['hash'] as String,
      highResSize: map['highResSize'] as int,
      lowResSize: map['lowResSize'] as int,
      originalSize: map['originalSize'] as int,
      size: map['size'] as int,
      updated: (map['updated'] as Timestamp).toDate(),
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
}
