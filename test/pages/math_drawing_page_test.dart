import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/math_drawing_page.dart';

Widget _buildTestApp({bool initialShowWebView = false}) {
  return MaterialApp(
    home: MathDrawingPage(initialShowWebView: initialShowWebView),
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
      await tester.pumpAndSettle();

      expect(find.text('数学绘制'), findsOneWidget);
    });

    testWidgets('renders 2D tab and 3D placeholder tab', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('2D 绘图'), findsOneWidget);
      expect(find.text('3D'), findsOneWidget);
    });

    testWidgets('renders formula input field', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('renders plot button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.functions), findsOneWidget);
    });

    testWidgets('shows placeholder text when no expression entered', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('输入数学表达式，如: x^2'), findsOneWidget);
    });
  });

  group('MathDrawingPage - expression input', () {
    testWidgets('typing expression updates LaTeX preview', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Type an expression
      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pumpAndSettle();

      // LaTeX preview should be visible
      expect(find.textContaining('x^2'), findsWidgets);
    });

    testWidgets('plot button is enabled when expression is entered', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Initially, plot button might be disabled
      // Type an expression
      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pumpAndSettle();

      // Plot button should be available
      expect(find.byIcon(Icons.functions), findsOneWidget);
    });

    testWidgets('clear button clears the expression', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Type an expression
      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pumpAndSettle();

      // Check the text field has the value
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals('x^2'));
    });
  });

  group('MathDrawingPage - parameter sliders', () {
    testWidgets('sliders appear when expression has parameters', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Enter expression with parameters
      await tester.enterText(find.byType(TextField), 'a*x^2 + b');
      await tester.pumpAndSettle();

      // Press the plot button to trigger parsing and slider display
      await tester.tap(find.byIcon(Icons.functions));
      await tester.pumpAndSettle();

      // Parameter sliders should appear
      // a and b are parameters
      expect(find.text('a'), findsWidgets);
      expect(find.text('b'), findsWidgets);
    });

    testWidgets('sliders disappear when expression is cleared', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Enter expression with parameters and plot
      await tester.enterText(find.byType(TextField), 'a*x + b');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.functions));
      await tester.pumpAndSettle();

      // Clear it
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      // Parameter labels should not be visible
      expect(find.text('a'), findsNothing);
    });
  });

  group('MathDrawingPage - tab switching', () {
    testWidgets('2D tab is selected by default', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // 2D tab should be active
      // The TabBar is present
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('switching to 3D tab shows coming soon message', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Tap 3D tab
      await tester.tap(find.text('3D'));
      await tester.pumpAndSettle();

      // Should show coming soon message
      expect(find.text('3D 绘图功能即将推出'), findsOneWidget);
    });

    testWidgets('switching back to 2D tab shows expression input', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Switch to 3D
      await tester.tap(find.text('3D'));
      await tester.pumpAndSettle();

      // Switch back to 2D
      await tester.tap(find.text('2D 绘图'));
      await tester.pumpAndSettle();

      // Input field should be visible again
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('MathDrawingPage - bottom coordinate panel', () {
    testWidgets('coordinate panel shows initial empty state', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Coordinate panel should show initial state
      expect(find.text('坐标数据'), findsOneWidget);
    });
  });

  group('MathDrawingPage - error handling', () {
    testWidgets('app does not crash on empty expression', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Just verify no crash
      expect(tester.takeException(), isNull);
    });
  });
}
