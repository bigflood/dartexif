import 'package:exif/exif.dart';
import 'package:test/test.dart';
import 'sample_file.dart';

runSamplesTest(SampleFile file) async {
  List<int> content = file.getContent();

  if (file.hasError == "error") {
    expect(readExifFromBytes(content), throwsRangeError);
  } else {
    var tags = await readExifFromBytes(content);
    if (tags.length == 0) {
      expect(file.hasError, equals("empty"));
    }
  }
}
