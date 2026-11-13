import 'video_gallery_web_source_stub.dart'
    if (dart.library.html) 'video_gallery_web_source_web.dart'
    as web;

Future<String?> createVideoGalleryWebSource(
  String storageKey,
  String mimeType,
) => web.createVideoGalleryWebSource(storageKey, mimeType);

void revokeVideoGalleryWebSource(String? source) =>
    web.revokeVideoGalleryWebSource(source);
