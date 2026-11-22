import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../utils/web_file_store.dart';

Future<String?> createVideoGalleryWebSource(
  String storageKey,
  String mimeType,
) async {
  final bytes = await WebFileStore.read(storageKey);
  if (bytes == null || bytes.isEmpty) return null;
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  return web.URL.createObjectURL(blob);
}

void revokeVideoGalleryWebSource(String? source) {
  if (source != null) web.URL.revokeObjectURL(source);
}
