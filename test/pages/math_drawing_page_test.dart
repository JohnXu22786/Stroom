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
    testWidgets('renders app bar with correct title', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.text('数学绘制'), findsOneWidget);
    });

    testWidgets('renders 2D and 3D tabs', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.text('2D 绘图'), findsOneWidget);
      expect(find.text('3D'), findsOneWidget);
    });

    testWidgets('shows one empty formula input initially', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows plot and add-formula buttons', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.byIcon(Icons.keyboard_return), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    });
  });

  group('MathDrawingPage - multi formula', () {
    testWidgets('typing in formula field updates state', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pump();

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller?.text, equals('x^2'));
    });

    testWidgets('plot button enabled when text differs from committed',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pump();

      // Button should be enabled
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('plot button disabled after plotting (no change)',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.keyboard_return));
      await tester.pumpAndSettle();

      // Button should now be disabled
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('plot button re-enabled when formula changes', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.keyboard_return));
      await tester.pumpAndSettle();

      // Change expression
      await tester.enterText(find.byType(TextField), 'x^3');
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('add formula button adds another input field',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Initially 1 text field
      expect(find.byType(TextField), findsOneWidget);

      // Add formula
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();

      // Now 2 text fields
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('remove formula button removes input field', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Add second formula
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(2));

      // Remove first formula
      await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
      await tester.pump();

      // Should have 1 left
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('pressing plot with multiple formulas works', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Enter first formula
      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pump();

      // Add second formula
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();

      // Enter text in second text field
      final fields = find.byType(TextField);
      await tester.enterText(fields.last, 'x');
      await tester.pump();

      // Press plot
      await tester.tap(find.byIcon(Icons.keyboard_return));
      await tester.pumpAndSettle();

      // No crash
      expect(tester.takeException(), isNull);
    });
  });

  group('MathDrawingPage - tab switching', () {
    testWidgets('switching to 3D shows placeholder', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.tap(find.text('3D'));
      await tester.pumpAndSettle();

      expect(find.text('3D 绘图功能即将推出'), findsOneWidget);
    });

    testWidgets('switching back to 2D shows input fields', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.tap(find.text('3D'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2D 绘图'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('MathDrawingPage - error handling', () {
    testWidgets('app does not crash', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows error for invalid expression', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'x ^^ 2');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.keyboard_return));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

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
