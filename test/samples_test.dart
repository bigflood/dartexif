@TestOn("vm")
import 'package:exif/exif.dart';
import 'package:test/test.dart';

import 'test_util.dart';

Future main() async {
  await for (final file in readSamples()) {
    test(file.name, () async {
      final exifDump = await printExifOfBytes(file.getContent());
      expect(exifDump, equals(file.dump));
    });
  }
}
