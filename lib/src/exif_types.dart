abstract class IfdTag {
  // tag ID number
  int? get tag;

  String get tagType;

  // printable version of data
  String? get printable;

  // list of data items (int(char or number) or Ratio)
  List? get values;
}

// Ratio object that eventually will be able to reduce itself to lowest
// common denominator for printing.
class Ratio {
  int numerator, denominator;

  Ratio(this.numerator, this.denominator) {
    if (denominator < 0) {
      numerator *= -1;
      denominator *= -1;
    }
  }

  @override
  String toString() {
    reduce();
    if (denominator == 1) {
      return this.numerator.toString();
    }

    return '$numerator/$denominator';
  }

  static int? _gcd(a, b) {
    if (b == 0) {
      return a;
    } else {
      return _gcd(b, a % b);
    }
  }

  void reduce() {
    int d = _gcd(this.numerator, this.denominator)!;
    if (d > 1) {
      this.numerator = this.numerator ~/ d;
      this.denominator = this.denominator ~/ d;
    }
  }
}
