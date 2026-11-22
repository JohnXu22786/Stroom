// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:stroom/anki/apkg/apkg_exporter.dart';
import 'package:stroom/anki/apkg/apkg_result.dart';

class _Documents extends PathProviderPlatform {
  _Documents(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'same-timestamp exports reserve distinct paths without replacing earlier bytes',
    () async {
      final directory = await Directory.systemTemp.createTemp('apkg_export_');
      final originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Documents(directory.path);
      addTearDown(() async {
        PathProviderPlatform.instance = originalPathProvider;
        await directory.delete(recursive: true);
      });

      final firstDatabase = File('${directory.path}/first.anki2');
      final secondDatabase = File('${directory.path}/second.anki2');
      await firstDatabase.writeAsBytes([1, 2, 3]);
      await secondDatabase.writeAsBytes([4, 5, 6]);
      final fixedTimestamp = DateTime.utc(2025, 1, 2, 3, 4, 5);
      final firstWriterStarted = Completer<void>();
      final releaseFirstWriter = Completer<void>();

      final firstExport = AnkiApkgExporter.export(
        dbPath: firstDatabase.path,
        clock: () => fixedTimestamp,
        writeBytes: (file, bytes) async {
          firstWriterStarted.complete();
          await releaseFirstWriter.future;
          await file.writeAsBytes(bytes);
        },
      );
      await firstWriterStarted.future;

      final firstExpectedPath =
          '${directory.path}/stroom_anki_2025-01-02T03-04-05-000Z.apkg';
      expect(await File(firstExpectedPath).exists(), isFalse);

      final secondPath = await AnkiApkgExporter.export(
        dbPath: secondDatabase.path,
        clock: () => fixedTimestamp,
      );
      final secondBytes = await File(secondPath).readAsBytes();
      releaseFirstWriter.complete();
      final firstPath = await firstExport;

      expect(firstPath, endsWith('stroom_anki_2025-01-02T03-04-05-000Z.apkg'));
      expect(
          secondPath, endsWith('stroom_anki_2025-01-02T03-04-05-000Z_1.apkg'));
      expect(firstPath, isNot(secondPath));
      expect(await File(firstPath).readAsBytes(), isNot(secondBytes));
      expect(await File(secondPath).readAsBytes(), secondBytes);
    },
  );

  test(
    'failed archive write does not leave a partial APKG at the final path',
    () async {
      final directory = await Directory.systemTemp.createTemp('apkg_export_');
      final originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Documents(directory.path);
      addTearDown(() async {
        PathProviderPlatform.instance = originalPathProvider;
        await directory.delete(recursive: true);
      });

      final database = File('${directory.path}/collection.anki2');
      await database.writeAsBytes([1, 2, 3]);
      File? attemptedWrite;

      await expectLater(
        AnkiApkgExporter.export(
          dbPath: database.path,
          writeBytes: (file, _) async {
            attemptedWrite = file;
            await file.writeAsBytes([1, 2]);
            throw const FileSystemException('simulated disk failure');
          },
        ),
        throwsA(isA<AnkiApkgException>()),
      );

      expect(attemptedWrite, isNotNull);
      expect(attemptedWrite!.path.endsWith('.apkg'), isFalse);
      expect(await attemptedWrite!.exists(), isFalse);
      expect(
        directory.listSync().whereType<File>().where(
              (file) => file.path.endsWith('.apkg'),
            ),
        isEmpty,
      );
    },
  );
}
