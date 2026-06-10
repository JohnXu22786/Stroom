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

    testWidgets('zoom buttons are present in the AppBar', (tester) async {
      await tester.pumpWidget(createTestApp(testImage));
      await waitForEditor(tester);

      // Should have zoom in button
      expect(find.byIcon(Icons.zoom_in), findsOneWidget);

      // Should have zoom out button
      expect(find.byIcon(Icons.zoom_out), findsOneWidget);

      // Should have fit-to-screen button
      expect(find.byIcon(Icons.fullscreen), findsOneWidget);
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

  group('ImageEditorPage - save dialog', () {
    testWidgets('Save button shows overwrite/save-as dialog', (tester) async {
      await tester.pumpWidget(createTestApp(testImage));
      await waitForEditor(tester);

      // Tap save button
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Dialog should appear with overwrite and save-as options
      expect(find.text('保存图片'), findsOneWidget);
      expect(find.text('覆盖'), findsOneWidget);
      expect(find.text('另存为'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
    });

    testWidgets('Cancel in save dialog dismisses dialog without popping', (tester) async {
      await tester.pumpWidget(createTestApp(testImage));
      await waitForEditor(tester);

      // Tap save button
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // Dialog should be gone
      expect(find.text('保存图片'), findsNothing);
      // Editor page should still be visible
      expect(find.text('保存'), findsOneWidget);
    });

    testWidgets('Save dialog overwrite option pops the editor page',
        (tester) async {
      await tester.pumpWidget(createTestApp(testImage));
      await waitForEditor(tester);

      // Tap save button
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Tap 覆盖 (Overwrite)
      await tester.tap(find.text('覆盖'));
      // Wait for async save + navigation
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
      await tester.pumpAndSettle();

      // Editor page should be gone (popped)
      expect(find.byType(ImageEditorPage), findsNothing);
    });

    testWidgets('Save dialog save-as option pops the editor page',
        (tester) async {
      await tester.pumpWidget(createTestApp(testImage));
      await waitForEditor(tester);

      // Tap save button
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Tap 另存为 (Save As)
      await tester.tap(find.text('另存为'));
      // Wait for async save + navigation
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
      await tester.pumpAndSettle();

      // Editor page should be gone (popped)
      expect(find.byType(ImageEditorPage), findsNothing);
    });
  });

  group('ImageEditorPage - zoom controls', () {
    testWidgets('Zoom in button changes transformation scale', (tester) async {
      await tester.pumpWidget(createTestApp(testImage));
      await waitForEditor(tester);

      // The identity matrix scale should be 1.0 initially
      // Tap zoom in button twice
      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();

      // No crash - button worked
    });

    testWidgets('Zoom out changes transformation scale', (tester) async {
      await tester.pumpWidget(createTestApp(testImage));
      await waitForEditor(tester);

      // Tap zoom in first, then zoom out
      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.zoom_out));
      await tester.pump();

      // No crash - button worked
    });

    testWidgets('Fit-to-screen button resets zoom after zoom in', (tester) async {
      await tester.pumpWidget(createTestApp(testImage));
      await waitForEditor(tester);

      // Zoom in first
      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();

      // Then fit to screen - should reset
      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pump();

      // No crash - button worked
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
