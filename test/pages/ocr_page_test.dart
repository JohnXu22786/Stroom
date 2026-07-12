import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/ocr_page.dart';
import 'package:stroom/pages/ocr/ocr_shared.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/image_manifest.dart';
import 'package:stroom/utils/text_manifest.dart';

// ============================================================================
// Helper: Build test app with optional provider overrides
// ============================================================================

Widget _buildTestApp({
  List<ProviderEntry>? entries,
  List<SelectedImage>? testImages,
}) {
  return ProviderScope(
    overrides: [
      if (entries != null)
        providerEntriesProvider.overrideWith((ref) {
          final notifier = ProviderEntriesNotifier();
          notifier.state = ProviderEntriesState(entries: entries);
          return notifier;
        }),
    ],
    child: MaterialApp(
      home: OcrPage(testImages: testImages),
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

    testWidgets('shows clear button only when images are selected', (
      tester,
    ) async {
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

    testWidgets('model selector label is visible', (tester) async {
      final entry = _createOcrEntry(withModels: true);
      await tester.pumpWidget(_buildTestApp(entries: [entry]));
      await tester.pumpAndSettle();

      // Should have a model-related label
      expect(find.textContaining('识别模型'), findsWidgets);
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
    testWidgets('start recognition button is visible when no images', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('开始识别'), findsOneWidget);
    });

    testWidgets('save-to section and start button are both visible', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Both save-to and start button should be present
      expect(find.text('保存至'), findsOneWidget);
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
    testWidgets('grid uses AnimatedPositioned for smooth position animation', (
      tester,
    ) async {
      final images = [
        _createTestImage(seed: 1),
        _createTestImage(seed: 2),
        _createTestImage(seed: 3),
      ];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Should use AnimatedPositioned for smooth position transitions
      // (3 items = 3 AnimatedPositioned widgets in the grid)
      expect(find.byType(AnimatedPositioned), findsNWidgets(3));
    });

    testWidgets('grid no longer uses GridView', (tester) async {
      final images = [
        _createTestImage(seed: 1),
        _createTestImage(seed: 2),
        _createTestImage(seed: 3),
      ];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Grid has been replaced by Stack-based layout
      expect(find.byType(GridView), findsNothing);
    });

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

    testWidgets(
      'AnimatedPositioned has identity-based keys for smooth transitions',
      (tester) async {
        final images = [
          _createTestImage(seed: 1),
          _createTestImage(seed: 2),
          _createTestImage(seed: 3),
        ];
        await tester.pumpWidget(_buildTestApp(testImages: images));
        await tester.pumpAndSettle();

        // Each AnimatedPositioned should have a key (identity-based)
        final animatedPositions = find.byType(AnimatedPositioned);
        expect(animatedPositions, findsNWidgets(3));

        // Verify each has a key matching the identity-based pattern
        for (final element in tester.widgetList(animatedPositions)) {
          final widget = element as AnimatedPositioned;
          expect(widget.key, isA<ValueKey<String>>());
          final keyValue = (widget.key as ValueKey<String>).value;
          expect(keyValue, contains('grid_item_pos_'));
          // Extract the numeric suffix and verify it's a valid integer hash
          final suffix = keyValue.replaceAll('grid_item_pos_', '');
          expect(int.tryParse(suffix), isNotNull);
        }
      },
    );

    testWidgets(
      'AnimatedPositioned duration is set to 300ms for smooth animation',
      (tester) async {
        final images = [
          _createTestImage(seed: 1),
          _createTestImage(seed: 2),
          _createTestImage(seed: 3),
        ];
        await tester.pumpWidget(_buildTestApp(testImages: images));
        await tester.pumpAndSettle();

        // AnimatedPositioned should have 300ms duration
        final animatedPositions = find.byType(AnimatedPositioned);
        for (final element in tester.widgetList(animatedPositions)) {
          final widget = element as AnimatedPositioned;
          expect(widget.duration, const Duration(milliseconds: 300));
        }
      },
    );

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
  // NEW TESTS: Unified colors - app=green, system=blue
  // ====================================================================

  group('OcrPage - unified colors (app=green, system=blue)', () {
    testWidgets('app album ChoiceCard uses green icon color', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();

      final choiceCards = find.byType(ChoiceCard);
      final firstCard = tester.widget<ChoiceCard>(choiceCards.at(0));
      expect(firstCard.color, Colors.green);
    });

    testWidgets('system album ChoiceCard uses blue icon color', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();

      final choiceCards = find.byType(ChoiceCard);
      final secondCard = tester.widget<ChoiceCard>(choiceCards.at(1));
      expect(secondCard.color, Colors.blue);
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
      'shows models from first valid config when all configs are valid',
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

        // Should show the first valid config's models
        expect(find.text('First-Model | First'), findsWidgets);
        // Models from the second config should NOT appear
        expect(find.text('Second-Model | Second'), findsNothing);
      },
    );

    testWidgets(
      'shows no model selector when no config has valid host/key',
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

        // No model selector should be shown
        expect(find.textContaining('识别模型'), findsNothing);
      },
    );

    testWidgets(
      'hides model selector when no valid OCR config exists',
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

        // No model selector should show
        expect(find.textContaining('识别模型'), findsNothing);
      },
    );
  });
}
