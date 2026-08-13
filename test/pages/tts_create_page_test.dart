import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/pages/tts_create_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/services/manifest_database.dart';

// ============================================================================
// Helper: Build test app with optional provider overrides
// ============================================================================

Widget _buildTestApp({List<ProviderEntry>? entries, SynthesisTask? retry}) {
  // ignore: prefer_const_constructors
  final overrides = [
    taskListProvider.overrideWith((ref) => TaskListNotifier(ref)),
  ];
  if (entries != null) {
    final notifier = ProviderEntriesNotifier();
    notifier.state = ProviderEntriesState(entries: entries);
    overrides.add(providerEntriesProvider.overrideWith((ref) => notifier));
  }

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: retry != null
          ? TTSCreatePage(retryTask: retry)
          : const TTSCreatePage(),
      localizationsDelegates: [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );
}

// ============================================================================
// Helper: Create a sample TTS provider entry with models
// ============================================================================

ProviderEntry _createTtsEntry({bool withModels = true}) {
  return ProviderEntry(
    id: 'test_tts',
    type: 'tts',
    name: 'TTS供应商',
    configs: [
      ProviderConfigItem(
        providerName: 'OpenAI',
        host: 'https://api.openai.com/v1',
        key: 'test-key',
        models: withModels
            ? [
                ModelConfig(name: 'TTS-1', modelId: 'tts-1'),
                ModelConfig(name: 'TTS-2', modelId: 'tts-2'),
              ]
            : [],
      ),
    ],
  );
}

/// A retry task whose model ('TTS-2' / 'tts-2') is the SECOND model of
/// [\_createTtsEntry] — a wrong fallback to the first model would fail tests.
SynthesisTask _retryTask({String? folder}) {
  return SynthesisTask(
    id: 't1',
    title: '任务',
    text: '文本',
    providerConfig: ProviderConfigItem(
      providerName: 'OpenAI',
      host: 'https://api.openai.com/v1',
      key: 'key',
    ),
    modelConfig: ModelConfig(name: 'TTS-2', modelId: 'tts-2'),
    folder: folder ?? '',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
  });

  group('TTSCreatePage - model selector (OCR/ASR style)', () {
    testWidgets('shows pill model selector with "ModelName | ProviderName"', (
      tester,
    ) async {
      final entry = _createTtsEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // Pill-style selector with label + first model auto-selected
      expect(find.text('合成模型'), findsOneWidget);
      expect(find.text('TTS-1 | OpenAI'), findsOneWidget);
    });

    testWidgets('model selector shows all models when tapped', (tester) async {
      final entry = _createTtsEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('TTS-1 | OpenAI'));
      await tester.pumpAndSettle();

      expect(find.text('TTS-2 | OpenAI'), findsWidgets);
    });

    testWidgets('shows configure prompt when no TTS entry exists', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(entries: []));
      await tester.pumpAndSettle();

      expect(find.text('合成模型'), findsOneWidget);
      expect(find.text('去配置'), findsOneWidget);
    });

    testWidgets('shows configure prompt when TTS entry has no models', (
      tester,
    ) async {
      final entry = _createTtsEntry(withModels: false);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      expect(find.text('合成模型'), findsOneWidget);
      expect(find.text('去配置'), findsOneWidget);
    });

    testWidgets('retry task selects its own model when it exists in the list', (
      tester,
    ) async {
      final entry = _createTtsEntry(withModels: true);
      await tester
          .pumpWidget(_buildTestApp(entries: [entry], retry: _retryTask()));
      await tester.pumpAndSettle();

      // The retry's model (TTS-2) must be selected — NOT auto-selected
      // first model (TTS-1). This pins the retry model-match logic.
      expect(find.text('TTS-2 | OpenAI'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('retry model survives the provider loading late (empty→models)',
        (
      tester,
    ) async {
      // Simulate the async provider load: the first state has the TTS entry
      // with zero models (clears the retry preset), then models arrive.
      final notifier = ProviderEntriesNotifier();
      notifier.state = ProviderEntriesState(
        entries: [_createTtsEntry(withModels: false)],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskListProvider.overrideWith((ref) => TaskListNotifier(ref)),
            providerEntriesProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: TTSCreatePage(retryTask: _retryTask()),
            localizationsDelegates: [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Models arrive now.
      notifier.state = ProviderEntriesState(
        entries: [_createTtsEntry(withModels: true)],
      );
      await tester.pumpAndSettle();

      // No crash; the retry's model (TTS-2) is selected — not the first.
      expect(find.text('TTS-2 | OpenAI'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('auto-select clamps speed to a narrow-range model', (
      tester,
    ) async {
      // A model whose speed range excludes the default 1.0 would make the
      // Slider assert if clamping failed.
      final entry = ProviderEntry(
        id: 'test_tts',
        type: 'tts',
        name: 'TTS供应商',
        configs: [
          ProviderConfigItem(
            providerName: 'NarrowAI',
            host: 'https://api.narrow.ai/v1',
            key: 'key',
            models: [
              ModelConfig(
                name: 'Narrow',
                modelId: 'narrow-1',
                hasSpeed: true,
                speedMin: 0.5,
                speedMax: 0.8,
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('TTSCreatePage - save-to folder selector', () {
    testWidgets('save-to shows root directory by default', (tester) async {
      await tester.pumpWidget(_buildTestApp(entries: []));
      await tester.pumpAndSettle();

      expect(find.text('保存至'), findsOneWidget);
      expect(find.text('根目录'), findsOneWidget);
    });

    testWidgets('tapping 保存至 opens folder picker dialog', (tester) async {
      await tester.pumpWidget(_buildTestApp(entries: []));
      await tester.pumpAndSettle();

      await tester.tap(find.text('根目录'));
      await tester.pumpAndSettle();

      expect(find.text('选择保存文件夹'), findsOneWidget);
    });

    testWidgets('retry task restores its save folder in the selector', (
      tester,
    ) async {
      final retryTask = SynthesisTask(
        id: 't1',
        title: '任务',
        text: '文本',
        providerConfig: ProviderConfigItem(
          providerName: 'OpenAI',
          host: 'https://api.openai.com/v1',
          key: 'key',
        ),
        modelConfig: ModelConfig(name: 'TTS-1', modelId: 'tts-1'),
        folder: '我的录音/子目录',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskListProvider.overrideWith((ref) => TaskListNotifier(ref)),
          ],
          child: MaterialApp(
            home: TTSCreatePage(retryTask: retryTask),
            localizationsDelegates: [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('我的录音/子目录'), findsOneWidget);
    });

    testWidgets('overwrite flow pre-fills the save folder (initialFolder)', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskListProvider.overrideWith((ref) => TaskListNotifier(ref)),
          ],
          child: const MaterialApp(
            home: TTSCreatePage(initialFolder: '朗读合集'),
            localizationsDelegates: [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('朗读合集'), findsOneWidget);
    });
  });

  group('TTSCreatePage - file path preview', () {
    testWidgets('shows full save path preview when text is entered', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(entries: []));
      await tester.pumpAndSettle();

      // Second TextField is the 转换文本 input (first is 录音标题)
      await tester.enterText(find.byType(TextField).at(1), '你好世界');
      await tester.pump();

      expect(find.text('将保存为: 根目录/你好世界.wav'), findsOneWidget);
    });

    testWidgets('path preview uses the title when title is entered', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(entries: []));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), '你好世界');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(0), '我的录音');
      await tester.pump();

      expect(find.text('将保存为: 根目录/我的录音.wav'), findsOneWidget);
    });
  });

  group('TTSCreatePage - error banner', () {
    testWidgets('generate without a model shows config error banner', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(entries: []));
      await tester.pumpAndSettle();

      await tester.tap(find.text('生成录音'));
      await tester.pump();

      expect(find.text('请先在设置中配置语音合成供应商和模型'), findsOneWidget);
    });

    testWidgets('generate with empty text shows error banner', (tester) async {
      final entry = _createTtsEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('生成录音'));
      await tester.pump();

      expect(find.text('请输入要转换的文本'), findsOneWidget);
    });

    testWidgets('error banner close button dismisses it', (tester) async {
      await tester.pumpWidget(_buildTestApp(entries: []));
      await tester.pumpAndSettle();

      await tester.tap(find.text('生成录音'));
      await tester.pump();
      expect(find.text('请先在设置中配置语音合成供应商和模型'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(find.text('请先在设置中配置语音合成供应商和模型'), findsNothing);
    });

    testWidgets('empty-text error banner dismisses once text is entered', (
      tester,
    ) async {
      final entry = _createTtsEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('生成录音'));
      await tester.pump();
      expect(find.text('请输入要转换的文本'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(1), '你好');
      await tester.pump();

      expect(find.text('请输入要转换的文本'), findsNothing);
    });
  });

  group('TTSCreatePage - clear action', () {
    testWidgets('清空 action appears with text and clears both fields', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(entries: []));
      await tester.pumpAndSettle();

      expect(find.text('清空'), findsNothing);

      await tester.enterText(find.byType(TextField).at(1), '你好世界');
      await tester.pump();
      expect(find.text('清空'), findsOneWidget);

      await tester.tap(find.text('清空'));
      await tester.pump();

      expect(find.text('清空'), findsNothing);
      expect(find.text('将保存为: 根目录/你好世界.wav'), findsNothing);
    });
  });

  // ====================================================================
  // SynthesisTask folder persistence (retry keeps the save folder)
  // ====================================================================

  group('SynthesisTask folder serialization', () {
    test('folder survives toMap/fromMap round-trip', () {
      final task = SynthesisTask(
        id: 't1',
        title: '任务',
        text: '文本',
        providerConfig: ProviderConfigItem(
          providerName: 'OpenAI',
          host: 'https://api.openai.com/v1',
          key: 'key',
        ),
        modelConfig: ModelConfig(name: 'TTS-1', modelId: 'tts-1'),
        folder: '我的录音/子目录',
      );

      final restored = SynthesisTask.fromMap(task.toMap());

      expect(restored.folder, '我的录音/子目录');
    });

    test('folder defaults to empty for legacy tasks', () {
      final task = SynthesisTask.fromMap({
        'id': 't1',
        'title': '任务',
        'status': 'completed',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'text': '文本',
        'providerConfig': ProviderConfigItem(
          providerName: 'OpenAI',
          host: 'https://api.openai.com/v1',
          key: 'key',
        ).toMap(),
        'modelConfig': ModelConfig(name: 'TTS-1', modelId: 'tts-1').toMap(),
      });

      expect(task.folder, '');
    });
  });
}
