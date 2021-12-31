import 'dart:typed_data';

import 'package:exif/src/file_interface.dart';
import 'package:exif/src/util.dart';

class HeicBox {
  final String name;

  int version = 0;
  int minorVersion = 0;
  int itemCount = 0;
  int size = 0;
  int after = 0;
  int pos = 0;
  List compat = [];
  int baseOffset = 0;

  // this is full of boxes, but not in a predictable order.
  Map<String, HeicBox> subs = {};
  Map<int, List<List<int>>> locs = {};
  HeicBox? exifInfe;
  int itemId = 0;
  Uint8List? itemType;
  Uint8List? itemName;
  int itemProtectionIndex = 0;
  Uint8List? majorBrand;
  int offsetSize = 0;
  int lengthSize = 0;
  int baseOffsetSize = 0;
  int indexSize = 0;
  int flags = 0;

  HeicBox(this.name);

  void setSizes(int offset, int length, int baseOffset, int index) {
    offsetSize = offset;
    lengthSize = length;
    baseOffsetSize = baseOffset;
    indexSize = index;
  }

  void setFull(int vflags) {
    /**
        ISO boxes come in 'old' and 'full' variants.
        The 'full' variant contains version and flags information.
     */
    version = vflags >> 24;
    flags = vflags & 0x00ffffff;
  }
}

class HEICExifFinder {
  final FileReader fileReader;

  const HEICExifFinder(this.fileReader);

  Uint8List getBytes(int nbytes) {
    final bytes = fileReader.readSync(nbytes);
    if (bytes.length != nbytes) {
      throw Exception("Bad size");
    }
    return Uint8List.fromList(bytes);
  }

  int getInt(int size) {
    // some fields have variant-sized data.
    if (size == 2) {
      return ByteData.view(getBytes(2).buffer).getInt16(0);
    }
    if (size == 4) {
      return ByteData.view(getBytes(4).buffer).getInt32(0);
    }
    if (size == 8) {
      return ByteData.view(getBytes(8).buffer).getInt64(0);
    }
    if (size == 0) {
      return 0;
    }
    throw Exception("Bad size");
  }

  Uint8List getString() {
    final List<Uint8List> read = [];
    while (true) {
      final char = getBytes(1);
      if (listEqual(char, Uint8List.fromList('\x00'.codeUnits))) {
        break;
      }
      read.add(char);
    }
    return Uint8List.fromList(read.expand((x) => x).toList());
  }

  List<int> getInt4x2() {
    final num = getBytes(1).single;
    final num0 = num >> 4;
    final num1 = num & 0xf;
    return [num0, num1];
  }

  HeicBox nextBox() {
    final pos = fileReader.positionSync();
    int size = ByteData.view(getBytes(4).buffer).getInt32(0);
    final kind = String.fromCharCodes(getBytes(4));
    final box = HeicBox(kind);
    if (size == 0) {
      //  signifies 'to the end of the file', we shouldn't see this.
      throw Exception("Unknown error");
    }
    if (size == 1) {
      // 64-bit size follows type.
      size = ByteData.view(getBytes(8).buffer).getInt64(0);
      box.size = size - 16;
      box.after = pos + size;
    } else {
      box.size = size - 8;
      box.after = pos + size;
    }
    box.pos = fileReader.positionSync();
    return box;
  }

  void _parseFtyp(HeicBox box) {
    box.majorBrand = getBytes(4);
    box.minorVersion = ByteData.view(getBytes(4).buffer).getInt32(0);
    box.compat = [];
    int size = box.size - 8;
    while (size > 0) {
      box.compat.add(getBytes(4));
      size -= 4;
    }
  }

  void _parseMeta(HeicBox meta) {
    meta.setFull(ByteData.view(getBytes(4).buffer).getInt32(0));
    while (fileReader.positionSync() < meta.after) {
      final box = nextBox();
      final psub = getParser(box);
      if (psub != null) {
        psub(box);
        meta.subs[box.name] = box;
      }
      // skip any unparsed data
      fileReader.setPositionSync(box.after);
    }
  }

  void _parseInfe(HeicBox box) {
    box.setFull(ByteData.view(getBytes(4).buffer).getInt32(0));
    if (box.version >= 2) {
      if (box.version == 2) {
        box.itemId = ByteData.view(getBytes(2).buffer).getInt16(0);
      } else if (box.version == 3) {
        box.itemId = ByteData.view(getBytes(4).buffer).getInt32(0);
      }
      box.itemProtectionIndex = ByteData.view(getBytes(2).buffer).getInt16(0);
      box.itemType = getBytes(4);
      box.itemName = getString();
      // ignore the rest
    }
  }

  void _parseIinf(HeicBox box) {
    box.setFull(ByteData.view(getBytes(4).buffer).getInt32(0));
    final count = ByteData.view(getBytes(2).buffer).getInt16(0);
    box.exifInfe = null;
    for (var i = 0; i < count; i += 1) {
      final infe = expectParse('infe');
      if (listEqual(infe.itemType, Uint8List.fromList('Exif'.codeUnits))) {
        box.exifInfe = infe;
        break;
      }
    }
  }

  void _parseIloc(HeicBox box) {
    box.setFull(ByteData.view(getBytes(4).buffer).getInt32(0));
    final size = getInt4x2();
    final size2 = getInt4x2();
    box.setSizes(size[0], size[1], size2[0], size2[1]);
    if (box.version < 2) {
      box.itemCount = ByteData.view(getBytes(2).buffer).getInt16(0);
    } else if (box.version == 2) {
      box.itemCount = ByteData.view(getBytes(4).buffer).getInt32(0);
    } else {
      throw Exception("Box version 2, ${box.version.toString()}");
    }
    box.locs = {};
    for (var i = 0; i < box.itemCount; i += 1) {
      int itemId;
      if (box.version < 2) {
        itemId = ByteData.view(getBytes(2).buffer).getInt16(0);
      } else if (box.version == 2) {
        itemId = ByteData.view(getBytes(4).buffer).getInt32(0);
      } else {
        throw Exception("Box version 2, ${box.version.toString()}");
      }

      if (box.version == 1 || box.version == 2) {
        // ignore construction_method
        ByteData.view(getBytes(2).buffer).getInt16(0);
      }
      // ignore data_reference_index
      ByteData.view(getBytes(2).buffer).getInt16(0);
      box.baseOffset = getInt(box.baseOffsetSize);
      final extentCount = ByteData.view(getBytes(2).buffer).getInt16(0);
      final List<List<int>> extent = [];
      for (var i = 0; i < extentCount; i += 1) {
        if ((box.version == 1 || box.version == 2) && box.indexSize > 0) {
          getInt(box.indexSize);
        }
        final extentOffset = getInt(box.offsetSize);
        final extentLength = getInt(box.lengthSize);
        extent.add([extentOffset, extentLength]);
      }
      box.locs[itemId] = extent;
    }
  }

  void Function(HeicBox)? getParser(HeicBox box) {
    final defs = {
      'ftyp': _parseFtyp,
      'meta': _parseMeta,
      'infe': _parseInfe,
      'iinf': _parseIinf,
      'iloc': _parseIloc,
    };
    return defs[box.name];
  }

  HeicBox parseBox(HeicBox box) {
    final probe = getParser(box);
    if (probe == null) {
      throw Exception('Unhandled box');
    }
    probe(box);
    //  in case anything is left unread
    fileReader.setPositionSync(box.after);
    return box;
  }

  HeicBox expectParse(String name) {
    while (true) {
      final box = nextBox();
      if (box.name == name) {
        return parseBox(box);
      }
      fileReader.setPositionSync(box.after);
    }
  }

  List<int> findExif() {
    final ftyp = expectParse('ftyp');
    assert(listEqual(ftyp.majorBrand, Uint8List.fromList('heic'.codeUnits)));
    assert(ftyp.minorVersion == 0);
    final meta = expectParse('meta');
    final itemId = meta.subs['iinf']?.exifInfe?.itemId;
    if (itemId == null) {
      return [];
    }
    final extents = meta.subs['iloc']?.locs[itemId];
    // we expect the Exif data to be in one piece.
    if (extents == null || extents.length != 1) {
      return [];
    }
    final int pos = extents[0][0];
    // looks like there's a kind of pseudo-box here.
    fileReader.setPositionSync(pos);
    // the payload of "Exif" item may be start with either
    //  b'\xFF\xE1\xSS\xSSExif\x00\x00' (with APP1 marker, e.g. Android Q)
    //  or
    // b'Exif\x00\x00' (without APP1 marker, e.g. iOS)
    // according to "ISO/IEC 23008-12, 2017-12", both of them are legal
    final exifTiffHeaderOffset = ByteData.view(getBytes(4).buffer).getInt32(0);
    assert(exifTiffHeaderOffset >= 6);
    getBytes(exifTiffHeaderOffset);
    // assert self.get(exif_tiff_header_offset)[-6:] == b'Exif\x00\x00'
    final offset = fileReader.positionSync();
    final endian = fileReader.readSync(1)[0];
    return [offset, endian];
  }
}
