import 'package:flutter/material.dart' show BuildContext;
import 'package:image_picker/image_picker.dart' show XFile;

Future<List<XFile>> pickNativeGalleryMedia(
  BuildContext context, {
  required bool isVideo,
  double? maxWidth,
  double? maxHeight,
  int? imageQuality,
}) {
  throw UnsupportedError('The native gallery picker is unavailable on Web.');
}
