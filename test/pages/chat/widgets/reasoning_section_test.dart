import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/pages/chat/chat_types.dart';
import 'package:stroom/pages/chat/widgets/reasoning_section.dart';
import 'package:stroom/providers/chat_stream_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';

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

    testWidgets(
        'chevron animation starts when an existing button flips from '
        '"思考完成" to streaming "思考中"', (tester) async {
      // Regression for the dead chevron animation: only one static "›"
      // remained because _ReasoningButtonState started its timer only in
      // initState and didUpdateWidget only handled the true→false
      // transition — a button rendered as "思考完成" (isStreaming=false)
      // and then flipped to streaming never started the timer.
      Widget build({required bool streaming}) => ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ReasoningSection(
                  sections: ReasoningSectionData(
                    texts: ['推理内容'],
                    streaming: streaming,
                  ),
                  messageId: 'flip-msg-id',
                ),
              ),
            ),
          );

      // First render: sealed section ("思考完成", no chevrons).
      await tester.pumpWidget(build(streaming: false));
      expect(find.text('思考完成'), findsOneWidget);
      expect(find.text('›'), findsNothing);

      // The same button flips to streaming (didUpdateWidget path).
      await tester.pumpWidget(build(streaming: true));
      await tester.pump();
      expect(find.text('思考中'), findsOneWidget);
      expect(find.text('›'), findsOneWidget);

      // The chevron timer must have started: it advances every 333ms.
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('››'), findsOneWidget,
          reason: 'false→true 翻转后滚动动画应启动（而不是只剩单个 "›"）');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('›››'), findsOneWidget);

      // Unmount to dispose the periodic chevron timer.
      await tester.pumpWidget(const SizedBox.shrink());
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
      expect(find.text('思考完成'), findsNothing, reason: '多段落时按钮带序号前缀，不应出现无前缀的按钮');
    });
  });

  group('ReasoningPanel dialog scroll affordances', () {
    // Long enough to overflow the dialog content area so the view starts
    // (and stays) NOT at the bottom.
    final longText = List.generate(120, (i) => '推理内容第 $i 行').join('\n\n');

    Future<void> openDialog(
      WidgetTester tester, {
      required bool sectionStreaming,
      required bool streamActive,
      required bool hasFirstToken,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeConversationIdProvider.overrideWith((ref) => 'test-conv-id'),
            streamingReasoningSectionsProvider('test-conv-id')
                .overrideWith((ref) => [longText]),
            isStreamingProvider('test-conv-id')
                .overrideWith((ref) => streamActive),
            streamingHasFirstTokenProvider('test-conv-id')
                .overrideWith((ref) => hasFirstToken),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ReasoningSection(
                sections: ReasoningSectionData(
                  texts: [longText],
                  streaming: sectionStreaming,
                ),
                messageId: 'scroll-msg-id',
              ),
            ),
          ),
        ),
      );

      // Open the reasoning panel dialog.
      await tester.tap(find.text(sectionStreaming ? '思考中' : '思考完成'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      // Scroll a little (away from the top) so the scroll position is
      // deterministically NOT at the bottom, like a user who scrolled up.
      await tester.drag(
        find.descendant(
          of: find.byType(Scrollbar),
          matching: find.byType(SingleChildScrollView),
        ),
        const Offset(0, -150),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    Scrollbar scrollbarOf(WidgetTester tester) =>
        tester.widget<Scrollbar>(find.byType(Scrollbar));

    /// Unmounts the widget tree (disposing the dialog), then flushes the
    /// visibility_detector one-shot update timer scheduled by
    /// markdown_widget's internals during the last paint, so no timer
    /// stays pending at teardown.
    Future<void> unmountAndFlushTimers(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
    }

    testWidgets(
        'streaming: jump-to-bottom button shows when not at bottom and the '
        'scrollbar stays hidden', (tester) async {
      // Reasoning in progress: stream active, no first text token yet.
      await openDialog(
        tester,
        sectionStreaming: true,
        streamActive: true,
        hasFirstToken: false,
      );

      expect(find.byIcon(Icons.arrow_downward), findsOneWidget,
          reason: '流式期间未在底部时应显示到底部按钮');

      // The scrollbar must not be shown while streaming: no thumb, no
      // interaction, zero thickness (nothing paints).
      final scrollbar = scrollbarOf(tester);
      expect(scrollbar.thumbVisibility, isFalse,
          reason: '流式期间滚动条 thumb 不应显示');
      expect(scrollbar.interactive, isFalse,
          reason: '流式期间滚动条不应可拖动');
      expect(scrollbar.thickness, 0,
          reason: '流式期间滚动条应零厚度（完全不可见）');

      // Unmount to dispose the streaming chevron timer.
      await unmountAndFlushTimers(tester);
    });

    testWidgets(
        'completed: no jump-to-bottom button even when not at bottom; '
        'draggable scrollbar takes over', (tester) async {
      // Thinking completed but the overall stream is still active (the
      // first text token has arrived): the button must disappear and the
      // draggable scrollbar must take over.
      await openDialog(
        tester,
        sectionStreaming: false,
        streamActive: true,
        hasFirstToken: true,
      );

      expect(find.byIcon(Icons.arrow_downward), findsNothing,
          reason: '思考完成后即使未在底部也不应显示到底部按钮');

      final scrollbar = scrollbarOf(tester);
      expect(scrollbar.thumbVisibility, isTrue,
          reason: '思考完成后滚动条 thumb 应常驻显示');
      expect(scrollbar.interactive, isTrue,
          reason: '思考完成后滚动条应可拖动');
      expect(scrollbar.thickness, isNot(0),
          reason: '思考完成后滚动条应恢复实际厚度');

      await unmountAndFlushTimers(tester);
    });

    testWidgets(
        'button disappears reactively the moment the thinking completes',
        (tester) async {
      await openDialog(
        tester,
        sectionStreaming: true,
        streamActive: true,
        hasFirstToken: false,
      );
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

      // Reasoning completes mid-session (first text token arrives while
      // the dialog is open): the button must vanish immediately.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ReasoningSection)),
      );
      container
          .read(streamingHasFirstTokenProvider('test-conv-id').notifier)
          .state = true;
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.arrow_downward), findsNothing,
          reason: '思考完成的瞬间到底部按钮应立即消失');
      expect(scrollbarOf(tester).thumbVisibility, isTrue,
          reason: '思考完成的瞬间滚动条应随即接管');

      // Unmount to dispose the streaming chevron timer / animations.
      await unmountAndFlushTimers(tester);
    });
  });
}
