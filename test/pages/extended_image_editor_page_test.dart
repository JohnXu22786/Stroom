import 'dart:math' as math;
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

    // ── 裁剪/旋转几何（回归：裁剪后输出必须等于裁剪区域大小并充满
    //    整张画布，不能保留原图尺寸、把裁掉的部分留成透明/白色）──
    // 直接调用顶层处理管线并用像素级断言验证输出内容。
    group('crop geometry', () {
      /// 生成 8x6 的左右双色 PNG（左半红、右半绿），像素级断言用。
      Uint8List twoTonePng() {
        final im = img.Image(width: 8, height: 6);
        for (final p in im) {
          p
            ..r = p.x < 4 ? 255 : 0
            ..g = p.x >= 4 ? 255 : 0
            ..b = 0
            ..a = 255;
        }
        return img.encodePng(im);
      }

      /// 生成 8x6 纯色 PNG。
      Uint8List solidPng({
        int width = 8,
        int height = 8,
        int r = 0,
        int g = 0,
        int b = 255,
      }) {
        final im = img.Image(width: width, height: height);
        for (final p in im) {
          p
            ..r = r
            ..g = g
            ..b = b
            ..a = 255;
        }
        return img.encodePng(im);
      }

      /// 生成 8x6 四象限 PNG：左上红、右上绿、左下蓝、右下黄。
      Uint8List quadrantPng() {
        final im = img.Image(width: 8, height: 6);
        for (final p in im) {
          p.a = 255;
          if (p.x < 4 && p.y < 3) {
            p
              ..r = 255
              ..g = 0
              ..b = 0; // 左上红
          } else if (p.x >= 4 && p.y < 3) {
            p
              ..r = 0
              ..g = 255
              ..b = 0; // 右上绿
          } else if (p.x < 4) {
            p
              ..r = 0
              ..g = 0
              ..b = 255; // 左下蓝
          } else {
            p
              ..r = 255
              ..g = 255
              ..b = 0; // 右下黄
          }
        }
        return img.encodePng(im);
      }

      testWidgets('裁剪后输出尺寸等于裁剪区域（不能保留原图尺寸）', (tester) async {
        final bytes = await tester.runAsync(
          () => processQuickEditImage(
            rawData: twoTonePng(),
            cropRect: Rect.fromLTWH(4, 0, 4, 6), // 右半（绿）
            action: null,
          ),
        );
        final out = img.decodePng(bytes!);
        expect(out, isNotNull);
        expect(out!.width, 4, reason: '裁剪输出宽度必须等于裁剪区域宽度');
        expect(out.height, 6, reason: '裁剪输出高度必须等于裁剪区域高度');
        for (final p in out) {
          expect(p.r, 0, reason: '输出必须是裁剪区域内容（绿），不能混入被裁掉的部分');
          expect(p.g, 255);
          expect(p.a, 255);
        }
      });

      testWidgets('裁剪区域充满整张输出画布，无透明/白色空白', (tester) async {
        final bytes = await tester.runAsync(
          () => processQuickEditImage(
            rawData: solidPng(width: 8, height: 8, b: 255),
            cropRect: Rect.fromLTWH(0, 0, 8, 4), // 上半（宽高比与源不同）
            action: null,
          ),
        );
        final out = img.decodePng(bytes!);
        expect(out, isNotNull);
        expect(out!.width, 8);
        expect(out.height, 4);
        for (final p in out) {
          expect(p.a, 255, reason: '裁剪输出不能含透明像素（被裁掉的部分不应留白）');
        }
      });

      testWidgets('旋转 90° 后内容居中充满画布，不裁剪不出白条', (tester) async {
        final bytes = await tester.runAsync(
          () => processQuickEditImage(
            rawData: twoTonePng(),
            cropRect: null,
            action: EditActionDetails()..rotateRadians = math.pi / 2,
          ),
        );
        final out = img.decodePng(bytes!);
        expect(out, isNotNull);
        expect(out!.width, 6, reason: '旋转 90° 后宽高应互换');
        expect(out.height, 8);
        for (final p in out) {
          expect(p.a, 255, reason: '旋转输出不能含透明/被裁剪掉的内容');
        }
      });

      testWidgets('裁剪 + 旋转 90°：裁剪框按旋转后坐标解释（与编辑器 getCropRect 一致）',
          (tester) async {
        // 8x6 右旋 90° 后框架是 6x8（顺时针：原图左上 → 框架右上）；
        // 旋转后裁剪框 (0,4,3,4) 对应原图右下象限（黄），输出 3x4。
        final bytes = await tester.runAsync(
          () => processQuickEditImage(
            rawData: quadrantPng(),
            cropRect: Rect.fromLTWH(0, 4, 3, 4),
            action: EditActionDetails()..rotateRadians = math.pi / 2,
          ),
        );
        final out = img.decodePng(bytes!);
        expect(out, isNotNull);
        expect(out!.width, 3, reason: '输出宽度 = 旋转后裁剪框宽度');
        expect(out.height, 4, reason: '输出高度 = 旋转后裁剪框高度');
        for (final p in out) {
          expect(p.a, 255, reason: '裁剪输出不能含透明像素');
          expect(p.r, 255, reason: '90° 反旋转应映射到原图右下象限（黄），不能取左上');
          expect(p.g, 255);
          expect(p.b, 0);
        }
      });

      testWidgets('裁剪 + 旋转 270°：反旋转方向与 90° 相反', (tester) async {
        // 同一裁剪框 (0,4,3,4) 在 270° 框架里对应原图左上象限（红）。
        final bytes = await tester.runAsync(
          () => processQuickEditImage(
            rawData: quadrantPng(),
            cropRect: Rect.fromLTWH(0, 4, 3, 4),
            action: EditActionDetails()..rotateRadians = -math.pi / 2,
          ),
        );
        final out = img.decodePng(bytes!);
        expect(out, isNotNull);
        expect(out!.width, 3);
        expect(out.height, 4);
        for (final p in out) {
          expect(p.a, 255);
          expect(p.r, 255, reason: '270° 反旋转应映射到原图左上象限（红），不能和 90° 一样取右下');
          expect(p.g, 0);
          expect(p.b, 0);
        }
      });

      testWidgets('完整流程：编辑器里右旋 90° 后点完成，输出旋转后尺寸且无白条', (tester) async {
        // 走真实编辑器（ExtendedImage editor）→ getCropRect() → 管线，
        // 验证生产路径旋转输出：尺寸为旋转后的竖版、全不透明无白条，
        // 且内容方向与编辑器预览一致（顺时针：左上蓝、右上红、
        // 左下黄、右下绿）。
        final png = quadrantPng();
        Uint8List? popResult;
        await _pushEditor(
          tester,
          imageBytes: png,
          onPopResult: (r) => popResult = r,
        );

        await tester.tap(find.text('右旋'));
        await tester.pump();
        await tester.tap(find.text('完成'));
        await tester.pump();
        await pumpUntil(tester, () => popResult != null);

        // 右旋触发了编辑器内部 400ms 的防抖保存定时器；推进虚拟时钟
        // 让它在测试结束前触发（回调只碰普通字段，安全）。
        await tester.pump(const Duration(milliseconds: 500));

        final out = img.decodePng(popResult!);
        expect(out, isNotNull);
        expect(out!.width, 6, reason: '右旋 90° 后输出应为竖版（宽 = 原图高）');
        expect(out.height, 8, reason: '右旋 90° 后输出高度 = 原图宽');
        for (final p in out) {
          expect(p.a, 255, reason: '旋转输出不能含透明/白色条（裁剪框外区域不应残留）');
        }
        // 内容方向必须与编辑器预览一致（顺时针旋转）：
        // 左上=蓝（原左下）、右上=红（原左上）、左下=黄（原右下）、
        // 右下=绿（原右上）。
        final tl = out.getPixel(1, 1);
        expect(tl.r.toInt(), 0);
        expect(tl.g.toInt(), 0);
        expect(tl.b.toInt(), 255, reason: '输出左上应为蓝色（原图左下象限顺时针转到左上）');
        final tr = out.getPixel(4, 1);
        expect(tr.r.toInt(), 255);
        expect(tr.g.toInt(), 0, reason: '输出右上应为红色（原图左上象限）');
        final bl = out.getPixel(1, 6);
        expect(bl.r.toInt(), 255);
        expect(bl.g.toInt(), 255, reason: '输出左下应为黄色（原图右下象限）');
        final br = out.getPixel(4, 6);
        expect(br.r.toInt(), 0);
        expect(br.g.toInt(), 255, reason: '输出右下应为绿色（原图右上象限）');
      });
      testWidgets('裁剪 + 旋转 180°：反旋转与方向无关', (tester) async {
        // 180° 框架与原图同尺寸；裁剪框 (0,0,4,6)（旋转后坐标，左半）
        // 对应原图右半（绿），输出 4x6。
        final bytes = await tester.runAsync(
          () => processQuickEditImage(
            rawData: twoTonePng(),
            cropRect: Rect.fromLTWH(0, 0, 4, 6),
            action: EditActionDetails()..rotateRadians = math.pi,
          ),
        );
        final out = img.decodePng(bytes!);
        expect(out, isNotNull);
        expect(out!.width, 4);
        expect(out.height, 6);
        for (final p in out) {
          expect(p.a, 255);
          expect(p.r, 0, reason: '180° 反旋转应映射到原图右半（绿）');
          expect(p.g, 255);
        }
      });

      testWidgets('翻转 + 裁剪：裁剪框在镜像后的显示坐标系里', (tester) async {
        // 翻转后显示框架 = 原图水平镜像：显示右上区域 (4,0,4,3) 显示的是
        // 原图左上（红）；输出 = 裁剪框尺寸 4x3 全红。
        final bytes = await tester.runAsync(
          () => processQuickEditImage(
            rawData: quadrantPng(),
            cropRect: Rect.fromLTWH(4, 0, 4, 3),
            action: EditActionDetails()..rotationYRadians = math.pi,
          ),
        );
        final out = img.decodePng(bytes!);
        expect(out, isNotNull);
        expect(out!.width, 4);
        expect(out.height, 3);
        for (final p in out) {
          expect(p.a, 255);
          expect(p.r, 255, reason: '翻转后的显示右上应取原图左上（红），不能直接按原图坐标采样');
          expect(p.g, 0);
          expect(p.b, 0);
        }
      });

      testWidgets('翻转 + 右旋 + 裁剪：镜像后再反旋转（270° 分支）', (tester) async {
        // 翻转后右旋：编辑器 rotateRadians = -90°（reverseRotateRadians）。
        // 显示坐标 (3,0,3,4) 对应原图右上象限（绿）。
        final bytes = await tester.runAsync(
          () => processQuickEditImage(
            rawData: quadrantPng(),
            cropRect: Rect.fromLTWH(3, 0, 3, 4),
            action: EditActionDetails()
              ..rotationYRadians = math.pi
              ..rotateRadians = -math.pi / 2,
          ),
        );
        final out = img.decodePng(bytes!);
        expect(out, isNotNull);
        expect(out!.width, 3);
        expect(out.height, 4);
        for (final p in out) {
          expect(p.a, 255);
          expect(p.r, 0, reason: '翻转+右旋应取原图右上象限（绿），不能取到左下');
          expect(p.g, 255);
          expect(p.b, 0);
        }
      });

      testWidgets('翻转 + 左旋 + 裁剪：镜像后再反旋转（90° 分支）', (tester) async {
        // 翻转后左旋：编辑器 rotateRadians = +90°。同一显示坐标 (3,0,3,4)
        // 对应原图左下象限（蓝），与右旋相反。
        final bytes = await tester.runAsync(
          () => processQuickEditImage(
            rawData: quadrantPng(),
            cropRect: Rect.fromLTWH(3, 0, 3, 4),
            action: EditActionDetails()
              ..rotationYRadians = math.pi
              ..rotateRadians = math.pi / 2,
          ),
        );
        final out = img.decodePng(bytes!);
        expect(out, isNotNull);
        expect(out!.width, 3);
        expect(out.height, 4);
        for (final p in out) {
          expect(p.a, 255);
          expect(p.r, 0, reason: '翻转+左旋应取原图左下象限（蓝），与右旋方向相反');
          expect(p.g, 0);
          expect(p.b, 255);
        }
      });
    });
  });
}
