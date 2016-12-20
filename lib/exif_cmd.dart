import 'package:dartexif/dartexif.dart';
import 'package:dartexif/exifheader.dart' hide DEFAULT_STOP_TAG;
import 'dart:io';

printExifOf(String path, printFunc(String),
    {stop_tag = null, details = true, strict = false, debug = false}) async {
  stop_tag = stop_tag ?? DEFAULT_STOP_TAG;

  Map<String, IfdTag> data = await readExifFromFile(new File(path),
      stop_tag: stop_tag, details: true, strict: false, debug: false);

  if (data == null || data.isEmpty) {
    printFunc("No EXIF information found\n");
    return;
  }

  if (data.containsKey('JPEGThumbnail')) {
    printFunc('File has JPEG thumbnail');
    data.remove('JPEGThumbnail');
  }
  if (data.containsKey('TIFFThumbnail')) {
    printFunc('File has TIFF thumbnail');
    data.remove('TIFFThumbnail');
  }

  List<String> tag_keys = data.keys.toList();
  tag_keys.sort();

  for (String i in tag_keys) {
    try {
      printFunc(i +
          ' (' +
          FIELD_TYPES[data[i].field_type][2] +
          '): ' +
          data[i].printable);
    } catch (e) {
      printFunc(i + " : " + data[i].toString());
    }
  }
}
