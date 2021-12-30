import 'package:exif/src/tags_info.dart' show MakerTag, TagsBase;

// Makernote (proprietary) tag definitions for Apple iOS
// Based on version 1.01 of ExifTool -> Image/ExifTool/Apple.pm
// http://owl.phy.queensu.ca/~phil/exiftool/

class MakerNoteApple extends TagsBase {
  //static MakerTag _make(String name) => MakerTag.make(name);
  static MakerTag _withMap(String name, Map<int, String> map) =>
      MakerTag.makeWithMap(name, map);

  static final tags = {
    0x000a: _withMap('HDRImageType', {
      3: 'HDR Image',
      4: 'Original Image',
    }),
  };
}
