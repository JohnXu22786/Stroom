import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/services/asr_result_saver.dart';
import 'package:stroom/services/asr_service.dart';
import 'package:stroom/services/asr_task_scheduler.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/audio_utils.dart';
import 'package:stroom/utils/text_manifest.dart';

const _config = AsrConfig(apiKey: 'key', host: 'https://asr.test/transcribe');

class _ControlledAdapter implements HttpClientAdapter {
  _ControlledAdapter({
    this.holdFirstResponse = false,
    this.failures = const [],
  });

  final bool holdFirstResponse;
  final List<DioExceptionType?> failures;
  final calls = <RequestOptions>[];
  final requestStarted = Completer<void>();
  final cancelObserved = Completer<void>();
  final releaseResponse = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    final index = calls.length;
    calls.add(options);
    final failure = index < failures.length ? failures[index] : null;
    if (failure == DioExceptionType.connectionTimeout) {
      throw DioException(
        requestOptions: options,
        type: failure!,
        message: 'test connection timeout',
      );
    }
    if (requestStream != null) {
      await for (final _ in requestStream) {}
    }
    if (!requestStarted.isCompleted) requestStarted.complete();
    if (failure != null) {
      throw DioException(
        requestOptions: options,
        type: failure,
        message: 'test $failure',
      );
    }
    if (holdFirstResponse && index == 0) {
      final cancelled = cancelFuture?.then<bool>(
        (_) {
          if (!cancelObserved.isCompleted) cancelObserved.complete();
          return true;
        },
        onError: (_) {
          if (!cancelObserved.isCompleted) cancelObserved.complete();
          return true;
        },
      );
      final wasCancelled = await Future.any<bool>([
        if (cancelled != null) cancelled,
        releaseResponse.future.then((_) => false),
      ]);
      if (wasCancelled) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
        );
      }
    }
    return ResponseBody.fromString(
      jsonEncode({'text': 'recognized ${index + 1}'}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory directory;
  late BackgroundTaskNotifier notifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
    directory = await Directory.systemTemp.createTemp('asr_scheduler_');
    BackgroundTaskNotifier.debugStorageDirectoryOverride = directory.path;
    notifier = BackgroundTaskNotifier();
  });

  tearDown(() async {
    if (notifier.mounted) notifier.dispose();
    await notifier.pendingPersistence;
    BackgroundTaskNotifier.debugStorageDirectoryOverride = null;
    await directory.delete(recursive: true);
  });

  AsrTaskAudio audio(String name) =>
      AsrTaskAudio(bytes: Uint8List.fromList([1, 2, 3]), name: name);

  AsrTaskScheduler scheduler(
    _ControlledAdapter adapter, {
    required List<AsrTaskAudio> audios,
    AsrConfig config = _config,
    AsrTextWriter? writeText,
  }) {
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    return AsrTaskScheduler(
      notifier: notifier,
      config: config,
      audios: audios,
      saveFolder: 'captured-folder',
      modelIndex: 2,
      serviceFactory: (config) => AsrService(config: config, dio: dio),
      writeText: writeText,
    );
  }

  test('start is idempotent and snapshots each request chain', () async {
    final adapter = _ControlledAdapter(holdFirstResponse: true);
    final input = audio('captured.wav');
    final run = scheduler(adapter, audios: [input]);
    input.bytes[0] = 99;

    final first = run.start();
    final second = run.start();
    await adapter.requestStarted.future.timeout(const Duration(seconds: 5));
    expect(run.taskIds, hasLength(1));
    expect(run.audios.single.bytes.first, 1);
    expect(notifier.state.single.title, 'ASR_captured.wav');
    expect(notifier.state.single.status, TaskStatus.running);
    expect(notifier.state.single.steps[2].status, BgStepStatus.running);
    expect(notifier.state.single.steps[2].label, '转写中');
    expect(notifier.state.single.steps[2].label, isNot(contains('%')));

    adapter.releaseResponse.complete();
    await Future.wait([first, second]);

    expect(adapter.calls, hasLength(1));
    expect(notifier.state.single.status, TaskStatus.completed);
    expect(notifier.state.single.resultFolder, 'captured-folder');
    expect((await TextManifest.loadRecords()).single.folder, 'captured-folder');
  });

  test('removing a waiting task prevents its request from starting', () async {
    final adapter = _ControlledAdapter(holdFirstResponse: true);
    final run = scheduler(
      adapter,
      audios: [audio('one.wav'), audio('two.wav')],
    );
    final execution = run.start();
    final taskIds = run.taskIds;
    await adapter.requestStarted.future.timeout(const Duration(seconds: 5));

    notifier.removeTask(taskIds[1]);
    adapter.releaseResponse.complete();
    await execution;

    expect(adapter.calls, hasLength(1));
    expect(notifier.state.map((task) => task.id), [taskIds.first]);
    expect(notifier.state.single.status, TaskStatus.completed);
  });

  test('canceling an in-flight request does not save its transcript', () async {
    final adapter = _ControlledAdapter(holdFirstResponse: true);
    final run = scheduler(adapter, audios: [audio('cancel.wav')]);
    final execution = run.start();
    await adapter.requestStarted.future.timeout(const Duration(seconds: 5));

    notifier.cancelTask(run.taskIds.single);
    await adapter.cancelObserved.future.timeout(const Duration(seconds: 5));
    await execution;

    expect(notifier.state.single.status, TaskStatus.failed);
    expect(notifier.state.single.result, isNull);
    expect(await TextManifest.loadRecords(), isEmpty);
  });

  test(
    'canceling during the save boundary rolls back the transcript',
    () async {
      final adapter = _ControlledAdapter();
      final saveEntered = Completer<void>();
      final releaseSave = Completer<void>();
      final run = scheduler(
        adapter,
        audios: [audio('save-cancel.wav')],
        writeText: (fileName, text, {beforeCommit}) async {
          saveEntered.complete();
          await releaseSave.future;
          beforeCommit?.call();
          return TextManifest.writeText(
            fileName,
            text,
            beforeCommit: beforeCommit,
          );
        },
      );
      final execution = run.start();
      await saveEntered.future.timeout(const Duration(seconds: 5));

      notifier.cancelTask(run.taskIds.single);
      releaseSave.complete();
      await execution;

      expect(notifier.state.single.status, TaskStatus.failed);
      expect(await TextManifest.loadRecords(), isEmpty);
      final hash = computeTextHash(
        Uint8List.fromList(utf8.encode('recognized 1')),
      );
      expect(await TextManifest.readFilePath('$hash.txt'), isNull);
    },
  );

  test('phase timeouts fail one task and the queue continues', () async {
    final adapter = _ControlledAdapter(
      failures: [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ],
    );
    final run = scheduler(
      adapter,
      audios: [
        audio('connect.wav'),
        audio('upload.wav'),
        audio('response.wav'),
        audio('next.wav'),
      ],
    );

    await run.start();

    final tasks = {for (final task in notifier.state) task.id: task};
    expect(tasks[run.taskIds[0]]!.status, TaskStatus.failed);
    expect(tasks[run.taskIds[1]]!.status, TaskStatus.failed);
    expect(tasks[run.taskIds[2]]!.status, TaskStatus.failed);
    expect(tasks[run.taskIds[3]]!.status, TaskStatus.completed);
    expect(adapter.calls, hasLength(4));
  });

  test(
    'progress reports upload, response, and completed chunk events',
    () async {
      final adapter = _ControlledAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final events = <AsrRequestProgress>[];
      final service = AsrService(
        config: _config.copyWith(
          maxFileSizeBytes: 100,
          chunking: 'fixedSize',
          fallbackMethod: 'generic',
        ),
        dio: dio,
      );
      final wav = pcmToWav(Uint8List(140));

      await service.transcribe(
        audioBytes: wav,
        audioFormat: 'wav',
        onProgress: events.add,
      );

      expect(
        events.any((event) => event.phase == AsrRequestPhase.uploading),
        isTrue,
      );
      expect(
        events.any((event) => event.phase == AsrRequestPhase.waiting),
        isTrue,
      );
      expect(
        events.any((event) => event.phase == AsrRequestPhase.receiving),
        isTrue,
      );
      expect(
        events.any((event) => event.phase == AsrRequestPhase.responseReceived),
        isTrue,
      );
      final completedChunks = events
          .where((event) => event.phase == AsrRequestPhase.chunkCompleted)
          .toList();
      expect(completedChunks, hasLength(adapter.calls.length));
      expect(completedChunks.first.chunkIndex, 1);
      expect(completedChunks.last.chunkIndex, adapter.calls.length);
      service.close();
    },
  );
}
