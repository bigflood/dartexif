import 'package:dartexif/dartexif.dart';
import 'package:args/args.dart';
import 'dart:io';
import 'package:dartexif/exif_cmd.dart';

// Show command line usage.
usage(exit_status) {
  var msg = ('Usage: EXIF.py [OPTIONS] file1 [file2 ...]\n'
          'Extract EXIF information from digital camera image files.\n\nOptions:\n'
          '-h --help               Display usage information and exit.\n'
          //'-v --version            Display version information and exit.\n'
          '-q --quick              Do not process MakerNotes.\n'
          '-t TAG --stop-tag TAG   Stop processing when this tag is retrieved.\n'
          '-s --strict             Run in strict mode (stop on errors).\n'
          '-d --debug              Run in debug mode (display extra info).\n'
      //'-c --color              Output in color (only works with debug on POSIX).\n'
      );
  print(msg);
  exit(exit_status);
}

// // Show the program version.
// show_version() {
//     printf('Version %s on Python%s', [__version__, sys.version_info[0]]);
//     exit(0);
// }

// Parse command line options/arguments and execute.
main(List<String> arguments) async {
  exitCode = 0;

  bool detailed = true;
  String stop_tag = DEFAULT_STOP_TAG;
  bool debug = false;
  bool strict = false;
  //bool color = false;

  final parser = new ArgParser()
        ..addFlag('help', abbr: 'h', callback: (v) {
          if (v) usage(0);
        })
        //..addFlag('version', abbr: 'v', callback: (v) { if (v) show_version(); })
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
        })
      //..addFlag('color', abbr: 'c', callback: (v) { color = v; } )
      ;

  List<String> args;

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

    await printExifOf(filename, (s) => print(s),
        stop_tag: stop_tag, details: detailed, strict: strict, debug: debug);
  }

  // var file_stop = new DateTime.now();
  // print("Tags processed in " + (tag_stop.difference(tag_start)).toString() + " seconds");
  // print("File processed in " + (file_stop.difference(file_start)).toString() + " seconds");
  // print("");
}
