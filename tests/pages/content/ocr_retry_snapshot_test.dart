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
      final images = (serialized['images'] as List)
          .cast<Map<String, dynamic>>();

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
  });
}
