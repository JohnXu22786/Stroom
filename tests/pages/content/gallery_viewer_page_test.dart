import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/gallery_viewer_page.dart';
import 'package:stroom/pages/image_editor_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/file_picker_utils.dart';
import 'package:stroom/utils/image_manifest.dart';
import 'package:stroom/utils/image_thumbnail_loader.dart';

/// Helper: create an in-memory [ImageRecord] for testing.
ImageRecord _makeRecord({
  String id = 'test_id',
  String name = 'test',
  String hash = 'abc123',
  String format = 'jpg',
  int size = 100,
  String folder = '/test',
}) {
  return ImageRecord(
    id: id,
    name: name,
    hash: hash,
    format: format,
    createdAt: DateTime(2024, 1, 1),
    size: size,
    folder: folder,
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

Widget _localizedMaterialApp({required Widget home}) => MaterialApp(
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    ImageManifest.invalidateCache();
    ImageThumbnailLoader.clear();
  });

  group('uniqueGallerySaveAsName', () {
    test(
      'concurrent copies get distinct paths accepted by gallery export',
      () async {
        final original = _makeRecord(name: 'trip', format: 'png', folder: '');
        final records = [original];

        Future<String> saveAsCopy(String id) =>
            withGalleryVisibleNameLock(original.folder, () async {
              final name = uniqueGallerySaveAsName(
                records: records,
                folder: original.folder,
                sourceName: original.name,
                format: original.format,
              );
              await Future<void>.delayed(Duration.zero);
              records.add(
                _makeRecord(
                  id: id,
                  name: name,
                  format: original.format,
                  folder: original.folder,
                ),
              );
              return name;
            });

        final names = await Future.wait([
          saveAsCopy('copy_1'),
          saveAsCopy('copy_2'),
        ]);

        expect(names.toSet(), {'trip_edited', 'trip_edited (2)'});
        expect(
          () => validateUserVisibleExportPaths(
            files: [
              for (final record in records)
                record.folder.isEmpty
                    ? '${record.name}.${record.format}'
                    : '${record.folder}/${record.name}.${record.format}',
            ],
          ),
          returnsNormally,
        );

        final caseVariantRecords = [
          _makeRecord(
            id: 'upper',
            name: 'trip',
            format: 'png',
            folder: 'Photos',
          ),
          _makeRecord(
            id: 'lower',
            name: 'trip',
            format: 'png',
            folder: 'photos',
          ),
        ];
        final caseVariantNames = await Future.wait([
          for (final record in caseVariantRecords)
            withGalleryVisibleNameLock(record.folder, () async {
              final name = uniqueGallerySaveAsName(
                records: caseVariantRecords,
                folder: record.folder,
                sourceName: record.name,
                format: record.format,
              );
              await Future<void>.delayed(Duration.zero);
              caseVariantRecords.add(record.copyWith(name: name));
              return name;
            }),
        ]);
        expect(caseVariantNames.toSet(), {'trip_edited', 'trip_edited (2)'});

        final importAndSaveRecords = [original];
        Future<String> saveAsName() => withGalleryVisibleNameLock('', () async {
              final name = uniqueGallerySaveAsName(
                records: importAndSaveRecords,
                folder: '',
                sourceName: 'trip',
                format: 'png',
              );
              await Future<void>.delayed(Duration.zero);
              importAndSaveRecords.add(
                _makeRecord(
                    id: 'save_as', name: name, format: 'png', folder: ''),
              );
              return name;
            });
        Future<String> importName() => withGalleryVisibleNameLock('', () async {
              final name = uniqueGalleryVisibleName(
                records: importAndSaveRecords,
                folder: '',
                baseName: 'trip_edited',
                format: 'png',
              );
              await Future<void>.delayed(Duration.zero);
              importAndSaveRecords.add(
                _makeRecord(
                    id: 'import', name: name, format: 'png', folder: ''),
              );
              return name;
            });
        final importAndSaveNames = await Future.wait([
          saveAsName(),
          importName(),
        ]);
        expect(importAndSaveNames.toSet(), {'trip_edited', 'trip_edited (2)'});
        expect(
          uniqueGalleryVisibleName(
            records: [],
            folder: 'test',
            baseName: 'trip',
            format: 'jpg',
            reservedFileNames: ['trip.png'],
          ),
          'trip',
        );
      },
    );

    test(
      'keeps the first suffix free across unrelated names and extensions',
      () {
        final original = _makeRecord(
          name: 'trip',
          format: 'PNG',
          folder: 'test',
        );
        final records = [
          original,
          _makeRecord(
            id: 'other_extension',
            name: 'trip_edited',
            format: 'jpg',
            folder: original.folder,
          ),
          _makeRecord(
            id: 'other_name',
            name: 'other',
            format: 'PNG',
            folder: original.folder,
          ),
          _makeRecord(
            id: 'other_folder',
            name: 'trip_edited',
            format: 'PNG',
            folder: 'elsewhere',
          ),
        ];

        expect(
          uniqueGallerySaveAsName(
            records: records,
            folder: original.folder,
            sourceName: original.name,
            format: original.format,
          ),
          'trip_edited',
        );
        expect(
          uniqueGallerySaveAsName(
            records: records,
            folder: original.folder,
            sourceName: original.name,
            format: original.format,
            existingFolders: ['${original.folder}/trip_edited.PNG'],
          ),
          'trip_edited (2)',
        );
        expect(
          uniqueGallerySaveAsName(
            records: [_makeRecord(name: 'trip', format: 'png', folder: '')],
            folder: '',
            sourceName: 'trip',
            format: 'png',
            existingFolders: ['trip_edited.png'],
          ),
          'trip_edited (2)',
        );
      },
    );

    test('root folder creation shares the file name reservation lock',
        () async {
      Future<String> saveRootFile() => withGalleryVisibleNameLock('', () async {
            final records = await ImageManifest.loadRecordsStrict();
            final folders = await ImageManifest.getAllFolders();
            final name = uniqueGalleryVisibleName(
              records: records,
              folder: '',
              baseName: 'photo',
              format: 'png',
              existingFolders: folders,
            );
            await Future<void>.delayed(Duration.zero);
            await ImageManifest.addRecord(
              _makeRecord(
                id: 'root_file',
                name: name,
                format: 'png',
                folder: '',
              ),
            );
            return name;
          });

      Future<bool> createRootFolder() => createGalleryFolderIfNameAvailable(
            'photo.png',
            () => ImageManifest.addFolder('photo.png'),
          );

      final outcomes = await Future.wait<Object>([
        saveRootFile(),
        createRootFolder(),
      ]);
      final savedName = outcomes[0] as String;
      final folderCreated = outcomes[1] as bool;
      final records = await ImageManifest.loadRecordsStrict();
      final folders = await ImageManifest.getAllFolders();

      expect(savedName, folderCreated ? 'photo (2)' : 'photo');
      expect(
        () => validateUserVisibleExportPaths(
          files: [
            for (final record in records) '${record.name}.${record.format}'
          ],
          folders: folders,
        ),
        returnsNormally,
      );
    });
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

      await tester.pumpWidget(
        _localizedMaterialApp(
          home: GalleryViewerPage(images: [recordA, recordB], initialIndex: 0),
        ),
      );
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
        'shows a loading spinner, not the cached thumbnail, while the '
        'full image is still loading', (tester) async {
      final png = await tester.runAsync(_createEnginePng);
      final record = _makeRecord(
        id: 'id_spinner',
        name: 'spinner',
        hash: 'spinner_hash',
        format: 'png',
      );
      await tester.runAsync(() async {
        await ImageManifest.writeFile(record.storagePath, png!);
        // 直接写缩略图文件，再通过 loadThumbnail 读入内存缓存 —— 不经过
        // 引擎解码生成，避免测试环境下的引擎工作引入不稳定的失败
        await ImageManifest.writeFile(imageThumbFileName(record.hash), png);
      });
      // 从磁盘读入内存缓存（模拟网格页已经加载过该图）。
      // 全图字节此时尚未进入查看器的字节缓存，进入查看器会先走加载占位。
      final thumb = await ImageThumbnailLoader.loadThumbnail(record);
      expect(thumb, isNotNull);

      await tester.pumpWidget(
        _localizedMaterialApp(
          home: GalleryViewerPage(images: [record], initialIndex: 0),
        ),
      );

      // 全图尚未加载完成：必须显示转圈动画，而不是缩略图占位。
      // （缩略图占位是 Image.memory —— 回归此行为就等于把
      // "先显示缩略图"的问题改回来。）
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage),
        findsNothing,
        reason: '加载期间不得显示缩略图占位',
      );

      // 字节已读到、全分辨率解码中（ExtendedImage loadStateChanged 分支）：
      // 同样必须显示转圈动画，而不是缩略图占位。解码是引擎工作，在
      // FakeAsync 下不会完成，ExtendedImage 会停留在 loading 状态。
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage),
        findsNothing,
        reason: '解码期间不得显示缩略图占位',
      );
      expect(find.text('1 / 1'), findsOneWidget);
    });
  });

  group('showImageSaveDialog', () {
    testWidgets('dialog shows correct options for quick edit save', (
      tester,
    ) async {
      await tester.pumpWidget(
        _localizedMaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showImageSaveDialog(context),
                child: const Text('保存'),
              );
            },
          ),
        ),
      );

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

      await tester.pumpWidget(
        _localizedMaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showImageSaveDialog(context);
                },
                child: const Text('保存'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('覆盖'));
      await tester.pumpAndSettle();

      expect(result, SaveAction.overwrite);
    });

    testWidgets('save-as returns SaveAction.saveAs', (tester) async {
      SaveAction? result;

      await tester.pumpWidget(
        _localizedMaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showImageSaveDialog(context);
                },
                child: const Text('保存'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('另存为'));
      await tester.pumpAndSettle();

      expect(result, SaveAction.saveAs);
    });

    testWidgets('cancel returns SaveAction.cancel', (tester) async {
      SaveAction? result;

      await tester.pumpWidget(
        _localizedMaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showImageSaveDialog(context);
                },
                child: const Text('保存'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(result, SaveAction.cancel);
    });
  });
}
