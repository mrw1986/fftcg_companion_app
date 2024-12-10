// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_image_metadata.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CardImageMetadataAdapter extends TypeAdapter<CardImageMetadata> {
  @override
  final int typeId = 3;

  @override
  CardImageMetadata read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CardImageMetadata(
      contentType: fields[0] as String,
      hash: fields[1] as String,
      highResSize: fields[2] as int,
      lowResSize: fields[3] as int,
      originalSize: fields[4] as int,
      size: fields[5] as int,
      updated: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CardImageMetadata obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.contentType)
      ..writeByte(1)
      ..write(obj.hash)
      ..writeByte(2)
      ..write(obj.highResSize)
      ..writeByte(3)
      ..write(obj.lowResSize)
      ..writeByte(4)
      ..write(obj.originalSize)
      ..writeByte(5)
      ..write(obj.size)
      ..writeByte(6)
      ..write(obj.updated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardImageMetadataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
