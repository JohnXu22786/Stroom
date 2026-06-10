import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/widgets/reasoning_section.dart';

void main() {
  group('ReasoningSection', () {
    testWidgets('renders collapsed by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReasoningSection(reasoningText: 'Test reasoning'),
          ),
        ),
      );

      // Should show title but not the reasoning text
      expect(find.text('推理过程'), findsOneWidget);
      // Collapsed so reasoning text should NOT be visible
      expect(find.text('Test reasoning'), findsNothing);
    });

    testWidgets('expands to show reasoning text on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReasoningSection(reasoningText: 'Test reasoning'),
          ),
        ),
      );

      // Tap to expand
      await tester.tap(find.text('推理过程'));
      await tester.pumpAndSettle();

      expect(find.text('Test reasoning'), findsOneWidget);
    });

    testWidgets('toggles between expanded and collapsed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReasoningSection(reasoningText: 'Toggle test'),
          ),
        ),
      );

      // Expand
      await tester.tap(find.text('推理过程'));
      await tester.pumpAndSettle();
      expect(find.text('Toggle test'), findsOneWidget);

      // Collapse
      await tester.tap(find.text('推理过程'));
      await tester.pumpAndSettle();
      expect(find.text('Toggle test'), findsNothing);
    });
  });
}
