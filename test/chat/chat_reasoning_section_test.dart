import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/chat_reasoning_section.dart';

void main() {
  group('ChatReasoningSection', () {
    testWidgets('renders reasoning text and toggle', (tester) async {
      const reasoningText = '分析用户意图...\n搜索相关文档...';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatReasoningSection(reasoningText: reasoningText),
          ),
        ),
      );

      // Initially, the reasoning text is collapsed
      expect(find.text('推理过程'), findsOneWidget);
      expect(find.text(reasoningText), findsNothing);

      // Tap to expand
      await tester.tap(find.text('推理过程'));
      await tester.pumpAndSettle();

      // Now the reasoning text should be visible
      expect(find.text(reasoningText), findsOneWidget);
    });

    testWidgets('toggle expands and collapses', (tester) async {
      const reasoningText = 'Step 1: ...\nStep 2: ...';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatReasoningSection(reasoningText: reasoningText),
          ),
        ),
      );

      // Expand
      await tester.tap(find.text('推理过程'));
      await tester.pumpAndSettle();
      expect(find.text(reasoningText), findsOneWidget);

      // Collapse  
      await tester.tap(find.text('推理过程'));
      await tester.pumpAndSettle();
      expect(find.text(reasoningText), findsNothing);
    });
  });
}
