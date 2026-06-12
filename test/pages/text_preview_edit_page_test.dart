import 'dart:typed_data';

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
      final bytes = Uint8List.fromList(testContent.codeUnits);
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
    });

    /// 导航到编辑页面
    Future<void> navigateToEditor(WidgetTester tester) async {
      await tester.tap(find.text('Open Editor'));
      await tester.pumpAndSettle();
    }

    /// 进入编辑模式（含初始化 widget）
    Future<void> enterEditMode(WidgetTester tester, {TextRecord? file, String? content}) async {
      await tester.pumpWidget(_buildTestApp(file ?? testFile, content ?? testContent));
      await navigateToEditor(tester);
      // Tap the edit icon button
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
    }

    // ==================== View Mode ====================

    testWidgets('renders in view mode with read-only text and icon-only edit button',
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

      // Content is SelectableText (read-only) not TextField
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    // ==================== Edit Mode: Icon-Only Buttons ====================

    testWidgets('edit mode shows icon-only save, discard, undo, redo buttons',
        (tester) async {
      await enterEditMode(tester);

      // View-mode edit icon should be gone
      expect(find.byIcon(Icons.edit), findsNothing);

      // Edit mode should have icon-only buttons (no text labels)
      expect(find.byIcon(Icons.save), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.undo), findsOneWidget);
      expect(find.byIcon(Icons.redo), findsOneWidget);

      // No text labels for any of these buttons
      expect(find.text('编辑'), findsNothing);
      expect(find.text('保存'), findsNothing);
      expect(find.text('放弃'), findsNothing);

      // SelectableText should be replaced by TextField
      expect(find.byType(SelectableText), findsNothing);
      expect(find.byType(TextField), findsOneWidget);

      // TextField should contain the original content
      final textField = tester.widget<TextField>(find.byType(TextField));
      final controller = textField.controller;
      expect(controller?.text, equals(testContent));
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

    testWidgets('discard reverts to view mode preserving original content',
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

      // Should be back in view mode with the edit icon
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.save), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);

      // Original content should be preserved (not the modified one)
      expect(find.text(testContent), findsOneWidget);
      expect(find.text('Modified content'), findsNothing);
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
      final newBytes = Uint8List.fromList(newContent.codeUnits);
      final newHash = computeTextHash(newBytes);
      final newStorageFileName = '$newHash.txt';
      final savedContent = await TextManifest.readText(newStorageFileName);
      expect(savedContent, equals(newContent));
    });

    // ==================== Title ====================

    testWidgets('initial page shows correct title', (tester) async {
      final customFile = TextRecord(
        name: 'my_document',
        hash: testFile.hash,
        format: 'md',
        createdAt: DateTime.now(),
        size: 100,
        textLength: 50,
      );

      await tester.pumpWidget(_buildTestApp(customFile, testContent));
      await navigateToEditor(tester);

      expect(find.text('my_document.md'), findsOneWidget);
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

      // '继续编辑' button should exist
      expect(find.text('继续编辑'), findsOneWidget);

      // Tap '继续编辑' to dismiss the dialog
      await tester.tap(find.text('继续编辑'));
      await tester.pumpAndSettle();

      // Should still be in edit mode
      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets(
        'back button confirmation "放弃" discards changes and pops',
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

    testWidgets('undo then redo becomes available',
        (tester) async {
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
  });
}
