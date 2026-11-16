// ignore_for_file: invalid_use_of_visible_for_testing_member

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
