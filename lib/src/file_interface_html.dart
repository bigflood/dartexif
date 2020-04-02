
import 'dart:async';
import 'dart:html' as dart_html ;
import 'dart:typed_data';

import 'file_interface.dart';

Future<FileReader> createFileReaderFromFile(dynamic file) async {
  if (file is dart_html.File) {
    var fileReader = dart_html.FileReader() ;
    fileReader.readAsArrayBuffer(file) ;
    await fileReader.onLoad.first ;
    Uint8List data = fileReader.result ;
    return FileReader.fromBytes(data) ;
  }
  else if (file is List<int>) {
    return FileReader.fromBytes(file) ;
  }
  throw UnsupportedError("Can't read file of type: ${ file.runtimeType }") ;
}
