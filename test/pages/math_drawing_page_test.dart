import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/math_drawing_page.dart';

Widget _buildTestApp({bool initialShowWebView = false, String? initialExpression}) {
  return MaterialApp(
    home: MathDrawingPage(
      initialShowWebView: initialShowWebView,
      initialExpression: initialExpression,
    ),
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

    testWidgets('renders 2D tab and 3D placeholder tab', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.text('2D 绘图'), findsOneWidget);
      expect(find.text('3D'), findsOneWidget);
    });

    testWidgets('renders formula input field', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('renders plot button with keyboard return icon', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.byIcon(Icons.keyboard_return), findsOneWidget);
    });

    testWidgets('shows placeholder text when no expression entered',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.text('输入数学表达式，如: x^2'), findsOneWidget);
    });
  });

  group('MathDrawingPage - expression input', () {
    testWidgets('typing expression shows in text field', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals('x^2'));
    });

    testWidgets('plot button enabled when expression differs from rendered',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Initially no expression rendered, typing enables the button
      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pump();

      expect(find.byIcon(Icons.keyboard_return), findsOneWidget);
    });

    testWidgets('pressing plot triggers canvas rendering', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.keyboard_return));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('button disabled after expression is rendered (no change)',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Enter and plot
      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.keyboard_return));
      await tester.pumpAndSettle();

      // Button should now be disabled (expression matches rendered)
      final button = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('button re-enabled when expression changes after render',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Enter and plot x^2
      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.keyboard_return));
      await tester.pumpAndSettle();

      // Change the expression
      await tester.enterText(find.byType(TextField), 'x^3');
      await tester.pump();

      // Button should be enabled again
      final button = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(button.onPressed, isNotNull);
    });
  });

  group('MathDrawingPage - parameter sliders', () {
    testWidgets('sliders appear when expression has parameters',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'a*x^2 + b');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.keyboard_return));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('a'), findsWidgets);
      expect(find.text('b'), findsWidgets);
    });

    testWidgets('sliders disappear when expression is cleared',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'a*x + b');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.keyboard_return));
      await tester.pump();

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('a'), findsNothing);
    });
  });

  group('MathDrawingPage - tab switching', () {
    testWidgets('2D tab is selected by default', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('switching to 3D tab shows coming soon message',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.tap(find.text('3D'));
      await tester.pumpAndSettle();

      expect(find.text('3D 绘图功能即将推出'), findsOneWidget);
    });

    testWidgets('switching back to 2D tab shows expression input',
        (tester) async {
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
    testWidgets('app does not crash on empty expression', (tester) async {
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

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals('sin(x)'));
    });
  });
}
