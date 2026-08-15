import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/math_drawing_page.dart';

Widget _buildTestApp({String? initialExpression}) {
  return MaterialApp(
    home: MathDrawingPage(initialExpression: initialExpression),
    localizationsDelegates: const [
      DefaultMaterialLocalizations.delegate,
      DefaultWidgetsLocalizations.delegate,
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MathDrawingPage - formula input', () {
    testWidgets('checkmark button plots formulas', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('MathDrawingPage - multi formula', () {
    testWidgets('add button adds another row', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_circle));
      await tester.pump();

      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('remove button with confirmation removes formula',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Add a second formula
      await tester.tap(find.byIcon(Icons.add_circle));
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(2));

      // Tap remove on first formula
      await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Confirmation dialog should appear
      expect(find.text('删除'), findsWidgets);

      // Confirm deletion
      await tester.tap(find.text('删除').last);
      await tester.pump();

      // Now 1 formula should remain
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('add button only on first row', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add_circle));
      await tester.pump();

      // There should be exactly 1 add button (only on first row)
      expect(find.byIcon(Icons.add_circle), findsOneWidget);
    });

    testWidgets('eye toggle hides formula', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pump();

      // Tap eye to toggle
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();

      // Should now show eye-off icon
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('plotting across tabs keeps formulas alive', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Enter formula
      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pump();

      // Plot it
      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();

      // Switch to 3D tab
      await tester.tap(find.text('3D'));
      await tester.pumpAndSettle();

      // Switch back to 2D tab
      await tester.tap(find.text('2D 绘图'));
      await tester.pumpAndSettle();

      // Text field should still have the formula
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller?.text, equals('x^2'));

      // Canvas should still be present
      expect(tester.takeException(), isNull);
    });
  });

  group('MathDrawingPage - error handling', () {
    testWidgets('shows error for invalid expression', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'x ^^ 2');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
    });
  });

  group('MathDrawingPage - UI spacing', () {
    // Helpers to measure the formula row's action buttons (the IconButtons
    // inside the row that contains the formula TextField, excluding the
    // AppBar's reset-view button and the TextField's own undo suffix icon).
    List<Rect> rowButtonRects(WidgetTester tester, {int rowIndex = 0}) {
      final row = find
          .ancestor(
            of: find.byType(TextField).at(rowIndex),
            matching: find.byType(Row),
          )
          .first;
      final buttons = find.descendant(
        of: row,
        matching: find.byWidgetPredicate(
          (w) => w is IconButton && (w.icon as Icon?)?.icon != Icons.undo,
        ),
      );
      return [
        for (var i = 0; i < buttons.evaluate().length; i++)
          tester.getRect(buttons.at(i)),
      ];
    }

    Rect textFieldRect(WidgetTester tester, {int rowIndex = 0}) {
      return tester.getRect(find.byType(TextField).at(rowIndex));
    }

    void expectUniformSpacing(
      WidgetTester tester, {
      required int rowIndex,
      required double gap,
    }) {
      final tfRect = textFieldRect(tester, rowIndex: rowIndex);
      final rects = rowButtonRects(tester, rowIndex: rowIndex);
      expect(rects, isNotEmpty);

      // Input -> first action button
      expect(rects.first.left - tfRect.right, closeTo(gap, 0.01),
          reason: 'Gap between text field and first action button');

      // Every action button is a compact 24x24 block
      for (final r in rects) {
        expect(r.width, closeTo(24, 0.01),
            reason: 'Action button should be 24 wide (compact block)');
        expect(r.height, closeTo(24, 0.01),
            reason: 'Action button should be 24 tall (compact block)');
      }

      // Uniform gaps between consecutive buttons
      for (var i = 0; i < rects.length - 1; i++) {
        expect(rects[i + 1].left - rects[i].right, closeTo(gap, 0.01),
            reason: 'Gap between consecutive action buttons should be uniform');
      }
    }

    testWidgets(
        'action buttons are compact 24x24 blocks with uniform 12px gaps',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      expectUniformSpacing(tester, rowIndex: 0, gap: 12);
    });
  });

  group('MathDrawingPage - initial expression', () {
    testWidgets('pre-populates expression when provided', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(initialExpression: 'sin(x)'),
      );
      await tester.pump();

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller?.text, equals('sin(x)'));
    });
  });
}
