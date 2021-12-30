import 'package:exif/exif.dart';
import "package:test/test.dart";

void main() {
  test("range error", () async {
    final data = [
      '',
      '\xFF',
      '\xFF\xD8',
      '\xFF\xD8abc',
      'II',
      'II*\x00',
      'II*\x00ftypheic',
      'MM',
      'MM\x00*',
    ];

    for (final x in data) {
      final exifDump = await printExifOfBytes(x.codeUnits);
      expect(exifDump, equals("No EXIF information found"), reason: x);
    }
  });
}
