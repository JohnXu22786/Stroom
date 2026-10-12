import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/ocr/ocr_retry_snapshot.dart';

void main() {
  group('OcrRetrySnapshot', () {
    test('serializes image references without image bodies', () {
      const firstRef =
          'ocr_retry_cache/0000000000000000000000000000000000000000000000000000000000000000.bin';
      const secondRef =
          'ocr_retry_cache/1111111111111111111111111111111111111111111111111111111111111111.bin';
      final snapshot = OcrRetrySnapshot.capture(
        configId: 'config-stable-2',
        modelId: 'model-stable-7',
        images: [
          const OcrRetryImage.reference(
            storageRef: firstRef,
            format: 'png',
            name: 'first.png',
          ),
          const OcrRetryImage.reference(
            storageRef: secondRef,
            format: 'jpeg',
            name: 'second.jpg',
          ),
        ],
        instructionContent: '  exact instruction  ',
        saveFolder: 'receipts/2026',
      );

      final serialized = snapshot.toMap();
      final images =
          (serialized['images'] as List).cast<Map<String, dynamic>>();

      expect(serialized['version'], OcrRetrySnapshot.currentVersion);
      expect(serialized['modelRef'], {
        'configId': 'config-stable-2',
        'modelId': 'model-stable-7',
      });
      expect(images.map((image) => image['storageRef']), [firstRef, secondRef]);
      expect(images.every((image) => !image.containsKey('bytes')), isTrue);
      expect(serialized['instructionContent'], '  exact instruction  ');
      expect(serialized['saveFolder'], 'receipts/2026');

      final restored = OcrRetrySnapshot.fromMap(serialized);
      expect(restored.configId, 'config-stable-2');
      expect(restored.modelId, 'model-stable-7');
      expect(restored.images.every((image) => image.bytes == null), isTrue);
    });

    test('current snapshots with unknown fields require migration', () {
      const reference =
          'ocr_retry_cache/0000000000000000000000000000000000000000000000000000000000000000.bin';
      const credential = 'unexpected-v2-credential';
      final imageBody = 'data:image/png;base64,${base64Encode([1, 2, 3, 4])}';
      final snapshot = OcrRetrySnapshot.fromMap({
        'type': 'ocr',
        'version': OcrRetrySnapshot.currentVersion,
        'modelRef': {
          'configId': 'config-1',
          'modelId': 'model-1',
          'credential': credential,
        },
        'images': [
          {
            'storageRef': reference,
            'format': 'png',
            'embeddedImage': imageBody,
          },
        ],
        'apiKey': credential,
      });

      expect(snapshot.needsMigration, isTrue);
      final sanitized = jsonEncode(snapshot.toMap());
      expect(sanitized, isNot(contains(credential)));
      expect(sanitized, isNot(contains(imageBody)));
    });

    test('current snapshots with malformed entries require migration', () {
      final snapshot = OcrRetrySnapshot.fromMap({
        'type': 'ocr',
        'version': 2,
        'modelRef': {'configId': 'config-1', 'modelId': 'model-1'},
        'images': [
          {
            'storageRef':
                'ocr_retry_cache/0000000000000000000000000000000000000000000000000000000000000000.bin',
            'format': 'png',
          },
          {'bytes': 'not-valid-base64!!!', 'format': 'png'},
        ],
      });

      expect(snapshot.hasInvalidImages, isTrue);
      expect(snapshot.imageEntryCount, 2);
      expect(snapshot.needsMigration, isTrue);
    });

    test('invalid optional metadata does not discard valid images', () {
      const reference =
          'ocr_retry_cache/0000000000000000000000000000000000000000000000000000000000000000.bin';
      const bytes = [1, 2, 3, 4];
      final snapshot = OcrRetrySnapshot.fromMap({
        'type': 'ocr',
        'version': 2,
        'modelRef': {'configId': 'config-1', 'modelId': 'model-1'},
        'images': [
          {
            'bytes': base64Encode(bytes),
            'format': 7,
            'name': {'invalid': 'type'},
          },
          {
            'storageRef': reference,
            'format': ['png'],
            'name': 9,
          },
        ],
      });

      expect(snapshot.hasInvalidImages, isFalse);
      expect(snapshot.hasInvalidImageMetadata, isTrue);
      expect(snapshot.needsMigration, isTrue);
      expect(snapshot.images, hasLength(2));
      expect(snapshot.images.first.bytes?.toList(), bytes);
      expect(snapshot.images.first.format, '');
      expect(snapshot.images.first.name, isNull);
      expect(snapshot.images.last.storageRef, reference);
      expect(snapshot.images.last.format, '');
      expect(snapshot.images.last.name, isNull);
    });

    test('infers format from valid inline bytes when metadata is malformed',
        () {
      final pngBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNgYGAAAAAEAAH2FzhVAAAAAElFTkSuQmCC',
      );
      final snapshot = OcrRetrySnapshot.fromMap({
        'type': 'ocr',
        'version': 2,
        'images': [
          {'bytes': base64Encode(pngBytes), 'format': 7},
        ],
      });

      expect(snapshot.hasInvalidImageMetadata, isTrue);
      expect(snapshot.images.single.bytes, pngBytes);
      expect(snapshot.images.single.format, 'png');
    });
  });
}
