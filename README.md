# exif
[![Build Status](https://travis-ci.org/bigflood/dartexif.svg?branch=master)](https://travis-ci.org/bigflood/dartexif)

Dart module to decode Exif data from tiff and jpeg files.

Dart port of ianaré sévi's EXIF library: <https://github.com/ianare/exif-py>.

## Usage

* Simple example:
```dart
printExifOf(String path) async {

  Map<String, IfdTag> data = readExifFromBytes(await new File(path).readAsBytes());

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

  for (String key in data.keys) {
    printFunc("$key (${data[key].tagType}): ${data[key]}");
  }
  
}
```

* example app: https://github.com/bigflood/exifviewer
