// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'draft_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DraftModelAdapter extends TypeAdapter<DraftModel> {
  @override
  final int typeId = 0;

  @override
  DraftModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DraftModel(
      formId: fields[0] as String,
      answers: (fields[1] as Map).cast<String, dynamic>(),
      images: (fields[2] as Map).cast<String, String>(),
      timestamp: fields[3] as DateTime,
      title: fields[5] as String,
      status: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DraftModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.formId)
      ..writeByte(1)
      ..write(obj.answers)
      ..writeByte(2)
      ..write(obj.images)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.title);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DraftModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
