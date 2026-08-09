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
            streamingReasoningSectionsProvider('test-conv-id').overrideWith(
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

      // Should show the "思考完成" label without any trailing chevrons
      // (chevrons are only shown during active streaming)
      expect(find.text('思考完成'), findsOneWidget);
      expect(find.text('›'), findsNothing);
      // The content should NOT be visible inline (it's a panel now)
      expect(find.text('Test reasoning content'), findsNothing);
    });

    testWidgets('shows reasoning in progress label when streaming',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            streamingReasoningSectionsProvider('test-conv-id').overrideWith(
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

      // Should show "思考中" label when streaming
      expect(find.text('思考中'), findsOneWidget);
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
            streamingReasoningSectionsProvider('test-conv-id').overrideWith(
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

      // The label must be visible during streaming
      expect(find.text('思考中'), findsOneWidget);
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
            streamingReasoningSectionsProvider('test-conv-id').overrideWith(
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

      // Should show "思考 1 思考完成" for the first section (completed)
      // and "思考 2 思考中" for the second section (still streaming)
      expect(find.text('思考 1 思考完成'), findsOneWidget,
          reason: '第一个已完成的推理应显示"思考 1 思考完成"');
      expect(find.text('思考 2 思考中'), findsOneWidget,
          reason: '第二个正在进行的推理应显示"思考 2 思考中"');
    });

    testWidgets('multiple reasoning buttons with index labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            streamingReasoningSectionsProvider('test-conv-id').overrideWith(
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

      // Should show "思考 1 思考完成" and "思考 2 思考完成"
      expect(find.text('思考 1 思考完成'), findsOneWidget, reason: '多推理时应显示序号');
      expect(find.text('思考 2 思考完成'), findsOneWidget, reason: '多推理时应显示序号');
    });

    testWidgets('tapping reasoning button opens a dialog', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            streamingReasoningSectionsProvider('test-conv-id').overrideWith(
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

      // Tap the reasoning text line
      await tester.tap(find.text('思考完成'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Dialog should be shown
      expect(find.byType(Dialog), findsOneWidget, reason: '点击推理按钮应弹出对话框');

      // Dismiss the dialog via the close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      // Verify dialog is dismissed
      expect(find.byType(Dialog), findsNothing, reason: '点击关闭按钮后对话框应关闭');
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
            streamingReasoningSectionsProvider('test-conv-id').overrideWith(
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

      // Tap the reasoning text line
      await tester.tap(find.text('思考完成'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Dialog should be shown with reasoning content
      expect(find.byType(Dialog), findsOneWidget);
      // Both the button AND the dialog header show "思考完成", so at least one
      expect(find.text('思考完成'), findsWidgets);
      expect(find.text(reasoningText), findsOneWidget);

      // Dismiss the dialog via the close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      // Verify dialog is dismissed
      expect(find.byType(Dialog), findsNothing, reason: '点击关闭按钮后对话框应关闭');
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
      expect(find.text('思考完成'), findsNothing);
    });

    testWidgets(
        'trailing empty placeholder section does not render a phantom button',
        (tester) async {
      // ReasoningSectionEndEvent appends an empty '' placeholder for the
      // NEXT reasoning round. While the model is calling tools without any
      // visible text (think → tool call directly), the textStream fallback
      // passes ALL sections — including the empty placeholder — to the
      // ReasoningSection. Regression: each tool round must NOT add a
      // phantom "思考完成" button for its empty placeholder.
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ReasoningSection(
                sections: ReasoningSectionData(
                  texts: ['第一轮推理', ''],
                  streaming: false,
                ),
                messageId: 'placeholder-msg-id',
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Only ONE button for the real section — the empty placeholder must
      // be skipped entirely (no phantom "思考 2 思考完成" button).
      expect(find.text('思考完成'), findsOneWidget,
          reason: '空占位段落不应渲染出多余的"思考完成"按钮');
      expect(find.textContaining('思考 2'), findsNothing,
          reason: '空占位段落不应产生带序号的按钮');
    });

    testWidgets(
        'trailing empty placeholder with streaming=true keeps the sealed '
        'section at "思考完成"', (tester) async {
      // While the model is calling tools (think → tool, no text), the
      // reasoningSections carry the '' placeholder for the next round.
      // If the stream is still "active" the streaming flag is true, but
      // the section actually being streamed is the invisible placeholder
      // — the last sealed section must keep showing "思考完成", not flip
      // to "思考中".
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ReasoningSection(
                sections: ReasoningSectionData(
                  texts: ['第一轮推理', ''],
                  streaming: true,
                ),
                messageId: 'streaming-placeholder-msg-id',
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('思考完成'), findsOneWidget,
          reason: '已结束的段落不应因空占位段而显示"思考中"');
      expect(find.text('思考中'), findsNothing);
    });

    testWidgets(
        'multiple real sections with a trailing empty placeholder render '
        'exactly the real buttons', (tester) async {
      // Two completed reasoning rounds + the '' placeholder for the next
      // (not yet started) round: only the two real sections get buttons.
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ReasoningSection(
                sections: ReasoningSectionData(
                  texts: ['第一轮推理', '第二轮推理', ''],
                  streaming: false,
                ),
                messageId: 'multi-placeholder-msg-id',
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Both real sections render, the empty placeholder is skipped.
      expect(find.text('思考 1 思考完成'), findsOneWidget);
      expect(find.text('思考 2 思考完成'), findsOneWidget);
      expect(find.textContaining('思考 3'), findsNothing,
          reason: '空占位段落不应渲染出第三个按钮');
      expect(find.text('思考完成'), findsNothing,
          reason: '多段落时按钮带序号前缀，不应出现无前缀的按钮');
    });
  });
}
