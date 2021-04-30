// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sample_file.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SampleFile _$SampleFileFromJson(Map<String, dynamic> json) {
  return SampleFile(
    name: json['name'] as String?,
    dump: json['dump'] as String?,
  )..encodedContent = json['encodedContent'] as String?;
}

Map<String, dynamic> _$SampleFileToJson(SampleFile instance) =>
    <String, dynamic>{
      'name': instance.name,
      'encodedContent': instance.encodedContent,
      'dump': instance.dump,
    };
