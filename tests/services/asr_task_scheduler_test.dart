import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/services/asr_result_saver.dart';
import 'package:stroom/services/asr_retry_storage.dart';
import 'package:stroom/services/asr_service.dart';
import 'package:stroom/services/asr_task_scheduler.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/audio_utils.dart';
import 'package:stroom/utils/audio_chunker.dart';
import 'package:stroom/utils/text_manifest.dart';

const _config = AsrConfig(apiKey: 'key', host: 'https://asr.test/transcribe');

class _ControlledAdapter implements HttpClientAdapter {
  _ControlledAdapter({
    this.holdFirstResponse = false,
    this.failures = const [],
    this.failureMessages = const [],
    this.responseStatuses = const [],
    this.responseBodyForCall,
    this.beforeResponse,
    this.exceptionForCall,
  });

  final bool holdFirstResponse;
  final List<DioExceptionType?> failures;
  final List<String> failureMessages;
  final List<int> responseStatuses;
  final String Function(int index)? responseBodyForCall;
  final FutureOr<void> Function(int index)? beforeResponse;
  final DioException? Function(RequestOptions options, int index)?
      exceptionForCall;
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
        message: index < failureMessages.length
            ? failureMessages[index]
            : 'test connection timeout',
      );
    }
    if (requestStream != null) {
      await for (final _ in requestStream) {}
    }
    if (!requestStarted.isCompleted) requestStarted.complete();
    final injectedException = exceptionForCall?.call(options, index);
    if (injectedException != null) throw injectedException;
    if (failure != null) {
      throw DioException(
        requestOptions: options,
        type: failure,
        message: index < failureMessages.length
            ? failureMessages[index]
            : 'test $failure',
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
    await beforeResponse?.call(index);
    return ResponseBody.fromString(
      responseBodyForCall?.call(index) ??
          jsonEncode({'text': 'recognized ${index + 1}'}),
      index < responseStatuses.length ? responseStatuses[index] : 200,
      headers: {
        Headers.contentTypeHeader: [
          responseBodyForCall == null
              ? Headers.jsonContentType
              : 'text/plain; charset=utf-8',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _UriValidatingAdapter extends _ControlledAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    final uri = options.uri;
    if (!uri.isAbsolute ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.unknown,
        error: FormatException('Invalid request URI'),
      );
    }
    return super.fetch(options, requestStream, cancelFuture);
  }
}

class _MemoryRetryAdapter implements AsrRetryStorageAdapter {
  final Map<String, Uint8List> files = {};
  Completer<void>? writeEntered;
  Completer<void>? releaseWrite;
  Completer<void>? checkpointWriteEntered;
  Completer<void>? releaseCheckpointWrite;
  bool failNextWrite = false;
  int? failWriteAt;
  int writeCount = 0;

  @override
  Future<void> write(String key, Uint8List bytes) async {
    writeCount++;
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('simulated retry audio write failure');
    }
    if (writeCount == failWriteAt) {
      throw StateError('simulated retry audio write failure');
    }
    files[key] = Uint8List.fromList(bytes);
    if (writeEntered != null && !writeEntered!.isCompleted) {
      writeEntered!.complete();
    }
    await releaseWrite?.future;
    if (key.endsWith('.chunks')) {
      if (checkpointWriteEntered != null &&
          !checkpointWriteEntered!.isCompleted) {
        checkpointWriteEntered!.complete();
      }
      await releaseCheckpointWrite?.future;
    }
  }

  @override
  Future<Uint8List?> read(String key) async =>
      files[key] == null ? null : Uint8List.fromList(files[key]!);

  @override
  Future<void> delete(String key) async {
    files.remove(key);
  }

  @override
  Future<List<String>> keysWithPrefix(String prefix) async =>
      files.keys.where((key) => key.startsWith(prefix)).toList();
}

class _FailOnceOnSuccessfulChunkCheckpoint extends BackgroundTaskNotifier {
  _FailOnceOnSuccessfulChunkCheckpoint({this.failureCount = 1});

  final int failureCount;
  int failedCheckpoints = 0;

  @override
  Future<bool> setRetryDataAndWaitForGeneration(
    String taskId,
    BackgroundTask taskGeneration,
    Map<String, dynamic>? retryData,
  ) {
    final chunks = retryData?['chunks'];
    final includesSuccess = chunks is List &&
        chunks.any(
          (chunk) =>
              chunk is Map && chunk['status'] == AsrChunkStatus.succeeded.name,
        );
    if (failedCheckpoints < failureCount && includesSuccess) {
      failedCheckpoints++;
      state = state.map((task) {
        if (task.id != taskId || !task.hasSameGenerationAs(taskGeneration)) {
          return task;
        }
        return task.copyWith(retryData: retryData);
      }).toList();
      return Future<bool>.value(false);
    }
    return super.setRetryDataAndWaitForGeneration(
      taskId,
      taskGeneration,
      retryData,
    );
  }
}

void main() {
  late Directory directory;
  late BackgroundTaskNotifier notifier;
  late AsrRetryAudioStore retryStore;
  late _MemoryRetryAdapter retryFiles;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
    directory = await Directory.systemTemp.createTemp('asr_scheduler_');
    BackgroundTaskNotifier.debugStorageDirectoryOverride = directory.path;
    notifier = BackgroundTaskNotifier();
    await notifier.restoreFromPersistence();
    retryFiles = _MemoryRetryAdapter();
    retryStore = AsrRetryAudioStore(adapter: retryFiles);
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
    void Function()? onSaved,
    String? sourceTaskId,
    BackgroundTaskNotifier? taskNotifier,
  }) {
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    return AsrTaskScheduler(
      notifier: taskNotifier ?? notifier,
      config: config,
      audios: audios,
      saveFolder: 'captured-folder',
      modelReference: const {'configId': 'config', 'modelId': 'model'},
      sourceTaskId: sourceTaskId,
      retryStore: retryStore,
      serviceFactory: (config) => AsrService(config: config, dio: dio),
      writeText: writeText,
      onSaved: onSaved,
    );
  }

  String srtTime(double seconds) {
    final milliseconds = (seconds * 1000).round();
    final hours = milliseconds ~/ 3600000;
    final minutes = (milliseconds ~/ 60000) % 60;
    final wholeSeconds = (milliseconds ~/ 1000) % 60;
    final fraction = milliseconds % 1000;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${wholeSeconds.toString().padLeft(2, '0')},'
        '${fraction.toString().padLeft(3, '0')}';
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
    expect(retryFiles.files, isEmpty);
  });

  test(
    'credential-shaped local file names are not persisted in task JSON',
    () async {
      final adapter = _ControlledAdapter(
        failures: [DioExceptionType.connectionTimeout],
      );
      const secretName = 'sk-abcdefghijklmnop.wav';
      final run = scheduler(adapter, audios: [audio(secretName)]);

      await run.start();

      final task = notifier.state.single;
      final persistedTask = jsonEncode(task.toMap());
      expect(persistedTask, isNot(contains('sk-abcdefghijklmnop')));
      expect(task.title, 'ASR_audio.wav');
      expect((task.retryData!['audioReference'] as Map)['name'], 'audio.wav');
    },
  );

  test(
    'a removed queued job cannot claim a same-ID replacement task',
    () async {
      final adapter = _ControlledAdapter(holdFirstResponse: true);
      final run = scheduler(
        adapter,
        audios: [audio('one.wav'), audio('removed.wav')],
      );
      final execution = run.start();
      final taskIds = run.taskIds;
      await adapter.requestStarted.future.timeout(const Duration(seconds: 5));

      final removal = notifier.removeTasksPersisted([taskIds[1]]);
      final replacementId = notifier.addTask(
        type: BackgroundTaskType.asr,
        title: 'replacement.wav',
        retryData: {'source': 'replacement'},
        startImmediately: false,
        taskId: taskIds[1],
      );
      expect(replacementId, taskIds[1]);
      expect(await removal, isTrue);

      adapter.releaseResponse.complete();
      await execution;

      final replacement = notifier.taskById(replacementId)!;
      expect(replacement.status, TaskStatus.waiting);
      expect(adapter.calls, hasLength(1));
    },
  );

  test(
    'retry input persistence cannot overwrite a same-ID replacement task',
    () async {
      retryFiles.writeEntered = Completer<void>();
      retryFiles.releaseWrite = Completer<void>();
      final adapter = _ControlledAdapter();
      final run = scheduler(adapter, audios: [audio('old.wav')]);
      final execution = run.start();
      await retryFiles.writeEntered!.future.timeout(const Duration(seconds: 5));
      final taskId = run.taskIds.single;

      final removal = notifier.removeTasksPersisted([taskId]);
      final replacementRetryData = {'source': 'replacement'};
      notifier.addTask(
        type: BackgroundTaskType.asr,
        title: 'replacement.wav',
        retryData: replacementRetryData,
        startImmediately: false,
        taskId: taskId,
      );
      expect(await removal, isTrue);

      retryFiles.releaseWrite!.complete();
      await execution;
      await notifier.pendingPersistence;

      expect(notifier.taskById(taskId)!.retryData, replacementRetryData);
      expect(notifier.taskById(taskId)!.status, TaskStatus.waiting);
      expect(adapter.calls, isEmpty);
      expect(retryFiles.files, isEmpty);
    },
  );

  test('retry input is durable before the provider request starts', () async {
    retryFiles.writeEntered = Completer<void>();
    retryFiles.releaseWrite = Completer<void>();
    final adapter = _ControlledAdapter(holdFirstResponse: true);
    final run = scheduler(adapter, audios: [audio('durable.wav')]);
    final execution = run.start();
    await retryFiles.writeEntered!.future.timeout(const Duration(seconds: 5));

    expect(adapter.calls, isEmpty);
    retryFiles.releaseWrite!.complete();
    await adapter.requestStarted.future.timeout(const Duration(seconds: 5));
    await notifier.pendingPersistence;

    final task = notifier.taskById(run.taskIds.single)!;
    expect(task.retryData!['version'], 2);
    expect(task.retryData!.containsKey('audioReference'), isTrue);
    adapter.releaseResponse.complete();
    await execution;
  });
  test(
    'local audio names redact the configured API key from retry tasks',
    () async {
      const configuredApiKey = 'c8r-f2m-v7q-k4n-p9x-3bh';
      final adapter = _ControlledAdapter(
        failures: [DioExceptionType.connectionTimeout],
      );
      final run = scheduler(
        adapter,
        audios: [audio('$configuredApiKey.wav')],
        config: AsrConfig(
          apiKey: configuredApiKey,
          host: 'https://asr.test/transcribe',
        ),
      );

      await run.start();

      final task = notifier.taskById(run.taskIds.single)!;
      final reference = task.retryData!['audioReference'] as Map;
      final persistedTask = jsonEncode(task.toMap());
      expect(persistedTask, isNot(contains(configuredApiKey)));
      expect(task.title, 'ASR_audio.wav');
      expect(reference['name'], 'audio.wav');
    },
  );

  test(
    'configured API keys echoed in chunk transcripts are not persisted',
    () async {
      const configuredApiKey = 'earth-blue-7';
      final config = AsrConfig(
        apiKey: configuredApiKey,
        host: 'https://asr.test/transcribe',
        typeConfig: {'enableResponseFormat': true, 'responseFormat': 'srt'},
        maxFileSizeBytes: 12000,
        chunking: 'fixedSize',
        fallbackMethod: 'generic',
      );
      final wav = pcmToWav(Uint8List(32000));
      final adapter = _ControlledAdapter(
        failures: [null, DioExceptionType.connectionTimeout],
        responseBodyForCall: (index) => '1\n00:00:00,000 --> 00:00:00,100\n'
            'recognized $configuredApiKey chunk ${index + 1}\n',
      );
      final run = scheduler(
        adapter,
        audios: [AsrTaskAudio(bytes: wav, name: 'echo.wav')],
        config: config,
      );

      await run.start();

      expect(adapter.calls, hasLength(3));
      final task = notifier.taskById(run.taskIds.single)!;
      expect(task.status, TaskStatus.failed);
      for (final bytes in retryFiles.files.values) {
        expect(
          utf8.decode(bytes, allowMalformed: true),
          isNot(contains(configuredApiKey)),
        );
      }
      expect(jsonEncode(task.retryData), isNot(contains(configuredApiKey)));
    },
  );

  test(
    'failed task errors redact configured API keys embedded in request URIs',
    () async {
      const configuredApiKey = 'c8r-f2m-v7q-k4n-p9x-3bh';
      final adapter = _ControlledAdapter();
      final run = scheduler(
        adapter,
        audios: [audio('failure.wav')],
        config: AsrConfig(
          apiKey: configuredApiKey,
          host: 'https://asr.test/transcribe/$configuredApiKey',
        ),
        writeText: (fileName, text, {beforeCommit}) async {
          throw StateError(
            'request failed at https://asr.test/transcribe/$configuredApiKey',
          );
        },
      );

      await run.start();

      final task = notifier.taskById(run.taskIds.single)!;
      expect(task.status, TaskStatus.failed);
      expect(task.error, isNot(contains(configuredApiKey)));
      expect(jsonEncode(task.toMap()), isNot(contains(configuredApiKey)));
    },
  );

  test(
    'restart retains retry references and never starts a second request',
    () async {
      final adapter = _ControlledAdapter(holdFirstResponse: true);
      final run = scheduler(adapter, audios: [audio('restart.wav')]);
      final execution = run.start();
      await adapter.requestStarted.future.timeout(const Duration(seconds: 5));
      await notifier.pendingPersistence;

      final restored = BackgroundTaskNotifier();
      await restored.restoreFromPersistence();

      expect(restored.state, hasLength(1));
      expect(restored.state.single.status, TaskStatus.failed);
      expect(restored.state.single.error, '应用重启，已中断');
      expect(restored.state.single.retryData!['version'], 2);
      expect(restored.state.single.retryData, isNot(contains('audios')));
      expect(adapter.calls, hasLength(1));

      notifier.cancelTask(run.taskIds.single);
      await adapter.cancelObserved.future.timeout(const Duration(seconds: 5));
      await execution;
      if (restored.mounted) restored.dispose();
      await restored.pendingPersistence;
    },
  );

  test('does not send a request when retry task persistence fails', () async {
    final blockedRoot = File('${directory.path}/blocked-root');
    await blockedRoot.writeAsString('not a directory');
    BackgroundTaskNotifier.debugStorageDirectoryOverride = blockedRoot.path;
    final adapter = _ControlledAdapter();
    final run = scheduler(adapter, audios: [audio('not-durable.wav')]);

    await run.start().timeout(const Duration(seconds: 5));

    expect(adapter.calls, isEmpty);
    expect(notifier.state.single.status, TaskStatus.failed);
    expect(notifier.state.single.error, contains('无法保存 ASR 重试音频'));
    expect(notifier.state.single.retryData, isNull);
    expect(retryFiles.files, isEmpty);
  });

  test(
    'concurrent pruning preserves audio until its retry reference is saved',
    () async {
      final writeEntered = Completer<void>();
      final releaseWrite = Completer<void>();
      retryFiles.writeEntered = writeEntered;
      retryFiles.releaseWrite = releaseWrite;
      final adapter = _ControlledAdapter(holdFirstResponse: true);
      final run = scheduler(adapter, audios: [audio('prune-race.wav')]);

      final execution = run.start();
      await writeEntered.future.timeout(const Duration(seconds: 5));
      await AsrRetryAudioStore(adapter: retryFiles).prune(() => <String>{});
      final retainedDuringWrite = retryFiles.files.length == 1;
      releaseWrite.complete();

      if (retainedDuringWrite) {
        await adapter.requestStarted.future.timeout(const Duration(seconds: 5));
        notifier.cancelTask(run.taskIds.single);
        await adapter.cancelObserved.future.timeout(const Duration(seconds: 5));
      }
      await execution;

      expect(retainedDuringWrite, isTrue);
      expect(notifier.state.single.status, TaskStatus.failed);
    },
  );

  test(
    'new tasks do not prune retry audio before persisted tasks restore',
    () async {
      const previousTaskAudioId = 'cccccccccccccccccccccccccccccccc';
      final previousTaskAudioPath =
          'background/asr_retry/$previousTaskAudioId.audio';
      retryFiles.files[previousTaskAudioPath] = Uint8List.fromList([9, 9, 9]);
      final pendingNotifier = BackgroundTaskNotifier();
      addTearDown(() async {
        if (pendingNotifier.mounted) pendingNotifier.dispose();
        await pendingNotifier.pendingPersistence;
      });
      final adapter = _ControlledAdapter();
      final run = scheduler(
        adapter,
        audios: [audio('startup-race.wav')],
        taskNotifier: pendingNotifier,
      );

      await run.start().timeout(const Duration(seconds: 5));

      expect(pendingNotifier.tasks.single.status, TaskStatus.completed);
      expect(retryFiles.files, contains(previousTaskAudioPath));
      expect(pendingNotifier.retryAudioCleanupSafe, isFalse);
    },
  );

  test(
    'removing a task during its audio save prunes the late orphan',
    () async {
      const unrelatedRetryAudioId = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      retryFiles.files['background/asr_retry/$unrelatedRetryAudioId.audio'] =
          Uint8List.fromList([9, 9, 9]);
      retryFiles.writeEntered = Completer<void>();
      retryFiles.releaseWrite = Completer<void>();
      final adapter = _ControlledAdapter();
      final run = scheduler(
        adapter,
        audios: [audio('removed-during-save.wav')],
      );
      final execution = run.start();
      await retryFiles.writeEntered!.future.timeout(const Duration(seconds: 5));

      notifier.removeTask(run.taskIds.single);
      await notifier.pendingPersistence;
      retryFiles.releaseWrite!.complete();
      await execution;

      expect(adapter.calls, isEmpty);
      expect(retryFiles.files.keys, [
        'background/asr_retry/$unrelatedRetryAudioId.audio',
      ]);
    },
  );

  test(
    'removing a retry child during preparation updates its source snapshot',
    () async {
      const firstAudio = [1, 2, 3];
      const secondAudio = [4, 5, 6];
      final sourceTaskId = notifier.addTask(
        type: BackgroundTaskType.asr,
        title: 'legacy batch',
        retryData: {
          'audios': [
            {
              'bytes': base64Encode(firstAudio),
              'name': 'one.wav',
              'format': 'wav',
            },
            {
              'bytes': base64Encode(secondAudio),
              'name': 'two.wav',
              'format': 'wav',
            },
          ],
        },
      );
      notifier.failTask(sourceTaskId, error: 'previous failure');
      retryFiles.writeEntered = Completer<void>();
      retryFiles.releaseWrite = Completer<void>();
      final adapter = _ControlledAdapter();
      final run = scheduler(
        adapter,
        audios: [
          audio('one.wav'),
          AsrTaskAudio(bytes: Uint8List.fromList(secondAudio), name: 'two.wav'),
        ],
        sourceTaskId: sourceTaskId,
      );
      final execution = run.start();
      await retryFiles.writeEntered!.future.timeout(const Duration(seconds: 5));

      notifier.removeTask(run.taskIds.first);
      await notifier.pendingPersistence;
      retryFiles.releaseWrite!.complete();
      await execution;

      expect(adapter.calls, hasLength(1));
      expect(notifier.taskById(sourceTaskId)!.retryData, isNull);
    },
  );

  test(
    'removing a queued retry child before preparation updates its source snapshot',
    () async {
      const firstAudio = [1, 2, 3];
      const secondAudio = [4, 5, 6];
      final sourceTaskId = notifier.addTask(
        type: BackgroundTaskType.asr,
        title: 'legacy batch',
        retryData: {
          'audios': [
            {
              'bytes': base64Encode(firstAudio),
              'name': 'one.wav',
              'format': 'wav',
            },
            {
              'bytes': base64Encode(secondAudio),
              'name': 'two.wav',
              'format': 'wav',
            },
          ],
        },
      );
      notifier.failTask(sourceTaskId, error: 'previous failure');
      retryFiles.writeEntered = Completer<void>();
      retryFiles.releaseWrite = Completer<void>();
      final adapter = _ControlledAdapter(holdFirstResponse: true);
      final run = scheduler(
        adapter,
        audios: [
          audio('one.wav'),
          AsrTaskAudio(bytes: Uint8List.fromList(secondAudio), name: 'two.wav'),
        ],
        sourceTaskId: sourceTaskId,
      );
      final execution = run.start();
      await retryFiles.writeEntered!.future.timeout(const Duration(seconds: 5));

      notifier.removeTask(run.taskIds[1]);
      await notifier.pendingPersistence;
      retryFiles.releaseWrite!.complete();
      await adapter.requestStarted.future.timeout(const Duration(seconds: 5));
      adapter.releaseResponse.complete();
      await execution;

      expect(adapter.calls, hasLength(1));
      expect(
        notifier.taskById(sourceTaskId)!.retryData,
        isNull,
        reason: 'a removed child must not keep its audio in source retry data',
      );
    },
  );

  test(
    'task and step errors redact credential paths from provider failures',
    () async {
      const opaqueSecret = 'opaque-scheduler-path-secret';
      final adapter = _ControlledAdapter(
        failures: [DioExceptionType.connectionTimeout],
        failureMessages: [
          'provider failed at /transcribe/api_key/$opaqueSecret',
        ],
      );
      final run = scheduler(adapter, audios: [audio('redacted-error.wav')]);

      await run.start();

      final task = notifier.taskById(run.taskIds.single)!;
      final persistedErrors = [
        task.error,
        for (final step in task.steps)
          if (step.error != null) step.error,
      ].join(' ');
      expect(persistedErrors, isNot(contains(opaqueSecret)));
      expect(persistedErrors, contains('/transcribe/api_key'));
    },
  );

  test(
    'request diagnostics omit configured API key values from custom params',
    () async {
      const configuredApiKey = 'c8r-f2m-v7q-k4n-p9x-3bh';
      final adapter = _ControlledAdapter(
        failures: [DioExceptionType.connectionTimeout],
      );
      final run = scheduler(
        adapter,
        audios: [audio('diagnostic-api-key.wav')],
        config: AsrConfig(
          apiKey: configuredApiKey,
          host: 'https://asr.test/$configuredApiKey',
          customParams: [
            CustomParam(
              paramName: 'x-client-meta',
              defaultValue: configuredApiKey,
            ),
            CustomParam(paramName: 'mode', defaultValue: 'fast'),
          ],
        ),
      );

      await run.start();

      final task = notifier.taskById(run.taskIds.single)!;
      final diagnostics = jsonEncode(task.rawRequest);
      expect(diagnostics, isNot(contains(configuredApiKey)));
      expect(jsonEncode(task.toMap()), isNot(contains(configuredApiKey)));
      expect(diagnostics, contains('fast'));
    },
  );

  test(
    'URL retry records redact credentials and require source reselection',
    () async {
      const secrets = [
        'opaque-userinfo-secret',
        'opaque-query-secret',
        'opaque-url-path-secret',
        'opaque-fragment-secret',
      ];
      const url =
          'https://user:opaque-userinfo-secret@media.example.test/audio/api_key/opaque-url-path-secret?api_key=opaque-query-secret#access_token=opaque-fragment-secret';
      final adapter = _ControlledAdapter(holdFirstResponse: true);
      final run = scheduler(
        adapter,
        audios: [AsrTaskAudio(bytes: Uint8List(0), name: url, format: 'url')],
      );
      final execution = run.start();
      await adapter.requestStarted.future.timeout(const Duration(seconds: 5));

      final task = notifier.taskById(run.taskIds.single)!;
      final reference = AsrAudioReference.fromMap(
        Map<String, dynamic>.from(task.retryData!['audioReference'] as Map),
      );
      final persisted = jsonEncode(task.toMap());
      for (final secret in secrets) {
        expect(persisted, isNot(contains(secret)));
      }
      expect(reference.requiresSourceReselection, isTrue);

      notifier.cancelTask(run.taskIds.single);
      await adapter.cancelObserved.future.timeout(const Duration(seconds: 5));
      await execution;

      final retryAdapter = _ControlledAdapter();
      final retry = scheduler(
        retryAdapter,
        audios: [
          AsrTaskAudio(
            bytes: Uint8List(0),
            name: reference.url!,
            format: 'url',
            audioReference: reference,
          ),
        ],
      );
      await retry.start();
      expect(retryAdapter.calls, isEmpty);
      expect(
        notifier.taskById(retry.taskIds.single)!.error,
        contains('请重新选择音频'),
      );
    },
  );

  test(
    'URL retry records redact the configured key and require reselection',
    () async {
      const apiKey = '0123456789abcdef0123456789abcdef';
      const url = 'https://media.example.test/audio/$apiKey';
      final adapter = _ControlledAdapter(holdFirstResponse: true);
      final run = scheduler(
        adapter,
        audios: [AsrTaskAudio(bytes: Uint8List(0), name: url, format: 'url')],
        config: const AsrConfig(
          apiKey: apiKey,
          host: 'https://asr.test/transcribe',
        ),
      );
      final execution = run.start();
      await adapter.requestStarted.future.timeout(const Duration(seconds: 5));

      final task = notifier.taskById(run.taskIds.single)!;
      final reference = task.retryData!['audioReference'] as Map;
      final persisted = jsonEncode(task.toMap());

      expect(persisted, isNot(contains(apiKey)));
      expect(task.title, isNot(contains(apiKey)));
      expect(reference['url'], isNot(contains(apiKey)));
      expect(reference['name'], isNot(contains(apiKey)));
      expect(reference['requiresSourceReselection'], isTrue);

      notifier.cancelTask(run.taskIds.single);
      await adapter.cancelObserved.future.timeout(const Duration(seconds: 5));
      await execution;
    },
  );

  test(
    'failed audio storage preserves legacy data and sends no jobs',
    () async {
      const firstAudio = [1, 2, 3];
      const secondAudio = [4, 5, 6];
      final sourceTaskId = notifier.addTask(
        type: BackgroundTaskType.asr,
        title: 'legacy batch',
        retryData: {
          'audios': [
            {
              'bytes': base64Encode(firstAudio),
              'name': 'one.wav',
              'format': 'wav',
            },
            {
              'bytes': base64Encode(secondAudio),
              'name': 'two.wav',
              'format': 'wav',
            },
          ],
        },
      );
      notifier.failTask(sourceTaskId, error: 'legacy failure');
      retryFiles.failNextWrite = true;
      final adapter = _ControlledAdapter();
      final run = scheduler(
        adapter,
        audios: [audio('one.wav'), audio('two.wav')],
        sourceTaskId: sourceTaskId,
      );

      await run.start();

      final sourceRetryData = notifier.taskById(sourceTaskId)!.retryData!;
      final legacyAudios = sourceRetryData['audios'] as List;
      expect(legacyAudios, hasLength(2));
      expect((legacyAudios.first as Map)['bytes'], base64Encode(firstAudio));
      expect((legacyAudios.last as Map)['bytes'], base64Encode(secondAudio));
      expect(adapter.calls, isEmpty);
    },
  );

  test(
    'multi-audio retry sends no jobs unless every input is durable',
    () async {
      final sourceTaskId = notifier.addTask(
        type: BackgroundTaskType.asr,
        title: 'legacy batch',
        retryData: {
          'audios': [
            {
              'bytes': base64Encode([1, 2, 3]),
              'name': 'one.wav',
              'format': 'wav',
            },
            {
              'bytes': base64Encode([4, 5, 6]),
              'name': 'two.wav',
              'format': 'wav',
            },
          ],
        },
      );
      notifier.failTask(sourceTaskId, error: 'legacy failure');
      retryFiles.failWriteAt = 2;
      final adapter = _ControlledAdapter();
      final run = scheduler(
        adapter,
        audios: [audio('one.wav'), audio('two.wav')],
        sourceTaskId: sourceTaskId,
      );

      await run.start();

      expect(adapter.calls, isEmpty);
      expect(
        run.taskIds.map((taskId) => notifier.taskById(taskId)!.status),
        everyElement(TaskStatus.failed),
      );
      final sourceRetryData = notifier.taskById(sourceTaskId)!.retryData!;
      expect(sourceRetryData['audios'], hasLength(2));
      expect(
        (sourceRetryData['audios'] as List).map(
          (audio) => (audio as Map)['bytes'],
        ),
        [
          base64Encode([1, 2, 3]),
          base64Encode([4, 5, 6]),
        ],
      );
      expect(
        run.taskIds.map((taskId) => notifier.taskById(taskId)!.retryData),
        everyElement(isNull),
      );
      expect(retryFiles.files, isEmpty);
    },
  );

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

  test('removing a failed task deletes only its retry audio', () async {
    final adapter = _ControlledAdapter(
      failures: [DioExceptionType.connectionTimeout],
    );
    final run = scheduler(adapter, audios: [audio('remove-retry.wav')]);

    await run.start();

    final taskId = run.taskIds.single;
    expect(notifier.taskById(taskId)!.status, TaskStatus.failed);
    expect(
      retryFiles.files.keys.where((key) => key.endsWith('.audio')),
      hasLength(1),
    );
    expect(
      retryFiles.files.keys.where((key) => key.endsWith('.chunks')),
      hasLength(1),
    );
    notifier.removeTask(taskId);
    await notifier.pendingPersistence;
    for (var attempt = 0;
        attempt < 100 && retryFiles.files.isNotEmpty;
        attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(retryFiles.files, isEmpty);
    expect(adapter.calls, hasLength(1));
  });

  test(
    'a multi-audio legacy retry migrates source data after storing every ref',
    () async {
      final legacyAudio = [1, 2, 3];
      final sourceTaskId = notifier.addTask(
        type: BackgroundTaskType.asr,
        title: 'legacy batch',
        retryData: {
          'audios': [
            {
              'bytes': base64Encode(legacyAudio),
              'name': 'one.wav',
              'format': 'wav',
            },
            {
              'bytes': base64Encode([4, 5, 6]),
              'name': 'two.wav',
              'format': 'wav',
            },
          ],
        },
      );
      notifier.failTask(sourceTaskId, error: 'legacy failure');
      final adapter = _ControlledAdapter(holdFirstResponse: true);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final run = AsrTaskScheduler(
        notifier: notifier,
        config: _config,
        audios: [audio('one.wav'), audio('two.wav')],
        saveFolder: 'captured-folder',
        modelReference: const {'configId': 'config', 'modelId': 'model'},
        sourceTaskId: sourceTaskId,
        retryStore: retryStore,
        serviceFactory: (config) => AsrService(config: config, dio: dio),
      );

      final execution = run.start();
      await adapter.requestStarted.future.timeout(const Duration(seconds: 5));

      final sourceRetryData = notifier.taskById(sourceTaskId)!.retryData!;
      expect(sourceRetryData['version'], 2);
      expect(sourceRetryData, isNot(contains('audios')));
      expect(
        jsonEncode(sourceRetryData),
        isNot(contains(base64Encode(legacyAudio))),
      );
      final references = sourceRetryData['audioReferences'] as List;
      expect(references, hasLength(2));
      expect(
        references.map((entry) => (entry as Map)['audioReference'] is Map),
        everyElement(isTrue),
      );

      notifier.cancelTask(run.taskIds.first);
      notifier.cancelTask(run.taskIds.last);
      await adapter.cancelObserved.future.timeout(const Duration(seconds: 5));
      adapter.releaseResponse.complete();
      await execution;
      expect(adapter.calls, hasLength(1));
    },
  );

  test('retrying a multi-audio source resends only failed audio', () async {
    final sourceTaskId = notifier.addTask(
      type: BackgroundTaskType.asr,
      title: 'legacy batch',
      retryData: {
        'audios': [
          {
            'bytes': base64Encode([1, 2, 3]),
            'name': 'one.wav',
            'format': 'wav',
          },
          {
            'bytes': base64Encode([4, 5, 6]),
            'name': 'two.wav',
            'format': 'wav',
          },
        ],
      },
    );
    notifier.failTask(sourceTaskId, error: 'legacy failure');
    final firstAdapter = _ControlledAdapter(
      failures: [null, DioExceptionType.connectionTimeout],
    );
    final firstRun = scheduler(
      firstAdapter,
      audios: [
        AsrTaskAudio(bytes: Uint8List.fromList([1, 2, 3]), name: 'one.wav'),
        AsrTaskAudio(bytes: Uint8List.fromList([4, 5, 6]), name: 'two.wav'),
      ],
      sourceTaskId: sourceTaskId,
    );

    await firstRun.start();

    expect(
      notifier.taskById(firstRun.taskIds.first)!.status,
      TaskStatus.completed,
    );
    expect(notifier.taskById(firstRun.taskIds.last)!.status, TaskStatus.failed);
    final sourceRetryData = notifier.taskById(sourceTaskId)!.retryData!;
    final retryAudios = <AsrTaskAudio>[];
    for (final value in sourceRetryData['audioReferences'] as List) {
      final item = Map<String, dynamic>.from(value as Map);
      final reference = AsrAudioReference.fromMap(
        Map<String, dynamic>.from(item['audioReference'] as Map),
      );
      retryAudios.add(
        AsrTaskAudio(
          bytes: await retryStore.load(reference),
          name: reference.name,
          format: reference.format,
          audioReference: reference,
          priorChunks: (item['chunks'] as List)
              .map(
                (chunk) => AsrChunkResult.fromMap(
                  Map<String, dynamic>.from(chunk as Map),
                ),
              )
              .toList(),
        ),
      );
    }
    final retryAdapter = _ControlledAdapter();
    final retryRun = scheduler(
      retryAdapter,
      audios: retryAudios,
      sourceTaskId: sourceTaskId,
    );

    await retryRun.start();

    expect(retryAdapter.calls, hasLength(1));
    expect(notifier.taskById(sourceTaskId)!.retryData, isNull);
  });

  test(
    'source retry ignores completed audio when clearing retry data fails',
    () async {
      final sourceTaskId = notifier.addTask(
        type: BackgroundTaskType.asr,
        title: 'legacy source',
        retryData: {
          'audios': [
            {
              'bytes': base64Encode([1, 2, 3]),
              'name': 'one.wav',
              'format': 'wav',
            },
          ],
        },
      );
      notifier.failTask(sourceTaskId, error: 'legacy failure');
      await notifier.pendingPersistence;

      final blockedRoot = File('${directory.path}/blocked-root');
      await blockedRoot.writeAsString('not a directory');
      final adapter = _ControlledAdapter(holdFirstResponse: true);
      final run = scheduler(
        adapter,
        audios: [audio('one.wav')],
        sourceTaskId: sourceTaskId,
        onSaved: () {
          // The child completion is queued to the durable file before this
          // callback. Fail only the subsequent source retry-data clear.
          BackgroundTaskNotifier.debugStorageDirectoryOverride =
              blockedRoot.path;
        },
      );

      final execution = run.start();
      await adapter.requestStarted.future.timeout(const Duration(seconds: 5));
      await notifier.pendingPersistence;
      adapter.releaseResponse.complete();
      await execution;
      await notifier.pendingPersistence;

      expect(
        notifier.taskById(run.taskIds.single)!.status,
        TaskStatus.completed,
      );
      expect(notifier.taskById(sourceTaskId)!.retryData, isNull);

      BackgroundTaskNotifier.debugStorageDirectoryOverride = directory.path;
      final restored = BackgroundTaskNotifier();
      await restored.restoreFromPersistence();
      await restored.pendingPersistence;
      addTearDown(() async {
        if (restored.mounted) restored.dispose();
        await restored.pendingPersistence;
      });

      final restoredSource = restored.taskById(sourceTaskId)!;
      final staleRetryData = restoredSource.retryData!;
      final reference = AsrAudioReference.fromMap(
        Map<String, dynamic>.from(staleRetryData['audioReference'] as Map),
      );
      expect(
        restored.taskById(run.taskIds.single)!.status,
        TaskStatus.completed,
      );
      expect(restored.taskById(run.taskIds.single)!.retryData, isNotNull);

      final retryAdapter = _ControlledAdapter();
      final retryDio = Dio()..httpClientAdapter = retryAdapter;
      addTearDown(() => retryDio.close(force: true));
      final retry = AsrTaskScheduler(
        notifier: restored,
        config: _config,
        audios: [
          AsrTaskAudio(
            bytes: await retryStore.load(reference),
            name: reference.name,
            format: reference.format,
            audioReference: reference,
          ),
        ],
        saveFolder: 'captured-folder',
        modelReference: const {'configId': 'config', 'modelId': 'model'},
        sourceTaskId: sourceTaskId,
        retryStore: retryStore,
        serviceFactory: (config) => AsrService(config: config, dio: retryDio),
      );

      await retry.start();

      expect(retryAdapter.calls, isEmpty);
      expect(restored.taskById(sourceTaskId)!.retryData, isNull);

      const changedModelSourceId = 'stale-source-with-changed-model';
      restored.addTask(
        type: BackgroundTaskType.asr,
        title: 'Retry with a different model',
        startImmediately: false,
        taskId: changedModelSourceId,
        retryData: staleRetryData,
      );
      await restored.pendingPersistence;

      final changedModelAdapter = _ControlledAdapter();
      final changedModelDio = Dio()..httpClientAdapter = changedModelAdapter;
      addTearDown(() => changedModelDio.close(force: true));
      final changedModelRetry = AsrTaskScheduler(
        notifier: restored,
        config: _config,
        audios: [
          AsrTaskAudio(
            bytes: await retryStore.load(reference),
            name: reference.name,
            format: reference.format,
            audioReference: reference,
          ),
        ],
        saveFolder: 'captured-folder',
        modelReference: const {
          'configId': 'different-config',
          'modelId': 'different-model',
        },
        sourceTaskId: changedModelSourceId,
        retryStore: retryStore,
        serviceFactory: (config) =>
            AsrService(config: config, dio: changedModelDio),
      );

      await changedModelRetry.start();

      expect(
        changedModelAdapter.calls,
        hasLength(1),
        reason:
            'a completed attempt with another stable model identity must not suppress this source audio',
      );
    },
  );

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
          maxFileSizeBytes: 12000,
          chunking: 'fixedSize',
          fallbackMethod: 'generic',
        ),
        dio: dio,
      );
      final wav = pcmToWav(Uint8List(32000));

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

  test(
    'post-response progress errors stay uncertain and block retry replay',
    () async {
      final adapter = _ControlledAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final service = AsrService(config: _config, dio: dio);
      final reportedChunks = <AsrChunkResult>[];

      Future<AsrChunkedTranscriptionException> transcribe({
        List<AsrChunkResult> priorChunks = const [],
      }) async {
        try {
          await service.transcribe(
            audioBytes: Uint8List.fromList([1, 2, 3]),
            audioFormat: 'wav',
            priorChunks: priorChunks,
            onProgress: (progress) {
              if (progress.phase == AsrRequestPhase.responseReceived) {
                throw StateError('response progress callback failed');
              }
            },
            onChunkResult: (chunk) async => reportedChunks.add(chunk),
          );
        } on AsrChunkedTranscriptionException catch (error) {
          return error;
        }
        fail('expected transcription to fail closed');
      }

      final failure = await transcribe();

      expect(failure.recoveryChunks, hasLength(1));
      expect(failure.recoveryChunks.single.status, AsrChunkStatus.uncertain);
      expect(reportedChunks.single.status, AsrChunkStatus.uncertain);
      expect(adapter.calls, hasLength(1));

      final retryFailure = await transcribe(
        priorChunks: failure.recoveryChunks,
      );

      expect(
        retryFailure.recoveryChunks.single.status,
        AsrChunkStatus.uncertain,
      );
      expect(adapter.calls, hasLength(1));
      service.close();
    },
  );

  test('cached successful chunks still emit completion progress', () async {
    final config = _config.copyWith(
      maxFileSizeBytes: 12000,
      chunking: 'fixedSize',
      fallbackMethod: 'generic',
    );
    final wav = pcmToWav(Uint8List(32000));
    final firstAdapter = _ControlledAdapter(
      failures: [null, DioExceptionType.connectionTimeout, null],
    );
    final firstDio = Dio()..httpClientAdapter = firstAdapter;
    addTearDown(() => firstDio.close(force: true));
    final firstService = AsrService(config: config, dio: firstDio);
    late AsrChunkedTranscriptionException incomplete;

    try {
      await firstService.transcribe(audioBytes: wav, audioFormat: 'wav');
      fail('expected the middle chunk to fail');
    } on AsrChunkedTranscriptionException catch (error) {
      incomplete = error;
    } finally {
      firstService.close();
    }

    final secondAdapter = _ControlledAdapter();
    final secondDio = Dio()..httpClientAdapter = secondAdapter;
    addTearDown(() => secondDio.close(force: true));
    final secondService = AsrService(config: config, dio: secondDio);
    final events = <AsrRequestProgress>[];

    await secondService.transcribe(
      audioBytes: wav,
      audioFormat: 'wav',
      priorChunks: incomplete.chunks,
      onProgress: events.add,
    );

    final completedChunks = events
        .where((event) => event.phase == AsrRequestPhase.chunkCompleted)
        .map((event) => event.chunkIndex)
        .toList();
    expect(completedChunks, [1, 2, 3]);
    expect(secondAdapter.calls, hasLength(1));
    secondService.close();
  });

  test('cached successful chunks without text are retried', () async {
    final config = _config.copyWith(
      maxFileSizeBytes: 12000,
      chunking: 'fixedSize',
      fallbackMethod: 'generic',
    );
    final wav = pcmToWav(Uint8List(32000));
    final firstAdapter = _ControlledAdapter();
    final firstDio = Dio()..httpClientAdapter = firstAdapter;
    addTearDown(() => firstDio.close(force: true));
    final firstService = AsrService(config: config, dio: firstDio);
    final savedChunks = <AsrChunkResult>[];

    await firstService.transcribe(
      audioBytes: wav,
      audioFormat: 'wav',
      onChunkResult: (chunk) async => savedChunks.add(chunk),
    );
    firstService.close();

    final missingTextMap = Map<String, dynamic>.from(savedChunks.first.toMap())
      ..remove('text');
    final nonStringTextMap = Map<String, dynamic>.from(
      savedChunks.first.toMap(),
    )..['text'] = 42;
    for (final malformedChunk in [missingTextMap, nonStringTextMap]) {
      final priorChunks = [...savedChunks];
      priorChunks[0] = AsrChunkResult.fromMap(malformedChunk);
      final retryAdapter = _ControlledAdapter();
      final retryDio = Dio()..httpClientAdapter = retryAdapter;
      addTearDown(() => retryDio.close(force: true));
      final retryService = AsrService(config: config, dio: retryDio);

      final retryResult = await retryService.transcribe(
        audioBytes: wav,
        audioFormat: 'wav',
        priorChunks: priorChunks,
      );

      expect(retryAdapter.calls, hasLength(1));
      expect(retryResult.text, contains('recognized 1'));
      retryService.close();
    }
  });

  test(
    'checkpoint callback failure cannot mark a successful chunk failed',
    () async {
      final adapter = _ControlledAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final service = AsrService(
        config: _config.copyWith(
          maxFileSizeBytes: 12000,
          chunking: 'fixedSize',
          fallbackMethod: 'generic',
        ),
        dio: dio,
      );
      final callbackError = Exception('simulated checkpoint write failure');
      final callbacks = <AsrChunkResult>[];

      await expectLater(
        service.transcribe(
          audioBytes: pcmToWav(Uint8List(32000)),
          audioFormat: 'wav',
          onChunkResult: (chunk) async {
            callbacks.add(chunk);
            if (callbacks.length == 2) {
              throw callbackError;
            }
          },
        ),
        throwsA(
          isA<AsrChunkedTranscriptionException>()
              .having(
                (error) => error.partialText,
                'partialText',
                'recognized 1 recognized 2',
              )
              .having((error) => error.cause, 'cause', same(callbackError)),
        ),
      );

      expect(callbacks, hasLength(2));
      expect(
        callbacks.map((chunk) => chunk.status),
        everyElement(AsrChunkStatus.succeeded),
      );
      expect(adapter.calls, hasLength(2));
      service.close();
    },
  );

  test(
    'repeated checkpoint write failures preserve completed chunks for restart retry',
    () async {
      final checkpointNotifier = _FailOnceOnSuccessfulChunkCheckpoint(
        failureCount: 2,
      );
      addTearDown(() async {
        if (checkpointNotifier.mounted) checkpointNotifier.dispose();
        await checkpointNotifier.pendingPersistence;
      });
      await checkpointNotifier.restoreFromPersistence();
      final config = _config.copyWith(
        maxFileSizeBytes: 12000,
        chunking: 'fixedSize',
        fallbackMethod: 'generic',
      );
      final wav = pcmToWav(Uint8List(32000));
      final firstAdapter = _ControlledAdapter();
      final firstDio = Dio()..httpClientAdapter = firstAdapter;
      addTearDown(() => firstDio.close(force: true));
      final first = AsrTaskScheduler(
        notifier: checkpointNotifier,
        config: config,
        audios: [AsrTaskAudio(bytes: wav, name: 'checkpoint.wav')],
        saveFolder: 'captured-folder',
        modelReference: const {'configId': 'config', 'modelId': 'model'},
        retryStore: retryStore,
        serviceFactory: (config) => AsrService(config: config, dio: firstDio),
      );

      await first.start();
      await checkpointNotifier.pendingPersistence;

      expect(checkpointNotifier.failedCheckpoints, 2);
      expect(firstAdapter.calls, hasLength(1));
      final failedTask = checkpointNotifier.taskById(first.taskIds.single)!;
      expect(failedTask.status, TaskStatus.failed);
      expect(failedTask.result, 'recognized 1');
      expect(failedTask.resultIsComplete, isFalse);
      final savedRetryData = failedTask.retryData!;
      final savedChunks = (savedRetryData['chunks'] as List)
          .map(
            (chunk) =>
                AsrChunkResult.fromMap(Map<String, dynamic>.from(chunk as Map)),
          )
          .toList();
      expect(savedChunks, hasLength(1));
      expect(savedChunks.single.status, AsrChunkStatus.succeeded);

      final restored = BackgroundTaskNotifier();
      addTearDown(() async {
        if (restored.mounted) restored.dispose();
        await restored.pendingPersistence;
      });
      await restored.restoreFromPersistence();
      final restoredTask = restored.taskById(failedTask.id)!;
      final retryData = restoredTask.retryData!;
      final reference = AsrAudioReference.fromMap(
        Map<String, dynamic>.from(retryData['audioReference'] as Map),
      );
      final priorChunks = (retryData['chunks'] as List)
          .map(
            (chunk) =>
                AsrChunkResult.fromMap(Map<String, dynamic>.from(chunk as Map)),
          )
          .toList();
      final secondAdapter = _ControlledAdapter();
      final secondDio = Dio()..httpClientAdapter = secondAdapter;
      addTearDown(() => secondDio.close(force: true));
      final retry = AsrTaskScheduler(
        notifier: restored,
        config: config,
        audios: [
          AsrTaskAudio(
            bytes: await retryStore.load(reference),
            name: reference.name,
            format: reference.format,
            audioReference: reference,
            priorChunks: priorChunks,
          ),
        ],
        saveFolder: 'captured-folder',
        modelReference: const {'configId': 'config', 'modelId': 'model'},
        sourceTaskId: restoredTask.id,
        retryStore: retryStore,
        serviceFactory: (config) => AsrService(config: config, dio: secondDio),
      );

      await retry.start();

      expect(secondAdapter.calls, hasLength(2));
    },
  );

  test(
    'restarted retry does not resend a chunk whose checkpoint could not persist',
    () async {
      final blockedRoot = File('${directory.path}/blocked-task-storage');
      await blockedRoot.writeAsString('not a directory');
      final config = _config.copyWith(
        maxFileSizeBytes: 12000,
        chunking: 'fixedSize',
        fallbackMethod: 'generic',
      );
      final wav = pcmToWav(Uint8List(32000));
      final firstAdapter = _ControlledAdapter(
        beforeResponse: (index) async {
          if (index == 0) {
            await notifier.pendingPersistence;
            BackgroundTaskNotifier.debugStorageDirectoryOverride =
                blockedRoot.path;
          }
        },
      );
      final first = AsrTaskScheduler(
        notifier: notifier,
        config: config,
        audios: [AsrTaskAudio(bytes: wav, name: 'uncertain.wav')],
        saveFolder: 'captured-folder',
        modelReference: const {'configId': 'config', 'modelId': 'model'},
        retryStore: retryStore,
        serviceFactory: (config) {
          final dio = Dio()..httpClientAdapter = firstAdapter;
          addTearDown(() => dio.close(force: true));
          return AsrService(config: config, dio: dio);
        },
      );

      await first.start();
      await notifier.pendingPersistence;
      expect(firstAdapter.calls, hasLength(1));

      BackgroundTaskNotifier.debugStorageDirectoryOverride = directory.path;
      final restored = BackgroundTaskNotifier();
      addTearDown(() async {
        if (restored.mounted) restored.dispose();
        await restored.pendingPersistence;
      });
      await restored.restoreFromPersistence();
      final interrupted = restored.taskById(first.taskIds.single)!;
      final retryData = interrupted.retryData!;
      final reference = AsrAudioReference.fromMap(
        Map<String, dynamic>.from(retryData['audioReference'] as Map),
      );
      final priorChunks = (retryData['chunks'] as List)
          .map(
            (chunk) =>
                AsrChunkResult.fromMap(Map<String, dynamic>.from(chunk as Map)),
          )
          .toList();
      final retryAdapter = _ControlledAdapter();
      final retryDio = Dio()..httpClientAdapter = retryAdapter;
      addTearDown(() => retryDio.close(force: true));
      final retry = AsrTaskScheduler(
        notifier: restored,
        config: config,
        audios: [
          AsrTaskAudio(
            bytes: await retryStore.load(reference),
            name: reference.name,
            format: reference.format,
            audioReference: reference,
            priorChunks: priorChunks,
          ),
        ],
        saveFolder: 'captured-folder',
        modelReference: const {'configId': 'config', 'modelId': 'model'},
        sourceTaskId: interrupted.id,
        retryStore: retryStore,
        serviceFactory: (config) => AsrService(config: config, dio: retryDio),
      );

      await retry.start();

      expect(retryAdapter.calls, hasLength(2));
    },
  );

  test(
    'sidecar write failure after response blocks retry after restart',
    () async {
      final blockedRoot = File('${directory.path}/blocked-task-storage');
      await blockedRoot.writeAsString('not a directory');
      final config = _config.copyWith(
        maxFileSizeBytes: 12000,
        chunking: 'fixedSize',
        fallbackMethod: 'generic',
      );
      final wav = pcmToWav(Uint8List(32000));
      late final AsrTaskScheduler first;
      final firstAdapter = _ControlledAdapter(
        beforeResponse: (index) async {
          if (index != 0) return;
          await notifier.pendingPersistence;
          expect(retryFiles.writeCount, 2);
          final retryData = notifier.taskById(first.taskIds.single)?.retryData;
          final referenceId = retryData!['audioReference']['id'] as String;
          final checkpointKey = 'background/asr_retry/$referenceId.chunks';
          final marker =
              jsonDecode(utf8.decode(retryFiles.files[checkpointKey]!))
                  as Map<String, dynamic>;
          final checkpoint =
              (marker['checkpoints'] as List).single as Map<String, dynamic>;
          expect(
            (checkpoint['chunks'] as List).single['status'],
            AsrChunkStatus.uncertain.name,
          );
          retryFiles.failWriteAt = retryFiles.writeCount + 1;
          BackgroundTaskNotifier.debugStorageDirectoryOverride =
              blockedRoot.path;
        },
      );
      first = AsrTaskScheduler(
        notifier: notifier,
        config: config,
        audios: [AsrTaskAudio(bytes: wav, name: 'sidecar-failure.wav')],
        saveFolder: 'captured-folder',
        modelReference: const {'configId': 'config', 'modelId': 'model'},
        retryStore: retryStore,
        serviceFactory: (config) {
          final dio = Dio()..httpClientAdapter = firstAdapter;
          addTearDown(() => dio.close(force: true));
          return AsrService(config: config, dio: dio);
        },
      );

      await first.start();
      await notifier.pendingPersistence;
      expect(firstAdapter.calls, hasLength(1));
      expect(retryFiles.writeCount, 3);
      final failedTask = notifier.taskById(first.taskIds.single)!;
      expect(failedTask.status, TaskStatus.failed);
      expect(failedTask.resultIsComplete, isFalse);
      expect(failedTask.error, contains('恢复记录写入失败'));

      BackgroundTaskNotifier.debugStorageDirectoryOverride = directory.path;
      notifier.dispose();
      notifier = BackgroundTaskNotifier();
      await notifier.restoreFromPersistence();
      final restoredTask = notifier.taskById(failedTask.id)!;
      final retryData = restoredTask.retryData!;
      final reference = AsrAudioReference.fromMap(
        Map<String, dynamic>.from(retryData['audioReference'] as Map),
      );
      final priorChunks = (retryData['chunks'] as List)
          .map(
            (chunk) =>
                AsrChunkResult.fromMap(Map<String, dynamic>.from(chunk as Map)),
          )
          .toList();
      final checkpoint = await retryStore.readChunkCheckpoint(
        reference,
        modelReference: const {'configId': 'config', 'modelId': 'model'},
      );
      expect(checkpoint!.chunks.single.status, AsrChunkStatus.uncertain);

      final retryAdapter = _ControlledAdapter();
      final retryDio = Dio()..httpClientAdapter = retryAdapter;
      addTearDown(() => retryDio.close(force: true));
      final retry = AsrTaskScheduler(
        notifier: notifier,
        config: config,
        audios: [
          AsrTaskAudio(
            bytes: await retryStore.load(reference),
            name: reference.name,
            format: reference.format,
            audioReference: reference,
            priorChunks: priorChunks,
          ),
        ],
        saveFolder: 'captured-folder',
        modelReference: const {'configId': 'config', 'modelId': 'model'},
        sourceTaskId: restoredTask.id,
        retryStore: retryStore,
        serviceFactory: (config) => AsrService(config: config, dio: retryDio),
      );

      await retry.start();

      expect(retryAdapter.calls, isEmpty);
      expect(notifier.taskById(retry.taskIds.single)?.error, contains('结果不确定'));
    },
  );

  test(
    'direct service retries do not submit a matching uncertain chunk',
    () async {
      final config = _config.copyWith(
        maxFileSizeBytes: 12000,
        chunking: 'fixedSize',
        fallbackMethod: 'generic',
      );
      final wav = pcmToWav(Uint8List(32000));
      final firstAdapter = _ControlledAdapter(
        failures: [DioExceptionType.receiveTimeout],
      );
      final firstDio = Dio()..httpClientAdapter = firstAdapter;
      addTearDown(() => firstDio.close(force: true));
      final firstService = AsrService(config: config, dio: firstDio);
      late AsrChunkedTranscriptionException uncertainAttempt;

      try {
        await firstService.transcribe(audioBytes: wav, audioFormat: 'wav');
        fail('expected the first chunk outcome to be uncertain');
      } on AsrChunkedTranscriptionException catch (error) {
        uncertainAttempt = error;
      } finally {
        firstService.close();
      }

      expect(uncertainAttempt.chunks, hasLength(1));
      expect(uncertainAttempt.chunks.single.status, AsrChunkStatus.uncertain);

      final retryAdapter = _ControlledAdapter();
      final retryDio = Dio()..httpClientAdapter = retryAdapter;
      addTearDown(() => retryDio.close(force: true));
      final retryService = AsrService(config: config, dio: retryDio);

      await expectLater(
        retryService.transcribe(
          audioBytes: wav,
          audioFormat: 'wav',
          priorChunks: uncertainAttempt.recoveryChunks,
        ),
        throwsA(isA<AsrChunkedTranscriptionException>()),
      );

      expect(retryAdapter.calls, isEmpty);
      retryService.close();
    },
  );

  test(
    'direct fail-closed retry preserves prior successful checkpoint text',
    () async {
      final config = _config.copyWith(
        maxFileSizeBytes: 12000,
        chunking: 'fixedSize',
        fallbackMethod: 'generic',
      );
      final wav = pcmToWav(Uint8List(32000));
      final adapter = _ControlledAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final service = AsrService(config: config, dio: dio);
      const priorChunks = [
        AsrChunkResult(
          index: 0,
          startSeconds: 0,
          endSeconds: 1,
          totalChunks: 2,
          planFingerprint:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          status: AsrChunkStatus.succeeded,
          text: 'durable first chunk',
        ),
        AsrChunkResult(
          index: 1,
          startSeconds: 1,
          endSeconds: 2,
          totalChunks: 2,
          planFingerprint:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          status: AsrChunkStatus.uncertain,
        ),
      ];

      await expectLater(
        service.transcribe(
          audioBytes: wav,
          audioFormat: 'wav',
          priorChunks: priorChunks,
        ),
        throwsA(
          isA<AsrChunkedTranscriptionException>().having(
            (error) => error.partialText,
            'partialText',
            'durable first chunk',
          ),
        ),
      );

      expect(adapter.calls, isEmpty);
      service.close();
    },
  );

  test('scheduled fail-closed retry keeps durable partial result text',
      () async {
    final adapter = _ControlledAdapter();
    final wav = pcmToWav(Uint8List(32000));
    const priorChunks = [
      AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 1,
        totalChunks: 2,
        planFingerprint:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        status: AsrChunkStatus.succeeded,
        text: 'durable first chunk',
      ),
      AsrChunkResult(
        index: 1,
        startSeconds: 1,
        endSeconds: 2,
        totalChunks: 2,
        planFingerprint:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        status: AsrChunkStatus.uncertain,
      ),
    ];
    final run = scheduler(
      adapter,
      audios: [
        AsrTaskAudio(
          bytes: wav,
          name: 'partial-retry.wav',
          priorChunks: priorChunks,
        ),
      ],
    );

    await run.start();

    expect(adapter.calls, isEmpty);
    final task = notifier.taskById(run.taskIds.single)!;
    expect(task.status, TaskStatus.failed);
    expect(task.error, contains('结果不确定'));
    expect(task.result, 'durable first chunk');
    expect(task.resultIsComplete, isFalse);
  });

  test(
    'direct service HTTP acceptance and server failures stay uncertain',
    () async {
      final config = _config.copyWith(
        maxFileSizeBytes: 12000,
        chunking: 'fixedSize',
        fallbackMethod: 'generic',
      );
      final wav = pcmToWav(Uint8List(32000));

      for (final statusCode in [200, 408, 500]) {
        final firstAdapter = _ControlledAdapter(
          exceptionForCall: (options, _) => DioException(
            requestOptions: options,
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: statusCode,
              data: {'text': 'provider may have accepted the request'},
            ),
            type: DioExceptionType.unknown,
            message: 'response processing failed after request submission',
          ),
        );
        final firstDio = Dio()..httpClientAdapter = firstAdapter;
        addTearDown(() => firstDio.close(force: true));
        final firstService = AsrService(config: config, dio: firstDio);
        late AsrChunkedTranscriptionException uncertainAttempt;

        try {
          await firstService.transcribe(audioBytes: wav, audioFormat: 'wav');
          fail('expected HTTP $statusCode to leave an uncertain chunk');
        } on AsrChunkedTranscriptionException catch (error) {
          uncertainAttempt = error;
        } finally {
          firstService.close();
        }

        expect(
          uncertainAttempt.chunks,
          isNotEmpty,
          reason: 'HTTP $statusCode does not prove the POST was not accepted',
        );
        expect(
          uncertainAttempt.chunks.every(
            (chunk) => chunk.status == AsrChunkStatus.uncertain,
          ),
          isTrue,
          reason: 'HTTP $statusCode outcomes must all remain uncertain',
        );

        final retryAdapter = _ControlledAdapter();
        final retryDio = Dio()..httpClientAdapter = retryAdapter;
        addTearDown(() => retryDio.close(force: true));
        final retryService = AsrService(config: config, dio: retryDio);

        await expectLater(
          retryService.transcribe(
            audioBytes: wav,
            audioFormat: 'wav',
            priorChunks: uncertainAttempt.recoveryChunks,
          ),
          throwsA(isA<AsrChunkedTranscriptionException>()),
        );

        expect(retryAdapter.calls, isEmpty);
        retryService.close();
      }
    },
  );

  test(
    'uncertain chunk outcomes are not submitted again after restart',
    () async {
      final config = _config.copyWith(
        maxFileSizeBytes: 12000,
        chunking: 'fixedSize',
        fallbackMethod: 'generic',
      );
      final wav = pcmToWav(Uint8List(32000));
      final firstAdapter = _ControlledAdapter(
        failures: [DioExceptionType.receiveTimeout],
      );
      final first = scheduler(
        firstAdapter,
        audios: [AsrTaskAudio(bytes: wav, name: 'uncertain.wav')],
        config: config,
      );

      await first.start();

      expect(firstAdapter.calls, hasLength(1));
      final failedTask = notifier.taskById(first.taskIds.single)!;
      expect(failedTask.status, TaskStatus.failed);
      expect(failedTask.retryData!['chunks'], hasLength(1));
      expect(
        (failedTask.retryData!['chunks'] as List).single['status'],
        AsrChunkStatus.uncertain.name,
      );
      expect(failedTask.error, contains('结果不确定'));

      await notifier.pendingPersistence;
      notifier.dispose();
      notifier = BackgroundTaskNotifier();
      await notifier.restoreFromPersistence();
      final restoredTask = notifier.taskById(failedTask.id)!;
      final retryData = restoredTask.retryData!;
      final reference = AsrAudioReference.fromMap(
        Map<String, dynamic>.from(retryData['audioReference'] as Map),
      );
      final priorChunks = (retryData['chunks'] as List)
          .map(
            (chunk) =>
                AsrChunkResult.fromMap(Map<String, dynamic>.from(chunk as Map)),
          )
          .toList();
      final retryAdapter = _ControlledAdapter();
      final retry = AsrTaskScheduler(
        notifier: notifier,
        config: config,
        audios: [
          AsrTaskAudio(
            bytes: await retryStore.load(reference),
            name: reference.name,
            format: reference.format,
            audioReference: reference,
            priorChunks: priorChunks,
          ),
        ],
        saveFolder: 'captured-folder',
        modelReference: const {'configId': 'config', 'modelId': 'model'},
        sourceTaskId: restoredTask.id,
        retryStore: retryStore,
        serviceFactory: (config) {
          final dio = Dio()..httpClientAdapter = retryAdapter;
          addTearDown(() => dio.close(force: true));
          return AsrService(config: config, dio: dio);
        },
      );

      await retry.start();

      expect(retryAdapter.calls, isEmpty);
      expect(
        notifier.taskById(retry.taskIds.single)!.error,
        contains('重新选择音频'),
      );
    },
  );

  test(
    'HTTP timeout and server errors are uncertain and are not replayed',
    () async {
      final config = _config.copyWith(
        maxFileSizeBytes: 12000,
        chunking: 'fixedSize',
        fallbackMethod: 'generic',
      );
      final wav = pcmToWav(Uint8List(32000));

      for (final status in [408, 503]) {
        for (final chunked in [false, true]) {
          final input = chunked ? wav : Uint8List.fromList([1, 2, 3]);
          final firstAdapter = _ControlledAdapter(responseStatuses: [status]);
          final first = scheduler(
            firstAdapter,
            audios: [
              AsrTaskAudio(
                bytes: input,
                name: 'uncertain-$status-${chunked ? 'chunked' : 'single'}.wav',
              ),
            ],
            config: config,
          );

          await first.start();

          expect(firstAdapter.calls, hasLength(1));
          final failedTask = notifier.taskById(first.taskIds.single)!;
          expect(failedTask.status, TaskStatus.failed);
          expect(
            (failedTask.retryData!['chunks'] as List).single['status'],
            AsrChunkStatus.uncertain.name,
            reason: 'HTTP $status may follow a request processed by the server',
          );

          await notifier.pendingPersistence;
          notifier.dispose();
          notifier = BackgroundTaskNotifier();
          await notifier.restoreFromPersistence();

          final restoredTask = notifier.taskById(failedTask.id)!;
          final retryData = restoredTask.retryData!;
          final reference = AsrAudioReference.fromMap(
            Map<String, dynamic>.from(retryData['audioReference'] as Map),
          );
          final priorChunks = (retryData['chunks'] as List)
              .map(
                (chunk) => AsrChunkResult.fromMap(
                  Map<String, dynamic>.from(chunk as Map),
                ),
              )
              .toList();
          final retryAdapter = _ControlledAdapter();
          final retry = AsrTaskScheduler(
            notifier: notifier,
            config: config,
            audios: [
              AsrTaskAudio(
                bytes: await retryStore.load(reference),
                name: reference.name,
                format: reference.format,
                audioReference: reference,
                priorChunks: priorChunks,
              ),
            ],
            saveFolder: 'captured-folder',
            modelReference: const {'configId': 'config', 'modelId': 'model'},
            sourceTaskId: restoredTask.id,
            retryStore: retryStore,
            serviceFactory: (config) {
              final dio = Dio()..httpClientAdapter = retryAdapter;
              addTearDown(() => dio.close(force: true));
              return AsrService(config: config, dio: dio);
            },
          );

          await retry.start();

          expect(retryAdapter.calls, isEmpty);
          expect(
            notifier.taskById(retry.taskIds.single)?.error,
            contains('结果不确定'),
          );
          await notifier.pendingPersistence;
        }
      }
    },
  );

  test(
    'cancellation during pre-request checkpoint write leaves chunk retryable',
    () async {
      retryFiles.checkpointWriteEntered = Completer<void>();
      retryFiles.releaseCheckpointWrite = Completer<void>();
      final config = _config.copyWith(
        maxFileSizeBytes: 12000,
        chunking: 'fixedSize',
        fallbackMethod: 'generic',
      );
      final wav = pcmToWav(Uint8List(32000));
      final firstAdapter = _ControlledAdapter();
      final first = scheduler(
        firstAdapter,
        audios: [AsrTaskAudio(bytes: wav, name: 'cancel-before-send.wav')],
        config: config,
      );
      final execution = first.start();
      await retryFiles.checkpointWriteEntered!.future.timeout(
        const Duration(seconds: 5),
      );

      final taskId = first.taskIds.single;
      notifier.cancelTask(taskId);
      retryFiles.releaseCheckpointWrite!.complete();
      await execution;

      expect(firstAdapter.calls, isEmpty);
      final cancelledTask = notifier.taskById(taskId)!;
      final reference = AsrAudioReference.fromMap(
        Map<String, dynamic>.from(
          cancelledTask.retryData!['audioReference'] as Map,
        ),
      );
      final checkpoint = await retryStore.readChunkCheckpoint(
        reference,
        modelReference: const {'configId': 'config', 'modelId': 'model'},
      );
      expect(checkpoint!.chunks.single.status, AsrChunkStatus.failed);

      final retryAdapter = _ControlledAdapter();
      final retry = AsrTaskScheduler(
        notifier: notifier,
        config: config,
        audios: [
          AsrTaskAudio(
            bytes: await retryStore.load(reference),
            name: reference.name,
            format: reference.format,
            audioReference: reference,
          ),
        ],
        saveFolder: 'captured-folder',
        modelReference: const {'configId': 'config', 'modelId': 'model'},
        retryStore: retryStore,
        serviceFactory: (config) {
          final dio = Dio()..httpClientAdapter = retryAdapter;
          addTearDown(() => dio.close(force: true));
          return AsrService(config: config, dio: dio);
        },
      );

      await retry.start();

      // No chunks had succeeded before cancellation, so the retry can submit
      // the complete three-chunk plan once.
      expect(retryAdapter.calls, hasLength(3));
      expect(
        notifier.taskById(retry.taskIds.single)?.status,
        TaskStatus.completed,
      );
    },
  );

  test(
    'URL connection timeouts remain retryable as definite failures',
    () async {
      const url = 'https://media.example.test/retryable.wav';
      final firstAdapter = _ControlledAdapter(
        failures: [DioExceptionType.connectionTimeout],
      );
      final first = scheduler(
        firstAdapter,
        audios: [AsrTaskAudio(bytes: Uint8List(0), name: url, format: 'url')],
      );

      await first.start();

      final failedTask = notifier.taskById(first.taskIds.single)!;
      expect(failedTask.status, TaskStatus.failed);
      expect(
        (failedTask.retryData!['chunks'] as List).single['status'],
        AsrChunkStatus.failed.name,
      );
      final retryData = failedTask.retryData!;
      final reference = AsrAudioReference.fromMap(
        Map<String, dynamic>.from(retryData['audioReference'] as Map),
      );
      final priorChunks = (retryData['chunks'] as List)
          .map(
            (chunk) =>
                AsrChunkResult.fromMap(Map<String, dynamic>.from(chunk as Map)),
          )
          .toList();
      final retryAdapter = _ControlledAdapter();
      final retry = scheduler(
        retryAdapter,
        audios: [
          AsrTaskAudio(
            bytes: Uint8List(0),
            name: reference.url!,
            format: 'url',
            audioReference: reference,
            priorChunks: priorChunks,
          ),
        ],
        sourceTaskId: failedTask.id,
      );

      await retry.start();

      expect(retryAdapter.calls, hasLength(1));
      expect(
        notifier.taskById(retry.taskIds.single)?.status,
        TaskStatus.completed,
      );
    },
  );

  test(
    'connection-refused socket errors remain retryable as definite failures',
    () async {
      final firstAdapter = _ControlledAdapter(
        exceptionForCall: (options, _) => DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const SocketException('Connection refused'),
        ),
      );
      final first = scheduler(
        firstAdapter,
        audios: [audio('connection-refused.wav')],
      );

      await first.start();

      final failedTask = notifier.taskById(first.taskIds.single)!;
      expect(failedTask.status, TaskStatus.failed);
      expect(
        (failedTask.retryData!['chunks'] as List).single['status'],
        AsrChunkStatus.failed.name,
      );
      final retryData = failedTask.retryData!;
      final reference = AsrAudioReference.fromMap(
        Map<String, dynamic>.from(retryData['audioReference'] as Map),
      );
      final priorChunks = (retryData['chunks'] as List)
          .map(
            (chunk) =>
                AsrChunkResult.fromMap(Map<String, dynamic>.from(chunk as Map)),
          )
          .toList();
      final retryAdapter = _ControlledAdapter();
      final retry = scheduler(
        retryAdapter,
        audios: [
          AsrTaskAudio(
            bytes: Uint8List.fromList([1, 2, 3]),
            name: reference.name,
            format: reference.format,
            audioReference: reference,
            priorChunks: priorChunks,
          ),
        ],
        sourceTaskId: failedTask.id,
      );

      await retry.start();

      expect(retryAdapter.calls, hasLength(1));
      expect(
        notifier.taskById(retry.taskIds.single)?.status,
        TaskStatus.completed,
      );
    },
  );

  test('uncertain URL outcomes are not replayed after restart', () async {
    final url = 'https://media.example.test/uncertain.wav';
    final firstAdapter = _ControlledAdapter(
      failures: [DioExceptionType.receiveTimeout],
    );
    final first = scheduler(
      firstAdapter,
      audios: [AsrTaskAudio(bytes: Uint8List(0), name: url, format: 'url')],
    );

    await first.start();

    expect(firstAdapter.calls, hasLength(1));
    final failedTask = notifier.taskById(first.taskIds.single)!;
    expect(failedTask.status, TaskStatus.failed);
    await notifier.pendingPersistence;
    notifier.dispose();
    notifier = BackgroundTaskNotifier();
    await notifier.restoreFromPersistence();
    final restoredTask = notifier.taskById(failedTask.id)!;
    final retryData = restoredTask.retryData!;
    final reference = AsrAudioReference.fromMap(
      Map<String, dynamic>.from(retryData['audioReference'] as Map),
    );
    final priorChunks = (retryData['chunks'] as List)
        .map(
          (chunk) =>
              AsrChunkResult.fromMap(Map<String, dynamic>.from(chunk as Map)),
        )
        .toList();
    final retryAdapter = _ControlledAdapter();
    final retry = scheduler(
      retryAdapter,
      audios: [
        AsrTaskAudio(
          bytes: Uint8List(0),
          name: reference.url!,
          format: 'url',
          audioReference: reference,
          priorChunks: priorChunks,
        ),
      ],
      sourceTaskId: restoredTask.id,
    );

    await retry.start();

    expect(retryAdapter.calls, isEmpty);
    expect(notifier.taskById(retry.taskIds.single)!.error, contains('结果不确定'));
  });

  test('URL success is reused after result-save failure and restart', () async {
    final url = 'https://media.example.test/success.wav';
    final firstAdapter = _ControlledAdapter();
    final first = scheduler(
      firstAdapter,
      audios: [AsrTaskAudio(bytes: Uint8List(0), name: url, format: 'url')],
      writeText: (fileName, text, {beforeCommit}) async {
        throw StateError('simulated transcript save failure');
      },
    );

    await first.start();

    expect(firstAdapter.calls, hasLength(1));
    final failedTask = notifier.taskById(first.taskIds.single)!;
    expect(failedTask.status, TaskStatus.failed);
    await notifier.pendingPersistence;
    notifier.dispose();
    notifier = BackgroundTaskNotifier();
    await notifier.restoreFromPersistence();
    final restoredTask = notifier.taskById(failedTask.id)!;
    final retryData = restoredTask.retryData!;
    final reference = AsrAudioReference.fromMap(
      Map<String, dynamic>.from(retryData['audioReference'] as Map),
    );
    final priorChunks = (retryData['chunks'] as List)
        .map(
          (chunk) =>
              AsrChunkResult.fromMap(Map<String, dynamic>.from(chunk as Map)),
        )
        .toList();
    final retryAdapter = _ControlledAdapter();
    final retry = scheduler(
      retryAdapter,
      audios: [
        AsrTaskAudio(
          bytes: Uint8List(0),
          name: reference.url!,
          format: 'url',
          audioReference: reference,
          priorChunks: priorChunks,
        ),
      ],
      sourceTaskId: restoredTask.id,
    );

    await retry.start();

    expect(retryAdapter.calls, isEmpty);
    expect(
      notifier.taskById(retry.taskIds.single)?.status,
      TaskStatus.completed,
    );
    final savedRecords = await TextManifest.loadRecords();
    expect(savedRecords, hasLength(1));
    expect(
      await TextManifest.readText(savedRecords.single.storageFileName),
      'recognized 1',
    );
  });

  test(
    'uncertain single-request outcomes are not replayed after restart',
    () async {
      final wav = pcmToWav(Uint8List(32000));
      final firstAdapter = _ControlledAdapter(
        failures: [DioExceptionType.receiveTimeout],
      );
      final first = scheduler(
        firstAdapter,
        audios: [AsrTaskAudio(bytes: wav, name: 'single-request.wav')],
      );

      await first.start();

      expect(firstAdapter.calls, hasLength(1));
      final failedTask = notifier.taskById(first.taskIds.single)!;
      expect(failedTask.status, TaskStatus.failed);
      await notifier.pendingPersistence;
      notifier.dispose();
      notifier = BackgroundTaskNotifier();
      await notifier.restoreFromPersistence();
      final restoredTask = notifier.taskById(failedTask.id)!;
      final retryData = restoredTask.retryData!;
      final reference = AsrAudioReference.fromMap(
        Map<String, dynamic>.from(retryData['audioReference'] as Map),
      );
      final priorChunks = (retryData['chunks'] as List)
          .map(
            (chunk) =>
                AsrChunkResult.fromMap(Map<String, dynamic>.from(chunk as Map)),
          )
          .toList();
      final retryAdapter = _ControlledAdapter();
      final retry = AsrTaskScheduler(
        notifier: notifier,
        config: _config,
        audios: [
          AsrTaskAudio(
            bytes: await retryStore.load(reference),
            name: reference.name,
            format: reference.format,
            audioReference: reference,
            priorChunks: priorChunks,
          ),
        ],
        saveFolder: 'captured-folder',
        modelReference: const {'configId': 'config', 'modelId': 'model'},
        sourceTaskId: restoredTask.id,
        retryStore: retryStore,
        serviceFactory: (config) {
          final dio = Dio()..httpClientAdapter = retryAdapter;
          addTearDown(() => dio.close(force: true));
          return AsrService(config: config, dio: dio);
        },
      );

      await retry.start();

      expect(retryAdapter.calls, isEmpty);
      expect(notifier.taskById(retry.taskIds.single)!.error, contains('结果不确定'));
    },
  );

  test('canceled submitted single-request outcomes remain uncertain', () async {
    final wav = pcmToWav(Uint8List(32000));
    final adapter = _ControlledAdapter(failures: [DioExceptionType.cancel]);
    final run = scheduler(
      adapter,
      audios: [AsrTaskAudio(bytes: wav, name: 'canceled-single-request.wav')],
    );

    await run.start();

    expect(adapter.calls, hasLength(1));
    final task = notifier.taskById(run.taskIds.single)!;
    expect(task.status, TaskStatus.failed);
    final reference = AsrAudioReference.fromMap(
      Map<String, dynamic>.from(task.retryData!['audioReference'] as Map),
    );
    final checkpoint = await retryStore.readChunkCheckpoint(
      reference,
      modelReference: const {'configId': 'config', 'modelId': 'model'},
      configuredApiKey: _config.apiKey,
    );
    expect(checkpoint!.chunks.single.status, AsrChunkStatus.uncertain);
  });

  test(
    'reselected provider checkpoint is cleared before transcription',
    () async {
      final wav = pcmToWav(Uint8List(32000));
      final reference = await retryStore.save(
        wav,
        name: 'changed-provider.wav',
        format: 'wav',
        configuredApiKey: _config.apiKey,
      );
      await retryStore.writeChunkCheckpoint(
        reference,
        [
          AsrChunkResult(
            index: 0,
            startSeconds: 0,
            endSeconds: parseWavHeader(wav).durationSeconds,
            totalChunks: 1,
            status: AsrChunkStatus.succeeded,
            text: 'old provider transcript',
          ),
        ],
        modelReference: const {'configId': 'config', 'modelId': 'model'},
        configuredApiKey: _config.apiKey,
      );
      final adapter = _ControlledAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final retry = AsrTaskScheduler(
        notifier: notifier,
        config: _config.copyWith(host: 'https://changed-asr.test/transcribe'),
        audios: [
          AsrTaskAudio(
            bytes: wav,
            name: reference.name,
            audioReference: reference,
            resetChunkCheckpoint: true,
          ),
        ],
        saveFolder: 'captured-folder',
        modelReference: const {'configId': 'config', 'modelId': 'model'},
        retryStore: retryStore,
        serviceFactory: (config) => AsrService(config: config, dio: dio),
      );

      await retry.start();

      expect(adapter.calls, hasLength(1));
      expect(notifier.taskById(retry.taskIds.single)!.result, 'recognized 1');
    },
  );

  test(
    'durable single-request results are reused after result-save failure and restart',
    () async {
      final wav = pcmToWav(Uint8List(32000));
      final firstAdapter = _ControlledAdapter();
      final first = scheduler(
        firstAdapter,
        audios: [AsrTaskAudio(bytes: wav, name: 'single-success.wav')],
        writeText: (fileName, text, {beforeCommit}) async {
          throw StateError('simulated transcript save failure');
        },
      );

      await first.start();

      expect(firstAdapter.calls, hasLength(1));
      final failedTask = notifier.taskById(first.taskIds.single)!;
      expect(failedTask.status, TaskStatus.failed);
      expect(
        (failedTask.retryData!['chunks'] as List).single['status'],
        AsrChunkStatus.succeeded.name,
      );
      await notifier.pendingPersistence;
      notifier.dispose();
      notifier = BackgroundTaskNotifier();
      await notifier.restoreFromPersistence();
      final restoredTask = notifier.taskById(failedTask.id)!;
      final retryData = restoredTask.retryData!;
      final reference = AsrAudioReference.fromMap(
        Map<String, dynamic>.from(retryData['audioReference'] as Map),
      );
      final priorChunks = (retryData['chunks'] as List)
          .map(
            (chunk) =>
                AsrChunkResult.fromMap(Map<String, dynamic>.from(chunk as Map)),
          )
          .toList();
      final retryAdapter = _ControlledAdapter();
      final retry = AsrTaskScheduler(
        notifier: notifier,
        config: _config,
        audios: [
          AsrTaskAudio(
            bytes: await retryStore.load(reference),
            name: reference.name,
            format: reference.format,
            audioReference: reference,
            priorChunks: priorChunks,
          ),
        ],
        saveFolder: 'captured-folder',
        modelReference: const {'configId': 'config', 'modelId': 'model'},
        sourceTaskId: restoredTask.id,
        retryStore: retryStore,
        serviceFactory: (config) {
          final dio = Dio()..httpClientAdapter = retryAdapter;
          addTearDown(() => dio.close(force: true));
          return AsrService(config: config, dio: dio);
        },
      );

      await retry.start();

      expect(retryAdapter.calls, isEmpty);
      expect(
        notifier.taskById(retry.taskIds.single)?.status,
        TaskStatus.completed,
      );
      final savedRecords = await TextManifest.loadRecords();
      expect(savedRecords, hasLength(1));
      expect(
        await TextManifest.readText(savedRecords.single.storageFileName),
        'recognized 1',
      );
    },
  );

  test(
    'single-request VTT checkpoint preserves original subtitle after save failure and restart',
    () async {
      const originalSubtitle =
          'WEBVTT\n\ncue-17\n00:00:00.000 --> 00:00:01.000 align:start\n'
          '<v Speaker><i>Hello</i></v>\n';
      final config = AsrConfig(
        apiKey: 'key',
        host: 'https://asr.test/transcribe',
        typeConfig: {'enableResponseFormat': true, 'responseFormat': 'vtt'},
      );
      final wav = pcmToWav(Uint8List(32000));
      final firstAdapter = _ControlledAdapter(
        responseBodyForCall: (_) => originalSubtitle,
      );
      final first = scheduler(
        firstAdapter,
        audios: [AsrTaskAudio(bytes: wav, name: 'single-subtitle.wav')],
        config: config,
        writeText: (fileName, text, {beforeCommit}) async {
          throw StateError('simulated transcript save failure');
        },
      );

      await first.start();

      expect(firstAdapter.calls, hasLength(1));
      final failedTask = notifier.taskById(first.taskIds.single)!;
      expect(failedTask.status, TaskStatus.failed);
      await notifier.pendingPersistence;
      notifier.dispose();
      notifier = BackgroundTaskNotifier();
      await notifier.restoreFromPersistence();
      final restoredTask = notifier.taskById(failedTask.id)!;
      final retryData = restoredTask.retryData!;
      final reference = AsrAudioReference.fromMap(
        Map<String, dynamic>.from(retryData['audioReference'] as Map),
      );
      final priorChunks = (retryData['chunks'] as List)
          .map(
            (chunk) =>
                AsrChunkResult.fromMap(Map<String, dynamic>.from(chunk as Map)),
          )
          .toList();
      final retryAdapter = _ControlledAdapter(
        responseBodyForCall: (_) => 'should not be requested',
      );
      final retry = AsrTaskScheduler(
        notifier: notifier,
        config: config,
        audios: [
          AsrTaskAudio(
            bytes: await retryStore.load(reference),
            name: reference.name,
            format: reference.format,
            audioReference: reference,
            priorChunks: priorChunks,
          ),
        ],
        saveFolder: 'captured-folder',
        modelReference: const {'configId': 'config', 'modelId': 'model'},
        sourceTaskId: restoredTask.id,
        retryStore: retryStore,
        serviceFactory: (config) {
          final dio = Dio()..httpClientAdapter = retryAdapter;
          addTearDown(() => dio.close(force: true));
          return AsrService(config: config, dio: dio);
        },
      );

      await retry.start();

      expect(retryAdapter.calls, isEmpty);
      final savedRecords = await TextManifest.loadRecords();
      expect(savedRecords, hasLength(1));
      expect(
        await TextManifest.readText(savedRecords.single.storageFileName),
        originalSubtitle,
      );
    },
  );

  test(
    'URL VTT checkpoint preserves original subtitle after save failure and restart',
    () async {
      const url = 'https://media.example.test/subtitle.wav';
      const originalSubtitle =
          'WEBVTT\n\ncue-18\n00:00:00.000 --> 00:00:01.000 align:start\n'
          '<v Speaker><i>Hello from URL</i></v>\n';
      final config = AsrConfig(
        apiKey: 'key',
        host: 'https://asr.test/transcribe',
        typeConfig: {'enableResponseFormat': true, 'responseFormat': 'vtt'},
      );
      final firstAdapter = _ControlledAdapter(
        responseBodyForCall: (_) => originalSubtitle,
      );
      final first = scheduler(
        firstAdapter,
        audios: [AsrTaskAudio(bytes: Uint8List(0), name: url, format: 'url')],
        config: config,
        writeText: (fileName, text, {beforeCommit}) async {
          throw StateError('simulated transcript save failure');
        },
      );

      await first.start();

      expect(firstAdapter.calls, hasLength(1));
      final failedTask = notifier.taskById(first.taskIds.single)!;
      expect(failedTask.status, TaskStatus.failed);
      await notifier.pendingPersistence;
      notifier.dispose();
      notifier = BackgroundTaskNotifier();
      await notifier.restoreFromPersistence();
      final restoredTask = notifier.taskById(failedTask.id)!;
      final retryData = restoredTask.retryData!;
      final reference = AsrAudioReference.fromMap(
        Map<String, dynamic>.from(retryData['audioReference'] as Map),
      );
      final priorChunks = (retryData['chunks'] as List)
          .map(
            (chunk) =>
                AsrChunkResult.fromMap(Map<String, dynamic>.from(chunk as Map)),
          )
          .toList();
      final retryAdapter = _ControlledAdapter(
        responseBodyForCall: (_) => 'should not be requested',
      );
      final retry = AsrTaskScheduler(
        notifier: notifier,
        config: config,
        audios: [
          AsrTaskAudio(
            bytes: Uint8List(0),
            name: reference.url!,
            format: 'url',
            audioReference: reference,
            priorChunks: priorChunks,
          ),
        ],
        saveFolder: 'captured-folder',
        modelReference: const {'configId': 'config', 'modelId': 'model'},
        sourceTaskId: restoredTask.id,
        retryStore: retryStore,
        serviceFactory: (config) {
          final dio = Dio()..httpClientAdapter = retryAdapter;
          addTearDown(() => dio.close(force: true));
          return AsrService(config: config, dio: dio);
        },
      );

      await retry.start();

      expect(retryAdapter.calls, isEmpty);
      final savedRecords = await TextManifest.loadRecords();
      expect(savedRecords, hasLength(1));
      expect(
        await TextManifest.readText(savedRecords.single.storageFileName),
        originalSubtitle,
      );
    },
  );

  test(
    'connection errors without a response stop further chunk requests',
    () async {
      final config = _config.copyWith(
        maxFileSizeBytes: 12000,
        chunking: 'fixedSize',
        fallbackMethod: 'generic',
      );
      final adapter = _ControlledAdapter(
        failures: List.filled(3, DioExceptionType.connectionError),
      );
      final run = scheduler(
        adapter,
        audios: [
          AsrTaskAudio(bytes: pcmToWav(Uint8List(32000)), name: 'reset.wav'),
        ],
        config: config,
      );

      await run.start();

      expect(adapter.calls, hasLength(1));
      final task = notifier.taskById(run.taskIds.single)!;
      expect(task.status, TaskStatus.failed);
      expect(task.retryData!['chunks'], hasLength(1));
      expect(
        (task.retryData!['chunks'] as List).single['status'],
        AsrChunkStatus.uncertain.name,
      );
      expect(task.error, contains('结果不确定'));
    },
  );

  test(
    'durable sidecar success overrides a stale failed task chunk on retry',
    () async {
      final config = _config.copyWith(
        maxFileSizeBytes: 12000,
        chunking: 'fixedSize',
        fallbackMethod: 'generic',
      );
      final wav = pcmToWav(Uint8List(32000));
      final firstAdapter = _ControlledAdapter(
        failures: [null, DioExceptionType.connectionTimeout, null],
      );
      final first = scheduler(
        firstAdapter,
        audios: [AsrTaskAudio(bytes: wav, name: 'stale-task-checkpoint.wav')],
        config: config,
      );

      await first.start();

      expect(firstAdapter.calls, hasLength(3));
      final failedTask = notifier.taskById(first.taskIds.single)!;
      expect(failedTask.status, TaskStatus.failed);
      final retryData = failedTask.retryData!;
      final reference = AsrAudioReference.fromMap(
        Map<String, dynamic>.from(retryData['audioReference'] as Map),
      );
      final priorChunks = (retryData['chunks'] as List)
          .map(
            (chunk) =>
                AsrChunkResult.fromMap(Map<String, dynamic>.from(chunk as Map)),
          )
          .toList();
      final firstSuccess = priorChunks.singleWhere((chunk) => chunk.index == 0);
      expect(firstSuccess.status, AsrChunkStatus.succeeded);
      final durableCheckpoint = await retryStore.readChunkCheckpoint(
        reference,
        modelReference: const {'configId': 'config', 'modelId': 'model'},
      );
      expect(
        durableCheckpoint!.chunks
            .singleWhere((chunk) => chunk.index == 0)
            .status,
        AsrChunkStatus.succeeded,
      );

      final staleTaskChunks = [
        for (final chunk in priorChunks)
          if (chunk.index == 0)
            AsrChunkResult(
              index: chunk.index,
              startSeconds: chunk.startSeconds,
              endSeconds: chunk.endSeconds,
              totalChunks: chunk.totalChunks,
              status: AsrChunkStatus.failed,
              error: 'stale task-file failure marker',
            )
          else
            chunk,
      ];
      final retryAdapter = _ControlledAdapter();
      final retry = scheduler(
        retryAdapter,
        audios: [
          AsrTaskAudio(
            bytes: await retryStore.load(reference),
            name: reference.name,
            format: reference.format,
            audioReference: reference,
            priorChunks: staleTaskChunks,
          ),
        ],
        config: config,
        sourceTaskId: failedTask.id,
      );

      await retry.start();

      expect(retryAdapter.calls, hasLength(1));
      expect(
        notifier.taskById(retry.taskIds.single)!.status,
        TaskStatus.completed,
      );
    },
  );

  test(
    'chunk checkpoints are not reused after the retry config snapshot changes',
    () async {
      final config = _config.copyWith(
        maxFileSizeBytes: 12000,
        chunking: 'fixedSize',
        fallbackMethod: 'generic',
        language: 'en',
      );
      final wav = pcmToWav(Uint8List(32000));
      final firstAdapter = _ControlledAdapter(
        failures: [null, DioExceptionType.connectionTimeout, null],
      );
      final first = scheduler(
        firstAdapter,
        audios: [AsrTaskAudio(bytes: wav, name: 'config-change.wav')],
        config: config,
      );

      await first.start();

      expect(firstAdapter.calls, hasLength(3));
      final failedTask = notifier.taskById(first.taskIds.single)!;
      expect(failedTask.status, TaskStatus.failed);
      final retryData = failedTask.retryData!;
      final reference = AsrAudioReference.fromMap(
        Map<String, dynamic>.from(retryData['audioReference'] as Map),
      );
      final checkpoint = await retryStore.readChunkCheckpoint(
        reference,
        modelReference: const {'configId': 'config', 'modelId': 'model'},
      );
      expect(
        checkpoint!.chunks.where(
          (chunk) => chunk.status == AsrChunkStatus.succeeded,
        ),
        hasLength(2),
      );
      final changedConfig = config.copyWith(language: 'fr');
      final retryAdapter = _ControlledAdapter();
      final retry = scheduler(
        retryAdapter,
        audios: [
          AsrTaskAudio(
            bytes: await retryStore.load(reference),
            name: reference.name,
            format: reference.format,
            audioReference: reference,
          ),
        ],
        config: changedConfig,
        sourceTaskId: failedTask.id,
      );

      await retry.start();

      expect(
        retryAdapter.calls,
        hasLength(3),
        reason:
            'sidecar successes from another sanitized config snapshot must not skip requests',
      );
      expect(
        notifier.taskById(retry.taskIds.single)!.status,
        TaskStatus.completed,
      );
    },
  );

  test(
    'task chunks from a different config are not reused without a matching sidecar',
    () async {
      final previousConfig = _config.copyWith(
        maxFileSizeBytes: 12000,
        chunking: 'fixedSize',
        fallbackMethod: 'generic',
        language: 'en',
      );
      final changedConfig = previousConfig.copyWith(language: 'fr');
      final wav = pcmToWav(Uint8List(32000));
      final previousAdapter = _ControlledAdapter();
      final previousDio = Dio()..httpClientAdapter = previousAdapter;
      addTearDown(() => previousDio.close(force: true));
      final previousResult = await AsrService(
        config: previousConfig,
        dio: previousDio,
      ).transcribe(audioBytes: wav, audioFormat: 'wav');
      expect(previousAdapter.calls, hasLength(3));
      expect(
        previousResult.chunks!.every(
          (chunk) => chunk.status == AsrChunkStatus.succeeded,
        ),
        isTrue,
      );

      final reference = await retryStore.save(
        wav,
        name: 'changed-config-task-chunks.wav',
        format: 'wav',
        configuredApiKey: previousConfig.apiKey,
      );
      await retryStore.writeChunkCheckpoint(
        reference,
        previousResult.chunks!,
        modelReference: const {'configId': 'config', 'modelId': 'model'},
        configSnapshotSha256: AsrRetryConfigSnapshot.fingerprintFromConfig(
          previousConfig,
        ),
        configuredApiKey: previousConfig.apiKey,
      );
      expect(
        await retryStore.readChunkCheckpoint(
          reference,
          modelReference: const {'configId': 'config', 'modelId': 'model'},
          configSnapshotSha256: AsrRetryConfigSnapshot.fingerprintFromConfig(
            changedConfig,
          ),
          configuredApiKey: changedConfig.apiKey,
        ),
        isNull,
      );

      final retryAdapter = _ControlledAdapter();
      final retry = scheduler(
        retryAdapter,
        config: changedConfig,
        audios: [
          AsrTaskAudio(
            bytes: wav,
            name: reference.name,
            format: reference.format,
            audioReference: reference,
            priorChunks: previousResult.chunks!,
          ),
        ],
      );

      await retry.start();

      expect(
        retryAdapter.calls,
        hasLength(3),
        reason: 'task chunks have no model/config identity of their own',
      );
    },
  );

  test(
    'URL retry drops stale chunks from a different plan before checkpointing',
    () async {
      const stalePlanFingerprint =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const staleChunks = [
        AsrChunkResult(
          index: 0,
          startSeconds: 0,
          endSeconds: 1,
          totalChunks: 2,
          planFingerprint: stalePlanFingerprint,
          status: AsrChunkStatus.failed,
        ),
        AsrChunkResult(
          index: 1,
          startSeconds: 1,
          endSeconds: 2,
          totalChunks: 2,
          planFingerprint: stalePlanFingerprint,
          status: AsrChunkStatus.failed,
        ),
      ];
      const url = 'https://files.test/retry-plan.wav';
      final adapter = _ControlledAdapter();
      final retry = scheduler(
        adapter,
        audios: [
          AsrTaskAudio(
            bytes: Uint8List(0),
            name: url,
            format: 'url',
            priorChunks: staleChunks,
          ),
        ],
      );

      await retry.start();

      expect(
        adapter.calls,
        hasLength(1),
        reason: 'a URL attempt must replace stale chunks from its prior plan',
      );
      expect(
        notifier.taskById(retry.taskIds.single)!.status,
        TaskStatus.completed,
      );
    },
  );

  test(
    'malformed response is uncertain and is not replayed after restart',
    () async {
      final config = _config.copyWith(
        maxFileSizeBytes: 12000,
        chunking: 'fixedSize',
        fallbackMethod: 'generic',
      );
      final wav = pcmToWav(Uint8List(32000));
      final firstAdapter = _ControlledAdapter(
        responseBodyForCall: (_) => 'not-json',
      );
      final first = scheduler(
        firstAdapter,
        audios: [AsrTaskAudio(bytes: wav, name: 'malformed-response.wav')],
        config: config,
      );

      await first.start();

      expect(firstAdapter.calls, hasLength(1));
      final failedTask = notifier.taskById(first.taskIds.single)!;
      expect(failedTask.status, TaskStatus.failed);
      expect(failedTask.retryData!['chunks'], hasLength(1));
      expect(
        (failedTask.retryData!['chunks'] as List).single['status'],
        AsrChunkStatus.uncertain.name,
      );
      expect(failedTask.error, contains('结果不确定'));

      await notifier.pendingPersistence;
      notifier.dispose();
      notifier = BackgroundTaskNotifier();
      await notifier.restoreFromPersistence();
      final restoredTask = notifier.taskById(failedTask.id)!;
      final retryData = restoredTask.retryData!;
      final reference = AsrAudioReference.fromMap(
        Map<String, dynamic>.from(retryData['audioReference'] as Map),
      );
      final priorChunks = (retryData['chunks'] as List)
          .map(
            (chunk) =>
                AsrChunkResult.fromMap(Map<String, dynamic>.from(chunk as Map)),
          )
          .toList();
      final retryAdapter = _ControlledAdapter();
      final retry = scheduler(
        retryAdapter,
        audios: [
          AsrTaskAudio(
            bytes: await retryStore.load(reference),
            name: reference.name,
            format: reference.format,
            audioReference: reference,
            priorChunks: priorChunks,
          ),
        ],
        config: config,
        sourceTaskId: restoredTask.id,
      );

      await retry.start();

      expect(retryAdapter.calls, isEmpty);
      expect(notifier.taskById(retry.taskIds.single)!.error, contains('结果不确定'));
    },
  );

  test('endpoint construction failure remains safely retryable', () async {
    final badEndpointConfig = _config.copyWith(host: 'not a URL');
    final firstAdapter = _UriValidatingAdapter();
    final first = scheduler(
      firstAdapter,
      audios: [audio('invalid-endpoint.wav')],
      config: badEndpointConfig,
    );

    await first.start();

    expect(firstAdapter.calls, isEmpty);
    final failedTask = notifier.taskById(first.taskIds.single)!;
    expect(failedTask.status, TaskStatus.failed);
    final failedChunks = failedTask.retryData!['chunks'] as List;
    expect(failedChunks, hasLength(1));
    expect((failedChunks.single as Map)['status'], AsrChunkStatus.failed.name);

    final retryData = failedTask.retryData!;
    final reference = AsrAudioReference.fromMap(
      Map<String, dynamic>.from(retryData['audioReference'] as Map),
    );
    final priorChunks = failedChunks
        .map(
          (chunk) =>
              AsrChunkResult.fromMap(Map<String, dynamic>.from(chunk as Map)),
        )
        .toList();
    final retryAdapter = _ControlledAdapter();
    final retry = scheduler(
      retryAdapter,
      audios: [
        AsrTaskAudio(
          bytes: await retryStore.load(reference),
          name: reference.name,
          format: reference.format,
          audioReference: reference,
          priorChunks: priorChunks,
        ),
      ],
      sourceTaskId: failedTask.id,
    );

    await retry.start();

    expect(retryAdapter.calls, hasLength(1));
    expect(
      notifier.taskById(retry.taskIds.single)!.status,
      TaskStatus.completed,
    );
  });

  test('Dio response-processing errors with HTTP 200 are uncertain', () async {
    final adapter = _ControlledAdapter(
      exceptionForCall: (options, _) => DioException(
        requestOptions: options,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: 'provider accepted the transcription response',
        ),
        type: DioExceptionType.unknown,
        message: 'response body decoding failed after provider acceptance',
      ),
    );
    final run = scheduler(adapter, audios: [audio('accepted-response.wav')]);

    await run.start();

    expect(adapter.calls, hasLength(1));
    final task = notifier.taskById(run.taskIds.single)!;
    expect(task.status, TaskStatus.failed);
    expect(task.retryData!['chunks'], hasLength(1));
    expect(
      (task.retryData!['chunks'] as List).single['status'],
      AsrChunkStatus.uncertain.name,
      reason: 'a successful status still proves the provider handled the POST',
    );
  });

  test(
    'changing stable model identity does not reuse old chunk outputs',
    () async {
      final config = _config.copyWith(
        maxFileSizeBytes: 12000,
        chunking: 'fixedSize',
        fallbackMethod: 'generic',
      );
      final wav = pcmToWav(Uint8List(32000));
      final firstAdapter = _ControlledAdapter(
        failures: [null, DioExceptionType.connectionTimeout, null],
      );
      final first = AsrTaskScheduler(
        notifier: notifier,
        config: config,
        audios: [AsrTaskAudio(bytes: wav, name: 'model-change.wav')],
        saveFolder: 'captured-folder',
        modelReference: const {'configId': 'provider-a', 'modelId': 'model-a'},
        retryStore: retryStore,
        serviceFactory: (config) {
          final dio = Dio()..httpClientAdapter = firstAdapter;
          addTearDown(() => dio.close(force: true));
          return AsrService(config: config, dio: dio);
        },
      );

      await first.start();

      expect(
        notifier.taskById(first.taskIds.single)!.status,
        TaskStatus.failed,
      );
      final sourceTask = notifier.taskById(first.taskIds.single)!;
      final sourceRetryData = sourceTask.retryData!;
      final reference = AsrAudioReference.fromMap(
        Map<String, dynamic>.from(sourceRetryData['audioReference'] as Map),
      );
      final retryAdapter = _ControlledAdapter();
      final retryDio = Dio()..httpClientAdapter = retryAdapter;
      addTearDown(() => retryDio.close(force: true));
      final changedModel = AsrTaskScheduler(
        notifier: notifier,
        config: config,
        audios: [
          AsrTaskAudio(
            bytes: await retryStore.load(reference),
            name: reference.name,
            format: reference.format,
            audioReference: reference,
            // The page clears these when the user changes stable model identity.
            priorChunks: const [],
          ),
        ],
        saveFolder: 'captured-folder',
        modelReference: const {'configId': 'provider-b', 'modelId': 'model-b'},
        sourceTaskId: sourceTask.id,
        retryStore: retryStore,
        serviceFactory: (config) => AsrService(config: config, dio: retryDio),
      );

      await changedModel.start();

      expect(retryAdapter.calls, hasLength(3));
    },
  );

  test('changing retry config snapshot does not reuse completed audio',
      () async {
    final reference = await retryStore.save(
      Uint8List.fromList([1, 2, 3]),
      name: 'config-change.wav',
      format: 'wav',
    );
    final oldRetryData = <String, dynamic>{
      'type': 'asr',
      'version': 2,
      'audioReference': reference.toMap(),
      'modelReference': const {'configId': 'config', 'modelId': 'model'},
      'configSnapshot': AsrRetryConfigSnapshot.fromConfig(_config).toMap(),
      'chunks': <dynamic>[],
      'saveFolder': 'captured-folder',
    };
    final sourceTaskId = notifier.addTask(
      type: BackgroundTaskType.asr,
      title: 'Retry source with changed configuration',
      retryData: oldRetryData,
    );
    notifier.failTask(sourceTaskId, error: 'retry needed');
    final completedTaskId = notifier.addTask(
      type: BackgroundTaskType.asr,
      title: 'Previously completed audio',
      startImmediately: false,
      retryData: oldRetryData,
    );
    notifier.completeTask(completedTaskId);
    await notifier.pendingPersistence;

    final changedConfig = _config.copyWith(maxFileSizeBytes: 12000);
    final changedAdapter = _ControlledAdapter();
    final changedDio = Dio()..httpClientAdapter = changedAdapter;
    addTearDown(() => changedDio.close(force: true));
    final retry = AsrTaskScheduler(
      notifier: notifier,
      config: changedConfig,
      audios: [
        AsrTaskAudio(
          bytes: await retryStore.load(reference),
          name: reference.name,
          format: reference.format,
          audioReference: reference,
        ),
      ],
      saveFolder: 'captured-folder',
      modelReference: const {'configId': 'config', 'modelId': 'model'},
      sourceTaskId: sourceTaskId,
      retryStore: retryStore,
      serviceFactory: (config) => AsrService(config: config, dio: changedDio),
    );

    await retry.start();

    expect(
      changedAdapter.calls,
      hasLength(1),
      reason:
          'a completed task with a stale config snapshot must not suppress retrying this audio',
    );
  });

  test('chunk results require a complete plan identity before reuse', () async {
    final config = _config.copyWith(
      maxFileSizeBytes: 12000,
      chunking: 'fixedSize',
      fallbackMethod: 'generic',
    );
    final wav = pcmToWav(Uint8List(32000));
    final firstAdapter = _ControlledAdapter();
    final firstDio = Dio()..httpClientAdapter = firstAdapter;
    addTearDown(() => firstDio.close(force: true));
    final firstResult = await AsrService(
      config: config,
      dio: firstDio,
    ).transcribe(audioBytes: wav, audioFormat: 'wav');

    final firstChunks = firstResult.chunks!;
    final planFingerprints = {
      for (final chunk in firstChunks) chunk.planFingerprint,
    };
    expect(firstChunks, hasLength(3));
    expect(planFingerprints, hasLength(1));
    expect(planFingerprints.single, matches(RegExp(r'^[a-f0-9]{64}$')));

    final legacyPriorChunks = [
      for (final chunk in firstChunks)
        AsrChunkResult.fromMap(
          Map<String, dynamic>.from(chunk.toMap())..remove('planFingerprint'),
        ),
    ];
    final completeLegacyAdapter = _ControlledAdapter();
    final completeLegacyDio = Dio()..httpClientAdapter = completeLegacyAdapter;
    addTearDown(() => completeLegacyDio.close(force: true));
    await AsrService(config: config, dio: completeLegacyDio).transcribe(
      audioBytes: wav,
      audioFormat: 'wav',
      priorChunks: legacyPriorChunks,
    );
    expect(completeLegacyAdapter.calls, isEmpty);

    final sparseLegacyAdapter = _ControlledAdapter();
    final sparseLegacyDio = Dio()..httpClientAdapter = sparseLegacyAdapter;
    addTearDown(() => sparseLegacyDio.close(force: true));
    await AsrService(config: config, dio: sparseLegacyDio).transcribe(
      audioBytes: wav,
      audioFormat: 'wav',
      priorChunks: [legacyPriorChunks[1]],
    );
    expect(sparseLegacyAdapter.calls, hasLength(3));

    final stalePlanFingerprint =
        planFingerprints.single == 'f' * 64 ? 'e' * 64 : 'f' * 64;
    final stalePriorChunks = [
      for (final chunk in firstChunks)
        AsrChunkResult.fromMap({
          ...chunk.toMap(),
          'planFingerprint': stalePlanFingerprint,
        }),
    ];
    final retryAdapter = _ControlledAdapter();
    final retryDio = Dio()..httpClientAdapter = retryAdapter;
    addTearDown(() => retryDio.close(force: true));

    await AsrService(config: config, dio: retryDio).transcribe(
      audioBytes: wav,
      audioFormat: 'wav',
      priorChunks: stalePriorChunks,
    );

    expect(retryAdapter.calls, hasLength(3));
  });

  test(
    'restarted retry retains complete legacy successes after a chunk fails',
    () async {
      final config = _config.copyWith(
        maxFileSizeBytes: 12000,
        chunking: 'fixedSize',
        fallbackMethod: 'generic',
      );
      final wav = pcmToWav(Uint8List(32000));
      final sourceDio = Dio()..httpClientAdapter = _ControlledAdapter();
      addTearDown(() => sourceDio.close(force: true));
      final sourceService = AsrService(config: config, dio: sourceDio);
      final sourceResult = await sourceService.transcribe(
        audioBytes: wav,
        audioFormat: 'wav',
      );
      sourceService.close();
      final legacyPriorChunks = [
        for (final chunk in sourceResult.chunks!)
          if (chunk.index == 1)
            AsrChunkResult(
              index: chunk.index,
              startSeconds: chunk.startSeconds,
              endSeconds: chunk.endSeconds,
              totalChunks: chunk.totalChunks,
              status: AsrChunkStatus.failed,
              error: 'previous definite failure',
            )
          else
            AsrChunkResult.fromMap(
              Map<String, dynamic>.from(chunk.toMap())
                ..remove('planFingerprint'),
            ),
      ];

      final firstAdapter = _ControlledAdapter(responseStatuses: [400]);
      final firstDio = Dio()..httpClientAdapter = firstAdapter;
      addTearDown(() => firstDio.close(force: true));
      final first = AsrTaskScheduler(
        notifier: notifier,
        config: config,
        audios: [
          AsrTaskAudio(
            bytes: wav,
            name: 'legacy-long.wav',
            priorChunks: legacyPriorChunks,
          ),
        ],
        saveFolder: 'captured-folder',
        modelReference: const {'configId': 'config', 'modelId': 'model'},
        retryStore: retryStore,
        serviceFactory: (config) => AsrService(config: config, dio: firstDio),
      );

      await first.start();

      expect(firstAdapter.calls, hasLength(1));
      final firstTask = notifier.taskById(first.taskIds.single)!;
      expect(firstTask.status, TaskStatus.failed);
      final retryData = firstTask.retryData!;
      final audioReference = AsrAudioReference.fromMap(
        Map<String, dynamic>.from(retryData['audioReference'] as Map),
      );
      final priorChunks = (retryData['chunks'] as List)
          .map(
            (chunk) =>
                AsrChunkResult.fromMap(Map<String, dynamic>.from(chunk as Map)),
          )
          .toList();
      expect(
        priorChunks.where((chunk) => chunk.status == AsrChunkStatus.succeeded),
        hasLength(2),
      );

      final secondAdapter = _ControlledAdapter();
      final secondDio = Dio()..httpClientAdapter = secondAdapter;
      addTearDown(() => secondDio.close(force: true));
      final second = AsrTaskScheduler(
        notifier: notifier,
        config: config,
        audios: [
          AsrTaskAudio(
            bytes: await retryStore.load(audioReference),
            name: audioReference.name,
            format: audioReference.format,
            audioReference: audioReference,
            priorChunks: priorChunks,
          ),
        ],
        saveFolder: 'captured-folder',
        modelReference: const {'configId': 'config', 'modelId': 'model'},
        retryStore: retryStore,
        serviceFactory: (config) => AsrService(config: config, dio: secondDio),
      );

      await second.start();

      expect(
        secondAdapter.calls,
        hasLength(1),
        reason:
            'the two successful legacy chunks must survive the sidecar restart',
      );
    },
  );

  test(
    'definite single-request failure can continue into a generic chunked plan',
    () async {
      final pcm = Uint8List(240);
      final pcmData = ByteData.sublistView(pcm);
      var randomState = 0x12345678;
      for (var index = 0; index < 120; index++) {
        randomState = (randomState * 1103515245 + 12345) & 0x7fffffff;
        pcmData.setInt16(
          index * 2,
          (randomState & 0xffff) - 32768,
          Endian.little,
        );
      }
      final wav = pcmToWav(pcm);
      final base64BodyBytes = utf8
          .encode(
            jsonEncode({
              'model': 'whisper-1',
              'response_format': 'json',
              'file': base64Encode(wav),
            }),
          )
          .length;
      final config = _config.copyWith(
        uploadMethod: AudioUploadMethod.multipart,
        maxFileSizeBytes: base64BodyBytes,
        chunking: 'fixedSize',
        fallbackMethod: 'all',
      );
      final adapter = _ControlledAdapter(responseStatuses: [400]);
      final run = scheduler(
        adapter,
        audios: [AsrTaskAudio(bytes: wav, name: 'fallback.wav')],
        config: config,
      );

      await run.start();

      expect(adapter.calls, hasLength(greaterThan(1)));
      expect(adapter.calls.first.contentType, contains('application/json'));
      expect(
        adapter.calls.skip(1).every(
              (request) => request.contentType!.contains('multipart/form-data'),
            ),
        isTrue,
      );
      expect(
        notifier.taskById(run.taskIds.single)!.status,
        TaskStatus.completed,
      );
    },
  );

  test(
    'a chunk retry sends only failed chunks and reuses successful output',
    () async {
      final config = AsrConfig(
        apiKey: 'sk-chunk-test-secret',
        host: 'https://asr.test/transcribe',
        typeConfig: {'enableResponseFormat': true, 'responseFormat': 'srt'},
        customParams: [
          CustomParam(
            paramName: 'x-client-meta',
            defaultValue: 'Bearer sk-custom-test-secret',
          ),
        ],
        maxFileSizeBytes: 12000,
        chunking: 'fixedSize',
        fallbackMethod: 'generic',
      );
      final wav = pcmToWav(Uint8List(32000));
      final firstAdapter = _ControlledAdapter(
        failures: [null, DioExceptionType.connectionTimeout, null],
        responseBodyForCall: (index) =>
            '1\n00:00:00,000 --> 00:00:00,100\nchunk ${index + 1}\n',
      );
      final firstDio = Dio()..httpClientAdapter = firstAdapter;
      addTearDown(() => firstDio.close(force: true));
      final first = AsrTaskScheduler(
        notifier: notifier,
        config: config,
        audios: [AsrTaskAudio(bytes: wav, name: 'long.wav')],
        saveFolder: 'captured-folder',
        modelReference: const {'configId': 'config', 'modelId': 'model'},
        retryStore: retryStore,
        serviceFactory: (config) => AsrService(config: config, dio: firstDio),
      );

      await first.start();

      final firstTask = notifier.taskById(first.taskIds.single)!;
      expect(firstTask.status, TaskStatus.failed);
      final retryData = firstTask.retryData!;
      expect(retryData['version'], 2);
      expect(retryData, isNot(contains('audios')));
      expect(jsonEncode(retryData), isNot(contains(base64Encode(wav))));
      expect(jsonEncode(retryData), isNot(contains('sk-chunk-test-secret')));
      expect(jsonEncode(retryData), isNot(contains('sk-custom-test-secret')));
      expect(
        jsonEncode(firstTask.rawRequest),
        isNot(contains('sk-custom-test-secret')),
      );
      expect(
        jsonEncode(firstTask.rawRequest),
        isNot(contains(base64Encode(wav))),
      );
      expect(retryData['modelReference'], {
        'configId': 'config',
        'modelId': 'model',
      });
      final audioReference = AsrAudioReference.fromMap(
        Map<String, dynamic>.from(retryData['audioReference'] as Map),
      );
      final priorChunks = (retryData['chunks'] as List)
          .map(
            (chunk) =>
                AsrChunkResult.fromMap(Map<String, dynamic>.from(chunk as Map)),
          )
          .toList();
      expect(priorChunks, hasLength(3));
      final planFingerprints = {
        for (final chunk in priorChunks) chunk.planFingerprint,
      };
      expect(planFingerprints, hasLength(1));
      expect(planFingerprints.single, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(
        priorChunks.where((chunk) => chunk.status == AsrChunkStatus.succeeded),
        hasLength(2),
      );
      expect(
        priorChunks.where((chunk) => chunk.status == AsrChunkStatus.failed),
        hasLength(1),
      );
      final secondChunkOffset = priorChunks[1].startSeconds;
      final thirdChunkOffset = priorChunks[2].startSeconds;

      final secondAdapter = _ControlledAdapter(
        responseBodyForCall: (index) =>
            '1\n00:00:00,000 --> 00:00:00,100\nrecovered middle\n',
      );
      final secondDio = Dio()..httpClientAdapter = secondAdapter;
      addTearDown(() => secondDio.close(force: true));
      final second = AsrTaskScheduler(
        notifier: notifier,
        config: config,
        audios: [
          AsrTaskAudio(
            bytes: wav,
            name: 'long.wav',
            audioReference: audioReference,
            priorChunks: priorChunks,
          ),
        ],
        saveFolder: 'captured-folder',
        modelReference: const {'configId': 'config', 'modelId': 'model'},
        retryStore: retryStore,
        serviceFactory: (config) => AsrService(config: config, dio: secondDio),
      );

      await second.start();

      expect(firstAdapter.calls, hasLength(3));
      expect(secondAdapter.calls, hasLength(1));
      final savedRecords = await TextManifest.loadRecords();
      expect(savedRecords, hasLength(1));
      final saved = await TextManifest.readText(
        savedRecords.single.storageFileName,
      );
      expect(saved, contains('chunk 1'));
      expect(saved, contains('recovered middle'));
      expect(saved, contains('chunk 3'));
      expect(saved, contains(srtTime(secondChunkOffset)));
      expect(saved, contains(srtTime(thirdChunkOffset)));
    },
  );
}
