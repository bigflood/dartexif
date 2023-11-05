import 'package:exif/src/tags_info.dart'
    show MakerTag, MakerTagFunc, TagsBase, MakerTagsWithName;
import 'package:exif/src/util.dart';

// Standard tag definitions.

class StandardTags extends TagsBase {
  static MakerTag _make(String name) => MakerTag.make(name);

  static MakerTag _withMap(String name, Map<int, String> map) =>
      MakerTag.makeWithMap(name, map);

  static MakerTag _withFunc(String name, MakerTagFunc func) =>
      MakerTag.makeWithFunc(name, func);

  static MakerTag _withTags(String name, MakerTagsWithName tags) =>
      MakerTag.makeWithTags(name, tags);

  // Interoperability tags
  static final Map<int, MakerTag> _interopTags = {
    0x0001: _make('InteroperabilityIndex'),
    0x0002: _make('InteroperabilityVersion'),
    0x1000: _make('RelatedImageFileFormat'),
    0x1001: _make('RelatedImageWidth'),
    0x1002: _make('RelatedImageLength'),
  };

  static final MakerTagsWithName _interopInfo =
      MakerTagsWithName(name: 'Interoperability', tags: _interopTags);

  // GPS tags
  static final Map<int, MakerTag> _gpsTags = {
    0x0000: _make('GPSVersionID'),
    0x0001: _make('GPSLatitudeRef'),
    0x0002: _make('GPSLatitude'),
    0x0003: _make('GPSLongitudeRef'),
    0x0004: _make('GPSLongitude'),
    0x0005: _make('GPSAltitudeRef'),
    0x0006: _make('GPSAltitude'),
    0x0007: _make('GPSTimeStamp'),
    0x0008: _make('GPSSatellites'),
    0x0009: _make('GPSStatus'),
    0x000A: _make('GPSMeasureMode'),
    0x000B: _make('GPSDOP'),
    0x000C: _make('GPSSpeedRef'),
    0x000D: _make('GPSSpeed'),
    0x000E: _make('GPSTrackRef'),
    0x000F: _make('GPSTrack'),
    0x0010: _make('GPSImgDirectionRef'),
    0x0011: _make('GPSImgDirection'),
    0x0012: _make('GPSMapDatum'),
    0x0013: _make('GPSDestLatitudeRef'),
    0x0014: _make('GPSDestLatitude'),
    0x0015: _make('GPSDestLongitudeRef'),
    0x0016: _make('GPSDestLongitude'),
    0x0017: _make('GPSDestBearingRef'),
    0x0018: _make('GPSDestBearing'),
    0x0019: _make('GPSDestDistanceRef'),
    0x001A: _make('GPSDestDistance'),
    0x001B: _make('GPSProcessingMethod'),
    0x001C: _make('GPSAreaInformation'),
    0x001D: _make('GPSDate'),
    0x001E: _make('GPSDifferential'),
  };

  static final MakerTagsWithName _gpsInfo =
      MakerTagsWithName(name: 'GPS', tags: _gpsTags);

  // Main Exif tag names
  static final Map<int, MakerTag> tags = {
    0x00FE: _withMap('SubfileType', {
      0x0: 'Full-resolution Image',
      0x1: 'Reduced-resolution image',
      0x2: 'Single page of multi-page image',
      0x3: 'Single page of multi-page reduced-resolution image',
      0x4: 'Transparency mask',
      0x5: 'Transparency mask of reduced-resolution image',
      0x6: 'Transparency mask of multi-page image',
      0x7: 'Transparency mask of reduced-resolution multi-page image',
      0x10001: 'Alternate reduced-resolution image',
      0xffffffff: 'invalid ',
    }),
    0x00FF: _withMap('OldSubfileType', {
      1: 'Full-resolution image',
      2: 'Reduced-resolution image',
      3: 'Single page of multi-page image',
    }),
    0x0100: _make('ImageWidth'),
    0x0101: _make('ImageLength'),
    0x0102: _make('BitsPerSample'),
    0x0103: _withMap('Compression', const {
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
      65535: 'Pentax PEF Compressed'
    }),
    0x0106: _make('PhotometricInterpretation'),
    0x0107: _make('Thresholding'),
    0x0108: _make('CellWidth'),
    0x0109: _make('CellLength'),
    0x010A: _make('FillOrder'),
    0x010D: _make('DocumentName'),
    0x010E: _make('ImageDescription'),
    0x010F: _make('Make'),
    0x0110: _make('Model'),
    0x0111: _make('StripOffsets'),
    0x0112: _withMap('Orientation', const {
      1: 'Horizontal (normal)',
      2: 'Mirrored horizontal',
      3: 'Rotated 180',
      4: 'Mirrored vertical',
      5: 'Mirrored horizontal then rotated 90 CCW',
      6: 'Rotated 90 CW',
      7: 'Mirrored horizontal then rotated 90 CW',
      8: 'Rotated 90 CCW'
    }),
    0x0115: _make('SamplesPerPixel'),
    0x0116: _make('RowsPerStrip'),
    0x0117: _make('StripByteCounts'),
    0x0118: _make('MinSampleValue'),
    0x0119: _make('MaxSampleValue'),
    0x011A: _make('XResolution'),
    0x011B: _make('YResolution'),
    0x011C: _make('PlanarConfiguration'),
    0x011D: _withFunc('PageName', makeString),
    0x011E: _make('XPosition'),
    0x011F: _make('YPosition'),
    0x0122: _withMap('GrayResponseUnit', const {
      1: '0.1',
      2: '0.001',
      3: '0.0001',
      4: '1e-05',
      5: '1e-06',
    }),
    0x0123: _make('GrayResponseCurve'),
    0x0124: _make('T4Options'),
    0x0125: _make('T6Options'),
    0x0128: _withMap('ResolutionUnit',
        const {1: 'Not Absolute', 2: 'Pixels/Inch', 3: 'Pixels/Centimeter'}),
    0x0129: _make('PageNumber'),
    0x012C: _make('ColorResponseUnit'),
    0x012D: _make('TransferFunction'),
    0x0131: _make('Software'),
    0x0132: _make('DateTime'),
    0x013B: _make('Artist'),
    0x013C: _make('HostComputer'),
    0x013D:
        _withMap('Predictor', const {1: 'None', 2: 'Horizontal differencing'}),
    0x013E: _make('WhitePoint'),
    0x013F: _make('PrimaryChromaticities'),
    0x0140: _make('ColorMap'),
    0x0141: _make('HalftoneHints'),
    0x0142: _make('TileWidth'),
    0x0143: _make('TileLength'),
    0x0144: _make('TileOffsets'),
    0x0145: _make('TileByteCounts'),
    0x0146: _make('BadFaxLines'),
    0x0147: _withMap(
        'CleanFaxData', const {0: 'Clean', 1: 'Regenerated', 2: 'Unclean'}),
    0x0148: _make('ConsecutiveBadFaxLines'),
    0x014C: _withMap('InkSet', const {1: 'CMYK', 2: 'Not CMYK'}),
    0x014D: _make('InkNames'),
    0x014E: _make('NumberofInks'),
    0x0150: _make('DotRange'),
    0x0151: _make('TargetPrinter'),
    0x0152: _withMap('ExtraSamples', const {
      0: 'Unspecified',
      1: 'Associated Alpha',
      2: 'Unassociated Alpha'
    }),
    0x0153: _withMap('SampleFormat', const {
      1: 'Unsigned',
      2: 'Signed',
      3: 'Float',
      4: 'Undefined',
      5: 'Complex int',
      6: 'Complex float'
    }),
    0x0154: _make('SMinSampleValue'),
    0x0155: _make('SMaxSampleValue'),
    0x0156: _make('TransferRange'),
    0x0157: _make('ClipPath'),
    0x0200: _make('JPEGProc'),
    0x0201: _make('JPEGInterchangeFormat'),
    0x0202: _make('JPEGInterchangeFormatLength'),
    0x0211: _make('YCbCrCoefficients'),
    0x0212: _make('YCbCrSubSampling'),
    0x0213: _withMap('YCbCrPositioning', const {1: 'Centered', 2: 'Co-sited'}),
    0x0214: _make('ReferenceBlackWhite'),
    0x02BC: _make('ApplicationNotes'), // XPM Info
    0x4746: _make('Rating'),
    0x828D: _make('CFARepeatPatternDim'),
    0x828E: _make('CFAPattern'),
    0x828F: _make('BatteryLevel'),
    0x8298: _make('Copyright'),
    0x829A: _make('ExposureTime'),
    0x829D: _make('FNumber'),
    0x83BB: _make('IPTC/NAA'),
    0x8769: _make('ExifOffset'), // Exif Tags
    0x8773: _make('InterColorProfile'),
    0x8822: _withMap('ExposureProgram', const {
      0: 'Unidentified',
      1: 'Manual',
      2: 'Program Normal',
      3: 'Aperture Priority',
      4: 'Shutter Priority',
      5: 'Program Creative',
      6: 'Program Action',
      7: 'Portrait Mode',
      8: 'Landscape Mode'
    }),
    0x8824: _make('SpectralSensitivity'),
    0x8825: _withTags('GPSInfo', _gpsInfo), // GPS tags
    0x8827: _make('ISOSpeedRatings'),
    0x8828: _make('OECF'),
    0x8830: _withMap('SensitivityType', const {
      0: 'Unknown',
      1: 'Standard Output Sensitivity',
      2: 'Recommended Exposure Index',
      3: 'ISO Speed',
      4: 'Standard Output Sensitivity and Recommended Exposure Index',
      5: 'Standard Output Sensitivity and ISO Speed',
      6: 'Recommended Exposure Index and ISO Speed',
      7: 'Standard Output Sensitivity, Recommended Exposure Index and ISO Speed'
    }),
    0x8832: _make('RecommendedExposureIndex'),
    0x8833: _make('ISOSpeed'),
    0x9000: _withFunc('ExifVersion', makeString),
    0x9003: _make('DateTimeOriginal'),
    0x9004: _make('DateTimeDigitized'),
    0x9010: _make('OffsetTime'),
    0x9011: _make('OffsetTimeOriginal'),
    0x9012: _make('OffsetTimeDigitized'),
    0x9101: _withMap('ComponentsConfiguration', const {
      0: '',
      1: 'Y',
      2: 'Cb',
      3: 'Cr',
      4: 'Red',
      5: 'Green',
      6: 'Blue'
    }),
    0x9102: _make('CompressedBitsPerPixel'),
    0x9201: _make('ShutterSpeedValue'),
    0x9202: _make('ApertureValue'),
    0x9203: _make('BrightnessValue'),
    0x9204: _make('ExposureBiasValue'),
    0x9205: _make('MaxApertureValue'),
    0x9206: _make('SubjectDistance'),
    0x9207: _withMap('MeteringMode', const {
      0: 'Unidentified',
      1: 'Average',
      2: 'CenterWeightedAverage',
      3: 'Spot',
      4: 'MultiSpot',
      5: 'Pattern',
      6: 'Partial',
      255: 'Other'
    }),
    0x9208: _withMap('LightSource', const {
      0: 'Unknown',
      1: 'Daylight',
      2: 'Fluorescent',
      3: 'Tungsten (incandescent light)',
      4: 'Flash',
      9: 'Fine weather',
      10: 'Cloudy weather',
      11: 'Shade',
      12: 'Daylight fluorescent (D 5700 - 7100K)',
      13: 'Day white fluorescent (N 4600 - 5400K)',
      14: 'Cool white fluorescent (W 3900 - 4500K)',
      15: 'White fluorescent (WW 3200 - 3700K)',
      17: 'Standard light A',
      18: 'Standard light B',
      19: 'Standard light C',
      20: 'D55',
      21: 'D65',
      22: 'D75',
      23: 'D50',
      24: 'ISO studio tungsten',
      255: 'Other light source'
    }),
    0x9209: _withMap('Flash', const {
      0: 'Flash did not fire',
      1: 'Flash fired',
      5: 'Strobe return light not detected',
      7: 'Strobe return light detected',
      9: 'Flash fired, compulsory flash mode',
      13: 'Flash fired, compulsory flash mode, return light not detected',
      15: 'Flash fired, compulsory flash mode, return light detected',
      16: 'Flash did not fire, compulsory flash mode',
      24: 'Flash did not fire, auto mode',
      25: 'Flash fired, auto mode',
      29: 'Flash fired, auto mode, return light not detected',
      31: 'Flash fired, auto mode, return light detected',
      32: 'No flash function',
      65: 'Flash fired, red-eye reduction mode',
      69: 'Flash fired, red-eye reduction mode, return light not detected',
      71: 'Flash fired, red-eye reduction mode, return light detected',
      73: 'Flash fired, compulsory flash mode, red-eye reduction mode',
      77: 'Flash fired, compulsory flash mode, red-eye reduction mode, return light not detected',
      79: 'Flash fired, compulsory flash mode, red-eye reduction mode, return light detected',
      89: 'Flash fired, auto mode, red-eye reduction mode',
      93: 'Flash fired, auto mode, return light not detected, red-eye reduction mode',
      95: 'Flash fired, auto mode, return light detected, red-eye reduction mode'
    }),
    0x920A: _make('FocalLength'),
    0x9214: _make('SubjectArea'),
    0x927C: _make('MakerNote'),
    0x9286: _withFunc('UserComment', makeStringUc),
    0x9290: _make('SubSecTime'),
    0x9291: _make('SubSecTimeOriginal'),
    0x9292: _make('SubSecTimeDigitized'),

    // used by Windows Explorer
    0x9C9B: _make('XPTitle'),
    0x9C9C: _make('XPComment'),
    0x9C9D: _withFunc('XPAuthor',
        makeString), // const [gnored by Windows Explorer if Artist exists]
    0x9C9E: _make('XPKeywords'),
    0x9C9F: _make('XPSubject'),
    0xA000: _withFunc('FlashPixVersion', makeString),
    0xA001: _withMap(
        'ColorSpace', const {1: 'sRGB', 2: 'Adobe RGB', 65535: 'Uncalibrated'}),
    0xA002: _make('ExifImageWidth'),
    0xA003: _make('ExifImageLength'),
    0xA004: _make('RelatedSoundFile'),
    0xA005: _withTags('InteroperabilityOffset', _interopInfo),
    0xA20B: _make('FlashEnergy'), // 0x920B in TIFF/EP
    0xA20C: _make('SpatialFrequencyResponse'), // 0x920C
    0xA20E: _make('FocalPlaneXResolution'), // 0x920E
    0xA20F: _make('FocalPlaneYResolution'), // 0x920F
    0xA210: _make('FocalPlaneResolutionUnit'), // 0x9210
    0xA214: _make('SubjectLocation'), // 0x9214
    0xA215: _make('ExposureIndex'), // 0x9215
    0xA217: _withMap('SensingMethod', const {
      // 0x9217
      1: 'Not defined',
      2: 'One-chip color area',
      3: 'Two-chip color area',
      4: 'Three-chip color area',
      5: 'Color sequential area',
      7: 'Trilinear',
      8: 'Color sequential linear'
    }),
    0xA300: _withMap('FileSource', const {
      1: 'Film Scanner',
      2: 'Reflection Print Scanner',
      3: 'Digital Camera'
    }),
    0xA301: _withMap('SceneType', const {1: 'Directly Photographed'}),
    0xA302: _make('CVAPattern'),
    0xA401: _withMap('CustomRendered', const {0: 'Normal', 1: 'Custom'}),
    0xA402: _withMap('ExposureMode',
        const {0: 'Auto Exposure', 1: 'Manual Exposure', 2: 'Auto Bracket'}),
    0xA403: _withMap('WhiteBalance', const {0: 'Auto', 1: 'Manual'}),
    0xA404: _make('DigitalZoomRatio'),
    0xA405: _make('FocalLengthIn35mmFilm'),
    0xA406: _withMap('SceneCaptureType',
        const {0: 'Standard', 1: 'Landscape', 2: 'Portrait', 3: 'Night]'}),
    0xA407: _withMap('GainControl', const {
      0: 'None',
      1: 'Low gain up',
      2: 'High gain up',
      3: 'Low gain down',
      4: 'High gain down'
    }),
    0xA408: _withMap('Contrast', const {0: 'Normal', 1: 'Soft', 2: 'Hard'}),
    0xA409: _withMap('Saturation', const {0: 'Normal', 1: 'Soft', 2: 'Hard'}),
    0xA40A: _withMap('Sharpness', const {0: 'Normal', 1: 'Soft', 2: 'Hard'}),
    0xA40B: _make('DeviceSettingDescription'),
    0xA40C: _make('SubjectDistanceRange'),
    0xA420: _make('ImageUniqueID'),
    0xA430: _make('CameraOwnerName'),
    0xA431: _make('BodySerialNumber'),
    0xA432: _make('LensSpecification'),
    0xA433: _make('LensMake'),
    0xA434: _make('LensModel'),
    0xA435: _make('LensSerialNumber'),
    0xA500: _make('Gamma'),
    0xC4A5: _make('PrintIM'),
    0xEA1C: _make('Padding'),
    0xEA1D: _make('OffsetSchema'),
    0xFDE8: _make('OwnerName'),
    0xFDE9: _make('SerialNumber'),
  };
}
