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

    test('rejects compressed images above the OCR pixel allocation limit',
        () async {
      final oversized = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 10, height: 10)),
      );
      var frameHeader = -1;
      for (var i = 0; i + 8 < oversized.length; i++) {
        if (oversized[i] == 0xff &&
            const [0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb]
                .contains(oversized[i + 1])) {
          frameHeader = i;
          break;
        }
      }
      expect(frameHeader, isNonNegative);

      void setUint16(int offset, int value) {
        oversized[offset] = value >> 8;
        oversized[offset + 1] = value & 0xff;
      }

      setUint16(frameHeader + 5, 10000);
      setUint16(frameHeader + 7, 10000);

      await expectLater(
        prepareOcrImagePayload(oversized),
        throwsA(isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('分辨率过大'),
        )),
      );
    });

    test('preflights EXIF JPEG to PNG expansion against request budget', () {
      final exif = img.ExifData()..imageIfd.orientation = 6;
      final bytes = Uint8List.fromList(
        img.injectJpgExif(
          img.encodeJpg(img.Image(width: 10, height: 10)),
          exif,
        )!,
      );
      var frameHeader = -1;
      for (var i = 0; i + 8 < bytes.length; i++) {
        if (bytes[i] == 0xff &&
            const [0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb]
                .contains(bytes[i + 1])) {
          frameHeader = i;
          break;
        }
      }
      expect(frameHeader, isNonNegative);

      void setUint16(int offset, int value) {
        bytes[offset] = value >> 8;
        bytes[offset + 1] = value & 0xff;
      }

      setUint16(frameHeader + 5, 3000);
      setUint16(frameHeader + 7, 3000);

      expect(
        () => prepareOcrImagePayloadSync(
          bytes,
          maxReencodedPngBytes: 1024,
        ),
        throwsA(isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('PNG 会超过'),
        )),
      );

      final webp = img.encodeWebP(
        img.Image(width: 10, height: 10)..exif = exif,
      );
      expect(
        () => prepareOcrImagePayloadSync(
          webp,
          maxReencodedPngBytes: 1024,
        ),
        throwsA(isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('PNG 会超过'),
        )),
      );
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

    test('applies WebP EXIF orientation to the normalized PNG pixels', () {
      final source = img.Image(width: 4, height: 3, numChannels: 3);
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width; x++) {
          source.setPixelRgb(x, y, x * 50, y * 70, (x + y) * 30);
        }
      }
      final exif = img.ExifData()..imageIfd.orientation = 6;
      final webp = img.encodeWebP(source..exif = exif);
      final decoder = img.WebPDecoder()..startDecode(webp);
      final rawFrame = decoder.decodeFrame(0)!;
      expect(decoder.info?.exif, isNotNull);
      final sourceOrientation = img.ExifData.fromInputBuffer(
        img.InputBuffer(decoder.info!.exif.codeUnits),
      ).imageIfd.orientation!;
      expect(sourceOrientation, 6);

      final frameWithoutExif = img.Image.from(rawFrame)
        ..exif.imageIfd.orientation = null;
      expect(frameWithoutExif.exif.imageIfd.orientation, isNull);
      final expectedOriented = applyOcrImageSourceOrientation(
        frameWithoutExif,
        sourceOrientation,
      );

      final prepared = prepareOcrImagePayloadSync(webp);
      final oriented = img.decodePng(prepared.bytes)!;

      expect(prepared.format, 'png');
      expect(prepared.width, 3);
      expect(prepared.height, 4);
      expect(oriented.width, 3);
      expect(oriented.height, 4);
      expect(expectedOriented.width, 3);
      expect(expectedOriented.height, 4);
      for (var y = 0; y < expectedOriented.height; y++) {
        for (var x = 0; x < expectedOriented.width; x++) {
          final actual = oriented.getPixel(x, y);
          final expected = rawFrame.getPixel(y, rawFrame.height - 1 - x);
          final helperPixel = expectedOriented.getPixel(x, y);
          expect(actual.r, expected.r, reason: 'pixel ($x, $y) red channel');
          expect(actual.g, expected.g, reason: 'pixel ($x, $y) green channel');
          expect(actual.b, expected.b, reason: 'pixel ($x, $y) blue channel');
          expect(
            helperPixel.r,
            expected.r,
            reason: 'metadata-free helper pixel ($x, $y) red channel',
          );
          expect(
            helperPixel.g,
            expected.g,
            reason: 'metadata-free helper pixel ($x, $y) green channel',
          );
          expect(
            helperPixel.b,
            expected.b,
            reason: 'metadata-free helper pixel ($x, $y) blue channel',
          );
        }
      }
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
