import 'dart:io';

abstract class FileReader {
  factory FileReader.fromFile(RandomAccessFile file) {
    return _FileReader(file);
  }

  int readByteSync();
  List<int> readSync(int bytes);
  int positionSync();
  setPositionSync(int position);

  factory FileReader.fromBytes(List<int> bytes) {
    return new _BytesReader(bytes);
  }
}

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
  setPositionSync(int position) {
    file.setPositionSync(position);
  }
}

class _BytesReader implements FileReader {
  List<int> bytes;
  int readPos = 0;

  _BytesReader(List<int> bytes) {
    this.bytes = bytes;
  }

  @override
  int positionSync() {
    return readPos;
  }

  @override
  int readByteSync() {
    return bytes[readPos++];
  }

  @override
  List<int> readSync(int n) {
    var start = readPos;
    var end = readPos + n;
    if (end > bytes.length) {
      end = bytes.length;
    }
    var r = bytes.sublist(start, end);
    readPos += end - start;
    return r;
  }

  @override
  setPositionSync(int position) {
    readPos = position;
  }
}
