import "package:test/test.dart";
import 'package:exif/src/util.dart';

void main() {
  test("make_string_uc", () {
    expect(makeStringUc([]), equals(""));
    expect(makeStringUc([1, 2, 3, 4, 5, 6, 7]), equals(""));
    expect(makeStringUc([1, 2, 3, 4, 5, 6, 7, 8, 97, 98, 99]), equals("abc"));
    expect(makeString([0, 2, 0, 0]), equals("0200"));
  });
}
