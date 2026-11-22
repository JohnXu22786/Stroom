import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/video_gallery_web_source.dart';
import 'package:stroom/utils/web_file_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('creates and revokes a blob URL for stored video bytes', skip: !kIsWeb,
      () async {
    WebFileStore.enableTestMode();
    addTearDown(WebFileStore.disableTestMode);
    await WebFileStore.write(
      'videos/sample.mp4',
      Uint8List.fromList([0, 1, 2, 3]),
    );

    final source = await createVideoGalleryWebSource(
      'videos/sample.mp4',
      'video/mp4',
    );

    expect(source, startsWith('blob:'));
    revokeVideoGalleryWebSource(source);
  });

  test('returns null when video bytes are missing or empty', skip: !kIsWeb,
      () async {
    WebFileStore.enableTestMode();
    addTearDown(WebFileStore.disableTestMode);
    await WebFileStore.write('videos/empty.mp4', Uint8List(0));

    expect(
      await createVideoGalleryWebSource('videos/missing.mp4', 'video/mp4'),
      isNull,
    );
    expect(
      await createVideoGalleryWebSource('videos/empty.mp4', 'video/mp4'),
      isNull,
    );
    revokeVideoGalleryWebSource(null);
  });
}
