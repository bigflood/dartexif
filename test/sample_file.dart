import 'dart:convert';
import 'dart:typed_data';

import 'package:json_annotation/json_annotation.dart';

part 'sample_file.g.dart';

@JsonSerializable()
class SampleFile {
  String name;
  String encodedContent = "";
  String? dump;

  List<int> getContent() => base64.decode(encodedContent);

  SampleFile({this.name = "", this.dump = "", Uint8List? content}) {
    if (content != null) {
      encodedContent = base64.encode(content);
    }
  }

  factory SampleFile.fromJson(Map<String, dynamic> json) =>
      _$SampleFileFromJson(json);
  Map<String, dynamic> toJson() => _$SampleFileToJson(this);
}
