import 'dart:async';

import 'file_interface_generic.dart'
    if (dart.library.html) "file_interface_html.dart"
    if (dart.library.io) 'file_interface_io.dart';

abstract class FileReader {
  static Future<FileReader> fromFile(dynamic file) async {
    return createFileReaderFromFile(file);
  }

  factory FileReader.fromBytes(List<int>? bytes) {
    return new _BytesReader(bytes);
  }

  int readByteSync();
  List<int> readSync(int bytes);
  int positionSync();
  setPositionSync(int position);
}

class _BytesReader implements FileReader {
  List<int>? bytes;
  int readPos = 0;

  _BytesReader(List<int>? bytes) {
    this.bytes = bytes;
  }

  @override
  int positionSync() {
    return readPos;
  }

  @override
  int readByteSync() {
    return bytes![readPos++];
  }

  @override
  List<int> readSync(int n) {
    var start = readPos;
    var end = readPos + n;
    if (end > bytes!.length) {
      end = bytes!.length;
    }
    var r = bytes!.sublist(start, end);
    readPos += end - start;
    return r;
  }

  @override
  setPositionSync(int position) {
    readPos = position;
  }
}
