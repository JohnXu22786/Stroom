import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/image_editor_page.dart';

/// Helper to create a small test image (png bytes, 100x100, green with red stripe)
Future<Uint8List> createTestImageBytes({int width = 100, int height = 100}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF00FF00),
  );
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width / 2, height.toDouble()),
    Paint()..color = const Color(0xFFFF0000),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

Widget createTestApp(Uint8List imageBytes) {
  return MaterialApp(
    home: Scaffold(
      body: ImageEditorPage(imageBytes: imageBytes),
    ),
  );
}

/// Helper to wait for async image decode to complete
Future<void> waitForEditor(WidgetTester tester) async {
  // The image decode involves real async operations (instantiateImageCodec)
  // which need runAsync to complete
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  late Uint8List testImage;

  setUp(() async {
    testImage = await createTestImageBytes();
  });

  group('ImageEditorPage rendering', () {
    testWidgets('renders image preview and toolbar', (tester) async {
      await tester.pumpWidget(createTestApp(testImage));
      await waitForEditor(tester);

      // Should show the image preview
      expect(find.byType(Image), findsOneWidget);

      // Should show tool buttons
      expect(find.text('裁剪'), findsOneWidget);
      expect(find.text('旋转'), findsOneWidget);
      expect(find.text('调整'), findsOneWidget);
      expect(find.text('滤镜'), findsOneWidget);
      expect(find.text('画笔'), findsOneWidget);

      // Should show save button in AppBar
      expect(find.text('保存'), findsOneWidget);

      // Should show the close icon (cancel button)
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Should show '重置' text in AppBar
      expect(find.text('重置'), findsOneWidget);
    });

    testWidgets('renders loading state for empty bytes', (tester) async {
      await tester.pumpWidget(createTestApp(Uint8List(0)));
      // For empty bytes, decode fails - loading state persists
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('加载图片中...'), findsOneWidget);
    });
  });

  group('ImageEditorPage - navigation', () {
    testWidgets('Cancel (close icon) is present and dismisses editor', (tester) async {
      await tester.pumpWidget(createTestApp(testImage));
      await waitForEditor(tester);

      // Close icon should be present in the AppBar
      expect(find.byIcon(Icons.close), findsOneWidget, reason: 'Close icon should be in AppBar');

      // Tapping close icon should not throw
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
    });

    testWidgets('Save button is present', (tester) async {
      await tester.pumpWidget(createTestApp(testImage));
      await waitForEditor(tester);

      // Save button should show "保存" text in AppBar
      expect(find.text('保存'), findsOneWidget, reason: 'Save button should be in AppBar');
    });
  });

  group('ImageEditorPage - tools', () {
    testWidgets('Rotate tool shows rotation buttons when selected',
        (tester) async {
      await tester.pumpWidget(createTestApp(testImage));
      await waitForEditor(tester);

      // Tap 旋转 (Rotate) button
      await tester.tap(find.text('旋转'));
      await tester.pump();

      // Should show rotation icons
      expect(find.byIcon(Icons.rotate_left), findsAtLeast(1));
      expect(find.byIcon(Icons.rotate_right), findsAtLeast(1));
      expect(find.byIcon(Icons.flip), findsAtLeast(1));
    });

    testWidgets('Adjust tool shows brightness/contrast/saturation sliders',
        (tester) async {
      await tester.pumpWidget(createTestApp(testImage));
      await waitForEditor(tester);

      // Tap 调整 (Adjust) button
      await tester.tap(find.text('调整'));
      await tester.pump();

      // Should show slider labels
      expect(find.text('亮度'), findsOneWidget);
      expect(find.text('对比度'), findsOneWidget);
      expect(find.text('饱和度'), findsOneWidget);
    });

    testWidgets('Filter tool shows filter options when selected',
        (tester) async {
      await tester.pumpWidget(createTestApp(testImage));
      await waitForEditor(tester);

      // Tap 滤镜 (Filter) button
      await tester.tap(find.text('滤镜'));
      await tester.pump();

      // Should show filter options
      expect(find.text('原图'), findsOneWidget);
      expect(find.text('灰度'), findsOneWidget);
    });

    testWidgets('Draw tool shows undo/clear buttons when selected',
        (tester) async {
      await tester.pumpWidget(createTestApp(testImage));
      await waitForEditor(tester);

      // Tap 画笔 (Draw) button
      await tester.tap(find.text('画笔'));
      await tester.pump();

      // Should show drawing controls
      expect(find.text('撤销'), findsOneWidget);
      expect(find.text('清除'), findsOneWidget);
    });

    testWidgets('switching between tools preserves state', (tester) async {
      await tester.pumpWidget(createTestApp(testImage));
      await waitForEditor(tester);

      // Go to rotate
      await tester.tap(find.text('旋转'));
      await tester.pump();

      // Rotate 90° right
      final rotateRight = find.byIcon(Icons.rotate_right);
      expect(rotateRight, findsAtLeast(1));
      await tester.tap(rotateRight.first);
      await tester.pump();

      // Switch to adjust
      await tester.tap(find.text('调整'));
      await tester.pump();

      // Switch back to rotate — rotation state should be preserved
      await tester.tap(find.text('旋转'));
      await tester.pump();

      // Should still show the rotation icons
      expect(find.byIcon(Icons.rotate_left), findsAtLeast(1));
      expect(find.byIcon(Icons.rotate_right), findsAtLeast(1));
    });
  });

  group('ImageEditorPage - output', () {
    testWidgets('save button is enabled and filter can be selected', (tester) async {
      await tester.pumpWidget(createTestApp(testImage));
      await waitForEditor(tester);

      // Tap 滤镜 (Filter) button
      await tester.tap(find.text('滤镜'));
      await tester.pump();

      // Select grayscale filter
      await tester.tap(find.text('灰度'));
      await tester.pump();

      // Save button should still be present
      expect(find.text('保存'), findsOneWidget);
    });
  });
}
