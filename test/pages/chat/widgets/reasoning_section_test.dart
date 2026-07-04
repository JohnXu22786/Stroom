import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/pages/chat/widgets/reasoning_section.dart';
import 'package:stroom/providers/chat_stream_provider.dart';

void main() {
  group('ReasoningSection (Single section)', () {
    testWidgets('shows reasoning button with label when content exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            streamingReasoningSectionsProvider.overrideWith(
              (ref) => ['Test reasoning content'],
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ReasoningSection(
                sections: ReasoningSectionData(
                  texts: ['Test reasoning content'],
                  streaming: false,
                ),
                messageId: 'test-msg-id',
              ),
            ),
          ),
        ),
      );

      // Should show the button with icon and "推理过程" label
      expect(find.text('推理过程'), findsOneWidget);
      // Should show the psychology icon
      expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
      // The content should NOT be visible inline (it's a panel now)
      expect(find.text('Test reasoning content'), findsNothing);
    });

    testWidgets('shows reasoning in progress label when streaming',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            streamingReasoningSectionsProvider.overrideWith(
              (ref) => ['Streaming reasoning...'],
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ReasoningSection(
                sections: ReasoningSectionData(
                  texts: ['Streaming reasoning...'],
                  streaming: true,
                ),
                messageId: 'test-msg-id',
              ),
            ),
          ),
        ),
      );

      // Should show "推理中" label when streaming
      expect(find.text('推理中'), findsOneWidget);
    });

    testWidgets('button appears when reasoning content exists during streaming',
        (tester) async {
      // This tests that the button renders correctly when
      // reasoning content has been received (even if only partially)
      // during active streaming. Regression test for the issue where
      // the button was not displayed during reasoning streaming.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            streamingReasoningSectionsProvider.overrideWith(
              (ref) => ['Partial reasoning text...'],
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ReasoningSection(
                sections: ReasoningSectionData(
                  texts: ['Partial reasoning text...'],
                  streaming: true,
                ),
                messageId: 'stream-msg-id',
              ),
            ),
          ),
        ),
      );

      // The button must be visible during streaming
      expect(find.text('推理中'), findsOneWidget);
      expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
    });
  });

  group('ReasoningSection (Multiple sections)', () {
    testWidgets('shows multiple reasoning buttons for multi-step reasoning', (
      tester,
    ) async {
      // Two reasoning sections: first complete, second streaming
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            streamingReasoningSectionsProvider.overrideWith(
              (ref) => ['第一步推理内容...', '第二步推理内容...'],
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ReasoningSection(
                sections: ReasoningSectionData(
                  texts: ['第一步推理内容...', '第二步推理内容...'],
                  streaming: true,
                ),
                messageId: 'multi-msg-id',
              ),
            ),
          ),
        ),
      );

      // Should show one "推理过程" for the first section and one "推理中" for the last
      expect(find.text('推理过程'), findsOneWidget, reason: '第一个已完成的推理应显示"推理过程"');
      expect(find.text('推理中'), findsOneWidget, reason: '第二个正在进行的推理应显示"推理中"');
    });

    testWidgets('multiple reasoning buttons with index labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            streamingReasoningSectionsProvider.overrideWith(
              (ref) => ['第一轮推理', '第二轮推理'],
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ReasoningSection(
                sections: ReasoningSectionData(
                  texts: ['第一轮推理', '第二轮推理'],
                  streaming: false,
                ),
                messageId: 'multi-msg-id',
              ),
            ),
          ),
        ),
      );

      // Should show "推理 1 推理过程" and "推理 2 推理过程"
      expect(find.text('推理 1'), findsOneWidget, reason: '多推理时应显示序号');
      expect(find.text('推理 2'), findsOneWidget, reason: '多推理时应显示序号');
    });

    testWidgets('tapping reasoning button opens a dialog', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            streamingReasoningSectionsProvider.overrideWith(
              (ref) => ['推理内容'],
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ReasoningSection(
                sections: ReasoningSectionData(
                  texts: ['推理内容'],
                  streaming: false,
                ),
                messageId: 'test-msg-id',
              ),
            ),
          ),
        ),
      );

      // Tap the reasoning button
      await tester.tap(find.text('推理过程'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Dialog should be shown
      expect(find.byType(Dialog), findsOneWidget, reason: '点击推理按钮应弹出对话框');

      // Dismiss the dialog via the close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      // Verify dialog is dismissed
      expect(find.byType(Dialog), findsNothing,
          reason: '点击关闭按钮后对话框应关闭');
      // Pump additional frames to clear pending timers
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testWidgets('dialog shows reasoning content for completed messages', (
      tester,
    ) async {
      const reasoningText = '这是完整的推理过程内容';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            streamingReasoningSectionsProvider.overrideWith(
              (ref) => [reasoningText],
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ReasoningSection(
                sections: ReasoningSectionData(
                  texts: [reasoningText],
                  streaming: false,
                ),
                messageId: 'test-msg-id',
              ),
            ),
          ),
        ),
      );

      // Tap the reasoning button
      await tester.tap(find.text('推理过程'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Dialog should be shown with reasoning content
      expect(find.byType(Dialog), findsOneWidget);
      // Both the button AND the dialog header show "推理过程", so at least one
      expect(find.text('推理过程'), findsWidgets);
      expect(find.text(reasoningText), findsOneWidget);

      // Dismiss the dialog via the close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      // Verify dialog is dismissed
      expect(find.byType(Dialog), findsNothing,
          reason: '点击关闭按钮后对话框应关闭');
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testWidgets('empty sections list should render nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ReasoningSection(
                sections: ReasoningSectionData(
                  texts: [],
                  streaming: false,
                ),
                messageId: 'empty-msg-id',
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Empty sections should render nothing
      expect(find.byIcon(Icons.psychology_outlined), findsNothing);
      expect(find.text('推理过程'), findsNothing);
    });
  });
}
