import 'dart:math';

import 'package:collection/collection.dart' show ListEquality;
import 'package:sprintf/sprintf.dart' show sprintf;

bool listRangeEqual(List list1, int begin, int end, List list2) {
  var beginIndex = begin >= 0 ? begin : 0;
  beginIndex = beginIndex < list1.length ? beginIndex : list1.length;

  var endIndex = end >= begin ? end : begin;
  endIndex = endIndex < list1.length ? endIndex : list1.length;

  return listEqual(list1.sublist(beginIndex, endIndex), list2);
}

final listEqual = const ListEquality().equals;

bool listHasPrefix(List list, List prefix, {int start = 0}) {
  if (prefix.isEmpty) {
    return true;
  }
  if (list.length - start < prefix.length) {
    return false;
  }
  return listEqual(list.sublist(start, start + prefix.length), prefix);
}

bool listContainedIn<T>(List<T> a, List<List<T>> b) =>
    b.any((i) => listEqual(i, a));

void printf(String a, List b) => print(sprintf(a, b));

// Don't throw an exception when given an out of range character.
String makeString(List<int> seq) {
  String s = String.fromCharCodes(seq.where((c) => 32 <= c && c < 256));
  if (s.isEmpty) {
    if (seq.isEmpty || seq.reduce(max) == 0) {
      return "";
    }
    s = seq.map((e) => e.toString()).join();
  }
  return s.trim();
}

// Special version to deal with the code in the first 8 bytes of a user comment.
// First 8 bytes gives coding system e.g. ASCII vs. JIS vs Unicode.
String makeStringUc(List<int> seq) {
  if (seq.length <= 8) {
    return "";
  }

  // Remove code from sequence only if it is valid
  if ({'ASCII', 'UNICODE', 'JIS', ''}
      .contains(makeString(seq.sublist(0, 8)).toUpperCase())) {
    seq = seq.sublist(8);
  }

  // Of course, this is only correct if ASCII, and the standard explicitly
  // allows JIS and Unicode.
  return makeString(seq);
}

// Extract multi-byte integer in little endian.
int s2nBigEndian(List<int> s, {bool signed = false}) {
  if (s.isEmpty) {
    return 0;
  }

  int xor = 0;
  if (signed && s[0] >= 128) {
    xor = 0xff;
  }

  int x = 0;
  for (final c in s) {
    x = (x << 8) | (c ^ xor);
  }

  if (xor != 0) {
    x = -(x + 1);
  }

  return x;
}

// Extract multi-byte integer in little endian.
int s2nLittleEndian(List<int> s, {bool signed = false}) {
  if (s.isEmpty) {
    return 0;
  }

  int xor = 0;
  if (signed && s.last >= 128) {
    xor = 0xff;
  }

  int x = 0;
  int y = 0;
  for (final int c in s) {
    x = x | ((c ^ xor) << y);
    y += 8;
  }

  if (xor != 0) {
    x = -(x + 1);
  }

  return x;
}
