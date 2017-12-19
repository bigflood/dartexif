import 'dart:io';

abstract class FileReader {
  int readByteSync();
  List<int> readSync(int bytes);
  int positionSync();
  setPositionSync(int position);

  factory FileReader.fromFile(RandomAccessFile f) {
    return new _RandomAccessFileReader(f);
  }

  factory FileReader.fromBytes(List<int> bytes) {
    return new _BytesReader(bytes);
  }
}

class _RandomAccessFileReader implements FileReader {
  RandomAccessFile file;

  _RandomAccessFileReader(RandomAccessFile file) {
    this.file = file;
  }  

  @override
  int positionSync() {
    return file.positionSync();
  }

  @override
  List<int> readSync(int bytes) {
    return file.readSync(bytes);
  }

  @override
  int readByteSync() {
    return file.readByteSync();
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
    var r = bytes.sublist(readPos, readPos + n);
    readPos += n;
    return r;
  }

  @override
  setPositionSync(int position) {
    readPos = position;
  }
}
