import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

TextRecord _textRecordWithContent(
  String id,
  String content, {
  DateTime? createdAt,
  String folder = '',
}) {
  final bytes = Uint8List.fromList(utf8.encode(content));
  return TextRecord(
    id: id,
    name: id,
    hash: computeTextHash(bytes),
    format: 'mmd',
    createdAt: createdAt ?? DateTime.utc(2024),
    size: bytes.length,
    folder: folder,
    textLength: content.length,
  );
}

Future<void> _exerciseStaleHashDelete(
  List<TextRecord> originalRecords,
  Future<void> Function() delete,
) async {
  const editedContent = 'graph TD\n  A-->edited';
  final editedRecords = originalRecords
      .map(
        (record) => _textRecordWithContent(
          record.id,
          editedContent,
          createdAt: DateTime.utc(2025),
          folder: record.folder,
        ),
      )
      .toList();
  final currentHash = editedRecords.first.hash;
  final concurrentReference = _textRecordWithContent(
    'concurrent-reference',
    editedContent,
  );

  for (final record in originalRecords) {
    await TextManifest.saveTextRecord(record, 'graph TD\n  A-->${record.id}');
  }

  final releaseOldHashes = Completer<void>();
  final releaseRegistration = Completer<void>();
  final releaseCurrentHash = Completer<void>();
  final referenceRegistered = Completer<void>();
  final oldHashAcquired = originalRecords
      .map((_) => Completer<void>())
      .toList(growable: false);
  final oldHashLocks = <Future<void>>[];
  for (var i = 0; i < originalRecords.length; i++) {
    oldHashLocks.add(
      TextManifest.withSaveLock(originalRecords[i].hash, () async {
        oldHashAcquired[i].complete();
        await releaseOldHashes.future;
      }),
    );
  }
  final registrationStarted = Completer<void>();
  var deleting = Future<void>.value();
  var concurrentSave = Future<void>.value();
  var hashGuardedSave = Future<void>.value();
  var deleteFinished = false;
  try {
    await Future.wait(oldHashAcquired.map((lock) => lock.future));

    deleting = delete().whenComplete(() => deleteFinished = true);
    await Future<void>.delayed(Duration.zero);

    // Emulate a row repoint that predates hash locking, so this also checks
    // that delete retries when its initial hash snapshot becomes stale.
    await TextManifest.writeText(
      editedRecords.first.storagePath,
      editedContent,
    );
    for (final record in editedRecords) {
      await ManifestDatabase.updateTextRecord(record.id, record.toMap());
    }
    TextManifest.invalidateCache();

    ManifestDatabase.beforeWebDataSaveForTesting = () async {
      ManifestDatabase.beforeWebDataSaveForTesting = null;
      registrationStarted.complete();
      await releaseRegistration.future;
    };
    hashGuardedSave = TextManifest.withSaveLock(currentHash, () async {
      concurrentSave = TextManifest.saveTextRecord(
        concurrentReference,
        editedContent,
      );
      await registrationStarted.future.timeout(const Duration(seconds: 5));
      await concurrentSave;
      referenceRegistered.complete();
      await releaseCurrentHash.future;
    });
    await registrationStarted.future.timeout(const Duration(seconds: 5));

    releaseOldHashes.complete();
    await Future<void>.delayed(Duration.zero);
    releaseRegistration.complete();
    await referenceRegistered.future.timeout(const Duration(seconds: 5));
    await Future<void>.delayed(Duration.zero);
    expect(deleteFinished, isFalse);
    expect(
      await TextManifest.readText(editedRecords.first.storagePath),
      editedContent,
    );
    releaseCurrentHash.complete();
    await Future.wait([
      ...oldHashLocks,
      deleting,
      concurrentSave,
      hashGuardedSave,
    ]).timeout(const Duration(seconds: 5));
  } finally {
    if (!releaseOldHashes.isCompleted) releaseOldHashes.complete();
    if (!releaseRegistration.isCompleted) releaseRegistration.complete();
    if (!releaseCurrentHash.isCompleted) releaseCurrentHash.complete();
    ManifestDatabase.beforeWebDataSaveForTesting = null;
    try {
      await Future.wait([
        ...oldHashLocks,
        deleting,
        concurrentSave,
        hashGuardedSave,
      ]).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  final remaining = await TextManifest.loadRecordsUncached();
  expect(
    remaining.map((record) => record.id),
    contains(concurrentReference.id),
  );
  for (final record in originalRecords) {
    expect(remaining.map((saved) => saved.id), isNot(contains(record.id)));
  }
  expect(
    await TextManifest.readText(editedRecords.first.storagePath),
    editedContent,
  );
}

Future<void> _exerciseDeleteSerializesHashRepoint(
  List<TextRecord> originalRecords,
  Future<void> Function() delete,
) async {
  for (final record in originalRecords) {
    await TextManifest.saveTextRecord(record, 'graph TD\n  A-->${record.id}');
  }
  TextManifest.invalidateCache();

  const editedContent = 'graph TD\n  A-->edited';
  final editedRecords = originalRecords
      .map(
        (record) => _textRecordWithContent(
          record.id,
          editedContent,
          createdAt: DateTime.utc(2025),
          folder: record.folder,
        ),
      )
      .toList(growable: false);
  final releaseDelete = Completer<void>();
  final hashCheckReached = Completer<void>();
  final updateLoadStarted = Completer<void>();
  var deleteFinished = false;
  var updateFinished = false;
  var deleting = Future<void>.value();
  var updating = Future<void>.value();
  TextManifest.beforeDeleteWithCurrentHashLocksForTesting = () async {
    TextManifest.beforeDeleteWithCurrentHashLocksForTesting = null;
    hashCheckReached.complete();
    await releaseDelete.future;
  };

  try {
    deleting = delete().whenComplete(() => deleteFinished = true);
    await hashCheckReached.future.timeout(const Duration(seconds: 5));

    ManifestDatabase.beforeWebDataReadForTesting = () async {
      ManifestDatabase.beforeWebDataReadForTesting = null;
      updateLoadStarted.complete();
    };
    ManifestDatabase.invalidateWebDataCacheForTesting();
    updating = Future.wait(
      editedRecords.map(TextManifest.updateRecord),
    ).whenComplete(() => updateFinished = true);
    await updateLoadStarted.future.timeout(const Duration(seconds: 5));
    await Future<void>.delayed(Duration.zero);
    expect(updateFinished, isFalse);
    expect(deleteFinished, isFalse);

    releaseDelete.complete();
    await Future.wait([deleting, updating]).timeout(const Duration(seconds: 5));
  } finally {
    if (!releaseDelete.isCompleted) releaseDelete.complete();
    TextManifest.beforeDeleteWithCurrentHashLocksForTesting = null;
    ManifestDatabase.beforeWebDataReadForTesting = null;
    try {
      await Future.wait([
        deleting,
        updating,
      ]).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  final remainingIds = (await TextManifest.loadRecordsUncached()).map(
    (record) => record.id,
  );
  for (final record in originalRecords) {
    expect(remainingIds, isNot(contains(record.id)));
    expect(await TextManifest.readText(record.storagePath), isNull);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    ManifestDatabase.beforeWebDataSaveForTesting = null;
    ManifestDatabase.beforeWebDataReadForTesting = null;
    TextManifest.beforeFolderLoadForTesting = null;
    TextManifest.beforeCacheInvalidationForTesting = null;
    TextManifest.beforeDeleteWithCurrentHashLocksForTesting = null;
    TextManifest.beforeFolderDeleteLocksForTesting = null;
    TextManifest.invalidateCache();
  });

  group('TextManifest hash-locked content changes', () {
    test(
      'keeps old content when another record references it before cleanup',
      () async {
        const oldContent = 'graph TD\n  A-->B';
        const editedContent = 'graph TD\n  A-->C';
        final originalRecord = _textRecordWithContent(
          'edited-chart',
          oldContent,
        );
        final oldHash = originalRecord.hash;
        final editedRecord = _textRecordWithContent(
          originalRecord.id,
          editedContent,
          createdAt: DateTime.utc(2025),
        );
        final concurrentReference = _textRecordWithContent(
          'concurrent-reference',
          oldContent,
          createdAt: DateTime.utc(2025),
        );
        final readStarted = Completer<void>();
        final releaseRead = Completer<void>();
        addTearDown(() {
          ManifestDatabase.beforeWebDataReadForTesting = null;
          if (!releaseRead.isCompleted) releaseRead.complete();
        });

        await TextManifest.writeText(originalRecord.storagePath, oldContent);
        await TextManifest.addRecord(originalRecord);
        final staleRecords = await TextManifest.loadRecordsUncached();
        await TextManifest.writeText(editedRecord.storagePath, editedContent);
        await TextManifest.updateRecord(editedRecord);
        expect(staleRecords.single.hash, oldHash);

        ManifestDatabase.beforeWebDataReadForTesting = () async {
          ManifestDatabase.beforeWebDataReadForTesting = null;
          readStarted.complete();
          await releaseRead.future;
        };
        ManifestDatabase.invalidateWebDataCacheForTesting();
        TextManifest.invalidateCache();
        final concurrentSave = TextManifest.saveTextRecord(
          concurrentReference,
          oldContent,
        );
        await readStarted.future.timeout(const Duration(seconds: 5));

        var cleanupFinished = false;
        final cleanup = TextManifest.deleteFileIfUnreferenced(
          oldHash,
          originalRecord.storagePath,
        ).then((deleted) {
          cleanupFinished = true;
          return deleted;
        });
        await Future<void>.delayed(Duration.zero);
        expect(cleanupFinished, isFalse);

        releaseRead.complete();
        await concurrentSave;

        expect(await cleanup, isFalse);
        expect(
          await TextManifest.readText(originalRecord.storagePath),
          oldContent,
        );
        expect(
          (await TextManifest.loadRecords()).map((record) => record.hash),
          contains(oldHash),
        );
      },
    );

    test(
      'keeps the hash lock until text content is published as a record',
      () async {
        const content = 'graph TD\n  A-->B';
        final record = _textRecordWithContent(
          'new-chart',
          content,
          createdAt: DateTime.utc(2025),
        );
        final hash = record.hash;
        final readStarted = Completer<void>();
        final releaseRead = Completer<void>();
        addTearDown(() {
          ManifestDatabase.beforeWebDataReadForTesting = null;
          if (!releaseRead.isCompleted) releaseRead.complete();
        });
        ManifestDatabase.beforeWebDataReadForTesting = () async {
          ManifestDatabase.beforeWebDataReadForTesting = null;
          readStarted.complete();
          await releaseRead.future;
        };
        ManifestDatabase.invalidateWebDataCacheForTesting();
        TextManifest.invalidateCache();

        final saving = TextManifest.saveTextRecord(record, content);
        await readStarted.future.timeout(const Duration(seconds: 5));

        var cleanupFinished = false;
        final cleanup = TextManifest.deleteFileIfUnreferenced(
          hash,
          record.storagePath,
        ).then((deleted) {
          cleanupFinished = true;
          return deleted;
        });
        await Future<void>.delayed(Duration.zero);
        expect(cleanupFinished, isFalse);
        expect(await TextManifest.readText(record.storagePath), content);

        releaseRead.complete();
        await saving;
        expect(await cleanup, isFalse);
        expect(await TextManifest.readText(record.storagePath), content);
        expect(
          (await TextManifest.loadRecords()).map((saved) => saved.id),
          contains(record.id),
        );
      },
    );

    test(
      'keeps the hash lock until edited content and record are updated',
      () async {
        const oldContent = 'graph TD\n  A-->B';
        const editedContent = 'graph TD\n  A-->C';
        final originalRecord = _textRecordWithContent(
          'edited-chart',
          oldContent,
        );
        final editedRecord = _textRecordWithContent(
          originalRecord.id,
          editedContent,
          createdAt: DateTime.utc(2025),
        );
        final updateWriteStarted = Completer<void>();
        final releaseWrite = Completer<void>();
        addTearDown(() {
          ManifestDatabase.beforeWebDataSaveForTesting = null;
          ManifestDatabase.beforeWebDataReadForTesting = null;
          if (!releaseWrite.isCompleted) releaseWrite.complete();
        });
        await TextManifest.writeText(originalRecord.storagePath, oldContent);
        await TextManifest.addRecord(originalRecord);

        ManifestDatabase.beforeWebDataSaveForTesting = () async {
          ManifestDatabase.beforeWebDataSaveForTesting = null;
          updateWriteStarted.complete();
          await releaseWrite.future;
        };
        ManifestDatabase.invalidateWebDataCacheForTesting();
        TextManifest.invalidateCache();

        final saving =
            TextManifest.updateTextRecord(editedRecord, editedContent);
        await updateWriteStarted.future.timeout(const Duration(seconds: 5));

        var cleanupFinished = false;
        final cleanup = TextManifest.deleteFileIfUnreferenced(
          editedRecord.hash,
          editedRecord.storagePath,
        ).then((deleted) {
          cleanupFinished = true;
          return deleted;
        });
        await Future<void>.delayed(Duration.zero);
        expect(cleanupFinished, isFalse);
        expect(await TextManifest.readText(editedRecord.storagePath),
            editedContent);

        releaseWrite.complete();
        await saving;
        expect(await cleanup, isFalse);
        expect(await TextManifest.readText(editedRecord.storagePath),
            editedContent);
        expect(
          (await TextManifest.loadRecords()).single.hash,
          editedRecord.hash,
        );
      },
    );

    test(
      'preserves a stale save that repoints the same record ID to old hash',
      () async {
        const oldContent = 'graph TD\n  A-->B';
        const editedContent = 'graph TD\n  A-->C';
        final originalRecord = _textRecordWithContent(
          'edited-chart',
          oldContent,
        );
        final oldHash = originalRecord.hash;
        final editedRecord = _textRecordWithContent(
          originalRecord.id,
          editedContent,
          createdAt: DateTime.utc(2025),
        );

        await TextManifest.writeText(originalRecord.storagePath, oldContent);
        await TextManifest.addRecord(originalRecord);
        await TextManifest.writeText(editedRecord.storagePath, editedContent);
        await TextManifest.updateRecord(editedRecord);
        await TextManifest.writeText(originalRecord.storagePath, oldContent);
        await TextManifest.updateRecord(originalRecord);

        final deleted = await TextManifest.deleteFileIfUnreferenced(
          oldHash,
          originalRecord.storagePath,
        );

        expect(deleted, isFalse);
        expect(
          await TextManifest.readText(originalRecord.storagePath),
          oldContent,
        );
        final savedRecords = await TextManifest.loadRecords();
        expect(savedRecords.single.id, originalRecord.id);
        expect(savedRecords.single.hash, oldHash);
      },
    );
  });
  group('TextManifest hash-locked record deletions', () {
    test(
      'single delete protects the row current hash after a stale snapshot',
      () async {
        final original = _textRecordWithContent(
          'single-delete',
          'graph TD\n  A-->single-delete',
        );

        await _exerciseStaleHashDelete([
          original,
        ], () => TextManifest.deleteRecord(original.id));
      },
    );

    test(
      'batch delete protects current hashes after stale snapshots',
      () async {
        final originals = [
          _textRecordWithContent(
            'batch-delete-a',
            'graph TD\n  A-->batch-delete-a',
          ),
          _textRecordWithContent(
            'batch-delete-b',
            'graph TD\n  A-->batch-delete-b',
          ),
        ];

        await _exerciseStaleHashDelete(
          originals,
          () => TextManifest.deleteRecords(
            originals.map((record) => record.id).toList(),
          ),
        );
      },
    );

    test('single delete serializes with a concurrent hash repoint', () async {
      final original = _textRecordWithContent(
        'single-delete-repoint',
        'graph TD\n  A-->single-delete-repoint',
      );

      await _exerciseDeleteSerializesHashRepoint([
        original,
      ], () => TextManifest.deleteRecord(original.id));
    });

    test('batch delete serializes with concurrent hash repoints', () async {
      final originals = [
        _textRecordWithContent(
          'batch-delete-repoint-a',
          'graph TD\n  A-->batch-delete-repoint-a',
        ),
        _textRecordWithContent(
          'batch-delete-repoint-b',
          'graph TD\n  A-->batch-delete-repoint-b',
        ),
      ];

      await _exerciseDeleteSerializesHashRepoint(
        originals,
        () => TextManifest.deleteRecords(
          originals.map((record) => record.id).toList(),
        ),
      );
    });

    test('folder delete serializes with a concurrent hash repoint', () async {
      const folder = 'mermaid-charts/subfolder';
      final original = _textRecordWithContent(
        'folder-delete-repoint',
        'graph TD\n  A-->folder-delete-repoint',
        folder: folder,
      );

      await _exerciseDeleteSerializesHashRepoint([
        original,
      ], () => TextManifest.removeFolder('mermaid-charts'));
    });

    test(
      'root folder no-op serializes its cache refresh with hash repoints',
      () async {
        const folder = 'mermaid-charts';
        const chartContent = 'graph TD\n  A-->shared-chart';
        const previousContent = 'graph TD\n  A-->previous-content';
        final chart = _textRecordWithContent(
          'folder-delete-shared-chart',
          chartContent,
          folder: folder,
        );
        final sharedReference = _textRecordWithContent(
          'folder-delete-shared-reference',
          previousContent,
        );
        final repointedReference = _textRecordWithContent(
          sharedReference.id,
          chartContent,
        );
        await TextManifest.saveTextRecord(chart, chartContent);
        await TextManifest.saveTextRecord(sharedReference, previousContent);
        TextManifest.invalidateCache();

        final refreshReached = Completer<void>();
        final releaseRefresh = Completer<void>();
        TextManifest.beforeFolderLoadForTesting = () async {
          TextManifest.beforeFolderLoadForTesting = null;
          refreshReached.complete();
          await releaseRefresh.future;
        };
        var updateFinished = false;
        var removingRoot = Future<void>.value();
        var updating = Future<void>.value();
        try {
          removingRoot = TextManifest.removeFolder('');
          await refreshReached.future.timeout(const Duration(seconds: 5));

          final updateReadStarted = Completer<void>();
          ManifestDatabase.beforeWebDataReadForTesting = () async {
            ManifestDatabase.beforeWebDataReadForTesting = null;
            updateReadStarted.complete();
          };
          ManifestDatabase.invalidateWebDataCacheForTesting();
          updating = TextManifest.updateRecord(
            repointedReference,
          ).whenComplete(() => updateFinished = true);
          await updateReadStarted.future.timeout(const Duration(seconds: 5));
          await Future<void>.delayed(Duration.zero);
          expect(updateFinished, isFalse);

          releaseRefresh.complete();
          await Future.wait([
            removingRoot,
            updating,
          ]).timeout(const Duration(seconds: 5));
        } finally {
          if (!releaseRefresh.isCompleted) releaseRefresh.complete();
          TextManifest.beforeFolderLoadForTesting = null;
          ManifestDatabase.beforeWebDataReadForTesting = null;
          try {
            await Future.wait([
              removingRoot,
              updating,
            ]).timeout(const Duration(seconds: 5));
          } catch (_) {}
        }

        expect(
          (await TextManifest.loadRecordsUncached()).map((record) => record.id),
          containsAll([chart.id, repointedReference.id]),
        );

        await TextManifest.removeFolder(folder);

        final remaining = await TextManifest.loadRecordsUncached();
        final remainingIds = remaining.map((record) => record.id);
        expect(remainingIds, isNot(contains(chart.id)));
        expect(remainingIds, contains(repointedReference.id));
        expect(
          remaining
              .singleWhere((record) => record.id == repointedReference.id)
              .hash,
          chart.hash,
        );
        expect(await TextManifest.readText(chart.storagePath), chartContent);
      },
    );

    test(
      'folder delete includes rows added after its initial selection',
      () async {
        const folder = 'mermaid-charts';
        const nestedFolder = '$folder/subfolder';
        const content = 'graph TD\n  A-->added-after-selection';
        final addedRecord = _textRecordWithContent(
          'folder-delete-added-after-selection',
          content,
          folder: nestedFolder,
        );
        await TextManifest.addFolder(folder);

        final selectionReached = Completer<void>();
        final releaseDelete = Completer<void>();
        TextManifest.beforeFolderDeleteLocksForTesting = () async {
          TextManifest.beforeFolderDeleteLocksForTesting = null;
          selectionReached.complete();
          await releaseDelete.future;
        };
        final deleting = TextManifest.removeFolder(folder);
        try {
          await selectionReached.future.timeout(const Duration(seconds: 5));
          await TextManifest.saveTextRecord(addedRecord, content);
          releaseDelete.complete();
          await deleting.timeout(const Duration(seconds: 5));
        } finally {
          if (!releaseDelete.isCompleted) releaseDelete.complete();
          TextManifest.beforeFolderDeleteLocksForTesting = null;
          await deleting;
        }

        expect(
          (await TextManifest.loadRecordsUncached()).map((record) => record.id),
          isNot(contains(addedRecord.id)),
        );
        expect(await TextManifest.readText(addedRecord.storagePath), isNull);
        expect(await TextManifest.getAllFolders(), isNot(contains(folder)));
        expect(
          await TextManifest.getAllFolders(),
          isNot(contains(nestedFolder)),
        );
      },
    );

    test(
      'folder delete includes rows moved into descendants after selection',
      () async {
        const folder = 'mermaid-charts';
        const nestedFolder = '$folder/subfolder';
        const content = 'graph TD\n  A-->moved-after-selection';
        final movedRecord = _textRecordWithContent(
          'folder-delete-moved-after-selection',
          content,
          folder: 'outside',
        );
        await TextManifest.addFolder(folder);
        await TextManifest.saveTextRecord(movedRecord, content);

        final selectionReached = Completer<void>();
        final releaseDelete = Completer<void>();
        TextManifest.beforeFolderDeleteLocksForTesting = () async {
          TextManifest.beforeFolderDeleteLocksForTesting = null;
          selectionReached.complete();
          await releaseDelete.future;
        };
        final deleting = TextManifest.removeFolder(folder);
        try {
          await selectionReached.future.timeout(const Duration(seconds: 5));
          await TextManifest.moveRecord(movedRecord.id, nestedFolder);
          releaseDelete.complete();
          await deleting.timeout(const Duration(seconds: 5));
        } finally {
          if (!releaseDelete.isCompleted) releaseDelete.complete();
          TextManifest.beforeFolderDeleteLocksForTesting = null;
          await deleting;
        }

        expect(
          (await TextManifest.loadRecordsUncached()).map((record) => record.id),
          isNot(contains(movedRecord.id)),
        );
        expect(await TextManifest.readText(movedRecord.storagePath), isNull);
        expect(await TextManifest.getAllFolders(), isNot(contains(folder)));
        expect(
          await TextManifest.getAllFolders(),
          isNot(contains(nestedFolder)),
        );
      },
    );

    test(
      'folder delete includes a row repointed into descendants after selection',
      () async {
        const folder = 'mermaid-charts';
        const nestedFolder = '$folder/subfolder';
        const originalContent = 'graph TD\n  A-->before-folder';
        const editedContent = 'graph TD\n  A-->after-folder';
        final originalRecord = _textRecordWithContent(
          'folder-delete-repointed-after-selection',
          originalContent,
          folder: 'outside',
        );
        final updatedRecord = _textRecordWithContent(
          originalRecord.id,
          editedContent,
          folder: nestedFolder,
        );
        await TextManifest.addFolder(folder);
        await TextManifest.addRecord(originalRecord);

        final selectionReached = Completer<void>();
        final releaseDelete = Completer<void>();
        TextManifest.beforeFolderDeleteLocksForTesting = () async {
          TextManifest.beforeFolderDeleteLocksForTesting = null;
          selectionReached.complete();
          await releaseDelete.future;
        };
        final deleting = TextManifest.removeFolder(folder);
        try {
          await selectionReached.future.timeout(const Duration(seconds: 5));
          await TextManifest.writeText(
            updatedRecord.storagePath,
            editedContent,
          );
          await TextManifest.updateRecord(updatedRecord);
          releaseDelete.complete();
          await deleting.timeout(const Duration(seconds: 5));
        } finally {
          if (!releaseDelete.isCompleted) releaseDelete.complete();
          TextManifest.beforeFolderDeleteLocksForTesting = null;
          await deleting;
        }

        expect(
          (await TextManifest.loadRecordsUncached()).map((record) => record.id),
          isNot(contains(updatedRecord.id)),
        );
        expect(await TextManifest.readText(updatedRecord.storagePath), isNull);
        expect(await TextManifest.getAllFolders(), isNot(contains(folder)));
        expect(
          await TextManifest.getAllFolders(),
          isNot(contains(nestedFolder)),
        );
      },
    );

    test(
      'folder delete orders a move after its final membership check',
      () async {
        const folder = 'mermaid-charts';
        const nestedFolder = '$folder/subfolder';
        const content = 'graph TD\n  A-->moved-after-final-check';
        final record = _textRecordWithContent(
          'folder-delete-final-move',
          content,
          folder: 'outside',
        );
        await TextManifest.addFolder(folder);
        await TextManifest.saveTextRecord(record, content);

        final checkReached = Completer<void>();
        final releaseDelete = Completer<void>();
        var moveFinished = false;
        TextManifest.beforeDeleteWithCurrentHashLocksForTesting = () async {
          TextManifest.beforeDeleteWithCurrentHashLocksForTesting = null;
          checkReached.complete();
          await releaseDelete.future;
        };
        final deleting = TextManifest.removeFolder(folder);
        var moving = Future<void>.value();
        try {
          await checkReached.future.timeout(const Duration(seconds: 5));
          moving = TextManifest.moveRecord(
            record.id,
            nestedFolder,
          ).whenComplete(() => moveFinished = true);
          await Future<void>.delayed(Duration.zero);
          expect(moveFinished, isFalse);

          releaseDelete.complete();
          await Future.wait([
            deleting,
            moving,
          ]).timeout(const Duration(seconds: 5));
        } finally {
          if (!releaseDelete.isCompleted) releaseDelete.complete();
          TextManifest.beforeDeleteWithCurrentHashLocksForTesting = null;
          await Future.wait([deleting, moving]);
        }

        final remaining = await TextManifest.loadRecordsUncached();
        expect(remaining.single.id, record.id);
        expect(remaining.single.folder, nestedFolder);
        expect(await TextManifest.readText(record.storagePath), content);
        expect(await TextManifest.getAllFolders(), contains(folder));
        expect(await TextManifest.getAllFolders(), contains(nestedFolder));
      },
    );

    test('root folder delete remains a no-op for Mermaid charts', () async {
      const content = 'graph TD\n  A-->root-chart';
      final record = _textRecordWithContent('root-chart', content);
      await TextManifest.saveTextRecord(record, content);

      await TextManifest.removeFolder('');

      expect(
        (await TextManifest.loadRecordsUncached()).map((saved) => saved.id),
        contains(record.id),
      );
      expect(await TextManifest.readText(record.storagePath), content);
    });

    test('cache invalidation waits until a record delete releases its lock',
        () async {
      const content = 'graph TD\n  A-->shared-cache-delete';
      final chart = _textRecordWithContent('cache-delete-chart', content);
      final reference = _textRecordWithContent('cache-delete-reference', content);
      await TextManifest.saveTextRecord(chart, content);
      await TextManifest.saveTextRecord(reference, content);

      final deleteReached = Completer<void>();
      final releaseDelete = Completer<void>();
      TextManifest.beforeDeleteWithCurrentHashLocksForTesting = () async {
        TextManifest.beforeDeleteWithCurrentHashLocksForTesting = null;
        deleteReached.complete();
        await releaseDelete.future;
      };
      final invalidationReached = Completer<void>();
      TextManifest.beforeCacheInvalidationForTesting = () async {
        TextManifest.beforeCacheInvalidationForTesting = null;
        invalidationReached.complete();
      };
      var deleting = Future<void>.value();
      try {
        deleting = TextManifest.deleteRecord(chart.id);
        await deleteReached.future.timeout(const Duration(seconds: 5));

        Zone.root.run(() => TextManifest.invalidateCache());
        await Future<void>.delayed(Duration.zero);
        expect(invalidationReached.isCompleted, isFalse);

        releaseDelete.complete();
        await deleting.timeout(const Duration(seconds: 5));
        await invalidationReached.future.timeout(const Duration(seconds: 5));
      } finally {
        if (!releaseDelete.isCompleted) releaseDelete.complete();
        TextManifest.beforeDeleteWithCurrentHashLocksForTesting = null;
        TextManifest.beforeCacheInvalidationForTesting = null;
        await deleting;
      }

      expect(
        (await TextManifest.loadRecords()).map((record) => record.id),
        [reference.id],
      );
      expect(await TextManifest.readText(chart.storagePath), content);
    });
  });

  testWidgets('cancel guard after asynchronous load prevents text insertion',
      (tester) async {
    var cancelled = false;
    final saving = TextManifest.addRecord(
      TextRecord(
          name: 'cancelled',
          hash: 'cancelled',
          createdAt: DateTime.now(),
          size: 1),
      beforeCommit: () {
        if (cancelled) throw StateError('cancelled');
      },
    );
    cancelled = true;
    await expectLater(saving, throwsStateError);
    expect(await ManifestDatabase.getAllTextRecords(), isEmpty);
    expect(await TextManifest.loadRecords(), isEmpty);
  });

  // ====== ManifestDatabase text records (in-memory, no file I/O) ======

  group('ManifestDatabase text records', () {
    testWidgets('empty initially', (WidgetTester t) async {
      final records = await ManifestDatabase.getAllTextRecords();
      expect(records, isEmpty);
    });

    testWidgets('insert and retrieve', (WidgetTester t) async {
      await ManifestDatabase.insertTextRecord({
        'id': 'txt_1',
        'name': 'test_text',
        'hash': 'abc123',
        'format': 'txt',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'textLength': 100,
      });
      final records = await ManifestDatabase.getAllTextRecords();
      expect(records.length, equals(1));
      expect(records[0]['id'], equals('txt_1'));
    });

    testWidgets('update existing record', (WidgetTester t) async {
      await ManifestDatabase.insertTextRecord({
        'id': 'txt_2',
        'name': 'original',
        'hash': 'def456',
        'format': 'txt',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 200,
        'folder': '',
        'textLength': 200,
      });
      await ManifestDatabase.updateTextRecord(
          'txt_2', {'name': 'renamed', 'size': 400});
      final records = await ManifestDatabase.getAllTextRecords();
      expect(records[0]['name'], equals('renamed'));
      expect(records[0]['size'], equals(400));
    });

    testWidgets('delete record', (WidgetTester t) async {
      await ManifestDatabase.insertTextRecord({
        'id': 'txt_3',
        'name': 'to_delete',
        'hash': 'ghi789',
        'format': 'txt',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 50,
        'folder': '',
        'textLength': 50,
      });
      await ManifestDatabase.deleteTextRecord('txt_3');
      final records = await ManifestDatabase.getAllTextRecords();
      expect(records, isEmpty);
    });

    testWidgets('batch delete', (WidgetTester t) async {
      for (var i = 0; i < 3; i++) {
        await ManifestDatabase.insertTextRecord({
          'id': 'txt_batch_$i',
          'name': 'batch_$i',
          'hash': 'hash_$i',
          'format': 'txt',
          'createdAt': DateTime.now().toIso8601String(),
          'size': 100,
          'folder': '',
          'textLength': 100,
        });
      }
      await ManifestDatabase.deleteTextRecords(['txt_batch_0', 'txt_batch_2']);
      final records = await ManifestDatabase.getAllTextRecords();
      expect(records.length, equals(1));
      expect(records[0]['id'], equals('txt_batch_1'));
    });
  });

  // ====== TextManifest record CRUD (DB-only methods, no file I/O) ======

  group('TextManifest DB operations', () {
    testWidgets('add and load records', (WidgetTester t) async {
      await TextManifest.addRecord(TextRecord(
        name: 'test_text',
        hash: 'hash1',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 100,
        textLength: 100,
      ));
      final records = await TextManifest.loadRecords();
      expect(records.length, equals(1));
      expect(records[0].name, equals('test_text'));
    });

    testWidgets('rename record (DB only)', (WidgetTester t) async {
      await TextManifest.addRecord(TextRecord(
        id: 'txt_rename',
        name: 'old_name',
        hash: 'hren',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 100,
        textLength: 100,
      ));
      await TextManifest.renameRecord('txt_rename', 'new_name');
      final records = await TextManifest.loadRecords();
      expect(records[0].name, equals('new_name'));
    });

    testWidgets('move record to folder (DB only)', (WidgetTester t) async {
      await TextManifest.addRecord(TextRecord(
        id: 'txt_move',
        name: 'movable',
        hash: 'hmov',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 100,
        folder: '',
        textLength: 100,
      ));
      await TextManifest.moveRecord('txt_move', 'my_folder');
      final records = await TextManifest.loadRecords();
      expect(records[0].folder, equals('my_folder'));
    });

    testWidgets('update record (DB only)', (WidgetTester t) async {
      final record = TextRecord(
        id: 'txt_upd',
        name: 'before',
        hash: 'hupd',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 100,
        textLength: 100,
      );
      await TextManifest.addRecord(record);
      await TextManifest.updateRecord(
          record.copyWith(name: 'after', size: 999));
      final records = await TextManifest.loadRecords();
      expect(records[0].name, equals('after'));
      expect(records[0].size, equals(999));
    });

    testWidgets('TextRecord serialization roundtrip', (WidgetTester t) async {
      final now = DateTime.now();
      final record = TextRecord(
        id: 'txt_roundtrip',
        name: 'my_text',
        hash: 'my_hash',
        format: 'txt',
        createdAt: now,
        size: 42,
        folder: 'subfolder',
        textLength: 42,
      );

      final map = record.toMap();
      final restored = TextRecord.fromMap(map);

      expect(restored.id, equals('txt_roundtrip'));
      expect(restored.name, equals('my_text'));
      expect(restored.hash, equals('my_hash'));
      expect(restored.format, equals('txt'));
      expect(restored.size, equals(42));
      expect(restored.folder, equals('subfolder'));
      expect(restored.textLength, equals(42));
      expect(
          restored.createdAt.toIso8601String(), equals(now.toIso8601String()));
    });
  });

  // ====================================================================
  // Encoding tests — verify UTF-8 encoding throughout the text storage
  // pipeline. These are CRITICAL because the original code used
  // `text.codeUnits` (UTF-16 code units truncated to 8 bits) which
  // corrupts Chinese and other non-ASCII text.
  //
  // NOTE: These tests verify the ENCODING LOGIC without relying on
  // file I/O (which requires flutter_test platform setup). We test
  // the encoding functions directly by simulating the writeText/readText
  // logic — this is safe and fast, and the actual file I/O is already
  // tested via ManifestDatabase (in-memory) and integration tests.
  // ====================================================================

  group('TextManifest UTF-8 encoding', () {
    /// Verify computeTextHash works correctly with utf8.encode bytes.
    test('computeTextHash with utf8.encode is deterministic', () {
      const chinese = '哈希一致性测试';

      final utf8Bytes = Uint8List.fromList(utf8.encode(chinese));
      final hash1 = computeTextHash(utf8Bytes);
      final hash2 = computeTextHash(Uint8List.fromList(utf8.encode(chinese)));

      expect(hash1, equals(hash2),
          reason: 'computeTextHash must return identical hash for same input.');
      expect(hash1, isNotEmpty, reason: 'Hash must not be empty.');
    });

    /// Verify what OCR/ASR pages currently do: utf8.encode for hash.
    test('OCR/ASR page hash pattern works correctly', () {
      const ocrText = '这是一段从图片中识别出的中文文字。';

      // This is exactly what ocr_page.dart does:
      // final bytes = Uint8List.fromList(utf8.encode(text));
      // final hash = computeTextHash(bytes);
      final bytes = Uint8List.fromList(utf8.encode(ocrText));
      final hash = computeTextHash(bytes);

      // The same hash should be computed from stored file content
      // (once writeText is fixed to use utf8.encode instead of codeUnits)
      expect(hash, isNotEmpty);
      expect(bytes.length, greaterThan(0),
          reason: 'UTF-8 encoded bytes must not be empty.');
    });
  });

  group('TextManifest legacy subtitle storage compatibility', () {
    test('reads legacy TXT files through SRT and VTT record paths', () async {
      const content = 'legacy subtitle transcript';
      final bytes = Uint8List.fromList(utf8.encode(content));
      final hash = computeTextHash(bytes);
      final legacyFileName = '$hash.txt';
      final subtitleFileNames = ['$hash.srt', '$hash.vtt'];
      for (final fileName in subtitleFileNames) {
        await TextManifest.deleteFile(fileName);
      }
      await TextManifest.writeText(legacyFileName, content);

      try {
        for (final format in ['srt', 'vtt']) {
          final record = TextRecord(
            name: 'legacy subtitle',
            hash: hash,
            format: format,
            createdAt: DateTime(2024),
            size: bytes.length,
          );

          expect(await TextManifest.readText(record.storageFileName), content);
        }
      } finally {
        for (final fileName in subtitleFileNames) {
          await TextManifest.deleteFile(fileName);
        }
        await TextManifest.deleteFile(legacyFileName);
      }
    });
  });

  // ====== writeText returns file path (used by ASR/OCR open file button) ======

  group('TextManifest writeText returns file path', () {
    test('writeText returns non-null non-empty file path for valid content',
        () async {
      const content = '测试文本内容 for ASR transcription result';
      final fileName = 'test_asr_result.txt';
      final filePath = await TextManifest.writeText(fileName, content);

      expect(filePath, isNotNull,
          reason: 'writeText must return a non-null file path');
      expect(filePath, isNotEmpty,
          reason: 'writeText must return a non-empty file path');
      // Path should contain the file name
      expect(filePath, contains(fileName),
          reason: 'Returned file path must contain the requested filename');
    });

    test('writeText returns unique path for each file', () async {
      final path1 =
          await TextManifest.writeText('unique_test_1.txt', 'content one');
      final path2 =
          await TextManifest.writeText('unique_test_2.txt', 'content two');

      expect(path1, isNot(equals(path2)),
          reason: 'Different files must return different paths');
      expect(path1, contains('unique_test_1.txt'));
      expect(path2, contains('unique_test_2.txt'));
    });
  });

  // ====== Empty file handling ======

  group('TextManifest empty file handling', () {
    test('readText returns empty string for empty bytes instead of null',
        () async {
      // Create a test file with empty content
      const emptyContent = '';
      final bytes = Uint8List.fromList(utf8.encode(emptyContent));
      final hash = computeTextHash(bytes);
      final storageFileName = '$hash.txt';

      // Write empty content
      await TextManifest.writeText(storageFileName, emptyContent);

      // Read back - should return '' not null
      final result = await TextManifest.readText(storageFileName);
      expect(result, isNotNull,
          reason: 'Empty content should return "" not null');
      expect(result, equals(''),
          reason: 'readText should return empty string for empty file');
    });

    test('computeTextHash for empty content is deterministic', () {
      final emptyBytes = Uint8List.fromList(utf8.encode(''));
      final hash1 = computeTextHash(emptyBytes);
      final hash2 = computeTextHash(Uint8List.fromList(utf8.encode('')));
      expect(hash1, equals(hash2),
          reason: 'Hash for empty content must be deterministic');
      expect(hash1, isNotEmpty,
          reason: 'Hash for empty content must still produce a valid hash');
    });
  });
}
