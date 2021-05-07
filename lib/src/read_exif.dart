import 'dart:async';

import 'heic.dart';
import 'exif_types.dart';
import 'exifheader.dart';
import 'file_interface.dart';
import 'linereader.dart';
import 'util.dart';

int? _incrementBase(List<int> data, int base) {
  return (data[base + 2]) * 256 + (data[base + 3]) + 2;
}

// Process an image file data.
// This is the function that has to deal with all the arbitrary nasty bits
// of the EXIF standard.
Future<Map<String?, IfdTag>?> readExifFromBytes(List<int> bytes,
    // ignore: non_constant_identifier_names
    {String? stop_tag,
    bool details = true,
    bool strict = false,
    bool debug = false,
    // ignore: non_constant_identifier_names
    bool truncate_tags = true}) async {
  return readExifFromFileReader(FileReader.fromBytes(bytes),
      stopTag: stop_tag,
      details: details,
      strict: strict,
      debug: debug,
      truncateTags: truncate_tags);
}

// Streaming version of [readExifFromBytes].
Future<Map<String?, IfdTag>?> readExifFromFile(dynamic file,
    // ignore: non_constant_identifier_names
    {String? stop_tag,
    bool details = true,
    bool strict = false,
    bool debug = false,
    // ignore: non_constant_identifier_names
    bool truncate_tags = true}) async {
  final randomAccessFile = file.openSync();
  final fileReader = await FileReader.fromFile(randomAccessFile);
  final r = readExifFromFileReader(fileReader,
      stopTag: stop_tag,
      details: details,
      strict: strict,
      debug: debug,
      truncateTags: truncate_tags);
  randomAccessFile.closeSync();
  return r;
}

// Process an image file (expects an open file object).
// This is the function that has to deal with all the arbitrary nasty bits
// of the EXIF standard.
Map<String?, IfdTag>? readExifFromFileReader(FileReader f,
    {String? stopTag,
    bool details = true,
    bool strict = false,
    bool debug = false,
    bool truncateTags = true}) {
  // by default do not fake an EXIF beginning
  bool fakeExif = false;
  int endian;
  int offset, base;
  int? increment;

  // determine whether it's a JPEG or TIFF
  List<int> data = f.readSync(12);
  if (listContainedIn(
      data.sublist(0, 4), ['II*\x00'.codeUnits, 'MM\x00*'.codeUnits])) {
    // it's a TIFF file
    // print("TIFF format recognized in data[0:4]");
    f.setPositionSync(0);
    endian = f.readByteSync();
    f.readSync(1);
    offset = 0;
  } else if (listRangeEqual(data, 4, 12, 'ftypheic'.codeUnits)!) {
    f.setPositionSync(0);
    final heic = HEICExifFinder(f);
    final res = heic.findExif();
    offset = res[0];
    endian = res[1];
  } else if (listRangeEqual(data, 0, 2, '\xFF\xD8'.codeUnits)!) {
    // it's a JPEG file
    //print("** JPEG format recognized data[0:2]= (0x${data[0]}, ${data[1]})");
    base = 2;
    //print("** data[2]=${data[2]} data[3]=${data[3]} data[6:10]=${data.sublist(6,10)}");
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
      if (listRangeEqual(data, base, base + 2, [0xFF, 0xE1])!) {
        // APP1
        // print("**   APP1 at base $base");
        // print("**   Length: (${data[base + 2]}, ${data[base + 3]})");
        // print("**   Code: ${new String.fromCharCodes(data.sublist(base + 4,base + 8))}");
        if (listRangeEqual(data, base + 4, base + 8, "Exif".codeUnits)!) {
          // print("**  Decrement base by 2 to get to pre-segment header (for compatibility with later code)");
          base -= 2;
          break;
        }
        increment = _incrementBase(data, base);
        // print("** Increment base by $increment");
        base += increment!;
      } else if (listRangeEqual(data, base, base + 2, [0xFF, 0xE0])!) {
        // APP0
        // print("**  APP0 at base $base");
        // printf("**  Length: 0x%X 0x%X", [data[base + 2], data[base + 3]]);
        // printf("**  Code: %s", [data.sublist(base + 4, base + 8)]);
        increment = _incrementBase(data, base);
        // print("** Increment base by $increment");
        base += increment!;
      } else if (listRangeEqual(data, base, base + 2, [0xFF, 0xE2])!) {
        // APP2
        // printf("**  APP2 at base 0x%X", [base]);
        // printf("**  Length: 0x%X 0x%X", [data[base + 2], data[base + 3]]);
        // printf("** Code: %s", [data.sublist(base + 4,base + 8)]);
        increment = _incrementBase(data, base);
        // print("** Increment base by $increment");
        base += increment!;
      } else if (listRangeEqual(data, base, base + 2, [0xFF, 0xEE])!) {
        // APP14
        // printf("**  APP14 Adobe segment at base 0x%X", [base]);
        // printf("**  Length: 0x%X 0x%X", [data[base + 2], data[base + 3]]);
        // printf("**  Code: %s", [data.sublist(base + 4,base + 8)]);
        increment = _incrementBase(data, base);
        // print("** Increment base by $increment");
        base += increment!;
        // print("**  There is useful EXIF-like data here, but we have no parser for it.");
      } else if (listRangeEqual(data, base, base + 2, [0xFF, 0xDB])!) {
        // printf("**  JPEG image data at base 0x%X No more segments are expected.", [base]);
        break;
      } else if (listRangeEqual(data, base, base + 2, [0xFF, 0xD8])!) {
        // APP12
        // printf("**  FFD8 segment at base 0x%X", [base]);
        // printf("**  Got 0x%X 0x%X and %s instead", [data[base], data[base + 1], data.sublist(4 + base,10 + base)]);
        // printf("**  Length: 0x%X 0x%X", [data[base + 2], data[base + 3]]);
        // printf("**  Code: %s", [data.sublist(base + 4,base + 8)]);
        increment = _incrementBase(data, base);
        // print("** Increment base by $increment");
        base += increment!;
      } else if (listRangeEqual(data, base, base + 2, [0xFF, 0xEC])!) {
        // APP12
        // printf("**  APP12 XMP (Ducky) or Pictureinfo segment at base 0x%X", [base]);
        // printf("**  Got 0x%X and 0x%X instead", [data[base], data[base + 1]]);
        // printf("**  Length: 0x%X 0x%X", [data[base + 2], data[base + 3]]);
        // printf("** Code: %s", [data.sublist(base + 4,base + 8)]);
        increment = _incrementBase(data, base);
        // print("** Increment base by $increment");
        base += increment!;
        // print("**  There is useful EXIF-like data here (quality, comment, copyright), but we have no parser for it.");
      } else {
        try {
          increment = _incrementBase(data, base);
          // printf("**  Got 0x%X and 0x%X instead", [data[base], data[base + 1]]);
        } on RangeError {
          // throw new FormatException("Unexpected/unhandled segment type or file content.");
          return {};
        }

        // print("** Increment base by $increment");
        base += increment!;
      }
    }

    f.setPositionSync(base + 12);
    if (data[2 + base] == 0xFF &&
        listRangeEqual(data, 6 + base, 10 + base, 'Exif'.codeUnits)!) {
      // detected EXIF header
      offset = f.positionSync();
      endian = f.readByteSync();
      //HACK TEST:  endian = 'M'
    } else if (data[2 + base] == 0xFF &&
        listRangeEqual(data, 6 + base, 10 + base + 1, 'Ducky'.codeUnits)!) {
      // detected Ducky header.
      // printf("** EXIF-like header (normally 0xFF and code): 0x%X and %s",
      //              [data[2 + base], data.sublist(6 + base,10 + base + 1)]);
      offset = f.positionSync();
      endian = f.readByteSync();
    } else if (data[2 + base] == 0xFF &&
        listRangeEqual(data, 6 + base, 10 + base + 1, 'Adobe'.codeUnits)!) {
      // detected APP14 (Adobe);
      // printf("** EXIF-like header (normally 0xFF and code): 0x%X and %s",
      //              [data[2 + base], data.sublist(6 + base,10 + base + 1)]);
      offset = f.positionSync();
      endian = f.readByteSync();
    } else {
      // no EXIF information
      // print("** No EXIF header expected data[2+base]==0xFF and data[6+base:10+base]===Exif (or Duck)");
      // printf("** Did get 0x%X and %s",
      //              [data[2 + base], data.sublist(6 + base,10 + base + 1)]);
      return {};
    }
  } else {
    // file format not recognized
    // print("File format not recognized.");
    return {};
  }

  //endian = chr(ord_(endian[0]));
  // deal with the EXIF info we found
  // print("** Endian format is ${new String.fromCharCode(endian)} (${{
  //     'I'.codeUnitAt(0) : 'Intel',
  //     'M'.codeUnitAt(0) : 'Motorola',
  //     '\x01'.codeUnitAt(0) : 'Adobe Ducky',
  //     'd'.codeUnitAt(0): 'XMP/Adobe unknown'
  // }[endian]})");

  final hdr = ExifHeader(
      file: f,
      endian: endian,
      offset: offset,
      fakeExif: fakeExif,
      strict: strict,
      debug: debug,
      detailed: details,
      truncateTags: truncateTags);

  final ifdList = hdr.listIfd();
  int thumbIfd = 0;
  int ctr = 0;
  String ifdName;

  for (final ifd in ifdList) {
    if (ctr == 0) {
      ifdName = 'Image';
    } else if (ctr == 1) {
      ifdName = 'Thumbnail';
      thumbIfd = ifd;
    } else {
      ifdName = 'IFD $ctr';
    }
    // print('** IFD $ctr ($ifd_name) at offset $ifd');
    hdr.dumpIfd(ifd, ifdName, stopTag: stopTag);
    ctr += 1;
  }
  // EXIF IFD
  final exifOff = hdr.tags['Image ExifOffset'] as IfdTagImpl?;
  if (exifOff != null && ![1, 2, 5, 6, 10].contains(exifOff.fieldType)) {
    // print('** Exif SubIFD at offset ${exif_off.values[0]}:');
    hdr.dumpIfd(exifOff.values![0] as int, 'EXIF', stopTag: stopTag);
  }

  // deal with MakerNote contained in EXIF IFD
  // (Some apps use MakerNote tags but do not use a format for which we
  // have a description, do not process these).
  if (details &&
      hdr.tags.containsKey('EXIF MakerNote') &&
      hdr.tags.containsKey('Image Make')) {
    hdr.decodeMakerNote();
  }

  // extract thumbnails
  if (details && thumbIfd != 0) {
    hdr.extractTiffThumbnail(thumbIfd);
    hdr.extractJpegThumbnail();
  }

  // parse XMP tags (experimental)
  if (debug && details) {
    String xmpString = '';
    // Easy we already have them
    if (hdr.tags.containsKey('Image ApplicationNotes')) {
      // print('** XMP present in Exif');
      xmpString =
          makeString(hdr.tags['Image ApplicationNotes']!.values! as List<int>);
      // We need to look in the entire file for the XML
    } else {
      // print('** XMP not in Exif, searching file for XMP info...');
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

  return hdr.tags;
}
