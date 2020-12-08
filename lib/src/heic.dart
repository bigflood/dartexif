import 'dart:typed_data';

import 'file_interface.dart';
import 'util.dart';

class HeicBox {
  final String name;

  int version = 0;
  int minor_version = 0;
  int item_count = 0;
  int size = 0;
  int after = 0;
  int pos = 0;
  List compat = [];
  int base_offset = 0;
  // this is full of boxes, but not in a predictable order.
  Map<String, HeicBox> subs = {};
  Map locs = {};
  dynamic exif_infe;
  int item_id = 0;
  Uint8List? item_type;
  Uint8List? item_name;
  int item_protection_index = 0;
  Uint8List? major_brand;
  int offset_size = 0;
  int length_size = 0;
  int base_offset_size = 0;
  int index_size = 0;
  int flags = 0;

  HeicBox(this.name);

  void setSizes(offset, length, base_offset, index) {
    offset_size = offset;
    length_size = length;
    base_offset_size = base_offset;
    index_size = index;
  }

  void setFull(vflags) {
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
      throw new Exception("Bad size");
    }
    return Uint8List.fromList(bytes);
  }

  int getInt(size) {
    // some fields have variant-sized data.
    if (size == 2) {
      return new ByteData.view(getBytes(2).buffer).getInt16(0);
    }
    if (size == 4) {
      return new ByteData.view(getBytes(4).buffer).getInt32(0);
    }
    if (size == 8) {
      return new ByteData.view(getBytes(8).buffer).getInt64(0);
    }
    if (size == 0) {
      return 0;
    }
    throw new Exception("Bad size");
  }

  Uint8List getString() {
    List<Uint8List> read = [];
    while (true) {
      final char = getBytes(1);
      if (list_eq(char, Uint8List.fromList('\x00'.codeUnits))) {
        break;
      }
      read.add(char);
    }
    return Uint8List.fromList(read.expand((x) => x).toList());
  }

  List get_int4x2() {
    final num = getBytes(1).single;
    final num0 = num >> 4;
    final num1 = num & 0xf;
    return [num0, num1];
  }

  HeicBox nextBox() {
    final pos = fileReader.positionSync();
    int size = new ByteData.view(getBytes(4).buffer).getInt32(0);
    final kind = new String.fromCharCodes(getBytes(4));
    final box = HeicBox(kind);
    if (size == 0) {
      //  signifies 'to the end of the file', we shouldn't see this.
      throw new Exception("Unknown error");
    }
    if (size == 1) {
      // 64-bit size follows type.
      size = new ByteData.view(getBytes(8).buffer).getInt64(0);
      box.size = size - 16;
      box.after = pos + size;
    } else {
      box.size = size - 8;
      box.after = pos + size;
    }
    box.pos = fileReader.positionSync();
    return box;
  }

  void _parse_ftyp(box) {
    box.major_brand = getBytes(4);
    box.minor_version = new ByteData.view(getBytes(4).buffer).getInt32(0);
    box.compat = [];
    int size = box.size - 8;
    while (size > 0) {
      box.compat.add(getBytes(4));
      size -= 4;
    }
  }

  void _parse_meta(HeicBox meta) {
    meta.setFull(new ByteData.view(getBytes(4).buffer).getInt32(0));
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

  void _parse_infe(HeicBox box) {
    box.setFull(new ByteData.view(getBytes(4).buffer).getInt32(0));
    if (box.version >= 2) {
      if (box.version == 2) {
        box.item_id = new ByteData.view(getBytes(2).buffer).getInt16(0);
      } else if (box.version == 3) {
        box.item_id = new ByteData.view(getBytes(4).buffer).getInt32(0);
      }
      box.item_protection_index =
          new ByteData.view(getBytes(2).buffer).getInt16(0);
      box.item_type = getBytes(4);
      box.item_name = getString();
      // ignore the rest
    }
  }

  void _parse_iinf(HeicBox box) {
    box.setFull(new ByteData.view(getBytes(4).buffer).getInt32(0));
    final count = new ByteData.view(getBytes(2).buffer).getInt16(0);
    box.exif_infe = null;
    for (var i = 0; i < count; i += 1) {
      final infe = expectParse('infe');
      if (list_eq(infe.item_type, Uint8List.fromList('Exif'.codeUnits))) {
        box.exif_infe = infe;
        break;
      }
    }
  }

  void _parse_iloc(HeicBox box) {
    box.setFull(new ByteData.view(getBytes(4).buffer).getInt32(0));
    final size = get_int4x2();
    final size2 = get_int4x2();
    box.setSizes(size[0], size[1], size2[0], size2[1]);
    if (box.version < 2) {
      box.item_count = new ByteData.view(getBytes(2).buffer).getInt16(0);
    } else if (box.version == 2) {
      box.item_count = new ByteData.view(getBytes(4).buffer).getInt32(0);
    } else {
      throw new Exception("Box version 2, " + box.version.toString());
    }
    box.locs = {};
    for (var i = 0; i < box.item_count; i += 1) {
      var item_id;
      if (box.version < 2) {
        item_id = new ByteData.view(getBytes(2).buffer).getInt16(0);
      } else if (box.version == 2) {
        item_id = new ByteData.view(getBytes(4).buffer).getInt32(0);
      } else {
        throw new Exception("Box version 2, " + box.version.toString());
      }

      if (box.version == 1 || box.version == 2) {
        // ignore construction_method
        new ByteData.view(getBytes(2).buffer).getInt16(0);
      }
      // ignore data_reference_index
      new ByteData.view(getBytes(2).buffer).getInt16(0);
      box.base_offset = getInt(box.base_offset_size);
      final extent_count = new ByteData.view(getBytes(2).buffer).getInt16(0);
      final extent = [];
      for (var i = 0; i < extent_count; i += 1) {
        if ((box.version == 1 || box.version == 2) && box.index_size > 0) {
          getInt(box.index_size);
        }
        final extent_offset = getInt(box.offset_size);
        final extent_length = getInt(box.length_size);
        extent.add([extent_offset, extent_length]);
      }
      box.locs[item_id] = extent;
    }
  }

  Function? getParser(box) {
    final defs = {
      'ftyp': _parse_ftyp,
      'meta': _parse_meta,
      'infe': _parse_infe,
      'iinf': _parse_iinf,
      'iloc': _parse_iloc,
    };
    return defs[box.name];
  }

  HeicBox parseBox(box) {
    final Function? probe = getParser(box);
    if (probe == null) {
      throw new Exception('Unhandled box');
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

  List findExif() {
    final ftyp = expectParse('ftyp');
    assert(list_eq(ftyp.major_brand, Uint8List.fromList('heic'.codeUnits)));
    assert(ftyp.minor_version == 0);
    final meta = expectParse('meta');
    assert(meta.subs['iinf']!.exif_infe != null);
    final item_id = meta.subs['iinf']!.exif_infe.item_id;
    final extents = meta.subs['iloc']!.locs[item_id];
    // we expect the Exif data to be in one piece.
    assert(extents.length == 1);
    final pos = extents[0][0];
    // looks like there's a kind of pseudo-box here.
    fileReader.setPositionSync(pos);
    // the payload of "Exif" item may be start with either
    //  b'\xFF\xE1\xSS\xSSExif\x00\x00' (with APP1 marker, e.g. Android Q)
    //  or
    // b'Exif\x00\x00' (without APP1 marker, e.g. iOS)
    // according to "ISO/IEC 23008-12, 2017-12", both of them are legal
    final exif_tiff_header_offset =
        new ByteData.view(getBytes(4).buffer).getInt32(0);
    assert(exif_tiff_header_offset >= 6);
    getBytes(exif_tiff_header_offset);
    // assert self.get(exif_tiff_header_offset)[-6:] == b'Exif\x00\x00'
    final offset = fileReader.positionSync();
    final endian = fileReader.readSync(1)[0];
    return [offset, endian];
  }
}
