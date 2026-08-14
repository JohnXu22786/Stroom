import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:stroom/pages/extended_image_editor_page.dart';

/// Creates a small valid PNG (8x8 green) via the real engine.
///
/// Must be called from `tester.runAsync` — engine image work never
/// completes inside the widget-test FakeAsync zone.
Future<Uint8List> createTestImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, 8, 8),
    Paint()..color = const Color(0xFF00FF00),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(8, 8);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}

/// Pumps until [condition] is true or [timeout] elapses.
///
/// Background image processing alternates between engine calls (decode,
/// rasterize, encode — need real async) and fake-zone continuations
/// (need pumps), so each iteration runs a real-async window followed by
/// a pump.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      fail('Timed out waiting for condition');
    }
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Pushes [ExtendedImageEditorPage] from a host button and waits for the
/// editor state to exist (the image must decode first — a real-async
/// process). Polls instead of sleeping a fixed time so a slow engine
/// decode on CI cannot race the test.
Future<void> _pushEditor(
  WidgetTester tester, {
  required Uint8List imageBytes,
  ValueChanged<Uint8List?>? onPopResult,
  bool waitForEditorReady = true,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () async {
          final result = await Navigator.push<Uint8List>(
            context,
            MaterialPageRoute(
              builder: (_) => ExtendedImageEditorPage(
                imageBytes: imageBytes,
                fileName: 'test.png',
              ),
            ),
          );
          onPopResult?.call(result);
        },
        child: const Text('Open'),
      ),
    ),
  ));

  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));

  if (waitForEditorReady) {
    // The editor widget is only built after the image finishes loading.
    await pumpUntil(
      tester,
      () => find.byType(ExtendedImageEditor).evaluate().isNotEmpty,
    );
  } else {
    // Give the (failing) load a moment to settle either way.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
  }
}

/// 生成一张小尺寸 JPEG（8x8 渐变），作为"照片源"编辑夹具。
Uint8List _createSmallJpeg() {
  final im = img.Image(width: 8, height: 8, numChannels: 3);
  for (final p in im) {
    p
      ..r = p.x * 30
      ..g = p.y * 30
      ..b = 100;
  }
  return img.encodeJpg(im, quality: 90);
}

void main() {
  group('ExtendedImageEditorPage', () {
    testWidgets('close button pops with null', (tester) async {
      Uint8List? result;
      final png = await tester.runAsync(createTestImage);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.push<Uint8List>(
                context,
                MaterialPageRoute(
                  builder: (_) => ExtendedImageEditorPage(
                    imageBytes: png!,
                    fileName: 'test.jpg',
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump();

      // Tap close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(result, isNull);
    });

    // ====================================================================
    // In-place processing
    //
    // On 保存 the editor does NOT close immediately: it stays on screen
    // with a full-screen processing overlay while the image is decoded,
    // cropped, rotated and re-encoded. Only after the pipeline finishes
    // does the page pop back with the edited bytes. While processing, the
    // user cannot leave (system back / close / 保存 are all blocked).
    // ====================================================================
    group('in-place processing: the page stays open until the image is done',
        () {
      testWidgets(
          'tapping 保存 keeps the page alive with a processing overlay '
          'while processing, then pops with the edited bytes', (tester) async {
        final png = await tester.runAsync(createTestImage);
        Uint8List? popResult;
        await _pushEditor(
          tester,
          imageBytes: png!,
          onPopResult: (r) => popResult = r,
        );

        // Tap 保存 — the page must NOT close: it processes in place.
        await tester.tap(find.text('保存'));
        await tester.pump();

        // The editor page is still alive and shows a processing overlay.
        expect(find.byType(ExtendedImageEditorPage), findsOneWidget,
            reason: 'the editor must stay on screen while processing');
        expect(find.byType(CircularProgressIndicator), findsOneWidget,
            reason: 'a processing spinner must be visible');
        expect(find.text('正在处理图片，请稍候…'), findsOneWidget,
            reason: 'the processing overlay must show a status message');
        expect(popResult, isNull,
            reason: 'the page must not pop before processing finishes');

        // Only after the pipeline completes does the page pop with the
        // edited bytes.
        await pumpUntil(tester, () => popResult != null);
        expect(popResult, isNotNull);
        expect(popResult!.isNotEmpty, isTrue);
      });

      testWidgets('delivered bytes decode to a valid image', (tester) async {
        final png = await tester.runAsync(createTestImage);
        Uint8List? popResult;
        await _pushEditor(
          tester,
          imageBytes: png!,
          onPopResult: (r) => popResult = r,
        );

        await tester.tap(find.text('保存'));
        await tester.pump();
        await pumpUntil(tester, () => popResult != null);

        // The 8x8 input PNG should come back as a valid 8x8 image.
        final codec =
            await tester.runAsync(() => ui.instantiateImageCodec(popResult!));
        final frame = await tester.runAsync(() => codec!.getNextFrame());
        expect(frame!.image.width, 8);
        expect(frame.image.height, 8);
        frame.image.dispose();
        codec!.dispose();
      });

      testWidgets('closing with X does not run the pipeline', (tester) async {
        final png = await tester.runAsync(createTestImage);
        Uint8List? popResult;
        await _pushEditor(
          tester,
          imageBytes: png!,
          onPopResult: (r) => popResult = r,
        );

        // Close the editor without confirming — no processing should run.
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();

        // Closing must NOT flash the processing overlay — X runs no
        // pipeline, so no "正在处理图片" feedback may appear.
        expect(find.text('正在处理图片，请稍候…'), findsNothing,
            reason: 'the processing overlay must not flash on close');

        await tester.pumpAndSettle();

        expect(popResult, isNull);
        expect(find.byType(ExtendedImageEditorPage), findsNothing);
      });

      testWidgets(
          'invalid image data shows an error snackbar and the page '
          'stays on screen', (tester) async {
        // Invalid image data — the editor image never loads, so the
        // editor state is never created and confirming reports an error
        // without starting the pipeline.
        await _pushEditor(
          tester,
          imageBytes: Uint8List.fromList([1, 2, 3]),
          // The image never loads — do not wait for an editor state.
          waitForEditorReady: false,
        );

        await tester.tap(find.text('保存'));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.byType(ExtendedImageEditorPage), findsOneWidget,
            reason: 'a failed edit must not close the editor');
      });

      testWidgets('system back is blocked while the image processes',
          (tester) async {
        final png = await tester.runAsync(createTestImage);
        Uint8List? popResult;
        await _pushEditor(
          tester,
          imageBytes: png!,
          onPopResult: (r) => popResult = r,
        );

        await tester.tap(find.text('保存'));
        await tester.pump();

        // During processing a system back must not destroy the page.
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byType(ExtendedImageEditorPage), findsOneWidget,
            reason: 'system back must be blocked while processing');

        // After the pipeline finishes the page pops with the bytes.
        await pumpUntil(tester, () => popResult != null);
        await pumpUntil(
          tester,
          () => find.byType(ExtendedImageEditorPage).evaluate().isEmpty,
        );
      });

      testWidgets('close and 保存 are disabled while the image processes',
          (tester) async {
        final png = await tester.runAsync(createTestImage);
        await _pushEditor(tester, imageBytes: png!);

        await tester.tap(find.text('保存'));
        await tester.pump();

        // The close button must be blocked so the user cannot leave
        // mid-processing.
        final closeBtn = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.close),
        );
        expect(closeBtn.onPressed, isNull,
            reason: 'close must be disabled while processing');

        // 保存 is disabled too — the full-screen overlay shows the
        // spinner instead of the button.
        final saveBtn = tester.widget<TextButton>(
          find.widgetWithText(TextButton, '保存'),
        );
        expect(saveBtn.onPressed, isNull,
            reason: '保存 must be disabled while processing');
      });

      testWidgets(
          'double-tapping close cannot pop the page below the '
          'editor', (tester) async {
        final png = await tester.runAsync(createTestImage);
        Uint8List? popResult;
        await _pushEditor(
          tester,
          imageBytes: png!,
          onPopResult: (r) => popResult = r,
        );

        // Close the editor — the first tap starts the exit transition.
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();

        // A second tap during the exit transition must be a no-op — it
        // must never pop the host page below the exiting editor.
        await tester.tap(find.byIcon(Icons.close), warnIfMissed: false);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Open'), findsOneWidget,
            reason: 'the host page must survive a double close tap');
        expect(popResult, isNull);
      });
    });

    // ── 输出格式（回归：非 JPEG 源必须输出编码后的 PNG 而不是
    //    raw RGBA 像素；JPEG 源输出 JPEG q90 而非体积暴涨的 PNG）──
    // 直接调用顶层处理管线（与 widget 生命周期解耦），比走完整
    // 编辑器 UI 更稳定（不依赖编辑器状态就绪时序）。
    group('output format selection', () {
      testWidgets('PNG 源输出可解码的 PNG（不能是 raw RGBA 像素）', (tester) async {
        final png = await tester.runAsync(createTestImage);
        final bytes = await tester.runAsync(
          () => processQuickEditImage(
              rawData: png!, cropRect: null, action: null),
        );

        expect(img.decodeImage(bytes!), isNotNull,
            reason: 'PNG 源编辑结果必须是可解码的图片（不能是 raw RGBA）');
        expect(bytes[0], 0x89);
        expect(bytes[1], 0x50, reason: 'PNG 源应保持无损 PNG 输出');
      });

      testWidgets('JPEG 源输出可解码的 JPEG（修复 4MB→12MB 膨胀）', (tester) async {
        final bytes = await tester.runAsync(
          () => processQuickEditImage(
            rawData: _createSmallJpeg(),
            cropRect: null,
            action: null,
          ),
        );

        expect(img.decodeImage(bytes!), isNotNull,
            reason: 'JPEG 源编辑结果必须是可解码的图片');
        expect(bytes[0], 0xFF);
        expect(bytes[1], 0xD8, reason: 'JPEG 照片源应输出 JPEG（旧实现输出 PNG 导致体积暴涨）');
      });
    });
  });
}
