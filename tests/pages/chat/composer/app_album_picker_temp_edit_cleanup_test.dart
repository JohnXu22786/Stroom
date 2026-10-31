import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/chat/composer/album_picker_shared.dart';
import 'package:stroom/pages/chat/composer/chat_album_picker_dialog.dart';
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
  final stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed > const Duration(seconds: 10)) {
      fail('Timed out waiting for condition');
    }
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
    appAlbumPickerEditImageForTesting = null;
    tempDir = await Directory.systemTemp.createTemp('album_picker_temp_edit_');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPathProvider(tempDir.path);
  });

  tearDown(() async {
    beforeAppAlbumPickerTempWriteForTesting = null;
    appAlbumPickerEditImageForTesting = null;
    PathProviderPlatform.instance = originalPathProvider;
    ImageManifest.invalidateCache();
    await tempDir.delete(recursive: true);
  });

  Future<Uint8List> openPickerWithSelectedImage(WidgetTester tester) async {
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
    final originalBytes =
        tester.widget<AlbumPreviewChip>(find.byType(AlbumPreviewChip)).bytes;
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
      appAlbumPickerEditImageForTesting =
          (_, _) async => Uint8List.fromList([10, 20, 30]);

      await openPickerWithSelectedImage(tester);
      await tester.tap(find.byType(AlbumPreviewChip));
      await tester.pump();
      await _pumpUntil(tester, () => writeStarted.isCompleted);
      final tempFile = await writeStarted.future;
      expect(await tester.runAsync(tempFile.exists), isFalse);

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(AppBar, '应用内相册'),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('应用内相册'), findsNothing);

      finishWrite.complete();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(await tester.runAsync(tempFile.exists), isFalse);
    },
  );

  testWidgets(
    'a failed temp write removes a partial file and keeps edited bytes in memory',
    (tester) async {
      beforeAppAlbumPickerTempWriteForTesting = (file, bytes) async {
        await file.writeAsBytes(bytes.sublist(0, 1));
        throw const FileSystemException('simulated temp write failure');
      };
      appAlbumPickerEditImageForTesting =
          (_, _) async => Uint8List.fromList([10, 20, 30]);

      final originalBytes = await openPickerWithSelectedImage(tester);
      await tester.tap(find.byType(AlbumPreviewChip));
      await tester.pump();
      await _pumpUntil(
        tester,
        () =>
            tester
                .widget<AlbumPreviewChip>(find.byType(AlbumPreviewChip))
                .bytes !=
            originalBytes,
      );
      final editedFiles = await tester.runAsync(
        () => tempDir
            .list()
            .where((file) => file.path.split('/').last.startsWith('edited_'))
            .toList(),
      );
      expect(editedFiles, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'concurrent edits of the same image use separate temp files',
    (tester) async {
      final files = <File>[];
      final writeGates = <Completer<void>>[];
      final writesFinished = <Future<void>>[];
      beforeAppAlbumPickerTempWriteForTesting = (file, bytes) async {
        files.add(file);
        final gate = Completer<void>();
        final finished = Completer<void>();
        writeGates.add(gate);
        writesFinished.add(finished.future);
        try {
          await gate.future;
          await file.writeAsBytes(bytes);
        } finally {
          finished.complete();
        }
      };
      appAlbumPickerEditImageForTesting =
          (_, _) async => Uint8List.fromList([10, 20, 30]);

      await openPickerWithSelectedImage(tester);
      await tester.tap(find.byType(AlbumPreviewChip));
      await tester.pump();
      await tester.tap(find.byType(AlbumPreviewChip));
      await tester.pump();
      await _pumpUntil(tester, () => files.length == 2);
      expect(files.map((file) => file.path).toSet(), hasLength(2));

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(AppBar, '应用内相册'),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();
      for (final gate in writeGates) {
        gate.complete();
      }
      await tester.runAsync(() => Future.wait(writesFinished));
      await tester.pump();
      expect(files.map((file) => file.existsSync()), everyElement(isFalse));
    },
  );
}
