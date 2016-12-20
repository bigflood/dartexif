import 'package:args/args.dart';
import 'dart:io';
import 'package:exif/exif.dart';

// Show command line usage.
usage(exit_status) {
  var msg = ('Usage: EXIF.py [OPTIONS] file1 [file2 ...]\n'
          'Extract EXIF information from digital camera image files.\n\nOptions:\n'
          '-h --help               Display usage information and exit.\n'
          '-q --quick              Do not process MakerNotes.\n'
          '-t TAG --stop-tag TAG   Stop processing when this tag is retrieved.\n'
          '-s --strict             Run in strict mode (stop on errors).\n'
          '-d --debug              Run in debug mode (display extra info).\n'
      );
  print(msg);
  exit(exit_status);
}


// Parse command line options/arguments and execute.
main(List<String> arguments) async {
  exitCode = 0;

  bool detailed = true;
  String stop_tag = null;
  bool debug = false;
  bool strict = false;

  final parser = new ArgParser()
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
        })
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

printExifOf(String path, printFunc(String),
    {String stop_tag = null, bool details = true, bool strict = false, bool debug = false}) async {

  Map<String, IfdTag> data = await readExifFromFile(new File(path),
      stop_tag: stop_tag, details: true, strict: false, debug: false);

  if (data == null || data.isEmpty) {
    printFunc("No EXIF information found\n");
    return;
  }

  if (data.containsKey('JPEGThumbnail')) {
    printFunc('File has JPEG thumbnail');
    data.remove('JPEGThumbnail');
  }
  if (data.containsKey('TIFFThumbnail')) {
    printFunc('File has TIFF thumbnail');
    data.remove('TIFFThumbnail');
  }

  List<String> tag_keys = data.keys.toList();
  tag_keys.sort();

  for (String key in tag_keys) {
    // try {
      printFunc("$key (${data[key].tagType}): ${data[key]}");
    // } catch (e) {
    //   printFunc("$i : ${data[i]}");
    // }
  }
}
