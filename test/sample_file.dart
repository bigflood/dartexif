import 'package:json_annotation/json_annotation.dart';
import 'dart:convert';
part 'sample_file.g.dart';

@JsonSerializable()
class SampleFile {
  String? name;
  String? encodedContent;
  String? hasError;

  List<int> getContent() => base64.decode(encodedContent!);
  setContent(List<int> v) {
    encodedContent = base64.encode(v);
  }

  SampleFile({this.name, this.hasError, List<int>? content}) {
    if (content != null) {
      setContent(content);
    }
  }

  factory SampleFile.fromJson(Map<String, dynamic> json) =>
      _$SampleFileFromJson(json);
  Map<String, dynamic> toJson() => _$SampleFileToJson(this);
}
