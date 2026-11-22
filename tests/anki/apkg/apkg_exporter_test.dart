import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:stroom/anki/apkg/apkg_exporter.dart';
import 'package:stroom/anki/apkg/apkg_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reports a missing collection database with its path', () async {
    final documents = await Directory.systemTemp.createTemp(
      'stroom_anki_apkg_export_test_',
    );
    final previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _DocumentsPathProvider(documents.path);
    final missingPath = '${documents.path}/missing-collection.anki2';

    try {
      await expectLater(
        AnkiApkgExporter.export(dbPath: missingPath),
        throwsA(
          isA<AnkiApkgException>()
              .having((error) => error.code, 'code',
                  AnkiApkgErrorCode.targetDatabaseMissing)
              .having((error) => error.path, 'path', missingPath),
        ),
      );
    } finally {
      PathProviderPlatform.instance = previous;
      await documents.delete(recursive: true);
    }
  });
}

class _DocumentsPathProvider extends PathProviderPlatform {
  _DocumentsPathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}
