import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stroom/anki/database/anki_database.dart';
import 'package:stroom/anki/database/anki_schema.dart';
import 'package:stroom/anki/database/col_dao.dart';
import 'package:stroom/anki/models/note.dart';
import 'package:stroom/anki/sync/anki_collection_transfer.dart';
import 'package:stroom/anki/sync/anki_incremental_sync.dart';
import 'package:stroom/anki/sync/anki_sync_destination_state.dart';
import 'package:stroom/anki/sync/anki_sync_protocol_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  test(
    'rejects an invalid server database without replacing the local file',
    () async {
      final documents = await Directory.systemTemp.createTemp(
        'stroom_anki_transfer_invalid_',
      );
      final collectionFile = File('${documents.path}/collection.anki2');
      await collectionFile.writeAsBytes([1, 2, 3]);
      final fake = _QueueHttpClient([
        http.Response.bytes([4, 5, 6], 200),
      ]);
      final client = AnkiSyncProtocolClient.ankiWeb(
        client: fake,
        hostKey: 'test-host-key',
      );

      try {
        await expectLater(
          AnkiCollectionTransfer.downloadAndReplaceLocalCollection(
            client,
            documentsPath: documents.path,
          ),
          throwsA(isA<AnkiSyncException>()),
        );

        expect(await collectionFile.readAsBytes(), [1, 2, 3]);
        expect(
          await File('${collectionFile.path}.sync-download.tmp').exists(),
          isFalse,
        );
      } finally {
        client.close();
        fake.close();
        await AnkiDatabase.closeOpenedInstance();
        await documents.delete(recursive: true);
      }
    },
  );

  test(
    'keeps the restored collection when failed-download cleanup fails',
    () async {
      final documents = await Directory.systemTemp.createTemp(
        'stroom_anki_transfer_restore_cleanup_',
      );
      final collectionFile = File('${documents.path}/collection.anki2');
      final backupFile = File('${documents.path}/collection.backup');
      await collectionFile.writeAsBytes([4, 5, 6]);
      await backupFile.writeAsBytes([1, 2, 3]);

      try {
        await AnkiCollectionTransfer.restoreLocalCollectionBackup(
          backupFile.path,
          documentsPath: documents.path,
          deleteDisplacedFile: (_) async {
            throw const FileSystemException('simulated cleanup failure');
          },
        );

        expect(await collectionFile.readAsBytes(), [1, 2, 3]);
        expect(
          await File('${collectionFile.path}.failed-download').readAsBytes(),
          [4, 5, 6],
        );
      } finally {
        await AnkiDatabase.closeOpenedInstance();
        await documents.delete(recursive: true);
      }
    },
  );

  test(
    'removes a first-time collection when full-download rollback has no backup',
    () async {
      final documents = await Directory.systemTemp.createTemp(
        'stroom_anki_transfer_first_download_rollback_',
      );
      final collectionFile = File('${documents.path}/collection.anki2');
      await collectionFile.writeAsBytes([4, 5, 6]);

      try {
        await AnkiCollectionTransfer.restoreLocalCollectionBackup(
          '',
          documentsPath: documents.path,
        );

        expect(await collectionFile.exists(), isFalse);
      } finally {
        await AnkiDatabase.closeOpenedInstance();
        await documents.delete(recursive: true);
      }
    },
  );

  test(
    'rejects an integrity-valid but incomplete schema 11 download',
    () async {
      final documents = await Directory.systemTemp.createTemp(
        'stroom_anki_transfer_incomplete_',
      );
      final collectionFile = File('${documents.path}/collection.anki2');
      await collectionFile.writeAsBytes([1, 2, 3]);
      final incompletePath = '${documents.path}/incomplete.anki2';
      final incomplete = await sqflite.openDatabase(
        incompletePath,
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
          CREATE TABLE col (
            id INTEGER PRIMARY KEY, crt INTEGER NOT NULL, mod INTEGER NOT NULL,
            scm INTEGER NOT NULL, ver INTEGER NOT NULL, dty INTEGER NOT NULL,
            usn INTEGER NOT NULL, ls INTEGER NOT NULL, conf TEXT NOT NULL,
            models TEXT NOT NULL, decks TEXT NOT NULL, dconf TEXT NOT NULL,
            tags TEXT NOT NULL
          )
        ''');
          await db.insert('col', {
            'id': 1,
            'crt': 1,
            'mod': 1,
            'scm': 1,
            'ver': 11,
            'dty': 0,
            'usn': 0,
            'ls': 0,
            'conf': '{}',
            'models': '{}',
            'decks': '{}',
            'dconf': '{}',
            'tags': '{}',
          });
        },
      );
      final integrity = await incomplete.rawQuery('PRAGMA integrity_check');
      expect(integrity.single.values.single, 'ok');
      await incomplete.close();
      final incompleteBytes = await File(incompletePath).readAsBytes();
      final fake = _QueueHttpClient([
        http.Response.bytes(incompleteBytes, 200),
      ]);
      final client = AnkiSyncProtocolClient.ankiWeb(
        client: fake,
        hostKey: 'test-host-key',
      );

      try {
        await expectLater(
          AnkiCollectionTransfer.downloadAndReplaceLocalCollection(
            client,
            documentsPath: documents.path,
          ),
          throwsA(isA<AnkiSyncException>()),
        );

        expect(await collectionFile.readAsBytes(), [1, 2, 3]);
        expect(
          await File('${collectionFile.path}.sync-download.tmp').exists(),
          isFalse,
        );
      } finally {
        client.close();
        fake.close();
        await AnkiDatabase.closeOpenedInstance();
        await documents.delete(recursive: true);
      }
    },
  );

  test(
    'installs official schema 11 collections without Stroom-only tables',
    () async {
      final documents = await Directory.systemTemp.createTemp(
        'stroom_anki_transfer_official_schema_',
      );
      final remoteDirectory = Directory('${documents.path}/remote');
      await remoteDirectory.create();
      final remote = AnkiDatabase(basePath: remoteDirectory.path);
      final local = AnkiDatabase(basePath: documents.path);

      try {
        await local.open();
        await local.close();
        await remote.open();
        await remote.col.load();
        final numericSortNote = Note.createNew(
          notetype_id: remote.col.modelList.first.id,
          fields: ['123', 'numeric back'],
        );
        await remote.notes.insert(numericSortNote);
        final remotePath = '${remoteDirectory.path}/collection.anki2';
        await remote.close();

        // Official schema 11 stores deck settings in col.dconf and collection
        // settings in col.conf, and uses INTEGER affinity for notes.sfld.
        final official = await sqflite.openDatabase(
          remotePath,
          singleInstance: false,
        );
        await official.execute('ALTER TABLE notes RENAME TO notes_local');
        await official.execute('''
          CREATE TABLE notes (
            id INTEGER PRIMARY KEY, guid TEXT NOT NULL, mid INTEGER NOT NULL,
            mod INTEGER NOT NULL, usn INTEGER NOT NULL, tags TEXT NOT NULL,
            flds TEXT NOT NULL, sfld INTEGER NOT NULL, csum INTEGER NOT NULL,
            flags INTEGER NOT NULL, data TEXT NOT NULL
          )
        ''');
        await official.execute('''
          INSERT INTO notes
          SELECT id, guid, mid, mod, usn, tags, flds, CAST(sfld AS INTEGER),
                 csum, flags, data
          FROM notes_local
        ''');
        await official.execute('DROP TABLE notes_local');
        await official.execute('DROP TABLE deck_config');
        await official.execute('DROP TABLE config');
        await official.execute('DROP TABLE stroom_sync_destination');
        await official.execute('PRAGMA user_version = 0');
        await official.close();

        final fake = _QueueHttpClient([
          http.Response.bytes(await File(remotePath).readAsBytes(), 200),
        ]);
        final client = AnkiSyncProtocolClient.ankiWeb(
          client: fake,
          hostKey: 'test-host-key',
        );

        try {
          await AnkiCollectionTransfer.downloadAndReplaceLocalCollection(
            client,
            documentsPath: documents.path,
          );

          final installed = AnkiDatabase(basePath: documents.path);
          await installed.open();
          expect(await installed.db.query('deck_config'), hasLength(1));
          expect(await installed.db.query('config'), isEmpty);
          expect(
            (await installed.notes.get(numericSortNote.id))!.sort_field,
            '123',
          );
          await installed.close();
        } finally {
          client.close();
          fake.close();
        }
      } finally {
        await AnkiDatabase.closeOpenedInstance();
        await documents.delete(recursive: true);
      }
    },
  );

  test('creates local notes with official INTEGER sfld affinity', () async {
    final documents = await Directory.systemTemp.createTemp(
      'stroom_anki_notes_affinity_',
    );
    final database = AnkiDatabase(basePath: documents.path);

    try {
      await database.open();

      final columns = await database.db.rawQuery('PRAGMA table_info(notes)');
      final sortField = columns.singleWhere(
        (column) => column['name'] == 'sfld',
      );
      expect(sortField['type'], 'INTEGER');
    } finally {
      await AnkiDatabase.closeOpenedInstance();
      await documents.delete(recursive: true);
    }
  });

  test('migrates local TEXT sfld columns without losing note data', () async {
    final documents = await Directory.systemTemp.createTemp(
      'stroom_anki_notes_affinity_migration_',
    );
    final path = '${documents.path}/collection.anki2';
    final legacy = await sqflite.openDatabase(
      path,
      version: AnkiSchema.schemaVersion,
      onCreate: (db, _) async {
        for (final statement in AnkiSchema.createStatements) {
          final sql = statement.contains('CREATE TABLE IF NOT EXISTS notes')
              ? statement.replaceFirst(
                  RegExp(r'sfld\s+(?:TEXT|INTEGER)'),
                  'sfld TEXT',
                )
              : statement;
          await db.execute(sql);
        }
        await ColDao.seed(db);
        await db.insert('notes', {
          'id': 1,
          'guid': 'legacy-guid',
          'mid': 1,
          'mod': 1700000000,
          'usn': 0,
          'tags': '',
          'flds': 'legacy sort\u001fback',
          'sfld': 'legacy sort',
          'csum': Note.computeChecksum('legacy sort'),
          'flags': 0,
          'data': '',
        });
      },
    );
    await legacy.close();
    final database = AnkiDatabase(basePath: documents.path);

    try {
      await database.open();

      final columns = await database.db.rawQuery('PRAGMA table_info(notes)');
      final sortField = columns.singleWhere(
        (column) => column['name'] == 'sfld',
      );
      expect(sortField['type'], 'INTEGER');
      final note = (await database.db.query('notes')).single;
      expect(note['id'], 1);
      expect(note['flds'], 'legacy sort\u001fback');
      expect(note['sfld'], 'legacy sort');
    } finally {
      await AnkiDatabase.closeOpenedInstance();
      await documents.delete(recursive: true);
    }
  });

  test(
    'rejects invalid local collection before backup or upload request',
    () async {
      final documents = await Directory.systemTemp.createTemp(
        'stroom_anki_transfer_invalid_upload_',
      );
      final collectionFile = File('${documents.path}/collection.anki2');
      await collectionFile.writeAsBytes([1, 2, 3]);
      final fake = _QueueHttpClient([]);
      final client = AnkiSyncProtocolClient.ankiWeb(
        client: fake,
        hostKey: 'test-host-key',
      );

      try {
        await expectLater(
          AnkiCollectionTransfer.uploadLocalCollection(
            client,
            documentsPath: documents.path,
          ),
          throwsA(isA<AnkiSyncException>()),
        );

        expect(fake.requestsSent, 0);
        expect(
          await documents
              .list()
              .where((entry) => entry.path.contains('.sync-backup-'))
              .toList(),
          isEmpty,
        );
        expect(await collectionFile.readAsBytes(), [1, 2, 3]);
      } finally {
        client.close();
        fake.close();
        await AnkiDatabase.closeOpenedInstance();
        await documents.delete(recursive: true);
      }
    },
  );

  test(
    'requires a verified full transfer after an ambiguous full upload failure',
    () async {
      final documents = await Directory.systemTemp.createTemp(
        'stroom_anki_transfer_destination_',
      );
      final local = AnkiDatabase(basePath: documents.path);
      await local.open();
      await local.col.load();
      await local.close();

      final firstFake = _QueueHttpClient([http.Response('OK', 200)]);
      final firstClient = AnkiSyncProtocolClient.ankiWeb(
        client: firstFake,
        hostKey: 'first-account-key',
      );
      final secondFake = _QueueHttpClient([
        http.Response('upload failed', 503),
      ]);
      final secondClient = AnkiSyncProtocolClient.selfHosted(
        endpoint: 'https://other-sync.example.invalid',
        client: secondFake,
        hostKey: 'second-account-key',
      );

      try {
        final backup = await AnkiCollectionTransfer.uploadLocalCollection(
          firstClient,
          documentsPath: documents.path,
        );
        expect(await File(backup).exists(), isTrue);

        final afterFirstUpload = AnkiDatabase(basePath: documents.path);
        await afterFirstUpload.open();
        expect(
          await AnkiSyncDestinationState.read(afterFirstUpload.db),
          firstClient.destinationIdentity,
        );
        await afterFirstUpload.close();

        await expectLater(
          AnkiCollectionTransfer.uploadLocalCollection(
            secondClient,
            documentsPath: documents.path,
          ),
          throwsA(isA<AnkiSyncException>()),
        );

        final requestCount = firstFake.requestsSent;
        final afterFailedUpload = AnkiDatabase(basePath: documents.path);
        await afterFailedUpload.open();
        await expectLater(
          AnkiIncrementalSync.sync(afterFailedUpload, firstClient),
          throwsA(isA<AnkiSyncFullTransferRequired>()),
        );
        expect(firstFake.requestsSent, requestCount);
        final secondRequestCount = secondFake.requestsSent;
        await expectLater(
          AnkiIncrementalSync.sync(afterFailedUpload, secondClient),
          throwsA(isA<AnkiSyncFullTransferRequired>()),
        );
        expect(secondFake.requestsSent, secondRequestCount);
        await afterFailedUpload.close();
      } finally {
        firstClient.close();
        firstFake.close();
        secondClient.close();
        secondFake.close();
        await AnkiDatabase.closeOpenedInstance();
        await documents.delete(recursive: true);
      }
    },
  );

  test(
    'replaces a valid collection and preserves a local database backup',
    () async {
      final documents = await Directory.systemTemp.createTemp(
        'stroom_anki_transfer_valid_',
      );
      final remoteDirectory = Directory('${documents.path}/remote');
      await remoteDirectory.create();
      final local = AnkiDatabase(basePath: documents.path);
      final remote = AnkiDatabase(basePath: remoteDirectory.path);

      try {
        await local.open();
        await local.col.load();
        final localCreated = ((await local.db.query('col', columns: ['crt']))
                .single['crt'] as num)
            .toInt();
        await local.close();
        final localFile = File('${documents.path}/collection.anki2');
        final originalBytes = await localFile.readAsBytes();

        await remote.open();
        await remote.col.load();
        final note = Note.createNew(
          notetype_id: remote.col.modelList.first.id,
          fields: ['downloaded front', 'downloaded back'],
        );
        await remote.notes.insert(note);
        await remote.db.update('col', {'crt': localCreated}, where: 'id = 1');
        await remote.db.update(
          'notes',
          {'sfld': 'stale metadata', 'csum': 0},
          where: 'id = ?',
          whereArgs: [note.id],
        );
        await remote.close();
        final remoteBytes = await File(
          '${remoteDirectory.path}/collection.anki2',
        ).readAsBytes();
        final fake = _QueueHttpClient([http.Response.bytes(remoteBytes, 200)]);
        final client = AnkiSyncProtocolClient.ankiWeb(
          client: fake,
          hostKey: 'test-host-key',
        );

        try {
          final backupPath =
              await AnkiCollectionTransfer.downloadAndReplaceLocalCollection(
            client,
            documentsPath: documents.path,
          );

          expect(await File(backupPath).readAsBytes(), originalBytes);
          expect(await localFile.exists(), isTrue);
          final installed = AnkiDatabase(basePath: documents.path);
          await installed.open();
          final integrity = await installed.db.rawQuery(
            'PRAGMA integrity_check',
          );
          expect(integrity.single.values.single, 'ok');
          final row = (await installed.db.query('col')).single;
          expect(row['ver'], 11);
          expect(row['ls'], row['mod']);
          expect(
            await AnkiSyncDestinationState.read(installed.db),
            client.destinationIdentity,
          );
          final migratedNote = (await installed.db.query(
            'notes',
            where: 'id = ?',
            whereArgs: [note.id],
          ))
              .single;
          expect(migratedNote['sfld'], 'downloaded front');
          expect(
            migratedNote['csum'],
            Note.computeChecksum('downloaded front'),
          );
          await installed.close();
        } finally {
          client.close();
          fake.close();
        }
      } finally {
        await AnkiDatabase.closeOpenedInstance();
        await documents.delete(recursive: true);
      }
    },
  );
}

class _QueueHttpClient extends http.BaseClient {
  final List<http.Response> _responses;
  var requestsSent = 0;

  _QueueHttpClient(this._responses);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestsSent++;
    await request.finalize().fold<List<int>>(
      <int>[],
      (collected, chunk) => collected..addAll(chunk),
    );
    final response = _responses.removeAt(0);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}
