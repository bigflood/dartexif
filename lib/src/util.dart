import 'dart:math';

import 'package:collection/collection.dart' show ListEquality;
import 'package:sprintf/sprintf.dart' show sprintf;

bool? list_range_eq(List list1, int begin, int end, List list2) {
  begin = begin >= 0 ? begin : 0;
  begin = begin < list1.length ? begin : list1.length;
  end = end >= begin ? end : begin;
  end = end < list1.length ? end : list1.length;

  return list_eq(list1.sublist(begin, end), list2);
}

Function list_eq = const ListEquality().equals;

list_in<T>(T a, List<T> b) => b.any((i) => list_eq(i, a));

printf(a, b) => print(sprintf(a, b));

// Don't throw an exception when given an out of range character.
String make_string(List<int> seq) {
  String s = new String.fromCharCodes(seq.where((c) => 32 <= c && c < 256));
  if (s.isEmpty) {
    if (seq.reduce(max) == 0) {
      return "";
    }
    s = seq.map((e) => e.toString()).join();
  }
  return s.trim();
}

// Special version to deal with the code in the first 8 bytes of a user comment.
// First 8 bytes gives coding system e.g. ASCII vs. JIS vs Unicode.
String make_string_uc(List<int> seq) {
  if (seq.length <= 8) {
    return "";
  }

  // Remove code from sequence only if it is valid
  if ({'ASCII', 'UNICODE', 'JIS', ''}
      .contains(make_string(seq.sublist(0, 8)).toUpperCase())) {
    seq = seq.sublist(8);
  }

  // Of course, this is only correct if ASCII, and the standard explicitly
  // allows JIS and Unicode.
  return make_string(seq);
}

// Extract multi-byte integer in little endian.
int s2n_bigEndian(List<int> s, {bool signed = false}) {
  if (s.isEmpty) {
    return 0;
  }

  int xor = 0;
  if (signed && s[0] >= 128) {
    xor = 0xff;
  }

  int x = 0;
  for (int c in s) {
    x = (x << 8) | (c ^ xor);
  }

  if (xor != 0) {
    x = -(x + 1);
  }

  return x;
}

// Extract multi-byte integer in little endian.
int s2n_littleEndian(List<int> s, {bool signed = false}) {
  if (s.isEmpty) {
    return 0;
  }

  int xor = 0;
  if (signed && s.last >= 128) {
    xor = 0xff;
  }

  int x = 0;
  int y = 0;
  for (int c in s) {
    x = x | ((c ^ xor) << y);
    y += 8;
  }

  if (xor != 0) {
    x = -(x + 1);
  }

  return x;
}
