import 'dart:typed_data';

import 'package:exif/src/exifheader.dart';
import 'package:exif/src/field_types.dart';
import 'package:exif/src/makernote_apple.dart';
import 'package:exif/src/makernote_canon.dart';
import 'package:exif/src/makernote_casio.dart';
import 'package:exif/src/makernote_fujifilm.dart';
import 'package:exif/src/makernote_nikon.dart';
import 'package:exif/src/makernote_olympus.dart';
import 'package:exif/src/reader.dart';
import 'package:exif/src/tags_info.dart';
import 'package:exif/src/util.dart';

class DecodeMakerNote {
  final Map<String, IfdTagImpl> tags;
  final IfdReader file;

  void Function(int ifd, String ifdName,
      {Map<int, MakerTag>? tagDict, bool relative}) dumpIfdFunc;

  DecodeMakerNote(this.tags, this.file, this.dumpIfdFunc);

  // deal with MakerNote contained in EXIF IFD
  // (Some apps use MakerNote tags but do not use a format for which we
  // have a description, do not process these).
  void decode() {
    final note = tags['EXIF MakerNote'];
    if (note == null) {
      return;
    }

    // Some apps use MakerNote tags but do not use a format for which we
    // have a description, so just do a raw dump for these.
    final make = tags['Image Make']?.tag.printable ?? '';
    if (make == '') {
      return;
    }

    _decodeMakerNote(note: note, make: make);
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
  void _decodeMakerNote({required IfdTagImpl note, required String make}) {
    if (_decodeNikon(note, make)) {
      return;
    }

    if (_decodeOlympus(note, make)) {
      return;
    }

    if (_decodeCasio(note, make)) {
      return;
    }

    if (_decodeFujifilm(note, make)) {
      return;
    }

    if (_decodeApple(note, make)) {
      return;
    }

    if (_decodeCanon(note, make)) {
      return;
    }
  }

  bool _decodeNikon(IfdTagImpl note, String make) {
    // Nikon
    // The maker note usually starts with the word Nikon, followed by the
    // type of the makernote (1 or 2, as a short).  If the word Nikon is
    // not at the start of the makernote, it's probably type 2, since some
    // cameras work that way.
    if (!make.contains('NIKON')) {
      return false;
    }

    if (listHasPrefix(
        note.tag.values.toList(), [78, 105, 107, 111, 110, 0, 1])) {
      // Looks like a type 1 Nikon MakerNote
      _dumpIfd(note.fieldOffset + 8, tagDict: MakerNoteNikon.tagsOld);
    } else if (listHasPrefix(
        note.tag.values.toList(), [78, 105, 107, 111, 110, 0, 2])) {
      // Looks like a labeled type 2 Nikon MakerNote
      if (!listHasPrefix(note.tag.values.toList(), [0, 42], start: 12) &&
          !listHasPrefix(note.tag.values.toList(), [42, 0], start: 12)) {
        throw const FormatException("Missing marker tag '42' in MakerNote.");
        // skip the Makernote label and the TIFF header
      }
      _dumpIfd(note.fieldOffset + 10 + 8,
          tagDict: MakerNoteNikon.tagsNew, relative: true);
    } else {
      // E99x or D1
      // Looks like an unlabeled type 2 Nikon MakerNote
      _dumpIfd(note.fieldOffset, tagDict: MakerNoteNikon.tagsNew);
    }
    return true;
  }

  bool _decodeOlympus(IfdTagImpl note, String make) {
    if (make.startsWith('OLYMPUS')) {
      _dumpIfd(note.fieldOffset + 8, tagDict: MakerNoteOlympus.tags);
      // TODO
      //for i in (('MakerNote Tag 0x2020', makernote.OLYMPUS_TAG_0x2020),):
      //    this.decode_olympus_tag(tags[i[0]].values, i[1])
      //return
      return true;
    }
    return false;
  }

  bool _decodeCasio(IfdTagImpl note, String make) {
    if (make.contains('CASIO') || make.contains('Casio')) {
      _dumpIfd(note.fieldOffset, tagDict: MakerNoteCasio.tags);
      return true;
    }
    return false;
  }

  bool _decodeFujifilm(IfdTagImpl note, String make) {
    if (make != 'FUJIFILM') {
      return false;
    }

    // bug: everything else is "Motorola" endian, but the MakerNote
    // is "Intel" endian
    const endian = Endian.little;

    // bug: IFD offsets are from beginning of MakerNote, not
    // beginning of file header
    final newBaseOffset = file.baseOffset + note.fieldOffset;

    // process note with bogus values (note is actually at offset 12)
    _dumpIfd2(12,
        tagDict: MakerNoteFujifilm.tags,
        baseOffset: newBaseOffset,
        endian: endian);

    return true;
  }

  bool _decodeApple(IfdTagImpl note, String make) {
    if (!_makerIsApple(note, make)) {
      return false;
    }

    final newBaseOffset = file.baseOffset + note.fieldOffset + 14;

    _dumpIfd2(0,
        tagDict: MakerNoteApple.tags,
        baseOffset: newBaseOffset,
        endian: file.endian);

    return true;
  }

  bool _makerIsApple(IfdTagImpl note, String make) =>
      make == 'Apple' &&
      listHasPrefix(note.tag.values.toList(),
          [65, 112, 112, 108, 101, 32, 105, 79, 83, 0]);

  bool _decodeCanon(IfdTagImpl note, String make) {
    if (make != 'Canon') {
      return false;
    }

    _dumpIfd(note.fieldOffset, tagDict: MakerNoteCanon.tags);

    MakerNoteCanon.tagsXxx.forEach((name, makerTags) {
      final tag = tags[name];
      if (tag != null) {
        _canonDecodeTag(
            tag.tag.values.toList().whereType<int>().toList(), makerTags);
        tags.remove(name);
      }
    });

    final cannonTag = tags[MakerNoteCanon.cameraInfoTagName];
    if (cannonTag != null) {
      _canonDecodeCameraInfo(cannonTag);
      tags.remove(MakerNoteCanon.cameraInfoTagName);
    }

    return true;
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

      // it's not a real IFD Tag but we fake one to make everybody
      // happy. this will have a "proprietary" type
      tags['MakerNote $name'] = IfdTagImpl(printable: val);
    }
  }

  // Decode the variable length encoded camera info section.
  void _canonDecodeCameraInfo(IfdTagImpl cameraInfoTag) {
    final modelTag = tags['Image Model'];
    if (modelTag == null) {
      return;
    }

    final model = modelTag.tag.values.toString();

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
    if (cameraInfoTag.fieldType != FieldType.byte &&
        cameraInfoTag.fieldType != FieldType.undefined) {
      return;
    }

    if (cameraInfoTag.tag.values is! List<int>) {
      return;
    }

    final cameraInfo = cameraInfoTag.tag.values as List<int>;

    // Look for each data value and decode it appropriately.
    for (final entry in cameraInfoTags.entries) {
      final offset = entry.key;
      final tag = entry.value;
      final tagSize = tag.tagSize;
      if (cameraInfo.length < offset + tagSize) {
        continue;
      }

      final packedTagValue = cameraInfo.sublist(offset, offset + tagSize);
      final tagValue = s2nLittleEndian(packedTagValue);

      tags['MakerNote ${tag.tagName}'] =
          IfdTagImpl(printable: tag.function(tagValue));
    }
  }

  void _dumpIfd(int ifd,
      {required Map<int, MakerTag> tagDict, bool relative = false}) {
    dumpIfdFunc(ifd, 'MakerNote', tagDict: tagDict, relative: relative);
  }

  void _dumpIfd2(int ifd,
      {required Map<int, MakerTag>? tagDict,
      bool relative = false,
      required int baseOffset,
      required Endian endian}) {
    final originalEndian = file.endian;
    final originalOffset = file.baseOffset;

    file.endian = endian;
    file.baseOffset = baseOffset;

    dumpIfdFunc(ifd, 'MakerNote', tagDict: tagDict, relative: relative);

    file.endian = originalEndian;
    file.baseOffset = originalOffset;
  }
}
