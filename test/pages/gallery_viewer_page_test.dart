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
