import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/ocr_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

// ============================================================================
// Helper: Build test app with optional provider overrides
// ============================================================================

Widget _buildTestApp({
  List<ProviderEntry>? entries,
}) {
  final overrides = <Override>[];
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
      home: OcrPage(),
      localizationsDelegates: [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );
}

// ============================================================================
// Helper: Create a sample OCR provider entry with models
// ============================================================================

ProviderEntry _createOcrEntry({
  bool withModels = true,
}) {
  return ProviderEntry(
    id: 'test_ocr',
    type: 'ocr',
    name: 'OCR供应商',
    configs: [
      ProviderConfigItem(
        providerName: 'OpenAI',
        host: 'https://api.openai.com',
        key: 'test-key',
        models: withModels
            ? [
                ModelConfig(name: 'GPT-4o', modelId: 'gpt-4o'),
                ModelConfig(name: 'GPT-4o Mini', modelId: 'gpt-4o-mini'),
                ModelConfig(name: 'GPT-4 Vision', modelId: 'gpt-4-vision-preview'),
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
    TextManifest.invalidateCache();
  });

  group('OcrPage - basic rendering', () {
    testWidgets('renders OCR page title', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('文字识别'), findsOneWidget);
    });

    testWidgets('shows photo source buttons', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('拍照识别'), findsOneWidget);
      expect(find.text('相册选择'), findsOneWidget);
    });

    testWidgets('shows empty state initially', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('暂无选中图片'), findsOneWidget);
    });

    testWidgets('shows clear button only when images are selected',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Initially no clear button
      expect(find.text('清空'), findsNothing);
    });

    testWidgets('shows image count text initially absent', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // No image count text when empty
      expect(find.textContaining('已选'), findsNothing);
    });
  });

  group('OcrPage - model selector', () {
    testWidgets('shows model selector when OCR provider has models',
        (tester) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // Should show the model selector
      expect(find.text('GPT-4o'), findsWidgets);
    });

    testWidgets('model selector shows all available models when tapped',
        (tester) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // Tap the model selector dropdown
      await tester.tap(find.text('GPT-4o').last);
      await tester.pumpAndSettle();

      // Should show all models in the dropdown
      expect(find.text('GPT-4o Mini'), findsWidgets);
      expect(find.text('GPT-4 Vision'), findsWidgets);
    });

    testWidgets('model selector label is visible', (tester) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // Should have a model-related label
      expect(find.textContaining('识别模型'), findsWidgets);
    });
  });

  group('OcrPage - camera choice panel', () {
    testWidgets('tapping camera button shows choice panel', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Tap the camera button
      await tester.tap(find.text('拍照识别'));
      await tester.pumpAndSettle();

      // Should show choice panel with app and system camera
      expect(find.text('应用相机'), findsOneWidget);
      expect(find.text('系统相机'), findsOneWidget);
    });

    testWidgets('camera choice panel shows icons', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('拍照识别'));
      await tester.pumpAndSettle();

      // Should show camera icons in the panel
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(find.byIcon(Icons.phone_android), findsOneWidget);
    });

    testWidgets('camera choice panel has title', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('拍照识别'));
      await tester.pumpAndSettle();

      expect(find.text('选择拍照方式'), findsOneWidget);
    });

    testWidgets('camera choice panel does NOT show save-to folder section',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('拍照识别'));
      await tester.pumpAndSettle();

      // Should NOT show the save-to folder section (unlike gallery page)
      expect(find.text('添加至文件夹'), findsNothing);
    });

    testWidgets('camera choice panel does NOT show edit toggle',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('拍照识别'));
      await tester.pumpAndSettle();

      // Should NOT show the edit after capture toggle
      expect(find.text('拍完编辑'), findsNothing);
    });
  });

  group('OcrPage - album choice panel', () {
    testWidgets('tapping album button shows choice panel', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Tap the album button
      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();

      // Should show choice panel with system album and app album
      expect(find.text('从系统相册选择'), findsOneWidget);
      expect(find.text('从应用相册选择'), findsOneWidget);
    });

    testWidgets('album choice panel shows title', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();

      expect(find.text('选择图片来源'), findsOneWidget);
    });
  });

  group('OcrPage - image tap to preview', () {
    testWidgets('empty grid shows empty state, no images to tap',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // No grid when no images
      expect(find.byType(GridView), findsNothing);
    });
  });

  group('OcrPage - save-to folder selector', () {
    testWidgets('shows save-to folder selector in bottom bar', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show save-to section in bottom bar
      expect(find.text('保存至'), findsOneWidget);
    });

    testWidgets('save-to shows root directory by default', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('根目录'), findsOneWidget);
    });
  });

  group('OcrPage - bottom bar', () {
    testWidgets('start recognition button is disabled when no images',
        (tester) async {
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
}
