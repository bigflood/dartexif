@TestOn("browser")

import "dart:convert";
import "package:test/test.dart";
import "sample_file.dart";
import "samples_run.dart";

void main() {
  test("run hybrid main", () async {
    var channel = spawnHybridUri("web_hybrid_main.dart");

    await for (var msg in channel.stream) {
      var file = SampleFile.fromJson(json.decode(msg));
      await runSamplesTest(file);
    }
  }, timeout: Timeout.parse("60s"));
}
