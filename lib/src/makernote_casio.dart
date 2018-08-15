import 'tags_info.dart' show MakerTag, tags_base;

// Makernote (proprietary) tag definitions for casio.

class makernote_casio extends tags_base {
  static Map<int, MakerTag> TAGS = _build_tags();

  static MakerTag _make(String name) => MakerTag.make(name);
  static MakerTag _withMap(String name, Map<int, String> map) =>
      MakerTag.makeWithMap(name, map);

  static Map<int, MakerTag> _build_tags() {
    return {
      0x0001: _withMap('RecordingMode', {
        1: 'Single Shutter',
        2: 'Panorama',
        3: 'Night Scene',
        4: 'Portrait',
        5: 'Landscape',
      }),
      0x0002: _withMap('Quality', {1: 'Economy', 2: 'Normal', 3: 'Fine'}),
      0x0003: _withMap('FocusingMode',
          {2: 'Macro', 3: 'Auto Focus', 4: 'Manual Focus', 5: 'Infinity'}),
      0x0004: _withMap('FlashMode', {
        1: 'Auto',
        2: 'On',
        3: 'Off',
        4: 'Red Eye Reduction',
      }),
      0x0005:
          _withMap('FlashIntensity', {11: 'Weak', 13: 'Normal', 15: 'Strong'}),
      0x0006: _make('Object Distance'),
      0x0007: _withMap('WhiteBalance', {
        1: 'Auto',
        2: 'Tungsten',
        3: 'Daylight',
        4: 'Fluorescent',
        5: 'Shade',
        129: 'Manual'
      }),
      0x000B: _withMap('Sharpness', {
        0: 'Normal',
        1: 'Soft',
        2: 'Hard',
      }),
      0x000C: _withMap('Contrast', {
        0: 'Normal',
        1: 'Low',
        2: 'High',
      }),
      0x000D: _withMap('Saturation', {
        0: 'Normal',
        1: 'Low',
        2: 'High',
      }),
      0x0014: _withMap('CCDSpeed', {
        64: 'Normal',
        80: 'Normal',
        100: 'High',
        125: '+1.0',
        244: '+3.0',
        250: '+2.0'
      }),
    };
  }
}
