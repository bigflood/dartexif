import 'exif_types.dart';
import 'read_exif.dart';

Future<String> printExifOfBytes(List<int> bytes,
    {String? stop_tag = null,
    bool details = true,
    bool strict = false,
    bool debug = false}) async {
  // Map<String, IfdTag> data = await readExifFromBytes(await new File(path).readAsBytes(),
  //     stop_tag: stop_tag, details: true, strict: false, debug: false);

  Map<String?, IfdTag>? data = await readExifFromBytes(bytes,
      stop_tag: stop_tag, details: true, strict: false, debug: false);

  if (data == null || data.isEmpty) {
    return "No EXIF information found";
  }

  var prints = [];

  if (data.containsKey('JPEGThumbnail')) {
    prints.add('File has JPEG thumbnail');
    data.remove('JPEGThumbnail');
  }
  if (data.containsKey('TIFFThumbnail')) {
    prints.add('File has TIFF thumbnail');
    data.remove('TIFFThumbnail');
  }

  List<String?> tag_keys = data.keys.toList();
  tag_keys.sort();

  for (String? key in tag_keys) {
    // try {
    prints.add("$key (${data[key]!.tagType}): ${data[key]}");
    // } catch (e) {
    //   printFunc("$i : ${data[i]}");
    // }
  }

  return prints.join("\n");
}
