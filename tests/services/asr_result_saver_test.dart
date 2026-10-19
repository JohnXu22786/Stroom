import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/services/asr_result_saver.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/utils/web_file_store.dart';

void main() {
  late Directory directory;
  late BackgroundTaskNotifier notifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
    directory = await Directory.systemTemp.createTemp('asr_result_saver_');
    BackgroundTaskNotifier.debugStorageDirectoryOverride = directory.path;
    notifier = BackgroundTaskNotifier();
  });

  tearDown(() async {
    if (notifier.mounted) notifier.dispose();
    await notifier.pendingPersistence;
    BackgroundTaskNotifier.debugStorageDirectoryOverride = null;
    await directory.delete(recursive: true);
  });

  test(
    'saving the same ASR output twice does not duplicate its record',
    () async {
      final firstTaskId = notifier.addTask(
        type: BackgroundTaskType.asr,
        title: 'first retry',
      );
      await AsrResultSaver(
        taskId: firstTaskId,
        notifier: notifier,
        title: 'same transcript',
        folder: 'captured-folder',
        cancelToken: CancelToken(),
        onSaved: () {},
      ).saveResult('same transcript', format: 'txt');

      final secondTaskId = notifier.addTask(
        type: BackgroundTaskType.asr,
        title: 'second retry',
      );
      await AsrResultSaver(
        taskId: secondTaskId,
        notifier: notifier,
        title: 'same transcript',
        folder: 'captured-folder',
        cancelToken: CancelToken(),
        onSaved: () {},
      ).saveResult('same transcript', format: 'txt');

      expect(await TextManifest.loadRecords(), hasLength(1));
      expect(notifier.taskById(secondTaskId)!.status, TaskStatus.completed);
    },
  );

  test(
    'saving the same ASR output repairs a mismatched published file',
    () async {
      const transcript = 'repairable transcript';
      final firstTaskId = notifier.addTask(
        type: BackgroundTaskType.asr,
        title: 'first retry',
      );
      final path = await AsrResultSaver(
        taskId: firstTaskId,
        notifier: notifier,
        title: transcript,
        folder: 'captured-folder',
        cancelToken: CancelToken(),
        onSaved: () {},
      ).saveResult(transcript, format: 'txt');
      final record = (await TextManifest.loadRecords()).single;
      await TextManifest.writeText(
        record.storageFileName,
        'stale file contents',
      );

      final secondTaskId = notifier.addTask(
        type: BackgroundTaskType.asr,
        title: 'second retry',
      );
      final repairedPath = await AsrResultSaver(
        taskId: secondTaskId,
        notifier: notifier,
        title: transcript,
        folder: 'captured-folder',
        cancelToken: CancelToken(),
        onSaved: () {},
      ).saveResult(transcript, format: 'txt');

      expect(repairedPath, path);
      expect(await TextManifest.readText(record.storageFileName), transcript);
      expect(await TextManifest.loadRecords(), hasLength(1));
      expect(notifier.taskById(secondTaskId)!.status, TaskStatus.completed);
    },
  );

  test(
    'saving the same ASR output repairs an invalid UTF-8 file',
    () async {
      const transcript = 'repair invalid UTF-8 before publishing';
      final firstTaskId = notifier.addTask(
        type: BackgroundTaskType.asr,
        title: 'first retry',
      );
      final path = await AsrResultSaver(
        taskId: firstTaskId,
        notifier: notifier,
        title: transcript,
        folder: 'captured-folder',
        cancelToken: CancelToken(),
        onSaved: () {},
      ).saveResult(transcript, format: 'txt');
      final record = (await TextManifest.loadRecords()).single;
      await WebFileStore.write(
        'texts/${record.storageFileName}',
        Uint8List.fromList([0xC3, 0x28]),
      );

      final secondTaskId = notifier.addTask(
        type: BackgroundTaskType.asr,
        title: 'second retry',
      );
      final repairedPath = await AsrResultSaver(
        taskId: secondTaskId,
        notifier: notifier,
        title: transcript,
        folder: 'captured-folder',
        cancelToken: CancelToken(),
        onSaved: () {},
      ).saveResult(transcript, format: 'txt');

      expect(repairedPath, path);
      expect(await TextManifest.readText(record.storageFileName), transcript);
      expect(await TextManifest.loadRecords(), hasLength(1));
      expect(notifier.taskById(secondTaskId)!.status, TaskStatus.completed);
    },
  );

  test(
    'identical output with a different title keeps the second manifest name',
    () async {
      const transcript = 'shared transcript text';
      for (final title in ['First recording', 'Second recording']) {
        final taskId = notifier.addTask(
          type: BackgroundTaskType.asr,
          title: title,
        );
        await AsrResultSaver(
          taskId: taskId,
          notifier: notifier,
          title: title,
          folder: 'captured-folder',
          cancelToken: CancelToken(),
          onSaved: () {},
        ).saveResult(transcript, format: 'txt');
      }

      final records = await TextManifest.loadRecords();
      expect(records, hasLength(2));
      expect(
        records.map((record) => record.name).toSet(),
        {'First recording', 'Second recording'},
      );
    },
  );

  test(
    'rollback removes a new text file when another format shares its hash',
    () async {
      const transcript = 'shared content hash';
      final hash = computeTextHash(Uint8List.fromList(transcript.codeUnits));
      final existingSubtitle = TextRecord(
        name: 'Existing subtitle',
        hash: hash,
        format: 'srt',
        createdAt: DateTime.utc(2024),
        size: transcript.length,
      );
      final taskId = notifier.addTask(
        type: BackgroundTaskType.asr,
        title: 'retry transcript',
      );
      final saver = AsrResultSaver(
        taskId: taskId,
        notifier: notifier,
        title: 'retry transcript',
        folder: 'captured-folder',
        cancelToken: CancelToken(),
        onSaved: () {},
        addRecord: (record, {beforeCommit}) async {
          throw StateError('manifest publication failed');
        },
        loadRecordsUncached: () async => [existingSubtitle],
      );

      await expectLater(
        saver.saveResult(transcript, format: 'txt'),
        throwsA(isA<StateError>()),
      );

      expect(await TextManifest.readFilePath('$hash.txt'), isNull);
    },
  );
}
