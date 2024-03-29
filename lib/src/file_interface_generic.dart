import 'dart:async';

import 'package:exif/src/file_interface.dart';

Future<FileReader> createFileReaderFromFile(dynamic file) async {
  if (file is List<int>) {
    return FileReader.fromBytes(file);
  }
  throw UnsupportedError("Can't read file of type: ${file.runtimeType}");
}
