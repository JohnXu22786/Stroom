import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/image_editor_page.dart';

void main() {
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
