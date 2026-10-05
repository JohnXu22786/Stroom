import 'package:flutter/material.dart' show BuildContext;
import 'package:image_picker/image_picker.dart' show XFile;

import 'system_gallery_picker_stub.dart'
    if (dart.library.io) 'system_gallery_picker_io.dart' as implementation;

Future<List<XFile>> pickNativeGalleryMedia(
  BuildContext context, {
  required bool isVideo,
  double? maxWidth,
  double? maxHeight,
  int? imageQuality,
}) {
  return implementation.pickNativeGalleryMedia(
    context,
    isVideo: isVideo,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    imageQuality: imageQuality,
  );
}
