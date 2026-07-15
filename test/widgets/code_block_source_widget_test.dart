import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/code_block_source_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CodeBlockSourceView - widget rendering', () {
    testWidgets('renders as a StatefulWidget', (tester) async {
      const widget = CodeBlockSourceView(code: 'print("hello")');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );
      expect(find.byType(CodeBlockSourceView), findsOneWidget);
    });

    testWidgets('shows raw code as text', (tester) async {
      const code = 'print("hello")';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(code: code),
          ),
        ),
      );

      // The raw code should be visible as text
      expect(find.text(code), findsOneWidget);
    });

    testWidgets('shows line numbers for multiline code', (tester) async {
      const code = 'line1\nline2\nline3';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(code: code),
          ),
        ),
      );

      // Should have line numbers 1, 2, 3
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows line number 1 for single line code', (tester) async {
      const code = 'single line';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(code: code),
          ),
        ),
      );

      expect(find.text(code), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('shows wrap toggle button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(code: 'some code'),
          ),
        ),
      );

      // Should show "换行显示" (wrap toggle) in the button row
      expect(find.text('换行显示'), findsOneWidget);
      expect(find.byIcon(Icons.wrap_text), findsOneWidget);
    });

    testWidgets('wrap toggle switches between wrap and no-wrap state',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(code: 'line1\nline2'),
          ),
        ),
      );

      // Initially shows '换行显示' (wrap off)
      expect(find.text('换行显示'), findsOneWidget);
      expect(find.text('取消换行'), findsNothing);

      // Tap the wrap toggle button
      await tester.tap(find.text('换行显示'));
      await tester.pumpAndSettle();

      // After tap, should show '取消换行' (wrap on)
      expect(find.text('取消换行'), findsOneWidget);
      expect(find.text('换行显示'), findsNothing);

      // Tap again to toggle back
      await tester.tap(find.text('取消换行'));
      await tester.pumpAndSettle();

      // Should be back to '换行显示'
      expect(find.text('换行显示'), findsOneWidget);
      expect(find.text('取消换行'), findsNothing);
    });

    testWidgets('shows (empty) for empty code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(code: ''),
          ),
        ),
      );

      expect(find.text('(empty)'), findsOneWidget);
      // No line numbers for empty code
      expect(find.text('1'), findsNothing);
    });

    testWidgets('handles additional action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(
              code: 'test',
              actionButtons: [
                TextButton(
                  onPressed: () {},
                  child: const Text('Custom Button'),
                ),
              ],
            ),
          ),
        ),
      );

      // The custom action button should be present
      expect(find.text('Custom Button'), findsOneWidget);
    });

    testWidgets('action buttons appear after wrap toggle button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(
              code: 'test',
              actionButtons: [
                TextButton(
                  onPressed: () {},
                  child: const Text('ExtraBtn'),
                ),
              ],
            ),
          ),
        ),
      );

      // Both the wrap toggle and the custom button should be visible
      expect(find.text('换行显示'), findsOneWidget);
      expect(find.text('ExtraBtn'), findsOneWidget);
    });

    testWidgets('adapts colors to dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          themeMode: ThemeMode.dark,
          darkTheme: ThemeData.dark(),
          home: Scaffold(
            body: CodeBlockSourceView(code: 'test code'),
          ),
        ),
      );

      // Widget should render without error in dark mode
      expect(find.byType(CodeBlockSourceView), findsOneWidget);
    });

    testWidgets('handles code with trailing newline', (tester) async {
      const code = 'line1\nline2\n';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockSourceView(code: code),
          ),
        ),
      );

      // Three lines: 'line1', 'line2', ''
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('CodeBlockSourceView - height behavior', () {
    testWidgets('respects explicit height property', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CodeBlockSourceView(
                code: 'short code',
                height: 200,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the SizedBox - should use 200
      final sizedBox = find.byType(SizedBox).first;
      final sizedBoxWidget = tester.widget<SizedBox>(sizedBox);

      expect(sizedBoxWidget.height, equals(200),
          reason: 'Explicit height should be respected');
    });
  });
}
