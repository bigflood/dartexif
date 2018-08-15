import 'package:sprintf/sprintf.dart' show sprintf;
import 'util.dart';
import 'tags_info.dart' show MakerTag, MakerTagFunc, tags_base;

// Makernote (proprietary) tag definitions for olympus.

class makernote_olympus extends tags_base {
  static Map<int, MakerTag> TAGS = _build_tags();

  static MakerTag _make(String name) => MakerTag.make(name);
  static MakerTag _withMap(String name, Map<int, String> map) =>
      MakerTag.makeWithMap(name, map);
  static MakerTag _withFunc(String name, MakerTagFunc func) =>
      MakerTag.makeWithFunc(name, func);

  // decode Olympus SpecialMode tag in MakerNote
  static String _special_mode(List<int> v) {
    Map<int, String> mode1 = {
      0: 'Normal',
      1: 'Unknown',
      2: 'Fast',
      3: 'Panorama',
    };
    Map<int, String> mode2 = {
      0: 'Non-panoramic',
      1: 'Left to right',
      2: 'Right to left',
      3: 'Bottom to top',
      4: 'Top to bottom',
    };

    if (v == null || v.isEmpty) {
      return '';
    }

    if (v == null ||
        v.length < 3 ||
        (!mode1.containsKey(v[0]) || !mode2.containsKey(v[2]))) {
      return v.toString();
    }

    return sprintf('%s - sequence %d - %s', [mode1[v[0]], v[1], mode2[v[2]]]);
  }

  static Map<int, MakerTag> _build_tags() {
    return {
      // ah HAH! those sneeeeeaky bastids! this is how they get past the fact
      // that a JPEG thumbnail is not allowed in an uncompressed TIFF file
      0x0100: _make('JPEGThumbnail'),
      0x0200: _withFunc('SpecialMode', _special_mode),
      0x0201: _withMap('JPEGQual', {
        1: 'SQ',
        2: 'HQ',
        3: 'SHQ',
      }),
      0x0202: _withMap('Macro', {0: 'Normal', 1: 'Macro', 2: 'SuperMacro'}),
      0x0203: _withMap('BWMode', {0: 'Off', 1: 'On'}),
      0x0204: _make('DigitalZoom'),
      0x0205: _make('FocalPlaneDiagonal'),
      0x0206: _make('LensDistortionParams'),
      0x0207: _make('SoftwareRelease'),
      0x0208: _make('PictureInfo'),
      0x0209: _withFunc('CameraID', make_string), // print as string
      0x0F00: _make('DataDump'),
      0x0300: _make('PreCaptureFrames'),
      0x0404: _make('SerialNumber'),
      0x1000: _make('ShutterSpeedValue'),
      0x1001: _make('ISOValue'),
      0x1002: _make('ApertureValue'),
      0x1003: _make('BrightnessValue'),
      0x1004: _withMap('FlashMode', {2: 'On', 3: 'Off'}),
      0x1005: _withMap('FlashDevice',
          {0: 'None', 1: 'Internal', 4: 'External', 5: 'Internal + External'}),
      0x1006: _make('ExposureCompensation'),
      0x1007: _make('SensorTemperature'),
      0x1008: _make('LensTemperature'),
      0x100b: _withMap('FocusMode', {0: 'Auto', 1: 'Manual'}),
      0x1017: _make('RedBalance'),
      0x1018: _make('BlueBalance'),
      0x101a: _make('SerialNumber'),
      0x1023: _make('FlashExposureComp'),
      0x1026: _withMap('ExternalFlashBounce', {0: 'No', 1: 'Yes'}),
      0x1027: _make('ExternalFlashZoom'),
      0x1028: _make('ExternalFlashMode'),
      0x1029: _withMap('Contrast  int16u', {0: 'High', 1: 'Normal', 2: 'Low'}),
      0x102a: _make('SharpnessFactor'),
      0x102b: _make('ColorControl'),
      0x102c: _make('ValidBits'),
      0x102d: _make('CoringFilter'),
      0x102e: _make('OlympusImageWidth'),
      0x102f: _make('OlympusImageHeight'),
      0x1034: _make('CompressionRatio'),
      0x1035: _withMap('PreviewImageValid', {0: 'No', 1: 'Yes'}),
      0x1036: _make('PreviewImageStart'),
      0x1037: _make('PreviewImageLength'),
      0x1039: _withMap('CCDScanMode', {0: 'Interlaced', 1: 'Progressive'}),
      0x103a: _withMap('NoiseReduction', {0: 'Off', 1: 'On'}),
      0x103b: _make('InfinityLensStep'),
      0x103c: _make('NearLensStep'),

      // TODO - these need extra definitions
      // http://search.cpan.org/src/EXIFTOOL/Image-ExifTool-6.90/html/TagNames/Olympus.html
      0x2010: _make('Equipment'),
      0x2020: _make('CameraSettings'),
      0x2030: _make('RawDevelopment'),
      0x2040: _make('ImageProcessing'),
      0x2050: _make('FocusInfo'),
      0x3000: _make('RawInfo '),
    };
  }
}

/*
  // 0x2020 CameraSettings
  static Map<int,List> TAG_0x2020 = {
      0x0100: ['PreviewImageValid', {
          0: 'No',
          1: 'Yes'
      }],
      0x0101: ['PreviewImageStart', ],
      0x0102: ['PreviewImageLength', ],
      0x0200: ['ExposureMode', {
          1: 'Manual',
          2: 'Program',
          3: 'Aperture-priority AE',
          4: 'Shutter speed priority AE',
          5: 'Program-shift'
      }],
      0x0201: ['AELock', {
          0: 'Off',
          1: 'On'
      }],
      0x0202: ['MeteringMode', {
          2: 'Center Weighted',
          3: 'Spot',
          5: 'ESP',
          261: 'Pattern+AF',
          515: 'Spot+Highlight control',
          1027: 'Spot+Shadow control'
      }],
      0x0300: ['MacroMode', {
          0: 'Off',
          1: 'On'
      }],
      0x0301: ['FocusMode', {
          0: 'Single AF',
          1: 'Sequential shooting AF',
          2: 'Continuous AF',
          3: 'Multi AF',
          10: 'MF'
      }],
      0x0302: ['FocusProcess', {
          0: 'AF Not Used',
          1: 'AF Used'
      }],
      0x0303: ['AFSearch', {
          0: 'Not Ready',
          1: 'Ready'
      }],
      0x0304: ['AFAreas', ],
      0x0401: ['FlashExposureCompensation', ],
      0x0500: ['WhiteBalance2', {
          0: 'Auto',
          16: '7500K (Fine Weather with Shade)',
          17: '6000K (Cloudy)',
          18: '5300K (Fine Weather)',
          20: '3000K (Tungsten light)',
          21: '3600K (Tungsten light-like)',
          33: '6600K (Daylight fluorescent)',
          34: '4500K (Neutral white fluorescent)',
          35: '4000K (Cool white fluorescent)',
          48: '3600K (Tungsten light-like)',
          256: 'Custom WB 1',
          257: 'Custom WB 2',
          258: 'Custom WB 3',
          259: 'Custom WB 4',
          512: 'Custom WB 5400K',
          513: 'Custom WB 2900K',
          514: 'Custom WB 8000K',
      }],
      0x0501: ['WhiteBalanceTemperature', ],
      0x0502: ['WhiteBalanceBracket', ],
      0x0503: ['CustomSaturation', ],  // (3 numbers: 1. CS Value, 2. Min, 3. Max)
      0x0504: ['ModifiedSaturation', {
          0: 'Off',
          1: 'CM1 (Red Enhance)',
          2: 'CM2 (Green Enhance)',
          3: 'CM3 (Blue Enhance)',
          4: 'CM4 (Skin Tones)',
      }],
      0x0505: ['ContrastSetting', ],  // (3 numbers: 1. Contrast, 2. Min, 3. Max)
      0x0506: ['SharpnessSetting', ],  // (3 numbers: 1. Sharpness, 2. Min, 3. Max)
      0x0507: ['ColorSpace', {
          0: 'sRGB',
          1: 'Adobe RGB',
          2: 'Pro Photo RGB'
      }],
      0x0509: ['SceneMode', {
          0: 'Standard',
          6: 'Auto',
          7: 'Sport',
          8: 'Portrait',
          9: 'Landscape+Portrait',
          10: 'Landscape',
          11: 'Night scene',
          13: 'Panorama',
          16: 'Landscape+Portrait',
          17: 'Night+Portrait',
          19: 'Fireworks',
          20: 'Sunset',
          22: 'Macro',
          25: 'Documents',
          26: 'Museum',
          28: 'Beach&Snow',
          30: 'Candle',
          35: 'Underwater Wide1',
          36: 'Underwater Macro',
          39: 'High Key',
          40: 'Digital Image Stabilization',
          44: 'Underwater Wide2',
          45: 'Low Key',
          46: 'Children',
          48: 'Nature Macro',
      }],
      0x050a: ['NoiseReduction', {
          0: 'Off',
          1: 'Noise Reduction',
          2: 'Noise Filter',
          3: 'Noise Reduction + Noise Filter',
          4: 'Noise Filter (ISO Boost)',
          5: 'Noise Reduction + Noise Filter (ISO Boost)'
      }],
      0x050b: ['DistortionCorrection', {
          0: 'Off',
          1: 'On'
      }],
      0x050c: ['ShadingCompensation', {
          0: 'Off',
          1: 'On'
      }],
      0x050d: ['CompressionFactor', ],
      0x050f: ['Gradation', {
          '-1 -1 1': 'Low Key',
          '0 -1 1': 'Normal',
          '1 -1 1': 'High Key'
      }],
      0x0520: ['PictureMode', {
          1: 'Vivid',
          2: 'Natural',
          3: 'Muted',
          256: 'Monotone',
          512: 'Sepia'
      }],
      0x0521: ['PictureModeSaturation', ],
      0x0522: ['PictureModeHue?', ],
      0x0523: ['PictureModeContrast', ],
      0x0524: ['PictureModeSharpness', ],
      0x0525: ['PictureModeBWFilter', {
          0: 'n/a',
          1: 'Neutral',
          2: 'Yellow',
          3: 'Orange',
          4: 'Red',
          5: 'Green'
      }],
      0x0526: ['PictureModeTone', {
          0: 'n/a',
          1: 'Neutral',
          2: 'Sepia',
          3: 'Blue',
          4: 'Purple',
          5: 'Green'
      }],
      0x0600: ['Sequence', ],  // 2 or 3 numbers: 1. Mode, 2. Shot number, 3. Mode bits
      0x0601: ['PanoramaMode', ],  // (2 numbers: 1. Mode, 2. Shot number)
      0x0603: ['ImageQuality2', {
          1: 'SQ',
          2: 'HQ',
          3: 'SHQ',
          4: 'RAW',
      }],
      0x0901: ['ManometerReading', ],
  };

*/
