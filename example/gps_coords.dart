import 'dart:io';

import 'package:exif/exif.dart';

Future main(List<String> arguments) async {
  for (final filename in arguments) {
    print("read $filename ..");

    final fileBytes = File(filename).readAsBytesSync();
    final data = await readExifFromBytes(fileBytes);

    if (data == null || data.isEmpty) {
      print("No EXIF information found");
      return;
    }

    final latRef = data['GPS GPSLatitudeRef']?.toString();
    var latVal = gpsValuesToFloat(data['GPS GPSLatitude']?.values);
    final lngRef = data['GPS GPSLongitudeRef']?.toString();
    var lngVal = gpsValuesToFloat(data['GPS GPSLongitude']?.values);

    if (latRef == null || latVal == null || lngRef == null || lngVal == null) {
      print("GPS information not found");
      return;
    }

    if (latRef == 'S') {
      latVal *= -1;
    }

    if (lngRef == 'W') {
      lngVal *= -1;
    }

    print("lat = $latVal");
    print("lng = $lngVal");
  }
}

double? gpsValuesToFloat(List? values) {
  if (values == null) {
    return null;
  }

  double sum = 0.0;
  double unit = 1.0;

  for (final v in values) {
    if (v is Ratio) {
      sum += (v.numerator / v.denominator) * unit;
    }
    unit /= 60.0;
  }

  return sum;
}
