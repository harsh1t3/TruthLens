// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_result.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScanResultAdapter extends TypeAdapter<ScanResult> {
  @override
  final int typeId = 0;

  @override
  ScanResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScanResult(
      id: fields[0] as String,
      imagePath: fields[1] as String,
      trustScore: fields[2] as double,
      spectralScore: fields[3] as double,
      metadataScore: fields[4] as double,
      compressionScore: fields[5] as double,
      aiSignalScore: fields[6] as double,
      findings: (fields[7] as List).cast<String>(),
      scannedAt: fields[8] as DateTime,
      verdict: fields[9] as String,
      heatmapPath: fields[10] as String?,
      aiGenerator: fields[11] as String?,
      c2paPresent: fields[12] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ScanResult obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.imagePath)
      ..writeByte(2)
      ..write(obj.trustScore)
      ..writeByte(3)
      ..write(obj.spectralScore)
      ..writeByte(4)
      ..write(obj.metadataScore)
      ..writeByte(5)
      ..write(obj.compressionScore)
      ..writeByte(6)
      ..write(obj.aiSignalScore)
      ..writeByte(7)
      ..write(obj.findings)
      ..writeByte(8)
      ..write(obj.scannedAt)
      ..writeByte(9)
      ..write(obj.verdict)
      ..writeByte(10)
      ..write(obj.heatmapPath)
      ..writeByte(11)
      ..write(obj.aiGenerator)
      ..writeByte(12)
      ..write(obj.c2paPresent);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
