// Regression test for: "model thinks then calls a tool directly (no text
// output first) — a pile of '思考完成' buttons stacks up and the tool call
// is not displayed until the first text token arrives".
//
// Root cause: while the streaming message is still a TextStreamMessage
// (before the first TextEvent converts it to a text message),
// _buildTextStreamMessage rendered ONLY the full reasoning-sections list as
// a group of buttons — including the empty '' placeholders appended by
// each ReasoningSectionEndEvent — and never rendered the live segments
// (which carry the tool call cards).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' hide ChatMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/message_block.dart';
import 'package:stroom/models/tool_call.dart'
    show ToolCallData, ToolCallStatus, ToolDefinition;
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/chat_stream_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/chat_manager_provider.dart';
import 'package:stroom/services/chat_stream_manager.dart'
    show ChatStreamManager, StreamResult;
import 'package:stroom/widgets/llm/tool_call_card.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// A [ChatStreamManager] whose [startStreaming] never completes: the
/// streaming placeholder message stays in textStream state forever, so the
/// test can drive the segment providers manually and inspect the
/// textStream-phase rendering (the exact phase where the bug occurred).
class _HangingStreamManager extends ChatStreamManager {
  _HangingStreamManager() : super(null);

  @override
  Future<StreamResult> startStreaming({
    required String text,
    required String convId,
    required List<ChatMessage> history,
    List<ToolDefinition> tools = const [],
    bool reasoning = false,
    String reasoningEffort = 'medium',
    Map<String, String> reasoningParamValues = const {},
    String? streamingMsgId,
  }) {
    return Completer<StreamResult>().future;
  }
}

Widget _buildTestApp(_HangingStreamManager manager) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      chatStreamManagerProvider.overrideWith((ref) => manager),
      conversationsProvider.overrideWith((ref) => ConversationsNotifier(ref)),
      activeConversationIdProvider.overrideWith((ref) => 'test-conv'),
      providerEntriesProvider.overrideWith((ref) => ProviderEntriesNotifier()),
    ],
    child: const MaterialApp(home: ChatPage()),
  );
}

/// Enters text into the composer and taps the (enabled) send button.
Future<void> _sendMessage(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  final sendButtons = tester
      .widgetList<IconButton>(
        find.widgetWithIcon(IconButton, Icons.send_rounded),
      )
      .where((b) => b.onPressed != null)
      .toList();
  expect(sendButtons, isNotEmpty, reason: '发送按钮应在输入文本后可用');
  await tester.tap(find.byWidget(sendButtons.first));
  await tester.pump();
  // Let _onMessageSend insert the user message and the textStream
  // placeholder (async controller insertions).
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Flushes flutter_chat_ui's internal one-shot timers (insert-animation
/// delay, scroll-to-bottom show/hide delays) so test teardown does not
/// fail with "A Timer is still pending".
Future<void> _flushPendingTimers(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  setUp(() {
    // Disable visibility_detector's 500ms debounce timer in tests,
    // otherwise it leaves a pending timer that fails test teardown.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() {
    VisibilityDetectorController.instance.updateInterval =
        const Duration(milliseconds: 500);
  });

  group('textStream phase: think → tool call without text', () {
    testWidgets(
        'shows the tool call card and a single reasoning button (no '
        'phantom "思考完成" pile, no hidden tool call)', (tester) async {
      final manager = _HangingStreamManager();
      await tester.pumpWidget(_buildTestApp(manager));
      // Wait for _initialize → _loadConversationMessages to complete.
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await _sendMessage(tester, '查一下天气');

      // Precondition: the streaming placeholder is still a
      // TextStreamMessage — i.e. no text token has arrived yet. This is
      // exactly the phase that used to hide tool calls.
      final chat = tester.widget<Chat>(find.byType(Chat));
      final placeholder =
          chat.chatController.messages.whereType<TextStreamMessage>().toList();
      expect(placeholder, hasLength(1), reason: '发送后应有一个 textStream 占位消息');

      // Simulate the provider state after: think → ReasoningSectionEnd →
      // ToolCallStart (no text events at all).
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChatPage)),
      );
      container
          .read(streamingReasoningSectionsProvider('test-conv').notifier)
          .state = ['模型思考内容', ''];
      container
          .read(streamingTextSectionsProvider('test-conv').notifier)
          .state = ['', ''];
      container
          .read(streamingToolCallRoundStartsProvider('test-conv').notifier)
          .state = [0];
      container.read(streamingToolCallsProvider('test-conv').notifier).state = [
        ToolCallData(
          id: 'tc-1',
          name: 'web_search',
          arguments: const {'query': '天气'},
          status: ToolCallStatus.running,
        ),
      ];
      await tester.pump();

      // The tool call card must be visible DURING the textStream phase,
      // not only after the first text token converts the message type.
      expect(find.byType(ToolCallCard), findsOneWidget,
          reason: 'textStream 阶段也应显示工具调用卡片');

      // Exactly ONE reasoning button for the real section — the trailing
      // '' placeholder must not add a phantom "思考完成" button.
      expect(find.text('思考完成'), findsOneWidget,
          reason: '空占位段落不应叠加出多余的"思考完成"按钮');
      expect(find.textContaining('思考 2'), findsNothing);
      expect(find.text('思考中'), findsNothing);

      await _flushPendingTimers(tester);
    });

    testWidgets(
        'first reasoning section shows "思考中" immediately — no stale '
        '"思考完成" flash at stream start', (tester) async {
      // Regression for: "对话页面还没开始思考就先显示思考完成大约1秒，然后才
      // 恢复思考中状态" and the dead chevron animation.
      //
      // Root cause: ChatStreamManager.startStreaming → _pushStateToProviders
      // re-pushes streamingTextSectionsProvider as a fresh [''], whose
      // listener marks reasoning as completed for the new message id. When
      // the first reasoning push then arrives, the reasoningSections
      // listener rebuilt the live segments BEFORE resetting that flag, so
      // the button rendered "思考完成" until the next (throttled) push —
      // and the button created in the sealed state never started its
      // chevron timer, leaving a single static "›".
      final manager = _HangingStreamManager();
      await tester.pumpWidget(_buildTestApp(manager));
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await _sendMessage(tester, '请思考这个问题');

      // Simulate the stream-start provider push: textSections re-pushed as
      // a fresh [''] list (the page's listener marks reasoning completed).
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChatPage)),
      );
      container
          .read(streamingTextSectionsProvider('test-conv').notifier)
          .state = [''];
      await tester.pump();

      // The first reasoning content arrives (throttled push). The button
      // must render as "思考中" right away, never "思考完成".
      container
          .read(streamingReasoningSectionsProvider('test-conv').notifier)
          .state = ['模型思考内容'];
      await tester.pump();

      expect(find.text('思考中'), findsOneWidget,
          reason: '首个推理段落应立即显示"思考中"，而不是闪烁"思考完成"');
      expect(find.text('思考完成'), findsNothing,
          reason: '推理仍在进行时不应显示"思考完成"');

      // The chevron animation must actually run: › → ›› → ›››.
      expect(find.text('›'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('››'), findsOneWidget,
          reason: '333ms 后滚动动画应推进到两个 "›"');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('›››'), findsOneWidget,
          reason: '666ms 后滚动动画应推进到三个 "›"');

      // Unmount to dispose the periodic chevron timer, then flush pending
      // one-shot timers (visibility_detector, chat UI internals).
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets(
        'a round-end placeholder append keeps the sealed section at '
        '"思考完成"', (tester) async {
      // Regression for the counterpart of the flash bug: the
      // reasoningSections flag reset must be scoped to content updates.
      // A ReasoningSectionEndEvent appends a trailing '' placeholder —
      // the round ENDED, so the sealed section must keep "思考完成".
      // Resetting the flag here would flip it to "思考中" (with running
      // chevrons) until the next round's first reasoning push.
      final manager = _HangingStreamManager();
      await tester.pumpWidget(_buildTestApp(manager));
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await _sendMessage(tester, '分两步完成');

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChatPage)),
      );

      // Round 1 text has flowed → the textSections listener marked the
      // reasoning as completed for this message.
      container
          .read(streamingTextSectionsProvider('test-conv').notifier)
          .state = ['第一轮回答'];
      await tester.pump();

      // Round 1's reasoning section ends (ReasoningSectionEndEvent appends
      // the '' placeholder for the next round). The sealed button must stay
      // "思考完成" — it must not flip to "思考中".
      container
          .read(streamingReasoningSectionsProvider('test-conv').notifier)
          .state = ['模型思考内容', ''];
      await tester.pump();

      expect(find.text('思考完成'), findsOneWidget,
          reason: '已结束的推理段落应保持"思考完成"');
      expect(find.text('思考中'), findsNothing,
          reason: '推理段已结束（占位追加）时不应翻转回"思考中"');

      await _flushPendingTimers(tester);
    });

    testWidgets(
        'two tool rounds each render their tool card and reasoning button',
        (tester) async {
      final manager = _HangingStreamManager();
      await tester.pumpWidget(_buildTestApp(manager));
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await _sendMessage(tester, '先搜索再读文件');

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChatPage)),
      );
      // Round 1: think → tool1; Round 2: think → tool2; third section is
      // the empty placeholder for a round that has not started yet.
      container
          .read(streamingReasoningSectionsProvider('test-conv').notifier)
          .state = ['第一轮思考', '第二轮思考', ''];
      container
          .read(streamingTextSectionsProvider('test-conv').notifier)
          .state = ['', '', ''];
      container
          .read(streamingToolCallRoundStartsProvider('test-conv').notifier)
          .state = [0, 1];
      container.read(streamingToolCallsProvider('test-conv').notifier).state = [
        ToolCallData(
          id: 'tc-1',
          name: 'web_search',
          arguments: const {'query': '天气'},
          status: ToolCallStatus.running,
        ),
        ToolCallData(
          id: 'tc-2',
          name: 'read_file',
          arguments: const {'path': '/tmp/a.txt'},
          status: ToolCallStatus.running,
        ),
      ];
      await tester.pump();

      // Both tool calls visible, both real reasoning sections get a
      // button (inline segments render single-section buttons without
      // the numbered prefix), no phantom third button.
      expect(find.byType(ToolCallCard), findsNWidgets(2));
      expect(find.text('思考完成'), findsNWidgets(2),
          reason: '两个真实推理段落各一个按钮，空占位不渲染');
      expect(find.textContaining('思考 3'), findsNothing);

      await _flushPendingTimers(tester);
    });
  });

  group('reload of roundStarts-era messages repairs misaligned blocks', () {
    testWidgets(
        'interior-empty reasoning sections render their buttons after '
        'reload', (tester) async {
      // A message persisted BEFORE the empty-section fix: its blocks were
      // built by the empty-skipping legacyToBlocks, so their ordinal
      // ReasoningSegment indices misalign with the raw reasoningSections
      // indices (think3 sits at raw index 2 but block-ordinal 1). The
      // load path must rebuild such blocks so think3's button survives.
      final staleMsg = ChatMessage(
        id: 'a1',
        role: 'assistant',
        content: 'final answer',
        reasoningSections: ['think1', '', 'think3', ''],
        textSections: ['', '', '', 'final answer'],
        toolCalls: [
          ToolCallData(
            id: '1',
            name: 'A',
            arguments: const {},
            status: ToolCallStatus.completed,
            result: 'r1',
          ),
          ToolCallData(
            id: '2',
            name: 'B',
            arguments: const {},
            status: ToolCallStatus.completed,
            result: 'r2',
          ),
          ToolCallData(
            id: '3',
            name: 'C',
            arguments: const {},
            status: ToolCallStatus.completed,
            result: 'r3',
          ),
        ],
        toolCallRoundStarts: [0, 1, 2],
        blocks: [
          ReasoningBlock(text: 'think1', isComplete: true),
          ToolCallBlock(
            id: '1',
            name: 'A',
            status: ToolCallStatus.completed,
            result: 'r1',
          ),
          ToolCallBlock(
            id: '2',
            name: 'B',
            status: ToolCallStatus.completed,
            result: 'r2',
          ),
          ReasoningBlock(text: 'think3', isComplete: true),
          ToolCallBlock(
            id: '3',
            name: 'C',
            status: ToolCallStatus.completed,
            result: 'r3',
          ),
          TextBlock(text: 'final answer'),
        ],
      );

      SharedPreferences.setMockInitialValues({});
      final conversation = Conversation(
        id: 'test-conv',
        title: 'Test Conversation',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        messages: [
          ChatMessage(
            id: 'u1',
            role: 'user',
            content: 'hello',
            createdAt: DateTime(2025, 1, 1),
          ),
          staleMsg,
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationsProvider.overrideWith((ref) {
              final notifier = ConversationsNotifier(ref);
              notifier.state = [conversation];
              return notifier;
            }),
            activeConversationIdProvider.overrideWith((ref) => 'test-conv'),
            providerEntriesProvider
                .overrideWith((ref) => ProviderEntriesNotifier()),
          ],
          child: const MaterialApp(home: ChatPage()),
        ),
      );
      // Let _initialize + _loadConversationMessages (and the initial
      // scroll positioning pass) complete.
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // BOTH real reasoning sections render their button after reload —
      // with the stale (misaligned) blocks trusted, think3's button
      // would be missing entirely.
      expect(find.text('思考完成'), findsNWidgets(2),
          reason: 'think1 与 think3 的按钮都应在重载后渲染（旧 blocks 需重建）');
      expect(find.byType(ToolCallCard), findsNWidgets(3));
      expect(find.textContaining('思考 2'), findsNothing,
          reason: '空占位段不应产生带序号的按钮');

      await _flushPendingTimers(tester);
    });
  });
}
