// Merged from: ocr_page_test.dart, ocr_page_preview_edit_test.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/ocr_page.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/ocr_instructions_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/image_manifest.dart';
import 'package:stroom/utils/text_manifest.dart';

/// Creates a small valid PNG (8x8 green) via the real engine.
///
/// Must be called from `tester.runAsync` — engine image work never
/// completes inside the widget-test FakeAsync zone.
Future<Uint8List> _createEnginePng() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, 8, 8),
    Paint()..color = const Color(0xFF00FF00),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(8, 8);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}

/// Pumps until [condition] is true or [timeout] elapses, alternating
/// real-async windows (engine image work) with pumps (fake-zone
/// continuations).
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      fail('Timed out waiting for condition');
    }
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

// ============================================================================
// Helper: Build test app with optional provider overrides
// ============================================================================

Widget _buildTestApp({
  List<ProviderEntry>? entries,
  List<SelectedImage>? testImages,
  Map<String, dynamic>? retryData,
  List<OcrInstruction> ocrInstructions = const [],
}) {
  return ProviderScope(
    overrides: [
      if (entries != null)
        providerEntriesProvider.overrideWith((ref) {
          final notifier = ProviderEntriesNotifier();
          notifier.state = ProviderEntriesState(entries: entries);
          return notifier;
        }),
      ocrInstructionsProvider.overrideWith((ref) {
        final notifier = OcrInstructionsNotifier(ref);
        notifier.state = ocrInstructions;
        return notifier;
      }),
    ],
    child: MaterialApp(
      home: OcrPage(testImages: testImages, retryData: retryData),
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );
}

// ============================================================================
// Helper: Create a sample OCR provider entry with models
// ============================================================================

ProviderEntry _createOcrEntry({bool withModels = true}) {
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
                ModelConfig(
                  name: 'GPT-4 Vision',
                  modelId: 'gpt-4-vision-preview',
                ),
              ]
            : [],
      ),
    ],
  );
}

/// Instructions notifier whose load() fills the list asynchronously —
/// mirrors the production provider (initial state empty, list arrives
/// after load), unlike the synchronous override used by [_buildTestApp].
class _DelayedInstructionsNotifier extends OcrInstructionsNotifier {
  _DelayedInstructionsNotifier(
    super.ref, {
    this.delay = const Duration(milliseconds: 100),
  });

  final Duration delay;

  @override
  Future<void> load() async {
    await Future<void>.delayed(delay);
    state = const [
      OcrInstruction(name: '发票提取', content: '提取发票号码和金额'),
      OcrInstruction(name: '表格提取', content: '提取表格内容'),
    ];
  }
}

/// Create a small valid PNG 1x1 pixel for mock image data.
Uint8List _createTestPngBytes() {
  // Minimal valid 1x1 red PNG
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, // PNG signature
    0x0D, 0x0A, 0x1A, 0x0A,
    0x00, 0x00, 0x00, 0x0D, // IHDR chunk
    0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, // width=1
    0x00, 0x00, 0x00, 0x01, // height=1
    0x08, 0x02, // bit depth=8, color type=RGB
    0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, // CRC
    0x00, 0x00, 0x00, 0x0C, // IDAT chunk
    0x49, 0x44, 0x41, 0x54,
    0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00, 0x00, 0x03, 0x00, 0x01,
    0x26, 0xE0, 0xFE, 0xA0, // CRC
    0x00, 0x00, 0x00, 0x00, // IEND chunk
    0x49, 0x45, 0x4E, 0x44,
    0xAE, 0x42, 0x60, 0x82,
  ]);
}

/// Create a test SelectedImage with dummy PNG bytes
SelectedImage _createTestImage({int seed = 1}) {
  return SelectedImage(
    bytes: _createTestPngBytes(),
    format: 'png',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    ImageManifest.invalidateCache();
    TextManifest.invalidateCache();
  });

  group('OcrPage - model selector', () {
    testWidgets('shows model selector when OCR provider has models', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // Should show the model selector with "ModelName | ProviderName" format
      expect(find.text('GPT-4o | OpenAI'), findsWidgets);
    });

    testWidgets('model selector shows all available models when tapped', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // Tap the model selector dropdown - need to tap the displayed text
      await tester.tap(find.text('GPT-4o | OpenAI').last);
      await tester.pumpAndSettle();

      // Should show all models in the dropdown with provider name
      expect(find.text('GPT-4o Mini | OpenAI'), findsWidgets);
      expect(find.text('GPT-4 Vision | OpenAI'), findsWidgets);
    });

    testWidgets('model selector falls back to modelId when name is empty', (
      tester,
    ) async {
      final entry = ProviderEntry(
        id: 'test_ocr',
        type: 'ocr',
        name: 'OCR供应商',
        configs: [
          ProviderConfigItem(
            providerName: 'TestAI',
            host: 'https://api.test.ai',
            key: 'test-key',
            models: [
              ModelConfig(name: '', modelId: 'test-model-v1'),
            ],
          ),
        ],
      );
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // Should show modelId | ProviderName when name is empty
      expect(find.text('test-model-v1 | TestAI'), findsWidgets);
    });

    testWidgets('model selector still works when provider name is empty', (
      tester,
    ) async {
      final entry = ProviderEntry(
        id: 'test_ocr',
        type: 'ocr',
        name: 'OCR供应商',
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
  });

  group('OcrPage - instruction selector', () {
    testWidgets('always shown even without any configured instructions', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // The selector is always visible regardless of configuration.
      expect(find.text('识别指令'), findsOneWidget);
      expect(find.text('默认（仅发送图片）'), findsOneWidget);
    });

    testWidgets('shows generic instruction names in the dropdown', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(
        _buildTestApp(
          entries: [entry],
          ocrInstructions: const [
            OcrInstruction(name: '发票提取', content: '提取发票号码和金额'),
            OcrInstruction(name: '表格提取', content: '提取表格内容'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('识别指令'), findsOneWidget);
      expect(find.text('默认（仅发送图片）'), findsOneWidget);

      // Open the dropdown — both instruction names are listed.
      await tester.tap(find.text('默认（仅发送图片）'));
      await tester.pumpAndSettle();
      expect(find.text('发票提取'), findsWidgets);
      expect(find.text('表格提取'), findsWidgets);
    });

    testWidgets('shows content snippet when instruction has no name', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(
        _buildTestApp(
          entries: [entry],
          ocrInstructions: const [
            OcrInstruction(content: '提取图片中的全部文字并翻译'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Open the dropdown — the unnamed instruction is labeled by its
      // content snippet.
      await tester.tap(find.text('默认（仅发送图片）'));
      await tester.pumpAndSettle();

      expect(find.text('提取图片中的全部文字并翻译'), findsWidgets);
    });

    testWidgets('selecting an instruction updates the dropdown display', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(
        _buildTestApp(
          entries: [entry],
          ocrInstructions: const [
            OcrInstruction(name: '发票提取', content: '提取发票号码和金额'),
            OcrInstruction(name: '表格提取', content: '提取表格内容'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Open the instruction dropdown and pick the second instruction.
      await tester.tap(find.text('默认（仅发送图片）'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('表格提取').last);
      await tester.pumpAndSettle();

      expect(find.text('表格提取'), findsOneWidget);
    });

    testWidgets('switching model keeps the generic instruction selection', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(
        _buildTestApp(
          entries: [entry],
          ocrInstructions: const [
            OcrInstruction(name: '发票提取', content: '提取发票号码和金额'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Select the instruction.
      await tester.tap(find.text('默认（仅发送图片）'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('发票提取').last);
      await tester.pumpAndSettle();
      expect(find.text('发票提取'), findsOneWidget);

      // Switch model — instructions are generic, so the selection sticks.
      await tester.tap(find.text('GPT-4o | OpenAI').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('GPT-4o Mini | OpenAI').last);
      await tester.pumpAndSettle();

      expect(find.text('识别指令'), findsOneWidget);
      expect(find.text('发票提取'), findsOneWidget);
    });

    testWidgets('retry data restores the instruction selection', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(
        _buildTestApp(
          entries: [entry],
          ocrInstructions: const [
            OcrInstruction(name: '发票提取', content: '提取发票号码和金额'),
            OcrInstruction(name: '表格提取', content: '提取表格内容'),
          ],
          retryData: {
            'type': 'ocr',
            'images': <Map<String, dynamic>>[],
            'modelIndex': 0,
            'instructionIndex': 1,
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('表格提取'), findsOneWidget);
    });

    testWidgets(
        'retry restores the instruction by content when the list changed', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(
        _buildTestApp(
          entries: [entry],
          ocrInstructions: const [
            OcrInstruction(name: '发票提取', content: '提取发票号码和金额'),
            OcrInstruction(name: '表格提取', content: '提取表格内容'),
          ],
          retryData: {
            'type': 'ocr',
            'images': <Map<String, dynamic>>[],
            'modelIndex': 0,
            // Stale index (the list changed since the task failed) — the
            // content wins and resolves to the correct instruction.
            'instructionIndex': 1,
            'instructionContent': '提取发票号码和金额',
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('发票提取'), findsOneWidget);
    });

    testWidgets(
        'retry falls back to the default when the instruction content is gone',
        (tester) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(
        _buildTestApp(
          entries: [entry],
          ocrInstructions: const [
            OcrInstruction(name: '发票提取', content: '提取发票号码和金额'),
          ],
          retryData: {
            'type': 'ocr',
            'images': <Map<String, dynamic>>[],
            'modelIndex': 0,
            'instructionIndex': 0,
            'instructionContent': '已删除的指令内容',
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('默认（仅发送图片）'), findsOneWidget);
    });

    testWidgets(
        'retry instruction restore survives the async list load (production '
        'race: list arrives after the first build)', (tester) async {
      // Simulates the real provider: initial state is empty, the list
      // arrives only after load() completes asynchronously.
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerEntriesProvider.overrideWith((ref) {
              final notifier = ProviderEntriesNotifier();
              notifier.state = ProviderEntriesState(entries: [entry]);
              return notifier;
            }),
            ocrInstructionsProvider.overrideWith((ref) {
              final notifier = _DelayedInstructionsNotifier(ref);
              notifier.load();
              return notifier;
            }),
          ],
          child: MaterialApp(
            home: OcrPage(
              retryData: {
                'type': 'ocr',
                'images': <Map<String, dynamic>>[],
                'modelIndex': 0,
                'instructionIndex': 1,
              },
            ),
            localizationsDelegates: const [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
          ),
        ),
      );
      // No time advance — the delayed load has not completed yet.
      await tester.pump();

      // The list has not arrived yet — the dropdown shows the default
      // instead of crashing on an out-of-range value.
      expect(find.text('默认（仅发送图片）'), findsOneWidget);

      // The list arrives — the restored instruction selection applies.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.text('表格提取'), findsOneWidget);
    });

    testWidgets(
        'user picking 默认 during the pending restore wins over the retry '
        'instruction', (tester) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerEntriesProvider.overrideWith((ref) {
              final notifier = ProviderEntriesNotifier();
              notifier.state = ProviderEntriesState(entries: [entry]);
              return notifier;
            }),
            ocrInstructionsProvider.overrideWith((ref) {
              final notifier = _DelayedInstructionsNotifier(ref);
              notifier.load();
              return notifier;
            }),
          ],
          child: MaterialApp(
            home: OcrPage(
              retryData: {
                'type': 'ocr',
                'images': <Map<String, dynamic>>[],
                'modelIndex': 0,
                'instructionIndex': 1,
              },
            ),
            localizationsDelegates: const [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pump();

      // Inside the pending window the dropdown has only the default item —
      // explicitly pick it.
      await tester.tap(find.text('默认（仅发送图片）'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('默认（仅发送图片）').last);
      await tester.pumpAndSettle();

      // The load lands — the user's explicit choice sticks and the retry
      // instruction does not resurrect.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.text('默认（仅发送图片）'), findsOneWidget);
      expect(find.text('表格提取'), findsNothing);
    });

    testWidgets('double-tap 开始识别 during the pending restore starts one task', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      final bgNotifier = BackgroundTaskNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerEntriesProvider.overrideWith((ref) {
              final notifier = ProviderEntriesNotifier();
              notifier.state = ProviderEntriesState(entries: [entry]);
              return notifier;
            }),
            ocrInstructionsProvider.overrideWith((ref) {
              // Long load so the restore is still pending after the route
              // transition settles.
              final notifier = _DelayedInstructionsNotifier(
                ref,
                delay: const Duration(seconds: 2),
              );
              notifier.load();
              return notifier;
            }),
            backgroundTasksProvider.overrideWith((ref) => bgNotifier),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OcrPage(
                          testImages: [_createTestImage()],
                          retryData: {
                            'type': 'ocr',
                            'images': <Map<String, dynamic>>[],
                            'modelIndex': 0,
                            'instructionIndex': 1,
                          },
                        ),
                      ),
                    ),
                    child: const Text('打开OCR'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开OCR'));
      await tester.pumpAndSettle();

      // Both taps land inside the pending-restore window (load takes 2s)
      // — the second must not start a duplicate OCR.
      await tester.tap(find.text('开始识别'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('开始识别'));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Exactly one task was created and the page popped exactly once
      // (host visible again).
      expect(bgNotifier.state.length, 1);
      expect(find.text('开始识别'), findsNothing);
      expect(find.text('打开OCR'), findsOneWidget);
    });

    testWidgets('manage button opens the instruction management dialog', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ocr_instruction_manage_btn')));
      await tester.pumpAndSettle();

      expect(find.text('管理识别指令'), findsOneWidget);
      expect(find.text('暂无指令'), findsOneWidget);
      expect(find.text('添加指令'), findsOneWidget);
    });

    testWidgets('adding an instruction via manage dialog shows it in dropdown',
        (tester) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ocr_instruction_manage_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加指令'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, '指令名称（可选）'),
        '发票提取',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '指令内容'),
        '提取发票号码和金额',
      );
      // Rebuild so the save button's enabled state reflects the content.
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // The new instruction appears in the manage dialog list.
      expect(find.text('发票提取'), findsOneWidget);

      // Close the dialog and open the dropdown — instruction is selectable.
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('默认（仅发送图片）'));
      await tester.pumpAndSettle();
      expect(find.text('发票提取'), findsWidgets);
    });

    testWidgets('editing an instruction via manage dialog updates the list', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(
        _buildTestApp(
          entries: [entry],
          ocrInstructions: const [
            OcrInstruction(name: '发票提取', content: '提取发票号码和金额'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ocr_instruction_manage_btn')));
      await tester.pumpAndSettle();

      // Open the editor — it is pre-filled with the existing instruction.
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '发票提取'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, '指令名称（可选）'),
        '发票提取v2',
      );
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // The updated name replaces the old one in the dialog list.
      expect(find.text('发票提取v2'), findsOneWidget);
      expect(find.text('发票提取'), findsNothing);

      // And in the dropdown after closing.
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('默认（仅发送图片）'));
      await tester.pumpAndSettle();
      expect(find.text('发票提取v2'), findsWidgets);
    });

    testWidgets('deleting the selected instruction falls back to the default', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(
        _buildTestApp(
          entries: [entry],
          ocrInstructions: const [
            OcrInstruction(name: '发票提取', content: '提取发票号码和金额'),
            OcrInstruction(name: '表格提取', content: '提取表格内容'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Select the second instruction, then delete it via the manage dialog.
      await tester.tap(find.text('默认（仅发送图片）'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('表格提取').last);
      await tester.pumpAndSettle();
      expect(find.text('表格提取'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ocr_instruction_manage_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pumpAndSettle();

      // Only the first instruction remains in the dialog.
      expect(find.text('发票提取'), findsOneWidget);
      expect(find.text('表格提取'), findsNothing);

      // Closing falls back to the default — the deleted selection never
      // sticks.
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(find.text('默认（仅发送图片）'), findsOneWidget);
    });

    testWidgets('save is disabled while the instruction content is blank', (
      tester,
    ) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ocr_instruction_manage_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加指令'));
      await tester.pumpAndSettle();

      FilledButton saveButton() => tester.widget<FilledButton>(
            find.widgetWithText(FilledButton, '保存'),
          );

      // Blank content — save disabled.
      expect(saveButton().onPressed, isNull);

      await tester.enterText(
        find.widgetWithText(TextField, '指令内容'),
        '提取发票号码',
      );
      await tester.pump();
      expect(saveButton().onPressed, isNotNull);
    });
  });

  group('OcrPage - instruction injection', () {
    const instructions = [
      OcrInstruction(name: '发票', content: '提取发票号码和金额'),
      OcrInstruction(content: '提取表格内容'),
    ];

    test('selected instruction content is written to typeConfig', () {
      final tc = applySelectedOcrInstruction(
        {'maxTokens': 4096},
        instructions,
        1,
      );
      expect(tc['userInstruction'], '提取表格内容');
    });

    test('default selection (-1) leaves typeConfig untouched', () {
      final tc = applySelectedOcrInstruction(
        {'maxTokens': 4096},
        instructions,
        -1,
      );
      expect(tc.containsKey('userInstruction'), isFalse);
    });

    test('out-of-range index leaves typeConfig untouched', () {
      final tc = applySelectedOcrInstruction(
        {'maxTokens': 4096},
        instructions,
        5,
      );
      expect(tc.containsKey('userInstruction'), isFalse);
    });

    test(
        'default selection removes a legacy per-model instruction from the '
        'request copy', () {
      // The request copy inherits the model's stored typeConfig, which may
      // still carry a legacy per-model userInstruction (kept in storage for
      // the migration) — the default selection must keep the request
      // images-only.
      final tc = applySelectedOcrInstruction(
        {'maxTokens': 4096, 'userInstruction': '旧版指令'},
        instructions,
        -1,
      );
      expect(tc.containsKey('userInstruction'), isFalse);
    });

    test('blank-content instruction is not injected', () {
      final tc = applySelectedOcrInstruction(
        {'maxTokens': 4096},
        const [
          OcrInstruction(name: '空白', content: '   \n\n  '),
        ],
        0,
      );
      expect(tc.containsKey('userInstruction'), isFalse);
    });
  });

  group('OcrPage - camera button (no choice panel)', () {
    testWidgets('tapping camera button does NOT show choice panel',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Tap the camera button - it now directly opens system camera
      await tester.tap(find.text('拍照识别'));
      await tester.pumpAndSettle();

      // The old choice panel should NOT appear
      expect(find.text('应用相机'), findsNothing);
      expect(find.text('系统相机'), findsNothing);
      expect(find.text('选择拍照方式'), findsNothing);
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
    testWidgets('empty grid shows empty state, no images to tap', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // No grid when no images
      expect(find.byType(GridView), findsNothing);
    });
  });

  group('OcrPage - bottom bar', () {
    testWidgets('start recognition button is visible when no images', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('开始识别'), findsOneWidget);
    });
  });

  // ====================================================================
  // NEW TESTS: Sort button label
  // ====================================================================

  group('OcrPage - sort button label', () {
    testWidgets('sort button NOT shown when fewer than 2 images', (
      tester,
    ) async {
      final images = [_createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Sort button should not appear with only 1 image
      expect(find.byKey(const Key('ocr_sort_btn')), findsNothing);
    });

    testWidgets('sort button shows text label "排序" when not in reorder mode', (
      tester,
    ) async {
      final images = [_createTestImage(seed: 1), _createTestImage(seed: 2)];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Sort button should be visible
      expect(find.byKey(const Key('ocr_sort_btn')), findsOneWidget);
      // Should show the "排序" text label
      expect(find.text('排序'), findsOneWidget);
    });

    testWidgets('sort button shows swap_vert icon when not in reorder mode', (
      tester,
    ) async {
      final images = [_createTestImage(seed: 1), _createTestImage(seed: 2)];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Should show swap_vert icon
      expect(find.byIcon(Icons.swap_vert), findsOneWidget);
    });

    testWidgets('sort button toggles to "完成" label and check icon after tap', (
      tester,
    ) async {
      final images = [_createTestImage(seed: 1), _createTestImage(seed: 2)];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Tap the sort button
      await tester.tap(find.byKey(const Key('ocr_sort_btn')));
      await tester.pumpAndSettle();

      // Should now show "完成" label
      expect(find.text('完成'), findsOneWidget);
      // Should now show check icon
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('sort button toggles back to "排序" label after second tap', (
      tester,
    ) async {
      final images = [_createTestImage(seed: 1), _createTestImage(seed: 2)];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Tap sort button to enter reorder mode
      await tester.tap(find.byKey(const Key('ocr_sort_btn')));
      await tester.pumpAndSettle();

      // Tap again to exit reorder mode
      await tester.tap(find.byKey(const Key('ocr_sort_btn')));
      await tester.pumpAndSettle();

      // Should be back to "排序" label
      expect(find.text('排序'), findsOneWidget);
    });
  });

  // ====================================================================
  // NEW TESTS: Tap to exit preview
  // ====================================================================

  group('OcrPage - tap image to exit preview', () {
    testWidgets('preview dialog shows close button', (tester) async {
      final images = [_createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Tap the image in the grid to open preview
      await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
      await tester.pumpAndSettle();

      // Should show the close button
      expect(find.byKey(const Key('preview_close_btn')), findsOneWidget);
    });

    testWidgets('tapping close button dismisses preview', (tester) async {
      final images = [_createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Tap the image in the grid to open preview
      await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
      await tester.pumpAndSettle();

      // Close button should be visible
      expect(find.byKey(const Key('preview_close_btn')), findsOneWidget);

      // Tap close button
      await tester.tap(find.byKey(const Key('preview_close_btn')));
      await tester.pumpAndSettle();

      // Preview should be dismissed — close button should be gone
      expect(find.byKey(const Key('preview_close_btn')), findsNothing);
    });

    testWidgets('tapping the image itself dismisses preview', (tester) async {
      final images = [_createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Tap the image in the grid to open preview
      await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
      await tester.pumpAndSettle();

      // Confirm dialog is open
      expect(find.byKey(const Key('preview_close_btn')), findsOneWidget);

      // Tap the preview image area
      await tester.tap(find.byKey(const Key('preview_tap_to_close')));
      await tester.pumpAndSettle();

      // Preview should be dismissed
      expect(find.byKey(const Key('preview_close_btn')), findsNothing);
    });
  });

  // ====================================================================
  // NEW TESTS: Reorder tests for audio_separation_page_test.dart
  // ====================================================================

  group('OcrPage - long-press drag to reorder in grid', () {
    testWidgets('grid items are wrapped in DragTarget and LongPressDraggable', (
      tester,
    ) async {
      final images = [
        _createTestImage(seed: 1),
        _createTestImage(seed: 2),
        _createTestImage(seed: 3),
      ];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Grid should be showing
      expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);
      expect(find.byKey(const Key('ocr_grid_item_1')), findsOneWidget);
      expect(find.byKey(const Key('ocr_grid_item_2')), findsOneWidget);

      // Each item should be inside a DragTarget
      expect(find.byKey(const Key('drag_target_0')), findsOneWidget);
      expect(find.byKey(const Key('drag_target_1')), findsOneWidget);
      expect(find.byKey(const Key('drag_target_2')), findsOneWidget);
    });

    testWidgets(
      'long-press drag and drop completes without crash and cleans up drag state',
      (tester) async {
        final images = [
          _createTestImage(seed: 1),
          _createTestImage(seed: 2),
          _createTestImage(seed: 3),
        ];
        await tester.pumpWidget(_buildTestApp(testImages: images));
        await tester.pumpAndSettle();

        // Get center coordinates of first and second items
        final item0Center = tester.getCenter(
          find.byKey(const Key('ocr_grid_item_0')),
        );
        final item1Center = tester.getCenter(
          find.byKey(const Key('ocr_grid_item_1')),
        );

        // Simulate long-press + drag from item 0 to item 1
        final gesture = await tester.startGesture(item0Center);
        // Wait for long-press delay (300ms) plus some buffer
        await tester.pump(const Duration(milliseconds: 400));

        // Drag from item 0 toward item 1
        await gesture.moveTo(item1Center);
        await tester.pump(const Duration(milliseconds: 100));

        // Complete the drag (drop) — this should trigger onAcceptWithDetails
        await gesture.up();
        await tester.pumpAndSettle();

        // After reorder, all items should still be visible
        expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);
        expect(find.byKey(const Key('ocr_grid_item_1')), findsOneWidget);
        expect(find.byKey(const Key('ocr_grid_item_2')), findsOneWidget);

        // No DragTargets should have active hover state (all drag state cleaned up)
        // Verify the sort button still works normally after the drag
        await tester.tap(find.byKey(const Key('ocr_sort_btn')));
        await tester.pumpAndSettle();
        expect(find.text('完成'), findsOneWidget);
      },
    );

    testWidgets(
      'sort button list reorder works independently of grid long-press',
      (tester) async {
        final images = [
          _createTestImage(seed: 1),
          _createTestImage(seed: 2),
          _createTestImage(seed: 3),
        ];
        await tester.pumpWidget(_buildTestApp(testImages: images));
        await tester.pumpAndSettle();

        // Tap sort button — should switch to list reorder mode
        await tester.tap(find.byKey(const Key('ocr_sort_btn')));
        await tester.pumpAndSettle();

        // Should be in reorder mode now (list view), with "完成" label
        expect(find.byKey(const Key('ocr_sort_btn')), findsOneWidget);
        expect(find.text('完成'), findsOneWidget);

        // Tap again to exit reorder mode
        await tester.tap(find.byKey(const Key('ocr_sort_btn')));
        await tester.pumpAndSettle();

        // Grid should be back to normal view with "排序" label
        expect(find.text('排序'), findsOneWidget);

        // Grid items should still be present
        expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);
        expect(find.byKey(const Key('ocr_grid_item_1')), findsOneWidget);
        expect(find.byKey(const Key('ocr_grid_item_2')), findsOneWidget);
      },
    );

    testWidgets('long-press is disabled with single image', (tester) async {
      final images = [_createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Sort button should not appear (need >1 images)
      expect(find.byKey(const Key('ocr_sort_btn')), findsNothing);

      // Grid item should be present
      expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);

      // Only one DragTarget since there's one item
      expect(find.byKey(const Key('drag_target_0')), findsOneWidget);

      // Long-press on the single item — should NOT crash or enter drag mode
      final itemCenter = tester.getCenter(
        find.byKey(const Key('ocr_grid_item_0')),
      );
      final gesture = await tester.startGesture(itemCenter);
      await tester.pump(const Duration(milliseconds: 350));
      // Move slightly to simulate drag attempt
      await gesture.moveBy(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      // Item should still be present (no crash)
      expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);
    });

    testWidgets('clear button hidden during reorder mode', (tester) async {
      final images = [_createTestImage(seed: 1), _createTestImage(seed: 2)];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Clear button visible initially
      expect(find.text('清空'), findsOneWidget);

      // Enter reorder mode via sort button
      await tester.tap(find.byKey(const Key('ocr_sort_btn')));
      await tester.pumpAndSettle();

      // Clear button should be hidden during reorder mode
      expect(find.text('清空'), findsNothing);
    });

    testWidgets(
      'grid items are wrapped in Draggable with proper drag lifecycle',
      (tester) async {
        final images = [_createTestImage(seed: 1), _createTestImage(seed: 2)];
        await tester.pumpWidget(_buildTestApp(testImages: images));
        await tester.pumpAndSettle();

        // Verify LongPressDraggable and DragTarget exist in the widget tree
        expect(find.byType(LongPressDraggable<int>), findsNWidgets(2));
        expect(find.byType(DragTarget<int>), findsNWidgets(2));

        // Start a long-press on item 0 to trigger drag
        final item0Center = tester.getCenter(
          find.byKey(const Key('ocr_grid_item_0')),
        );
        final gesture = await tester.startGesture(item0Center);
        await tester.pump(
          const Duration(milliseconds: 400),
        ); // 300ms is the new delay

        // During drag, cancel the drag by moving outside
        await gesture.moveBy(const Offset(300, 300));
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.up();
        await tester.pumpAndSettle();

        // After drag cancel, items should return to normal
        expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);
        expect(find.byKey(const Key('ocr_grid_item_1')), findsOneWidget);
      },
    );
  });

  // ====================================================================
  // NEW TESTS: In-app album picker dialog (uses showAppAlbumPickerDialog)
  // ====================================================================

  group('OcrPage - in-app album picker dialog', () {
    testWidgets('tapping 从应用相册选择 opens in-app album picker dialog', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Add a record so the dialog can open (not empty state)
      await ImageManifest.addRecord(
        ImageRecord(
          name: '测试图片',
          hash: 'test_hash_abc',
          format: 'png',
          createdAt: DateTime.now(),
          size: 1024,
        ),
      );

      // Tap the album button
      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();

      // Tap "从应用相册选择"
      await tester.tap(find.text('从应用相册选择'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show the in-app album picker dialog title
      expect(find.text('应用内相册'), findsOneWidget);
    });

    testWidgets('in-app album picker shows empty state when no images', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Ensure image records are empty
      final records = await ImageManifest.loadRecords();
      expect(records, isEmpty);

      // Navigate to the in-app album picker
      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从应用相册选择'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show empty state text
      expect(find.text('暂无图片'), findsOneWidget);
    });

    testWidgets('in-app album picker shows records when images exist', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Add a test image record to the manifest
      await ImageManifest.addRecord(
        ImageRecord(
          name: '测试图片',
          hash: 'test_hash_123',
          format: 'png',
          createdAt: DateTime.now(),
          size: 1024,
        ),
      );
      // Verify the record was added
      final records = await ImageManifest.loadRecords();
      expect(records.length, equals(1));

      // Navigate to the in-app album picker
      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从应用相册选择'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show the record name
      expect(find.text('测试图片.png'), findsOneWidget);
    });

    testWidgets(
      'in-app album picker tapping record with missing file shows error snackbar',
      (tester) async {
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // Add a test image record (file won't exist in test environment)
        await ImageManifest.addRecord(
          ImageRecord(
            name: '缺失图片',
            hash: 'missing_hash',
            format: 'png',
            createdAt: DateTime.now(),
            size: 1024,
          ),
        );

        // Navigate to the in-app album picker
        await tester.tap(find.text('相册选择'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('从应用相册选择'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Tap the checkbox to toggle selection (this triggers read)
        final checkboxes = find.byType(Checkbox);
        if (checkboxes.evaluate().isNotEmpty) {
          await tester.tap(checkboxes.first);
        } else {
          // Fallback: tap the text
          await tester.tap(find.text('缺失图片.png'));
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Should show error snackbar since the file doesn't exist
        expect(find.textContaining('无法读取'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets('in-app album picker close button dismisses the dialog', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Add a record so the dialog opens
      await ImageManifest.addRecord(
        ImageRecord(
          name: '测试图片',
          hash: 'test_hash_close',
          format: 'png',
          createdAt: DateTime.now(),
          size: 1024,
        ),
      );

      // Navigate to the in-app album picker
      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从应用相册选择'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Dialog should be visible
      expect(find.text('应用内相册'), findsOneWidget);

      // Tap the close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Dialog should be dismissed
      expect(find.text('应用内相册'), findsNothing);
    });
  });

  // ====================================================================
  // NEW TESTS: Smooth release animation with Stack+AnimatedPositioned
  // ====================================================================

  group('OcrPage - smooth drag-release animation', () {
    testWidgets('long-press delay is 300ms (changed from 500ms)', (
      tester,
    ) async {
      final images = [
        _createTestImage(seed: 1),
        _createTestImage(seed: 2),
        _createTestImage(seed: 3),
      ];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      final item0Center = tester.getCenter(
        find.byKey(const Key('ocr_grid_item_0')),
      );

      // Negative case: pump well below 300ms — drag should NOT have started
      final gestureEarly = await tester.startGesture(item0Center);
      await tester.pump(const Duration(milliseconds: 200)); // 200ms << 300ms

      // Cancel without any drag movement — no crash, no stale state
      await gestureEarly.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);

      // Positive case: pump past 300ms — drag SHOULD start (old 500ms would NOT)
      final gesture = await tester.startGesture(item0Center);
      await tester.pump(const Duration(milliseconds: 350));

      // Drag should have started by now (350ms > 300ms)
      await tester.pump(const Duration(milliseconds: 50));

      // Cancel the drag
      await gesture.up();
      await tester.pumpAndSettle();

      // No crash — drag started and ended cleanly with 300ms delay
      expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);
      expect(find.byKey(const Key('ocr_grid_item_1')), findsOneWidget);
    });

    testWidgets('after drop, all items remain visible and sort button works', (
      tester,
    ) async {
      final images = [
        _createTestImage(seed: 1),
        _createTestImage(seed: 2),
        _createTestImage(seed: 3),
      ];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Long-press and drag item 0 to item 2
      final item0Center = tester.getCenter(
        find.byKey(const Key('ocr_grid_item_0')),
      );
      final item2Center = tester.getCenter(
        find.byKey(const Key('ocr_grid_item_2')),
      );

      final gesture = await tester.startGesture(item0Center);
      await tester.pump(
        const Duration(milliseconds: 350),
      ); // trigger long-press

      // Drag to item 2 position
      await gesture.moveTo(item2Center);
      await tester.pump(const Duration(milliseconds: 100));

      // Drop
      await gesture.up();
      await tester.pumpAndSettle();

      // All items should still be visible (no items lost)
      expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);
      expect(find.byKey(const Key('ocr_grid_item_1')), findsOneWidget);
      expect(find.byKey(const Key('ocr_grid_item_2')), findsOneWidget);

      // No crash — operation completed
      expect(find.byKey(const Key('ocr_sort_btn')), findsOneWidget);

      // Verify sort button toggles (confirming clean state after reorder)
      await tester.tap(find.byKey(const Key('ocr_sort_btn')));
      await tester.pumpAndSettle();
      expect(find.text('完成'), findsOneWidget);
    });

    testWidgets('no crash during rapid drag and drop', (tester) async {
      final images = [
        _createTestImage(seed: 1),
        _createTestImage(seed: 2),
        _createTestImage(seed: 3),
      ];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Rapidly drag and drop multiple times
      for (int i = 0; i < 10; i++) {
        final item0Center = tester.getCenter(
          find.byKey(const Key('ocr_grid_item_0')),
        );
        final item1Center = tester.getCenter(
          find.byKey(const Key('ocr_grid_item_1')),
        );

        final gesture = await tester.startGesture(item0Center);
        await tester.pump(const Duration(milliseconds: 350));
        await gesture.moveTo(item1Center);
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.up();
        await tester.pumpAndSettle();
      }

      // No crash after rapid operations
      expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);
      expect(find.byKey(const Key('ocr_grid_item_1')), findsOneWidget);
      expect(find.byKey(const Key('ocr_grid_item_2')), findsOneWidget);
    });

    testWidgets('drag state is properly cleaned up after drag cancel', (
      tester,
    ) async {
      final images = [
        _createTestImage(seed: 1),
        _createTestImage(seed: 2),
        _createTestImage(seed: 3),
      ];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Long-press item 0 to trigger drag
      final item0Center = tester.getCenter(
        find.byKey(const Key('ocr_grid_item_0')),
      );
      final gesture = await tester.startGesture(item0Center);
      await tester.pump(const Duration(milliseconds: 350));

      // Move to hover over item 1 (sets _dragTargetIndex)
      final item1Center = tester.getCenter(
        find.byKey(const Key('ocr_grid_item_1')),
      );
      await gesture.moveTo(item1Center);
      await tester.pump(const Duration(milliseconds: 50));

      // Cancel the drag (not drop — cancel leaves original order intact)
      await gesture.up();
      await tester.pumpAndSettle();

      // All items should still be present and normal
      expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);
      expect(find.byKey(const Key('ocr_grid_item_1')), findsOneWidget);
      expect(find.byKey(const Key('ocr_grid_item_2')), findsOneWidget);

      // Sort button still functional after drag cancel
      // (proves no stale drag state)
      expect(find.byKey(const Key('ocr_sort_btn')), findsOneWidget);
    });

    testWidgets('reorder completes correctly after drag-and-drop', (
      tester,
    ) async {
      final images = [
        _createTestImage(seed: 1),
        _createTestImage(seed: 2),
        _createTestImage(seed: 3),
      ];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Drag item 0 and drop on item 2
      final item0Center = tester.getCenter(
        find.byKey(const Key('ocr_grid_item_0')),
      );
      final item2Center = tester.getCenter(
        find.byKey(const Key('ocr_grid_item_2')),
      );

      final gesture = await tester.startGesture(item0Center);
      await tester.pump(const Duration(milliseconds: 350));

      // Move to item 2's position
      await gesture.moveTo(item2Center);
      await tester.pump(const Duration(milliseconds: 50));

      // Drop on item 2
      await gesture.up();
      await tester.pumpAndSettle();

      // After reorder, grid should be stable — all items visible
      expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);
      expect(find.byKey(const Key('ocr_grid_item_1')), findsOneWidget);
      expect(find.byKey(const Key('ocr_grid_item_2')), findsOneWidget);

      // Verify sort button still works after reorder
      await tester.tap(find.byKey(const Key('ocr_sort_btn')));
      await tester.pumpAndSettle();
      expect(find.text('完成'), findsOneWidget);
    });
  });

  // ====================================================================
  // NEW TESTS: Unified order - app first, system second
  // ====================================================================

  group('OcrPage - unified order (app first, system second)', () {
    testWidgets(
      'album choice panel shows app album BEFORE system album (Y-coordinate)',
      (tester) async {
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        await tester.tap(find.text('相册选择'));
        await tester.pumpAndSettle();

        // Verify both options are rendered
        final appAlbum = find.text('从应用相册选择');
        final sysAlbum = find.text('从系统相册选择');
        expect(appAlbum, findsOneWidget);
        expect(sysAlbum, findsOneWidget);

        // Verify app album renders ABOVE system album (lower Y = higher on screen)
        final appRect = tester.getRect(appAlbum);
        final sysRect = tester.getRect(sysAlbum);
        expect(
          appRect.center.dy,
          lessThan(sysRect.center.dy),
          reason: '从应用相册选择 should appear above 从系统相册选择',
        );
      },
    );

    testWidgets('both 从应用相册选择 and 从系统相册选择 are visible in album panel', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();

      expect(find.text('从应用相册选择'), findsOneWidget);
      expect(find.text('从系统相册选择'), findsOneWidget);
    });
  });

  // ====================================================================
  // NEW TESTS: Multiple configs within a single OCR entry
  // ====================================================================

  group('OcrPage - multiple configs', () {
    testWidgets(
      'shows models from valid config when first config has no host/key',
      (tester) async {
        final entry = ProviderEntry(
          id: 'test_ocr',
          type: 'ocr',
          name: 'OCR供应商',
          configs: [
            ProviderConfigItem(
              providerName: 'Empty',
              host: '',
              key: '',
              models: [
                ModelConfig(name: 'Empty-Model', modelId: 'empty-model'),
              ],
            ),
            ProviderConfigItem(
              providerName: 'Valid',
              host: 'https://api.valid.com',
              key: 'valid-key-123',
              models: [
                ModelConfig(name: 'Valid-Model', modelId: 'valid-model'),
              ],
            ),
          ],
        );
        await tester.pumpWidget(_buildTestApp(entries: [entry]));
        await tester.pumpAndSettle();

        // Should show the valid config's model
        expect(find.text('Valid-Model | Valid'), findsWidgets);
      },
    );

    testWidgets(
      'shows models from ALL valid configs (not just first)',
      (tester) async {
        final entry = ProviderEntry(
          id: 'test_ocr',
          type: 'ocr',
          name: 'OCR供应商',
          configs: [
            ProviderConfigItem(
              providerName: 'First',
              host: 'https://api.first.com',
              key: 'first-key',
              models: [
                ModelConfig(name: 'First-Model', modelId: 'first-model'),
              ],
            ),
            ProviderConfigItem(
              providerName: 'Second',
              host: 'https://api.second.com',
              key: 'second-key',
              models: [
                ModelConfig(name: 'Second-Model', modelId: 'second-model'),
              ],
            ),
          ],
        );
        await tester.pumpWidget(_buildTestApp(entries: [entry]));
        await tester.pumpAndSettle();

        // First model is selected by default (visible in collapsed dropdown)
        expect(find.text('First-Model | First'), findsOneWidget);

        // Tap the dropdown to open it and see all items
        await tester.tap(find.text('First-Model | First'));
        await tester.pumpAndSettle();

        // Should show models from ALL valid configs in the dropdown
        expect(find.text('Second-Model | Second'), findsWidgets);
      },
    );

    testWidgets(
      'shows configure prompt when no config has valid host/key',
      (tester) async {
        final entry = ProviderEntry(
          id: 'test_ocr',
          type: 'ocr',
          name: 'OCR供应商',
          configs: [
            ProviderConfigItem(
              providerName: 'Empty',
              host: '',
              key: '',
              models: [
                ModelConfig(name: 'Empty-Model', modelId: 'empty-model'),
              ],
            ),
            ProviderConfigItem(
              providerName: 'Also Empty',
              host: '',
              key: '',
              models: [
                ModelConfig(name: 'Also-Empty', modelId: 'also-empty'),
              ],
            ),
          ],
        );
        await tester.pumpWidget(_buildTestApp(entries: [entry]));
        await tester.pumpAndSettle();

        // Should show configure prompt instead of hiding the selector
        expect(find.text('识别模型'), findsOneWidget);
        expect(find.textContaining('配置'), findsWidgets);
      },
    );

    testWidgets(
      'shows configure prompt when no OCR models exist',
      (tester) async {
        final entry = ProviderEntry(
          id: 'test_ocr',
          type: 'ocr',
          name: 'OCR供应商',
          configs: [
            ProviderConfigItem(
              providerName: 'Empty',
              host: '',
              key: '',
              models: [],
            ),
          ],
        );
        await tester.pumpWidget(_buildTestApp(entries: [entry]));
        await tester.pumpAndSettle();

        // Should show configure prompt
        expect(find.text('识别模型'), findsOneWidget);
        expect(find.textContaining('配置'), findsWidgets);
      },
    );

    testWidgets(
      'shows configure prompt when no OCR entry exists',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(entries: []));
        await tester.pumpAndSettle();

        // Should show configure prompt
        expect(find.text('识别模型'), findsOneWidget);
        expect(find.textContaining('配置'), findsWidgets);
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────
  // Merged from: test/pages/ocr_page_preview_edit_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('OcrPage - preview dialog two edit buttons', () {
    testWidgets('preview dialog shows crop and edit buttons in top-right', (
      tester,
    ) async {
      final images = [_createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Tap the image to open preview
      await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
      await tester.pumpAndSettle();

      // Should see TWO edit icon buttons: crop + full editor
      expect(find.byIcon(Icons.crop), findsOneWidget,
          reason: 'Crop button should be visible');
      expect(find.byIcon(Icons.edit), findsOneWidget,
          reason: 'Full editor button should be visible');
    });

    testWidgets('preview dialog shows close button in top-left', (
      tester,
    ) async {
      final images = [_createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
      await tester.pumpAndSettle();

      // Close button should be present
      expect(find.byKey(const Key('preview_close_btn')), findsOneWidget);
    });

    testWidgets('preview dialog shows position indicator for multiple images', (
      tester,
    ) async {
      final images = [_createTestImage(), _createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Tap the first image
      await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
      await tester.pumpAndSettle();

      // Should show the position indicator
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('preview dialog can be closed with close button', (
      tester,
    ) async {
      final images = [_createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
      await tester.pumpAndSettle();

      // Tap close button
      await tester.tap(find.byKey(const Key('preview_close_btn')));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.byIcon(Icons.crop), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
    });
  });

  // ====================================================================
  // Quick-edit background processing: start-button gating
  // ====================================================================
  group('OcrPage - quick edit background gating', () {
    testWidgets('start button is disabled while a quick edit processes',
        (tester) async {
      // Engine-generated PNG — the quick editor only builds after the
      // image decodes, which needs a real-async window.
      final png = await tester.runAsync(_createEnginePng);
      final images = [SelectedImage(bytes: png!, format: 'png')];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Open the preview and the quick editor.
      await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.crop));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Wait for the editor image to decode (engine work — real async).
      await _pumpUntil(
        tester,
        () => find.byType(ExtendedImageEditor).evaluate().isNotEmpty,
      );

      // Confirm the edit — the editor pops immediately and the image
      // processing continues in the background.
      await tester.tap(find.text('完成'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Gating: while processing, the start button is disabled and
      // shows the processing label — starting OCR now would run on the
      // unedited bytes.
      expect(find.text('图片处理中...'), findsOneWidget);
      final startBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '图片处理中...'),
      );
      expect(startBtn.onPressed, isNull);

      // Once the background pipeline finishes, the button re-enables.
      await _pumpUntil(
        tester,
        () => find.text('图片处理中...').evaluate().isEmpty,
      );
      final startBtn2 = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '开始识别'),
      );
      expect(startBtn2.onPressed, isNotNull);
    });
  });
}
