import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../../../core/models/sync_status.dart';
import 'card_image_metadata.dart';
import 'card_extended_data.dart';

part 'fftcg_card.g.dart';

@HiveType(typeId: 1)
class FFTCGCard extends HiveObject {
  @HiveField(0)
  final int categoryId;

  @HiveField(1)
  final String cleanName;

  @HiveField(2)
  final List<CardExtendedData> extendedData;

  @HiveField(3)
  final String groupHash;

  @HiveField(4)
  final int groupId;

  @HiveField(5)
  final String highResUrl;

  @HiveField(6)
  final int imageCount;

  @HiveField(7)
  final CardImageMetadata imageMetadata;

  @HiveField(8)
  final DateTime lastUpdated;

  @HiveField(9)
  final String lowResUrl;

  @HiveField(10)
  final String? modifiedOn;

  @HiveField(11)
  final String name;

  @HiveField(12)
  final String originalUrl;

  @HiveField(13)
  final bool isPresale;

  @HiveField(14)
  final int productId;

  @HiveField(15)
  final String url;

  // Sync-related fields
  @HiveField(16)
  SyncStatus syncStatus;

  @HiveField(17)
  DateTime? lastModifiedLocally;

  // Convenience getters for common card properties (not stored in Hive directly)
  String? get cardNumber => _getExtendedValue('Number');
  String? get description => _getExtendedValue('Description');
  String? get cardType => _getExtendedValue('CardType');
  List<String> get elements => _getExtendedValue('Element')?.split(',') ?? [];
  String? get cost => _getExtendedValue('Cost');
  String? get power => _getExtendedValue('Power');
  String? get job => _getExtendedValue('Job');
  String? get category => _getExtendedValue('Category');
  String? get rarity => _getExtendedValue('Rarity');

  FFTCGCard({
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
    this.syncStatus = SyncStatus.synced,
    this.lastModifiedLocally,
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

  // Sync-related methods
  void markForSync() {
    syncStatus = SyncStatus.pending;
    lastModifiedLocally = DateTime.now();
    save(); // Hive save method
  }

  void markSynced() {
    syncStatus = SyncStatus.synced;
    lastModifiedLocally = null;
    save();
  }

  void markError() {
    syncStatus = SyncStatus.error;
    save();
  }

  // Create a copy of the card with updated sync status
  FFTCGCard copyWith({
    int? categoryId,
    String? cleanName,
    List<CardExtendedData>? extendedData,
    String? groupHash,
    int? groupId,
    String? highResUrl,
    int? imageCount,
    CardImageMetadata? imageMetadata,
    DateTime? lastUpdated,
    String? lowResUrl,
    String? modifiedOn,
    String? name,
    String? originalUrl,
    bool? isPresale,
    int? productId,
    String? url,
    SyncStatus? syncStatus,
    DateTime? lastModifiedLocally,
  }) {
    return FFTCGCard(
      categoryId: categoryId ?? this.categoryId,
      cleanName: cleanName ?? this.cleanName,
      extendedData: extendedData ?? this.extendedData,
      groupHash: groupHash ?? this.groupHash,
      groupId: groupId ?? this.groupId,
      highResUrl: highResUrl ?? this.highResUrl,
      imageCount: imageCount ?? this.imageCount,
      imageMetadata: imageMetadata ?? this.imageMetadata,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lowResUrl: lowResUrl ?? this.lowResUrl,
      modifiedOn: modifiedOn ?? this.modifiedOn,
      name: name ?? this.name,
      originalUrl: originalUrl ?? this.originalUrl,
      isPresale: isPresale ?? this.isPresale,
      productId: productId ?? this.productId,
      url: url ?? this.url,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModifiedLocally: lastModifiedLocally ?? this.lastModifiedLocally,
    );
  }
}
