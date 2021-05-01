import 'dart:convert';

import 'package:sprintf/sprintf.dart' show sprintf;

import 'exif_types.dart';
import 'file_interface.dart';
import 'makernote_apple.dart';
import 'makernote_canon.dart';
import 'makernote_casio.dart';
import 'makernote_fujifilm.dart';
import 'makernote_nikon.dart';
import 'makernote_olympus.dart';
import 'tags.dart';
import 'tags_info.dart';
import 'util.dart';

const defaultStopTag = 'UNDEF';

class FieldType {
  final int length;
  final String abbr;
  final String name;

  const FieldType(this.length, this.abbr, this.name);
}

// field type descriptions as (length, abbreviation, full name) tuples
const fieldTypes = [
  FieldType(0, 'X', 'Proprietary'), // no such type
  FieldType(1, 'B', 'Byte'),
  FieldType(1, 'A', 'ASCII'),
  FieldType(2, 'S', 'Short'),
  FieldType(4, 'L', 'Long'),
  FieldType(8, 'R', 'Ratio'),
  FieldType(1, 'SB', 'Signed Byte'),
  FieldType(1, 'U', 'Undefined'),
  FieldType(2, 'SS', 'Signed Short'),
  FieldType(4, 'SL', 'Signed Long'),
  FieldType(8, 'SR', 'Signed Ratio'),
  FieldType(4, 'F32', 'Single-Precision Floating Point (32-bit)'),
  FieldType(8, 'F64', 'Double-Precision Floating Point (64-bit)'),
  FieldType(4, 'L', 'IFD'),
];

// To ignore when quick processing
const ignoreTags = [
  0x9286, // user comment
  0x927C, // MakerNote Tags
  0x02BC, // XPM
];

// Eases dealing with tags.
class IfdTagImpl extends IfdTag {
  // printable version of data
  String? _printable;

  @override
  String? get printable => _printable;

  // tag ID number
  int? _tag;

  @override
  int? get tag => _tag;

  // field type as index into FIELD_TYPES
  int fieldType;

  @override
  String get tagType => fieldTypes[fieldType].name;

  // offset of start of field in bytes from beginning of IFD
  int fieldOffset;

  // length of data field in bytes
  int fieldLength;

  // list of data items (int(char or number) or Ratio)
  List? _values;

  @override
  List? get values => _values;

  IfdTagImpl(
      {String? printable = '',
      int tag = -1,
      this.fieldType = 0,
      List? values,
      this.fieldOffset = 0,
      this.fieldLength = 0}) {
    _printable = printable;
    _tag = tag;
    _values = values;
  }

  @override
  String toString() => printable!;

  String get repr => sprintf('(0x%04X) %s=%s @ %d',
      [tag, fieldTypes[fieldType].name, printable, fieldOffset]);
}

// Handle an EXIF header.
class ExifHeader {
  FileReader file;
  int endian;
  int offset;
  bool fakeExif;
  bool strict;
  bool debug;
  bool detailed;
  bool truncateTags;
  Map<String?, IfdTag> tags = {};
  List<String> warnings = [];

  ExifHeader({
    required this.file,
    required this.endian,
    required this.offset,
    required this.fakeExif,
    required this.strict,
    this.debug = false,
    this.detailed = true,
    this.truncateTags = true,
  });

  // Convert slice to integer, based on sign and endian flags.
  // Usually this offset is assumed to be relative to the beginning of the
  // start of the EXIF information.
  // For some cameras that use relative tags, this offset may be relative
  // to some other starting point.
  int s2n(int offset, int length, {bool signed = false}) {
    file.setPositionSync(this.offset + offset);
    final sliced = file.readSync(length);
    int val;

    if (endian == 'I'.codeUnitAt(0)) {
      val = s2nLittleEndian(sliced, signed: signed);
    } else {
      val = s2nBigEndian(sliced, signed: signed);
    }

    return val;
  }

  // Convert offset to string.
  List<int> n2s(int _readOffset, int length) {
    var readOffset = _readOffset;
    final List<int> s = [];
    for (int dummy = 0; dummy < length; dummy++) {
      if (endian == 'I'.codeUnitAt(0)) {
        s.add(readOffset & 0xFF);
      } else {
        s.insert(0, readOffset & 0xFF);
      }
      readOffset = readOffset >> 8;
    }
    return s;
  }

  // Return first IFD.
  int _firstIfd() => s2n(4, 4);

  // Return the pointer to next IFD.
  int _nextIfd(int ifd) {
    final entries = s2n(ifd, 2);
    final nextIfd = s2n(ifd + 2 + 12 * entries, 4);
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

  // Return a list of entries in the given IFD.
  void dumpIfd(int ifd, String ifdName,
      {Map<int, MakerTag>? tagDict, bool relative = false, String? stopTag}) {
    stopTag ??= defaultStopTag;
    tagDict ??= StandardTags.tags;

    // print('** ifd_name $ifd_name');

    // make sure we can process the entries
    int entries;
    try {
      entries = s2n(ifd, 2);
    } catch (e) {
      printf("Possibly corrupted IFD: %s", [ifd]);
      return;
    }

    for (int i = 0; i < entries; i++) {
      // entry is index of start of this IFD in the file
      final entry = ifd + 2 + 12 * i;
      final tag = s2n(entry, 2);

      //print('** tag=$tag');

      // get tag name early to avoid errors, help debug
      final MakerTag? tagEntry = tagDict[tag];
      String tagName;
      if (tagEntry != null) {
        tagName = tagEntry.name;
      } else {
        tagName = sprintf('Tag 0x%04X', [tag]);
      }

      // print('** ifd=$ifd_name tag=$tag_name ($tag)');

      // ignore certain tags for faster processing
      if (detailed || !ignoreTags.contains(tag)) {
        processTag(
            ifd: ifd,
            ifdName: ifdName,
            tagEntry: tagEntry,
            entry: entry,
            tag: tag,
            tagName: tagName,
            relative: relative,
            stopTag: stopTag);

        if (tagName == stopTag) {
          break;
        }
      }
    }
  }

  void processTag(
      {required int ifd,
      required String ifdName,
      required MakerTag? tagEntry,
      required int entry,
      required int tag,
      required String tagName,
      required bool relative,
      required String? stopTag}) {
    final fieldType = s2n(entry + 2, 2);

    // unknown field type
    if (fieldType <= 0 || fieldType >= fieldTypes.length) {
      //print('** ifd=$ifd_name tag=$tag_name field_type=$field_type');

      if (!strict) {
        return;
      } else {
        throw FormatException(
            sprintf('Unknown type %d in tag 0x%04X', [fieldType, tag]));
      }
    }

    final typeLength = fieldTypes[fieldType].length;
    final count = s2n(entry + 4, 4);

    // print('** ifd=$ifd_name tag=$tag_name type=${FIELD_TYPES[field_type]}  len=$type_length, count=$count');

    // Adjust for tag id/type/count (2+2+4 bytes)
    // Now we point at either the data or the 2nd level offset
    int offset = entry + 8;
    // print('** offset=$offset');

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
        final tmpOffset = s2n(offset, 4);
        offset = tmpOffset + ifd - 8;
        if (fakeExif) {
          offset += 18;
        }
      } else {
        offset = s2n(offset, 4);
      }
    }

    final fieldOffset = offset;
    // print('** fieldOffset=$fieldOffset, field_type=$field_type');

    List values = [];
    if (fieldType == 2) {
      values = processAsciiField(ifdName, tagName, count, offset);
    } else {
      values = processField(tagName, count, fieldType, typeLength, offset);
    }

    // print('** values[${values.length}]=$values');

    // now 'values' is either a string or an array
    var printable =
        toPrintableString(values, ifdName, tagName, count, fieldType);

    // compute printable version of values
    if (tagEntry != null) {
      // optional 2nd tag element is present
      if (tagEntry.func != null) {
        // call mapping function
        printable = tagEntry.func!(values.whereType<int>().toList())!;
      } else if (tagEntry.tags != null) {
        try {
          // print('** ${tag_entry.tags.name} SubIFD at offset ${values[0]}:');
          dumpIfd(values[0] as int, tagEntry.tags!.name,
              tagDict: tagEntry.tags!.tags, stopTag: stopTag);
        } on RangeError {
          warnings.add('No values found for ${tagEntry.tags!.name} SubIFD');
        }
      } else if (tagEntry.map != null) {
        final sb = StringBuffer();
        for (final i in values) {
          // use lookup table for this tag
          sb.write(tagEntry.map![i as int] ?? i);
        }
        printable = sb.toString();
      }
    }

    // print('** ifd=$ifd_name tag=$tag_name ($tag) field_type=$field_type, type_length=$type_length, count=$count');

    tags['$ifdName $tagName'] = IfdTagImpl(
        printable: printable,
        tag: tag,
        fieldType: fieldType,
        values: values,
        fieldOffset: fieldOffset,
        fieldLength: count * typeLength);

    // var t = tags[ifd_name + ' ' + tag_name];
    // print('**  "$ifd_name $tag_name": str=$t ${FIELD_TYPES[t.field_type]} @${t.field_offset} len=${t.field_length}');
  }

  String toPrintableString(List<dynamic> values, String ifdName, String tagName,
      int count, int fieldType) {
    if (fieldTypes[fieldType].name == "ASCII") {
      final bytes = values.whereType<int>().toList();
      try {
        return utf8.decode(bytes);
      } catch (e) {
        warnings.add("Possibly corrupted field $tagName in $ifdName IFD");
        if (truncateTags && bytes.length > 20) {
          return 'b"${bytesToStringRepr(bytes.sublist(0, 20))}, ... ]';
        }
        return "b'${bytesToStringRepr(bytes)}'";
      }
    }

    if (count == 1 && fieldType != 2) {
      return values[0].toString();
    } else if (count > 50 && values.length > 20) {
      if (truncateTags) {
        final s = values.sublist(0, 20).toString();
        return "${s.substring(0, s.length - 1)}, ... ]";
      }
    }

    return values.toString();
  }

  String bytesToStringRepr(List<int> bytes) => bytes.map((e) {
        switch (e) {
          case 9:
            return r'\t';
          case 10:
            return r'\n';
          case 13:
            return r'\r';
          case 92:
            return r'\\';
        }

        if (e < 32 || e >= 128) {
          final hex = e.toRadixString(16).padLeft(2, '0');
          return "\\x$hex";
        }

        return String.fromCharCode(e);
      }).join();

  List processAsciiField(
      String ifdName, String tagName, int _count, int offset) {
    var count = _count;
    // special case: null-terminated ASCII string
    // XXX investigate
    // sometimes gets too big to fit in int value
    if (count <= 0) {
      return [];
    }

    if (count > 1024 * 1024) {
      count = 1024 * 1024;
    }
    final int filePosition = this.offset + offset;

    try {
      // and count < (2**31))  // 2E31 is hardware dependant. --gd
      file.setPositionSync(filePosition);
      var values = file.readSync(count);
      // Drop any garbage after a null.
      final i = values.indexOf(0);
      if (i >= 0) {
        values = values.sublist(0, i);
      }
      return values;
    } catch (e) {
      warnings.add("exception($e) at position: $filePosition, length: $count");
      return [];
    }
  }

  List processField(String tagName, int count, int fieldType, int typeLength,
      int _fieldOffset) {
    var fieldOffset = _fieldOffset;
    final List values = [];
    // print('** field_type $field_type ${FIELD_TYPES[field_type]}');
    // print('** count ${count}');

    final signed = [6, 8, 9, 10].contains(fieldType);
    // print('** signed=$signed');

    // XXX investigate
    // some entries get too big to handle could be malformed
    // file or problem with this.s2n
    if (count < 1000) {
      for (int dummy = 0; dummy < count; dummy++) {
        if (fieldType == 5 || fieldType == 10) {
          // a ratio
          final n = s2n(fieldOffset, 4, signed: signed);
          final d = s2n(fieldOffset + 4, 4, signed: signed);
          final r = Ratio(n, d);
          values.add(r);
        } else {
          values.add(s2n(fieldOffset, typeLength, signed: signed));
        }
        fieldOffset += typeLength;
      }
      // The test above causes problems with tags that are
      // supposed to have long values! Fix up one important case.
    } else if (tagName == 'MakerNote' ||
        tagName == MakerNoteCanon.cameraInfoTagName) {
      for (int dummy = 0; dummy < count; dummy++) {
        final value = s2n(fieldOffset, typeLength, signed: signed);
        values.add(value);
        fieldOffset += typeLength;
      }
    }
    return values;
  }

  // Extract uncompressed TIFF thumbnail.
  // Take advantage of the pre-existing layout in the thumbnail IFD as
  // much as possible
  void extractTiffThumbnail(int thumbIfd) {
    final thumb = tags['Thumbnail Compression'] as IfdTagImpl?;
    if (thumb == null || thumb.printable != 'Uncompressed TIFF') {
      return;
    }

    List<int> tiff;
    int stripOff = 0, stripLen = 0;

    final entries = s2n(thumbIfd, 2);
    // this is header plus offset to IFD ...
    if (endian == 'M'.codeUnitAt(0)) {
      tiff = 'MM\x00*\x00\x00\x00\x08'.codeUnits;
    } else {
      tiff = 'II*\x00\x08\x00\x00\x00'.codeUnits;
      // ... plus thumbnail IFD data plus a null "next IFD" pointer
    }

    file.setPositionSync(offset + thumbIfd);
    tiff.addAll(file.readSync(entries * 12 + 2));
    tiff.addAll([0, 0, 0, 0]);

    // fix up large value offset pointers into data area
    for (int i = 0; i < entries; i++) {
      final entry = thumbIfd + 2 + 12 * i;
      final tag = s2n(entry, 2);
      final fieldType = s2n(entry + 2, 2);
      final typeLength = fieldTypes[fieldType].length;
      final count = s2n(entry + 4, 4);
      final oldOffset = s2n(entry + 8, 4);
      // start of the 4-byte pointer area in entry
      final ptr = i * 12 + 18;
      // remember strip offsets location
      if (tag == 0x0111) {
        stripOff = ptr;
        stripLen = count * typeLength;
        // is it in the data area?
      }
      if (count * typeLength > 4) {
        // update offset pointer (nasty "strings are immutable" crap)
        // should be able to say "tiff[ptr:ptr+4]=newOffset"
        final tiff0 = tiff;
        final newOffset = tiff0.length;
        tiff = tiff0.sublist(0, ptr);
        tiff.addAll(n2s(newOffset, 4));
        tiff.addAll(tiff0.sublist(ptr + 4));
        // remember strip offsets location
        if (tag == 0x0111) {
          stripOff = newOffset;
          stripLen = 4;
        }
        // get original data and store it
        file.setPositionSync(offset + oldOffset);
        tiff.addAll(file.readSync(count * typeLength));
      }
    }

    // add pixel strips and update strip offset info
    final oldOffsets = tags['Thumbnail StripOffsets']!.values!;
    final oldCounts = tags['Thumbnail StripByteCounts']!.values;
    for (int i = 0; i < oldOffsets.length; i++) {
      // update offset pointer (more nasty "strings are immutable" crap)
      final tiff0 = tiff;
      final offset = n2s(tiff0.length, stripLen);
      tiff = tiff0.sublist(0, stripOff);
      tiff.addAll(offset);
      tiff.addAll(tiff0.sublist(stripOff + stripLen));
      stripOff += stripLen;
      // add pixel strip to end
      file.setPositionSync(this.offset + (oldOffsets[i] as int));
      tiff.addAll(file.readSync(oldCounts![i] as int));
    }

    tags['TIFFThumbnail'] = IfdTagImpl(values: tiff);
  }

  // Extract JPEG thumbnail.
  // (Thankfully the JPEG data is stored as a unit.)
  void extractJpegThumbnail() {
    var thumbOffset = tags['Thumbnail JPEGInterchangeFormat'] as IfdTagImpl?;
    if (thumbOffset != null) {
      file.setPositionSync(offset + (thumbOffset.values![0] as int));
      final size =
          tags['Thumbnail JPEGInterchangeFormatLength']!.values![0] as int;
      tags['JPEGThumbnail'] = IfdTagImpl(values: file.readSync(size));
    }

    // Sometimes in a TIFF file, a JPEG thumbnail is hidden in the MakerNote
    // since it's not allowed in a uncompressed TIFF IFD
    if (!tags.containsKey('JPEGThumbnail')) {
      thumbOffset = tags['MakerNote JPEGThumbnail'] as IfdTagImpl?;
      if (thumbOffset != null) {
        file.setPositionSync(offset + (thumbOffset.values![0] as int));
        tags['JPEGThumbnail'] =
            IfdTagImpl(values: file.readSync(thumbOffset.fieldLength));
      }
    }
  }

  // Decode all the camera-specific MakerNote formats
  // Note is the data that comprises this MakerNote.
  // The MakerNote will likely have pointers in it that point to other
  // parts of the file. We'll use this.offset as the starting point for
  // most of those pointers, since they are relative to the beginning
  // of the file.
  // If the MakerNote is in a newer format, it may use relative addressing
  // within the MakerNote. In that case we'll use relative addresses for
  // the pointers.
  // As an aside: it's not just to be annoying that the manufacturers use
  // relative offsets.  It's so that if the makernote has to be moved by the
  // picture software all of the offsets don't have to be adjusted.  Overall,
  // this is probably the right strategy for makernotes, though the spec is
  // ambiguous.
  // The spec does not appear to imagine that makernotes would
  // follow EXIF format internally.  Once they did, it's ambiguous whether
  // the offsets should be from the header at the start of all the EXIF info,
  // or from the header at the start of the makernote.
  void decodeMakerNote() {
    final note = tags['EXIF MakerNote'] as IfdTagImpl?;

    // Some apps use MakerNote tags but do not use a format for which we
    // have a description, so just do a raw dump for these.
    final make = tags['Image Make']!.printable!;

    // print('** make=$make');

    // Nikon
    // The maker note usually starts with the word Nikon, followed by the
    // type of the makernote (1 or 2, as a short).  If the word Nikon is
    // not at the start of the makernote, it's probably type 2, since some
    // cameras work that way.
    if (make.contains('NIKON')) {
      if (listEqual(
          note!.values!.sublist(0, 7), [78, 105, 107, 111, 110, 0, 1])) {
        //print("Looks like a type 1 Nikon MakerNote.");
        dumpIfd(note.fieldOffset + 8, 'MakerNote',
            tagDict: MakerNoteNikon.tagsOld);
      } else if (listEqual(
          note.values!.sublist(0, 7), [78, 105, 107, 111, 110, 0, 2])) {
        //print("Looks like a labeled type 2 Nikon MakerNote");
        if (!listEqual(note.values!.sublist(12, 14), [0, 42]) &&
            !listEqual(note.values!.sublist(12, 14), [42, 0])) {
          throw const FormatException("Missing marker tag '42' in MakerNote.");
          // skip the Makernote label and the TIFF header
        }
        dumpIfd(note.fieldOffset + 10 + 8, 'MakerNote',
            tagDict: MakerNoteNikon.tagsNew, relative: true);
      } else {
        // E99x or D1
        //print("Looks like an unlabeled type 2 Nikon MakerNote");
        dumpIfd(note.fieldOffset, 'MakerNote', tagDict: MakerNoteNikon.tagsNew);
      }
      return;
    }

    // Olympus
    if (make.startsWith('OLYMPUS')) {
      dumpIfd(note!.fieldOffset + 8, 'MakerNote',
          tagDict: MakerNoteOlympus.tags);
      // TODO
      //for i in (('MakerNote Tag 0x2020', makernote.OLYMPUS_TAG_0x2020),):
      //    this.decode_olympus_tag(tags[i[0]].values, i[1])
      //return
    }

    // Casio
    if (make.contains('CASIO') || make.contains('Casio')) {
      dumpIfd(note!.fieldOffset, 'MakerNote', tagDict: MakerNoteCasio.tags);
      return;
    }

    // Fujifilm
    if (make == 'FUJIFILM') {
      // bug: everything else is "Motorola" endian, but the MakerNote
      // is "Intel" endian
      final originalEndian = endian;
      final originalOffset = offset;

      endian = 'I'.codeUnitAt(0);
      // bug: IFD offsets are from beginning of MakerNote, not
      // beginning of file header
      offset += note!.fieldOffset;
      // process note with bogus values (note is actually at offset 12)
      dumpIfd(12, 'MakerNote', tagDict: MakerNoteFujifilm.tags);

      // reset to correct values
      endian = originalEndian;
      offset = originalOffset;
      return;
    }

    // Apple
    if (make == 'Apple' &&
        listEqual(note!.values!.sublist(0, 10),
            [65, 112, 112, 108, 101, 32, 105, 79, 83, 0])) {
      final originalOffset = offset;
      offset += note.fieldOffset + 14;
      dumpIfd(0, 'MakerNote', tagDict: MakerNoteApple.tags);
      offset = originalOffset;
      return;
    }

    // Canon
    if (make == 'Canon') {
      dumpIfd(note!.fieldOffset, 'MakerNote', tagDict: MakerNoteCanon.tags);

      MakerNoteCanon.tagsXxx.forEach((name, makerTags) {
        if (tags.containsKey(name)) {
          _canonDecodeTag(
              tags[name]!.values!.whereType<int>().toList(), makerTags);
          tags.remove(name);
        }
      });

      if (tags.containsKey(MakerNoteCanon.cameraInfoTagName)) {
        final tag = tags[MakerNoteCanon.cameraInfoTagName] as IfdTagImpl?;
        _canonDecodeCameraInfo(tag);
        tags.remove(MakerNoteCanon.cameraInfoTagName);
      }

      return;
    }
  }

  // TODO Decode Olympus MakerNote tag based on offset within tag
  // void _olympus_decode_tag(List<int> value, mn_tags) {}

  // Decode Canon MakerNote tag based on offset within tag.
  // See http://www.burren.cx/david/canon.html by David Burren
  void _canonDecodeTag(List<int> value, Map<int, MakerTag> mnTags) {
    for (int i = 1; i < value.length; i++) {
      final tag = mnTags[i] ?? MakerTag.make('Unknown');
      final name = tag.name;
      String val;
      if (tag.map != null) {
        val = tag.map![value[i]] ?? 'Unknown';
      } else {
        val = value[i].toString();
      }

      // print("** canon decode tag - $i $name ${value[i]}");

      // it's not a real IFD Tag but we fake one to make everybody
      // happy. this will have a "proprietary" type
      tags['MakerNote $name'] = IfdTagImpl(printable: val);
    }
  }

  // Decode the variable length encoded camera info section.
  void _canonDecodeCameraInfo(IfdTagImpl? cameraInfoTag) {
    final modelTag = tags['Image Model'] as IfdTagImpl?;
    if (modelTag == null) {
      return;
    }

    final model = modelTag.values.toString();

    Map<int, CameraInfo>? cameraInfoTags;
    for (final modelNameRegExp in MakerNoteCanon.cameraInfoModelMap.keys) {
      final tagDesc = MakerNoteCanon.cameraInfoModelMap[modelNameRegExp];
      if (RegExp(modelNameRegExp).hasMatch(model)) {
        cameraInfoTags = tagDesc;
        break;
      }
    }

    if (cameraInfoTags == null) {
      return;
    }

    // We are assuming here that these are all unsigned bytes (Byte or
    // Unknown)
    if (![1, 7].contains(cameraInfoTag!.fieldType)) {
      return;
    }

    final cameraInfo = cameraInfoTag.values as List<int>?;

    // Look for each data value and decode it appropriately.
    for (final offset in cameraInfoTags.keys) {
      final tag = cameraInfoTags[offset]!;
      final tagSize = tag.tagSize;
      if (cameraInfo!.length < offset + tagSize) {
        continue;
      }

      final packedTagValue = cameraInfo.sublist(offset, offset + tagSize);
      final tagValue = s2nLittleEndian(packedTagValue);

      tags['MakerNote ${tag.tagName}'] =
          IfdTagImpl(printable: tag.function(tagValue));
    }
  }

  void parseXmp(String xmpString) {
    //import xml.dom.minidom;

    // print('XMP cleaning data');

    // xml = xml.dom.minidom.parseString(xmp_string);
    // String pretty = xml.toprettyxml();
    // List<String> cleaned = [];
    // for (String line in pretty.splitlines()) {
    //     if (line.trim().isNotEmpty) {
    //         cleaned.add(line);
    //     }
    // }

    // tags['Image ApplicationNotes'] = new IfdTag('\n'.join(cleaned), null, 1, null, null, null);
    tags['Image ApplicationNotes'] =
        IfdTagImpl(printable: xmpString, fieldType: 1);
  }
}
