import 'tags_info.dart' show MakerTag, MakerTagFunc, tags_base;
import 'util.dart';

// Makernote (proprietary) tag definitions for FujiFilm.
// http://www.sno.phy.queensu.ca/~phil/exiftool/TagNames/FujiFilm.html

class makernote_fujifilm extends tags_base {
  static Map<int, MakerTag> TAGS = _build_tags();

  static MakerTag _make(String name) => MakerTag.make(name);
  static MakerTag _withMap(String name, Map<int, String> map) =>
      MakerTag.makeWithMap(name, map);
  static MakerTag _withFunc(String name, MakerTagFunc func) =>
      MakerTag.makeWithFunc(name, func);

  static Map<int, MakerTag> _build_tags() {
    return {
      0x0000: _withFunc('NoteVersion', make_string),
      0x0010: _make('InternalSerialNumber'),
      0x1000: _make('Quality'),
      0x1001: _withMap('Sharpness', {
        0x1: 'Soft',
        0x2: 'Soft',
        0x3: 'Normal',
        0x4: 'Hard',
        0x5: 'Hard2',
        0x82: 'Medium Soft',
        0x84: 'Medium Hard',
        0x8000: 'Film Simulation'
      }),
      0x1002: _withMap('WhiteBalance', {
        0x0: 'Auto',
        0x100: 'Daylight',
        0x200: 'Cloudy',
        0x300: 'Daylight Fluorescent',
        0x301: 'Day White Fluorescent',
        0x302: 'White Fluorescent',
        0x303: 'Warm White Fluorescent',
        0x304: 'Living Room Warm White Fluorescent',
        0x400: 'Incandescent',
        0x500: 'Flash',
        0x600: 'Underwater',
        0xf00: 'Custom',
        0xf01: 'Custom2',
        0xf02: 'Custom3',
        0xf03: 'Custom4',
        0xf04: 'Custom5',
        0xff0: 'Kelvin'
      }),
      0x1003: _withMap('Saturation', {
        0x0: 'Normal',
        0x80: 'Medium High',
        0x100: 'High',
        0x180: 'Medium Low',
        0x200: 'Low',
        0x300: 'None (B&W)',
        0x301: 'B&W Red Filter',
        0x302: 'B&W Yellow Filter',
        0x303: 'B&W Green Filter',
        0x310: 'B&W Sepia',
        0x400: 'Low 2',
        0x8000: 'Film Simulation'
      }),
      0x1004: _withMap('Contrast', {
        0x0: 'Normal',
        0x80: 'Medium High',
        0x100: 'High',
        0x180: 'Medium Low',
        0x200: 'Low',
        0x8000: 'Film Simulation'
      }),
      0x1005: _make('ColorTemperature'),
      0x1006:
          _withMap('Contrast', {0x0: 'Normal', 0x100: 'High', 0x300: 'Low'}),
      0x100a: _make('WhiteBalanceFineTune'),
      0x1010: _withMap(
          'FlashMode', {0: 'Auto', 1: 'On', 2: 'Off', 3: 'Red Eye Reduction'}),
      0x1011: _make('FlashStrength'),
      0x1020: _withMap('Macro', {0: 'Off', 1: 'On'}),
      0x1021: _withMap('FocusMode', {0: 'Auto', 1: 'Manual'}),
      0x1022: _withMap('AFPointSet', {0: 'Yes', 1: 'No'}),
      0x1023: _make('FocusPixel'),
      0x1030: _withMap('SlowSync', {0: 'Off', 1: 'On'}),
      0x1031: _withMap('PictureMode', {
        0: 'Auto',
        1: 'Portrait',
        2: 'Landscape',
        4: 'Sports',
        5: 'Night',
        6: 'Program AE',
        256: 'Aperture Priority AE',
        512: 'Shutter Priority AE',
        768: 'Manual Exposure'
      }),
      0x1032: _make('ExposureCount'),
      0x1100: _withMap('MotorOrBracket', {0: 'Off', 1: 'On'}),
      0x1210: _withMap(
          'ColorMode', {0x0: 'Standard', 0x10: 'Chrome', 0x30: 'B & W'}),
      0x1300: _withMap('BlurWarning', {0: 'Off', 1: 'On'}),
      0x1301: _withMap('FocusWarning', {0: 'Off', 1: 'On'}),
      0x1302: _withMap('ExposureWarning', {0: 'Off', 1: 'On'}),
    };
  }
}
