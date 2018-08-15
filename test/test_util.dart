library dartexif.test.test_util;

import 'dart:mirrors';

import 'package:path/path.dart' as p;

final String testDirPath = p.dirname(p.fromUri(currentMirrorSystem()
    .findLibrary(const Symbol('dartexif.test.test_util'))
    .uri));
