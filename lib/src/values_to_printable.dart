import 'dart:convert';

import 'package:exif/src/exif_types.dart';
import 'package:exif/src/field_types.dart';
import 'package:exif/src/reader.dart';
import 'package:exif/src/tags_info.dart';

class ValuesToPrintable {
  final String value;
  final bool malformed;

  const ValuesToPrintable(this.value) : malformed = false;

  const ValuesToPrintable.malformed(this.value) : malformed = true;

  factory ValuesToPrintable.convert(IfdValues values, IfdEntry entry,
      {required MakerTag? tagEntry, required bool truncateTags}) {
    // compute printable version of values
    if (tagEntry != null) {
      // optional 2nd tag element is present
      if (tagEntry.func != null) {
        // call mapping function
        final printable =
            tagEntry.func!(values.toList().whereType<int>().toList());
        return ValuesToPrintable(printable);
      } else if (tagEntry.map != null) {
        final sb = StringBuffer();
        for (final i in values.toList()) {
          // use lookup table for this tag
          if (i is int) {
            sb.write(tagEntry.map![i] ?? i);
          } else {
            sb.write(i);
          }
        }
        return ValuesToPrintable(sb.toString());
      }
    }

    if (entry.fieldType == FieldType.ascii && values is IfdBytes) {
      final bytes = values.bytes;
      try {
        return ValuesToPrintable(utf8.decode(bytes));
      } on FormatException {
        if (truncateTags && bytes.length > 20) {
          return ValuesToPrintable.malformed(
              'b"${bytesToStringRepr(bytes.sublist(0, 20))}, ... ]');
        }
        return ValuesToPrintable.malformed("b'${bytesToStringRepr(bytes)}'");
      }
    } else if (entry.count == 1) {
      return ValuesToPrintable(values.toList()[0].toString());
    }

    if (entry.count > 50 && values.length > 20) {
      if (truncateTags) {
        final s = values.toList().sublist(0, 20).toString();
        return ValuesToPrintable("${s.substring(0, s.length - 1)}, ... ]");
      }
    }

    return ValuesToPrintable(values.toString());
  }

  static String bytesToStringRepr(List<int> bytes) => bytes.map((e) {
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
}
