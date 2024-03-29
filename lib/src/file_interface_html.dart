import 'dart:async';
import 'dart:html' as dart_html;
import 'dart:typed_data';

import 'package:exif/src/file_interface.dart';

Future<FileReader> createFileReaderFromFile(dynamic file) async {
  if (file is dart_html.File) {
    final fileReader = dart_html.FileReader();
    fileReader.readAsArrayBuffer(file);
    await fileReader.onLoad.first;
    final data = fileReader.result;
    if (data is Uint8List) {
      return FileReader.fromBytes(data);
    }
  } else if (file is List<int>) {
    return FileReader.fromBytes(file);
  }
  throw UnsupportedError("Can't read file of type: ${file.runtimeType}");
}
