import 'package:cloud_firestore/cloud_firestore.dart';
import 'card_image_metadata.dart';
import 'card_extended_data.dart';

class FFTCGCard {
  final int categoryId;
  final String cleanName;
  final List<CardExtendedData> extendedData;
  final String groupHash;
  final int groupId;
  final String highResUrl;
  final int imageCount;
  final CardImageMetadata imageMetadata;
  final DateTime lastUpdated;
  final String lowResUrl;
  final String? modifiedOn;
  final String name;
  final String originalUrl;
  final bool isPresale;
  final int productId;
  final String url;

  // Convenience getters for common card properties
  String? get cardNumber => _getExtendedValue('Number');
  String? get description => _getExtendedValue('Description');
  String? get cardType => _getExtendedValue('CardType');
  List<String> get elements => _getExtendedValue('Element')?.split(',') ?? [];
  String? get cost => _getExtendedValue('Cost');
  String? get power => _getExtendedValue('Power');
  String? get job => _getExtendedValue('Job');
  String? get category => _getExtendedValue('Category');
  String? get rarity => _getExtendedValue('Rarity');

  const FFTCGCard({
    required this.categoryId,
    required this.cleanName,
    required this.extendedData,
    required this.groupHash,
    required this.groupId,
    required this.highResUrl,
    required this.imageCount,
    required this.imageMetadata,
    required this.lastUpdated,
    required this.lowResUrl,
    required this.name,
    required this.originalUrl,
    required this.isPresale,
    required this.productId,
    required this.url,
    this.modifiedOn,
  });

  String? _getExtendedValue(String name) {
    return extendedData
        .firstWhere(
          (data) => data.name == name,
          orElse: () => const CardExtendedData(
            displayName: '',
            name: '',
            value: '',
          ),
        )
        .value;
  }

  factory FFTCGCard.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FFTCGCard(
      categoryId: data['categoryId'] as int,
      cleanName: data['cleanName'] as String,
      extendedData: (data['extendedData'] as List<dynamic>)
          .map((e) => CardExtendedData.fromMap(e as Map<String, dynamic>))
          .toList(),
      groupHash: data['groupHash'] as String,
      groupId: data['groupId'] as int,
      highResUrl: data['highResUrl'] as String,
      imageCount: data['imageCount'] as int,
      imageMetadata: CardImageMetadata.fromMap(
        data['imageMetadata'] as Map<String, dynamic>,
      ),
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
      lowResUrl: data['lowResUrl'] as String,
      modifiedOn: data['modifiedOn'] as String?,
      name: data['name'] as String,
      originalUrl: data['originalUrl'] as String,
      isPresale:
          (data['presaleInfo'] as Map<String, dynamic>)['isPresale'] as bool,
      productId: data['productId'] as int,
      url: data['url'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'cleanName': cleanName,
      'extendedData': extendedData.map((e) => e.toMap()).toList(),
      'groupHash': groupHash,
      'groupId': groupId,
      'highResUrl': highResUrl,
      'imageCount': imageCount,
      'imageMetadata': imageMetadata.toMap(),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'lowResUrl': lowResUrl,
      'modifiedOn': modifiedOn,
      'name': name,
      'originalUrl': originalUrl,
      'presaleInfo': {
        'isPresale': isPresale,
        'note': null,
        'releasedOn': null,
      },
      'productId': productId,
      'url': url,
    };
  }
}
