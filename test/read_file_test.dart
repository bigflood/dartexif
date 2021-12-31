import "dart:io" as io;

import 'package:exif/exif.dart';
import "package:test/test.dart";

void main() {
  test("read file test", () async {
    const filename = "test/data/heic-test.heic";
    final file = io.File(filename);
    final output = tagsToString(await readExifFromFile(file));
    final expected = await io.File("$filename.dump").readAsString();
    expect(output, equals(expected.trim()));
  });
}

String tagsToString(Map<String, IfdTag> tags) {
  final tagKeys = tags.keys.toList();
  tagKeys.sort();
  final prints = [];

  for (final key in tagKeys) {
    final tag = tags[key];
    prints.add("$key (${tag!.tagType}): $tag");
  }

  return prints.join("\n");
}
