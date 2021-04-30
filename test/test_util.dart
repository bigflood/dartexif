// library dartexif.test.test_util;

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

// import 'dart:mirrors';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'sample_file.dart';

Stream<SampleFile> readSamples() async* {
  var commit = "2a62d69683c154ffe03b4502bdfa3248d8a1b05c";
  var filenamePrefix = p.join("test", "data", "$commit-");

  var dumpFile = await downloadUrl(
    filenamePrefix,
    "https://raw.githubusercontent.com/ianare/exif-samples/$commit/dump",
  );

  var nameToDumps = readDumpFile(dumpFile);

  var path = await downloadUrl(
    filenamePrefix,
    "https://github.com/ianare/exif-samples/archive/$commit.tar.gz",
  );

  var data = io.File(path).readAsBytesSync();

  var ar = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(data));

  for (var file in ar) {
    file.name =
        file.name.replaceAll("exif-samples-$commit", "exif-samples-master");

    if (!file.name.endsWith('.jpg') && !file.name.endsWith('.tiff')) {
      continue;
    }

    if (!nameToDumps.containsKey(file.name)) {
      file.name = utf8.decode(file.name.codeUnits);
    }

    yield SampleFile(
      name: file.name,
      content: file.content,
      dump: nameToDumps[file.name],
    );
  }
}

Map<String, String> readDumpFile(String dumpFile) {
  var fileDumps = io.File(dumpFile).readAsStringSync().trim().split("\n\n");

  var nameAndDumps = fileDumps.map((e) => e.split("\n")).map((e) => MapEntry(
      e[0].split("Opening: ")[1],
      e
          .sublist(1)
          .where((e) =>
              !e.startsWith("Possibly corrupted ") &&
              !e.startsWith("No values found for "))
          .join("\n")));

  return Map.fromEntries(nameAndDumps);
}

Future<String> downloadUrl(String filenamePrefix, String url) async {
  var filename = filenamePrefix + Uri.parse(url).pathSegments.last;

  if (!await io.File(filename).exists()) {
    print('downloading $filename ..');
    var res = await http.get(Uri.parse(url));
    await io.File(filename).writeAsBytes(res.bodyBytes);
  }

  return filename;
}
