// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_extended_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CardExtendedDataAdapter extends TypeAdapter<CardExtendedData> {
  @override
  final int typeId = 2;

  @override
  CardExtendedData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CardExtendedData(
      displayName: fields[0] as String,
      name: fields[1] as String,
      value: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, CardExtendedData obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.displayName)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.value);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardExtendedDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
