import 'dart:typed_data';

import 'package:exif/src/exif_types.dart';
import 'package:exif/src/field_types.dart';
import 'package:exif/src/file_interface.dart';
import 'package:exif/src/makernote_canon.dart';
import 'package:exif/src/util.dart';

enum Endian {
  little,
  big,
}

class Reader {
  FileReader file;
  int baseOffset;
  Endian endian;

  Reader(this.file, this.baseOffset, this.endian);

  List<int> readSlice(int relativePos, int length) {
    file.setPositionSync(baseOffset + relativePos);
    return file.readSync(length);
  }

  // Convert slice to integer, based on sign and endian flags.
  // Usually this offset is assumed to be relative to the beginning of the
  // start of the EXIF information.
  // For some cameras that use relative tags, this offset may be relative
  // to some other starting point.
  int readInt(int offset, int length, {bool signed = false}) {
    final sliced = readSlice(offset, length);
    int val;

    if (endian == Endian.little) {
      val = s2nLittleEndian(sliced, signed: signed);
    } else {
      val = s2nBigEndian(sliced, signed: signed);
    }

    return val;
  }

  Ratio readRatio(int offset, {required bool signed}) {
    final n = readInt(offset, 4, signed: signed);
    final d = readInt(offset + 4, 4, signed: signed);
    return Ratio(n, d);
  }

  // Convert offset to string.
  List<int> offsetToBytes(int _readOffset, int length) {
    var readOffset = _readOffset;
    final List<int> s = [];
    for (int dummy = 0; dummy < length; dummy++) {
      if (endian == Endian.little) {
        s.add(readOffset & 0xFF);
      } else {
        s.insert(0, readOffset & 0xFF);
      }
      readOffset = readOffset >> 8;
    }
    return s;
  }

  static Endian endianOfByte(int b) {
    if (b == 'I'.codeUnitAt(0)) {
      return Endian.little;
    }
    return Endian.big;
  }
}

class IfdReader {
  Reader file;
  final bool fakeExif;

  IfdReader(this.file, {required this.fakeExif});

  // Return first IFD.
  int _firstIfd() => file.readInt(4, 4);

  // Return the pointer to next IFD.
  int _nextIfd(int ifd) {
    final entries = file.readInt(ifd, 2);
    final nextIfd = file.readInt(ifd + 2 + 12 * entries, 4);
    if (nextIfd == ifd) {
      return 0;
    } else {
      return nextIfd;
    }
  }

  // Return the list of IFDs in the header.
  List<int> listIfd() {
    int i = _firstIfd();
    final List<int> ifds = [];
    while (i > 0) {
      ifds.add(i);
      i = _nextIfd(i);
    }
    return ifds;
  }

  List<IfdEntry> readIfdEntries(int ifd, {required bool relative}) {
    final numEntries = file.readInt(ifd, 2);

    return List<IfdEntry>.generate(numEntries, (i) {
      // entry is index of start of this IFD in the file
      final offset = ifd + 2 + 12 * i;
      final tag = file.readInt(offset, 2);
      final fieldType = FieldType.ofValue(file.readInt(offset + 2, 2));
      final count = file.readInt(offset + 4, 4);

      final typeLength = fieldType.length;

      // Adjust for tag id/type/count (2+2+4 bytes)
      // Now we point at either the data or the 2nd level offset
      int fieldOffset = offset + 8;

      // If the value fits in 4 bytes, it is inlined, else we
      // need to jump ahead again.
      if (count * typeLength > 4) {
        // offset is not the value; it's a pointer to the value
        // if relative we set things up so s2n will seek to the right
        // place when it adds this.offset.  Note that this 'relative'
        // is for the Nikon type 3 makernote.  Other cameras may use
        // other relative offsets, which would have to be computed here
        // slightly differently.
        if (relative) {
          fieldOffset = file.readInt(fieldOffset, 4) + ifd - 8;
          if (fakeExif) {
            fieldOffset += 18;
          }
        } else {
          fieldOffset = file.readInt(fieldOffset, 4);
        }
      }

      return IfdEntry(
          fieldOffset: fieldOffset,
          tag: tag,
          fieldType: fieldType,
          count: count);
    });
  }

  Endian get endian => file.endian;

  set endian(Endian e) {
    file.endian = e;
  }

  int get baseOffset => file.baseOffset;

  set baseOffset(int v) {
    file.baseOffset = v;
  }

  int readInt(int offset, int length, {bool signed = false}) {
    return file.readInt(offset, length, signed: signed);
  }

  List<int> readSlice(int relativePos, int length) {
    return file.readSlice(relativePos, length);
  }

  IfdRatios _readIfdRatios(IfdEntry entry) {
    final List<Ratio> values = [];
    var pos = entry.fieldOffset;
    for (int dummy = 0; dummy < entry.count; dummy++) {
      values.add(file.readRatio(pos, signed: entry.fieldType.isSigned));
      pos += entry.fieldType.length;
    }
    return IfdRatios(values);
  }

  IfdInts _readIfdInts(IfdEntry entry) {
    final List<int> values = [];
    var pos = entry.fieldOffset;
    for (int dummy = 0; dummy < entry.count; dummy++) {
      values.add(file.readInt(pos, entry.fieldType.length,
          signed: entry.fieldType.isSigned));
      pos += entry.fieldType.length;
    }
    return IfdInts(values);
  }

  IfdBytes _readAscii(IfdEntry entry) {
    var count = entry.count;
    // special case: null-terminated ASCII string
    // XXX investigate
    // sometimes gets too big to fit in int value
    if (count <= 0) {
      return IfdBytes.empty();
    }

    if (count > 1024 * 1024) {
      count = 1024 * 1024;
    }

    try {
      // and count < (2**31))  // 2E31 is hardware dependant. --gd
      var values = file.readSlice(entry.fieldOffset, count);
      // Drop any garbage after a null.
      final i = values.indexOf(0);
      if (i >= 0) {
        values = values.sublist(0, i);
      }
      return IfdBytes(Uint8List.fromList(values));
    } catch (e) {
      // warnings.add("exception($e) at position: $filePosition, length: $count");
      return IfdBytes.empty();
    }
  }

  IfdValues readField(IfdEntry entry, {required String tagName}) {
    if (entry.fieldType == FieldType.ascii) {
      return _readAscii(entry);
    }

    // XXX investigate
    // some entries get too big to handle could be malformed
    // file or problem with this.s2n
    if (entry.count < 1000) {
      if (entry.fieldType == FieldType.ratio ||
          entry.fieldType == FieldType.signedRatio) {
        return _readIfdRatios(entry);
      } else {
        return _readIfdInts(entry);
      }
      // The test above causes problems with tags that are
      // supposed to have long values! Fix up one important case.
    } else if (tagName == 'MakerNote' ||
        tagName == MakerNoteCanon.cameraInfoTagName) {
      return _readIfdInts(entry);
    }
    return const IfdNone();
  }

  List<int> offsetToBytes(int _readOffset, int length) {
    return file.offsetToBytes(_readOffset, length);
  }
}

class IfdEntry {
  final int fieldOffset;
  final int tag;
  final FieldType fieldType;
  final int count;

  IfdEntry({
    required this.fieldOffset,
    required this.tag,
    required this.fieldType,
    required this.count,
  });
}
