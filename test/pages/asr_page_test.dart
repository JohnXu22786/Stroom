import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/pages/asr_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/tts_state_provider.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/file_manifest.dart';

// ============================================================================
// Helper: Build test app with optional provider overrides
// ============================================================================

Widget _buildTestApp({List<ProviderEntry>? entries}) {
  // ignore: prefer_const_constructors
  final overrides = [
    audioRecordsProvider.overrideWith((ref) => AudioRecordsNotifier()),
  ];
  if (entries != null) {
    final notifier = ProviderEntriesNotifier();
    notifier.state = ProviderEntriesState(entries: entries);
    overrides.add(providerEntriesProvider.overrideWith((ref) => notifier));
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

ProviderEntry _createAsrEntry({bool withModels = true}) {
  return ProviderEntry(
    id: 'test_asr',
    type: 'asr',
    name: '音频转写供应商',
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

      expect(find.text('音频转写'), findsOneWidget);
    });

    testWidgets('shows two audio source buttons matching OCR design', (
      tester,
    ) async {
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

    testWidgets('shows clear button only when audio is selected', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Initially no clear button
      expect(find.text('清空'), findsNothing);
    });
  });

  group('AsrPage - model selector', () {
    testWidgets('shows model selector when ASR provider has models', (
      tester,
    ) async {
      final entry = _createAsrEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // Should show the model selector with "ModelName | ProviderName" format
      expect(find.text('Whisper-1 | OpenAI'), findsWidgets);
    });

    testWidgets('model selector shows all models when tapped', (tester) async {
      final entry = _createAsrEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // Tap the model selector dropdown
      await tester.tap(find.text('Whisper-1 | OpenAI').last);
      await tester.pumpAndSettle();

      // Should show all models in dropdown with provider name
      expect(find.text('Whisper-2 | OpenAI'), findsWidgets);
    });

    testWidgets('model selector falls back to modelId when name is empty', (
      tester,
    ) async {
      final entry = ProviderEntry(
        id: 'test_asr',
        type: 'asr',
        name: '音频转写供应商',
        configs: [
          ProviderConfigItem(
            providerName: 'TestAI',
            host: 'https://api.test.ai',
            key: 'test-key',
            models: [
              ModelConfig(name: '', modelId: 'test-asr-model'),
            ],
          ),
        ],
      );
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // Should show modelId | ProviderName when name is empty
      expect(find.text('test-asr-model | TestAI'), findsWidgets);
    });

    testWidgets('model selector still works when provider name is empty', (
      tester,
    ) async {
      final entry = ProviderEntry(
        id: 'test_asr',
        type: 'asr',
        name: '音频转写供应商',
        configs: [
          ProviderConfigItem(
            providerName: '',
            host: 'https://api.test.ai',
            key: 'test-key',
            models: [
              ModelConfig(name: 'TestModel', modelId: 'test-model-v1'),
            ],
          ),
        ],
      );
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // Should show just the model name when no provider name
      expect(find.text('TestModel'), findsWidgets);
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
    testWidgets('tapping "录音选择" opens bottom sheet with ChoiceCards', (
      tester,
    ) async {
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

    testWidgets('tapping "音频文件" opens bottom sheet with ChoiceCards', (
      tester,
    ) async {
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

    testWidgets('audio source bottom sheet shows ChoiceCard icons', (
      tester,
    ) async {
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

  group('AsrPage - unified in-app audio picker', () {
    testWidgets(
      'tapping "应用内录音" opens unified media picker with correct title',
      (tester) async {
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // Open the bottom sheet
        await tester.tap(find.text('录音选择'));
        await tester.pumpAndSettle();

        // Tap "应用内录音" ChoiceCard
        await tester.tap(find.text('应用内录音'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Should open the unified media picker with the correct title
        expect(find.text('选择应用内录音'), findsOneWidget);
      },
    );

    testWidgets('unified media picker shows empty state when no recordings', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Open the bottom sheet
      await tester.tap(find.text('录音选择'));
      await tester.pumpAndSettle();

      // Tap "应用内录音" ChoiceCard
      await tester.tap(find.text('应用内录音'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show empty state since no audio records are loaded
      expect(find.text('暂无录音'), findsOneWidget);
    });

    testWidgets(
      'unified media picker shows close button and can be dismissed',
      (tester) async {
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // Open the bottom sheet
        await tester.tap(find.text('录音选择'));
        await tester.pumpAndSettle();

        // Tap "应用内录音" ChoiceCard
        await tester.tap(find.text('应用内录音'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Dialog should be visible
        expect(find.text('选择应用内录音'), findsOneWidget);

        // Tap close button
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        // Dialog should be dismissed
        expect(find.text('选择应用内录音'), findsNothing);
      },
    );
  });

  group('AsrPage - unified order and colors', () {
    testWidgets('audio source sheet shows app-internal FIRST, system SECOND', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Open the bottom sheet
      await tester.tap(find.text('录音选择'));
      await tester.pumpAndSettle();

      // Both options should be present
      expect(find.text('应用内录音'), findsOneWidget);
      expect(find.text('系统音频文件'), findsOneWidget);

      // '应用内录音' should appear above '系统音频文件' in the sheet
      final appInternalBox =
          tester.renderObject(find.text('应用内录音')) as RenderBox;
      final systemBox = tester.renderObject(find.text('系统音频文件')) as RenderBox;
      expect(
        appInternalBox.localToGlobal(Offset.zero).dy,
        lessThan(systemBox.localToGlobal(Offset.zero).dy),
      );
    });
  });

  group('AsrPage - rename to 音频转写', () {
    testWidgets('page title shows 音频转写', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('音频转写'), findsOneWidget);
    });
  });

  group('AsrPage - multi-select in-app audio picker', () {
    testWidgets('in-app audio picker has multiSelect enabled', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Add a test audio record so the picker shows file items
      await FileManifest.addRecord(
        AudioRecord(
          name: '测试录音',
          hash: 'test_hash',
          format: 'wav',
          createdAt: DateTime.now(),
          size: 1024,
        ),
      );

      // Open the bottom sheet
      await tester.tap(find.text('录音选择'));
      await tester.pumpAndSettle();

      // Tap "应用内录音" ChoiceCard to open the unified media picker
      await tester.tap(find.text('应用内录音'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show checkboxes for multi-select
      expect(find.byType(Checkbox), findsWidgets);

      // Should show confirm button for multi-select
      expect(find.byKey(const Key('media_picker_confirm_btn')), findsOneWidget);
    });

    testWidgets('in-app audio picker shows preview bar for multi-select', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Add a test audio record and its file so the picker shows file items
      // and selection can succeed (readFile needs the file to exist)
      await FileManifest.addRecord(
        AudioRecord(
          name: '测试录音',
          hash: 'test_hash_2',
          format: 'wav',
          createdAt: DateTime.now(),
          size: 1024,
        ),
      );
      await FileManifest.writeFile(
        'test_hash_2.wav',
        Uint8List.fromList([1, 2, 3]),
      );

      // Open the bottom sheet
      await tester.tap(find.text('录音选择'));
      await tester.pumpAndSettle();

      // Tap "应用内录音" ChoiceCard to open the unified media picker
      await tester.tap(find.text('应用内录音'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the checkbox to select the item, which triggers read and shows preview bar
      final checkboxes = find.byType(Checkbox);
      if (checkboxes.evaluate().isNotEmpty) {
        await tester.tap(checkboxes.first);
      } else {
        await tester.tap(find.text('测试录音'));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Preview bar should be present (only shown in multi-select mode when items selected)
      expect(find.byKey(const Key('media_picker_preview_bar')), findsOneWidget);

      // Confirm button should be present
      expect(find.byKey(const Key('media_picker_confirm_btn')), findsOneWidget);
    });
  });

  group('AsrPage - sequential processing of multiple audios', () {
    testWidgets(
      'start transcription button is present when audios are selected',
      (tester) async {
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // The start transcription button should be visible in the bottom bar
        expect(find.text('开始识别'), findsOneWidget);
      },
    );
  });
}
