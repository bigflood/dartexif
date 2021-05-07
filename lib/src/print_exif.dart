import 'read_exif.dart';

Future<String> printExifOfBytes(List<int> bytes,
    // ignore: non_constant_identifier_names
    {String? stop_tag,
    bool details = true,
    bool strict = false,
    bool debug = false}) async {
  final data = await readExifFromBytes(bytes, stop_tag: stop_tag);

  if (data == null || data.isEmpty) {
    return "No EXIF information found";
  }

  final prints = [];

  if (data.containsKey('JPEGThumbnail')) {
    prints.add('File has JPEG thumbnail');
    data.remove('JPEGThumbnail');
  }
  if (data.containsKey('TIFFThumbnail')) {
    prints.add('File has TIFF thumbnail');
    data.remove('TIFFThumbnail');
  }

  final List<String?> tagKeys = data.keys.toList();
  tagKeys.sort();

  for (final key in tagKeys) {
    prints.add("$key (${data[key]!.tagType}): ${data[key]}");
  }

  return prints.join("\n");
}
