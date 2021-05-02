class FieldType {
  final int _value;
  final int length;
  final String abbr;
  final String name;
  final bool isValid;
  final bool isSigned;

  const FieldType(this._value, this.length, this.abbr, this.name,
      {this.isValid = true, this.isSigned = false});

  factory FieldType.ofValue(int v) {
    if (v < 0 || v >= fieldTypes.length) {
      return FieldType(v, 0, 'X', 'Unknown', isValid: false);
    }
    return fieldTypes[v];
  }

  @override
  bool operator ==(Object other) =>
      other is FieldType && _value == other._value;

  @override
  int get hashCode => _value.hashCode;

  static const proprietary =
      FieldType(0, 0, 'X', 'Proprietary', isValid: false); // no such type
  static const byte = FieldType(1, 1, 'B', 'Byte');
  static const ascii = FieldType(2, 1, 'A', 'ASCII');
  static const short = FieldType(3, 2, 'S', 'Short');
  static const long = FieldType(4, 4, 'L', 'Long');
  static const ratio = FieldType(5, 8, 'R', 'Ratio');
  static const signedByte =
      FieldType(6, 1, 'SB', 'Signed Byte', isSigned: true);
  static const undefined = FieldType(7, 1, 'U', 'Undefined');
  static const signedShort =
      FieldType(8, 2, 'SS', 'Signed Short', isSigned: true);
  static const signedLong =
      FieldType(9, 4, 'SL', 'Signed Long', isSigned: true);
  static const signedRatio =
      FieldType(10, 8, 'SR', 'Signed Ratio', isSigned: true);
  static const f32 =
      FieldType(11, 4, 'F32', 'Single-Precision Floating Point (32-bit)');
  static const f64 =
      FieldType(12, 8, 'F64', 'Double-Precision Floating Point (64-bit)');
  static const ifd = FieldType(13, 4, 'L', 'IFD');
}

// field type descriptions as (length, abbreviation, full name) tuples
const fieldTypes = [
  FieldType.proprietary, // no such type
  FieldType.byte,
  FieldType.ascii,
  FieldType.short,
  FieldType.long,
  FieldType.ratio,
  FieldType.signedByte,
  FieldType.undefined,
  FieldType.signedShort,
  FieldType.signedLong,
  FieldType.signedRatio,
  FieldType.f32,
  FieldType.f64,
  FieldType.ifd,
];
