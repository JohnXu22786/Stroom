import 'dart:convert';
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

  test('classifies package read failures as local file failures', () async {
    final directory = await Directory.systemTemp.createTemp(
      'stroom_anki_apkg_read_error_test_',
    );
    final unreadablePath = '${directory.path}/package.apkg';
    await File(unreadablePath).writeAsBytes([0]);

    try {
      await expectLater(
        AnkiApkgImporter.import(
          unreadablePath,
          readPackageBytes: (_) => throw const FileSystemException(
            'Permission denied',
          ),
        ),
        throwsA(
          isA<AnkiApkgException>().having(
            (error) => error.code,
            'code',
            AnkiApkgErrorCode.localFileFailure,
          ),
        ),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('classifies a valid archive without a collection database', () async {
    final directory = await Directory.systemTemp.createTemp(
      'stroom_anki_apkg_collection_missing_test_',
    );
    final archive = Archive()
      ..addFile(ArchiveFile('README.txt', 5, [104, 101, 108, 108, 111]));
    final packagePath = '${directory.path}/no-collection.apkg';
    await File(packagePath).writeAsBytes(ZipEncoder().encode(archive));

    try {
      await expectLater(
        AnkiApkgImporter.import(packagePath),
        throwsA(
          isA<AnkiApkgException>().having(
            (error) => error.code,
            'code',
            AnkiApkgErrorCode.collectionMissing,
          ),
        ),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('classifies malformed package archives', () async {
    final directory = await Directory.systemTemp.createTemp(
      'stroom_anki_apkg_archive_error_test_',
    );
    final packagePath = '${directory.path}/broken.apkg';
    await File(packagePath).writeAsBytes([0x50, 0x4b, 0x03]);

    try {
      await expectLater(
        AnkiApkgImporter.import(packagePath),
        throwsA(
          isA<AnkiApkgException>().having(
            (error) => error.code,
            'code',
            AnkiApkgErrorCode.invalidArchive,
          ),
        ),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('links imported cards to newly imported notes', () async {
    final documents = await Directory.systemTemp.createTemp(
      'stroom_anki_apkg_import_note_card_link_test_',
    );
    final previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _DocumentsPathProvider(documents.path);
    final sourcePath = '${documents.path}/source.anki2';
    final targetPath = '${documents.path}/collection.anki2';

    try {
      await _createCollection(sourcePath, includeNote: true, includeCard: true);
      await _createCollection(targetPath);
      final packagePath = await _packageCollection(documents, sourcePath);

      await AnkiApkgImporter.import(packagePath);

      final target = await sqflite.openDatabase(targetPath, readOnly: true);
      try {
        final notes = await target.query('notes');
        final cards = await target.query('cards');
        expect(notes, hasLength(1));
        expect(cards, hasLength(1));
        expect(cards.single['nid'], notes.single['id']);
        expect(notes.single['id'], isNot(42));
      } finally {
        await target.close();
      }
    } finally {
      PathProviderPlatform.instance = previous;
      await documents.delete(recursive: true);
    }
  });

  test(
    'imports missing note type definitions and keeps notes mapped to them',
    () async {
      final documents = await Directory.systemTemp.createTemp(
        'stroom_anki_apkg_import_note_type_test_',
      );
      final previous = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _DocumentsPathProvider(documents.path);
      final sourcePath = '${documents.path}/source.anki2';
      final targetPath = '${documents.path}/collection.anki2';

      try {
        await _createCollection(
          sourcePath,
          includeNote: true,
          includeCard: true,
          noteModelId: 200,
          models: {
            '100': _modelJson(
              100,
              'Existing target type',
              did: 2,
              templateDid: 2,
            ),
            '200': _modelJson(
              200,
              'Imported custom type',
              did: 2,
              templateDid: 2,
            ),
          },
          decks: {
            '2': {'id': 2, 'name': 'Imported deck'},
          },
        );
        await _createCollection(
          targetPath,
          models: {
            '100': Map.fromEntries(
              _modelJson(
                100,
                'Existing target type',
                did: 100,
                templateDid: 100,
              ).entries.toList().reversed,
            ),
          },
          decks: {
            '100': {'id': 100, 'name': 'Imported deck'},
          },
        );
        final packagePath = await _packageCollection(documents, sourcePath);

        await AnkiApkgImporter.import(packagePath);

        final target = await sqflite.openDatabase(targetPath, readOnly: true);
        try {
          final collection = (await target.query('col')).single;
          final models = Map<String, dynamic>.from(
            jsonDecode(collection['models'] as String) as Map,
          );
          final notes = await target.query('notes');
          final cards = await target.query('cards');
          expect(models, contains('200'));
          expect(models, hasLength(2));
          expect(models['200']['name'], 'Imported custom type');
          expect(models['200']['did'], 100);
          expect(models['200']['tmpls'].single['did'], 100);
          expect(notes.single['mid'], 200);
          expect(
            models.containsKey((notes.single['mid'] as int).toString()),
            isTrue,
          );
          expect(cards.single['nid'], notes.single['id']);
          expect(cards.single['ord'], 0);
        } finally {
          await target.close();
        }
      } finally {
        PathProviderPlatform.instance = previous;
        await documents.delete(recursive: true);
      }
    },
  );

  test('remaps imported notes when a note type ID collides', () async {
    final documents = await Directory.systemTemp.createTemp(
      'stroom_anki_apkg_import_note_type_collision_test_',
    );
    final previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _DocumentsPathProvider(documents.path);
    final sourcePath = '${documents.path}/source.anki2';
    final targetPath = '${documents.path}/collection.anki2';

    try {
      await _createCollection(
        sourcePath,
        includeNote: true,
        includeCard: true,
        noteModelId: 200,
        models: {'200': _modelJson(200, 'Imported package type')},
      );
      await _createCollection(
        targetPath,
        models: {'200': _modelJson(200, 'Existing target type')},
      );
      final packagePath = await _packageCollection(documents, sourcePath);

      await AnkiApkgImporter.import(packagePath);

      final target = await sqflite.openDatabase(targetPath, readOnly: true);
      try {
        final collection = (await target.query('col')).single;
        final models = Map<String, dynamic>.from(
          jsonDecode(collection['models'] as String) as Map,
        );
        final note = (await target.query('notes')).single;
        final card = (await target.query('cards')).single;
        final mappedModelId = note['mid'] as int;
        expect(mappedModelId, isNot(200));
        expect(models['200']['name'], 'Existing target type');
        expect(
          models[mappedModelId.toString()]['name'],
          'Imported package type',
        );
        expect(card['nid'], note['id']);
        expect(card['ord'], 0);
      } finally {
        await target.close();
      }
    } finally {
      PathProviderPlatform.instance = previous;
      await documents.delete(recursive: true);
    }
  });

  test('does not import a duplicate card for an existing note', () async {
    final documents = await Directory.systemTemp.createTemp(
      'stroom_anki_apkg_import_duplicate_note_card_link_test_',
    );
    final previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _DocumentsPathProvider(documents.path);
    final sourcePath = '${documents.path}/source.anki2';
    final targetPath = '${documents.path}/collection.anki2';

    try {
      await _createCollection(sourcePath, includeNote: true, includeCard: true);
      await _createCollection(
        targetPath,
        includeNote: true,
        includeCard: true,
        noteId: 900,
      );
      final packagePath = await _packageCollection(documents, sourcePath);

      final summary = await AnkiApkgImporter.import(packagePath);

      final target = await sqflite.openDatabase(targetPath, readOnly: true);
      try {
        final notes = await target.query('notes');
        final cards = await target.query('cards');
        expect(notes, hasLength(1));
        expect(notes.single['id'], 900);
        expect(cards, hasLength(1));
        expect(cards.single['nid'], 900);
        expect(summary.cardsImported, 0);
      } finally {
        await target.close();
      }
    } finally {
      PathProviderPlatform.instance = previous;
      await documents.delete(recursive: true);
    }
  });

  test('imports a missing card ordinal for an existing note', () async {
    final documents = await Directory.systemTemp.createTemp(
      'stroom_anki_apkg_import_missing_duplicate_note_card_test_',
    );
    final previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _DocumentsPathProvider(documents.path);
    final sourcePath = '${documents.path}/source.anki2';
    final targetPath = '${documents.path}/collection.anki2';

    try {
      await _createCollection(sourcePath, includeNote: true, includeCard: true);
      await _createCollection(targetPath, includeNote: true, noteId: 900);
      final packagePath = await _packageCollection(documents, sourcePath);

      final summary = await AnkiApkgImporter.import(packagePath);

      final target = await sqflite.openDatabase(targetPath, readOnly: true);
      try {
        final notes = await target.query('notes');
        final cards = await target.query('cards');
        expect(notes, hasLength(1));
        expect(notes.single['id'], 900);
        expect(cards, hasLength(1));
        expect(cards.single['nid'], 900);
        expect(summary.cardsImported, 1);
      } finally {
        await target.close();
      }
    } finally {
      PathProviderPlatform.instance = previous;
      await documents.delete(recursive: true);
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
                (entry) =>
                    entry.uri.pathSegments.last.startsWith('tmp_import_'),
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

      Future<void> createCollectionWithoutNotesOrCards(
        String path, {
        String decks = '{}',
      }) async {
        final db = await sqflite.openDatabase(
          path,
          version: 1,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE col (id INTEGER PRIMARY KEY, decks TEXT, mod INTEGER, dty INTEGER)',
            );
            await db.insert('col', {
              'id': 1,
              'decks': decks,
              'mod': 10,
              'dty': 0,
            });
          },
        );
        await db.close();
      }

      try {
        await createCollectionWithoutNotesOrCards(
          sourcePath,
          decks: '{"2":{"name":"Imported deck"}}',
        );
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
              AnkiApkgErrorCode.unexpectedError,
            ),
          ),
        );
        final target = await sqflite.openDatabase(targetPath, readOnly: true);
        try {
          final collection = (await target.query('col')).single;
          expect(collection['decks'], '{}');
          expect(collection['mod'], 10);
          expect(collection['dty'], 0);
        } finally {
          await target.close();
        }
        expect(
          documents.listSync().where(
                (entry) =>
                    entry.uri.pathSegments.last.startsWith('tmp_import_'),
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

      Future<void> createCollection(String path,
          {bool includeNote = false}) async {
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
              AnkiApkgErrorCode.unexpectedError,
            ),
          ),
        );
        expect(
          documents.listSync().where(
                (entry) =>
                    entry.uri.pathSegments.last.startsWith('tmp_import_'),
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

Future<void> _createCollection(
  String path, {
  bool includeNote = false,
  bool includeCard = false,
  int noteId = 42,
  int noteModelId = 1,
  Map<String, dynamic>? models,
  Map<String, dynamic> decks = const {},
}) async {
  final collectionModels = models ?? {'1': _modelJson(1, 'Basic')};
  final db = await sqflite.openDatabase(
    path,
    version: 1,
    onCreate: (db, _) async {
      await db.execute(
        'CREATE TABLE col (id INTEGER PRIMARY KEY, decks TEXT, models TEXT, mod INTEGER, dty INTEGER)',
      );
      await db.insert('col', {
        'id': 1,
        'decks': jsonEncode(decks),
        'models': jsonEncode(collectionModels),
      });
      await db.execute(
        'CREATE TABLE notes (id INTEGER, guid TEXT, mid INTEGER, mod INTEGER, usn INTEGER, tags TEXT, flds TEXT, sfld TEXT, csum INTEGER, flags INTEGER, data TEXT)',
      );
      await db.execute(
        'CREATE TABLE cards (id INTEGER, nid INTEGER, did INTEGER, ord INTEGER, mod INTEGER, usn INTEGER, type INTEGER, queue INTEGER, due INTEGER, ivl INTEGER, factor INTEGER, reps INTEGER, lapses INTEGER, left INTEGER, odue INTEGER, odid INTEGER, flags INTEGER, data TEXT)',
      );
      if (includeNote) {
        await db.insert('notes', {
          'id': noteId,
          'guid': 'note-guid',
          'mid': noteModelId,
          'mod': 0,
          'usn': 0,
          'tags': '',
          'flds': 'front\u001fback',
          'sfld': 'front',
          'csum': 0,
          'flags': 0,
          'data': '',
        });
      }
      if (includeCard) {
        await db.insert('cards', {
          'id': 43,
          'nid': noteId,
          'did': 1,
          'ord': 0,
          'mod': 0,
          'usn': 0,
          'type': 0,
          'queue': 0,
          'due': 0,
          'ivl': 0,
          'factor': 2500,
          'reps': 0,
          'lapses': 0,
          'left': 0,
          'odue': 0,
          'odid': 0,
          'flags': 0,
          'data': '',
        });
      }
    },
  );
  await db.close();
}

Future<String> _packageCollection(
  Directory directory,
  String sourcePath,
) async {
  final source = File(sourcePath);
  final archive = Archive()
    ..addFile(
      ArchiveFile(
        'collection.anki2',
        await source.length(),
        await source.readAsBytes(),
      ),
    );
  final packagePath = '${directory.path}/package.apkg';
  await File(packagePath).writeAsBytes(ZipEncoder().encode(archive));
  return packagePath;
}

class _DocumentsPathProvider extends PathProviderPlatform {
  _DocumentsPathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

Map<String, dynamic> _modelJson(
  int id,
  String name, {
  int did = 1,
  int? templateDid,
}) =>
    {
      'id': id,
      'name': name,
      'type': 0,
      'mod': 1,
      'usn': -1,
      'sortf': 0,
      'did': did,
      'flds': [
        {'name': 'Front', 'ord': 0},
        {'name': 'Back', 'ord': 1},
      ],
      'tmpls': [
        {
          'name': 'Card 1',
          'ord': 0,
          'qfmt': '{{Front}}',
          'afmt': '{{Back}}',
          // ignore: use_null_aware_elements
          if (templateDid != null) 'did': templateDid,
        },
      ],
      'css': '',
      'req': [],
      'tags': [],
      'latexPre': '',
      'latexPost': '',
      'latex': 'dvipng',
    };
