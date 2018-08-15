import 'tags_info.dart' show MakerTag, tags_base;

// Makernote (proprietary) tag definitions for Apple iOS
// Based on version 1.01 of ExifTool -> Image/ExifTool/Apple.pm
// http://owl.phy.queensu.ca/~phil/exiftool/

class makernote_apple extends tags_base {
  static Map<int, MakerTag> TAGS = _build_tags();

  //static MakerTag _make(String name) => MakerTag.make(name);
  static MakerTag _withMap(String name, Map<int, String> map) =>
      MakerTag.makeWithMap(name, map);

  static Map<int, MakerTag> _build_tags() {
    return {
      0x000a: _withMap('HDRImageType', {
        3: 'HDR Image',
        4: 'Original Image',
      }),
    };
  }
}
