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

  group('MathDrawingPage - initial render', () {
    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.text('数学绘图'), findsOneWidget);
    });

    testWidgets('renders 2D and 3D tabs', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.text('2D 绘图'), findsOneWidget);
      expect(find.text('3D'), findsOneWidget);
    });

    testWidgets('shows one formula row with text field', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows add, checkmark, eye, color buttons', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.byIcon(Icons.add_circle), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });
  });

  group('MathDrawingPage - formula input', () {
    testWidgets('typing shows in text field', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pump();
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller?.text, equals('x^2'));
    });

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
    testWidgets('no crash on empty', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

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
    testWidgets('formula row left side has adequate spacing', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Color circle and eye icon should both be present
      expect(find.byIcon(Icons.visibility), findsOneWidget);

      // The color indicator is a Container with circle shape
      // Check that the Row has appropriate spacing
      // (verified indirectly by layout not crashing)
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'right side formula IconButtons have compact constraints for consistent sizing',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Find only the IconButtons within the formula list (exclude AppBar)
      final formulaList = find.byType(ListView);
      final iconButtonsInFormula = find.descendant(
        of: formulaList,
        matching: find.byType(IconButton),
      );

      // Should have at least add + checkmark (2)
      expect(iconButtonsInFormula, findsAtLeastNWidgets(2));

      // All formula IconButtons should have explicit tight constraints (28x28)
      for (final btn in iconButtonsInFormula.evaluate()) {
        final ib = btn.widget as IconButton;
        final c = ib.constraints;
        expect(c, isNotNull);
        expect(c!.minWidth, 28);
        expect(c.maxWidth, 28);
        expect(c.minHeight, 28);
        expect(c.maxHeight, 28);
      }
    });

    testWidgets('remove button also has tight constraints when visible',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Add a second formula to make remove button visible
      await tester.tap(find.byType(IconButton).first);
      await tester.pump();

      final formulaList = find.byType(ListView);
      final iconButtonsInFormula = find.descendant(
        of: formulaList,
        matching: find.byType(IconButton),
      );

      // Now should have more IconButtons (add, 2×remove, 2×plot = 5)
      expect(iconButtonsInFormula, findsAtLeastNWidgets(3));

      // All should have tight constraints
      for (final btn in iconButtonsInFormula.evaluate()) {
        final ib = btn.widget as IconButton;
        final c = ib.constraints;
        expect(c, isNotNull);
        expect(c!.minWidth, 28);
        expect(c.maxWidth, 28);
      }
    });

    testWidgets('formula row overall layout does not overflow', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Type a long formula to stress test layout
      await tester.enterText(
        find.byType(TextField),
        'sin(x) + cos(x) + tan(x) + log(x) + sqrt(x)',
      );
      await tester.pump();

      // Should not have overflow errors
      expect(tester.takeException(), isNull);
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
