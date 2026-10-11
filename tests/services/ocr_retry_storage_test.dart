import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/ocr/ocr_retry_snapshot.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/task_provider.dart';
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

  test('version 2 stores cached references and restores image bytes', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final snapshot = OcrRetrySnapshot.capture(
      configId: 'config-1',
      modelId: 'model-1',
      images: [OcrRetryImage(bytes: bytes, format: 'png', name: 'scan.png')],
      instructionContent: 'receipt text',
      saveFolder: 'receipts',
    );

    final stored = await OcrRetryStorage.cacheSnapshot(
      taskId: 'task-1',
      snapshot: snapshot,
    );
    final imageMap = (stored['images'] as List).single as Map;
    final restored = await OcrRetryStorage.restoreImages(
      OcrRetrySnapshot.fromMap(stored),
    );

    expect(stored['version'], 2);
    expect(imageMap.keys.toSet(), {'storageRef', 'format', 'name'});
    expect(imageMap['storageRef'], startsWith('ocr_retry_cache/'));
    expect(imageMap.containsKey('bytes'), isFalse);
    expect(restored.isComplete, isTrue);
    expect(restored.images.single.bytes, bytes);
    expect(stored['instructionContent'], 'receipt text');
    expect(stored['saveFolder'], 'receipts');
  });

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
        final reference =
            ((sharedSnapshot['images'] as List).single as Map)['storageRef']
                as String;
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
        final reference =
            ((retryData['images'] as List).single as Map)['storageRef']
                as String;

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
      final originalReference =
          ((originalSnapshot['images'] as List).single as Map)['storageRef']
              as String;
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
        final reference =
            ((retryData['images'] as List).single as Map)['storageRef']
                as String;
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
