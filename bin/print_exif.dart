import 'dart:io';

import 'package:args/args.dart';
import 'package:exif/exif.dart';

// Show command line usage.
usage(exit_status) {
  var msg = ('Usage: EXIF [OPTIONS] file1 [file2 ...]\n'
      'Extract EXIF information from digital camera image files.\n\nOptions:\n'
      '-h --help               Display usage information and exit.\n'
      '-q --quick              Do not process MakerNotes.\n'
      '-t TAG --stop-tag TAG   Stop processing when this tag is retrieved.\n'
      '-s --strict             Run in strict mode (stop on errors).\n'
      '-d --debug              Run in debug mode (display extra info).\n');
  print(msg);
  exit(exit_status);
}

// Parse command line options/arguments and execute.
main(List<String> arguments) async {
  exitCode = 0;

  bool detailed = true;
  String? stop_tag;
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
      stop_tag = v;
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

  // output info for each file
  for (String filename in args) {
    // var file_start = new DateTime.now();
    print("Opening: " + filename);

    var fileBytes = File(filename).readAsBytesSync();

    print(await printExifOfBytes(fileBytes,
        stop_tag: stop_tag, details: detailed, strict: strict, debug: debug));
  }

  // var file_stop = new DateTime.now();
  // print("Tags processed in " + (tag_stop.difference(tag_start)).toString() + " seconds");
  // print("File processed in " + (file_stop.difference(file_start)).toString() + " seconds");
  // print("");
}
