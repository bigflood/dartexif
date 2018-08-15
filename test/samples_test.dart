import 'package:test/test.dart';
import 'package:exif/exif.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'dart:io' as io;
import 'dart:convert';
import 'test_util.dart';
import 'package:path/path.dart' as p;

main() async {
  var url = "https://github.com/ianare/exif-samples/archive/master.tar.gz";
  var path = p.join(testDirPath, "data/master.tar.gz");
  var samplesExifFileName = p.join(testDirPath, "data/samples-exif.json");

  if (!await io.File(path).exists()) {
    print('downloading $path ..');
    var res = await http.get(url);
    await io.File(path).writeAsBytes(res.bodyBytes);
  }

  var data = io.File(path).readAsBytesSync();
  var ar = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(data));

  Map<String, dynamic> samples =
      json.decode(io.File(samplesExifFileName).readAsStringSync());

  for (var file in ar) {
    if (!file.name.endsWith('.jpg') && !file.name.endsWith('.tiff')) {
      continue;
    }
    test(file.name, () async {
      List<int> content = file.content;

      if (samples[file.name] == "error") {
        expect(readExifFromBytes(content), throwsRangeError);
      } else {
        var tags = await readExifFromBytes(content);
        if (tags.length == 0) {
          expect(samples[file.name], equals("empty"));
        }
      }
    });
  }
}
