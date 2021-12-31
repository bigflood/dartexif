# exif

[![Pub Package](https://img.shields.io/pub/v/exif.svg)](https://pub.dev/packages/exif)
[![Dart CI](https://github.com/bigflood/dartexif/actions/workflows/dart.yml/badge.svg)](https://github.com/bigflood/dartexif/actions/workflows/dart.yml)

Dart package to decode Exif data from tiff, jpeg and heic files.

Dart port of ianaré sévi's EXIF library: <https://github.com/ianare/exif-py>.

## Usage

* Simple example:
```dart
printExifOf(String path) async {

  final fileBytes = File(path).readAsBytesSync();
  final data = await readExifFromBytes(fileBytes);

  if (data.isEmpty) {
    print("No EXIF information found");
    return;
  }

  if (data.containsKey('JPEGThumbnail')) {
    print('File has JPEG thumbnail');
    data.remove('JPEGThumbnail');
  }
  if (data.containsKey('TIFFThumbnail')) {
    print('File has TIFF thumbnail');
    data.remove('TIFFThumbnail');
  }

  for (final entry in data.entries) {
    print("${entry.key}: ${entry.value}");
  }
  
}
```

* example app: https://github.com/bigflood/exifviewer
