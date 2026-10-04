// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/utils/audio_utils.dart';
import 'package:stroom/utils/file_manifest.dart';

class _Documents extends PathProviderPlatform {
  _Documents(this.path);

  final String path;

  @override
  Future<String> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late PathProviderPlatform previousDocuments;
  late ProviderContainer container;
  late TaskListNotifier notifier;
  late ProviderConfigItem providerConfig;
  final audio = pcmToWav(Uint8List.fromList([0, 0, 1, 0]));
  final hash = computeAudioHash(audio);
  final modelConfig = ModelConfig(name: 'test', modelId: 'test');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    FileManifest.invalidateCache();
    directory = await Directory.systemTemp.createTemp('tts_save_cancel_');
    previousDocuments = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Documents(directory.path);
    AppStorage.resetCache();

    providerConfig = ProviderConfigItem(
      providerName: 'test',
      host: 'https://example.invalid/speech',
      key: 'test-key',
    );
    container = ProviderContainer();
    notifier = container.read(taskListProvider.notifier);
    notifier.debugSynthesize = (_, __, ___) async => audio;
  });

  tearDown(() async {
    container.dispose();
    // Task persistence is launched without awaiting it by add/pause/remove.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    PathProviderPlatform.instance = previousDocuments;
    AppStorage.resetCache();
    await directory.delete(recursive: true);
  });

  Future<SynthesisTask> waitForStatus(String id, TaskStatus status) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      final task =
          container.read(taskListProvider).singleWhere((t) => t.id == id);
      if (task.status == status) return task;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('Task $id never reached $status');
  }

  Future<void> waitUntil(Future<bool> Function() predicate) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      if (await predicate()) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('Save did not settle to the expected state');
  }

  test('pausing during save removes audio, source text, and gallery record',
      () async {
    final enteredSave = Completer<void>();
    final releaseSave = Completer<void>();
    notifier.debugBeforeSaveCommit = () async {
      enteredSave.complete();
      await releaseSave.future;
    };

    final id = notifier.addTask(
      title: 'Canceled speech',
      text: 'Canceled source',
      providerConfig: providerConfig,
      modelConfig: modelConfig,
    );
    await enteredSave.future.timeout(const Duration(seconds: 5));
    expect(await FileManifest.readFile('$hash.wav'), isNotNull);
    expect(await FileManifest.readFile('$hash.txt'), isNotNull);
    expect(await FileManifest.loadRecords(), isEmpty);

    notifier.pauseTask(id);
    releaseSave.complete();
    await waitForStatus(id, TaskStatus.paused);
    await waitUntil(() async =>
        (await FileManifest.loadRecords()).isEmpty &&
        await FileManifest.readFile('$hash.wav') == null &&
        await FileManifest.readFile('$hash.txt') == null);

    expect(await FileManifest.loadRecords(), isEmpty);
    expect(await FileManifest.readFile('$hash.wav'), isNull);
    expect(await FileManifest.readFile('$hash.txt'), isNull);
    expect(container.read(taskListProvider).single.status, TaskStatus.paused);
  });

  for (final persisted in [false, true]) {
    test(
        persisted
            ? 'persisted removal during gallery save rolls back its files'
            : 'removing a task after gallery insertion rolls back its files',
        () async {
      final enteredSave = Completer<void>();
      final releaseSave = Completer<void>();
      notifier.debugAfterSaveCommit = () async {
        enteredSave.complete();
        await releaseSave.future;
      };

      final id = notifier.addTask(
        title: 'Canceled after insert',
        text: 'Canceled source',
        providerConfig: providerConfig,
        modelConfig: modelConfig,
      );
      await enteredSave.future.timeout(const Duration(seconds: 5));
      expect(await FileManifest.loadRecords(), hasLength(1));

      if (persisted) {
        expect(await notifier.removeTasksPersisted([id]), isTrue);
      } else {
        notifier.removeTask(id);
      }
      releaseSave.complete();
      await waitUntil(() async =>
          (await FileManifest.loadRecords()).isEmpty &&
          await FileManifest.readFile('$hash.wav') == null &&
          await FileManifest.readFile('$hash.txt') == null);

      expect(container.read(taskListProvider), isEmpty);
    });
  }

  test('failed persisted removal keeps an ongoing gallery save intact',
      () async {
    final enteredSave = Completer<void>();
    final releaseSave = Completer<void>();
    notifier.debugAfterSaveCommit = () async {
      enteredSave.complete();
      await releaseSave.future;
    };
    final id = notifier.addTask(
        title: 'Kept speech',
        text: 'Kept source',
        providerConfig: providerConfig,
        modelConfig: modelConfig);
    await enteredSave.future.timeout(const Duration(seconds: 5));
    expect(await notifier.removeTasksPersisted(['absent']), isTrue);
    final file = File('${directory.path}/synthesis/tasks.json');
    final backup = File('${file.path}.bak');
    await file.rename(backup.path);
    await Directory(file.path).create();
    expect(await notifier.removeTasksPersisted([id]), isFalse);
    expect(container.read(taskListProvider).single.id, id);
    expect((jsonDecode(await backup.readAsString()) as List).single['id'], id);
    await Directory(file.path).delete();
    await backup.rename(file.path);
    releaseSave.complete();
    final task = await waitForStatus(id, TaskStatus.completed);
    expect(task.downloadedFilePath, isNotNull);
    expect(await FileManifest.readFile('$hash.wav'), audio);
    expect(await FileManifest.readFile('$hash.txt'), isNotNull);
    expect(await FileManifest.loadRecords(), hasLength(1));
    expect(await notifier.removeTasksPersisted(['absent']), isTrue);
  });

  test('canceled duplicate save preserves an existing record and source',
      () async {
    final originalText = Uint8List.fromList(utf8.encode('Original source'));
    await FileManifest.writeFile('$hash.wav', audio);
    await FileManifest.writeFile('$hash.txt', originalText);
    final original = AudioRecord(
      name: 'Original speech',
      hash: hash,
      format: 'wav',
      createdAt: DateTime.now(),
      size: audio.length,
      sourceText: 'Original source',
    );
    await FileManifest.addRecord(original);

    final enteredSave = Completer<void>();
    final releaseSave = Completer<void>();
    notifier.debugBeforeSaveCommit = () async {
      enteredSave.complete();
      await releaseSave.future;
    };
    final id = notifier.addTask(
      title: 'Canceled duplicate',
      text: 'Different source',
      providerConfig: providerConfig,
      modelConfig: modelConfig,
    );
    await enteredSave.future.timeout(const Duration(seconds: 5));
    notifier.pauseTask(id);
    releaseSave.complete();
    await waitUntil(() async {
      final records = await FileManifest.loadRecords();
      final source = await FileManifest.readFile('$hash.txt');
      return records.length == 1 &&
          records.single.id == original.id &&
          source != null &&
          utf8.decode(source) == 'Original source';
    });

    expect(await FileManifest.readFile('$hash.wav'), audio);
    expect(container.read(taskListProvider).single.status, TaskStatus.paused);
  });

  test('resumed save waits for canceled save cleanup of the same audio',
      () async {
    final firstEntered = Completer<void>();
    final secondEntered = Completer<void>();
    final secondSynthesized = Completer<void>();
    final releaseFirst = Completer<void>();
    final releaseSecond = Completer<void>();
    var synthesisCount = 0;
    var saveCount = 0;
    notifier.debugSynthesize = (_, __, ___) async {
      if (++synthesisCount == 2) secondSynthesized.complete();
      return audio;
    };
    notifier.debugBeforeSaveCommit = () async {
      if (++saveCount == 1) {
        firstEntered.complete();
        await releaseFirst.future;
      } else {
        secondEntered.complete();
        await releaseSecond.future;
      }
    };

    final id = notifier.addTask(
      title: 'Resumed speech',
      text: 'Resumed source',
      providerConfig: providerConfig,
      modelConfig: modelConfig,
    );
    await firstEntered.future.timeout(const Duration(seconds: 5));
    notifier.pauseTask(id);
    notifier.resumeTask(id);
    await secondSynthesized.future.timeout(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final enteredBeforeCleanup = secondEntered.isCompleted;

    releaseFirst.complete();
    await secondEntered.future.timeout(const Duration(seconds: 5));
    releaseSecond.complete();
    await waitForStatus(id, TaskStatus.completed);
    expect(enteredBeforeCleanup, isFalse,
        reason: 'The resumed save must wait until the old save rolls back.');
    expect(await FileManifest.readFile('$hash.wav'), audio);
    expect(await FileManifest.readFile('$hash.txt'), isNotNull);
    expect(await FileManifest.loadRecords(), hasLength(1));
  });

  test('standalone task still saves a gallery record and source text',
      () async {
    final id = notifier.addTask(
      title: 'Saved speech',
      text: 'Saved source',
      providerConfig: providerConfig,
      modelConfig: modelConfig,
      folder: 'Narration',
    );
    final task = await waitForStatus(id, TaskStatus.completed);

    expect(task.downloadedFilePath, isNotNull);
    expect(await FileManifest.readFile('$hash.wav'), audio);
    final records = await FileManifest.loadRecords();
    expect(records, hasLength(1));
    expect(records.single.name, 'Saved speech');
    expect(records.single.sourceText, 'Saved source');
    expect(records.single.folder, 'Narration');
    expect(await FileManifest.readFile('$hash.txt'), isNotNull);
  });
}
