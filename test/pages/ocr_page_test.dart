import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/ocr_page.dart';
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
                ModelConfig(
                    name: 'GPT-4 Vision', modelId: 'gpt-4-vision-preview'),
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
    provider: MemoryImage(_createTestPngBytes()),
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
    testWidgets('start recognition button is visible when no images',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('开始识别'), findsOneWidget);
    });

    testWidgets('save-to section and start button are both visible', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Both save-to and start button should be present
      expect(find.text('保存至'), findsOneWidget);
      expect(find.text('开始识别'), findsOneWidget);
    });
  });

  // ====================================================================
  // NEW TESTS: Sort button label (Requirement 1)
  // ====================================================================

  group('OcrPage - sort button label', () {
    testWidgets('sort button NOT shown when fewer than 2 images',
        (tester) async {
      final images = [_createTestImage()];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Sort button should not appear with only 1 image
      expect(find.byKey(const Key('ocr_sort_btn')), findsNothing);
    });

    testWidgets('sort button shows text label "排序" when not in reorder mode',
        (tester) async {
      final images = [_createTestImage(seed: 1), _createTestImage(seed: 2)];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Sort button should be visible
      expect(find.byKey(const Key('ocr_sort_btn')), findsOneWidget);
      // Should show the "排序" text label
      expect(find.text('排序'), findsOneWidget);
    });

    testWidgets(
        'sort button shows swap_vert icon when not in reorder mode',
        (tester) async {
      final images = [_createTestImage(seed: 1), _createTestImage(seed: 2)];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Should show swap_vert icon
      expect(find.byIcon(Icons.swap_vert), findsOneWidget);
    });

    testWidgets(
        'sort button toggles to "完成" label and check icon after tap',
        (tester) async {
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

    testWidgets(
        'sort button toggles back to "排序" label after second tap',
        (tester) async {
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
  // NEW TESTS: Tap to exit preview (Requirement 2)
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
  // NEW TESTS: Long-press to drag-reorder in grid (Requirement 3)
  // ====================================================================

  group('OcrPage - long-press drag to reorder in grid', () {
    testWidgets('grid items are wrapped in DragTarget and LongPressDraggable',
        (tester) async {
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
          find.byKey(const Key('ocr_grid_item_0')));
      final item1Center = tester.getCenter(
          find.byKey(const Key('ocr_grid_item_1')));

      // Simulate long-press + drag from item 0 to item 1
      final gesture = await tester.startGesture(item0Center);
      // Wait for long-press delay (300ms) plus some buffer
      await tester.pump(const Duration(milliseconds: 600));

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
    });

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
    });

    testWidgets(
        'long-press is disabled with single image',
        (tester) async {
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
          find.byKey(const Key('ocr_grid_item_0')));
      final gesture = await tester.startGesture(itemCenter);
      await tester.pump(const Duration(milliseconds: 600));
      // Move slightly to simulate drag attempt
      await gesture.moveBy(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      // Item should still be present (no crash)
      expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);
    });

    testWidgets(
        'clear button hidden during reorder mode',
        (tester) async {
      final images = [
        _createTestImage(seed: 1),
        _createTestImage(seed: 2),
      ];
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
      final images = [
        _createTestImage(seed: 1),
        _createTestImage(seed: 2),
      ];
      await tester.pumpWidget(_buildTestApp(testImages: images));
      await tester.pumpAndSettle();

      // Verify LongPressDraggable and DragTarget exist in the widget tree
      expect(find.byType(LongPressDraggable<int>), findsNWidgets(2));
      expect(find.byType(DragTarget<int>), findsNWidgets(2));

      // Start a long-press on item 0 to trigger drag
      final item0Center = tester.getCenter(
          find.byKey(const Key('ocr_grid_item_0')));
      final gesture = await tester.startGesture(item0Center);
      await tester.pump(const Duration(milliseconds: 600));

      // During drag, cancel the drag by moving outside
      await gesture.moveBy(const Offset(300, 300));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      // After drag cancel, items should return to normal
      expect(find.byKey(const Key('ocr_grid_item_0')), findsOneWidget);
      expect(find.byKey(const Key('ocr_grid_item_1')), findsOneWidget);
    });
  });

  // ====================================================================
  // NEW TESTS: In-app album picker dialog
  // ====================================================================

  group('OcrPage - in-app album picker dialog', () {
    testWidgets('tapping 从应用相册选择 opens in-app album picker dialog',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Add a record so the dialog can open (not empty state)
      await ImageManifest.addRecord(ImageRecord(
        name: '测试图片',
        hash: 'test_hash_abc',
        format: 'png',
        createdAt: DateTime.now(),
        size: 1024,
      ));

      // Tap the album button
      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();

      // Tap "从应用相册选择"
      await tester.tap(find.text('从应用相册选择'));
      await tester.pumpAndSettle();

      // Should show the in-app album picker dialog title
      expect(find.text('选择应用内图片'), findsOneWidget);
    });

    testWidgets('in-app album picker shows empty state when no images',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Ensure image records are empty
      final records = await ImageManifest.loadRecords();
      expect(records, isEmpty);

      // Navigate to the in-app album picker
      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从应用相册选择'));
      await tester.pumpAndSettle();

      // Should show empty state text
      expect(find.text('暂无可用的应用内图片'), findsOneWidget);
    });

    testWidgets('in-app album picker shows records when images exist',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Add a test image record to the manifest
      await ImageManifest.addRecord(ImageRecord(
        name: '测试图片',
        hash: 'test_hash_123',
        format: 'png',
        createdAt: DateTime.now(),
        size: 1024,
      ));
      // Verify the record was added
      final records = await ImageManifest.loadRecords();
      expect(records.length, equals(1));

      // Navigate to the in-app album picker
      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从应用相册选择'));
      await tester.pumpAndSettle();

      // Should show the record name
      expect(find.text('测试图片'), findsOneWidget);
    });

    testWidgets(
        'in-app album picker tapping record with missing file shows error snackbar',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Add a test image record (file won't exist in test environment)
      await ImageManifest.addRecord(ImageRecord(
        name: '缺失图片',
        hash: 'missing_hash',
        format: 'png',
        createdAt: DateTime.now(),
        size: 1024,
      ));

      // Navigate to the in-app album picker
      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从应用相册选择'));
      await tester.pumpAndSettle();

      // Tap on the record
      await tester.tap(find.text('缺失图片'));
      await tester.pumpAndSettle();

      // Should show error snackbar since the file doesn't exist
      expect(find.textContaining('无法读取'), findsOneWidget);
    });

    testWidgets('in-app album picker close button dismisses the dialog',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Add a record so the dialog opens
      await ImageManifest.addRecord(ImageRecord(
        name: '测试图片',
        hash: 'test_hash_close',
        format: 'png',
        createdAt: DateTime.now(),
        size: 1024,
      ));

      // Navigate to the in-app album picker
      await tester.tap(find.text('相册选择'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从应用相册选择'));
      await tester.pumpAndSettle();

      // Dialog should be visible
      expect(find.text('选择应用内图片'), findsOneWidget);

      // Tap the close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('选择应用内图片'), findsNothing);
    });
  });
}
