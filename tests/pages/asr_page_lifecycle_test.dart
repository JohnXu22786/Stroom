import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/asr_page.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/tts_state_provider.dart';
import 'package:stroom/services/asr_service.dart';
import 'package:stroom/services/asr_retry_storage.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/utils/text_manifest.dart';

class _ControlledAsrService extends AsrService {
  final Future<void> _responseGate;
  final void Function(CancelToken?) _onStarted;

  _ControlledAsrService(
    AsrConfig config, {
    required Future<void> responseGate,
    required void Function(CancelToken?) onStarted,
  })  : _responseGate = responseGate,
        _onStarted = onStarted,
        super(config: config);

  @override
  Future<AsrResult> transcribe({
    required Uint8List audioBytes,
    String audioFormat = 'wav',
    CancelToken? cancelToken,
    AsrProgressCallback? onProgress,
    List<AsrChunkResult> priorChunks = const [],
    AsrChunkResultCallback? onChunkResult,
    AsrChunkResultCallback? onChunkAttempt,
  }) async {
    _onStarted(cancelToken);
    await _responseGate;
    return const AsrResult(text: 'page result');
  }

  @override
  Future<AsrResult> transcribeFromUrl(
    String audioUrl, {
    CancelToken? cancelToken,
    AsrProgressCallback? onProgress,
    List<AsrChunkResult> priorChunks = const [],
    AsrChunkResultCallback? onChunkAttempt,
    AsrChunkResultCallback? onChunkResult,
  }) async {
    _onStarted(cancelToken);
    await _responseGate;
    return const AsrResult(text: 'page result');
  }
}

class _MemoryRetryAdapter implements AsrRetryStorageAdapter {
  final Map<String, Uint8List> files = {};

  @override
  Future<void> write(String key, Uint8List bytes) async {
    files[key] = Uint8List.fromList(bytes);
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

class _DelayedReadRetryAdapter extends _MemoryRetryAdapter {
  final Completer<void> readGate = Completer<void>();
  bool holdReads = false;

  @override
  Future<Uint8List?> read(String key) async {
    if (holdReads) await readGate.future;
    return super.read(key);
  }
}

class _DelayedProviderEntriesNotifier extends ProviderEntriesNotifier {
  final Completer<void> _loadGate = Completer<void>();

  @override
  Future<void> get ready => _loadGate.future;

  void finishLoad(ProviderEntriesState loadedState) {
    state = loadedState;
    _loadGate.complete();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late BackgroundTaskNotifier background;
  late ProviderEntriesNotifier providerEntries;
  late Completer<void> releaseResponse;
  late AsrRetryAudioStore defaultRetryStore;
  late int serviceCalls;
  late bool serviceMethodEntered;
  CancelToken? activeToken;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
    directory = await Directory.systemTemp.createTemp('asr_page_owned_');
    BackgroundTaskNotifier.debugStorageDirectoryOverride = directory.path;
    BackgroundTaskNotifier.debugDisablePersistence = true;
    background = BackgroundTaskNotifier();
    providerEntries = ProviderEntriesNotifier()
      ..state = ProviderEntriesState(
        entries: [
          ProviderEntry(
            name: 'ASR',
            type: 'asr',
            configs: [
              ProviderConfigItem(
                id: 'provider',
                providerName: 'ASR',
                host: 'https://api.test.com/audio/transcriptions',
                key: 'test-key',
                models: [
                  ModelConfig(
                    id: 'model',
                    name: 'Test ASR',
                    modelId: 'whisper-test',
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    releaseResponse = Completer<void>();
    defaultRetryStore = AsrRetryAudioStore(adapter: _MemoryRetryAdapter());
    serviceCalls = 0;
    serviceMethodEntered = false;
    activeToken = null;
  });

  tearDown(() async {
    if (background.mounted) {
      for (final task in background.state) {
        if (task.status == TaskStatus.running ||
            task.status == TaskStatus.waiting) {
          background.cancelTask(task.id);
        }
      }
    }
    if (!releaseResponse.isCompleted) releaseResponse.complete();
    if (background.mounted) background.dispose();
    await background.pendingPersistence;
    BackgroundTaskNotifier.debugDisablePersistence = false;
    BackgroundTaskNotifier.debugStorageDirectoryOverride = null;
    try {
      directory.deleteSync(recursive: true);
    } catch (_) {}
  });

  Map<String, dynamic> retryData() => {
        'audios': [
          {
            'bytes': base64Encode([1, 2, 3]),
            'name': 'captured.wav',
            'format': 'wav',
          },
        ],
        'modelReference': {'configId': 'provider', 'modelId': 'model'},
        'configSnapshot': AsrRetryConfigSnapshot.fromConfig(
          const AsrConfig(
            apiKey: 'test-key',
            host: 'https://api.test.com/audio/transcriptions',
            model: 'whisper-test',
          ),
        ).toMap(),
        'saveFolder': 'captured-folder',
      };

  Widget app({
    bool keepPageOpen = false,
    Map<String, dynamic>? initialRetryData,
    AsrRetryAudioStore? retryStoreOverride,
    String? retryTaskId,
    ProviderEntriesNotifier? providerEntriesOverride,
  }) =>
      ProviderScope(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => providerEntriesOverride ?? providerEntries,
          ),
          backgroundTasksProvider.overrideWith((ref) => background),
          audioRecordsProvider.overrideWith((ref) => AudioRecordsNotifier()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AsrPage(
                      retryData: initialRetryData ?? retryData(),
                      retryAudioStore: retryStoreOverride ?? defaultRetryStore,
                      retryTaskId: retryTaskId,
                      asrServiceFactory: (config) {
                        serviceCalls++;
                        return _ControlledAsrService(
                          config,
                          responseGate: releaseResponse.future,
                          onStarted: (token) {
                            activeToken = token;
                            serviceMethodEntered = true;
                          },
                        );
                      },
                      onNavigateBack: keepPageOpen ? () {} : null,
                    ),
                  ),
                ),
                child: const Text('打开 ASR'),
              ),
            ),
          ),
        ),
      );

  Future<void> waitForServiceCall(WidgetTester tester) async {
    for (var attempt = 0; attempt < 50 && serviceCalls == 0; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  testWidgets(
    'starting then leaving the page keeps the captured task running',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.tap(find.text('打开 ASR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('开始识别'));
      await waitForServiceCall(tester);
      await tester.pumpAndSettle();

      expect(find.text('打开 ASR'), findsOneWidget);
      expect(background.state, hasLength(1));
      expect(
        background.state.single.status,
        TaskStatus.running,
        reason: jsonEncode(background.state.single.toMap()),
      );
      expect(serviceCalls, 1);
      expect(activeToken?.isCancelled, isNot(true));
      background.cancelTask(background.state.single.id);
      releaseResponse.complete();
    },
  );

  testWidgets('repeated start taps create one ASR task and request', (
    tester,
  ) async {
    await tester.pumpWidget(app(keepPageOpen: true));
    await tester.tap(find.text('打开 ASR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始识别'));
    await tester.pump();
    await waitForServiceCall(tester);
    await tester.tap(find.byType(FilledButton).last);
    await tester.pump();

    expect(background.state, hasLength(1));
    expect(
      serviceCalls,
      1,
      reason: jsonEncode(background.state.map((task) => task.toMap()).toList()),
    );
    expect(activeToken?.isCancelled, isNot(true));
    background.cancelTask(background.state.single.id);
    releaseResponse.complete();
  });

  testWidgets(
    'retry ignores a non-string save folder while restoring audio',
    (tester) async {
      final data = {
        'audios': [
          {
            'bytes': base64Encode([1, 2, 3]),
            'name': 'recovered.wav',
            'format': 'wav',
          },
        ],
        'modelReference': {'configId': 'provider', 'modelId': 'model'},
        'configSnapshot': retryData()['configSnapshot'],
        'saveFolder': 7,
      };
      await tester.pumpWidget(app(initialRetryData: data));
      await tester.tap(find.text('打开 ASR'));
      await tester.pumpAndSettle();

      expect(find.text('1. recovered.wav'), findsOneWidget);
      expect(find.text('根目录'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'malformed retry data shows an error and finishes loading',
    (tester) async {
      await tester.pumpWidget(
        app(initialRetryData: {'audios': 'not-an-audio-list'}),
      );
      await tester.tap(find.text('打开 ASR'));
      await tester.pumpAndSettle();

      expect(find.textContaining('重试数据无法读取'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'retry with a missing chunk status requires reselection instead of replay',
    (tester) async {
      final store = AsrRetryAudioStore(adapter: _MemoryRetryAdapter());
      final reference = await store.save(
        Uint8List.fromList([9, 8, 7]),
        name: 'unknown-status.wav',
        format: 'wav',
        configuredApiKey: 'test-key',
      );
      await store.releaseProtection(reference);
      final data = {
        'version': 2,
        'audioReference': reference.toMap(configuredApiKey: 'test-key'),
        'modelReference': {'configId': 'provider', 'modelId': 'model'},
        'configSnapshot': retryData()['configSnapshot'],
        'chunks': [
          {
            'index': 0,
            'startSeconds': 0,
            'endSeconds': 1,
            'totalChunks': 1,
            'text': 'must not be replayed',
          },
        ],
        'saveFolder': 'captured-folder',
      };

      await tester.pumpWidget(
        app(initialRetryData: data, retryStoreOverride: store),
      );
      await tester.tap(find.text('打开 ASR'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('开始识别'));
      await tester.pump();
      await waitForServiceCall(tester);

      expect(serviceCalls, 0);
      expect(find.textContaining('重试音频数据无法读取'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'retry keeps a valid saved model while provider entries are loading',
    (tester) async {
      final delayedProviderEntries = _DelayedProviderEntriesNotifier();
      await tester.pumpWidget(
        app(providerEntriesOverride: delayedProviderEntries),
      );
      await tester.tap(find.text('打开 ASR'));
      await tester.pumpAndSettle();

      delayedProviderEntries.finishLoad(
        ProviderEntriesState(
          entries: [
            ProviderEntry(
              name: 'ASR',
              type: 'asr',
              configs: [
                ProviderConfigItem(
                  id: 'provider',
                  providerName: 'ASR',
                  host: 'https://api.test.com/audio/transcriptions',
                  key: 'test-key',
                  models: [
                    ModelConfig(
                      id: 'model',
                      name: 'Retry target',
                      modelId: 'whisper-test',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Retry target | ASR'), findsOneWidget);
      expect(find.text('请重新选择模型'), findsNothing);
    },
  );

  testWidgets(
      'retry selection follows model identity after reorder and blocks removal',
      (tester) async {
    providerEntries.state = ProviderEntriesState(entries: [
      ProviderEntry(
        name: 'ASR',
        type: 'asr',
        configs: [
          ProviderConfigItem(
            id: 'provider',
            providerName: 'ASR',
            host: 'https://api.test.com/audio/transcriptions',
            key: 'test-key',
            models: [
              ModelConfig(id: 'model', name: 'Retry target', modelId: 'retry'),
              ModelConfig(id: 'other', name: 'Other', modelId: 'other'),
            ],
          ),
        ],
      ),
    ]);
    await tester.pumpWidget(app());
    await tester.tap(find.text('打开 ASR'));
    await tester.pumpAndSettle();
    expect(find.text('Retry target | ASR'), findsOneWidget);

    providerEntries.state = ProviderEntriesState(entries: [
      ProviderEntry(
        name: 'ASR',
        type: 'asr',
        configs: [
          ProviderConfigItem(
            id: 'provider',
            providerName: 'ASR',
            host: 'https://api.test.com/audio/transcriptions',
            key: 'test-key',
            models: [
              ModelConfig(id: 'other', name: 'Other', modelId: 'other'),
              ModelConfig(id: 'model', name: 'Retry target', modelId: 'retry'),
            ],
          ),
        ],
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Retry target | ASR'), findsOneWidget);

    providerEntries.state = ProviderEntriesState(entries: [
      ProviderEntry(
        name: 'ASR',
        type: 'asr',
        configs: [
          ProviderConfigItem(
            id: 'provider',
            providerName: 'ASR',
            host: 'https://api.test.com/audio/transcriptions',
            key: 'test-key',
            models: [
              ModelConfig(id: 'other', name: 'Other', modelId: 'other'),
            ],
          ),
        ],
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('请重新选择模型'), findsOneWidget);
    await tester.tap(find.text('开始识别'));
    await tester.pump();
    expect(serviceCalls, 0);
    expect(
      find.text('原识别模型已失效或无法确认，请重新选择识别模型'),
      findsOneWidget,
    );
  });

  testWidgets(
      'legacy index retry loads audio but requires model reselection and persists v2 before request',
      (tester) async {
    final legacyData = {
      'audios': [
        {
          'bytes': base64Encode([9, 8, 7]),
          'name': 'legacy.wav',
          'format': 'wav',
        },
      ],
      'modelIndex': 0,
      'saveFolder': 'captured-folder',
    };
    final sourceTaskId = background.addTask(
      type: BackgroundTaskType.asr,
      title: 'legacy retry',
      retryData: legacyData,
    );
    background.failTask(sourceTaskId, error: 'legacy failure');
    await background.pendingPersistence;
    providerEntries.state = ProviderEntriesState(entries: [
      ProviderEntry(
        name: 'ASR',
        type: 'asr',
        configs: [
          ProviderConfigItem(
            id: 'provider',
            providerName: 'ASR',
            host: 'https://api.test.com/audio/transcriptions',
            key: 'test-key',
            models: [
              ModelConfig(
                  id: 'model', name: 'Test ASR', modelId: 'whisper-test'),
              ModelConfig(id: 'other', name: 'Other', modelId: 'other'),
            ],
          ),
        ],
      ),
    ]);
    await tester.pumpWidget(app(
      initialRetryData: legacyData,
      retryTaskId: sourceTaskId,
    ));
    await tester.tap(find.text('打开 ASR'));
    await tester.pumpAndSettle();
    expect(find.text('请重新选择模型'), findsOneWidget);
    expect(find.text('1. legacy.wav'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test ASR | ASR').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始识别'));
    await tester.pump(const Duration(seconds: 1));
    await waitForServiceCall(tester);

    expect(serviceCalls, 1);
    final retry = background.state.first.retryData!;
    expect(retry['version'], 2);
    expect(retry, isNot(contains('audios')));
    expect(jsonEncode(retry), isNot(contains(base64Encode([9, 8, 7]))));
    expect(jsonEncode(retry), isNot(contains('test-key')));
    expect(
        retry['modelReference'], {'configId': 'provider', 'modelId': 'model'});
    await background.pendingPersistence;
    expect(background.taskById(sourceTaskId)!.retryData, retry);
    background.cancelTask(background.state.first.id);
    releaseResponse.complete();
  });

  testWidgets(
    'model reselection invalidates the saved checkpoint before retrying',
    (tester) async {
      final retryFiles = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: retryFiles);
      final bytes = Uint8List.fromList([9, 8, 7]);
      final reference = await store.save(
        bytes,
        name: 'reselected.wav',
        format: 'wav',
        configuredApiKey: 'test-key',
      );
      await store.writeChunkCheckpoint(
        reference,
        const [
          AsrChunkResult(
            index: 0,
            startSeconds: 0,
            endSeconds: 1,
            totalChunks: 1,
            status: AsrChunkStatus.succeeded,
            text: 'old provider transcript',
          ),
        ],
        modelReference: const {'configId': 'provider', 'modelId': 'model'},
        configuredApiKey: 'test-key',
      );
      final data = {
        'version': 2,
        'audioReference': reference.toMap(configuredApiKey: 'test-key'),
        'modelReference': {'configId': 'provider', 'modelId': 'model'},
        'configSnapshot': AsrRetryConfigSnapshot.fromConfig(
          const AsrConfig(
            apiKey: 'test-key',
            host: 'https://api.test.com/audio/transcriptions',
            model: 'whisper-test',
          ),
        ).toMap(),
        'chunks': [],
        'saveFolder': 'captured-folder',
      };
      final sourceTaskId = background.addTask(
        type: BackgroundTaskType.asr,
        title: 'provider changed retry',
        retryData: data,
      );
      background.failTask(sourceTaskId, error: 'previous failure');
      providerEntries.state = ProviderEntriesState(entries: [
        ProviderEntry(
          name: 'ASR',
          type: 'asr',
          configs: [
            ProviderConfigItem(
              id: 'provider',
              providerName: 'ASR',
              host: 'https://changed-api.test.com/audio/transcriptions',
              key: 'test-key',
              models: [
                ModelConfig(
                  id: 'model',
                  name: 'Test ASR',
                  modelId: 'whisper-test',
                ),
              ],
            ),
          ],
        ),
      ]);

      await tester.pumpWidget(app(
        initialRetryData: data,
        retryStoreOverride: store,
        retryTaskId: sourceTaskId,
        keepPageOpen: true,
      ));
      await tester.tap(find.text('打开 ASR'));
      await tester.pumpAndSettle();
      expect(find.text('请重新选择模型'), findsOneWidget);

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test ASR | ASR').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('开始识别'));
      await tester.pump();
      await waitForServiceCall(tester);

      expect(serviceCalls, 1);
      expect(
        await store.readChunkCheckpoint(
          reference,
          modelReference: const {'configId': 'provider', 'modelId': 'model'},
          configuredApiKey: 'test-key',
        ),
        isNull,
      );
      background.cancelTask(background.state.last.id);
      releaseResponse.complete();
    },
  );

  testWidgets(
    'model selection is disabled while retry audio restoration is pending',
    (tester) async {
      final adapter = _DelayedReadRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      final reference = await store.save(
        Uint8List.fromList([9, 8, 7]),
        name: 'pending-restore.wav',
        format: 'wav',
        configuredApiKey: 'test-key',
      );
      await store.releaseProtection(reference);
      adapter.holdReads = true;
      providerEntries.state = ProviderEntriesState(entries: [
        ProviderEntry(
          name: 'ASR',
          type: 'asr',
          configs: [
            ProviderConfigItem(
              id: 'provider',
              providerName: 'ASR',
              host: 'https://api.test.com/audio/transcriptions',
              key: 'test-key',
              models: [
                ModelConfig(
                  id: 'model',
                  name: 'Saved model',
                  modelId: 'whisper-test',
                ),
                ModelConfig(
                  id: 'other',
                  name: 'New model',
                  modelId: 'whisper-other',
                ),
              ],
            ),
          ],
        ),
      ]);
      final data = {
        'version': 2,
        'audioReference': reference.toMap(configuredApiKey: 'test-key'),
        'modelReference': {'configId': 'provider', 'modelId': 'model'},
        'configSnapshot': retryData()['configSnapshot'],
        'chunks': [
          const AsrChunkResult(
            index: 0,
            startSeconds: 0,
            endSeconds: 1,
            totalChunks: 1,
            status: AsrChunkStatus.succeeded,
            text: 'saved-model transcript',
          ).toMap(),
        ],
      };

      try {
        await tester.pumpWidget(
          app(
            initialRetryData: data,
            retryStoreOverride: store,
            keepPageOpen: true,
          ),
        );
        await tester.tap(find.text('打开 ASR'));
        await tester.pumpAndSettle();

        final dropdown = tester.widget<DropdownButton<int>>(
          find.byType(DropdownButton<int>),
        );
        expect(dropdown.onChanged, isNull);
        expect(dropdown.value, 0);
      } finally {
        adapter.holdReads = false;
        if (!adapter.readGate.isCompleted) adapter.readGate.complete();
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('retry URL snapshot controls the audio picker after live changes',
      (tester) async {
    const url = 'https://media.example.test/public/audio.wav';
    final urlReference = AsrAudioReference(
      id: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      name: url,
      format: 'url',
      byteLength: 0,
      sha256: List.filled(64, '0').join(),
      url: url,
    );
    final urlRetryData = {
      'version': 2,
      'audioReference': urlReference.toMap(),
      'modelReference': {'configId': 'provider', 'modelId': 'model'},
      'configSnapshot': AsrRetryConfigSnapshot.fromConfig(
        const AsrConfig(
          apiKey: 'test-key',
          host: 'https://api.test.com/audio/transcriptions',
          model: 'whisper-test',
          uploadMethod: AudioUploadMethod.url,
        ),
      ).toMap(),
    };

    await tester.pumpWidget(app(initialRetryData: urlRetryData));
    await tester.tap(find.text('打开 ASR'));
    await tester.pumpAndSettle();

    expect(find.text('输入公网音频链接'), findsOneWidget);
    expect(find.text('音频文件'), findsNothing);
    expect(serviceCalls, 0);
  });

  testWidgets(
    'URL retry preserves uncertain prior chunks when its checkpoint is missing',
    (tester) async {
      const url = 'https://media.example.test/retry/uncertain.wav';
      final reference = AsrAudioReference(
        id: 'abababababababababababababababab',
        name: url,
        format: 'url',
        byteLength: 0,
        sha256: List.filled(64, 'b').join(),
        url: url,
      );
      final retryConfig = const AsrConfig(
        apiKey: 'test-key',
        host: 'https://api.test.com/audio/transcriptions',
        model: 'whisper-test',
        uploadMethod: AudioUploadMethod.url,
      );
      final uncertainChunk = AsrChunkResult(
        index: 0,
        startSeconds: 0,
        endSeconds: 10,
        totalChunks: 1,
        status: AsrChunkStatus.uncertain,
      );
      final retrySnapshot = {
        'version': 2,
        'audioReference': reference.toMap(),
        'chunks': [uncertainChunk.toMap()],
        'modelReference': {'configId': 'provider', 'modelId': 'model'},
        'configSnapshot':
            AsrRetryConfigSnapshot.fromConfig(retryConfig).toMap(),
        'saveFolder': 'captured-folder',
      };
      final sourceTaskId = background.addTask(
        type: BackgroundTaskType.asr,
        title: 'Uncertain URL retry',
        retryData: retrySnapshot,
      );
      background.failTask(sourceTaskId, error: 'provider response uncertain');
      await background.pendingPersistence;
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      final urlProviderEntries = ProviderEntriesNotifier()
        // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
        ..state = ProviderEntriesState(
          entries: [
            ProviderEntry(
              name: 'ASR',
              type: 'asr',
              configs: [
                ProviderConfigItem(
                  id: 'provider',
                  providerName: 'ASR',
                  host: 'https://api.test.com/audio/transcriptions',
                  key: 'test-key',
                  typeConfig: {'uploadMethod': 'url'},
                  models: [
                    ModelConfig(
                      id: 'model',
                      name: 'Test ASR',
                      modelId: 'whisper-test',
                    ),
                  ],
                ),
              ],
            ),
          ],
        );

      await tester.pumpWidget(
        app(
          initialRetryData: retrySnapshot,
          retryStoreOverride: store,
          retryTaskId: sourceTaskId,
          keepPageOpen: true,
          providerEntriesOverride: urlProviderEntries,
        ),
      );
      await tester.tap(find.text('打开 ASR'));
      await tester.pumpAndSettle();
      expect(
        await store.readChunkCheckpoint(
          reference,
          modelReference: const {'configId': 'provider', 'modelId': 'model'},
          configuredApiKey: 'test-key',
        ),
        isNull,
      );

      await tester.tap(find.text('开始识别'));
      await tester.pump();
      final retryTaskId = background.tasks.last.id;
      for (var attempt = 0;
          attempt < 50 &&
              background.taskById(retryTaskId)?.status != TaskStatus.failed;
          attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }

      expect(serviceMethodEntered, isFalse);
      expect(serviceCalls, 0);
      final retryTask = background.taskById(retryTaskId);
      expect(retryTask?.status, TaskStatus.failed);
      final persistedChunks = retryTask?.retryData?['chunks'] as List<dynamic>?;
      expect(persistedChunks, hasLength(1));
      expect((persistedChunks!.single as Map)['status'], 'uncertain');
      background.cancelTask(retryTaskId);
      releaseResponse.complete();
    },
  );

  testWidgets(
    'unresolved URL retry keeps the saved URL source mode',
    (tester) async {
      const url = 'https://media.example.test/unresolved.wav';
      final retryData = {
        'version': 2,
        'audioReference': AsrAudioReference(
          id: 'cccccccccccccccccccccccccccccccc',
          name: url,
          format: 'url',
          byteLength: 0,
          sha256: List.filled(64, '2').join(),
          url: url,
        ).toMap(),
        'modelReference': {
          'configId': 'removed-provider',
          'modelId': 'removed-model',
        },
        'configSnapshot': AsrRetryConfigSnapshot.fromConfig(
          const AsrConfig(
            apiKey: 'test-key',
            host: 'https://api.test.com/audio/transcriptions',
            model: 'whisper-test',
            uploadMethod: AudioUploadMethod.url,
          ),
        ).toMap(),
      };

      await tester.pumpWidget(app(initialRetryData: retryData));
      await tester.tap(find.text('打开 ASR'));
      await tester.pumpAndSettle();

      expect(find.text('请重新选择模型'), findsOneWidget);
      expect(find.text('输入公网音频链接'), findsOneWidget);
      expect(find.text('音频文件'), findsNothing);
      expect(serviceCalls, 0);
    },
  );

  testWidgets(
    'legacy URL retry keeps URL mode while model reselection is required',
    (tester) async {
      const url = 'https://media.example.test/legacy.wav';
      final retryData = {
        'audios': [
          {'url': url},
        ],
        'modelIndex': 0,
      };

      await tester.pumpWidget(app(initialRetryData: retryData));
      await tester.tap(find.text('打开 ASR'));
      await tester.pumpAndSettle();

      expect(find.text('请重新选择模型'), findsOneWidget);
      expect(find.text('输入公网音频链接'), findsOneWidget);
      expect(find.text('音频文件'), findsNothing);
      expect(serviceCalls, 0);
    },
  );

  testWidgets(
    'retry disables source controls until the saved upload mode resolves',
    (tester) async {
      const url = 'https://media.example.test/public/pending.wav';
      final urlRetryData = {
        'version': 2,
        'audioReference': AsrAudioReference(
          id: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          name: url,
          format: 'url',
          byteLength: 0,
          sha256: List.filled(64, '1').join(),
          url: url,
        ).toMap(),
        'modelReference': {'configId': 'provider', 'modelId': 'model'},
        'configSnapshot': AsrRetryConfigSnapshot.fromConfig(
          const AsrConfig(
            apiKey: 'test-key',
            host: 'https://api.test.com/audio/transcriptions',
            model: 'whisper-test',
            uploadMethod: AudioUploadMethod.url,
          ),
        ).toMap(),
      };
      final delayedProviderEntries = _DelayedProviderEntriesNotifier();

      await tester.pumpWidget(
        app(
          initialRetryData: urlRetryData,
          providerEntriesOverride: delayedProviderEntries,
        ),
      );
      await tester.tap(find.text('打开 ASR'));
      await tester.pumpAndSettle();

      final filePicker = find.widgetWithText(ElevatedButton, '音频文件');
      expect(filePicker, findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(filePicker).onPressed,
        isNull,
        reason:
            'a pending URL-mode retry must not expose the fallback multipart source controls',
      );

      delayedProviderEntries.finishLoad(
        ProviderEntriesState(
          entries: [
            ProviderEntry(
              name: 'ASR',
              type: 'asr',
              configs: [
                ProviderConfigItem(
                  id: 'provider',
                  providerName: 'ASR',
                  host: 'https://api.test.com/audio/transcriptions',
                  key: 'test-key',
                  models: [
                    ModelConfig(
                      id: 'model',
                      name: 'Retry target',
                      modelId: 'whisper-test',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('输入公网音频链接'), findsOneWidget);
      expect(find.text('音频文件'), findsNothing);
    },
  );

  testWidgets(
      'retry file snapshot controls the audio picker after live changes',
      (tester) async {
    final urlProviderEntries = ProviderEntriesNotifier()
      ..state = ProviderEntriesState(
        entries: [
          ProviderEntry(
            id: 'asr-entry',
            name: 'ASR',
            type: 'asr',
            configs: [
              ProviderConfigItem(
                id: 'provider',
                providerName: 'ASR',
                host: 'https://api.test.com/audio/transcriptions',
                key: 'test-key',
                typeConfig: {'uploadMethod': 'url'},
                models: [
                  ModelConfig(
                    id: 'model',
                    name: 'Test ASR',
                    modelId: 'whisper-test',
                  ),
                ],
              ),
            ],
          ),
        ],
      );

    await tester.pumpWidget(
      app(
        initialRetryData: retryData(),
        providerEntriesOverride: urlProviderEntries,
      ),
    );
    await tester.tap(find.text('打开 ASR'));
    await tester.pumpAndSettle();

    expect(find.text('音频文件'), findsOneWidget);
    expect(find.text('输入公网音频链接'), findsNothing);
    expect(serviceCalls, 0);
  });

  testWidgets(
      'missing retry source audio shows a clear error without a request',
      (tester) async {
    final adapter = _EmptyRetryAdapter();
    final store = AsrRetryAudioStore(adapter: adapter);
    final missingReference = AsrAudioReference(
      id: '00000000000000000000000000000000',
      name: 'missing.wav',
      format: 'wav',
      byteLength: 3,
      sha256:
          '0000000000000000000000000000000000000000000000000000000000000000',
    );
    await tester.pumpWidget(app(
      retryStoreOverride: store,
      initialRetryData: {
        'version': 2,
        'audioReference': missingReference.toMap(),
        'modelReference': {'configId': 'provider', 'modelId': 'model'},
        'saveFolder': 'captured-folder',
      },
    ));
    await tester.tap(find.text('打开 ASR'));
    await tester.pumpAndSettle();

    expect(find.textContaining('原始音频文件已丢失'), findsOneWidget);
    expect(serviceCalls, 0);
  });

  testWidgets(
    'missing versioned multi-audio source blocks submitting a replacement',
    (tester) async {
      final adapter = _MemoryRetryAdapter();
      final store = AsrRetryAudioStore(adapter: adapter);
      final restoredReference = await store.save(
        Uint8List.fromList([1, 2, 3]),
        name: 'restored.wav',
        format: 'wav',
        configuredApiKey: 'test-key',
      );
      final missingReference = AsrAudioReference(
        id: '00000000000000000000000000000000',
        name: 'missing.wav',
        format: 'wav',
        byteLength: 3,
        sha256:
            '0000000000000000000000000000000000000000000000000000000000000000',
      );
      final retryConfig = const AsrConfig(
        apiKey: 'test-key',
        host: 'https://api.test.com/audio/transcriptions',
        model: 'whisper-test',
        uploadMethod: AudioUploadMethod.url,
      );
      final data = {
        'version': 2,
        'audioReferences': [
          {'audioReference': restoredReference.toMap(), 'chunks': []},
          {'audioReference': missingReference.toMap(), 'chunks': []},
        ],
        'modelReference': {'configId': 'provider', 'modelId': 'model'},
        'configSnapshot':
            AsrRetryConfigSnapshot.fromConfig(retryConfig).toMap(),
        'saveFolder': 'captured-folder',
      };
      final sourceTaskId = background.addTask(
        type: BackgroundTaskType.asr,
        title: 'Missing versioned source',
        retryData: data,
      );
      background.failTask(sourceTaskId, error: 'previous retry failed');
      await background.pendingPersistence;
      final urlProviderEntries = ProviderEntriesNotifier()
        ..state = ProviderEntriesState(
          entries: [
            ProviderEntry(
              name: 'ASR',
              type: 'asr',
              configs: [
                ProviderConfigItem(
                  id: 'provider',
                  providerName: 'ASR',
                  host: 'https://api.test.com/audio/transcriptions',
                  key: 'test-key',
                  typeConfig: {'uploadMethod': 'url'},
                  models: [
                    ModelConfig(
                      id: 'model',
                      name: 'Test ASR',
                      modelId: 'whisper-test',
                    ),
                  ],
                ),
              ],
            ),
          ],
        );

      await tester.pumpWidget(
        app(
          initialRetryData: data,
          retryStoreOverride: store,
          retryTaskId: sourceTaskId,
          providerEntriesOverride: urlProviderEntries,
        ),
      );
      await tester.tap(find.text('打开 ASR'));
      await tester.pumpAndSettle();
      expect(find.textContaining('原始音频文件已丢失'), findsOneWidget);

      await tester.tap(find.text('输入公网音频链接'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'https://media.example.test/replacement.wav',
      );
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();

      final startButton = find.widgetWithText(FilledButton, '开始识别');
      expect(startButton, findsOneWidget);
      expect(
        tester.widget<FilledButton>(startButton).onPressed,
        isNull,
        reason:
            'a replacement cannot be submitted while the saved multi-audio source set is incomplete',
      );
      expect(background.taskById(sourceTaskId)!.retryData, data);
      expect(serviceCalls, 0);

      await tester.ensureVisible(
        find.text('1. https://media.example.test/replacement.wav'),
      );
      await tester.pumpAndSettle();
      final replacementCard = find.ancestor(
        of: find.text('1. https://media.example.test/replacement.wav'),
        matching: find.byType(Card),
      );
      await tester.tap(
        find.descendant(
            of: replacementCard, matching: find.byIcon(Icons.close)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('输入公网音频链接'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'https://media.example.test/another-replacement.wav',
      );
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(startButton).onPressed,
        isNull,
        reason:
            'removing a replacement cannot clear the incomplete retry state',
      );

      await tester.tap(find.text('清空'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('输入公网音频链接'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'https://media.example.test/new-request.wav',
      );
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('开始识别'));
      await tester.pump();
      await waitForServiceCall(tester);

      expect(background.taskById(sourceTaskId)!.status, TaskStatus.failed);
      expect(background.taskById(sourceTaskId)!.retryData, data);
      expect(background.state, hasLength(2));
      final newTask =
          background.state.singleWhere((task) => task.id != sourceTaskId);
      background.cancelTask(newTask.id);
      releaseResponse.complete();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'versioned retry without audio references asks for reselection',
    (tester) async {
      final retrySnapshots = <Map<String, dynamic>>[
        {
          'version': 2,
          'audioReferences': <dynamic>[],
          'modelReference': {'configId': 'provider', 'modelId': 'model'},
          'saveFolder': 'captured-folder',
        },
        {
          'version': 2,
          'modelReference': {'configId': 'provider', 'modelId': 'model'},
          'saveFolder': 'captured-folder',
        },
      ];
      for (final retryData in retrySnapshots) {
        await tester.pumpWidget(app(initialRetryData: retryData));
        await tester.tap(find.text('打开 ASR'));
        await tester.pumpAndSettle();

        expect(find.text('暂未选择音频文件'), findsOneWidget);
        expect(find.textContaining('重新选择音频'), findsOneWidget);
        expect(serviceCalls, 0);
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'legacy retry with no recoverable audio asks for reselection',
    (tester) async {
      await tester.pumpWidget(app(
        initialRetryData: {
          'audios': [
            {'name': 'missing.wav', 'format': 'wav'},
          ],
        },
      ));
      await tester.tap(find.text('打开 ASR'));
      await tester.pumpAndSettle();

      expect(find.text('暂未选择音频文件'), findsOneWidget);
      expect(find.textContaining('旧版重试音频不可用'), findsOneWidget);
      expect(find.text('清空'), findsOneWidget);
      await tester.tap(find.text('清空'));
      await tester.pumpAndSettle();

      expect(find.textContaining('旧版重试音频不可用'), findsNothing);
      expect(find.text('暂未选择音频文件'), findsOneWidget);
      expect(serviceCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy retry reports a missing source while retaining restored audio',
    (tester) async {
      await tester.pumpWidget(app(
        initialRetryData: {
          'audios': [
            {
              'name': 'restored.wav',
              'format': 'wav',
              'bytes': base64Encode([1, 2, 3]),
            },
            {'name': 'missing.wav', 'format': 'wav'},
          ],
        },
      ));
      await tester.tap(find.text('打开 ASR'));
      await tester.pumpAndSettle();

      expect(find.text('已选择 1 个音频文件'), findsOneWidget);
      expect(find.textContaining('旧版重试音频不可用'), findsOneWidget);
      expect(serviceCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'partially unreadable legacy retry cannot submit or replace its source',
    (tester) async {
      final partialLegacyData = {
        ...retryData(),
        'audios': [
          {
            'name': 'restored.wav',
            'format': 'wav',
            'bytes': base64Encode([1, 2, 3]),
          },
          {'name': 'missing.wav', 'format': 'wav'},
        ],
      };
      final sourceTaskId = background.addTask(
        type: BackgroundTaskType.asr,
        title: 'Partially unreadable legacy retry',
        retryData: partialLegacyData,
        startImmediately: false,
        taskId: 'partial-legacy-retry-source',
      );
      background.failTask(sourceTaskId, error: 'legacy retry');
      await background.pendingPersistence;

      await tester.pumpWidget(app(
        keepPageOpen: true,
        initialRetryData: partialLegacyData,
        retryTaskId: sourceTaskId,
      ));
      await tester.tap(find.text('打开 ASR'));
      await tester.pumpAndSettle();

      expect(find.text('已选择 1 个音频文件'), findsOneWidget);
      expect(find.textContaining('旧版重试音频不可用'), findsOneWidget);
      await tester.tap(find.text('开始识别'));
      await tester.pump();
      await waitForServiceCall(tester);

      expect(background.taskById(sourceTaskId)!.retryData, partialLegacyData);
      expect(serviceCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('versioned multi-audio retries restore every referenced source',
      (tester) async {
    final adapter = _MemoryRetryAdapter();
    final store = AsrRetryAudioStore(adapter: adapter);
    final first = await store.save(
      Uint8List.fromList([1, 2, 3]),
      name: 'one.wav',
      format: 'wav',
    );
    final second = await store.save(
      Uint8List.fromList([4, 5, 6]),
      name: 'two.wav',
      format: 'wav',
    );
    await tester.pumpWidget(app(
      retryStoreOverride: store,
      initialRetryData: {
        'version': 2,
        'audioReferences': [
          {'audioReference': first.toMap(), 'chunks': []},
          {'audioReference': second.toMap(), 'chunks': []},
        ],
        'modelReference': {'configId': 'provider', 'modelId': 'model'},
        'configSnapshot': AsrRetryConfigSnapshot.fromConfig(
          const AsrConfig(
            apiKey: 'test-key',
            host: 'https://api.test.com/audio/transcriptions',
            model: 'whisper-test',
          ),
        ).toMap(),
      },
    ));
    await tester.tap(find.text('打开 ASR'));
    await tester.pumpAndSettle();

    expect(find.text('已选择 2 个音频文件'), findsOneWidget);
    expect(find.text('1. one.wav'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('2. two.wav'), findsOneWidget);
    expect(serviceCalls, 0);
  });
}

class _EmptyRetryAdapter implements AsrRetryStorageAdapter {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<List<String>> keysWithPrefix(String prefix) async => const [];

  @override
  Future<Uint8List?> read(String key) async => null;

  @override
  Future<void> write(String key, Uint8List bytes) async {}
}
