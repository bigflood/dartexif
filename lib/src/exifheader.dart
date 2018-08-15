import 'package:sprintf/sprintf.dart' show sprintf;

import 'util.dart';
import 'tags.dart';
import 'makernote_apple.dart';
import 'makernote_canon.dart';
import 'makernote_casio.dart';
import 'makernote_fujifilm.dart';
import 'makernote_nikon.dart';
import 'makernote_olympus.dart';
import 'tags_info.dart';
import 'exif_types.dart';
import 'file_interface.dart';

const String DEFAULT_STOP_TAG = 'UNDEF';

// field type descriptions as (length, abbreviation, full name) tuples
const List<List> FIELD_TYPES = const [
  const [0, 'X', 'Proprietary'], // no such type
  const [1, 'B', 'Byte'],
  const [1, 'A', 'ASCII'],
  const [2, 'S', 'Short'],
  const [4, 'L', 'Long'],
  const [8, 'R', 'Ratio'],
  const [1, 'SB', 'Signed Byte'],
  const [1, 'U', 'Undefined'],
  const [2, 'SS', 'Signed Short'],
  const [4, 'SL', 'Signed Long'],
  const [8, 'SR', 'Signed Ratio'],
];

// To ignore when quick processing
const List<int> IGNORE_TAGS = const [
  0x9286, // user comment
  0x927C, // MakerNote Tags
  0x02BC, // XPM
];

// Eases dealing with tags.
class IfdTagImpl extends IfdTag {
  // printable version of data
  String _printable;

  @override
  String get printable => _printable;

  // tag ID number
  int _tag;
  @override
  int get tag => _tag;

  // field type as index into FIELD_TYPES
  int field_type;

  @override
  String get tagType => FIELD_TYPES[field_type][2];

  // offset of start of field in bytes from beginning of IFD
  int field_offset;

  // length of data field in bytes
  int field_length;

  // list of data items (int(char or number) or Ratio)
  List _values;

  @override
  List get values => _values;

  IfdTagImpl(
      {String printable: '',
      int tag: -1,
      this.field_type: 0,
      List values: null,
      this.field_offset: 0,
      this.field_length: 0}) {
    _printable = printable;
    _tag = tag;
    _values = values;
  }

  @override
  String toString() => printable;

  String get repr {
    return sprintf('(0x%04X) %s=%s @ %d',
        [tag, FIELD_TYPES[field_type][2], printable, field_offset]);
    // except:
    //     s = '(%s) %s=%s @ %s' % (str(this.tag),
    //                              FIELD_TYPES[this.field_type][2],
    //                              this.printable,
    //                              str(this.field_offset))
  }
}

// Handle an EXIF header.
class ExifHeader {
  FileReader file;
  var endian;
  int offset;
  bool fake_exif;
  bool strict;
  bool debug;
  bool detailed;
  bool truncate_tags;
  Map<String, IfdTag> tags;

  ExifHeader(this.file, this.endian, this.offset, this.fake_exif, this.strict,
      [this.debug = false, this.detailed = true, this.truncate_tags = true]) {
    tags = {};
  }

  // Convert slice to integer, based on sign and endian flags.
  // Usually this offset is assumed to be relative to the beginning of the
  // start of the EXIF information.
  // For some cameras that use relative tags, this offset may be relative
  // to some other starting point.
  int s2n(int offset, int length, [signed = false]) {
    file.setPositionSync(this.offset + offset);
    List<int> sliced = file.readSync(length);
    int val;

    if (this.endian == 'I'.codeUnitAt(0)) {
      val = s2n_littleEndian(sliced);
    } else {
      val = s2n_bigEndian(sliced);
      // Sign extension?
    }
    if (signed) {
      int msb = 1 << (8 * length - 1);
      if ((val & msb) != 0) {
        val -= (msb << 1);
      }
    }

    return val;
  }

  // Convert offset to string.
  List<int> n2s(int offset, int length) {
    List<int> s = [];
    for (int dummy; dummy < length; dummy++) {
      if (this.endian == 'I'.codeUnitAt(0)) {
        s.add(offset & 0xFF);
      } else {
        s.insert(0, offset & 0xFF);
      }
      offset = offset >> 8;
    }
    return s;
  }

  // Return first IFD.
  int _first_ifd() {
    return this.s2n(4, 4);
  }

  // Return the pointer to next IFD.
  int _next_ifd(int ifd) {
    int entries = this.s2n(ifd, 2);
    int next_ifd = this.s2n(ifd + 2 + 12 * entries, 4);
    if (next_ifd == ifd) {
      return 0;
    } else {
      return next_ifd;
    }
  }

  // Return the list of IFDs in the header.
  List<int> list_ifd() {
    int i = _first_ifd();
    List<int> ifds = [];
    while (i > 0) {
      ifds.add(i);
      i = _next_ifd(i);
    }
    return ifds;
  }

  // Return a list of entries in the given IFD.
  void dump_ifd(int ifd, ifd_name,
      {Map<int, MakerTag> tag_dict: null,
      bool relative: false,
      String stop_tag}) {
    stop_tag = stop_tag ?? DEFAULT_STOP_TAG;

    if (tag_dict == null) {
      tag_dict = standard_tags.TAGS;
    }

    // print('** ifd_name $ifd_name');

    // make sure we can process the entries
    int entries;
    try {
      entries = this.s2n(ifd, 2);
    } catch (e) {
      printf("Possibly corrupted IFD: %s", [ifd]);
      return;
    }

    for (int i = 0; i < entries; i++) {
      // entry is index of start of this IFD in the file
      int entry = ifd + 2 + 12 * i;
      int tag = this.s2n(entry, 2);

      //print('** tag=$tag');

      // get tag name early to avoid errors, help debug
      MakerTag tag_entry = tag_dict[tag];
      String tag_name;
      if (tag_entry != null) {
        tag_name = tag_entry.name;
      } else {
        tag_name = sprintf('Tag 0x%04X', [tag]);
      }

      // print('** ifd=$ifd_name tag=$tag_name ($tag)');

      // ignore certain tags for faster processing
      if (this.detailed || !IGNORE_TAGS.contains(tag)) {
        int field_type = this.s2n(entry + 2, 2);

        // unknown field type
        if (field_type <= 0 || field_type >= FIELD_TYPES.length) {
          //print('** ifd=$ifd_name tag=$tag_name field_type=$field_type');

          if (!this.strict) {
            continue;
          } else {
            throw new FormatException(
                sprintf('Unknown type %d in tag 0x%04X', [field_type, tag]));
          }
        }

        int type_length = FIELD_TYPES[field_type][0];
        int count = this.s2n(entry + 4, 4);

        // print('** ifd=$ifd_name tag=$tag_name type=${FIELD_TYPES[field_type]}  len=$type_length, count=$count');

        // Adjust for tag id/type/count (2+2+4 bytes)
        // Now we point at either the data or the 2nd level offset
        int offset = entry + 8;
        // print('** offset=$offset');

        // If the value fits in 4 bytes, it is inlined, else we
        // need to jump ahead again.
        if (count * type_length > 4) {
          // offset is not the value; it's a pointer to the value
          // if relative we set things up so s2n will seek to the right
          // place when it adds this.offset.  Note that this 'relative'
          // is for the Nikon type 3 makernote.  Other cameras may use
          // other relative offsets, which would have to be computed here
          // slightly differently.
          if (relative) {
            int tmp_offset = this.s2n(offset, 4);
            offset = tmp_offset + ifd - 8;
            if (this.fake_exif) {
              offset += 18;
            }
          } else {
            offset = this.s2n(offset, 4);
          }
        }

        int field_offset = offset;
        // print('** field_offset=$field_offset, field_type=$field_type');

        List values = [];
        if (field_type == 2) {
          // special case: null-terminated ASCII string
          // XXX investigate
          // sometimes gets too big to fit in int value
          if (count <= 0) {
          } else {
            if (count > 1024 * 1024) {
              count = 1024 * 1024;
            }
            // and count < (2**31))  // 2E31 is hardware dependant. --gd
            int file_position = this.offset + offset;

            this.file.setPositionSync(file_position);
            values = this.file.readSync(count);
            // Drop any garbage after a null.
            int i = values.indexOf(0);
            if (i >= 0) {
              values = values.sublist(0, i);
            }
          }
        } else {
          // print('** field_type $field_type ${FIELD_TYPES[field_type]}');
          // print('** count ${count}');

          bool signed = [6, 8, 9, 10].contains(field_type);
          // print('** signed=$signed');

          // XXX investigate
          // some entries get too big to handle could be malformed
          // file or problem with this.s2n
          if (count < 1000) {
            for (int dummy = 0; dummy < count; dummy++) {
              if (field_type == 5 || field_type == 10) {
                // a ratio
                int n = this.s2n(offset, 4, signed);
                int d = this.s2n(offset + 4, 4, signed);
                //print('** $n/$d');
                Ratio r = new Ratio(n, d);
                values.add(r);
              } else {
                values.add(this.s2n(offset, type_length, signed));
              }
              offset = offset + type_length;
            }
            // The test above causes problems with tags that are
            // supposed to have long values! Fix up one important case.
          } else if (tag_name == 'MakerNote' ||
              tag_name == makernote_canon.CAMERA_INFO_TAG_NAME) {
            for (int dummy = 0; dummy < count; dummy++) {
              int value = this.s2n(offset, type_length, signed);
              values.add(value);
              offset = offset + type_length;
            }
          }
        }

        // print('** values[${values.length}]=$values');
        String printable = '';
        // now 'values' is either a string or an array
        if (field_type == 2) {
          printable = new String.fromCharCodes(
              values.where((v) => v.runtimeType == int).map((v) => v as int));
        } else if (count == 1 && field_type != 2) {
          printable = values[0].toString();
        } else if (count > 50 && values.length > 20) {
          if (this.truncate_tags) {
            String s = values.sublist(0, 20).toString();
            printable = s.substring(0, s.length - 1) + ", ... ]";
          } else {
            printable = values.toString();
          }
        } else {
          printable = values.toString();
        }

        // compute printable version of values
        if (tag_entry != null) {
          // optional 2nd tag element is present
          if (tag_entry.func != null) {
            // call mapping function
            printable = tag_entry.func(values.whereType<int>().toList());
          } else if (tag_entry.tags != null) {
            try {
              // print('** ${tag_entry.tags.name} SubIFD at offset ${values[0]}:');
              this.dump_ifd(values[0], tag_entry.tags.name,
                  tag_dict: tag_entry.tags.tags, stop_tag: stop_tag);
            } on RangeError {
              // printf('** No values found for %s SubIFD', [tag_entry.tags.name]);
            }
          } else if (tag_entry.map != null) {
            printable = '';
            for (int i in values) {
              // use lookup table for this tag
              printable += tag_entry.map[i] ?? i.toString();
            }
          }
        }

        // print('** ifd=$ifd_name tag=$tag_name ($tag) field_type=$field_type, type_length=$type_length, count=$count');

        this.tags[ifd_name + ' ' + tag_name] = new IfdTagImpl(
            printable: printable,
            tag: tag,
            field_type: field_type,
            values: values,
            field_offset: field_offset,
            field_length: count * type_length);

        // var t = this.tags[ifd_name + ' ' + tag_name];
        // print('**  "$ifd_name $tag_name": str=$t ${FIELD_TYPES[t.field_type]} @${t.field_offset} len=${t.field_length}');

        if (tag_name == stop_tag) {
          break;
        }
      }
    }
  }

  // Extract uncompressed TIFF thumbnail.
  // Take advantage of the pre-existing layout in the thumbnail IFD as
  // much as possible
  void extract_tiff_thumbnail(thumb_ifd) {
    IfdTagImpl thumb = this.tags['Thumbnail Compression'];
    if (thumb == null || thumb.printable != 'Uncompressed TIFF') {
      return;
    }

    List<int> tiff;
    int strip_off = 0, strip_len = 0;

    int entries = this.s2n(thumb_ifd, 2);
    // this is header plus offset to IFD ...
    if (this.endian == 'M'.codeUnitAt(0)) {
      tiff = 'MM\x00*\x00\x00\x00\x08'.codeUnits;
    } else {
      tiff = 'II*\x00\x08\x00\x00\x00'.codeUnits;
      // ... plus thumbnail IFD data plus a null "next IFD" pointer
    }

    this.file.setPositionSync(this.offset + thumb_ifd);
    tiff.addAll(this.file.readSync(entries * 12 + 2));
    tiff.addAll([0, 0, 0, 0]);

    // fix up large value offset pointers into data area
    for (int i = 0; i < entries; i++) {
      int entry = thumb_ifd + 2 + 12 * i;
      int tag = this.s2n(entry, 2);
      int field_type = this.s2n(entry + 2, 2);
      int type_length = FIELD_TYPES[field_type][0];
      int count = this.s2n(entry + 4, 4);
      int old_offset = this.s2n(entry + 8, 4);
      // start of the 4-byte pointer area in entry
      int ptr = i * 12 + 18;
      // remember strip offsets location
      if (tag == 0x0111) {
        strip_off = ptr;
        strip_len = count * type_length;
        // is it in the data area?
      }
      if (count * type_length > 4) {
        // update offset pointer (nasty "strings are immutable" crap)
        // should be able to say "tiff[ptr:ptr+4]=newoff"
        List<int> tiff0 = tiff;
        int newoff = tiff0.length;
        tiff = tiff0.sublist(0, ptr);
        tiff.addAll(n2s(newoff, 4));
        tiff.addAll(tiff0.sublist(ptr + 4));
        // remember strip offsets location
        if (tag == 0x0111) {
          strip_off = newoff;
          strip_len = 4;
        }
        // get original data and store it
        this.file.setPositionSync(this.offset + old_offset);
        tiff.addAll(this.file.readSync(count * type_length));
      }
    }

    // add pixel strips and update strip offset info
    var old_offsets = this.tags['Thumbnail StripOffsets'].values;
    var old_counts = this.tags['Thumbnail StripByteCounts'].values;
    for (int i = 0; i < old_offsets.length; i++) {
      // update offset pointer (more nasty "strings are immutable" crap)
      List<int> tiff0 = tiff;
      List<int> offset = n2s(tiff0.length, strip_len);
      tiff = tiff0.sublist(0, strip_off);
      tiff.addAll(offset);
      tiff.addAll(tiff0.sublist(strip_off + strip_len));
      strip_off += strip_len;
      // add pixel strip to end
      this.file.setPositionSync(this.offset + old_offsets[i]);
      tiff.addAll(this.file.readSync(old_counts[i]));
    }

    this.tags['TIFFThumbnail'] = new IfdTagImpl(values: tiff);
  }

  // Extract JPEG thumbnail.
  // (Thankfully the JPEG data is stored as a unit.)
  extract_jpeg_thumbnail() {
    IfdTagImpl thumb_offset = this.tags['Thumbnail JPEGInterchangeFormat'];
    if (thumb_offset != null) {
      this.file.setPositionSync(this.offset + thumb_offset.values[0]);
      int size = this.tags['Thumbnail JPEGInterchangeFormatLength'].values[0];
      this.tags['JPEGThumbnail'] =
          new IfdTagImpl(values: this.file.readSync(size));
    }

    // Sometimes in a TIFF file, a JPEG thumbnail is hidden in the MakerNote
    // since it's not allowed in a uncompressed TIFF IFD
    if (!this.tags.containsKey('JPEGThumbnail')) {
      thumb_offset = this.tags['MakerNote JPEGThumbnail'];
      if (thumb_offset != null) {
        this.file.setPositionSync(this.offset + thumb_offset.values[0]);
        this.tags['JPEGThumbnail'] = new IfdTagImpl(
            values: this.file.readSync(thumb_offset.field_length));
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
  void decode_maker_note() {
    IfdTagImpl note = this.tags['EXIF MakerNote'];

    // Some apps use MakerNote tags but do not use a format for which we
    // have a description, so just do a raw dump for these.
    String make = this.tags['Image Make'].printable;

    // print('** make=$make');

    // Nikon
    // The maker note usually starts with the word Nikon, followed by the
    // type of the makernote (1 or 2, as a short).  If the word Nikon is
    // not at the start of the makernote, it's probably type 2, since some
    // cameras work that way.
    if (make.contains('NIKON')) {
      if (list_eq(note.values.sublist(0, 7), [78, 105, 107, 111, 110, 0, 1])) {
        //print("Looks like a type 1 Nikon MakerNote.");
        this.dump_ifd(note.field_offset + 8, 'MakerNote',
            tag_dict: makernote_nikon.TAGS_OLD);
      } else if (list_eq(
          note.values.sublist(0, 7), [78, 105, 107, 111, 110, 0, 2])) {
        //print("Looks like a labeled type 2 Nikon MakerNote");
        if (!list_eq(note.values.sublist(12, 14), [0, 42]) &&
            !list_eq(note.values.sublist(12, 14), [42, 0])) {
          throw new FormatException("Missing marker tag '42' in MakerNote.");
          // skip the Makernote label and the TIFF header
        }
        this.dump_ifd(note.field_offset + 10 + 8, 'MakerNote',
            tag_dict: makernote_nikon.TAGS_NEW, relative: true);
      } else {
        // E99x or D1
        //print("Looks like an unlabeled type 2 Nikon MakerNote");
        this.dump_ifd(note.field_offset, 'MakerNote',
            tag_dict: makernote_nikon.TAGS_NEW);
      }
      return;
    }

    // Olympus
    if (make.startsWith('OLYMPUS')) {
      this.dump_ifd(note.field_offset + 8, 'MakerNote',
          tag_dict: makernote_olympus.TAGS);
      // TODO
      //for i in (('MakerNote Tag 0x2020', makernote.OLYMPUS_TAG_0x2020),):
      //    this.decode_olympus_tag(this.tags[i[0]].values, i[1])
      //return
    }

    // Casio
    if (make.contains('CASIO') || make.contains('Casio')) {
      this.dump_ifd(note.field_offset, 'MakerNote',
          tag_dict: makernote_casio.TAGS);
      return;
    }

    // Fujifilm
    if (make == 'FUJIFILM') {
      // bug: everything else is "Motorola" endian, but the MakerNote
      // is "Intel" endian
      endian = this.endian;
      this.endian = 'I'.codeUnitAt(0);
      // bug: IFD offsets are from beginning of MakerNote, not
      // beginning of file header
      int offset = this.offset;
      this.offset += note.field_offset;
      // process note with bogus values (note is actually at offset 12)
      this.dump_ifd(12, 'MakerNote', tag_dict: makernote_fujifilm.TAGS);
      // reset to correct values
      this.endian = endian;
      this.offset = offset;
      return;
    }

    // Apple
    if (make == 'Apple' &&
        list_eq(note.values.sublist(0, 10),
            [65, 112, 112, 108, 101, 32, 105, 79, 83, 0])) {
      int t = this.offset;
      this.offset += note.field_offset + 14;
      this.dump_ifd(0, 'MakerNote', tag_dict: makernote_apple.TAGS);
      this.offset = t;
      return;
    }

    // Canon
    if (make == 'Canon') {
      this.dump_ifd(note.field_offset, 'MakerNote',
          tag_dict: makernote_canon.TAGS);

      for (List i in [
        ['MakerNote Tag 0x0001', makernote_canon.CAMERA_SETTINGS],
        ['MakerNote Tag 0x0002', makernote_canon.FOCAL_LENGTH],
        ['MakerNote Tag 0x0004', makernote_canon.SHOT_INFO],
        ['MakerNote Tag 0x0026', makernote_canon.AF_INFO_2],
        ['MakerNote Tag 0x0093', makernote_canon.FILE_INFO]
      ]) {
        String name = i[0];
        Map<int, MakerTag> makerTags = i[1];

        if (this.tags.containsKey(name)) {
          this._canon_decode_tag(
              this.tags[name].values.whereType<int>().toList(), makerTags);
          this.tags.remove(name);
        }
      }

      if (this.tags.containsKey(makernote_canon.CAMERA_INFO_TAG_NAME)) {
        IfdTagImpl tag = this.tags[makernote_canon.CAMERA_INFO_TAG_NAME];
        //print('Canon CameraInfo');
        this._canon_decode_camera_info(tag);
        this.tags.remove(makernote_canon.CAMERA_INFO_TAG_NAME);
      }

      return;
    }
  }

  // TODO Decode Olympus MakerNote tag based on offset within tag
  // void _olympus_decode_tag(List<int> value, mn_tags) {}

  // Decode Canon MakerNote tag based on offset within tag.
  // See http://www.burren.cx/david/canon.html by David Burren
  void _canon_decode_tag(List<int> value, Map<int, MakerTag> mn_tags) {
    for (int i = 1; i < value.length; i++) {
      MakerTag tag = mn_tags[i] ?? MakerTag.make('Unknown');
      String name = tag.name;
      String val;
      if (tag.map != null) {
        val = tag.map[value[i]] ?? 'Unknown';
      } else {
        val = value[i].toString();
      }

      // print("** canon decode tag - $i $name ${value[i]}");

      // it's not a real IFD Tag but we fake one to make everybody
      // happy. this will have a "proprietary" type
      this.tags['MakerNote ' + name] = new IfdTagImpl(printable: val);
    }
  }

  // Decode the variable length encoded camera info section.
  void _canon_decode_camera_info(IfdTagImpl camera_info_tag) {
    IfdTagImpl modelTag = this.tags['Image Model'];
    if (modelTag == null) {
      return;
    }

    String model = modelTag.values.toString();

    Map<int, List> camera_info_tags = null;
    //for ((model_name_re, tag_desc) in makernote_canon.CAMERA_INFO_MODEL_MAP.items()) {
    for (String model_name_re in makernote_canon.CAMERA_INFO_MODEL_MAP.keys) {
      Map<int, List> tag_desc =
          makernote_canon.CAMERA_INFO_MODEL_MAP[model_name_re];
      if (new RegExp(model_name_re).hasMatch(model)) {
        camera_info_tags = tag_desc;
        break;
      }
    }

    if (camera_info_tags == null) {
      return;
    }

    // We are assuming here that these are all unsigned bytes (Byte or
    // Unknown)
    if (![1, 7].contains(camera_info_tag.field_type)) {
      return;
    }

    List<int> camera_info = camera_info_tag.values;

    // Look for each data value and decode it appropriately.
    for (int offset in camera_info_tags.keys) {
      List tag = camera_info_tags[offset];
      int tag_size = tag[1];
      if (camera_info.length < offset + tag_size) {
        continue;
      }

      List<int> packed_tag_value =
          camera_info.sublist(offset, offset + tag_size);
      int tag_value = s2n_littleEndian(packed_tag_value);

      String tag_name = tag[0];
      if (tag.length > 2) {
        if (tag[2] is Function) {
          tag_value = tag[2](tag_value);
        } else {
          tag_value = tag[2][tag_value] ?? tag_value;
        }
      }

      //print(" $tag_name $tag_value");

      this.tags['MakerNote ' + tag_name] =
          new IfdTagImpl(printable: tag_value.toString());
    }
  }

  void parse_xmp(xmp_string) {
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

    // this.tags['Image ApplicationNotes'] = new IfdTag('\n'.join(cleaned), null, 1, null, null, null);
    this.tags['Image ApplicationNotes'] =
        new IfdTagImpl(printable: xmp_string, field_type: 1);
  }
}
