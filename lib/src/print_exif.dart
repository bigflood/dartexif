import 'package:exif/src/file_interface.dart';
import 'package:exif/src/read_exif.dart';

Future<String> printExifOfBytes(List<int> bytes,
    {String? stopTag,
    bool details = true,
    bool strict = false,
    bool debug = false}) async {
  final data =
      readExifFromFileReader(FileReader.fromBytes(bytes), stopTag: stopTag);

  if (data.tags.isEmpty) {
    return "No EXIF information found";
  }

  final prints = [];

  // prints.addAll(data.warnings);

  if (data.tags.containsKey('JPEGThumbnail')) {
    prints.add('File has JPEG thumbnail');
    data.tags.remove('JPEGThumbnail');
  }
  if (data.tags.containsKey('TIFFThumbnail')) {
    prints.add('File has TIFF thumbnail');
    data.tags.remove('TIFFThumbnail');
  }

  final tagKeys = data.tags.keys.toList();
  tagKeys.sort();

  for (final key in tagKeys) {
    final tag = data.tags[key];
    prints.add("$key (${tag!.tagType}): $tag");
  }

  return prints.join("\n");
}
