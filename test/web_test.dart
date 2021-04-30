@TestOn("browser")

import "dart:convert";
import 'package:exif/exif.dart';
import "package:test/test.dart";
import "sample_file.dart";

void main() {
  test("run hybrid main", () async {
    var channel = spawnHybridUri("web_hybrid_main.dart");

    await for (var msg in channel.stream) {
      var file = SampleFile.fromJson(json.decode(msg));
      expect(await printExifOfBytes(file.getContent()), equals(file.dump));
    }
  }, timeout: Timeout.parse("60s"));
}
