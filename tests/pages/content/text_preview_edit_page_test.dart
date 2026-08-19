import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/text_preview_edit_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 构建测试应用，将 TextPreviewEditPage 放置在一个可以弹出返回的路径中
Widget _buildTestApp(TextRecord file, String content) {
  return ProviderScope(
    child: MaterialApp(
      initialRoute: '/',
      routes: {
        '/': (_) => const _PlaceholderPage(),
        '/edit': (_) =>
            TextPreviewEditPage(file: file, initialContent: content),
      },
    ),
  );
}

/// 占位页面，用于提供返回导航上下文
class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Placeholder')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/edit'),
          child: const Text('Open Editor'),
        ),
      ),
    );
  }
}

/// 查看模式下内容 Text 的样式（SelectionArea 内唯一的 Text）
TextStyle? _viewModeContentStyle(WidgetTester tester) {
  final text = tester.widget<Text>(
    find.descendant(
      of: find.byType(SelectionArea),
      matching: find.byType(Text),
    ),
  );
  return text.style;
}

/// 以指定平台运行 [body]，保证失败时也会复位平台覆盖 —— 测试绑定在
/// test body 结束时（早于 addTearDown）校验 foundation 调试变量已复位。
Future<void> _withPlatform(
  WidgetTester tester,
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  group('TextPreviewEditPage', () {
    late TextRecord testFile;
    const testContent = 'Hello, this is a test text content.\nSecond line.';

    setUp(() async {
      // Create a test text file in the manifest
      // Use utf8.encode instead of codeUnits to properly handle non-ASCII text
      final bytes = Uint8List.fromList(utf8.encode(testContent));
      final hash = computeTextHash(bytes);
      final storageFileName = '$hash.txt';
      await TextManifest.writeText(storageFileName, testContent);

      testFile = TextRecord(
        name: 'test_file',
        hash: hash,
        format: 'txt',
        createdAt: DateTime.now(),
        size: bytes.length,
        textLength: testContent.length,
      );
      // Insert the record into the manifest database so that save
      // operations can update it via updateRecord.
      await TextManifest.addRecord(testFile);
    });

    /// 导航到编辑页面
    Future<void> navigateToEditor(WidgetTester tester) async {
      await tester.tap(find.text('Open Editor'));
      await tester.pumpAndSettle();
    }

    /// 进入编辑模式（含初始化 widget）
    Future<void> enterEditMode(WidgetTester tester,
        {TextRecord? file, String? content}) async {
      await tester
          .pumpWidget(_buildTestApp(file ?? testFile, content ?? testContent));
      await navigateToEditor(tester);
      // Tap the edit icon button
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
    }

    // ==================== View Mode ====================

    testWidgets(
        'renders in view mode with read-only text and icon-only edit button',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(testFile, testContent));
      await navigateToEditor(tester);

      // Title shows filename.format
      expect(find.text('test_file.txt'), findsOneWidget);

      // Content is shown as selectable read-only text
      expect(find.text(testContent), findsOneWidget);

      // Edit button is icon-only (no text label), save/discard icons are not visible
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.save), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);

      // Content is wrapped in SelectionArea (read-only) not TextField
      expect(find.byType(SelectionArea), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    // ==================== Edit Mode: Icon-Only Buttons ====================

    testWidgets(
        'edit mode shows icon-only save, discard, undo, redo, font size buttons',
        (tester) async {
      await enterEditMode(tester);

      // View-mode edit icon should be gone
      expect(find.byIcon(Icons.edit), findsNothing);

      // Edit mode should have icon-only buttons (no text labels)
      expect(find.byIcon(Icons.format_size), findsOneWidget);
      expect(find.byIcon(Icons.save), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.undo), findsOneWidget);
      expect(find.byIcon(Icons.redo), findsOneWidget);

      // No text labels for any of these buttons
      expect(find.text('编辑'), findsNothing);
      expect(find.text('保存'), findsNothing);
      expect(find.text('放弃'), findsNothing);

      // SelectionArea should be replaced by TextField
      expect(find.byType(SelectionArea), findsNothing);
      expect(find.byType(TextField), findsOneWidget);

      // TextField should contain the original content
      final textField = tester.widget<TextField>(find.byType(TextField));
      final controller = textField.controller;
      expect(controller?.text, equals(testContent));
    });

    testWidgets('font size button shows slider popup and changes text size',
        (tester) async {
      await enterEditMode(tester);

      // Font size button should be present
      expect(find.byIcon(Icons.format_size), findsOneWidget);

      // Tap font size button
      await tester.tap(find.byIcon(Icons.format_size));
      await tester.pumpAndSettle();

      // Popup should show
      expect(find.text('字号调整'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // Default font size 14 should be shown
      expect(find.text('14'), findsOneWidget);

      // Drag slider to change font size
      final slider = find.byType(Slider);
      // Slide right to increase to a larger value
      await tester.drag(slider, const Offset(100, 0));
      await tester.pumpAndSettle();

      // The displayed value should have changed (greater than 14)
      // Close the popup
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();

      // Verify TextStyle font size has been updated in TextField
      final textField = tester.widget<TextField>(find.byType(TextField));
      final textStyle = textField.style;
      expect(textStyle?.fontSize, greaterThan(14));
    });

    // ==================== Undo / Redo ====================

    testWidgets('undo button reverts to previous text state', (tester) async {
      await enterEditMode(tester);

      // Modify the content
      final textField = tester.widget<TextField>(find.byType(TextField));
      final controller = textField.controller;
      controller?.text = 'Modified content';
      await tester.pump(); // 触发 listener 记录到撤销栈

      // Tap undo
      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();

      // Content should be back to original
      expect(controller?.text, equals(testContent));
    });

    testWidgets('redo button restores undone text state', (tester) async {
      await enterEditMode(tester);

      // Modify the content, then undo it
      final textField = tester.widget<TextField>(find.byType(TextField));
      final controller = textField.controller;
      controller?.text = 'Modified content';
      await tester.pump();

      // Undo
      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();

      // Redo
      await tester.tap(find.byIcon(Icons.redo));
      await tester.pumpAndSettle();

      // Content should be back to modified
      expect(controller?.text, equals('Modified content'));
    });

    testWidgets('undo is disabled when no undo history', (tester) async {
      await enterEditMode(tester);

      // At the start of edit mode, there should be no undo history
      // (only the initial state exists, no previous states to undo to)
      // Use ancestor finder to get the IconButton wrapping the undo icon
      final undoButtonFinder = find.ancestor(
        of: find.byIcon(Icons.undo),
        matching: find.byType(IconButton),
      );
      final undoButton = tester.widget<IconButton>(undoButtonFinder);
      expect(undoButton.onPressed, isNull);
    });

    testWidgets('redo is disabled when no redo history', (tester) async {
      await enterEditMode(tester);

      // After entering edit mode without any undo, redo should be disabled
      final redoButtonFinder = find.ancestor(
        of: find.byIcon(Icons.redo),
        matching: find.byType(IconButton),
      );
      final redoButton = tester.widget<IconButton>(redoButtonFinder);
      expect(redoButton.onPressed, isNull);
    });

    testWidgets('multiple undo steps work correctly', (tester) async {
      await enterEditMode(tester);

      final textField = tester.widget<TextField>(find.byType(TextField));
      final controller = textField.controller;

      // Make multiple changes
      controller?.text = 'Step 1';
      await tester.pump();
      controller?.text = 'Step 2';
      await tester.pump();

      // Undo twice
      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();
      expect(controller?.text, equals('Step 1'));

      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();
      expect(controller?.text, equals(testContent));
    });

    // ==================== Discard ====================

    testWidgets('close button is enabled in edit mode when no changes',
        (tester) async {
      await enterEditMode(tester);

      // Close button should be enabled even when no changes have been made
      final closeButtonFinder = find.ancestor(
        of: find.byIcon(Icons.close),
        matching: find.byType(IconButton),
      );
      final closeButton = tester.widget<IconButton>(closeButtonFinder);
      expect(closeButton.onPressed, isNotNull);
    });

    testWidgets('close button discards directly when no changes made',
        (tester) async {
      await enterEditMode(tester);

      // No modifications made - tap close (Icons.close)
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Should be back in view mode without confirmation dialog
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.text('放弃编辑？'), findsNothing);
    });

    testWidgets(
        'close button shows confirmation dialog when changes have been made and "放弃" discards',
        (tester) async {
      await enterEditMode(tester);

      // Modify the content
      final textField = tester.widget<TextField>(find.byType(TextField));
      final controller = textField.controller;
      controller?.text = 'Modified content';
      await tester.pump();

      // Tap discard (Icons.close)
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('放弃编辑？'), findsOneWidget);
      expect(find.text('你有未保存的更改，确定要放弃吗？'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('放弃'), findsOneWidget);

      // Tap "放弃" to confirm discarding
      await tester.tap(find.text('放弃'));
      await tester.pumpAndSettle();

      // Should be back in view mode with the edit icon
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.save), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);

      // Original content should be preserved (not the modified one)
      expect(find.text(testContent), findsOneWidget);
      expect(find.text('Modified content'), findsNothing);
    });

    testWidgets(
        'close button dialog "取消" dismisses dialog and stays in edit mode',
        (tester) async {
      await enterEditMode(tester);

      // Modify the content
      final textField = tester.widget<TextField>(find.byType(TextField));
      final controller = textField.controller;
      controller?.text = 'Modified content';
      await tester.pump();

      // Tap close (Icons.close)
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('放弃编辑？'), findsOneWidget);

      // Tap "取消" to dismiss dialog
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // Should still be in edit mode with modified content
      expect(find.byIcon(Icons.save), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('Modified content'), findsOneWidget);
    });

    // ==================== Save ====================

    testWidgets('save writes new content under new hash filename',
        (tester) async {
      await enterEditMode(tester);

      // Modify the content
      const newContent = 'Updated text content';
      final textField = tester.widget<TextField>(find.byType(TextField));
      final controller = textField.controller;
      controller?.text = newContent;
      await tester.pump();

      // Tap save (Icons.save)
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      // The old file should be deleted (no longer exists)
      final oldContent = await TextManifest.readText(testFile.storagePath);
      expect(oldContent, isNull);

      // The new content should be saved under the new hash filename
      // Use utf8.encode to properly compute hash (same as fixed save logic)
      final newBytes = Uint8List.fromList(utf8.encode(newContent));
      final newHash = computeTextHash(newBytes);
      final newStorageFileName = '$newHash.txt';
      final savedContent = await TextManifest.readText(newStorageFileName);
      expect(savedContent, equals(newContent));
    });

    testWidgets('save with Chinese text preserves content correctly',
        (tester) async {
      await enterEditMode(tester);

      // Modify with Chinese content (non-ASCII)
      const chineseContent = '你好世界！这是一段中文测试文本。Hello! 123';
      final textField = tester.widget<TextField>(find.byType(TextField));
      final controller = textField.controller;
      controller?.text = chineseContent;
      await tester.pump();

      // Tap save
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      // Compute expected hash using utf8.encode (same as fixed save logic)
      final expectedBytes = Uint8List.fromList(utf8.encode(chineseContent));
      final expectedHash = computeTextHash(expectedBytes);
      final newStorageFileName = '$expectedHash.txt';

      // Verify the saved content can be read back correctly
      final savedContent = await TextManifest.readText(newStorageFileName);
      expect(savedContent, equals(chineseContent),
          reason:
              'Chinese text saved via TextPreviewEditPage must roundtrip correctly. '
              'If this fails, the save logic may still use codeUnits instead of utf8.encode.');

      // Verify the old test file (ASCII only) was deleted
      final oldContent = await TextManifest.readText(testFile.storagePath);
      expect(oldContent, isNull);

      // Verify the hash computed by the page matches our expected hash
      // by comparing the stored file hash from the database
      final records = await TextManifest.loadRecords();
      final updatedRecord = records.first;
      expect(updatedRecord.hash, equals(expectedHash),
          reason:
              'Database record hash must match utf8-based hash for Chinese text. '
              'Bug: codeUnits truncation produces wrong hash for non-ASCII text.');
      expect(updatedRecord.size, equals(expectedBytes.length),
          reason:
              'Database record size must match utf8 byte count for Chinese text. '
              'Bug: codeUnits truncation produces wrong byte count.');
    });

    // ==================== Title ====================

    testWidgets('initial page shows correct title', (tester) async {
      final customFile = TextRecord(
        name: 'my_document',
        hash: testFile.hash,
        format: 'txt',
        createdAt: DateTime.now(),
        size: 100,
        textLength: 50,
      );

      await tester.pumpWidget(_buildTestApp(customFile, testContent));
      await navigateToEditor(tester);

      expect(find.text('my_document.txt'), findsOneWidget);
    });

    // ==================== Back Navigation: No Changes ====================

    testWidgets('back button pops directly in view mode', (tester) async {
      await tester.pumpWidget(_buildTestApp(testFile, testContent));
      await navigateToEditor(tester);

      // In view mode, back button pops directly without confirmation
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Page should be gone - we're back at placeholder
      expect(find.text('Placeholder'), findsOneWidget);
      expect(find.text('Open Editor'), findsOneWidget);
    });

    testWidgets('back button pops directly in edit mode with NO changes',
        (tester) async {
      await enterEditMode(tester);

      // No changes made to the content
      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Should pop directly without confirmation dialog
      expect(find.text('Placeholder'), findsOneWidget);
      expect(find.text('Open Editor'), findsOneWidget);
    });

    // ==================== Back Navigation: With Changes ====================

    testWidgets(
        'back button shows confirmation dialog in edit mode WITH changes',
        (tester) async {
      await enterEditMode(tester);

      // Make a change
      final textField = tester.widget<TextField>(find.byType(TextField));
      final controller = textField.controller;
      controller?.text = 'Changed content';
      await tester.pump();

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('放弃编辑？'), findsOneWidget);
      expect(find.text('你有未保存的更改，确定要放弃吗？'), findsOneWidget);

      // '取消' button should exist
      expect(find.text('取消'), findsOneWidget);

      // Tap '取消' to dismiss the dialog
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // Should still be in edit mode
      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('back button confirmation "放弃" discards changes and pops',
        (tester) async {
      await enterEditMode(tester);

      // Make a change
      final textField = tester.widget<TextField>(find.byType(TextField));
      final controller = textField.controller;
      controller?.text = 'Changed content';
      await tester.pump();

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('放弃编辑？'), findsOneWidget);

      // Tap the dialog's "放弃" button
      await tester.tap(find.text('放弃'));
      await tester.pumpAndSettle();

      // After discarding and popping, the page should be gone
      expect(find.text('Placeholder'), findsOneWidget);
      expect(find.text('Open Editor'), findsOneWidget);
    });

    // ==================== Undo/Redo After Discard ====================

    testWidgets('undo then redo becomes available', (tester) async {
      await enterEditMode(tester);

      // Make a change and undo it
      final textField = tester.widget<TextField>(find.byType(TextField));
      final controller = textField.controller;
      controller?.text = 'Change 1';
      await tester.pump();

      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();

      // Redo should now be available
      final redoButtonFinder = find.ancestor(
        of: find.byIcon(Icons.redo),
        matching: find.byType(IconButton),
      );
      final redoButton = tester.widget<IconButton>(redoButtonFinder);
      expect(redoButton.onPressed, isNotNull);
    });

    // ==================== Empty Content ====================

    testWidgets('renders empty content without error', (tester) async {
      final emptyFile = TextRecord(
        name: 'empty_file',
        hash: testFile.hash,
        format: 'txt',
        createdAt: DateTime.now(),
        size: 0,
        textLength: 0,
      );

      await tester.pumpWidget(_buildTestApp(emptyFile, ''));
      await navigateToEditor(tester);

      // Should show the title
      expect(find.text('empty_file.txt'), findsOneWidget);

      // Should show empty content area (no crash)
      expect(find.byType(SelectionArea), findsOneWidget);
    });

    // ==================== Font Size Button in View Mode ====================

    testWidgets(
        'font size button is visible in view mode (non-edit state) '
        'and pops up font size dialog with reset button', (tester) async {
      await tester.pumpWidget(_buildTestApp(testFile, testContent));
      await navigateToEditor(tester);

      // In view mode, font size button should be visible
      expect(find.byIcon(Icons.format_size), findsOneWidget);

      // Tap font size button
      await tester.tap(find.byIcon(Icons.format_size));
      await tester.pumpAndSettle();

      // Popup should show
      expect(find.text('字号调整'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // Should have a '恢复默认' (reset to default) button
      expect(find.text('恢复默认'), findsOneWidget);

      // Default value 14 should be visible in the popup
      expect(find.text('14'), findsOneWidget);
    });

    testWidgets('font size reset button restores font size to 14 after change',
        (tester) async {
      await enterEditMode(tester);

      // Tap font size button
      await tester.tap(find.byIcon(Icons.format_size));
      await tester.pumpAndSettle();

      // Drag slider to change font size
      final slider = find.byType(Slider);
      await tester.drag(slider, const Offset(100, 0));
      await tester.pumpAndSettle();

      // The displayed value should have changed
      final fontSizeText = find.textContaining(RegExp(r'[0-9]+'));
      expect(fontSizeText, findsWidgets);

      // Tap reset button
      await tester.tap(find.text('恢复默认'));
      await tester.pumpAndSettle();

      // After reset, should show '14' again
      // (the popup re-renders with fontSize back to 14)
      expect(find.text('14'), findsWidgets);
    });

    // ==================== Font Size Persistence ====================

    testWidgets('font size persists across page reopen', (tester) async {
      await enterEditMode(tester);

      // Adjust font size and close the popup
      await tester.tap(find.byIcon(Icons.format_size));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Slider), const Offset(100, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();

      // Record the adjusted size and verify it was persisted
      final textField = tester.widget<TextField>(find.byType(TextField));
      final adjustedSize = textField.style?.fontSize;
      expect(adjustedSize, greaterThan(14));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('text_preview_font_size'), adjustedSize);

      // Go back and reopen the page
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await navigateToEditor(tester);
      await tester.pump();

      // View mode should restore the persisted font size
      expect(_viewModeContentStyle(tester)?.fontSize, adjustedSize);
    });

    testWidgets('font size reset persists default across page reopen',
        (tester) async {
      await enterEditMode(tester);

      // Increase font size first
      await tester.tap(find.byIcon(Icons.format_size));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Slider), const Offset(100, 0));
      await tester.pumpAndSettle();

      // Reset to default
      await tester.tap(find.text('恢复默认'));
      await tester.pumpAndSettle();
      expect(find.text('14'), findsWidgets);

      // Close popup, go back and reopen the page
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await navigateToEditor(tester);
      await tester.pump();

      // View mode should restore the default 14
      expect(_viewModeContentStyle(tester)?.fontSize, 14);
    });

    testWidgets('out-of-range persisted font size is clamped on load',
        (tester) async {
      SharedPreferences.setMockInitialValues({'text_preview_font_size': 999.0});

      await tester.pumpWidget(_buildTestApp(testFile, testContent));
      await navigateToEditor(tester);
      await tester.pump();

      final selectable = _viewModeContentStyle(tester);
      expect(selectable?.fontSize, 28);
    });

    testWidgets('non-finite persisted font size falls back to default',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {'text_preview_font_size': double.nan});

      await tester.pumpWidget(_buildTestApp(testFile, testContent));
      await navigateToEditor(tester);
      await tester.pump();

      final selectable = _viewModeContentStyle(tester);
      expect(selectable?.fontSize, 14);
    });

    testWidgets(
        'font size adjusted mid-drag is persisted when dialog dismissed',
        (tester) async {
      await enterEditMode(tester);

      // Open the popup and start a slider drag without releasing the pointer
      await tester.tap(find.byIcon(Icons.format_size));
      await tester.pumpAndSettle();
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(Slider)));
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();

      // Dismiss the dialog mid-drag by tapping the barrier with a second
      // pointer, so Slider's onChangeEnd never fires
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await gesture.cancel();
      await tester.pumpAndSettle();

      // The adjusted size must still have been persisted
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble('text_preview_font_size');
      expect(saved, isNotNull);
      expect(saved, greaterThan(14));
    });

    // ==================== MMD Format Support ====================

    group('mmd format support', () {
      const mmdContent = 'graph TD\n  A[Start] --> B[End]';

      late TextRecord mmdFile;

      setUp(() async {
        final bytes = Uint8List.fromList(utf8.encode(mmdContent));
        final hash = computeTextHash(bytes);
        final storageFileName = '$hash.txt';
        await TextManifest.writeText(storageFileName, mmdContent);

        mmdFile = TextRecord(
          name: 'my_chart',
          hash: hash,
          format: 'mmd',
          createdAt: DateTime.now(),
          size: bytes.length,
          textLength: mmdContent.length,
        );
        await TextManifest.addRecord(mmdFile);
      });

      testWidgets('renders mmd file content as selectable text in view mode',
          (tester) async {
        await tester.pumpWidget(_buildTestApp(mmdFile, mmdContent));
        await navigateToEditor(tester);

        // Title should show filename.mmd
        expect(find.text('my_chart.mmd'), findsOneWidget);

        // Content should be shown as selectable text
        expect(find.text(mmdContent), findsOneWidget);
        expect(find.byType(SelectionArea), findsOneWidget);
      });

      testWidgets(
          'mmd view mode shows chart editor button to open MermaidChartPage',
          (tester) async {
        await tester.pumpWidget(_buildTestApp(mmdFile, mmdContent));
        await navigateToEditor(tester);

        // Should show the chart editor button in view mode
        expect(find.byIcon(Icons.account_tree), findsOneWidget);
      });
    });

    // ==================== Scroll on Drag (desktop) ====================
    //
    // 在 Windows/Linux/macOS 上，SelectableText 内部的拖拽识别器是
    // TapAndPanGestureRecognizer（接受包括触摸在内的所有指针类型）。
    // 它的接受阈值（computePanSlop：触摸 36px/鼠标 2px）虽然大于外层
    // SingleChildScrollView 的垂直拖拽阈值（18px/1px），但手势竞技场中
    // 谁先 accept 谁赢——当单次移动事件跨越 pan 阈值（快速拖动、触控板
    // 大位移）时，位于更内层的文本识别器先处理事件并胜出，导致在文本上
    // （以及文本末尾空行形成的空白区域）拖动变成文本选择而不是滚动页面。
    //
    // 注意：不能用 tester.drag 复现——它的第一步移动固定是 kDragSlopDefault
    // （20px），恰好超过滚动视图阈值（18px）但不超过 pan 阈值（36px），
    // 会让滚动视图抢先胜出，掩盖这个缺陷。因此这里用手动手势模拟
    // 「先小步移动、再大步跨越」的真实快速拖动。

    /// 生成 [lineCount] 行文本，保证内容超出视口需要滚动
    String longContent(int lineCount) =>
        List.generate(lineCount, (i) => 'Scroll line $i').join('\n');

    /// 页面内容滚动视图对应的 Scrollable（第一个，即外层
    /// SingleChildScrollView 的）
    Finder pageScrollable() => find
        .descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        )
        .first;

    /// 从 [start] 开始做一次「快速拖动」：先移动 [slop] 个像素，再单次
    /// 大步移动 [bigJump] 像素两次，最后抬手。默认向上（负 dy，从文档
    /// 顶部向下滚动）；向下拖动时传入正的 [bigJump]。
    ///
    /// 三段的理由：滚动视图的拖拽在跨越阈值（18px）的那次移动才启动，
    /// 且启动那次移动的位移被 DragStartBehavior.start 消耗（不产生滚动），
    /// 因此需要后续再有一次大位移才能真正滚动页面——这也更接近真实的
    /// 快速连续拖动。
    Future<void> fastDrag(
      WidgetTester tester,
      Offset start, {
      Offset slop = const Offset(0, -10),
      Offset bigJump = const Offset(0, -60),
    }) async {
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(slop);
      await gesture.moveBy(bigJump);
      await gesture.moveBy(bigJump);
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets(
        'desktop touch drag on the text scrolls the page instead of '
        'selecting text', (tester) async {
      await _withPlatform(tester, TargetPlatform.windows, () async {
        await tester.pumpWidget(_buildTestApp(testFile, longContent(100)));
        await navigateToEditor(tester);

        final scrollable = pageScrollable();
        expect(
          tester.state<ScrollableState>(scrollable).position.pixels,
          0,
          reason: '页面初始应位于顶部',
        );

        // 在文本区域上快速触摸拖动：页面必须滚动
        await fastDrag(tester, tester.getCenter(scrollable));

        expect(
          tester.state<ScrollableState>(scrollable).position.pixels,
          greaterThan(0),
          reason: '在文本上拖动应滚动页面而不是被文本选择手势拦截',
        );
      });
    });

    testWidgets(
        'desktop touch drag on the trailing blank area scrolls the page',
        (tester) async {
      await _withPlatform(tester, TargetPlatform.windows, () async {
        // 文本末尾带大量空行：末尾空行（空白区域）位于文本小部件的
        // 命中范围内，同样不应拦截滚动
        final content = '${longContent(40)}\n${'\n' * 80}';
        await tester.pumpWidget(_buildTestApp(testFile, content));
        await navigateToEditor(tester);

        final scrollable = pageScrollable();
        final position = tester.state<ScrollableState>(scrollable).position;

        // 先滚到底部附近，让末尾空行区域进入视口
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(position.pixels, greaterThan(0));
        final pixelsBefore = position.pixels;

        // 在视口下部（末尾空行所在的空白区域）快速向下拖动（位于文档
        // 底部时向下拖动是向文档开头滚动）：页面必须滚动。
        // 注意拖动点必须落在滚动视图内（测试环境中 Scaffold 给 body 的
        // 是松散约束，滚动视图会收缩到文本宽度，而不是铺满屏幕）
        final viewportRect = tester.getRect(find.byType(SingleChildScrollView));
        await fastDrag(
          tester,
          Offset(viewportRect.center.dx, viewportRect.bottom - 30),
          bigJump: const Offset(0, 60),
        );

        expect(
          position.pixels,
          lessThan(pixelsBefore),
          reason: '在末尾空白区域拖动应滚动页面而不是被文本选择手势拦截',
        );
      });
    });

    // ==================== Markdown Format ====================

    group('markdown format', () {
      const mdContent = '# 标题\n\n这是**加粗**文本。';
      late TextRecord mdFile;

      setUp(() async {
        final bytes = Uint8List.fromList(utf8.encode(mdContent));
        final hash = computeTextHash(bytes);
        final storageFileName = '$hash.txt';
        await TextManifest.writeText(storageFileName, mdContent);

        mdFile = TextRecord(
          name: 'readme',
          hash: hash,
          format: 'md',
          createdAt: DateTime.now(),
          size: bytes.length,
          textLength: mdContent.length,
        );
        await TextManifest.addRecord(mdFile);
      });

      testWidgets('markdown hides font size button in view and edit mode',
          (tester) async {
        await tester.pumpWidget(_buildTestApp(mdFile, mdContent));
        await navigateToEditor(tester);

        // Title shows filename.md
        expect(find.text('readme.md'), findsOneWidget);

        // View mode: no font size adjustment button
        expect(find.byIcon(Icons.format_size), findsNothing);

        // Edit mode: still no font size adjustment button
        await tester.tap(find.byIcon(Icons.edit));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.format_size), findsNothing);
        expect(find.byIcon(Icons.save), findsOneWidget);
      });
    });
  });
}
