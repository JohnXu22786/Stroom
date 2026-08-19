// Regression test for: "编辑消息重发或者消息重新生成以后，工具折叠的那一个
// card 也不会跟着消失掉" — after editing a message and resending, or after
// regenerating (retrying) an assistant reply, the OLD message's collapsed
// tool call card must disappear together with the old message.
//
// Root cause: a STOPPED partial reply stays in the chat controller and its
// segment cache, but — when the stop hits a hanging tool call whose
// cancellation is not honored (so the manager's finalize never persists the
// partial) — it never enters _history. The edit/retry truncation only
// removed messages found in _history, so the stopped reply — and its
// collapsed tool card — survived the edit/regenerate as a ghost card.
// (With a normally-finalized stop the partial IS persisted and synced into
// _history, so the truncation removes it — no ghost; the ghost is the
// aborted-finalize path modeled here.)
//
// The fix: truncation also sweeps controller messages that are not part of
// the truncated _history, and deleting such an orphan message works too.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/message_block.dart';
import 'package:stroom/models/tool_call.dart'
    show ToolCallData, ToolCallStatus, ToolDefinition;
import 'package:stroom/pages/chat/chat_types.dart' show isStreamingProvider;
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/chat_manager_provider.dart';
import 'package:stroom/providers/chat_stream_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_stream_manager.dart'
    show ChatStreamManager, StreamResult;
import 'package:stroom/widgets/llm/tool_call_card.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// A [ChatStreamManager] that mimics the REAL streaming sequence: pushes the
/// initial provider state synchronously, then blocks until the test completes
/// its [finish] with a [StreamResult] — exactly like a real stream that runs
/// for a while. Supports multiple sequential streams (each call gets a fresh
/// completer, so retry/regenerate works).
class _LiveStreamManager extends ChatStreamManager {
  Ref? ref;
  final List<Completer<StreamResult>> _completers = [];

  void attachRef(Ref ref) => this.ref = ref;

  /// The streaming message id of the most recent stream.
  String? lastStreamingMsgId;

  /// Full reply reported by [fullReplyFor] — the stopped-stream path reads
  /// this to decide whether to keep the partial message in the controller.
  String partialReply = '';

  @override
  String fullReplyFor(String convId) => partialReply;

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
    Assistant? assistant,
  }) async {
    lastStreamingMsgId = streamingMsgId;
    // Mimic the real manager's synchronous start pushes.
    ref!.read(streamingConversationsProvider.notifier).state = {
      ...ref!.read(streamingConversationsProvider),
      convId,
    };
    ref!.read(isStreamingProvider(convId).notifier).state = true;
    ref!.read(streamingMsgIdProvider(convId).notifier).state = streamingMsgId;
    ref!.read(streamingReasoningSectionsProvider(convId).notifier).state = [];
    ref!.read(streamingTextSectionsProvider(convId).notifier).state = [''];
    ref!.read(streamingToolCallsProvider(convId).notifier).state = [];
    ref!.read(streamingToolCallRoundStartsProvider(convId).notifier).state = [];
    final completer = Completer<StreamResult>();
    _completers.add(completer);
    return completer.future;
  }

  /// Completes the currently pending stream: removes the conversation from
  /// the streaming set (like [_completeStream]) and completes the future.
  ///
  /// NOTE on the model: the real manager's `_completeStream` PERSISTS the
  /// stopped partial into the conversations provider before completing. When
  /// that happens the page's post-stop sync pulls the partial into _history
  /// and the edit/retry truncation removes it normally — no ghost. The ghost
  /// occurs on the ABORTED-finalize path: a stop while a tool call is still
  /// hanging (cancellation not honored promptly, or the finalize never
  /// lands) leaves the partial only in the controller + segment cache,
  /// never in _history. The STOP tests therefore do NOT persist the partial
  /// — they model exactly that abort path (the fake's future completes
  /// without a provider write).
  Future<void> finish(String convId, StreamResult result) async {
    ref!.read(streamingConversationsProvider.notifier).state = {
      ...ref!.read(streamingConversationsProvider),
    }..remove(convId);
    _completers.last.complete(result);
  }
}

/// A [ChatStreamManager] whose [startStreaming] completes immediately with a
/// reply that itself contains a COMPLETED tool call card (a different tool
/// than the old reply, so old/new cards are distinguishable), persisting the
/// new history to the conversations provider — the same observable end state
/// as a real regenerate that ran a tool.
class _ImmediateStreamManager extends ChatStreamManager {
  /// Attached by the provider override below so the fake can persist the
  /// new history to the conversations provider (like the real manager).
  Ref? ref;

  void attachRef(Ref ref) => this.ref = ref;

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
    Assistant? assistant,
  }) async {
    final assistantMsg = ChatMessage(
      id: streamingMsgId ?? 'a-new',
      role: 'assistant',
      content: '重新生成的回答',
      createdAt: DateTime.now(),
      textSections: ['重新生成的回答'],
      toolCalls: [
        ToolCallData(
          id: 'tc-new',
          name: 'read_file',
          arguments: const {'path': '/tmp/a.txt'},
          status: ToolCallStatus.completed,
          result: '文件内容',
        ),
      ],
      toolCallRoundStarts: const [0],
    );
    final newHistory = [...history, assistantMsg];
    await ref!
        .read(conversationsProvider.notifier)
        .updateMessages(convId, newHistory);
    return StreamResult(
      history: newHistory,
      assistantMessage: assistantMsg,
      fullReply: '重新生成的回答',
      textSections: ['重新生成的回答'],
      toolCalls: List<ToolCallData>.from(assistantMsg.toolCalls!),
      toolCallRoundStarts: const [0],
      blocks: [
        ToolCallBlock(
          id: 'tc-new',
          name: 'read_file',
          status: ToolCallStatus.completed,
          result: '文件内容',
        ),
        TextBlock(text: '重新生成的回答'),
      ],
    );
  }
}

/// Seeds a conversation whose assistant reply contains a COMPLETED
/// (collapsed) tool call card.
ChatMessage _assistantWithToolCard() {
  return ChatMessage(
    id: 'a1',
    role: 'assistant',
    content: '查到了',
    createdAt: DateTime(2025, 1, 1, 0, 1),
    reasoningSections: const [],
    textSections: ['查到了'],
    toolCalls: [
      ToolCallData(
        id: 'tc-1',
        name: 'web_search',
        arguments: const {'query': '天气'},
        status: ToolCallStatus.completed,
        result: '搜索结果',
      ),
    ],
    toolCallRoundStarts: const [0],
  );
}

Widget _buildTestApp(_ImmediateStreamManager manager) {
  SharedPreferences.setMockInitialValues({});
  final conversation = Conversation(
    id: 'test-conv',
    title: 'Test',
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
    messages: [
      ChatMessage(
        id: 'u1',
        role: 'user',
        content: '查一下天气',
        createdAt: DateTime(2025, 1, 1),
      ),
      _assistantWithToolCard(),
    ],
  );
  return ProviderScope(
    overrides: [
      chatStreamManagerProvider.overrideWith((ref) {
        manager.attachRef(ref);
        return manager;
      }),
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        notifier.state = [conversation];
        return notifier;
      }),
      activeConversationIdProvider.overrideWith((ref) => 'test-conv'),
      providerEntriesProvider.overrideWith((ref) => ProviderEntriesNotifier()),
    ],
    child: const MaterialApp(home: ChatPage()),
  );
}

/// Pumps until the initial message load has finished and the collapsed tool
/// card is on screen.
Future<void> _pumpLoaded(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 2000));
  for (int i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Flushes one-shot timers (insert/remove animations, visibility detector,
/// scroll-to-bottom delays) so teardown does not fail on pending timers.
Future<void> _flushTimers(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() {
    VisibilityDetectorController.instance.updateInterval =
        const Duration(milliseconds: 500);
  });

  testWidgets(
      'regenerating an assistant reply removes its collapsed tool call card',
      (tester) async {
    final manager = _ImmediateStreamManager();
    await tester.pumpWidget(_buildTestApp(manager));
    await _pumpLoaded(tester);

    // Precondition: the old reply's collapsed card is visible.
    expect(find.byType(ToolCallCard), findsOneWidget, reason: '重试前应显示旧的工具调用卡片');
    expect(find.text('web_search'), findsOneWidget);
    // Collapsed: details hidden.
    expect(find.text('query: 天气'), findsNothing);

    // Tap the retry (refresh) button of the AI message and confirm.
    final retryButton = find.byIcon(Icons.refresh);
    expect(retryButton, findsOneWidget);
    await tester.tap(retryButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('确定要重新生成回复吗？'), findsOneWidget, reason: '应弹出重试确认对话框');
    await tester.tap(find.text('确定'));
    // Let the retry flow run: truncation, removal animation, immediate
    // stream completion, final segment build, provider sync.
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The OLD collapsed tool card must be gone — the whole old message was
    // deleted as part of the regenerate. Only the NEW reply's card (a
    // different tool) may remain.
    expect(find.text('web_search'), findsNothing,
        reason: '重新生成后，旧消息的折叠工具卡片应随旧消息一起消失');
    expect(find.text('read_file'), findsOneWidget, reason: '新回复自己的工具卡片应正常显示');

    // The new reply is on screen.
    expect(find.text('重新生成的回答'), findsOneWidget);

    await _flushTimers(tester);
  });

  testWidgets(
      'editing a user message and resending removes the collapsed tool '
      'call card of the reply below it', (tester) async {
    final manager = _ImmediateStreamManager();
    await tester.pumpWidget(_buildTestApp(manager));
    await _pumpLoaded(tester);

    expect(find.byType(ToolCallCard), findsOneWidget);

    // Enter edit mode on the user message, change the text, resend.
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pump(const Duration(milliseconds: 100));
    final editField = find.byType(TextField).last;
    await tester.enterText(editField, '查一下明天的天气');
    await tester.pump();
    final sendButtons = tester
        .widgetList<IconButton>(
          find.widgetWithIcon(IconButton, Icons.send_rounded),
        )
        .where((b) => b.onPressed != null)
        .toList();
    await tester.tap(find.byWidget(sendButtons.first));
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The old reply — and its collapsed tool card — must be gone. The new
    // reply (with its own card) is on screen, so the resend did not fail.
    expect(find.text('web_search'), findsNothing,
        reason: '编辑重发后，旧回复的折叠工具卡片应随旧消息一起消失');
    expect(find.text('read_file'), findsOneWidget,
        reason: '编辑重发后新回复的工具卡片应正常显示');
    expect(find.text('重新生成的回答'), findsOneWidget);

    await _flushTimers(tester);
  });

  testWidgets(
      'live-streamed reply: regenerating removes the collapsed tool card '
      'of the old reply', (tester) async {
    // Same regression, but the OLD reply was streamed LIVE in this page
    // session (tool card created through the real streaming pipeline:
    // running → completed → collapse → finalize) instead of being loaded
    // from persistence.
    final manager = _LiveStreamManager();
    SharedPreferences.setMockInitialValues({});
    final conversation = Conversation(
      id: 'test-conv',
      title: 'Test',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      messages: [
        ChatMessage(
          id: 'u1',
          role: 'user',
          content: '第一条',
          createdAt: DateTime(2025, 1, 1),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        chatStreamManagerProvider.overrideWith((ref) {
          manager.attachRef(ref);
          return manager;
        }),
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
    ));
    await _pumpLoaded(tester);

    // Send a message → the live stream starts (blocks on the manager).
    await tester.enterText(find.byType(TextField), '查一下天气');
    await tester.pump();
    final sendButtons = tester
        .widgetList<IconButton>(
          find.widgetWithIcon(IconButton, Icons.send_rounded),
        )
        .where((b) => b.onPressed != null)
        .toList();
    await tester.tap(find.byWidget(sendButtons.first));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(manager.lastStreamingMsgId, isNotNull, reason: '流应已开始');

    final container =
        ProviderScope.containerOf(tester.element(find.byType(ChatPage)));
    // Tool call starts (running) → card visible, expanded.
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
    expect(find.byType(ToolCallCard), findsOneWidget);
    expect(find.text('query: 天气'), findsOneWidget, reason: '进行中工具卡片应展开');

    // Tool completes → card collapses (auto-collapse invariant).
    container.read(streamingToolCallsProvider('test-conv').notifier).state = [
      ToolCallData(
        id: 'tc-1',
        name: 'web_search',
        arguments: const {'query': '天气'},
        status: ToolCallStatus.completed,
        result: '搜索结果',
      ),
    ];
    // First text token flows → placeholder converts to a text message.
    container.read(streamingTextSectionsProvider('test-conv').notifier).state =
        ['查到了'];
    container.read(streamingFullReplyProvider('test-conv').notifier).state =
        '查到了';
    await tester.pump();
    expect(find.text('query: 天气'), findsNothing, reason: '工具完成后卡片应收起为一行');

    // Stream completes with the final message (same id as placeholder).
    final aiMsgId = manager.lastStreamingMsgId!;
    final oldAssistantMsg = ChatMessage(
      id: aiMsgId,
      role: 'assistant',
      content: '查到了',
      createdAt: DateTime(2025, 1, 1, 0, 2),
      textSections: ['查到了'],
      toolCalls: [
        ToolCallData(
          id: 'tc-1',
          name: 'web_search',
          arguments: const {'query': '天气'},
          status: ToolCallStatus.completed,
          result: '搜索结果',
        ),
      ],
      toolCallRoundStarts: const [0],
    );
    final newHistory1 = [
      conversation.messages[0],
      ChatMessage(
        id: 'u2',
        role: 'user',
        content: '查一下天气',
        createdAt: DateTime(2025, 1, 1, 0, 2),
      ),
      oldAssistantMsg,
    ];
    await persistHistory(container, 'test-conv', newHistory1);
    manager.finish(
        'test-conv',
        StreamResult(
          history: newHistory1,
          assistantMessage: oldAssistantMsg,
          fullReply: '查到了',
          textSections: ['查到了'],
          toolCalls: List<ToolCallData>.from(oldAssistantMsg.toolCalls!),
          toolCallRoundStarts: const [0],
          blocks: [
            ToolCallBlock(
              id: 'tc-1',
              name: 'web_search',
              status: ToolCallStatus.completed,
              result: '搜索结果',
            ),
            TextBlock(text: '查到了'),
          ],
        ));
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Precondition: the live reply's collapsed card is on screen.
    expect(find.text('web_search'), findsOneWidget);
    expect(find.text('query: 天气'), findsNothing, reason: '直播完成的回复卡片应收起');

    // Regenerate (retry) the live reply.
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('确定'));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    // The regenerated stream completes with a DIFFERENT tool.
    final aiMsgId2 = manager.lastStreamingMsgId!;
    final newAssistantMsg = ChatMessage(
      id: aiMsgId2,
      role: 'assistant',
      content: '重新生成的回答',
      createdAt: DateTime(2025, 1, 1, 0, 3),
      textSections: ['重新生成的回答'],
      toolCalls: [
        ToolCallData(
          id: 'tc-new',
          name: 'read_file',
          arguments: const {'path': '/tmp/a.txt'},
          status: ToolCallStatus.completed,
          result: '文件内容',
        ),
      ],
      toolCallRoundStarts: const [0],
    );
    final newHistory2 = [
      conversation.messages[0],
      newHistory1[1],
      newAssistantMsg,
    ];
    await persistHistory(container, 'test-conv', newHistory2);
    manager.finish(
        'test-conv',
        StreamResult(
          history: newHistory2,
          assistantMessage: newAssistantMsg,
          fullReply: '重新生成的回答',
          textSections: ['重新生成的回答'],
          toolCalls: List<ToolCallData>.from(newAssistantMsg.toolCalls!),
          toolCallRoundStarts: const [0],
          blocks: [
            ToolCallBlock(
              id: 'tc-new',
              name: 'read_file',
              status: ToolCallStatus.completed,
              result: '文件内容',
            ),
            TextBlock(text: '重新生成的回答'),
          ],
        ));
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The OLD live reply's collapsed card must be gone; only the new
    // reply's own card remains.
    expect(find.text('web_search'), findsNothing,
        reason: '重新生成后，旧回复（直播生成）的折叠工具卡片应随旧消息消失');
    expect(find.text('read_file'), findsOneWidget, reason: '新回复自己的工具卡片应正常显示');

    await _flushTimers(tester);
  });
  testWidgets(
      'retrying a reply with newer messages below removes its collapsed '
      'tool card along with everything below', (tester) async {
    // History: u1, a1 (with collapsed tool card), u2, a2. Retrying a1 must
    // delete a1 AND everything below it — no stale card may survive.
    final manager = _ImmediateStreamManager();
    SharedPreferences.setMockInitialValues({});
    final conversation = Conversation(
      id: 'test-conv',
      title: 'Test',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      messages: [
        ChatMessage(
          id: 'u1',
          role: 'user',
          content: '查一下天气',
          createdAt: DateTime(2025, 1, 1),
        ),
        _assistantWithToolCard(),
        ChatMessage(
          id: 'u2',
          role: 'user',
          content: '还有呢',
          createdAt: DateTime(2025, 1, 1, 0, 2),
        ),
        ChatMessage(
          id: 'a2',
          role: 'assistant',
          content: '更多回答',
          createdAt: DateTime(2025, 1, 1, 0, 3),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        chatStreamManagerProvider.overrideWith((ref) {
          manager.attachRef(ref);
          return manager;
        }),
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
    ));
    await _pumpLoaded(tester);

    expect(find.text('web_search'), findsOneWidget, reason: '重试前应显示旧回复的折叠工具卡片');

    // Retry a1 (the FIRST refresh icon — the message with the card).
    final refreshIcons = find.byIcon(Icons.refresh);
    expect(refreshIcons, findsNWidgets(2), reason: '两条 AI 消息各有一个重试按钮');
    await tester.tap(refreshIcons.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('确定要重试这条回复吗？此操作将删除此消息及之后的所有消息。'), findsOneWidget,
        reason: '应弹出删除下方消息的确认对话框');
    await tester.tap(find.text('确定'));
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Old reply and everything below it are gone; only the regenerated
    // reply (with its own card) remains.
    expect(find.text('web_search'), findsNothing,
        reason: '重试后旧回复的折叠工具卡片应随消息一起消失');
    expect(find.text('还有呢'), findsNothing, reason: '旧回复之下的消息也应被删除');
    expect(find.text('read_file'), findsOneWidget, reason: '新回复自己的工具卡片应正常显示');

    await _flushTimers(tester);
  });
  testWidgets(
      'editing and resending after STOP leaves no ghost tool card of the '
      'stopped partial reply', (tester) async {
    // THE real-world repro: the user stops a streaming reply that already
    // produced a tool call + partial text. The stopped message stays in the
    // controller (and its segment cache) but is NOT part of _history. When
    // the user then edits the user message above and resends, the truncation
    // only removes messages found in _history — the stopped reply's message
    // (and its collapsed tool card) survives as a ghost.
    final manager = _LiveStreamManager();
    SharedPreferences.setMockInitialValues({});
    final conversation = Conversation(
      id: 'test-conv',
      title: 'Test',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      messages: [
        ChatMessage(
          id: 'u1',
          role: 'user',
          content: '第一条',
          createdAt: DateTime(2025, 1, 1),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        chatStreamManagerProvider.overrideWith((ref) {
          manager.attachRef(ref);
          return manager;
        }),
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
    ));
    await _pumpLoaded(tester);

    // Send a message → live stream starts.
    await tester.enterText(find.byType(TextField), '查一下天气');
    await tester.pump();
    final sendButtons = tester
        .widgetList<IconButton>(
          find.widgetWithIcon(IconButton, Icons.send_rounded),
        )
        .where((b) => b.onPressed != null)
        .toList();
    await tester.tap(find.byWidget(sendButtons.first));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    final container =
        ProviderScope.containerOf(tester.element(find.byType(ChatPage)));
    // Tool call completes (collapsed card) + partial text arrives.
    container
        .read(streamingToolCallRoundStartsProvider('test-conv').notifier)
        .state = [0];
    container.read(streamingToolCallsProvider('test-conv').notifier).state = [
      ToolCallData(
        id: 'tc-1',
        name: 'web_search',
        arguments: const {'query': '天气'},
        status: ToolCallStatus.completed,
        result: '搜索结果',
      ),
    ];
    container.read(streamingTextSectionsProvider('test-conv').notifier).state =
        ['部分回答'];
    container.read(streamingFullReplyProvider('test-conv').notifier).state =
        '部分回答';
    manager.partialReply = '部分回答';
    await tester.pump();
    expect(find.text('web_search'), findsOneWidget, reason: '停止前应显示折叠的工具卡片');

    // STOP the stream. Model: the manager's finalize does NOT land (the
    // tool call was still hanging when the user stopped — cancellation not
    // honored — so the partial is never persisted and never enters
    // _history; it lives only in the controller + segment cache).
    await tester.tap(find.byIcon(Icons.stop_circle_outlined));
    await tester.pump();
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    // Complete the abandoned stream future (the page ignores the result —
    // pageOwnedStream is false after a stop).
    manager.finish(
        'test-conv',
        StreamResult(
          history: const [],
          fullReply: '部分回答',
          cancelled: true,
        ));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text('web_search'), findsOneWidget,
        reason: '停止后部分回复及其折叠卡片应保留在界面上');

    // Now edit the user message (the LAST one — u2) and resend.
    await tester.tap(find.byIcon(Icons.edit_outlined).last);
    await tester.pump(const Duration(milliseconds: 100));
    final editField = find.byType(TextField).last;
    await tester.enterText(editField, '改一下再问');
    await tester.pump();
    final sendButtons2 = tester
        .widgetList<IconButton>(
          find.widgetWithIcon(IconButton, Icons.send_rounded),
        )
        .where((b) => b.onPressed != null)
        .toList();
    await tester.tap(find.byWidget(sendButtons2.first));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    // The regenerated stream completes with a different tool.
    final aiMsgId2 = manager.lastStreamingMsgId!;
    final newAssistantMsg = ChatMessage(
      id: aiMsgId2,
      role: 'assistant',
      content: '重新生成的回答',
      createdAt: DateTime(2025, 1, 1, 0, 3),
      textSections: ['重新生成的回答'],
      toolCalls: [
        ToolCallData(
          id: 'tc-new',
          name: 'read_file',
          arguments: const {'path': '/tmp/a.txt'},
          status: ToolCallStatus.completed,
          result: '文件内容',
        ),
      ],
      toolCallRoundStarts: const [0],
    );
    final newHistory = [
      conversation.messages[0],
      ChatMessage(
        id: 'u2',
        role: 'user',
        content: '改一下再问',
        createdAt: DateTime(2025, 1, 1, 0, 2),
      ),
      newAssistantMsg,
    ];
    await persistHistory(container, 'test-conv', newHistory);
    manager.finish(
        'test-conv',
        StreamResult(
          history: newHistory,
          assistantMessage: newAssistantMsg,
          fullReply: '重新生成的回答',
          textSections: ['重新生成的回答'],
          toolCalls: List<ToolCallData>.from(newAssistantMsg.toolCalls!),
          toolCallRoundStarts: const [0],
          blocks: [
            ToolCallBlock(
              id: 'tc-new',
              name: 'read_file',
              status: ToolCallStatus.completed,
              result: '文件内容',
            ),
            TextBlock(text: '重新生成的回答'),
          ],
        ));
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // THE GHOST: the stopped reply's collapsed card must disappear together
    // with everything below the edited message. Only the new reply's own
    // card may remain.
    expect(find.text('web_search'), findsNothing,
        reason: '编辑重发后，被停止的旧回复（含其折叠工具卡片）必须随之下方消息一起消失');
    expect(find.text('read_file'), findsOneWidget, reason: '新回复自己的工具卡片应正常显示');

    await _flushTimers(tester);
  });

  testWidgets(
      'regenerating an earlier reply after STOP also removes the stopped '
      'reply ghost card', (tester) async {
    // History: u1, a1 (with collapsed card). Send u2 → stream → stop with
    // partial text + a second tool card (stopped message only lives in the
    // controller). Then retry a1: the truncation must remove BOTH a1 and the
    // stopped orphan message — no ghost card may survive.
    final manager = _LiveStreamManager();
    SharedPreferences.setMockInitialValues({});
    final conversation = Conversation(
      id: 'test-conv',
      title: 'Test',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      messages: [
        ChatMessage(
          id: 'u1',
          role: 'user',
          content: '查一下天气',
          createdAt: DateTime(2025, 1, 1),
        ),
        _assistantWithToolCard(),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        chatStreamManagerProvider.overrideWith((ref) {
          manager.attachRef(ref);
          return manager;
        }),
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
    ));
    await _pumpLoaded(tester);
    expect(find.text('web_search'), findsOneWidget, reason: '前置：a1 的折叠工具卡片应可见');

    // Send u2 → live stream → tool card + partial text → STOP.
    await tester.enterText(find.byType(TextField), '继续查');
    await tester.pump();
    final sendButtons = tester
        .widgetList<IconButton>(
          find.widgetWithIcon(IconButton, Icons.send_rounded),
        )
        .where((b) => b.onPressed != null)
        .toList();
    await tester.tap(find.byWidget(sendButtons.first));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    final container =
        ProviderScope.containerOf(tester.element(find.byType(ChatPage)));
    container
        .read(streamingToolCallRoundStartsProvider('test-conv').notifier)
        .state = [0];
    container.read(streamingToolCallsProvider('test-conv').notifier).state = [
      ToolCallData(
        id: 'tc-2',
        name: 'web_search',
        arguments: const {'query': '继续'},
        status: ToolCallStatus.completed,
        result: '更多结果',
      ),
    ];
    container.read(streamingTextSectionsProvider('test-conv').notifier).state =
        ['部分回答'];
    container.read(streamingFullReplyProvider('test-conv').notifier).state =
        '部分回答';
    manager.partialReply = '部分回答';
    await tester.pump();
    expect(find.byType(ToolCallCard), findsNWidgets(2),
        reason: '停止前 a1 与流式回复各有一张工具卡片');

    await tester.tap(find.byIcon(Icons.stop_circle_outlined));
    await tester.pump();
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    manager.finish(
        'test-conv',
        StreamResult(
          history: const [],
          fullReply: '部分回答',
          cancelled: true,
        ));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byType(ToolCallCard), findsNWidgets(2),
        reason: '停止后两张卡片都应保留在界面上');

    // Retry a1 (the FIRST refresh icon — the older reply). u2 exists below
    // it, so the dialog warns about deleting everything below.
    await tester.tap(find.byIcon(Icons.refresh).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('确定要重试这条回复吗？此操作将删除此消息及之后的所有消息。'), findsOneWidget);
    await tester.tap(find.text('确定'));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    // Regenerated stream completes with a different tool.
    final aiMsgId2 = manager.lastStreamingMsgId!;
    final newAssistantMsg = ChatMessage(
      id: aiMsgId2,
      role: 'assistant',
      content: '重新生成的回答',
      createdAt: DateTime(2025, 1, 1, 0, 3),
      textSections: ['重新生成的回答'],
      toolCalls: [
        ToolCallData(
          id: 'tc-new',
          name: 'read_file',
          arguments: const {'path': '/tmp/a.txt'},
          status: ToolCallStatus.completed,
          result: '文件内容',
        ),
      ],
      toolCallRoundStarts: const [0],
    );
    final newHistory = [
      conversation.messages[0],
      newAssistantMsg,
    ];
    await persistHistory(container, 'test-conv', newHistory);
    manager.finish(
        'test-conv',
        StreamResult(
          history: newHistory,
          assistantMessage: newAssistantMsg,
          fullReply: '重新生成的回答',
          textSections: ['重新生成的回答'],
          toolCalls: List<ToolCallData>.from(newAssistantMsg.toolCalls!),
          toolCallRoundStarts: const [0],
          blocks: [
            ToolCallBlock(
              id: 'tc-new',
              name: 'read_file',
              status: ToolCallStatus.completed,
              result: '文件内容',
            ),
            TextBlock(text: '重新生成的回答'),
          ],
        ));
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Neither the retried a1's card nor the stopped reply's card may remain.
    expect(find.text('web_search'), findsNothing,
        reason: '重新生成后，被重试的回复与被停止的回复（含折叠工具卡片）都必须消失');
    expect(find.text('read_file'), findsOneWidget);

    await _flushTimers(tester);
  });

  testWidgets('deleting a stopped partial reply removes its tool card',
      (tester) async {
    // The delete button on a stopped partial reply used to be a no-op (the
    // message is not in _history) — its tool card lingered forever.
    final manager = _LiveStreamManager();
    SharedPreferences.setMockInitialValues({});
    final conversation = Conversation(
      id: 'test-conv',
      title: 'Test',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      messages: [
        ChatMessage(
          id: 'u1',
          role: 'user',
          content: '第一条',
          createdAt: DateTime(2025, 1, 1),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        chatStreamManagerProvider.overrideWith((ref) {
          manager.attachRef(ref);
          return manager;
        }),
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
    ));
    await _pumpLoaded(tester);

    // Send → stream → tool card + partial text → STOP.
    await tester.enterText(find.byType(TextField), '查一下天气');
    await tester.pump();
    final sendButtons = tester
        .widgetList<IconButton>(
          find.widgetWithIcon(IconButton, Icons.send_rounded),
        )
        .where((b) => b.onPressed != null)
        .toList();
    await tester.tap(find.byWidget(sendButtons.first));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    final container =
        ProviderScope.containerOf(tester.element(find.byType(ChatPage)));
    container
        .read(streamingToolCallRoundStartsProvider('test-conv').notifier)
        .state = [0];
    container.read(streamingToolCallsProvider('test-conv').notifier).state = [
      ToolCallData(
        id: 'tc-1',
        name: 'web_search',
        arguments: const {'query': '天气'},
        status: ToolCallStatus.completed,
        result: '搜索结果',
      ),
    ];
    container.read(streamingTextSectionsProvider('test-conv').notifier).state =
        ['部分回答'];
    container.read(streamingFullReplyProvider('test-conv').notifier).state =
        '部分回答';
    manager.partialReply = '部分回答';
    await tester.pump();
    await tester.tap(find.byIcon(Icons.stop_circle_outlined));
    await tester.pump();
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    manager.finish(
        'test-conv',
        StreamResult(
          history: const [],
          fullReply: '部分回答',
          cancelled: true,
        ));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text('web_search'), findsOneWidget,
        reason: '停止后的部分回复应保留其折叠工具卡片');

    // Delete the stopped partial reply (its delete button is the LAST
    // delete icon — the stopped message is the newest AI message).
    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('确定要删除这条消息吗？此操作无法撤销。'), findsOneWidget,
        reason: '应弹出删除确认对话框');
    await tester.tap(find.text('删除'));
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The orphan branch must be surgical: only the stopped reply is gone —
    // the earlier user message and its edit/delete buttons stay.
    expect(find.text('web_search'), findsNothing,
        reason: '删除被停止的部分回复后，其折叠工具卡片应一并消失');
    expect(find.text('第一条'), findsOneWidget,
        reason: '删除孤儿消息不应影响 _history 中的既有消息');

    await _flushTimers(tester);
  });
}

/// Persists [history] to the conversations provider (what the real manager's
/// `_saveMessages` does before completing).
Future<void> persistHistory(ProviderContainer container, String convId,
    List<ChatMessage> history) async {
  await container
      .read(conversationsProvider.notifier)
      .updateMessages(convId, history);
}
