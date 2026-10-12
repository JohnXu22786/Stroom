import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/ocr_batch_execution.dart';
import 'package:stroom/pages/ocr/ocr_retry_snapshot.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/services/ocr_retry_storage.dart';
import 'package:stroom/utils/web_file_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory taskDirectory;

  setUp(() async {
    taskDirectory = await Directory.systemTemp.createTemp(
      'ocr_retry_storage_test_',
    );
    BackgroundTaskNotifier.debugStorageDirectoryOverride = taskDirectory.path;
    WebFileStore.enableTestMode();
  });

  tearDown(() async {
    BackgroundTaskNotifier.debugStorageDirectoryOverride = null;
    WebFileStore.disableTestMode();
    try {
      await taskDirectory.delete(recursive: true);
    } catch (_) {}
  });

  test('current snapshot stores execution settings and restores image bytes',
      () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final snapshot = OcrRetrySnapshot.capture(
      configId: 'config-1',
      modelId: 'model-1',
      images: [OcrRetryImage(bytes: bytes, format: 'png', name: 'scan.png')],
      instructionContent: 'receipt text',
      saveFolder: 'receipts',
      batchMode: OcrBatchMode.perImage,
      perImageConcurrency: 2,
      requestSizeBudgetBytes: 7 * 1024 * 1024,
    );

    final stored = await OcrRetryStorage.cacheSnapshot(
      taskId: 'task-1',
      snapshot: snapshot,
    );
    final imageMap = (stored['images'] as List).single as Map;
    final restored = await OcrRetryStorage.restoreImages(
      OcrRetrySnapshot.fromMap(stored),
    );

    expect(stored['version'], OcrRetrySnapshot.currentVersion);
    expect(imageMap.keys.toSet(), {'storageRef', 'format', 'name'});
    expect(imageMap['storageRef'], startsWith('ocr_retry_cache/'));
    expect(imageMap.containsKey('bytes'), isFalse);
    expect(restored.isComplete, isTrue);
    expect(restored.images.single.bytes, bytes);
    expect(stored['instructionContent'], 'receipt text');
    expect(stored['saveFolder'], 'receipts');
    expect(stored['batchMode'], OcrBatchMode.perImage.name);
    expect(stored['perImageConcurrency'], 2);
    expect(stored['requestSizeBudgetBytes'], 7 * 1024 * 1024);
  });

  test(
    'invalid supplied references cannot overwrite unrelated web files',
    () async {
      const unrelatedReference = 'attachments/keep.bin';
      final unrelatedBytes = Uint8List.fromList([9, 9, 9]);
      final imageBytes = Uint8List.fromList([1, 2, 3, 4]);
      await WebFileStore.write(unrelatedReference, unrelatedBytes);

      Map<String, dynamic>? stored;
      Object? failure;
      try {
        stored = await OcrRetryStorage.cacheSnapshot(
          taskId: 'invalid-reference-cache',
          snapshot: OcrRetrySnapshot.capture(
            images: [
              OcrRetryImage(
                bytes: imageBytes,
                storageRef: unrelatedReference,
                format: 'png',
              ),
            ],
          ),
        );
      } catch (error) {
        failure = error;
      }

      expect(await WebFileStore.read(unrelatedReference), unrelatedBytes);
      expect(failure, isNull);
      final reference =
          ((stored!['images'] as List).single as Map)['storageRef'] as String;

      expect(reference, startsWith('ocr_retry_cache/'));
      expect(await OcrRetryStorage.read(reference), imageBytes);
      expect(await WebFileStore.read(unrelatedReference), unrelatedBytes);
    },
  );

  test(
    'malformed cache format is inferred from readable bytes and keeps its reference',
    () async {
      final pngBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNgYGAAAAAEAAH2FzhVAAAAAElFTkSuQmCC',
      );
      final cached = await OcrRetryStorage.cacheSnapshot(
        taskId: 'malformed-format',
        snapshot: OcrRetrySnapshot.capture(
          images: [OcrRetryImage(bytes: pngBytes, format: 'png')],
        ),
      );
      final reference =
          ((cached['images'] as List).single as Map)['storageRef'] as String;
      for (final malformedImage in <Map<String, dynamic>>[
        {
          'storageRef': reference,
          'format': ['png'],
        },
        {'storageRef': reference},
      ]) {
        final malformed = <String, dynamic>{
          ...cached,
          'images': [malformedImage],
        };
        final snapshot = OcrRetrySnapshot.fromMap(malformed);

        expect(snapshot.needsMigration, isTrue);
        final restored = await OcrRetryStorage.restoreImages(snapshot);
        expect(restored.isComplete, isTrue);
        expect(restored.images.single.bytes, pngBytes);
        expect(restored.images.single.format, 'png');

        final migrated = await OcrRetryStorage.cacheSnapshot(
          taskId: 'malformed-format',
          snapshot: snapshot,
        );
        final migratedImage = (migrated['images'] as List).single as Map;
        expect(migratedImage['storageRef'], reference);
        expect(migratedImage['format'], 'png');
        expect(await OcrRetryStorage.read(reference), pngBytes);

        await OcrRetryStorage.cleanupUnreferencedCache(
          referenced: OcrRetryStorage.referencesFromSnapshot(migrated),
        );
        expect(await OcrRetryStorage.read(reference), pngBytes);
      }
    },
  );

  test(
    'legacy images with unknown bytes keep their cache ref without a guessed format',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      for (final metadata in <Map<String, dynamic>>[
        const {},
        {
          'format': ['png'],
        },
      ]) {
        final snapshot = OcrRetrySnapshot.fromMap({
          'type': 'ocr',
          'version': 1,
          'images': [
            {'bytes': base64Encode(bytes), ...metadata},
          ],
        });

        final legacyRestore = await OcrRetryStorage.restoreImages(snapshot);
        expect(legacyRestore.images.single.bytes, bytes);
        expect(legacyRestore.images.single.format, isEmpty);

        final cached = await OcrRetryStorage.cacheSnapshot(
          taskId: 'unknown-format-migration',
          snapshot: snapshot,
        );
        final image = (cached['images'] as List).single as Map;
        final reference = image['storageRef'] as String;
        expect(image['format'], '');

        final migratedRestore = await OcrRetryStorage.restoreImages(
          OcrRetrySnapshot.fromMap(cached),
        );
        expect(migratedRestore.images.single.bytes, bytes);
        expect(migratedRestore.images.single.format, isEmpty);
        expect(await OcrRetryStorage.read(reference), bytes);
      }
    },
  );

  test(
    'version 2 snapshot missing type migrates before cache cleanup',
    () async {
      final imageBytes = Uint8List.fromList([3, 1, 4, 1, 5]);
      final cached = await OcrRetryStorage.cacheSnapshot(
        taskId: 'missing-type-cache',
        snapshot: OcrRetrySnapshot.capture(
          images: [OcrRetryImage(bytes: imageBytes, format: 'png')],
        ),
      );
      final originalImage = (cached['images'] as List).single as Map;
      final reference = originalImage['storageRef'] as String;
      final version2 = Map<String, dynamic>.from(cached)
        ..['version'] = 2
        ..remove('batchMode')
        ..remove('perImageConcurrency')
        ..remove('requestSizeBudgetBytes');
      final missingType = version2..remove('type');
      final snapshot = OcrRetrySnapshot.fromMap(missingType);

      expect(snapshot.needsMigration, isTrue);

      final migrated = await OcrRetryStorage.cacheSnapshot(
        taskId: 'missing-type-cache',
        snapshot: snapshot,
      );
      expect(migrated['type'], 'ocr');
      expect(migrated['version'], OcrRetrySnapshot.currentVersion);
      expect(migrated['batchMode'], OcrBatchMode.joint.name);
      expect(migrated['perImageConcurrency'], 1);
      expect(
        migrated['requestSizeBudgetBytes'],
        defaultOcrRequestSizeBudgetBytes,
      );
      expect(
        ((migrated['images'] as List).single as Map)['storageRef'],
        reference,
      );

      await OcrRetryStorage.cleanupUnreferencedCache(
        referenced: OcrRetryStorage.referencesFromSnapshot(migrated),
      );
      expect(await OcrRetryStorage.read(reference), imageBytes);
    },
  );

  test(
    'legacy inline retries open and migrate without losing retry context',
    () async {
      final bytes = Uint8List.fromList([9, 8, 7]);
      final legacy = <String, dynamic>{
        'type': 'ocr',
        'version': 1,
        'modelRef': {'configId': 'old-config', 'modelId': 'old-model'},
        'images': [
          {
            'bytes': base64Encode(bytes),
            'format': 'jpeg',
            'name': 'legacy.jpg',
          },
        ],
        'instructionContent': 'saved prompt',
        'saveFolder': 'archive',
      };
      final snapshot = OcrRetrySnapshot.fromMap(legacy);
      final beforeMigration = await OcrRetryStorage.restoreImages(snapshot);
      final migrated = await OcrRetryStorage.cacheSnapshot(
        taskId: 'old-task',
        snapshot: snapshot,
      );
      final migratedSnapshot = OcrRetrySnapshot.fromMap(migrated);
      final afterMigration = await OcrRetryStorage.restoreImages(
        migratedSnapshot,
      );

      expect(snapshot.needsMigration, isTrue);
      expect(beforeMigration.isComplete, isTrue);
      expect(beforeMigration.images.single.bytes, bytes);
      expect(migrated['version'], OcrRetrySnapshot.currentVersion);
      expect(migratedSnapshot.configId, 'old-config');
      expect(migratedSnapshot.modelId, 'old-model');
      expect(migratedSnapshot.instructionContent, 'saved prompt');
      expect(migratedSnapshot.saveFolder, 'archive');
      expect(afterMigration.images.single.bytes, bytes);
    },
  );

  test('missing cache references report incomplete inputs', () async {
    final snapshot = OcrRetrySnapshot.fromMap({
      'type': 'ocr',
      'version': 2,
      'modelRef': {'configId': 'config-1', 'modelId': 'model-1'},
      'images': [
        {
          'storageRef':
              'ocr_retry_cache/ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff.bin',
          'format': 'png',
          'name': 'lost.png',
        },
      ],
    });

    final restored = await OcrRetryStorage.restoreImages(snapshot);

    expect(restored.isComplete, isFalse);
    expect(restored.missingImageCount, 1);
    expect(restored.images, isEmpty);
  });

  test(
    'orphan cleanup deletes only exact unreferenced OCR cache blobs',
    () async {
      final imageBytes = Uint8List.fromList([1, 2, 3]);
      final orphan = await OcrRetryStorage.cacheSnapshot(
        taskId: 'orphan-cache',
        snapshot: OcrRetrySnapshot.capture(
          images: [OcrRetryImage(bytes: imageBytes, format: 'png')],
        ),
      );
      final referenced = await OcrRetryStorage.cacheSnapshot(
        taskId: 'referenced-cache',
        snapshot: OcrRetrySnapshot.capture(
          images: [OcrRetryImage(bytes: imageBytes, format: 'png')],
        ),
      );
      final orphanReference =
          ((orphan['images'] as List).single as Map)['storageRef'] as String;
      final liveReference = ((referenced['images'] as List).single
          as Map)['storageRef'] as String;
      final unrelatedKey = 'unrelated/keep.bin';
      final malformedCacheKey = 'ocr_retry_cache/not-an-owned-blob.bin';
      await WebFileStore.write(unrelatedKey, Uint8List.fromList([4, 5, 6]));
      await WebFileStore.write(
        malformedCacheKey,
        Uint8List.fromList([7, 8, 9]),
      );

      await OcrRetryStorage.cleanupUnreferencedCache(
        referenced: {liveReference},
      );

      expect(await OcrRetryStorage.read(orphanReference), isNull);
      expect(await OcrRetryStorage.read(liveReference), imageBytes);
      expect(await WebFileStore.read(unrelatedKey), [4, 5, 6]);
      expect(await WebFileStore.read(malformedCacheKey), [7, 8, 9]);
    },
  );

  test(
    'unknown damaged image count is not replaced with a placeholder',
    () async {
      final snapshot = OcrRetrySnapshot.fromMap({
        'type': 'ocr',
        'version': 2,
        'modelRef': {'configId': 'config-1', 'modelId': 'model-1'},
        'images': 'damaged',
      });

      final migrated = await OcrRetryStorage.cacheSnapshot(
        taskId: 'unknown-count-task',
        snapshot: snapshot,
        allowIncompleteImages: true,
      );
      final restored = OcrRetrySnapshot.fromMap(migrated);
      final restoreResult = await OcrRetryStorage.restoreImages(restored);

      expect(snapshot.hasInvalidImages, isTrue);
      expect(snapshot.imageEntryCount, 0);
      expect(restored.imageEntryCount, 0);
      expect(restored.images, isEmpty);
      expect(restored.needsMigration, isFalse);
      expect(restoreResult.isComplete, isFalse);
      expect(restoreResult.missingImageCount, 0);
    },
  );

  test('migration preserves surviving cache reference identity', () async {
    final firstBytes = Uint8List.fromList([1, 2, 3]);
    final secondBytes = Uint8List.fromList([4, 5, 6]);
    final original = await OcrRetryStorage.cacheSnapshot(
      taskId: 'mixed-cache-identity',
      snapshot: OcrRetrySnapshot.capture(
        images: [
          OcrRetryImage(bytes: firstBytes, format: 'png'),
          OcrRetryImage(bytes: secondBytes, format: 'png'),
        ],
      ),
    );
    final originalImages = (original['images'] as List).cast<Map>();
    final survivingReference = originalImages[1]['storageRef'] as String;
    final damaged = OcrRetrySnapshot.fromMap({
      ...original,
      'images': [
        {'bytes': 'not-valid-base64!!!', 'format': 'png'},
        originalImages[1],
      ],
    });

    final migrated = await OcrRetryStorage.cacheSnapshot(
      taskId: 'mixed-cache-identity',
      snapshot: damaged,
      allowIncompleteImages: true,
    );
    final migratedImages = (migrated['images'] as List).cast<Map>();
    final references = OcrRetryStorage.referencesFromSnapshot(migrated);
    final restored = await OcrRetryStorage.restoreImages(
      OcrRetrySnapshot.fromMap(migrated),
    );

    expect(references, contains(survivingReference));
    expect(migratedImages, hasLength(2));
    expect(migratedImages[0]['storageRef'], isNot(survivingReference));
    expect(migratedImages[1]['storageRef'], survivingReference);
    expect(restored.images.single.bytes, secondBytes);

    final unavailable = OcrRetryStorage.unavailableSnapshot(
      taskId: 'mixed-cache-identity',
      snapshot: damaged,
    );
    final unavailableImages = (unavailable['images'] as List).cast<Map>();
    expect(unavailableImages, hasLength(2));
    expect(unavailableImages[0]['storageRef'], isNot(survivingReference));
    expect(unavailableImages[1]['storageRef'], survivingReference);

    await OcrRetryStorage.deleteUnreferenced(
      candidates: {survivingReference},
      referenced: references,
    );
    expect(await OcrRetryStorage.read(survivingReference), secondBytes);
    expect(
      (migrated['images'] as List).every(
        (image) => image is Map && !image.containsKey('bytes'),
      ),
      isTrue,
    );
    expect(jsonEncode(migrated), isNot(contains('not-valid-base64!!!')));
  });

  test(
    'valid inline image bytes survive an unusable cache reference',
    () async {
      final bytes = Uint8List.fromList([5, 4, 3, 2]);
      final encodedBytes = base64Encode(bytes);
      final snapshot = OcrRetrySnapshot.fromMap({
        'type': 'ocr',
        'version': 1,
        'images': [
          {
            'bytes': encodedBytes,
            'storageRef': '../stale-reference.bin',
            'format': 'png',
          },
        ],
      });

      expect(snapshot.hasInvalidImages, isFalse);
      expect(snapshot.images.single.bytes, bytes);
      expect(snapshot.images.single.storageRef, isNull);

      final migrated = await OcrRetryStorage.cacheSnapshot(
        taskId: 'inline-bytes-with-stale-reference',
        snapshot: snapshot,
      );
      final migratedSnapshot = OcrRetrySnapshot.fromMap(migrated);
      final restored = await OcrRetryStorage.restoreImages(migratedSnapshot);

      expect(restored.isComplete, isTrue);
      expect(restored.images.single.bytes, bytes);
      expect(
        migratedSnapshot.images.single.storageRef,
        startsWith('ocr_retry_cache/'),
      );
      expect(jsonEncode(migrated), isNot(contains(encodedBytes)));
      expect(jsonEncode(migrated), isNot(contains('../stale-reference.bin')));
    },
  );

  test('invalid inline bytes do not discard a valid cache reference', () async {
    final bytes = Uint8List.fromList([8, 7, 6]);
    final original = await OcrRetryStorage.cacheSnapshot(
      taskId: 'invalid-inline-with-valid-reference',
      snapshot: OcrRetrySnapshot.capture(
        images: [OcrRetryImage(bytes: bytes, format: 'png')],
      ),
    );
    final originalImage = (original['images'] as List).single as Map;
    final reference = originalImage['storageRef'] as String;
    final snapshot = OcrRetrySnapshot.fromMap({
      ...original,
      'images': [
        {...originalImage, 'bytes': 'not-base64!'},
      ],
    });

    expect(snapshot.hasInvalidImages, isFalse);
    expect(snapshot.hasInlineImageData, isTrue);
    expect(snapshot.needsMigration, isTrue);
    expect(snapshot.images.single.storageRef, reference);

    final migrated = await OcrRetryStorage.cacheSnapshot(
      taskId: 'invalid-inline-with-valid-reference',
      snapshot: snapshot,
    );
    final restored = await OcrRetryStorage.restoreImages(
      OcrRetrySnapshot.fromMap(migrated),
    );

    expect(restored.isComplete, isTrue);
    expect(restored.images.single.bytes, bytes);
    expect(jsonEncode(migrated), isNot(contains('not-base64!')));
    expect(jsonEncode(migrated), contains(reference));
  });

  test(
    'malformed cache paths migrate to unavailable owned references',
    () async {
      final snapshot = OcrRetrySnapshot.fromMap({
        'type': 'ocr',
        'version': 2,
        'modelRef': {'configId': 'config-1', 'modelId': 'model-1'},
        'images': [
          {'storageRef': '../outside.bin', 'format': 'png'},
        ],
      });

      final migrated = await OcrRetryStorage.cacheSnapshot(
        taskId: 'malformed-path-task',
        snapshot: snapshot,
        allowIncompleteImages: true,
      );
      final restored = OcrRetrySnapshot.fromMap(migrated);
      final image = (migrated['images'] as List).single as Map;

      expect(snapshot.hasInvalidImages, isTrue);
      expect(snapshot.needsMigration, isTrue);
      expect(restored.needsMigration, isFalse);
      expect(restored.imageEntryCount, 1);
      expect(image['storageRef'], startsWith('ocr_retry_cache/'));
      expect(
        await OcrRetryStorage.restoreImages(restored),
        isA<OcrRetryRestoreResult>().having(
          (result) => result.isComplete,
          'complete image set',
          isFalse,
        ),
      );
      expect(jsonEncode(migrated), isNot(contains('../outside.bin')));
      expect(jsonEncode(migrated), isNot(contains('bytes')));
    },
  );

  test(
    'restore migrates legacy images before unrelated task updates persist',
    () async {
      final bytes = Uint8List.fromList(List<int>.filled(160 * 1024, 0x5a));
      final legacySnapshot = <String, dynamic>{
        'type': 'ocr',
        'version': 1,
        'modelRef': {'configId': 'legacy-config', 'modelId': 'legacy-model'},
        'images': [
          {'bytes': base64Encode(bytes), 'format': 'png', 'name': 'legacy.png'},
        ],
      };
      final taskFile = File(
        '${taskDirectory.path}${Platform.pathSeparator}background${Platform.pathSeparator}tasks.json',
      );
      await taskFile.parent.create(recursive: true);
      await taskFile.writeAsString(
        jsonEncode([
          {
            'id': 'legacy-ocr',
            'type': 'ocr',
            'title': 'legacy OCR task',
            'status': 'completed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'steps': [],
            'retryData': legacySnapshot,
          },
          {
            'id': 'unrelated-task',
            'type': 'asr',
            'title': 'unrelated task',
            'status': 'waiting',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'steps': [
              {'label': 'step', 'status': 'pending'},
            ],
          },
        ]),
      );
      final notifier = BackgroundTaskNotifier();
      try {
        await notifier.restoreFromPersistence();
        final restored = notifier.state.singleWhere(
          (task) => task.id == 'legacy-ocr',
        );
        final migratedData = restored.retryData!;
        final migratedSnapshot = OcrRetrySnapshot.fromMap(migratedData);
        expect(migratedSnapshot.needsMigration, isFalse);
        expect(migratedSnapshot.images.single.bytes, isNull);
        expect(
          await OcrRetryStorage.restoreImages(migratedSnapshot),
          isA<OcrRetryRestoreResult>().having(
            (result) => result.images.single.bytes,
            'restored image bytes',
            bytes,
          ),
        );

        notifier.updateStep('unrelated-task', 0, completed: true);
        await notifier.pendingPersistence;
        final encoded = await taskFile.readAsString();
        expect(encoded, isNot(contains(base64Encode(bytes))));
        final persisted = (jsonDecode(encoded) as List)
            .cast<Map<String, dynamic>>()
            .singleWhere((task) => task['id'] == 'legacy-ocr');
        final image =
            ((persisted['retryData'] as Map)['images'] as List).single as Map;
        expect(image.keys.toSet(), {'storageRef', 'format', 'name'});
      } finally {
        notifier.dispose();
        await notifier.pendingPersistence;
      }
    },
  );

  test(
    'restore drops malformed legacy image bodies and keeps retry incomplete',
    () async {
      final bytes = Uint8List.fromList(List<int>.filled(64 * 1024, 0x5a));
      final encodedBytes = base64Encode(bytes);
      final malformedBytes = '$encodedBytes!!!';
      final legacySnapshot = <String, dynamic>{
        'type': 'ocr',
        'version': 1,
        'modelRef': {'configId': 'legacy-config', 'modelId': 'legacy-model'},
        'instructionContent': 'saved prompt',
        'images': [
          {'bytes': encodedBytes, 'format': 'png', 'name': 'valid.png'},
          {'bytes': malformedBytes, 'format': 'png', 'name': 'broken.png'},
        ],
      };
      final taskFile = File(
        '${taskDirectory.path}${Platform.pathSeparator}background${Platform.pathSeparator}tasks.json',
      );
      await taskFile.parent.create(recursive: true);
      await taskFile.writeAsString(
        jsonEncode([
          {
            'id': 'damaged-legacy-ocr',
            'type': 'ocr',
            'title': 'damaged legacy OCR task',
            'status': 'completed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'steps': [],
            'retryData': legacySnapshot,
          },
          {
            'id': 'unrelated-task',
            'type': 'asr',
            'title': 'unrelated task',
            'status': 'waiting',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'steps': [
              {'label': 'step', 'status': 'pending'},
            ],
          },
        ]),
      );
      final notifier = BackgroundTaskNotifier();
      try {
        await notifier.restoreFromPersistence();
        final restored = notifier.state.singleWhere(
          (task) => task.id == 'damaged-legacy-ocr',
        );
        final snapshot = OcrRetrySnapshot.fromMap(restored.retryData!);
        final images = await OcrRetryStorage.restoreImages(snapshot);
        expect(snapshot.needsMigration, isFalse);
        expect(snapshot.instructionContent, 'saved prompt');
        expect(images.images.single.bytes, bytes);
        expect(images.isComplete, isFalse);
        expect(images.missingImageCount, 1);

        notifier.updateStep('unrelated-task', 0, completed: true);
        await notifier.pendingPersistence;
        final persisted = await taskFile.readAsString();
        expect(persisted, isNot(contains(encodedBytes)));
        expect(persisted, isNot(contains(malformedBytes)));
      } finally {
        notifier.dispose();
        await notifier.pendingPersistence;
      }
    },
  );

  test(
    'restore migrates malformed version 2 entries before unrelated updates persist',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final encodedBytes = base64Encode(List<int>.filled(64 * 1024, 0x5a));
      final validSnapshot = await OcrRetryStorage.cacheSnapshot(
        taskId: 'mixed-v2-ocr',
        snapshot: OcrRetrySnapshot.capture(
          configId: 'config-1',
          modelId: 'model-1',
          images: [OcrRetryImage(bytes: bytes, format: 'png')],
          instructionContent: 'saved prompt',
        ),
      );
      final version2Snapshot = Map<String, dynamic>.from(validSnapshot)
        ..['version'] = 2
        ..remove('batchMode')
        ..remove('perImageConcurrency')
        ..remove('requestSizeBudgetBytes');
      final malformedSnapshot = <String, dynamic>{
        ...version2Snapshot,
        'images': [
          ...(validSnapshot['images'] as List),
          {'bytes': '$encodedBytes!!!', 'format': 'png'},
        ],
      };
      final taskFile = File(
        '${taskDirectory.path}${Platform.pathSeparator}background${Platform.pathSeparator}tasks.json',
      );
      await taskFile.parent.create(recursive: true);
      await taskFile.writeAsString(
        jsonEncode([
          {
            'id': 'mixed-v2-ocr',
            'type': 'ocr',
            'title': 'mixed v2 OCR task',
            'status': 'completed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'steps': [],
            'retryData': malformedSnapshot,
          },
          {
            'id': 'unrelated-task',
            'type': 'asr',
            'title': 'unrelated task',
            'status': 'waiting',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'steps': [
              {'label': 'step', 'status': 'pending'},
            ],
          },
        ]),
      );

      final notifier = BackgroundTaskNotifier();
      try {
        await notifier.restoreFromPersistence();
        final task = notifier.state.singleWhere(
          (candidate) => candidate.id == 'mixed-v2-ocr',
        );
        final snapshot = OcrRetrySnapshot.fromMap(task.retryData!);
        final images = await OcrRetryStorage.restoreImages(snapshot);
        expect(snapshot.hasInvalidImages, isFalse);
        expect(snapshot.imageEntryCount, 2);
        expect(snapshot.instructionContent, 'saved prompt');
        expect(images.images.single.bytes, bytes);
        expect(images.isComplete, isFalse);
        expect(images.missingImageCount, 1);

        notifier.updateStep('unrelated-task', 0, completed: true);
        await notifier.pendingPersistence;
        final persisted = await taskFile.readAsString();
        expect(persisted, isNot(contains(encodedBytes)));
      } finally {
        notifier.dispose();
        await notifier.pendingPersistence;
      }
    },
  );

  test(
    'failed malformed snapshot migration retains readable cache references',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final cached = await OcrRetryStorage.cacheSnapshot(
        taskId: 'mixed-v2-failure',
        snapshot: OcrRetrySnapshot.capture(
          configId: 'config-1',
          modelId: 'model-1',
          images: [OcrRetryImage(bytes: bytes, format: 'png')],
        ),
      );
      final readableImage = (cached['images'] as List).single as Map;
      final readableReference = readableImage['storageRef'] as String;
      final missingReference =
          'ocr_retry_cache/${List.filled(64, 'f').join()}.bin';
      final encodedMalformedBody = base64Encode(
        List<int>.filled(32 * 1024, 0x5a),
      );
      final malformedSnapshot = <String, dynamic>{
        ...cached,
        'images': [
          readableImage,
          OcrRetryImage.reference(
            storageRef: missingReference,
            format: 'png',
          ).toMap(),
          {'bytes': '$encodedMalformedBody!!!', 'format': 'png'},
        ],
      };
      final taskFile = File(
        '${taskDirectory.path}${Platform.pathSeparator}background${Platform.pathSeparator}tasks.json',
      );
      await taskFile.parent.create(recursive: true);
      await taskFile.writeAsString(
        jsonEncode([
          {
            'id': 'mixed-v2-failure',
            'type': 'ocr',
            'title': 'mixed OCR retry',
            'status': 'failed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'steps': [],
            'retryData': malformedSnapshot,
          },
          {
            'id': 'unrelated-task',
            'type': 'asr',
            'title': 'unrelated task',
            'status': 'waiting',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'steps': [
              {'label': 'step', 'status': 'pending'},
            ],
          },
        ]),
      );

      final notifier = BackgroundTaskNotifier();
      try {
        await notifier.restoreFromPersistence();
        final task = notifier.state.singleWhere(
          (candidate) => candidate.id == 'mixed-v2-failure',
        );
        final retryData = task.retryData!;
        final snapshot = OcrRetrySnapshot.fromMap(retryData);
        final references = OcrRetryStorage.referencesFromSnapshot(retryData);
        final restored = await OcrRetryStorage.restoreImages(snapshot);
        expect(references, contains(readableReference));
        expect(restored.images.single.bytes, bytes);
        expect(restored.isComplete, isFalse);
        expect(restored.missingImageCount, 2);
        expect(jsonEncode(retryData), isNot(contains(encodedMalformedBody)));

        notifier.updateStep('unrelated-task', 0, completed: true);
        await notifier.pendingPersistence;
        var persisted = await taskFile.readAsString();
        expect(persisted, contains(readableReference));
        expect(persisted, isNot(contains(encodedMalformedBody)));
        expect(await OcrRetryStorage.read(readableReference), bytes);

        notifier.removeTask('mixed-v2-failure');
        await notifier.pendingPersistence;
        persisted = await taskFile.readAsString();
        expect(persisted, isNot(contains(readableReference)));
        expect(await OcrRetryStorage.read(readableReference), isNull);
      } finally {
        notifier.dispose();
        await notifier.pendingPersistence;
      }
    },
  );

  test(
    'step persistence stays small after cached retry data is attached',
    () async {
      final bytes = Uint8List.fromList(List<int>.filled(160 * 1024, 0x5a));
      final notifier = BackgroundTaskNotifier();
      final taskId = notifier.addTask(
        type: BackgroundTaskType.ocr,
        title: 'large retry input',
        taskId: 'large-task',
      );
      try {
        final retryData = await OcrRetryStorage.cacheSnapshot(
          taskId: taskId,
          snapshot: OcrRetrySnapshot.capture(
            configId: 'config-1',
            modelId: 'model-1',
            images: [OcrRetryImage(bytes: bytes, format: 'png')],
          ),
        );
        notifier.setRetryData(taskId, retryData);
        await notifier.pendingPersistence;

        final taskFile = File(
          '${taskDirectory.path}${Platform.pathSeparator}background${Platform.pathSeparator}tasks.json',
        );
        for (var index = 0; index < 5; index++) {
          notifier.updateStep(taskId, index, running: true);
          await notifier.pendingPersistence;
          final encoded = await taskFile.readAsString();
          final persisted = (jsonDecode(encoded) as List).single as Map;
          final image =
              ((persisted['retryData'] as Map)['images'] as List).single as Map;
          expect(image.containsKey('bytes'), isFalse);
          expect(encoded.length, lessThan(4000));
        }

        expect(
          await OcrRetryStorage.read(
            ((retryData['images'] as List).single as Map)['storageRef']
                as String,
          ),
          bytes,
        );
      } finally {
        notifier.dispose();
        await notifier.pendingPersistence;
      }
    },
  );

  test(
    'changing a shared image reference preserves the other snapshot',
    () async {
      final originalBytes = Uint8List.fromList([1, 2, 3]);
      final replacementBytes = Uint8List.fromList([4, 5, 6]);
      final original = await OcrRetryStorage.cacheSnapshot(
        taskId: 'first-task',
        snapshot: OcrRetrySnapshot.capture(
          configId: 'config-1',
          modelId: 'model-1',
          images: [OcrRetryImage(bytes: originalBytes, format: 'png')],
        ),
      );
      final reference =
          ((original['images'] as List).single as Map)['storageRef'] as String;
      final shared = await OcrRetryStorage.cacheSnapshot(
        taskId: 'second-task',
        snapshot: OcrRetrySnapshot.capture(
          configId: 'config-1',
          modelId: 'model-1',
          images: [
            OcrRetryImage.reference(storageRef: reference, format: 'png'),
          ],
        ),
      );

      final updated = await OcrRetryStorage.cacheSnapshot(
        taskId: 'first-task',
        snapshot: OcrRetrySnapshot.capture(
          configId: 'config-1',
          modelId: 'model-1',
          images: [OcrRetryImage(bytes: replacementBytes, format: 'png')],
        ),
      );
      final sharedRestore = await OcrRetryStorage.restoreImages(
        OcrRetrySnapshot.fromMap(shared),
      );

      expect(
        ((updated['images'] as List).single as Map)['storageRef'],
        isNot(reference),
      );
      expect(sharedRestore.images.single.bytes, originalBytes);
    },
  );

  test(
    'task deletion preserves shared references and unrelated files',
    () async {
      final notifier = BackgroundTaskNotifier();
      final removedId = notifier.addTask(
        type: BackgroundTaskType.ocr,
        title: 'first task',
        taskId: 'first-task',
      );
      final remainingId = notifier.addTask(
        type: BackgroundTaskType.ocr,
        title: 'second task',
        taskId: 'second-task',
      );
      try {
        final sharedSnapshot = await OcrRetryStorage.cacheSnapshot(
          taskId: removedId,
          snapshot: OcrRetrySnapshot.capture(
            configId: 'config-1',
            modelId: 'model-1',
            images: [
              OcrRetryImage(bytes: Uint8List.fromList([1, 2]), format: 'png'),
            ],
          ),
        );
        final reference = ((sharedSnapshot['images'] as List).single
            as Map)['storageRef'] as String;
        notifier.setRetryData(removedId, sharedSnapshot);
        notifier.setRetryData(remainingId, sharedSnapshot);
        await WebFileStore.write(
          'attachments/unrelated.bin',
          Uint8List.fromList([4, 5]),
        );

        notifier.removeTask(removedId);
        await notifier.pendingPersistence;
        expect(await OcrRetryStorage.read(reference), isNotNull);

        expect(await notifier.removeTasksPersisted([remainingId]), isTrue);
        expect(await OcrRetryStorage.read(reference), isNull);
        expect(
          await WebFileStore.read('attachments/unrelated.bin'),
          Uint8List.fromList([4, 5]),
        );
      } finally {
        notifier.dispose();
        await notifier.pendingPersistence;
      }
    },
  );

  test(
    'persisted deletion cleans cache references attached while saving',
    () async {
      final notifier = BackgroundTaskNotifier();
      final taskId = notifier.addTask(
        type: BackgroundTaskType.ocr,
        title: 'legacy task',
        taskId: 'legacy-task',
        retryData: {
          'type': 'ocr',
          'version': 1,
          'images': [
            {'bytes': 'AQID', 'format': 'png'},
          ],
        },
      );
      try {
        await notifier.pendingPersistence;
        final retryData = await OcrRetryStorage.cacheSnapshot(
          taskId: taskId,
          snapshot: OcrRetrySnapshot.capture(
            configId: 'config-1',
            modelId: 'model-1',
            images: [
              OcrRetryImage(
                bytes: Uint8List.fromList([1, 2, 3]),
                format: 'png',
              ),
            ],
          ),
        );
        final reference = ((retryData['images'] as List).single
            as Map)['storageRef'] as String;

        final removal = notifier.removeTasksPersisted([taskId]);
        notifier.setRetryData(taskId, retryData);

        expect(await removal, isTrue);
        await notifier.pendingPersistence;
        expect(await OcrRetryStorage.read(reference), isNull);
      } finally {
        notifier.dispose();
        await notifier.pendingPersistence;
      }
    },
  );

  test(
    'cache failure rolls back partial blobs and preserves existing files',
    () async {
      final originalBytes = Uint8List.fromList([9, 8, 7]);
      final originalSnapshot = await OcrRetryStorage.cacheSnapshot(
        taskId: 'partial-task',
        snapshot: OcrRetrySnapshot.capture(
          configId: 'config-1',
          modelId: 'model-1',
          images: [OcrRetryImage(bytes: originalBytes, format: 'png')],
        ),
      );
      final originalReference = ((originalSnapshot['images'] as List).single
          as Map)['storageRef'] as String;
      final missingReference =
          'ocr_retry_cache/${List.filled(64, 'f').join()}.bin';
      final snapshot = OcrRetrySnapshot.capture(
        configId: 'config-1',
        modelId: 'model-1',
        images: [
          OcrRetryImage(bytes: Uint8List.fromList([1, 2, 3]), format: 'png'),
          OcrRetryImage(bytes: Uint8List.fromList([4, 5, 6]), format: 'png'),
          OcrRetryImage.reference(storageRef: missingReference, format: 'png'),
        ],
      );

      await expectLater(
        OcrRetryStorage.cacheSnapshot(
          taskId: 'partial-task',
          snapshot: snapshot,
        ),
        throwsFormatException,
      );

      expect(await WebFileStore.keysWithPrefix('ocr_retry_cache/'), [
        originalReference,
      ]);
      expect(await OcrRetryStorage.read(originalReference), originalBytes);
    },
  );

  test(
    'failed cache rollback preserves a concurrent write for the task',
    () async {
      final missingReference =
          'ocr_retry_cache/${List.filled(64, 'f').join()}.bin';
      final firstImage = Uint8List.fromList([1, 2, 3]);
      final failedSnapshot = OcrRetrySnapshot.capture(
        configId: 'config-1',
        modelId: 'model-1',
        images: [
          OcrRetryImage(bytes: firstImage, format: 'png'),
          OcrRetryImage.reference(storageRef: missingReference, format: 'png'),
        ],
      );
      final completeSnapshot = OcrRetrySnapshot.capture(
        configId: 'config-1',
        modelId: 'model-1',
        images: [
          OcrRetryImage(bytes: firstImage, format: 'png'),
          OcrRetryImage(bytes: Uint8List.fromList([4, 5, 6]), format: 'png'),
        ],
      );

      final failedWrite = OcrRetryStorage.cacheSnapshot(
        taskId: 'concurrent-task',
        snapshot: failedSnapshot,
      );
      final failure = expectLater(failedWrite, throwsFormatException);
      final successfulWrite = OcrRetryStorage.cacheSnapshot(
        taskId: 'concurrent-task',
        snapshot: completeSnapshot,
      );

      final stored = await successfulWrite;
      await failure;
      final restored = await OcrRetryStorage.restoreImages(
        OcrRetrySnapshot.fromMap(stored),
      );
      expect(restored.isComplete, isTrue);
      expect(restored.images.map((image) => image.bytes).toList(), [
        firstImage,
        Uint8List.fromList([4, 5, 6]),
      ]);
    },
  );

  test(
    'direct OCR removal during persisted bulk removal stays durable',
    () async {
      final notifier = BackgroundTaskNotifier();
      final bulkId = notifier.addTask(
        type: BackgroundTaskType.asr,
        title: 'bulk removal',
        taskId: 'bulk-task',
      );
      final directId = notifier.addTask(
        type: BackgroundTaskType.ocr,
        title: 'direct removal',
        taskId: 'direct-task',
      );
      try {
        final retryData = await OcrRetryStorage.cacheSnapshot(
          taskId: directId,
          snapshot: OcrRetrySnapshot.capture(
            configId: 'config-1',
            modelId: 'model-1',
            images: [
              OcrRetryImage(
                bytes: Uint8List.fromList([1, 2, 3]),
                format: 'png',
              ),
            ],
          ),
        );
        final reference = ((retryData['images'] as List).single
            as Map)['storageRef'] as String;
        notifier.setRetryData(directId, retryData);
        await notifier.pendingPersistence;

        final removal = notifier.removeTasksPersisted([bulkId]);
        notifier.removeTask(directId);

        expect(await removal, isTrue);
        await notifier.pendingPersistence;
        final taskFile = File(
          '${taskDirectory.path}${Platform.pathSeparator}background${Platform.pathSeparator}tasks.json',
        );
        expect(jsonDecode(await taskFile.readAsString()), isEmpty);
        expect(await OcrRetryStorage.read(reference), isNull);
      } finally {
        notifier.dispose();
        await notifier.pendingPersistence;
      }
    },
  );
}
