import 'dart:async';

import 'package:exif/src/exif_decode_makernote.dart';

import 'exif_types.dart';
import 'exifheader.dart';
import 'file_interface.dart';
import 'heic.dart';
import 'linereader.dart';
import 'reader.dart';
import 'util.dart';

int _incrementBase(List<int> data, int base) {
  return (data[base + 2]) * 256 + (data[base + 3]) + 2;
}

/// Process an image file data.
/// This is the function that has to deal with all the arbitrary nasty bits
/// of the EXIF standard.
Future<Map<String, IfdTag>> readExifFromBytes(List<int> bytes,
    {String? stopTag,
    bool details = true,
    bool strict = false,
    bool debug = false,
    bool truncateTags = true}) async {
  return readExifFromFileReader(FileReader.fromBytes(bytes),
          stopTag: stopTag,
          details: details,
          strict: strict,
          debug: debug,
          truncateTags: truncateTags)
      .tags;
}

/// Streaming version of [readExifFromBytes].
Future<Map<String, IfdTag>> readExifFromFile(dynamic file,
    {String? stopTag,
    bool details = true,
    bool strict = false,
    bool debug = false,
    bool truncateTags = true}) async {
  final randomAccessFile = file.openSync();
  final fileReader = await FileReader.fromFile(randomAccessFile);
  final r = readExifFromFileReader(fileReader,
      stopTag: stopTag,
      details: details,
      strict: strict,
      debug: debug,
      truncateTags: truncateTags);
  randomAccessFile.closeSync();
  return r.tags;
}

/// Process an image file (expects an open file object).
/// This is the function that has to deal with all the arbitrary nasty bits
/// of the EXIF standard.
ExifData readExifFromFileReader(FileReader f,
    {String? stopTag,
    bool details = true,
    bool strict = false,
    bool debug = false,
    bool truncateTags = true}) {
  ReadParams readParams;

  // determine whether it's a JPEG or TIFF
  final header = f.readSync(12);
  if (_isTiff(header)) {
    readParams = _tiffReadParams(f);
  } else if (_isHeic(header)) {
    readParams = _heicReadParams(f);
  } else if (_isJpeg(header)) {
    readParams = _jpegReadParams(f);
  } else {
    return ExifData.withWarning("File format not recognized.");
  }

  if (readParams.error != "") {
    return ExifData.withWarning(readParams.error);
  }

  final file = IfdReader(Reader(f, readParams.offset, readParams.endian),
      fakeExif: readParams.fakeExif);

  final hdr = ExifHeader(
      file: file,
      strict: strict,
      debug: debug,
      detailed: details,
      truncateTags: truncateTags);

  final ifdList = file.listIfd();

  ifdList.asMap().forEach((ifdIndex, ifd) {
    hdr.dumpIfd(ifd, _ifdNameOfIndex(ifdIndex), stopTag: stopTag);
  });

  // EXIF IFD
  final exifOff = hdr.tags['Image ExifOffset'];
  if (exifOff != null && exifOff.tag.values is IfdInts) {
    hdr.dumpIfd(exifOff.tag.values.firstAsInt(), 'EXIF', stopTag: stopTag);
  }

  if (details) {
    DecodeMakerNote(hdr.tags, hdr.file, hdr.dumpIfd).decode();
  }

  if (details && ifdList.length >= 2) {
    hdr.extractTiffThumbnail(ifdList[1]);
    hdr.extractJpegThumbnail();
  }

  // parse XMP tags (experimental)
  if (debug && details) {
    _parseXmpTags(f, hdr);
  }

  return ExifData(
      hdr.tags.map((key, value) => MapEntry(key, value.tag)), hdr.warnings);
}

String _ifdNameOfIndex(int index) {
  if (index == 0) {
    return 'Image';
  } else if (index == 1) {
    return 'Thumbnail';
  } else {
    return 'IFD $index';
  }
}

void _parseXmpTags(FileReader f, ExifHeader hdr) {
  String xmpString = '';
  // Easy we already have them
  final imageApplicationNotes = hdr.tags['Image ApplicationNotes'];
  if (imageApplicationNotes != null) {
    // XMP present in Exif
    final tag = imageApplicationNotes.tag;
    xmpString =
        (tag is IfdInts) ? makeString((tag as IfdInts).ints) : tag.toString();
    // We need to look in the entire file for the XML
  } else {
    // XMP not in Exif, searching file for XMP info...
    bool xmlStarted = false;
    bool xmlFinished = false;
    final reader = LineReader(f);
    while (true) {
      String line = reader.readLine();
      if (line.isEmpty) break;

      final openTag = line.indexOf('<x:xmpmeta');
      final closeTag = line.indexOf('</x:xmpmeta>');

      if (openTag != -1) {
        xmlStarted = true;
        line = line.substring(openTag);
        // printf('** XMP found opening tag at line position %s', [open_tag]);
      }

      if (closeTag != -1) {
        // printf('** XMP found closing tag at line position %s', [close_tag]);
        int lineOffset = 0;
        if (openTag != -1) {
          lineOffset = openTag;
        }
        line = line.substring(0, (closeTag - lineOffset) + 12);
        xmlFinished = true;
      }

      if (xmlStarted) {
        xmpString += line;
      }

      if (xmlFinished) {
        break;
      }
    }

    // print('** XMP Finished searching for info');
    if (xmpString.isNotEmpty) {
      hdr.parseXmp(xmpString);
    }
  }
}

bool _isTiff(List<int> header) =>
    header.length >= 4 &&
    listContainedIn(
        header.sublist(0, 4), ['II*\x00'.codeUnits, 'MM\x00*'.codeUnits]);

bool _isHeic(List<int> header) =>
    listRangeEqual(header, 4, 12, 'ftypheic'.codeUnits);

bool _isJpeg(List<int> header) =>
    listRangeEqual(header, 0, 2, '\xFF\xD8'.codeUnits);

ReadParams _heicReadParams(FileReader f) {
  f.setPositionSync(0);
  final heic = HEICExifFinder(f);
  final res = heic.findExif();
  final int offset = res[0];
  final Endian endian = Reader.endianOfByte(res[1]);
  return ReadParams(endian: endian, offset: offset);
}

ReadParams _jpegReadParams(FileReader f) {
  // by default do not fake an EXIF beginning
  var fakeExif = false;
  int offset;
  Endian endian;

  f.setPositionSync(0);

  const headerLength = 12;
  var data = f.readSync(headerLength);
  if (data.length != headerLength) {
    return ReadParams.error("File format not recognized.");
  }

  var base = 2;
  while (data[2] == 0xFF &&
      listContainedIn(data.sublist(6, 10), [
        'JFIF'.codeUnits,
        'JFXX'.codeUnits,
        'OLYM'.codeUnits,
        'Phot'.codeUnits
      ])) {
    final length = data[4] * 256 + data[5];
    // printf("** Length offset is %d", [length]);
    f.readSync(length - 8);
    // fake an EXIF beginning of file
    // I don't think this is used. --gd
    data = [0xFF, 0x00];
    data.addAll(f.readSync(10));
    fakeExif = true;
    if (base > 2) {
      // print("** Added to base");
      base = base + length + 4 - 2;
    } else {
      // print("** Added to zero");
      base = length + 4;
    }
    // printf("** Set segment base to 0x%X", [base]);
  }

  // Big ugly patch to deal with APP2 (or other) data coming before APP1
  f.setPositionSync(0);
  // in theory, this could be insufficient since 64K is the maximum size--gd
  // print('** f.position=${f.positionSync()}, base=$base');
  data = f.readSync(base + 4000);
  // print('** data.length=${data.length}');

  // base = 2
  while (true) {
    // print('** base=$base');

    // if (data.length == 4020) {
    //   print("**  data.length=${data.length}, base=$base");
    // }
    if (listRangeEqual(data, base, base + 2, [0xFF, 0xE1])) {
      // APP1
      // print("**   APP1 at base $base");
      // print("**   Length: (${data[base + 2]}, ${data[base + 3]})");
      // print("**   Code: ${new String.fromCharCodes(data.sublist(base + 4,base + 8))}");
      if (listRangeEqual(data, base + 4, base + 8, "Exif".codeUnits)) {
        // print("**  Decrement base by 2 to get to pre-segment header (for compatibility with later code)");
        base -= 2;
        break;
      }
      base += _incrementBase(data, base);
    } else if (listRangeEqual(data, base, base + 2, [0xFF, 0xE0])) {
      // APP0
      // print("**  APP0 at base $base");
      // printf("**  Length: 0x%X 0x%X", [data[base + 2], data[base + 3]]);
      // printf("**  Code: %s", [data.sublist(base + 4, base + 8)]);
      base += _incrementBase(data, base);
    } else if (listRangeEqual(data, base, base + 2, [0xFF, 0xE2])) {
      // APP2
      // printf("**  APP2 at base 0x%X", [base]);
      // printf("**  Length: 0x%X 0x%X", [data[base + 2], data[base + 3]]);
      // printf("** Code: %s", [data.sublist(base + 4,base + 8)]);
      base += _incrementBase(data, base);
    } else if (listRangeEqual(data, base, base + 2, [0xFF, 0xEE])) {
      // APP14
      // printf("**  APP14 Adobe segment at base 0x%X", [base]);
      // printf("**  Length: 0x%X 0x%X", [data[base + 2], data[base + 3]]);
      // printf("**  Code: %s", [data.sublist(base + 4,base + 8)]);
      base += _incrementBase(data, base);
      // print("**  There is useful EXIF-like data here, but we have no parser for it.");
    } else if (listRangeEqual(data, base, base + 2, [0xFF, 0xDB])) {
      // printf("**  JPEG image data at base 0x%X No more segments are expected.", [base]);
      break;
    } else if (listRangeEqual(data, base, base + 2, [0xFF, 0xD8])) {
      // APP12
      // printf("**  FFD8 segment at base 0x%X", [base]);
      // printf("**  Got 0x%X 0x%X and %s instead", [data[base], data[base + 1], data.sublist(4 + base,10 + base)]);
      // printf("**  Length: 0x%X 0x%X", [data[base + 2], data[base + 3]]);
      // printf("**  Code: %s", [data.sublist(base + 4,base + 8)]);
      base += _incrementBase(data, base);
    } else if (listRangeEqual(data, base, base + 2, [0xFF, 0xEC])) {
      // APP12
      // printf("**  APP12 XMP (Ducky) or Pictureinfo segment at base 0x%X", [base]);
      // printf("**  Got 0x%X and 0x%X instead", [data[base], data[base + 1]]);
      // printf("**  Length: 0x%X 0x%X", [data[base + 2], data[base + 3]]);
      // printf("** Code: %s", [data.sublist(base + 4,base + 8)]);
      base += _incrementBase(data, base);
      // print("**  There is useful EXIF-like data here (quality, comment, copyright), but we have no parser for it.");
    } else {
      try {
        base += _incrementBase(data, base);
      } on RangeError {
        return ReadParams.error(
            "Unexpected/unhandled segment type or file content.");
      }
    }
  }

  f.setPositionSync(base + 12);
  if (data[2 + base] == 0xFF &&
      listRangeEqual(data, 6 + base, 10 + base, 'Exif'.codeUnits)) {
    // detected EXIF header
    offset = f.positionSync();
    endian = Reader.endianOfByte(f.readByteSync());
    //HACK TEST:  endian = 'M'
  } else if (data[2 + base] == 0xFF &&
      listRangeEqual(data, 6 + base, 10 + base + 1, 'Ducky'.codeUnits)) {
    // detected Ducky header.
    // printf("** EXIF-like header (normally 0xFF and code): 0x%X and %s",
    //              [data[2 + base], data.sublist(6 + base,10 + base + 1)]);
    offset = f.positionSync();
    endian = Reader.endianOfByte(f.readByteSync());
  } else if (data[2 + base] == 0xFF &&
      listRangeEqual(data, 6 + base, 10 + base + 1, 'Adobe'.codeUnits)) {
    // detected APP14 (Adobe);
    // printf("** EXIF-like header (normally 0xFF and code): 0x%X and %s",
    //              [data[2 + base], data.sublist(6 + base,10 + base + 1)]);
    offset = f.positionSync();
    endian = Reader.endianOfByte(f.readByteSync());
  } else {
    // print("** No EXIF header expected data[2+base]==0xFF and data[6+base:10+base]===Exif (or Duck)");
    // printf("** Did get 0x%X and %s",
    //              [data[2 + base], data.sublist(6 + base,10 + base + 1)]);
    return ReadParams.error("No EXIF information found");
  }

  return ReadParams(endian: endian, offset: offset, fakeExif: fakeExif);
}

ReadParams _tiffReadParams(FileReader f) {
  f.setPositionSync(0);
  final endian = Reader.endianOfByte(f.readByteSync());
  f.readSync(1);
  return ReadParams(endian: endian, offset: 0);
}

class ReadParams {
  final bool fakeExif;
  final Endian endian;
  final int offset;
  final String error;

  ReadParams({
    required this.endian,
    required this.offset,
    // by default do not fake an EXIF beginning
    this.fakeExif = false,
  }) : error = "";

  ReadParams.error(this.error)
      : endian = Endian.little,
        offset = 0,
        fakeExif = false;
}
