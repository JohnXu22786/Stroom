import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/ocr/ocr_retry_snapshot.dart';

void main() {
  group('OcrRetrySnapshot', () {
    test(
      'round trips stable refs and ordered execution inputs without secrets',
      () {
        final snapshot = OcrRetrySnapshot.capture(
          configId: 'config-stable-2',
          modelId: 'model-stable-7',
          images: [
            OcrRetryImage(
              bytes: Uint8List.fromList([1, 2, 3]),
              format: 'png',
              name: 'first.png',
            ),
            OcrRetryImage(
              bytes: Uint8List.fromList([4, 5]),
              format: 'jpeg',
              name: 'second.jpg',
            ),
          ],
          instructionContent: '  exact instruction  ',
          saveFolder: 'receipts/2026',
        );

        final serialized = snapshot.toMap();

        expect(serialized['version'], OcrRetrySnapshot.currentVersion);
        expect(serialized['modelRef'], {
          'configId': 'config-stable-2',
          'modelId': 'model-stable-7',
        });
        expect(
          (serialized['images'] as List).map((image) => image['name']).toList(),
          ['first.png', 'second.jpg'],
        );
        expect(
          (serialized['images'] as List)
              .map((image) => base64Decode(image['bytes'] as String).toList())
              .toList(),
          [
            [1, 2, 3],
            [4, 5],
          ],
        );
        expect(serialized['instructionContent'], '  exact instruction  ');
        expect(serialized['saveFolder'], 'receipts/2026');
        expect(serialized.keys.toSet(), {
          'type',
          'version',
          'modelRef',
          'images',
          'instructionContent',
          'saveFolder',
        });
        expect(
          (serialized['images'] as List).cast<Map<String, dynamic>>().every(
                (image) =>
                    image.keys
                        .toSet()
                        .containsAll({'bytes', 'format', 'name'}) &&
                    image.keys.length == 3,
              ),
          isTrue,
        );

        final restored = OcrRetrySnapshot.fromMap(serialized);
        expect(restored.isLegacy, isFalse);
        expect(restored.configId, 'config-stable-2');
        expect(restored.modelId, 'model-stable-7');
        expect(restored.instructionContent, '  exact instruction  ');
        expect(restored.saveFolder, 'receipts/2026');
        expect(restored.images.map((image) => image.format), ['png', 'jpeg']);
        expect(restored.images.map((image) => image.name), [
          'first.png',
          'second.jpg',
        ]);
      },
    );
  });
}
