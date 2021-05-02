import 'dart:io';

import 'package:args/args.dart';
import 'package:exif/exif.dart';

void usage(int exitStatus) {
  const msg = 'Usage: EXIF [OPTIONS] file1 [file2 ...]\n'
      'Extract EXIF information from digital camera image files.\n'
      '\n'
      'Options:\n'
      '-h --help               Display usage information and exit.\n'
      '-q --quick              Do not process MakerNotes.\n'
      '-t TAG --stop-tag TAG   Stop processing when this tag is retrieved.\n'
      '-s --strict             Run in strict mode (stop on errors).\n'
      '-d --debug              Run in debug mode (display extra info).\n';
  print(msg);
  exit(exitStatus);
}

Future main(List<String> arguments) async {
  exitCode = 0;

  bool detailed = true;
  String? stopTag;
  bool debug = false;
  bool strict = false;

  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', callback: (v) {
      if (v) usage(0);
    })
    ..addFlag('quick', abbr: 'q', callback: (v) {
      detailed = !v;
    })
    ..addOption('stop-tag', abbr: 't', callback: (v) {
      stopTag = v;
    })
    ..addFlag('strict', abbr: 's', callback: (v) {
      strict = v;
    })
    ..addFlag('debug', abbr: 'd', callback: (v) {
      debug = v;
    });

  late List<String> args;

  try {
    args = parser.parse(arguments).rest;
  } on ArgParserException {
    usage(2);
  }

  if (args.isEmpty) {
    usage(2);
  }

  for (final String filename in args) {
    print("Opening: $filename");

    final fileBytes = File(filename).readAsBytesSync();

    print(await printExifOfBytes(fileBytes,
        stopTag: stopTag, details: detailed, strict: strict, debug: debug));
  }
}
