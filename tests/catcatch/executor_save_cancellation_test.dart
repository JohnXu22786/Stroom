// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/catcatch/engine/executor_save.dart';
import 'package:stroom/catcatch/engine/task_executor.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/task_flow/services/block_executors/catcatch_output_registrator.dart';
import 'package:stroom/utils/file_manifest.dart';
import 'package:stroom/utils/video_manifest.dart';
import 'package:stroom/utils/web_file_store.dart';

class _Documents extends PathProviderPlatform {
  _Documents(this.path);
  final String path;
  Completer<void>? entered;
  Completer<void>? release;

  @override
  Future<String> getApplicationDocumentsPath() async {
    final pending = release;
    if (pending != null) {
      release = null;
      entered?.complete();
      await pending.future;
    }
    return path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late PathProviderPlatform previous;
  late _Documents documents;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    VideoManifest.invalidateCache();
    FileManifest.invalidateCache();
    directory = await Directory.systemTemp.createTemp('catcatch_save_cancel_');
    previous = PathProviderPlatform.instance;
    documents = _Documents(directory.path);
    PathProviderPlatform.instance = documents;
    AppStorage.resetCache();
  });

  tearDown(() async {
    PathProviderPlatform.instance = previous;
    AppStorage.resetCache();
    await directory.delete(recursive: true);
  });

  test('cancel while save resolves storage leaves no completed copy', () async {
    final source = await File(p.join(directory.path, 'source.bin'))
        .writeAsBytes(
            await File('tests/fixtures/catcatch/video_only.mp4').readAsBytes());
    final task = CatCatchTask(
      id: 'cancel-during-save',
      url: 'https://example.invalid/source',
      expectedDurationSec: 0,
      createdAt: DateTime.now(),
      downloadedFilePath: source.path,
      steps: [
        for (final type in StepType.values)
          type == StepType.saving
              ? StepStatus.pending(type)
              : StepStatus.done(type),
      ],
    );
    final token = CancelToken();
    final entered = Completer<void>();
    final release = Completer<void>();
    documents.entered = entered;
    documents.release = release;

    final run = TaskExecutor.retryFromStep(
      task: task,
      fromStep: StepType.saving,
      onUpdate: (_) {},
      cancelToken: token,
    );
    await entered.future.timeout(const Duration(seconds: 5));
    token.cancel();
    release.complete();

    expect(await run, isNull);
    expect(await source.exists(), isTrue);
    expect(
        await File(
                p.join(directory.path, 'catcatch', 'completed', 'source.bin'))
            .exists(),
        isFalse);
  });

  CatCatchTask taskFor(String id, String path) => CatCatchTask(
        id: id,
        url: 'https://example.invalid/source',
        expectedDurationSec: 3,
        createdAt: DateTime.now(),
        downloadedFilePath: path,
        steps: [for (final type in StepType.values) StepStatus.pending(type)],
      );

  Future<String> save(
    CatCatchTask task, {
    CancelToken? token,
    Future<void> Function()? afterRecordAdded,
  }) =>
      executeSave(
        task: task,
        steps: List<StepStatus>.from(task.steps),
        sourcePath: task.downloadedFilePath,
        onUpdate: (_) {},
        cancelToken: token,
        afterRecordAdded: afterRecordAdded,
      );

  Future<List<int>> videoBytes(int tag) async {
    final fixture =
        await File(p.join('tests', 'fixtures', 'catcatch', 'video_only.mp4'))
            .readAsBytes();
    // A valid trailing ISO free box gives each scenario a distinct hash.
    return [...fixture, 0, 0, 0, 9, ...'free'.codeUnits, tag];
  }

  Future<List<int>> audioOggBytes() =>
      File(p.join('tests', 'fixtures', 'catcatch', 'audio_only.ogg'))
          .readAsBytes();

  test('cancel after video insertion rolls back record and completed copy',
      () async {
    final bytes = await videoBytes(1);
    final hash = md5.convert(bytes).toString();
    final source =
        await File(p.join(directory.path, 'clip.mp4')).writeAsBytes(bytes);
    final token = CancelToken();
    final entered = Completer<void>();
    final release = Completer<void>();
    final pending = save(taskFor('video', source.path), token: token,
        afterRecordAdded: () async {
      entered.complete();
      await release.future;
    });

    await entered.future.timeout(const Duration(seconds: 5));
    expect(await VideoManifest.loadRecords(), hasLength(1));
    token.cancel();
    release.complete();
    await expectLater(pending, throwsA(isA<Exception>()));

    expect(await VideoManifest.loadRecords(), isEmpty);
    expect(await WebFileStore.exists('videos/$hash.mp4'), isTrue);
    expect(
        await File(p.join(directory.path, 'catcatch', 'completed', 'clip.mp4'))
            .exists(),
        isFalse);
    expect(await source.readAsBytes(), bytes);
  });

  test('cancelled duplicate keeps the existing gallery owner and blob',
      () async {
    final bytes = await videoBytes(2);
    final hash = md5.convert(bytes).toString();
    final original = VideoRecord(
      name: 'Original',
      hash: hash,
      format: 'mp4',
      createdAt: DateTime.now(),
      size: bytes.length,
    );
    await VideoManifest.writeFile('$hash.mp4', Uint8List.fromList(bytes));
    await VideoManifest.addRecord(original);
    final source =
        await File(p.join(directory.path, 'duplicate.mp4')).writeAsBytes(bytes);
    final token = CancelToken();
    final entered = Completer<void>();
    final release = Completer<void>();
    final pending = save(taskFor('duplicate', source.path), token: token,
        afterRecordAdded: () async {
      entered.complete();
      await release.future;
    });

    await entered.future.timeout(const Duration(seconds: 5));
    expect(await VideoManifest.loadRecords(), hasLength(2));
    token.cancel();
    release.complete();
    await expectLater(pending, throwsA(isA<Exception>()));

    final records = await VideoManifest.loadRecords();
    expect(records.map((record) => record.id), [original.id]);
    expect(await VideoManifest.readFile('$hash.mp4'), bytes);
  });

  test('cancel in save progress callback rolls back the committed video',
      () async {
    final bytes = await videoBytes(3);
    final hash = md5.convert(bytes).toString();
    final source =
        await File(p.join(directory.path, 'callback.mp4')).writeAsBytes(bytes);
    final task = taskFor('callback', source.path);
    final token = CancelToken();

    await expectLater(
      executeSave(
        task: task,
        steps: List<StepStatus>.from(task.steps),
        sourcePath: source.path,
        onUpdate: (_) => token.cancel(),
        cancelToken: token,
      ),
      throwsA(isA<Exception>()),
    );

    expect(await VideoManifest.loadRecords(), isEmpty);
    expect(await WebFileStore.exists('videos/$hash.mp4'), isTrue);
    expect(
        await File(
                p.join(directory.path, 'catcatch', 'completed', 'callback.mp4'))
            .exists(),
        isFalse);
  });

  test('cancel after Ogg audio insertion rolls back its gallery record',
      () async {
    final bytes = await audioOggBytes();
    final hash = md5.convert(bytes).toString();
    final source =
        await File(p.join(directory.path, 'audio.ogg')).writeAsBytes(bytes);
    final token = CancelToken();
    final entered = Completer<void>();
    final release = Completer<void>();
    final pending = save(taskFor('audio', source.path), token: token,
        afterRecordAdded: () async {
      entered.complete();
      await release.future;
    });

    await entered.future.timeout(const Duration(seconds: 5));
    expect(await VideoManifest.loadRecords(), isEmpty);
    expect(await FileManifest.loadRecords(), hasLength(1));
    token.cancel();
    release.complete();
    await expectLater(pending, throwsA(isA<Exception>()));

    expect(await VideoManifest.loadRecords(), isEmpty);
    expect(await FileManifest.loadRecords(), isEmpty);
    expect(await WebFileStore.exists('videos/$hash.ogg'), isFalse);
    expect(await WebFileStore.exists('tts_audio/$hash.ogg'), isTrue);
  });

  test('new save waits for cancelled same-hash save to roll back', () async {
    final bytes = await videoBytes(4);
    final hash = md5.convert(bytes).toString();
    final first =
        await File(p.join(directory.path, 'first.mp4')).writeAsBytes(bytes);
    final second =
        await File(p.join(directory.path, 'second.mp4')).writeAsBytes(bytes);
    final token = CancelToken();
    final entered = Completer<void>();
    final release = Completer<void>();
    final firstSave = save(taskFor('first', first.path), token: token,
        afterRecordAdded: () async {
      entered.complete();
      await release.future;
    });
    await entered.future.timeout(const Duration(seconds: 5));
    final secondSave = save(taskFor('second', second.path));
    token.cancel();
    release.complete();
    await expectLater(firstSave, throwsA(isA<Exception>()));
    expect(await secondSave, isNotNull);

    expect(await VideoManifest.loadRecords(), hasLength(1));
    expect(await VideoManifest.readFile('$hash.mp4'), bytes);
  });

  test('last rollback retains an ambiguous shared blob', () async {
    final bytes = await videoBytes(5);
    final hash = md5.convert(bytes).toString();
    final first =
        await File(p.join(directory.path, 'first.mp4')).writeAsBytes(bytes);
    final second =
        await File(p.join(directory.path, 'second.mp4')).writeAsBytes(bytes);

    final firstRegistration =
        await registerCompletedMedia(first.path, taskFor('first', first.path));
    final secondRegistration = await registerCompletedMedia(
        second.path, taskFor('second', second.path));
    expect(await VideoManifest.loadRecords(), hasLength(2));

    await firstRegistration.rollback();
    expect(await VideoManifest.loadRecords(), hasLength(1));
    expect(await VideoManifest.readFile('$hash.mp4'), bytes);
    await secondRegistration.rollback();
    expect(await VideoManifest.loadRecords(), isEmpty);
    expect(await WebFileStore.exists('videos/$hash.mp4'), isTrue);
  });

  test('gallery deletion during registration repairs the shared blob',
      () async {
    final bytes = await videoBytes(6);
    final hash = md5.convert(bytes).toString();
    final original = VideoRecord(
      name: 'Original',
      hash: hash,
      format: 'mp4',
      createdAt: DateTime.now(),
      size: bytes.length,
    );
    await VideoManifest.writeFile('$hash.mp4', Uint8List.fromList(bytes));
    await VideoManifest.addRecord(original);
    final source =
        await File(p.join(directory.path, 'incoming.mp4')).writeAsBytes(bytes);
    final entered = Completer<void>();
    final release = Completer<void>();
    final registration = registerCompletedMedia(
      source.path,
      taskFor('incoming', source.path),
      beforeRecordAdded: () async {
        entered.complete();
        await release.future;
      },
    );

    await entered.future.timeout(const Duration(seconds: 5));
    await VideoManifest.deleteRecord(original.id);
    expect(await VideoManifest.readFile('$hash.mp4'), isNull);
    release.complete();
    await registration;

    final records = await VideoManifest.loadRecords();
    expect(records, hasLength(1));
    expect(records.single.id, isNot(original.id));
    expect(await VideoManifest.readFile('$hash.mp4'), bytes);
  });

  test('an unowned partial hash blob is repaired before registration',
      () async {
    final bytes = await videoBytes(7);
    final hash = md5.convert(bytes).toString();
    final source =
        await File(p.join(directory.path, 'repair.mp4')).writeAsBytes(bytes);
    await VideoManifest.writeFile(
        '$hash.mp4', Uint8List.fromList(bytes.sublist(0, 2)));

    await registerCompletedMedia(source.path, taskFor('repair', source.path));
    expect(await VideoManifest.loadRecords(), hasLength(1));
    expect(await VideoManifest.readFile('$hash.mp4'), bytes);
  });

  test('cancel before native blob publication cleans only private staging',
      () async {
    final bytes = await videoBytes(8);
    final hash = md5.convert(bytes).toString();
    final source =
        await File(p.join(directory.path, 'staged.mp4')).writeAsBytes(bytes);
    final storage = await Directory(p.join(directory.path, 'videos')).create();
    final target = File(p.join(storage.path, '$hash.mp4'));
    final entered = Completer<void>();
    final release = Completer<void>();
    var cancelled = false;
    final pending =
        publishCompletedBlob(source, '$hash.mp4', storage.path, hash,
            cancelled: () => cancelled,
            afterStaged: () async {
              entered.complete();
              await release.future;
            });

    await entered.future.timeout(const Duration(seconds: 5));
    expect(await target.exists(), isFalse);
    expect(await storage.list().toList(), hasLength(1));
    cancelled = true;
    release.complete();
    await expectLater(pending, throwsA(isA<Exception>()));
    expect(await storage.list().toList(), isEmpty);

    await publishCompletedBlob(source, '$hash.mp4', storage.path, hash,
        cancelled: () => false);
    expect(await target.readAsBytes(), bytes);
  });

  test('native publication replaces an incomplete preexisting hash blob',
      () async {
    final bytes = await videoBytes(9);
    final hash = md5.convert(bytes).toString();
    final source =
        await File(p.join(directory.path, 'recovery.mp4')).writeAsBytes(bytes);
    final storage = await Directory(p.join(directory.path, 'videos')).create();
    final target = await File(p.join(storage.path, '$hash.mp4'))
        .writeAsBytes(bytes.sublist(0, 2));

    await publishCompletedBlob(source, '$hash.mp4', storage.path, hash,
        cancelled: () => false);

    expect(await target.readAsBytes(), bytes);
    expect(await storage.list().toList(), [isA<File>()]);
  });

  test('rename refusal repairs invalid blob but preserves a valid shared blob',
      () async {
    final bytes = [81, 82, 83, 84];
    final hash = md5.convert(bytes).toString();
    final source =
        await File(p.join(directory.path, 'windows.mp4')).writeAsBytes(bytes);
    final storage = await Directory(p.join(directory.path, 'videos')).create();
    final target = await File(p.join(storage.path, '$hash.mp4'))
        .writeAsBytes(bytes.sublist(0, 2));
    var renameAttempts = 0;
    var replacements = 0;

    Future<File> refuseOverwrite(File staged, String path) async {
      renameAttempts++;
      if (await File(path).exists()) {
        throw FileSystemException('Target already exists', path);
      }
      return staged.rename(path);
    }

    Future<bool> replaceExisting(String stagedPath, String targetPath) async {
      replacements++;
      await File(stagedPath).rename(targetPath);
      return true;
    }

    await publishCompletedBlob(source, '$hash.mp4', storage.path, hash,
        cancelled: () => false,
        renameStaged: refuseOverwrite,
        replaceExisting: replaceExisting);
    expect(await target.readAsBytes(), bytes);
    expect(renameAttempts, 1);
    expect(replacements, 1);
    expect(await storage.list().toList(), [isA<File>()]);

    await publishCompletedBlob(source, '$hash.mp4', storage.path, hash,
        cancelled: () => false,
        renameStaged: refuseOverwrite,
        replaceExisting: replaceExisting);
    expect(await target.readAsBytes(), bytes);
    expect(renameAttempts, 1);
    expect(replacements, 1);
  });

  test('flow fallback rolls back a record when its execution is cancelled',
      () async {
    final bytes = await videoBytes(10);
    final hash = md5.convert(bytes).toString();
    final source =
        await File(p.join(directory.path, 'flow.mp4')).writeAsBytes(bytes);
    final task = taskFor('flow', source.path);
    final entered = Completer<void>();
    final release = Completer<void>();
    var current = true;
    final pending = registerFlowCatCatchOutput(
      source.path,
      task,
      isCurrent: () => current,
      afterRecordAdded: () async {
        entered.complete();
        await release.future;
      },
    );

    await entered.future.timeout(const Duration(seconds: 5));
    expect(await VideoManifest.loadRecords(), hasLength(1));
    current = false;
    release.complete();
    await expectLater(pending, throwsA(isA<Exception>()));

    expect(await VideoManifest.loadRecords(), isEmpty);
    expect(await WebFileStore.exists('videos/$hash.mp4'), isTrue);
  });
}
