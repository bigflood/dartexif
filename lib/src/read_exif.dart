import 'dart:async';

import 'exifheader.dart';
import 'util.dart';
import 'linereader.dart';
import 'exif_types.dart';
import 'file_interface.dart';

int _increment_base(data, base) {
  return (data[base + 2]) * 256 + (data[base + 3]) + 2;
}

// Process an image file data.
// This is the function that has to deal with all the arbitrary nasty bits
// of the EXIF standard.
Future<Map<String, IfdTag>> readExifFromBytes(List<int> bytes,
    {String stop_tag,
    bool details = true,
    bool strict = false,
    bool debug = false,
    bool truncate_tags = true}) async {
  var r = await readExifFromFileReader(new FileReader.fromBytes(bytes),
      stop_tag: stop_tag,
      details: details,
      strict: strict,
      debug: debug,
      truncate_tags: truncate_tags);

  return r;
}

// Streaming version of [readExifFromBytes].
Future<Map<String, IfdTag>> readExifFromFile(dynamic file,
    {String stop_tag,
    bool details = true,
    bool strict = false,
    bool debug = false,
    bool truncate_tags = true}) async {
  final randomAccessFile = file.openSync();
  var fileReader = await FileReader.fromFile(randomAccessFile);
  var r = await readExifFromFileReader(fileReader,
      stop_tag: stop_tag,
      details: details,
      strict: strict,
      debug: debug,
      truncate_tags: truncate_tags);
  randomAccessFile.closeSync();
  return r;
}

// Process an image file (expects an open file object).
// This is the function that has to deal with all the arbitrary nasty bits
// of the EXIF standard.
Map<String, IfdTag> readExifFromFileReader(FileReader f,
    {String stop_tag,
    bool details = true,
    bool strict = false,
    bool debug = false,
    bool truncate_tags = true}) {
  // by default do not fake an EXIF beginning
  bool fake_exif = false;
  int endian;
  int offset, base;
  int increment;

  // determine whether it's a JPEG or TIFF
  List<int> data = f.readSync(12);
  if (list_in(data.sublist(0, 4), ['II*\x00'.codeUnits, 'MM\x00*'.codeUnits])) {
    // it's a TIFF file
    // print("TIFF format recognized in data[0:4]");
    f.setPositionSync(0);
    endian = f.readByteSync();
    f.readSync(1);
    offset = 0;
  } else if (list_range_eq(data, 0, 2, '\xFF\xD8'.codeUnits)) {
    // it's a JPEG file
    //print("** JPEG format recognized data[0:2]= (0x${data[0]}, ${data[1]})");
    base = 2;
    //print("** data[2]=${data[2]} data[3]=${data[3]} data[6:10]=${data.sublist(6,10)}");
    while (data[2] == 0xFF &&
        list_in(data.sublist(6, 10), [
          'JFIF'.codeUnits,
          'JFXX'.codeUnits,
          'OLYM'.codeUnits,
          'Phot'.codeUnits
        ])) {
      int length = data[4] * 256 + data[5];
      // printf("** Length offset is %d", [length]);
      f.readSync(length - 8);
      // fake an EXIF beginning of file
      // I don't think this is used. --gd
      data = [0xFF, 0x00];
      data.addAll(f.readSync(10));
      fake_exif = true;
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
      if (list_range_eq(data, base, base + 2, [0xFF, 0xE1])) {
        // APP1
        // print("**   APP1 at base $base");
        // print("**   Length: (${data[base + 2]}, ${data[base + 3]})");
        // print("**   Code: ${new String.fromCharCodes(data.sublist(base + 4,base + 8))}");
        if (list_range_eq(data, base + 4, base + 8, "Exif".codeUnits)) {
          // print("**  Decrement base by 2 to get to pre-segment header (for compatibility with later code)");
          base -= 2;
          break;
        }
        increment = _increment_base(data, base);
        // print("** Increment base by $increment");
        base += increment;
      } else if (list_range_eq(data, base, base + 2, [0xFF, 0xE0])) {
        // APP0
        // print("**  APP0 at base $base");
        // printf("**  Length: 0x%X 0x%X", [data[base + 2], data[base + 3]]);
        // printf("**  Code: %s", [data.sublist(base + 4, base + 8)]);
        increment = _increment_base(data, base);
        // print("** Increment base by $increment");
        base += increment;
      } else if (list_range_eq(data, base, base + 2, [0xFF, 0xE2])) {
        // APP2
        // printf("**  APP2 at base 0x%X", [base]);
        // printf("**  Length: 0x%X 0x%X", [data[base + 2], data[base + 3]]);
        // printf("** Code: %s", [data.sublist(base + 4,base + 8)]);
        increment = _increment_base(data, base);
        // print("** Increment base by $increment");
        base += increment;
      } else if (list_range_eq(data, base, base + 2, [0xFF, 0xEE])) {
        // APP14
        // printf("**  APP14 Adobe segment at base 0x%X", [base]);
        // printf("**  Length: 0x%X 0x%X", [data[base + 2], data[base + 3]]);
        // printf("**  Code: %s", [data.sublist(base + 4,base + 8)]);
        increment = _increment_base(data, base);
        // print("** Increment base by $increment");
        base += increment;
        // print("**  There is useful EXIF-like data here, but we have no parser for it.");
      } else if (list_range_eq(data, base, base + 2, [0xFF, 0xDB])) {
        // printf("**  JPEG image data at base 0x%X No more segments are expected.", [base]);
        break;
      } else if (list_range_eq(data, base, base + 2, [0xFF, 0xD8])) {
        // APP12
        // printf("**  FFD8 segment at base 0x%X", [base]);
        // printf("**  Got 0x%X 0x%X and %s instead", [data[base], data[base + 1], data.sublist(4 + base,10 + base)]);
        // printf("**  Length: 0x%X 0x%X", [data[base + 2], data[base + 3]]);
        // printf("**  Code: %s", [data.sublist(base + 4,base + 8)]);
        increment = _increment_base(data, base);
        // print("** Increment base by $increment");
        base += increment;
      } else if (list_range_eq(data, base, base + 2, [0xFF, 0xEC])) {
        // APP12
        // printf("**  APP12 XMP (Ducky) or Pictureinfo segment at base 0x%X", [base]);
        // printf("**  Got 0x%X and 0x%X instead", [data[base], data[base + 1]]);
        // printf("**  Length: 0x%X 0x%X", [data[base + 2], data[base + 3]]);
        // printf("** Code: %s", [data.sublist(base + 4,base + 8)]);
        increment = _increment_base(data, base);
        // print("** Increment base by $increment");
        base += increment;
        // print("**  There is useful EXIF-like data here (quality, comment, copyright), but we have no parser for it.");
      } else {
        try {
          increment = _increment_base(data, base);
          // printf("**  Got 0x%X and 0x%X instead", [data[base], data[base + 1]]);
        } on RangeError {
          // throw new FormatException("Unexpected/unhandled segment type or file content.");
          return {};
        }

        // print("** Increment base by $increment");
        base += increment;
      }
    }

    f.setPositionSync(base + 12);
    if (data[2 + base] == 0xFF &&
        list_range_eq(data, 6 + base, 10 + base, 'Exif'.codeUnits)) {
      // detected EXIF header
      offset = f.positionSync();
      endian = f.readByteSync();
      //HACK TEST:  endian = 'M'
    } else if (data[2 + base] == 0xFF &&
        list_range_eq(data, 6 + base, 10 + base + 1, 'Ducky'.codeUnits)) {
      // detected Ducky header.
      // printf("** EXIF-like header (normally 0xFF and code): 0x%X and %s",
      //              [data[2 + base], data.sublist(6 + base,10 + base + 1)]);
      offset = f.positionSync();
      endian = f.readByteSync();
    } else if (data[2 + base] == 0xFF &&
        list_range_eq(data, 6 + base, 10 + base + 1, 'Adobe'.codeUnits)) {
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

  ExifHeader hdr = new ExifHeader(
      f, endian, offset, fake_exif, strict, debug, details, truncate_tags);
  List<int> ifd_list = hdr.list_ifd();
  int thumb_ifd = 0;
  int ctr = 0;
  String ifd_name;

  for (var ifd in ifd_list) {
    if (ctr == 0) {
      ifd_name = 'Image';
    } else if (ctr == 1) {
      ifd_name = 'Thumbnail';
      thumb_ifd = ifd;
    } else {
      ifd_name = 'IFD ' + ctr.toString();
    }
    // print('** IFD $ctr ($ifd_name) at offset $ifd');
    hdr.dump_ifd(ifd, ifd_name, stop_tag: stop_tag);
    ctr += 1;
  }
  // EXIF IFD
  IfdTagImpl exif_off = hdr.tags['Image ExifOffset'];
  if (exif_off != null && ![1, 2, 5, 6, 10].contains(exif_off.field_type)) {
    // print('** Exif SubIFD at offset ${exif_off.values[0]}:');
    hdr.dump_ifd(exif_off.values[0], 'EXIF', stop_tag: stop_tag);
  }

  // deal with MakerNote contained in EXIF IFD
  // (Some apps use MakerNote tags but do not use a format for which we
  // have a description, do not process these).
  if (details &&
      hdr.tags.containsKey('EXIF MakerNote') &&
      hdr.tags.containsKey('Image Make')) {
    hdr.decode_maker_note();
  }

  // extract thumbnails
  if (details && thumb_ifd != 0) {
    hdr.extract_tiff_thumbnail(thumb_ifd);
    hdr.extract_jpeg_thumbnail();
  }

  // parse XMP tags (experimental)
  if (debug && details) {
    String xmp_string = '';
    // Easy we already have them
    if (hdr.tags.containsKey('Image ApplicationNotes')) {
      // print('** XMP present in Exif');
      xmp_string = make_string(hdr.tags['Image ApplicationNotes'].values);
      // We need to look in the entire file for the XML
    } else {
      // print('** XMP not in Exif, searching file for XMP info...');
      bool xml_started = false;
      bool xml_finished = false;
      LineReader reader = new LineReader(f);
      while (true) {
        String line = reader.readline();
        if (line.isEmpty) break;

        int open_tag = line.indexOf('<x:xmpmeta');
        int close_tag = line.indexOf('</x:xmpmeta>');

        if (open_tag != -1) {
          xml_started = true;
          line = line.substring(open_tag);
          // printf('** XMP found opening tag at line position %s', [open_tag]);
        }

        if (close_tag != -1) {
          // printf('** XMP found closing tag at line position %s', [close_tag]);
          int line_offset = 0;
          if (open_tag != -1) {
            line_offset = open_tag;
          }
          line = line.substring(0, (close_tag - line_offset) + 12);
          xml_finished = true;
        }

        if (xml_started) {
          xmp_string += line;
        }

        if (xml_finished) {
          break;
        }
      }

      // print('** XMP Finished searching for info');
      if (xmp_string.isNotEmpty) {
        hdr.parse_xmp(xmp_string);
      }
    }
  }

  return hdr.tags;
}
