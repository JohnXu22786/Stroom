import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

Future<List<XFile>> pickNativeGalleryMedia(
  BuildContext context, {
  required bool isVideo,
  double? maxWidth,
  double? maxHeight,
  int? imageQuality,
}) async {
  throw UnsupportedError('The native gallery picker is unavailable on web.');
}
