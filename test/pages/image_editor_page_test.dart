import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/image_editor_page.dart';

void main() {
  // ====================================================================
  // Editor configuration: save affordance clarity
  //
  // The main editor's top-right button must be a save icon (final save),
  // while sub-editors (crop, paint, ...) keep their checkmark confirm
  // buttons (apply this edit). This pins the user-facing contract in
  // case a future package upgrade changes the defaults.
  // ====================================================================
  group('buildImageEditorConfigs', () {
    test('main editor top-right button is a save icon, close stays X',
        () {
      final configs = buildImageEditorConfigs();

      expect(configs.mainEditor.icons.doneIcon, Icons.save,
          reason: 'final save must look like a save button, not a check');
      expect(configs.mainEditor.icons.closeEditor, Icons.clear,
          reason: 'closing without saving must stay an X');
    });

    test('sub-editor confirm buttons stay checkmarks', () {
      final configs = buildImageEditorConfigs();

      expect(configs.cropRotateEditor.icons.applyChanges, Icons.done,
          reason: 'crop/rotate confirm (打勾) must remain a checkmark');
    });

    test('done tooltip and processing message are localized to Chinese',
        () {
      final configs = buildImageEditorConfigs();

      expect(configs.i18n.done, '保存');
      expect(configs.i18n.doneLoadingMsg, '正在生成图片，请稍候…',
          reason: 'user must see clear feedback while the image is generated');
    });
  });

  // ====================================================================
  // Tests for the save dialog function
  // ====================================================================
  group('showImageSaveDialog', () {
    testWidgets('shows correct save options', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => showImageSaveDialog(context),
            child: const Text('保存'),
          );
        }),
      ));

      // Tap save button to show dialog
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Dialog should show with all options
      expect(find.text('保存图片'), findsOneWidget);
      expect(find.text('覆盖'), findsOneWidget);
      expect(find.text('另存为'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
    });

    testWidgets('cancel returns SaveAction.cancel', (tester) async {
      SaveAction? result;

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              result = await showImageSaveDialog(context);
            },
            child: const Text('保存'),
          );
        }),
      ));

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // Dialog should be gone and result should be null
      expect(find.text('保存图片'), findsNothing);
      expect(result, SaveAction.cancel);
    });

    testWidgets('overwrite returns SaveAction.overwrite', (tester) async {
      SaveAction? result;

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              result = await showImageSaveDialog(context);
            },
            child: const Text('保存'),
          );
        }),
      ));

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Tap 覆盖
      await tester.tap(find.text('覆盖'));
      await tester.pumpAndSettle();

      expect(result, SaveAction.overwrite);
    });

    testWidgets('save-as returns SaveAction.saveAs', (tester) async {
      SaveAction? result;

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              result = await showImageSaveDialog(context);
            },
            child: const Text('保存'),
          );
        }),
      ));

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Tap 另存为
      await tester.tap(find.text('另存为'));
      await tester.pumpAndSettle();

      expect(result, SaveAction.saveAs);
    });

    testWidgets('dialog is not dismissible by tapping outside', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => showImageSaveDialog(context),
            child: const Text('保存'),
          );
        }),
      ));

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Dialog should be present
      expect(find.text('保存图片'), findsOneWidget);

      // Tap outside the dialog (on the barrier)
      // The dialog's barrierDismissible is false, so it should not dismiss
      await tester.tapAt(const Offset(0, 0));
      await tester.pumpAndSettle();

      // Dialog should still be visible
      expect(find.text('保存图片'), findsOneWidget);
    });
  });

  group('showDiscardOrSaveDialog', () {
    testWidgets('shows correct title and options', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => showDiscardOrSaveDialog(context),
            child: const Text('保存'),
          );
        }),
      ));

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('保存照片'), findsOneWidget);
      // "保存" appears inside the dialog's FilledButton and on the trigger button
      expect(find.widgetWithText(FilledButton, '保存'), findsOneWidget);
      expect(find.text('不保存'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
    });

    testWidgets('save returns SaveAction.save', (tester) async {
      SaveAction? result;

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              result = await showDiscardOrSaveDialog(context);
            },
            child: const Text('保存'),
          );
        }),
      ));

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Tap the "保存" FilledButton inside the dialog
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      expect(result, SaveAction.save);
    });

    testWidgets('discard returns SaveAction.discard', (tester) async {
      SaveAction? result;

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              result = await showDiscardOrSaveDialog(context);
            },
            child: const Text('保存'),
          );
        }),
      ));

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('不保存'));
      await tester.pumpAndSettle();

      expect(result, SaveAction.discard);
    });

    testWidgets('cancel returns SaveAction.cancel', (tester) async {
      SaveAction? result;

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              result = await showDiscardOrSaveDialog(context);
            },
            child: const Text('保存'),
          );
        }),
      ));

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(result, SaveAction.cancel);
    });
  });
}
