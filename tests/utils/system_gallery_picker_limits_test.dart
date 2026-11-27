import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/system_gallery_picker_io.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

void main() {
  test(
    'missing constrained thumbnail fails instead of exposing the original',
    () async {
      var requestedSize = const ThumbnailSize(0, 0);
      var requestedQuality = 0;

      await expectLater(
        createConstrainedGalleryImageFile(
          title: 'large-photo.png',
          width: 4000,
          height: 3000,
          maxWidth: 800,
          maxHeight: 600,
          imageQuality: 72,
          thumbnailDataWithSize: (size, {required format, required quality}) {
            requestedSize = size;
            requestedQuality = quality;
            return Future<Uint8List?>.value(null);
          },
        ),
        throwsA(isA<StateError>()),
      );

      expect(requestedSize.width, 800);
      expect(requestedSize.height, 600);
      expect(requestedQuality, 72);
    },
  );

  test('constrained thumbnail is returned as a JPEG XFile', () async {
    final file = await createConstrainedGalleryImageFile(
      title: 'photo.png',
      width: 4000,
      height: 2000,
      maxWidth: 1000,
      maxHeight: null,
      imageQuality: null,
      thumbnailDataWithSize: (size, {required format, required quality}) async {
        expect(size.width, 1000);
        expect(size.height, 500);
        expect(format, ThumbnailFormat.jpeg);
        expect(quality, 100);
        return Uint8List.fromList([1, 2, 3]);
      },
    );

    expect(file.mimeType, 'image/jpeg');
    expect(await file.readAsBytes(), [1, 2, 3]);
  });
}
