import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/anki/apkg/apkg_importer.dart';
import 'package:stroom/anki/apkg/apkg_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reports a missing package with its path', () async {
    final directory = await Directory.systemTemp.createTemp(
      'stroom_anki_apkg_import_test_',
    );
    final missingPath = '${directory.path}/missing.apkg';

    try {
      await expectLater(
        AnkiApkgImporter.import(missingPath),
        throwsA(
          isA<AnkiApkgException>()
              .having(
                  (error) => error.code, 'code', AnkiApkgErrorCode.fileNotFound)
              .having((error) => error.path, 'path', missingPath),
        ),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
