// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fftcg_card.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FFTCGCardAdapter extends TypeAdapter<FFTCGCard> {
  @override
  final int typeId = 1;

  @override
  FFTCGCard read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FFTCGCard(
      categoryId: fields[0] as int,
      cleanName: fields[1] as String,
      extendedData: (fields[2] as List).cast<CardExtendedData>(),
      groupHash: fields[3] as String,
      groupId: fields[4] as int,
      highResUrl: fields[5] as String,
      imageCount: fields[6] as int,
      imageMetadata: fields[7] as CardImageMetadata,
      lastUpdated: fields[8] as DateTime,
      lowResUrl: fields[9] as String,
      name: fields[11] as String,
      originalUrl: fields[12] as String,
      isPresale: fields[13] as bool,
      productId: fields[14] as int,
      url: fields[15] as String,
      modifiedOn: fields[10] as String?,
      syncStatus: fields[16] as SyncStatus,
      lastModifiedLocally: fields[17] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, FFTCGCard obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.categoryId)
      ..writeByte(1)
      ..write(obj.cleanName)
      ..writeByte(2)
      ..write(obj.extendedData)
      ..writeByte(3)
      ..write(obj.groupHash)
      ..writeByte(4)
      ..write(obj.groupId)
      ..writeByte(5)
      ..write(obj.highResUrl)
      ..writeByte(6)
      ..write(obj.imageCount)
      ..writeByte(7)
      ..write(obj.imageMetadata)
      ..writeByte(8)
      ..write(obj.lastUpdated)
      ..writeByte(9)
      ..write(obj.lowResUrl)
      ..writeByte(10)
      ..write(obj.modifiedOn)
      ..writeByte(11)
      ..write(obj.name)
      ..writeByte(12)
      ..write(obj.originalUrl)
      ..writeByte(13)
      ..write(obj.isPresale)
      ..writeByte(14)
      ..write(obj.productId)
      ..writeByte(15)
      ..write(obj.url)
      ..writeByte(16)
      ..write(obj.syncStatus)
      ..writeByte(17)
      ..write(obj.lastModifiedLocally);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FFTCGCardAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
