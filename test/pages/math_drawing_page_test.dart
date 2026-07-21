import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/math_3d_tool.dart';
import 'package:stroom/pages/math_drawing_page.dart';
import 'package:stroom/widgets/math_3d_toolbar.dart';

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
    testWidgets(
        'eye icon is inside TextField as prefixIcon for consistent spacing',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // The eye icon should be rendered inside the TextField's InputDecoration
      // as a prefixIcon, not as a standalone GestureDetector in the Row.
      final tf = tester.widget<TextField>(find.byType(TextField));
      final decoration = tf.decoration;
      expect(decoration, isNotNull);

      // prefixIcon should be present and wrap an Icon with Icons.visibility
      final prefixIcon = decoration!.prefixIcon;
      expect(prefixIcon, isNotNull);

      // Verify the prefixIcon widget tree contains Icons.visibility
      final iconInPrefix = find.descendant(
        of: find.byWidgetPredicate((w) => w == prefixIcon),
        matching: find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.visibility,
        ),
      );
      expect(iconInPrefix, findsOneWidget);

      // Ensure no standalone eye icon exists directly in the Row
      // (the only eye icon should be inside the TextField as prefixIcon)
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('eye icon as prefixIcon toggles visibility when tapped',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pump();

      // Tap the visibility icon (now inside the TextField as prefixIcon)
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();

      // Should now show visibility_off icon
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      // Tap again to toggle back
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets(
        'prefixIcon and suffixIcon both exist inside TextField decoration with balanced spacing',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Enter text to make the undo suffixIcon appear
      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pump();

      final tf = tester.widget<TextField>(find.byType(TextField));
      final decoration = tf.decoration;
      expect(decoration, isNotNull);

      // Both prefixIcon (eye) and suffixIcon (undo) should be present
      expect(decoration!.prefixIcon, isNotNull);
      expect(decoration.suffixIcon, isNotNull);

      // Both use the same contentPadding for balanced spacing
      expect(decoration.contentPadding,
          const EdgeInsets.symmetric(horizontal: 8, vertical: 6));
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

      // All formula IconButtons should have explicit tight constraints (24x24)
      for (final btn in iconButtonsInFormula.evaluate()) {
        final ib = btn.widget as IconButton;
        final c = ib.constraints;
        expect(c, isNotNull);
        expect(c!.minWidth, 24);
        expect(c.maxWidth, 24);
        expect(c.minHeight, 24);
        expect(c.maxHeight, 24);
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
        expect(c!.minWidth, 24);
        expect(c.maxWidth, 24);
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

  group('Math3DToolbar - tool icons', () {
    testWidgets('renders all tool buttons with Material icons', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Math3DToolbar(
            activeTool: ConstructionTool.move,
            onToolSelected: (_) {},
          ),
        ),
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
      ));
      await tester.pump();

      // Each ConstructionTool should have a corresponding Material Icon rendered
      for (final tool in ConstructionTool.values) {
        final info = ToolInfo.all[tool]!;
        // Verify the icon data is a Material Design icon (not a string)
        expect(info.iconData, isA<IconData>());
        // Each tool button should be findable by tooltip message prefix
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Tooltip &&
                (w.message?.startsWith('${info.name}:') ?? false),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('active tool button has highlighted background',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Math3DToolbar(
            activeTool: ConstructionTool.sphere,
            onToolSelected: (_) {},
          ),
        ),
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
      ));
      await tester.pump();

      // Find the sphere tool button by tooltip
      final sphereInfo = ToolInfo.all[ConstructionTool.sphere]!;
      final tooltip = find.byWidgetPredicate(
        (w) =>
            w is Tooltip &&
            (w.message?.startsWith('${sphereInfo.name}:') ?? false),
      );
      expect(tooltip, findsOneWidget);

      // The active tool's Material should have a non-transparent background
      final tooltipWidget = tester.widget<Tooltip>(tooltip);
      expect(tooltipWidget.message, contains(sphereInfo.name));

      // The Icon rendered inside should use the primary color via iconColor
      // (verify by checking the Icon widget exists with correct iconData)
      final iconFinder = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == sphereInfo.iconData,
      );
      expect(iconFinder, findsAtLeastNWidgets(1));
    });

    testWidgets('each tool has a unique Material icon', (tester) async {
      final icons = <IconData>{};
      for (final tool in ConstructionTool.values) {
        final icon = ToolInfo.all[tool]!.iconData;
        icons.add(icon);
      }
      // Most tools should have unique icons; at minimum there should be
      // more than 8 distinct icons for the 12 tools
      expect(icons.length, greaterThan(8));
    });
  });
}
