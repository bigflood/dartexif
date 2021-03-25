// library dartexif.test.test_util;

import 'dart:async';
// import 'dart:mirrors';
import 'package:archive/archive.dart';
import 'dart:io' as io;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'sample_file.dart';

Stream<SampleFile> readSamples() async* {
  // var uri =currentMirrorSystem()
  //   .findLibrary(const Symbol('dartexif.test.test_util'))
  //   .uri;

  // print('uri = $uri');

  // var testDirPath = p.dirname(p.fromUri(uri));
  var testDirPath = 'test';

  var url = "https://github.com/ianare/exif-samples/archive/master.tar.gz";
  var path = p.join(testDirPath, "data/master.tar.gz");
  var samplesExifFileName = p.join(testDirPath, "data/samples-exif.json");

  if (!await io.File(path).exists()) {
    print('downloading $path ..');
    var res = await http.get(Uri.parse(url));
    await io.File(path).writeAsBytes(res.bodyBytes);
  }

  var data = io.File(path).readAsBytesSync();

  var ar = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(data));

  Map<String, dynamic>? samples =
      json.decode(io.File(samplesExifFileName).readAsStringSync());

  for (var file in ar) {
    if (!file.name.endsWith('.jpg') && !file.name.endsWith('.tiff')) {
      continue;
    }

    yield SampleFile(
      name: file.name,
      content: file.content,
      hasError: samples![file.name],
    );
  }
}
