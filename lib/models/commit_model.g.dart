// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commit_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CommitModelAdapter extends TypeAdapter<CommitModel> {
  @override
  final int typeId = 1;

  @override
  CommitModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CommitModel(
      formId: fields[0] as String,
      answers: (fields[1] as Map).cast<String, dynamic>(),
      images: (fields[2] as Map).cast<String, String>(),
      timestamp: fields[3] as DateTime,
      title: fields[5] as String,
      status: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, CommitModel obj) {
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
      other is CommitModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
