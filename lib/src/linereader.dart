import 'dart:io';
import 'dart:async';
import 'dart:convert';

class LineReader {
  RandomAccessFile file;
  List<int> buffer;
  bool endoffile = false;

  LineReader(this.file);

  String popString(int n) {
    String s;

    if (n < buffer.length) {
      s = UTF8.decode(buffer.sublist(0, n));
      buffer.removeRange(0, n);
    } else {
      s = UTF8.decode(buffer);
      buffer.clear();
    }

    return s;
  }

  Future<String> readline() async {
    if (buffer == null) {
      buffer = [];
    }

    int endofline = buffer.indexOf(10);
    if (endofline >= 0) {
      return popString(endofline + 1);
    }

    if (endoffile) {
      return popString(buffer.length);
    }

    while (true) {
      List<int> r = await file.read(1024 * 10);

      if (r == null || r.isEmpty) {
        endoffile = true;
        endofline = -1;
      } else {
        endofline = r.indexOf(10);
        buffer.addAll(r);
        if (endofline >= 0) {
          endofline += buffer.length;
        }
      }

      if (endofline >= 0) {
        return popString(endofline + 1);
      } else if (endoffile) {
        return popString(buffer.length);
      }
    }
  }
}
