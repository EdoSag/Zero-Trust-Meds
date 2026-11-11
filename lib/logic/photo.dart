import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The longest side of a stored child photo, in pixels.
const photoSize = 256;

/// Re-encodes a picked photo as a small JPEG with no metadata at all: no
/// GPS position, no camera or time. Rotation from the camera is applied
/// to the pixels first, so the photo still stands upright. Null when the
/// bytes aren't an image.
Uint8List? cleanPhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  if (image.width > photoSize || image.height > photoSize) {
    image = image.width >= image.height
        ? img.copyResize(image, width: photoSize)
        : img.copyResize(image, height: photoSize);
  }
  image.exif = img.ExifData();
  return img.encodeJpg(image, quality: 80);
}
