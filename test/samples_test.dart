@TestOn("vm")
import 'package:exif/exif.dart';
import 'package:test/test.dart';

import 'test_util.dart';

main() async {
  await for (var file in readSamples()) {
    test(file.name, () async {
      var exifDump = await printExifOfBytes(file.getContent());
      expect(exifDump, equals(file.dump));
    });
  }
}
