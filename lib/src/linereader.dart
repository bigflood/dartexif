import 'dart:convert';

import 'file_interface.dart';

class LineReader {
  FileReader file;
  final List<int> _buffer = [];
  bool _endOfFile = false;

  LineReader(this.file);

  String popString(int n) {
    String s;

    if (n < _buffer.length) {
      s = utf8.decode(_buffer.sublist(0, n));
      _buffer.removeRange(0, n);
    } else {
      s = utf8.decode(_buffer);
      _buffer.clear();
    }

    return s;
  }

  String readLine() {
    int endOfLine = _buffer.indexOf(10);
    if (endOfLine >= 0) {
      return popString(endOfLine + 1);
    }

    if (_endOfFile) {
      return popString(_buffer.length);
    }

    while (true) {
      final r = file.readSync(1024 * 10);

      if (r.isEmpty) {
        _endOfFile = true;
        endOfLine = -1;
      } else {
        endOfLine = r.indexOf(10);
        _buffer.addAll(r);
        if (endOfLine >= 0) {
          endOfLine += _buffer.length;
        }
      }

      if (endOfLine >= 0) {
        return popString(endOfLine + 1);
      } else if (_endOfFile) {
        return popString(_buffer.length);
      }
    }
  }
}
