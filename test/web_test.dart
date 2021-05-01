@TestOn("browser")
import "dart:convert";

import 'package:exif/exif.dart';
import "package:test/test.dart";

import "sample_file.dart";

void main() {
  test("run hybrid main", () async {
    final channel = spawnHybridUri("web_hybrid_main.dart");

    await for (final msg in channel.stream) {
      final file = SampleFile.fromJson(
          json.decode(msg as String) as Map<String, dynamic>);
      expect(await printExifOfBytes(file.getContent()), equals(file.dump));
    }
  }, timeout: Timeout.parse("60s"));
}
