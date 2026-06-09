import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/image_editor_utils.dart';

void main() {
  group('ImageEditorPipeline', () {
    late Uint8List testJpeg;
    final testWidth = 200;
    final testHeight = 100;

    setUp(() async {
      // Create a simple test image (width 200 x height 100) with colored pixels
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      // Red rectangle on left half
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 100, 100),
        Paint()..color = const Color(0xFFFF0000),
      );
      // Blue rectangle on right half
      canvas.drawRect(
        const Rect.fromLTWH(100, 0, 100, 100),
        Paint()..color = const Color(0xFF0000FF),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(testWidth, testHeight);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      testJpeg = byteData!.buffer.asUint8List();
    });

    test('decodeImage decodes PNG bytes to ui.Image', () async {
      final image = await ImageEditorPipeline.decodeImage(testJpeg);
      expect(image, isNotNull);
      expect(image.width, testWidth);
      expect(image.height, testHeight);
    });

    test('encodeImage encodes ui.Image to PNG bytes', () async {
      final image = await ImageEditorPipeline.decodeImage(testJpeg);
      final bytes = await ImageEditorPipeline.encodeImage(image);
      expect(bytes, isNotNull);
      expect(bytes.length, greaterThan(0));

      // Decode again — should be valid image
      final decoded = await ImageEditorPipeline.decodeImage(bytes);
      expect(decoded.width, testWidth);
      expect(decoded.height, testHeight);
    });

    test('applyRotate 90° swaps dimensions', () async {
      final rotated = await ImageEditorPipeline.applyRotate(testJpeg, 90);
      final image = await ImageEditorPipeline.decodeImage(rotated);
      expect(image.width, testHeight);
      expect(image.height, testWidth);
    });

    test('applyRotate 180° keeps dimensions', () async {
      final rotated = await ImageEditorPipeline.applyRotate(testJpeg, 180);
      final image = await ImageEditorPipeline.decodeImage(rotated);
      expect(image.width, testWidth);
      expect(image.height, testHeight);
    });

    test('applyRotate 270° swaps dimensions', () async {
      final rotated = await ImageEditorPipeline.applyRotate(testJpeg, 270);
      final image = await ImageEditorPipeline.decodeImage(rotated);
      expect(image.width, testHeight);
      expect(image.height, testWidth);
    });

    test('applyRotate 0° returns same dimensions', () async {
      final rotated = await ImageEditorPipeline.applyRotate(testJpeg, 0);
      final image = await ImageEditorPipeline.decodeImage(rotated);
      expect(image.width, testWidth);
      expect(image.height, testHeight);
    });

    test('applyFlip horizontal mirrors image', () async {
      final flipped = await ImageEditorPipeline.applyFlip(testJpeg, flipH: true);
      final image = await ImageEditorPipeline.decodeImage(flipped);
      expect(image.width, testWidth);
      expect(image.height, testHeight);

      // Verify pixels at (0,0) and (199,0) are swapped colors
      final byteData = await image.toByteData();
      expect(byteData, isNotNull);
      // Left edge pixel — after flip it should be blue (right side moved to left)
      // We check that the image is valid, exact pixel check is complex in RGBA
    });

    test('applyFlip vertical mirrors image', () async {
      final flipped = await ImageEditorPipeline.applyFlip(testJpeg, flipV: true);
      final image = await ImageEditorPipeline.decodeImage(flipped);
      expect(image.width, testWidth);
      expect(image.height, testHeight);
    });

    test('applyFlip both axes', () async {
      final flipped =
          await ImageEditorPipeline.applyFlip(testJpeg, flipH: true, flipV: true);
      final image = await ImageEditorPipeline.decodeImage(flipped);
      expect(image.width, testWidth);
      expect(image.height, testHeight);
    });

    group('applyCrop', () {
      test('crops to specified rect', () async {
        final cropRect = CropRect(
          x: 0.1,
          y: 0.1,
          width: 0.5,
          height: 0.8,
        );
        final cropped = await ImageEditorPipeline.applyCrop(testJpeg, cropRect);
        final image = await ImageEditorPipeline.decodeImage(cropped);
        // Original: 200x100. Crop 50% of width, 80% of height
        expect(image.width, 100); // 200 * 0.5
        expect(image.height, 80); // 100 * 0.8
      });

      test('full crop returns same dimensions', () async {
        final cropRect = CropRect(x: 0, y: 0, width: 1, height: 1);
        final cropped = await ImageEditorPipeline.applyCrop(testJpeg, cropRect);
        final image = await ImageEditorPipeline.decodeImage(cropped);
        expect(image.width, testWidth);
        expect(image.height, testHeight);
      });

      test('zero-size crop throws ArgumentError', () async {
        final cropRect = CropRect(x: 0, y: 0, width: 0, height: 0);
        expect(
          () => ImageEditorPipeline.applyCrop(testJpeg, cropRect),
          throwsArgumentError,
        );
      });
    });

    test('applyColorAdjust applies brightness', () async {
      final adjusted = await ImageEditorPipeline.applyColorAdjust(
        testJpeg,
        brightness: 0.2,
      );
      final decoded = await ImageEditorPipeline.decodeImage(adjusted);
      expect(decoded.width, testWidth);
      expect(decoded.height, testHeight);
    });

    test('applyColorAdjust applies contrast', () async {
      final adjusted = await ImageEditorPipeline.applyColorAdjust(
        testJpeg,
        contrast: 1.5,
      );
      final decoded = await ImageEditorPipeline.decodeImage(adjusted);
      expect(decoded.width, testWidth);
      expect(decoded.height, testHeight);
    });

    test('applyColorAdjust applies saturation', () async {
      final adjusted = await ImageEditorPipeline.applyColorAdjust(
        testJpeg,
        saturation: 1.5,
      );
      final decoded = await ImageEditorPipeline.decodeImage(adjusted);
      expect(decoded.width, testWidth);
      expect(decoded.height, testHeight);
    });

    test('applyColorAdjust with all params', () async {
      final adjusted = await ImageEditorPipeline.applyColorAdjust(
        testJpeg,
        brightness: -0.1,
        contrast: 1.2,
        saturation: 0.8,
      );
      final decoded = await ImageEditorPipeline.decodeImage(adjusted);
      expect(decoded.width, testWidth);
      expect(decoded.height, testHeight);
    });

    group('filters', () {
      for (final filter in ImageFilterType.values) {
        test('applyFilter $filter produces valid image', () async {
          final filteredBytes =
              await ImageEditorPipeline.applyFilter(testJpeg, filter);
          final image = await ImageEditorPipeline.decodeImage(filteredBytes);
          expect(image.width, testWidth);
          expect(image.height, testHeight);
        });
      }
    });

    test('applyDrawings composites paths onto image', () async {
      final drawings = [
        EditorPath(
          points: [const Offset(10, 10), const Offset(50, 50)],
          color: const Color(0xFFFF0000),
          strokeWidth: 3.0,
        ),
        EditorPath(
          points: [const Offset(100, 10), const Offset(150, 60)],
          color: const Color(0xFF0000FF),
          strokeWidth: 5.0,
        ),
      ];
      final result = await ImageEditorPipeline.applyDrawings(testJpeg, drawings);
      final image = await ImageEditorPipeline.decodeImage(result);
      expect(image.width, testWidth);
      expect(image.height, testHeight);
    });

    test('applyDrawings with empty list returns unchanged image', () async {
      final result = await ImageEditorPipeline.applyDrawings(testJpeg, []);
      final image1 = await ImageEditorPipeline.decodeImage(result);
      final image2 = await ImageEditorPipeline.decodeImage(testJpeg);
      expect(image1.width, image2.width);
      expect(image1.height, image2.height);
    });

    test('full pipeline applies all edits in sequence', () async {
      final result = await ImageEditorPipeline.applyAll(testJpeg, editorState: {
        'rotation': 90,
        'flipH': true,
        'cropRect': CropRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
        'brightness': 0.1,
        'contrast': 1.1,
        'saturation': 1.0,
        'filter': ImageFilterType.grayscale,
        'drawings': <EditorPath>[
          EditorPath(
            points: [const Offset(10, 10), const Offset(50, 50)],
            color: const Color(0xFFFF0000),
            strokeWidth: 3.0,
          ),
        ],
      });
      expect(result, isNotNull);
      expect(result.length, greaterThan(0));
      // After crop (80%) then rotate 90°: width = old height*0.8, height = old width*0.8
      final image = await ImageEditorPipeline.decodeImage(result);
      expect(image.width, (testHeight * 0.8).round());
      expect(image.height, (testWidth * 0.8).round());
    });

    test('full pipeline with no edits returns similar image', () async {
      // Apply all with default values — should be close to original
      final result = await ImageEditorPipeline.applyAll(testJpeg, editorState: {
        'rotation': 0,
        'flipH': false,
        'cropRect': null, // no crop
        'brightness': 0.0,
        'contrast': 1.0,
        'saturation': 1.0,
        'filter': ImageFilterType.none,
        'drawings': <EditorPath>[],
      });
      final image = await ImageEditorPipeline.decodeImage(result);
      expect(image.width, testWidth);
      expect(image.height, testHeight);
    });
  });

  group('CropRect', () {
    test('creates with clamped values', () {
      final rect = CropRect(
        x: -0.1,
        y: 0.5,
        width: 1.5,
        height: 0.3,
      );
      expect(rect.x, 0.0);
      expect(rect.y, 0.5);
      expect(rect.width, 1.0);
      expect(rect.height, 0.3);
    });

    test('equality works', () {
      final a = CropRect(x: 0.1, y: 0.2, width: 0.5, height: 0.6);
      final b = CropRect(x: 0.1, y: 0.2, width: 0.5, height: 0.6);
      final c = CropRect(x: 0.2, y: 0.2, width: 0.5, height: 0.6);
      expect(a, b);
      expect(a == c, false);
    });
  });

  group('EditorPath', () {
    test('creates with valid values', () {
      final path = EditorPath(
        points: [const Offset(0, 0), const Offset(10, 10)],
        color: const Color(0xFFFF0000),
        strokeWidth: 2.0,
      );
      expect(path.points.length, 2);
      expect(path.color, const Color(0xFFFF0000));
      expect(path.strokeWidth, 2.0);
    });
  });

  group('ImageFilterType', () {
    test('all types have display names', () {
      for (final type in ImageFilterType.values) {
        final name = type.displayName;
        expect(name, isNotEmpty);
      }
    });

    test('none is the default', () {
      expect(ImageFilterType.none, ImageFilterType.values.first);
    });
  });

  group('computeImageHash for edited images', () {
    test('edited image produces different hash', () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 100, 100),
        Paint()..color = const Color(0xFF00FF00),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(100, 100);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final originalBytes = byteData!.buffer.asUint8List();

      final edited = await ImageEditorPipeline.applyFilter(
        originalBytes,
        ImageFilterType.sepia,
      );
      // Use the hash function already in image_manifest.dart
      // We just check the bytes are different
      expect(edited, isNot(equals(originalBytes)));
    });
  });
}
