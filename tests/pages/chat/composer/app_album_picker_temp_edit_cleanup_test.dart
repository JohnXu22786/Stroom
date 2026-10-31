import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/chat/composer/album_picker_shared.dart';
import 'package:stroom/pages/chat/composer/chat_album_picker_dialog.dart';
import 'package:stroom/pages/extended_image_editor_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/image_manifest.dart';

class _TestPathProvider extends PathProviderPlatform {
  _TestPathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

Future<Uint8List> _createEnginePng() async {
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

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  final end = DateTime.now().add(const Duration(seconds: 10));
  while (!condition()) {
    if (DateTime.now().isAfter(end)) fail('Timed out waiting for condition');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform originalPathProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    ImageManifest.invalidateCache();
    beforeAppAlbumPickerTempWriteForTesting = null;
    tempDir = await Directory.systemTemp.createTemp('album_picker_temp_edit_');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPathProvider(tempDir.path);
  });

  tearDown(() async {
    beforeAppAlbumPickerTempWriteForTesting = null;
    PathProviderPlatform.instance = originalPathProvider;
    ImageManifest.invalidateCache();
    await tempDir.delete(recursive: true);
  });

  Future<Uint8List> openEditorForSeededImage(WidgetTester tester) async {
    final png = await tester.runAsync(_createEnginePng);
    await tester.runAsync(() async {
      await ImageManifest.writeFile('temp-edit-hash.png', png!);
      await ImageManifest.addRecord(
        ImageRecord(
          name: 'temp-edit-image',
          hash: 'temp-edit-hash',
          format: 'png',
          createdAt: DateTime.now(),
          size: png.length,
          folder: '',
        ),
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAppAlbumPickerDialog(context),
              child: const Text('Open Album'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Album'));
    await tester.pump();
    await _pumpUntil(
      tester,
      () => find.text('temp-edit-image.png').evaluate().isNotEmpty,
    );
    await tester.tap(find.text('temp-edit-image.png'));
    await tester.pump();
    await _pumpUntil(
      tester,
      () => find.byType(AlbumPreviewChip).evaluate().isNotEmpty,
    );
    final originalBytes = tester
        .widget<AlbumPreviewChip>(find.byType(AlbumPreviewChip))
        .bytes;

    await tester.tap(find.byType(AlbumPreviewChip));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.crop));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _pumpUntil(
      tester,
      () => find.byType(ExtendedImageEditor).evaluate().isNotEmpty,
    );
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _pumpUntil(
      tester,
      () => find.byType(ExtendedImageEditorPage).evaluate().isEmpty,
    );
    return originalBytes;
  }

  testWidgets(
    'closing during a temp write deletes the file after the write finishes',
    (tester) async {
      final writeStarted = Completer<File>();
      final finishWrite = Completer<void>();
      beforeAppAlbumPickerTempWriteForTesting = (file, bytes) async {
        writeStarted.complete(file);
        await finishWrite.future;
        await file.writeAsBytes(bytes);
      };

      await openEditorForSeededImage(tester);
      await _pumpUntil(tester, () => writeStarted.isCompleted);
      final tempFile = await writeStarted.future;
      expect(await tempFile.exists(), isFalse);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('应用内相册'), findsNothing);

      finishWrite.complete();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(await tempFile.exists(), isFalse);
    },
  );

  testWidgets(
    'a failed temp write removes a partial file and keeps edited bytes in memory',
    (tester) async {
      beforeAppAlbumPickerTempWriteForTesting = (file, bytes) async {
        await file.writeAsBytes(bytes.sublist(0, 1));
        throw const FileSystemException('simulated temp write failure');
      };

      final originalBytes = await openEditorForSeededImage(tester);
      await _pumpUntil(
        tester,
        () =>
            tester
                .widget<AlbumPreviewChip>(find.byType(AlbumPreviewChip))
                .bytes !=
            originalBytes,
      );
      final editedFiles = await tempDir
          .list()
          .where((file) => file.path.split('/').last.startsWith('edited_'))
          .toList();
      expect(editedFiles, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
