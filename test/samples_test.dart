@TestOn("vm")

import 'package:test/test.dart';
import 'test_util.dart';
import 'samples_run.dart';

main() async {
  await for (var file in readSamples()) {
    test(file.name, () async {
      await runSamplesTest(file);
    });
  }
}
