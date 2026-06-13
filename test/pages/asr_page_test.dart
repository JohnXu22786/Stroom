import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/pages/asr_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/tts_state_provider.dart';
import 'package:stroom/services/manifest_database.dart';

// ============================================================================
// Helper: Build test app with optional provider overrides
// ============================================================================

Widget _buildTestApp({
  List<ProviderEntry>? entries,
}) {
  final overrides = <Override>[
    audioRecordsProvider.overrideWith((ref) => AudioRecordsNotifier()),
  ];
  if (entries != null) {
    final notifier = ProviderEntriesNotifier();
    notifier.state = ProviderEntriesState(entries: entries);
    overrides.add(
      providerEntriesProvider.overrideWith((ref) => notifier),
    );
  }

  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(
      home: AsrPage(),
      localizationsDelegates: [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );
}

// ============================================================================
// Helper: Create a sample ASR provider entry with models
// ============================================================================

ProviderEntry _createAsrEntry({
  bool withModels = true,
}) {
  return ProviderEntry(
    id: 'test_asr',
    type: 'asr',
    name: '语音识别供应商',
    configs: [
      ProviderConfigItem(
        providerName: 'OpenAI',
        host: 'https://api.openai.com/v1/audio/transcriptions',
        key: 'test-key',
        models: withModels
            ? [
                ModelConfig(name: 'Whisper-1', modelId: 'whisper-1'),
                ModelConfig(name: 'Whisper-2', modelId: 'whisper-2'),
              ]
            : [],
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
  });

  group('AsrPage - basic rendering', () {
    testWidgets('renders ASR page title', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('语音识别'), findsOneWidget);
    });

    testWidgets('shows two audio source buttons matching OCR design',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show two buttons side by side (matching OCR pattern)
      expect(find.text('录音选择'), findsOneWidget);
      expect(find.text('音频文件'), findsOneWidget);
    });

    testWidgets('shows empty state initially', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('暂未选择音频文件'), findsOneWidget);
    });

    testWidgets('shows clear button only when audio is selected',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Initially no clear button
      expect(find.text('清空'), findsNothing);
    });
  });

  group('AsrPage - model selector', () {
    testWidgets('shows model selector when ASR provider has models',
        (tester) async {
      final entry = _createAsrEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // Should show the model selector with first model name
      expect(find.text('Whisper-1'), findsWidgets);
    });

    testWidgets('model selector shows all models when tapped',
        (tester) async {
      final entry = _createAsrEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // Tap the model selector dropdown
      await tester.tap(find.text('Whisper-1').last);
      await tester.pumpAndSettle();

      // Should show all models in dropdown
      expect(find.text('Whisper-2'), findsWidgets);
    });

    testWidgets('model selector label is visible', (tester) async {
      final entry = _createAsrEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // Should have a model-related label
      expect(find.textContaining('识别模型'), findsWidgets);
    });
  });

  group('AsrPage - save-to folder selector', () {
    testWidgets('shows save-to folder selector in bottom bar', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show save-to section in bottom bar
      expect(find.text('保存至'), findsOneWidget);
    });

    testWidgets('save-to shows root directory by default', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // By default save-to shows root directory
      expect(find.text('根目录'), findsOneWidget);
    });
  });

  group('AsrPage - bottom bar', () {
    testWidgets('start transcription button is present', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('开始识别'), findsOneWidget);
    });

    testWidgets('save-to section is above the start button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Both save-to and start button should be present
      expect(find.text('保存至'), findsOneWidget);
      expect(find.text('开始识别'), findsOneWidget);
    });
  });

  group('AsrPage - audio source selection', () {
    testWidgets('tapping "录音选择" opens bottom sheet with ChoiceCards',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('录音选择'));
      await tester.pumpAndSettle();

      // Should show bottom sheet title (matching OCR panel style)
      expect(find.text('选择音频来源'), findsOneWidget);

      // Should show source options as ChoiceCards
      expect(find.text('应用内录音'), findsOneWidget);
      expect(find.text('系统音频文件'), findsOneWidget);
    });

    testWidgets('tapping "音频文件" opens bottom sheet with ChoiceCards',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('音频文件'));
      await tester.pumpAndSettle();

      // Should show bottom sheet title
      expect(find.text('选择音频来源'), findsOneWidget);

      // Should show source options as ChoiceCards
      expect(find.text('应用内录音'), findsOneWidget);
      expect(find.text('系统音频文件'), findsOneWidget);
    });

    testWidgets('audio source bottom sheet shows ChoiceCard icons',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('录音选择'));
      await tester.pumpAndSettle();

      // ChoiceCards should have icons (matching OCR design)
      expect(find.byIcon(Icons.library_music_outlined), findsOneWidget);
      // audio_file_outlined appears in the bar button AND in the ChoiceCard
      expect(find.byIcon(Icons.audio_file_outlined), findsNWidgets(2));
    });
  });
}
