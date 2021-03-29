import "package:test/test.dart";
import 'package:exif/src/util.dart';

void main() {
  test("make_string_uc", () {
    expect(make_string_uc([]), equals(""));
    expect(make_string_uc([1, 2, 3, 4, 5, 6, 7]), equals(""));
    expect(make_string_uc([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]), equals("[9, 10]"));
    expect(make_string_uc([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]), equals("[9, 10]"));
    expect(make_string_uc([1, 2, 3, 4, 5, 6, 7, 8, 97, 98, 99]), equals("abc"));
  });
}
