import 'package:sprintf/sprintf.dart' show sprintf;
import 'tags_info.dart' show MakerTag, MakerTagFunc, tags_base;
import 'util.dart';
import 'exif_types.dart';

// Makernote (proprietary) tag definitions for Nikon.

class makernote_nikon extends tags_base {
  static Map<int, MakerTag> TAGS_NEW = _build_tags_new();
  static Map<int, MakerTag> TAGS_OLD = _build_tags_old();

  static MakerTag _make(String name) => MakerTag.make(name);
  static MakerTag _withMap(String name, Map<int, String> map) =>
      MakerTag.makeWithMap(name, map);
  static MakerTag _withFunc(String name, MakerTagFunc func) =>
      MakerTag.makeWithFunc(name, func);

  // First digit seems to be in steps of 1/6 EV.
  // Does the third value mean the step size?  It is usually 6,
  // but it is 12 for the ExposureDifference.
  // Check for an error condition that could cause a crash.
  // This only happens if something has gone really wrong in
  // reading the Nikon MakerNote.
  // http://tomtia.plala.jp/DigitalCamera/MakerNote/index.asp
  static String _ev_bias(List<int> seq) {
    if (seq.length < 4) {
      return '';
    }
    if (list_eq(seq, [252, 1, 6, 0])) {
      return '-2/3 EV';
    }
    if (list_eq(seq, [253, 1, 6, 0])) {
      return '-1/2 EV';
    }
    if (list_eq(seq, [254, 1, 6, 0])) {
      return '-1/3 EV';
    }
    if (list_eq(seq, [0, 1, 6, 0])) {
      return '0 EV';
    }
    if (list_eq(seq, [2, 1, 6, 0])) {
      return '+1/3 EV';
    }
    if (list_eq(seq, [3, 1, 6, 0])) {
      return '+1/2 EV';
    }
    if (list_eq(seq, [4, 1, 6, 0])) {
      return '+2/3 EV';
    }
    // Handle combinations not in the table.

    int a = seq[0];
    String? ret_str;
    // Causes headaches for the +/- logic, so special case it.
    if (a == 0) {
      return '0 EV';
    }
    if (a > 127) {
      a = 256 - a;
      ret_str = '-';
    } else {
      ret_str = '+';
    }

    int step = seq[2]; // Assume third value means the step size
    int whole = a ~/ step;
    a = a % step;

    if (whole != 0) {
      ret_str = sprintf('%s%s ', [ret_str, whole.toString()]);
    }

    if (a == 0) {
      ret_str += 'EV';
    } else {
      Ratio r = new Ratio(a, step);
      ret_str = ret_str + r.toString() + ' EV';
    }

    return ret_str;
  }

  // Nikon E99x MakerNote Tags
  static Map<int, MakerTag> _build_tags_new() {
    return {
      0x0001: _withFunc('MakernoteVersion', make_string), // Sometimes binary
      0x0002: _make('ISOSetting'),
      0x0003: _make('ColorMode'),
      0x0004: _make('Quality'),
      0x0005: _make('Whitebalance'),
      0x0006: _make('ImageSharpening'),
      0x0007: _make('FocusMode'),
      0x0008: _make('FlashSetting'),
      0x0009: _make('AutoFlashMode'),
      0x000B: _make('WhiteBalanceBias'),
      0x000C: _make('WhiteBalanceRBCoeff'),
      0x000D: _withFunc('ProgramShift', _ev_bias),
      // Nearly the same as the other EV vals, but step size is 1/12 EV []
      0x000E: _withFunc('ExposureDifference', _ev_bias),
      0x000F: _make('ISOSelection'),
      0x0010: _make('DataDump'),
      0x0011: _make('NikonPreview'),
      0x0012: _withFunc('FlashCompensation', _ev_bias),
      0x0013: _make('ISOSpeedRequested'),
      0x0016: _make('PhotoCornerCoordinates'),
      0x0017: _withFunc('ExternalFlashExposureComp', _ev_bias),
      0x0018: _withFunc('FlashBracketCompensationApplied', _ev_bias),
      0x0019: _make('AEBracketCompensationApplied'),
      0x001A: _make('ImageProcessing'),
      0x001B: _make('CropHiSpeed'),
      0x001C: _make('ExposureTuning'),
      0x001D: _make('SerialNumber'), // Conflict with 0x00A0 ?
      0x001E: _make('ColorSpace'),
      0x001F: _make('VRInfo'),
      0x0020: _make('ImageAuthentication'),
      0x0022: _make('ActiveDLighting'),
      0x0023: _make('PictureControl'),
      0x0024: _make('WorldTime'),
      0x0025: _make('ISOInfo'),
      0x0080: _make('ImageAdjustment'),
      0x0081: _make('ToneCompensation'),
      0x0082: _make('AuxiliaryLens'),
      0x0083: _make('LensType'),
      0x0084: _make('LensMinMaxFocalMaxAperture'),
      0x0085: _make('ManualFocusDistance'),
      0x0086: _make('DigitalZoomFactor'),
      0x0087: _withMap('FlashMode', {
        0x00: 'Did Not Fire',
        0x01: 'Fired, Manual',
        0x07: 'Fired, External',
        0x08: 'Fired, Commander Mode ',
        0x09: 'Fired, TTL Mode',
      }),
      0x0088: _withMap('AFFocusPosition', {
        0x0000: 'Center',
        0x0100: 'Top',
        0x0200: 'Bottom',
        0x0300: 'Left',
        0x0400: 'Right',
      }),
      0x0089: _withMap('BracketingMode', {
        0x00: 'Single frame, no bracketing',
        0x01: 'Continuous, no bracketing',
        0x02: 'Timer, no bracketing',
        0x10: 'Single frame, exposure bracketing',
        0x11: 'Continuous, exposure bracketing',
        0x12: 'Timer, exposure bracketing',
        0x40: 'Single frame, white balance bracketing',
        0x41: 'Continuous, white balance bracketing',
        0x42: 'Timer, white balance bracketing'
      }),
      0x008A: _make('AutoBracketRelease'),
      0x008B: _make('LensFStops'),
      0x008C: _make('NEFCurve1'), // ExifTool calls this 'ContrastCurve'
      0x008D: _make('ColorMode'),
      0x008F: _make('SceneMode'),
      0x0090: _make('LightingType'),
      0x0091: _make('ShotInfo'), // First 4 bytes are a version number in ASCII
      0x0092: _make('HueAdjustment'),
      // ExifTool calls this 'NEFCompression', should be 1-4
      0x0093: _make('Compression'),
      0x0094: _withMap('Saturation', {
        -3: 'B&W',
        -2: '-2',
        -1: '-1',
        0: '0',
        1: '1',
        2: '2',
      }),
      0x0095: _make('NoiseReduction'),
      0x0096: _make('NEFCurve2'), // ExifTool calls this 'LinearizationTable'
      0x0097:
          _make('ColorBalance'), // First 4 bytes are a version number in ASCII
      0x0098: _make('LensData'), // First 4 bytes are a version number in ASCII
      0x0099: _make('RawImageCenter'),
      0x009A: _make('SensorPixelSize'),
      0x009C: _make('Scene Assist'),
      0x009E: _make('RetouchHistory'),
      0x00A0: _make('SerialNumber'),
      0x00A2: _make('ImageDataSize'),
      // 00A3: unknown - a single byte 0
      // 00A4: In NEF, looks like a 4 byte ASCII version number ('0200')
      0x00A5: _make('ImageCount'),
      0x00A6: _make('DeletedImageCount'),
      0x00A7: _make('TotalShutterReleases'),
      // First 4 bytes are a version number in ASCII, with version specific
      // info to follow.  Its hard to treat it as a string due to embedded nulls.
      0x00A8: _make('FlashInfo'),
      0x00A9: _make('ImageOptimization'),
      0x00AA: _make('Saturation'),
      0x00AB: _make('DigitalVariProgram'),
      0x00AC: _make('ImageStabilization'),
      0x00AD: _make('AFResponse'),
      0x00B0: _make('MultiExposure'),
      0x00B1: _make('HighISONoiseReduction'),
      0x00B6: _make('PowerUpTime'),
      0x00B7: _make('AFInfo2'),
      0x00B8: _make('FileInfo'),
      0x00B9: _make('AFTune'),
      0x0100: _make('DigitalICE'),
      0x0103: _withMap('PreviewCompression', {
        1: 'Uncompressed',
        2: 'CCITT 1D',
        3: 'T4/Group 3 Fax',
        4: 'T6/Group 4 Fax',
        5: 'LZW',
        6: 'JPEG (old-style)',
        7: 'JPEG',
        8: 'Adobe Deflate',
        9: 'JBIG B&W',
        10: 'JBIG Color',
        32766: 'Next',
        32769: 'Epson ERF Compressed',
        32771: 'CCIRLEW',
        32773: 'PackBits',
        32809: 'Thunderscan',
        32895: 'IT8CTPAD',
        32896: 'IT8LW',
        32897: 'IT8MP',
        32898: 'IT8BL',
        32908: 'PixarFilm',
        32909: 'PixarLog',
        32946: 'Deflate',
        32947: 'DCS',
        34661: 'JBIG',
        34676: 'SGILog',
        34677: 'SGILog24',
        34712: 'JPEG 2000',
        34713: 'Nikon NEF Compressed',
        65000: 'Kodak DCR Compressed',
        65535: 'Pentax PEF Compressed',
      }),
      0x0201: _make('PreviewImageStart'),
      0x0202: _make('PreviewImageLength'),
      0x0213: _withMap('PreviewYCbCrPositioning', {
        1: 'Centered',
        2: 'Co-sited',
      }),
      0x0E09: _make('NikonCaptureVersion'),
      0x0E0E: _make('NikonCaptureOffsets'),
      0x0E10: _make('NikonScan'),
      0x0E22: _make('NEFBitDepth'),
    };
  }

  static Map<int, MakerTag> _build_tags_old() {
    return {
      0x0003: _withMap('Quality', {
        1: 'VGA Basic',
        2: 'VGA Normal',
        3: 'VGA Fine',
        4: 'SXGA Basic',
        5: 'SXGA Normal',
        6: 'SXGA Fine',
      }),
      0x0004: _withMap('ColorMode', {
        1: 'Color',
        2: 'Monochrome',
      }),
      0x0005: _withMap('ImageAdjustment', {
        0: 'Normal',
        1: 'Bright+',
        2: 'Bright-',
        3: 'Contrast+',
        4: 'Contrast-',
      }),
      0x0006: _withMap('CCDSpeed', {
        0: 'ISO 80',
        2: 'ISO 160',
        4: 'ISO 320',
        5: 'ISO 100',
      }),
      0x0007: _withMap('WhiteBalance', {
        0: 'Auto',
        1: 'Preset',
        2: 'Daylight',
        3: 'Incandescent',
        4: 'Fluorescent',
        5: 'Cloudy',
        6: 'Speed Light',
      }),
    };
  }
}
