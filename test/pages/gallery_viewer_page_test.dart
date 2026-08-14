import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/gallery_viewer_page.dart';
import 'package:stroom/pages/image_editor_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/image_manifest.dart';
import 'package:stroom/utils/image_thumbnail_loader.dart';

/// Helper: create an in-memory [ImageRecord] for testing.
ImageRecord _makeRecord({
  String id = 'test_id',
  String name = 'test',
  String hash = 'abc123',
  String format = 'jpg',
  int size = 100,
}) {
  return ImageRecord(
    id: id,
    name: name,
    hash: hash,
    format: format,
    createdAt: DateTime(2024, 1, 1),
    size: size,
    folder: '/test',
  );
}

/// Creates a small valid PNG (8x8 green) via the real engine.
Future<Uint8List> _createEnginePng() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, 8, 8),
    ui.Paint()..color = const ui.Color(0xFF00FF00),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(8, 8);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    ImageManifest.invalidateCache();
    ImageThumbnailLoader.clear();
  });

  group('GalleryViewerPage - loading with real image files', () {
    testWidgets(
        'renders pages from disk and preloads/swipes to the next '
        'page without crashing', (tester) async {
      // 预加载/字节缓存/占位符路径需要真实的文件存在（无文件时只会
      // 走到错误占位，覆盖不到新逻辑）
      final png = await tester.runAsync(_createEnginePng);
      final pngBytes = png!;
      await tester.runAsync(() async {
        await ImageManifest.writeFile('img_a.png', pngBytes);
        await ImageManifest.writeFile('img_b.png', pngBytes);
      });
      final recordA = _makeRecord(
        id: 'id_a',
        name: 'first',
        hash: 'img_a',
        format: 'png',
      );
      final recordB = _makeRecord(
        id: 'id_b',
        name: 'second',
        hash: 'img_b',
        format: 'png',
      );

      await tester.pumpWidget(MaterialApp(
        home: GalleryViewerPage(
          images: [recordA, recordB],
          initialIndex: 0,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('first.png'), findsOneWidget);

      // 滑动到下一页 —— 预加载应已把字节读入缓存，页面正常显示
      await tester.drag(
        find.byType(ExtendedImageGesturePageView),
        const Offset(-500, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('second.png'), findsOneWidget);
    });

    testWidgets(
        'shows the cached thumbnail immediately while the full image '
        'is still loading', (tester) async {
      final png = await tester.runAsync(_createEnginePng);
      final record = _makeRecord(
        id: 'id_thumb_first',
        name: 'thumb_first',
        hash: 'thumb_first_hash',
        format: 'png',
      );
      await tester.runAsync(() async {
        await ImageManifest.writeFile(record.storagePath, png!);
        // 直接写缩略图文件，再通过 loadThumbnail 读入内存缓存 —— 不经过
        // 引擎解码生成，避免测试环境下的引擎工作引入不稳定的失败
        await ImageManifest.writeFile('${record.hash}_thumb.png', png);
      });
      // 从磁盘读入内存缓存（模拟网格页已经加载过该图）。
      // 全图字节此时尚未进入查看器的字节缓存，进入查看器会先走加载占位。
      final thumb = await ImageThumbnailLoader.loadThumbnail(record);
      expect(thumb, isNotNull);

      await tester.pumpWidget(MaterialApp(
        home: GalleryViewerPage(images: [record], initialIndex: 0),
      ));

      // 全图字节尚未读到：立即显示已缓存的缩略图（像聊天页一样点开就能
      // 看到图像内容），而不是干等一个转圈动画。
      final thumbFinder = find.byWidgetPredicate(
        (w) => w is Image && w.image is MemoryImage,
      );
      expect(thumbFinder, findsOneWidget,
          reason: '加载期间必须先显示已缓存的缩略图占位');
      // 占位缩略图必须撑满全屏（letterbox 与原图同框）—— 若按 256px
      // 原始尺寸缩在屏幕中间，切换原图时会出现明显的尺寸跳变
      expect(tester.getSize(thumbFinder), tester.getSize(find.byType(
        GalleryViewerPage,
      )));
      // 缩略图只是占位：叠加小加载指示，明确原图仍在加载/解码
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 字节已读到、全分辨率解码中（ExtendedImage loadStateChanged 分支）：
      // 仍显示缩略图占位，解码完成后才替换为原图。解码是引擎工作，在
      // FakeAsync 下不会完成，ExtendedImage 会停留在 loading 状态。
      await tester.pump();
      expect(
        find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage),
        findsOneWidget,
        reason: '解码期间不得退回纯转圈动画',
      );
      expect(find.text('1 / 1'), findsOneWidget);
    });

    testWidgets(
        'falls back to the loading spinner when no thumbnail is cached',
        (tester) async {
      final png = await tester.runAsync(_createEnginePng);
      final record = _makeRecord(
        id: 'id_spinner',
        name: 'spinner',
        hash: 'spinner_hash',
        format: 'png',
      );
      await tester.runAsync(() async {
        await ImageManifest.writeFile(record.storagePath, png!);
      });
      // 不写缩略图文件、也不加载缩略图：peek 必然未命中 → 退回转圈动画

      await tester.pumpWidget(MaterialApp(
        home: GalleryViewerPage(images: [record], initialIndex: 0),
      ));

      // 全图未加载且无缩略图可显示：显示转圈动画
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage),
        findsNothing,
        reason: '无缩略图时不得出现图像占位',
      );

      // 字节已读到、解码中：依然只有转圈动画
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);
    });
  });

  group('showImageSaveDialog', () {
    testWidgets('dialog shows correct options for quick edit save', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => showImageSaveDialog(context),
            child: const Text('保存'),
          );
        }),
      ));

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Verify same dialog is used for quick edit
      expect(find.text('保存图片'), findsOneWidget);
      expect(find.text('覆盖'), findsOneWidget);
      expect(find.text('另存为'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
    });

    testWidgets('overwrite returns SaveAction.overwrite', (tester) async {
      SaveAction? result;

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              result = await showImageSaveDialog(context);
            },
            child: const Text('保存'),
          );
        }),
      ));

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('覆盖'));
      await tester.pumpAndSettle();

      expect(result, SaveAction.overwrite);
    });

    testWidgets('save-as returns SaveAction.saveAs', (tester) async {
      SaveAction? result;

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              result = await showImageSaveDialog(context);
            },
            child: const Text('保存'),
          );
        }),
      ));

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('另存为'));
      await tester.pumpAndSettle();

      expect(result, SaveAction.saveAs);
    });

    testWidgets('cancel returns SaveAction.cancel', (tester) async {
      SaveAction? result;

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              result = await showImageSaveDialog(context);
            },
            child: const Text('保存'),
          );
        }),
      ));

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(result, SaveAction.cancel);
    });
  });
}
