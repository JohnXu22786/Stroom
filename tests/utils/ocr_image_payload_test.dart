import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:stroom/utils/ocr_image_payload.dart';

void main() {
  group('prepareOcrImagePayload', () {
    test('detects PNG, JPEG and WebP from their bytes', () async {
      final image = img.Image(width: 3, height: 2, numChannels: 3);
      final fixtures = [
        (img.encodePng(image), 'png', 'image/png'),
        (img.encodeJpg(image, quality: 90), 'jpeg', 'image/jpeg'),
        (img.encodeWebP(image), 'webp', 'image/webp'),
      ];

      for (final (bytes, format, mimeType) in fixtures) {
        final prepared = await prepareOcrImagePayload(bytes);
        expect(prepared.format, format);
        expect(prepared.mimeType, mimeType);
        expect(prepared.bytes, bytes);
        expect(prepared.width, 3);
        expect(prepared.height, 2);
      }
    });

    test('rejects empty and corrupt data and guides unsupported formats',
        () async {
      await expectLater(
        prepareOcrImagePayload(Uint8List(0)),
        throwsA(isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('为空'),
        )),
      );
      await expectLater(
        prepareOcrImagePayload(Uint8List.fromList([0xff, 0xd8, 0xff, 0x00])),
        throwsA(isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('损坏'),
        )),
      );

      final unsupported = <Uint8List>[
        Uint8List.fromList([0x49, 0x49, 0x2a, 0x00, 0x08, 0x00]),
        Uint8List.fromList(
            [0x00, 0x00, 0x00, 0x18, ...ascii.encode('ftypheic')]),
        Uint8List.fromList(
            utf8.encode('<svg xmlns="http://www.w3.org/2000/svg"/>')),
      ];
      for (final bytes in unsupported) {
        await expectLater(
          prepareOcrImagePayload(bytes),
          throwsA(isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(contains('不支持'), contains('PNG'), contains('JPEG')),
          )),
        );
      }
    });

    test('bakes EXIF orientation into lossless PNG pixels', () async {
      final jpeg = img.encodeJpg(img.Image(width: 2, height: 3), quality: 90);
      final exif = img.ExifData()..imageIfd.orientation = 6;
      final orientedJpeg = img.injectJpgExif(jpeg, exif)!;
      expect(img.decodeJpgExif(orientedJpeg)?.imageIfd.orientation, 6);

      final prepared = await prepareOcrImagePayload(orientedJpeg);

      expect(prepared.format, 'png');
      expect(prepared.mimeType, 'image/png');
      expect(prepared.width, 3);
      expect(prepared.height, 2);
      expect(img.decodeImage(prepared.bytes), isNotNull);
    });
  });

  group('applyOcrImageImportQualitySync', () {
    test('standard desktop limits resize and encode at quality 90', () {
      final sourceBytes = img.encodePng(img.Image(width: 3000, height: 2200));
      final source = prepareOcrImagePayloadSync(sourceBytes);

      final prepared = applyOcrImageImportQualitySync(
        source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      expect(prepared.format, 'jpeg');
      expect(prepared.width, 2048);
      expect(prepared.height, lessThanOrEqualTo(2048));
      expect(prepared.bytes, isNot(sourceBytes));
    });

    test('null limits preserve original bytes and dimensions', () {
      final sourceBytes = img.encodePng(img.Image(width: 3000, height: 2200));
      final source = prepareOcrImagePayloadSync(sourceBytes);

      final prepared = applyOcrImageImportQualitySync(source);

      expect(prepared, same(source));
      expect(prepared.bytes, same(sourceBytes));
      expect(prepared.width, 3000);
      expect(prepared.height, 2200);
    });
  });
}
