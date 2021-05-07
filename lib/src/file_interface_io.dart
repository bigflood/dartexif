import 'dart:async';
import 'dart:io';

import 'file_interface.dart';

class _FileReader implements FileReader {
  final RandomAccessFile file;

  _FileReader(this.file);

  @override
  int positionSync() {
    return file.positionSync();
  }

  @override
  int readByteSync() {
    return file.readByteSync();
  }

  @override
  List<int> readSync(int bytes) {
    return file.readSync(bytes).toList(growable: false);
  }

  @override
  void setPositionSync(int position) {
    file.setPositionSync(position);
  }
}

Future<FileReader> createFileReaderFromFile(dynamic file) async {
  if (file is RandomAccessFile) {
    return _FileReader(file);
  } else if (file is File) {
    final data = await file.readAsBytes();
    return FileReader.fromBytes(data);
  } else if (file is List<int>) {
    return FileReader.fromBytes(file);
  }
  throw UnsupportedError("Can't read file of type: ${file.runtimeType}");
}
