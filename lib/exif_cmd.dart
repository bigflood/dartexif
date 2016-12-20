import 'dart:io';
import 'exif.dart';

printExifOf(String path, printFunc(String),
    {String stop_tag = null, bool details = true, bool strict = false, bool debug = false}) async {

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

  for (String key in tag_keys) {
    // try {
      printFunc("$key (${data[key].tagType}): ${data[key]}");
    // } catch (e) {
    //   printFunc("$i : ${data[i]}");
    // }
  }
}
