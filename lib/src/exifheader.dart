import 'package:exif/src/exif_thumbnail.dart';
import 'package:exif/src/exif_types.dart';
import 'package:exif/src/field_types.dart';
import 'package:exif/src/reader.dart';
import 'package:exif/src/tags.dart';
import 'package:exif/src/tags_info.dart';
import 'package:exif/src/values_to_printable.dart';
import 'package:sprintf/sprintf.dart' show sprintf;

const defaultStopTag = 'UNDEF';

// To ignore when quick processing
const ignoreTags = [
  0x9286, // user comment
  0x927C, // MakerNote Tags
  0x02BC, // XPM
];

// Eases dealing with tags.
class IfdTagImpl {
  final IfdTag tag;

  final FieldType fieldType;

  // offset of start of field in bytes from beginning of IFD
  int fieldOffset;

  // length of data field in bytes
  int fieldLength;

  IfdTagImpl({
    this.fieldType = FieldType.proprietary,
    this.fieldOffset = 0,
    this.fieldLength = 0,
    String printable = '',
    int tag = -1,
    IfdValues values = const IfdNone(),
  }) : tag = IfdTag(
          tag: tag,
          tagType: fieldType.name,
          printable: printable,
          values: values,
        );
}

/// Handle an EXIF header.
class ExifHeader {
  bool strict;
  bool debug;
  bool detailed;
  bool truncateTags;
  Map<String, IfdTagImpl> tags = {};
  List<String> warnings = [];
  IfdReader file;

  ExifHeader({
    required this.file,
    required this.strict,
    this.debug = false,
    this.detailed = true,
    this.truncateTags = true,
  });

  // Return a list of entries in the given IFD.
  void dumpIfd(int ifd, String ifdName,
      {Map<int, MakerTag>? tagDict, bool relative = false, String? stopTag}) {
    stopTag ??= defaultStopTag;
    tagDict ??= StandardTags.tags;

    // make sure we can process the entries
    List<IfdEntry> entries;
    try {
      entries = file.readIfdEntries(ifd, relative: relative);
    } catch (e) {
      warnings.add("Possibly corrupted IFD: $ifd");
      return;
    }

    for (final entry in entries) {
      // get tag name early to avoid errors, help debug
      final MakerTag? tagEntry = tagDict[entry.tag];
      String tagName;
      if (tagEntry != null) {
        tagName = tagEntry.name;
      } else {
        tagName = sprintf('Tag 0x%04X', [entry.tag]);
      }

      // ignore certain tags for faster processing
      if (detailed || !ignoreTags.contains(entry.tag)) {
        processTag(
            ifd: ifd,
            ifdName: ifdName,
            tagEntry: tagEntry,
            entry: entry,
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
      required IfdEntry entry,
      required String tagName,
      required bool relative,
      required String? stopTag}) {
    // unknown field type
    if (!entry.fieldType.isValid) {
      if (!strict) {
        return;
      } else {
        throw FormatException(sprintf(
            'Unknown type %d in tag 0x%04X', [entry.fieldType, entry.tag]));
      }
    }

    final values = file.readField(entry, tagName: tagName);

    // now 'values' is either a string or an array
    final printable = ValuesToPrintable.convert(values, entry,
        tagEntry: tagEntry, truncateTags: truncateTags);
    if (printable.malformed) {
      warnings.add("Possibly corrupted field $tagName in $ifdName IFD");
    }

    final makerTags = tagEntry?.tags;
    if (makerTags != null) {
      try {
        dumpIfd(values.firstAsInt(), makerTags.name,
            tagDict: makerTags.tags, stopTag: stopTag);
      } on RangeError {
        warnings.add('No values found for ${makerTags.name} SubIFD');
      }
    }

    tags['$ifdName $tagName'] = IfdTagImpl(
        printable: printable.value,
        tag: entry.tag,
        fieldType: entry.fieldType,
        values: values,
        fieldOffset: entry.fieldOffset,
        fieldLength: entry.count * entry.fieldType.length);

    // var t = tags[ifd_name + ' ' + tag_name];
  }

  void extractTiffThumbnail(int thumbIfd) {
    final values = Thumbnail(tags, file).extractTiffThumbnail(thumbIfd);
    if (values != null) {
      tags['TIFFThumbnail'] = IfdTagImpl(values: IfdBytes.fromList(values));
    }
  }

  void extractJpegThumbnail() {
    final values = Thumbnail(tags, file).extractJpegThumbnail();
    if (values != null) {
      tags['JPEGThumbnail'] = IfdTagImpl(values: IfdBytes.fromList(values));
    }
  }

  void parseXmp(String xmpString) {
    tags['Image ApplicationNotes'] =
        IfdTagImpl(printable: xmpString, fieldType: FieldType.byte);
  }
}
