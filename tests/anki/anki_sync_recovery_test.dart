import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stroom/anki/database/anki_database.dart';
import 'package:stroom/anki/models/note.dart';
import 'package:stroom/anki/sync/anki_media_sync.dart';
import 'package:stroom/anki/sync/anki_sync_protocol_client.dart';
import 'package:stroom/anki/sync/anki_full_download_recovery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  test('startup restores collection and media after an interrupted download',
      () async {
    final documents = await Directory.systemTemp.createTemp(
      'stroom_anki_recovery_',
    );
    final collection = AnkiDatabase(basePath: documents.path);
    final remoteDirectory = Directory('${documents.path}/remote');
    await remoteDirectory.create();
    final remote = AnkiDatabase(basePath: remoteDirectory.path);
    final mediaDirectory = Directory('${documents.path}/collection.media');
    final localMedia = File('${mediaDirectory.path}/local.jpg');
    final downloadedMedia = File('${mediaDirectory.path}/remote.jpg');
    final client = AnkiSyncProtocolClient.ankiWeb(
      client: http.Client(),
      hostKey: 'recovery-test',
    );

    try {
      await collection.open();
      await collection.col.load();
      final localNote = Note.createNew(
        notetype_id: collection.col.modelList.first.id,
        fields: ['local-only', 'keep me'],
      );
      await collection.notes.insert(localNote);
      await AnkiDatabase.closeOpenedInstance();
      final originalCollection = await File(
        '${documents.path}/collection.anki2',
      ).readAsBytes();

      await remote.open();
      await remote.col.load();
      final remoteNote = Note.createNew(
        notetype_id: remote.col.modelList.first.id,
        fields: ['server-only', 'replace me'],
      );
      await remote.notes.insert(remoteNote);
      await remote.close();

      await mediaDirectory.create();
      await localMedia.writeAsBytes([1, 2, 3]);
      final index = _indexFile(documents.path, client.destinationIdentity);
      await index.writeAsBytes([9, 8, 7]);
      final otherDestinationIndex = _indexFile(
        documents.path,
        'other-destination',
      );
      await otherDestinationIndex.writeAsBytes([6, 5, 4]);
      final recovery = await AnkiFullDownloadRecovery.begin(
        documentsPath: documents.path,
        destinationIdentity: client.destinationIdentity,
      );
      await AnkiMediaSync.prepareForFullDownload(
        client: client,
        documentsPath: documents.path,
        recovery: recovery,
      );
      await File('${documents.path}/collection.anki2')
          .copy(recovery.collectionBackupPath!);
      await recovery.markCollectionReplacementStarted();
      await File('${remoteDirectory.path}/collection.anki2')
          .copy('${documents.path}/collection.anki2');
      await downloadedMedia.writeAsBytes([4, 5, 6]);
      for (final suffix in ['-wal', '-shm', '-journal']) {
        await File('${documents.path}/collection.anki2$suffix')
            .writeAsBytes([4, 5, 6]);
      }
      await AnkiDatabase.closeOpenedInstance();
      AnkiFullDownloadRecovery.simulateProcessRestartForTesting();

      // Opening the local collection after process restart runs recovery first.
      final reopened = AnkiDatabase(basePath: documents.path);
      await reopened.open();
      await reopened.col.load();
      expect(await reopened.notes.get(localNote.id), isNotNull);
      expect(await reopened.notes.get(remoteNote.id), isNull);
      expect(
        await File('${documents.path}/collection.anki2').readAsBytes(),
        originalCollection,
      );
      expect(await localMedia.readAsBytes(), [1, 2, 3]);
      expect(await index.readAsBytes(), [9, 8, 7]);
      expect(await otherDestinationIndex.readAsBytes(), [6, 5, 4]);
      expect(await downloadedMedia.exists(), isFalse);
      for (final suffix in ['-wal', '-shm', '-journal']) {
        expect(
          await File('${documents.path}/collection.anki2$suffix').exists(),
          isFalse,
        );
      }
      expect(
        await AnkiFullDownloadRecovery.hasPending(documents.path),
        isFalse,
      );
      await reopened.close();
    } finally {
      client.close();
      await AnkiDatabase.closeOpenedInstance();
      await documents.delete(recursive: true);
    }
  });

  test(
    'restores original collection SQLite sidecars after interruption',
    () async {
      final documents = await Directory.systemTemp.createTemp(
        'stroom_anki_recovery_collection_sidecars_',
      );
      final collection = AnkiDatabase(basePath: documents.path);
      final client = AnkiSyncProtocolClient.ankiWeb(
        client: http.Client(),
        hostKey: 'recovery-test',
      );

      try {
        await collection.open();
        await AnkiDatabase.closeOpenedInstance();
        final collectionPath = '${documents.path}/collection.anki2';
        final originalCollection = await File(collectionPath).readAsBytes();
        const sidecars = {
          '-wal': [1, 2, 3],
          '-shm': [4, 5, 6],
          '-journal': [7, 8, 9],
        };
        for (final entry in sidecars.entries) {
          await File('$collectionPath${entry.key}').writeAsBytes(entry.value);
        }

        final recovery = await AnkiFullDownloadRecovery.begin(
          documentsPath: documents.path,
          destinationIdentity: client.destinationIdentity,
        );
        await File(collectionPath).copy(recovery.collectionBackupPath!);
        await File(collectionPath).writeAsBytes([9, 9, 9]);
        await recovery.markCollectionReplacementStarted();
        for (final suffix in sidecars.keys) {
          await File('$collectionPath$suffix').writeAsBytes([0]);
        }
        AnkiFullDownloadRecovery.simulateProcessRestartForTesting();
        await AnkiFullDownloadRecovery.recoverIfNeeded(documents.path);

        expect(await File(collectionPath).readAsBytes(), originalCollection);
        for (final entry in sidecars.entries) {
          expect(
            await File('$collectionPath${entry.key}').readAsBytes(),
            entry.value,
          );
        }
        expect(
          await AnkiFullDownloadRecovery.hasPending(documents.path),
          isFalse,
        );
      } finally {
        client.close();
        await AnkiDatabase.closeOpenedInstance();
        await documents.delete(recursive: true);
      }
    },
  );

  test('recovery does not alter data before the media reset starts', () async {
    final documents = await Directory.systemTemp.createTemp(
      'stroom_anki_recovery_before_reset_',
    );
    final collection = AnkiDatabase(basePath: documents.path);
    final mediaDirectory = Directory('${documents.path}/collection.media');
    final media = File('${mediaDirectory.path}/existing.jpg');
    final client = AnkiSyncProtocolClient.ankiWeb(
      client: http.Client(),
      hostKey: 'recovery-test',
    );

    try {
      await collection.open();
      await AnkiDatabase.closeOpenedInstance();
      await mediaDirectory.create();
      await media.writeAsBytes([7, 8, 9]);
      final index = _indexFile(documents.path, client.destinationIdentity);
      await index.writeAsBytes([6, 5, 4]);
      await AnkiFullDownloadRecovery.begin(
        documentsPath: documents.path,
        destinationIdentity: client.destinationIdentity,
      );
      AnkiFullDownloadRecovery.simulateProcessRestartForTesting();

      final reopened = AnkiDatabase(basePath: documents.path);
      await reopened.open();

      expect(await media.readAsBytes(), [7, 8, 9]);
      expect(await index.readAsBytes(), [6, 5, 4]);
      expect(
        await AnkiFullDownloadRecovery.hasPending(documents.path),
        isFalse,
      );
      await reopened.close();
    } finally {
      client.close();
      await AnkiDatabase.closeOpenedInstance();
      await documents.delete(recursive: true);
    }
  });

  test(
    'keeps startup blocked when the original collection backup is missing',
    () async {
      final documents = await Directory.systemTemp.createTemp(
        'stroom_anki_recovery_missing_',
      );
      final remoteDirectory = Directory('${documents.path}/remote');
      await remoteDirectory.create();
      final local = AnkiDatabase(basePath: documents.path);
      final remote = AnkiDatabase(basePath: remoteDirectory.path);
      final client = AnkiSyncProtocolClient.ankiWeb(
        client: http.Client(),
        hostKey: 'recovery-test',
      );

      try {
        await local.open();
        await AnkiDatabase.closeOpenedInstance();
        await remote.open();
        await remote.close();
        final recovery = await AnkiFullDownloadRecovery.begin(
          documentsPath: documents.path,
          destinationIdentity: client.destinationIdentity,
        );
        await AnkiMediaSync.prepareForFullDownload(
          client: client,
          documentsPath: documents.path,
          recovery: recovery,
        );
        await recovery.markCollectionReplacementStarted();
        await File('${remoteDirectory.path}/collection.anki2')
            .copy('${documents.path}/collection.anki2');
        AnkiFullDownloadRecovery.simulateProcessRestartForTesting();

        final reopened = AnkiDatabase(basePath: documents.path);
        await expectLater(reopened.open(), throwsA(isA<FileSystemException>()));
        expect(
          await AnkiFullDownloadRecovery.hasPending(documents.path),
          isTrue,
        );
        expect(
          await File('${documents.path}/collection.anki2').exists(),
          isTrue,
        );
      } finally {
        client.close();
        await AnkiDatabase.closeOpenedInstance();
        await documents.delete(recursive: true);
      }
    },
  );

  test(
    'keeps startup blocked when the original media backup is missing',
    () async {
      final documents = await Directory.systemTemp.createTemp(
        'stroom_anki_recovery_media_missing_',
      );
      final local = AnkiDatabase(basePath: documents.path);
      final mediaDirectory = Directory('${documents.path}/collection.media');
      final client = AnkiSyncProtocolClient.ankiWeb(
        client: http.Client(),
        hostKey: 'recovery-test',
      );

      try {
        await local.open();
        await AnkiDatabase.closeOpenedInstance();
        await mediaDirectory.create();
        await File('${mediaDirectory.path}/old.jpg').writeAsBytes([1]);
        final recovery = await AnkiFullDownloadRecovery.begin(
          documentsPath: documents.path,
          destinationIdentity: client.destinationIdentity,
        );
        await AnkiMediaSync.prepareForFullDownload(
          client: client,
          documentsPath: documents.path,
          recovery: recovery,
        );
        await File('${mediaDirectory.path}/new.jpg').writeAsBytes([2]);
        await Directory(recovery.mediaBackupPath).delete(recursive: true);
        AnkiFullDownloadRecovery.simulateProcessRestartForTesting();

        final reopened = AnkiDatabase(basePath: documents.path);
        await expectLater(reopened.open(), throwsA(isA<FileSystemException>()));
        expect(
          await AnkiFullDownloadRecovery.hasPending(documents.path),
          isTrue,
        );
        expect(await File('${mediaDirectory.path}/new.jpg').readAsBytes(), [2]);
      } finally {
        client.close();
        await AnkiDatabase.closeOpenedInstance();
        await documents.delete(recursive: true);
      }
    },
  );

  test(
      'detects a missing media backup after a move is interrupted before its completion marker',
      () async {
    final documents = await Directory.systemTemp.createTemp(
      'stroom_anki_recovery_media_move_gap_',
    );
    final local = AnkiDatabase(basePath: documents.path);
    final mediaDirectory = Directory('${documents.path}/collection.media');
    final client = AnkiSyncProtocolClient.ankiWeb(
      client: http.Client(),
      hostKey: 'recovery-test',
    );

    try {
      await local.open();
      await AnkiDatabase.closeOpenedInstance();
      await mediaDirectory.create();
      await File('${mediaDirectory.path}/old.jpg').writeAsBytes([1]);
      final recovery = await AnkiFullDownloadRecovery.begin(
        documentsPath: documents.path,
        destinationIdentity: client.destinationIdentity,
      );
      await recovery.markMediaResetStarted();
      await recovery.markMediaMoveStarted();
      await mediaDirectory.rename(recovery.mediaBackupPath);
      await Directory(recovery.mediaBackupPath).delete(recursive: true);
      AnkiFullDownloadRecovery.simulateProcessRestartForTesting();

      final reopened = AnkiDatabase(basePath: documents.path);
      await expectLater(reopened.open(), throwsA(isA<FileSystemException>()));
      expect(await AnkiFullDownloadRecovery.hasPending(documents.path), isTrue);
    } finally {
      client.close();
      await AnkiDatabase.closeOpenedInstance();
      await documents.delete(recursive: true);
    }
  });

  test(
    'keeps startup blocked when an original media index backup is missing',
    () async {
      final documents = await Directory.systemTemp.createTemp(
        'stroom_anki_recovery_index_missing_',
      );
      final local = AnkiDatabase(basePath: documents.path);
      final client = AnkiSyncProtocolClient.ankiWeb(
        client: http.Client(),
        hostKey: 'recovery-test',
      );

      try {
        await local.open();
        await AnkiDatabase.closeOpenedInstance();
        final index = _indexFile(documents.path, client.destinationIdentity);
        await index.writeAsBytes([1]);
        final recovery = await AnkiFullDownloadRecovery.begin(
          documentsPath: documents.path,
          destinationIdentity: client.destinationIdentity,
        );
        await AnkiMediaSync.prepareForFullDownload(
          client: client,
          documentsPath: documents.path,
          recovery: recovery,
        );
        await index.writeAsBytes([2]);
        await File(recovery.mediaIndexBackupPath).delete();
        AnkiFullDownloadRecovery.simulateProcessRestartForTesting();

        final reopened = AnkiDatabase(basePath: documents.path);
        await expectLater(reopened.open(), throwsA(isA<FileSystemException>()));
        expect(
          await AnkiFullDownloadRecovery.hasPending(documents.path),
          isTrue,
        );
        expect(await index.readAsBytes(), [2]);
      } finally {
        client.close();
        await AnkiDatabase.closeOpenedInstance();
        await documents.delete(recursive: true);
      }
    },
  );

  test(
      'detects a missing media index after a move is interrupted before its completion marker',
      () async {
    final documents = await Directory.systemTemp.createTemp(
      'stroom_anki_recovery_index_move_gap_',
    );
    final local = AnkiDatabase(basePath: documents.path);
    final client = AnkiSyncProtocolClient.ankiWeb(
      client: http.Client(),
      hostKey: 'recovery-test',
    );

    try {
      await local.open();
      await AnkiDatabase.closeOpenedInstance();
      final index = _indexFile(documents.path, client.destinationIdentity);
      await index.writeAsBytes([1]);
      final recovery = await AnkiFullDownloadRecovery.begin(
        documentsPath: documents.path,
        destinationIdentity: client.destinationIdentity,
      );
      await recovery.markMediaResetStarted();
      await recovery.markMediaIndexFileMoveStarted(index.path);
      await index.rename(recovery.mediaIndexBackupPath);
      await File(recovery.mediaIndexBackupPath).delete();
      AnkiFullDownloadRecovery.simulateProcessRestartForTesting();

      final reopened = AnkiDatabase(basePath: documents.path);
      await expectLater(reopened.open(), throwsA(isA<FileSystemException>()));
      expect(await AnkiFullDownloadRecovery.hasPending(documents.path), isTrue);
    } finally {
      client.close();
      await AnkiDatabase.closeOpenedInstance();
      await documents.delete(recursive: true);
    }
  });

  test(
    'completed full download survives restart and clears its journal',
    () async {
      final documents = await Directory.systemTemp.createTemp(
        'stroom_anki_recovery_commit_',
      );
      final remoteDirectory = Directory('${documents.path}/remote');
      await remoteDirectory.create();
      final local = AnkiDatabase(basePath: documents.path);
      final remote = AnkiDatabase(basePath: remoteDirectory.path);
      final client = AnkiSyncProtocolClient.ankiWeb(
        client: http.Client(),
        hostKey: 'recovery-test',
      );
      final mediaDirectory = Directory('${documents.path}/collection.media');

      try {
        await local.open();
        await local.col.load();
        final localNote = Note.createNew(
          notetype_id: local.col.modelList.first.id,
          fields: ['old local', 'local collection'],
        );
        await local.notes.insert(localNote);
        await AnkiDatabase.closeOpenedInstance();
        final otherIndex = _indexFile(documents.path, 'other-destination');
        await otherIndex.writeAsBytes([3, 2, 1]);

        await remote.open();
        await remote.col.load();
        final remoteNote = Note.createNew(
          notetype_id: remote.col.modelList.first.id,
          fields: ['new remote', 'downloaded collection'],
        );
        remoteNote.id = localNote.id + 1;
        await remote.notes.insert(remoteNote);
        await remote.close();

        await mediaDirectory.create();
        await File('${mediaDirectory.path}/old.jpg').writeAsBytes([1]);
        final recovery = await AnkiFullDownloadRecovery.begin(
          documentsPath: documents.path,
          destinationIdentity: client.destinationIdentity,
        );
        final reset = await AnkiMediaSync.prepareForFullDownload(
          client: client,
          documentsPath: documents.path,
          recovery: recovery,
        );
        expect(await otherIndex.exists(), isFalse);
        await File('${documents.path}/collection.anki2')
            .copy(recovery.collectionBackupPath!);
        await recovery.markCollectionReplacementStarted();
        await File('${remoteDirectory.path}/collection.anki2')
            .copy('${documents.path}/collection.anki2');
        await File('${mediaDirectory.path}/new.jpg').writeAsBytes([2]);

        await recovery.commit();
        await reset.commit();
        expect(await otherIndex.exists(), isFalse);
        AnkiFullDownloadRecovery.simulateProcessRestartForTesting();

        final installed = AnkiDatabase(basePath: documents.path);
        await installed.open();
        expect(await installed.notes.get(remoteNote.id), isNotNull);
        expect(await installed.notes.get(localNote.id), isNull);
        expect(await File('${mediaDirectory.path}/new.jpg').readAsBytes(), [2]);
        expect(await File('${mediaDirectory.path}/old.jpg').exists(), isFalse);
        expect(
          await AnkiFullDownloadRecovery.hasPending(documents.path),
          isFalse,
        );
        await installed.close();
      } finally {
        client.close();
        await AnkiDatabase.closeOpenedInstance();
        await documents.delete(recursive: true);
      }
    },
  );
}

File _indexFile(String documentsPath, String identity) {
  final hash = sha256.convert(utf8.encode(identity));
  return File('$documentsPath/collection.media.sync.$hash.db');
}
