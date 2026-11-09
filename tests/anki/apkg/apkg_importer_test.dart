import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stroom/anki/apkg/apkg_importer.dart';
import 'package:stroom/anki/apkg/apkg_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

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
                (error) => error.code,
                'code',
                AnkiApkgErrorCode.fileNotFound,
              )
              .having((error) => error.path, 'path', missingPath),
        ),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test(
    'maps invalid SQLite package data and removes the extracted temp file',
    () async {
      final documents = await Directory.systemTemp.createTemp(
        'stroom_anki_apkg_import_invalid_db_test_',
      );
      final previous = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _DocumentsPathProvider(documents.path);
      final collectionPath = '${documents.path}/collection.anki2';
      await File(collectionPath).writeAsBytes([1, 2, 3]);

      final invalidDatabase = [1, 2, 3, 4, 5];
      final archive = Archive()
        ..addFile(
          ArchiveFile(
            'collection.anki2',
            invalidDatabase.length,
            invalidDatabase,
          ),
        );
      final encoded = ZipEncoder().encode(archive);
      final packagePath = '${documents.path}/invalid.anki2.apkg';
      await File(packagePath).writeAsBytes(encoded);

      try {
        await expectLater(
          AnkiApkgImporter.import(packagePath),
          throwsA(
            isA<AnkiApkgException>().having(
              (error) => error.code,
              'code',
              AnkiApkgErrorCode.databaseCorrupt,
            ),
          ),
        );
        expect(
          documents.listSync().where(
            (entry) => entry.uri.pathSegments.last.startsWith('tmp_import_'),
          ),
          isEmpty,
        );
      } finally {
        PathProviderPlatform.instance = previous;
        await documents.delete(recursive: true);
      }
    },
  );

  test(
    'maps missing imported tables and removes the extracted temp file',
    () async {
      final documents = await Directory.systemTemp.createTemp(
        'stroom_anki_apkg_import_missing_table_test_',
      );
      final previous = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _DocumentsPathProvider(documents.path);
      final sourcePath = '${documents.path}/source.anki2';
      final targetPath = '${documents.path}/collection.anki2';

      Future<void> createCollectionWithoutNotesOrCards(String path) async {
        final db = await sqflite.openDatabase(
          path,
          version: 1,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE col (id INTEGER PRIMARY KEY, decks TEXT, mod INTEGER, dty INTEGER)',
            );
            await db.insert('col', {'id': 1, 'decks': '{}'});
          },
        );
        await db.close();
      }

      try {
        await createCollectionWithoutNotesOrCards(sourcePath);
        await createCollectionWithoutNotesOrCards(targetPath);
        final archive = Archive()
          ..addFile(
            ArchiveFile(
              'collection.anki2',
              await File(sourcePath).length(),
              await File(sourcePath).readAsBytes(),
            ),
          );
        final packagePath = '${documents.path}/missing-tables.apkg';
        await File(packagePath).writeAsBytes(ZipEncoder().encode(archive));

        await expectLater(
          AnkiApkgImporter.import(packagePath),
          throwsA(
            isA<AnkiApkgException>().having(
              (error) => error.code,
              'code',
              AnkiApkgErrorCode.databaseCorrupt,
            ),
          ),
        );
        expect(
          documents.listSync().where(
            (entry) => entry.uri.pathSegments.last.startsWith('tmp_import_'),
          ),
          isEmpty,
        );
      } finally {
        PathProviderPlatform.instance = previous;
        await documents.delete(recursive: true);
      }
    },
  );

  test(
    'maps missing destination tables and removes the extracted temp file',
    () async {
      final documents = await Directory.systemTemp.createTemp(
        'stroom_anki_apkg_import_missing_destination_table_test_',
      );
      final previous = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _DocumentsPathProvider(documents.path);
      final sourcePath = '${documents.path}/source.anki2';
      final targetPath = '${documents.path}/collection.anki2';

      Future<void> createCollection(String path, {bool includeNote = false}) async {
        final db = await sqflite.openDatabase(
          path,
          version: 1,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE col (id INTEGER PRIMARY KEY, decks TEXT, mod INTEGER, dty INTEGER)',
            );
            await db.insert('col', {'id': 1, 'decks': '{}'});
            if (includeNote) {
              await db.execute(
                'CREATE TABLE notes (id INTEGER, guid TEXT, mid INTEGER, tags TEXT, flds TEXT, sfld TEXT, csum INTEGER, flags INTEGER, data TEXT)',
              );
              await db.insert('notes', {
                'id': 1,
                'guid': 'test-note-guid',
                'mid': 1,
                'tags': '',
                'flds': 'test',
                'sfld': 'test',
                'csum': 0,
                'flags': 0,
                'data': '',
              });
            }
          },
        );
        await db.close();
      }

      try {
        await createCollection(sourcePath, includeNote: true);
        await createCollection(targetPath);
        final sourceFile = File(sourcePath);
        final archive = Archive()
          ..addFile(
            ArchiveFile(
              'collection.anki2',
              await sourceFile.length(),
              await sourceFile.readAsBytes(),
            ),
          );
        final packagePath = '${documents.path}/missing-destination-table.apkg';
        await File(packagePath).writeAsBytes(ZipEncoder().encode(archive));

        await expectLater(
          AnkiApkgImporter.import(packagePath),
          throwsA(
            isA<AnkiApkgException>().having(
              (error) => error.code,
              'code',
              AnkiApkgErrorCode.databaseCorrupt,
            ),
          ),
        );
        expect(
          documents.listSync().where(
            (entry) => entry.uri.pathSegments.last.startsWith('tmp_import_'),
          ),
          isEmpty,
        );
      } finally {
        PathProviderPlatform.instance = previous;
        await documents.delete(recursive: true);
      }
    },
  );
}

class _DocumentsPathProvider extends PathProviderPlatform {
  _DocumentsPathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}
