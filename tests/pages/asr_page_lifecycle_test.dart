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
  }) async {
    _onStarted(cancelToken);
    await _responseGate;
    return const AsrResult(text: 'page result');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late BackgroundTaskNotifier background;
  late ProviderEntriesNotifier providerEntries;
  late Completer<void> releaseResponse;
  late int serviceCalls;
  CancelToken? activeToken;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
    directory = await Directory.systemTemp.createTemp('asr_page_owned_');
    BackgroundTaskNotifier.debugStorageDirectoryOverride = directory.path;
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
    serviceCalls = 0;
    activeToken = null;
  });

  tearDown(() async {
    if (background.mounted) background.dispose();
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
        'saveFolder': 'captured-folder',
      };

  Widget app({bool keepPageOpen = false}) => ProviderScope(
        overrides: [
          providerEntriesProvider.overrideWith((ref) => providerEntries),
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
                      retryData: retryData(),
                      asrServiceFactory: (config) {
                        serviceCalls++;
                        return _ControlledAsrService(
                          config,
                          responseGate: releaseResponse.future,
                          onStarted: (token) {
                            activeToken = token;
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

  testWidgets(
    'starting then leaving the page keeps the captured task running',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.tap(find.text('打开 ASR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('开始识别'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('打开 ASR'), findsOneWidget);
      expect(background.state, hasLength(1));
      expect(background.state.single.status, TaskStatus.running);
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
    await tester.tap(find.byType(FilledButton).last);
    await tester.pump();

    expect(background.state, hasLength(1));
    expect(serviceCalls, 1);
    expect(activeToken?.isCancelled, isNot(true));
    background.cancelTask(background.state.single.id);
    releaseResponse.complete();
  });
}
