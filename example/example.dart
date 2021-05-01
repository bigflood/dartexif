import 'dart:io';

import 'package:exif/exif.dart';

Future main(List<String> arguments) async {
  for (final filename in arguments) {
    print("read $filename ..");

    final fileBytes = File(filename).readAsBytesSync();
    final data = await readExifFromBytes(fileBytes);

    if (data == null || data.isEmpty) {
      return "No EXIF information found";
    }

    if (data.containsKey('JPEGThumbnail')) {
      print('File has JPEG thumbnail');
      data.remove('JPEGThumbnail');
    }
    if (data.containsKey('TIFFThumbnail')) {
      print('File has TIFF thumbnail');
      data.remove('TIFFThumbnail');
    }

    for (final entry in data.entries) {
      print("${entry.key}: ${entry.value}");
    }
  }
}
