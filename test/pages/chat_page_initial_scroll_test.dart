import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' hide ChatMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/tool_call.dart' show ToolCallData;
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/chat_manager_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_stream_manager.dart';

import 'chat_page_test.dart' show createChatTestApp, createTestMessages;

/// Short content so a bubble occupies roughly one line.
ChatMessage _msg(String id, String role, String content, int hour) {
  return ChatMessage(
    id: id,
    role: role,
    content: content,
    createdAt: DateTime(2025, 1, 1).add(Duration(hours: hour)),
  );
}

/// The chat list scroll position: the page's only Scrollable whose viewport
/// is taller than 100 logical pixels.
ScrollPosition _chatPosition(WidgetTester tester) {
  final finder = find.descendant(
    of: find.byType(ChatPage),
    matching: find.byType(Scrollable),
    skipOffstage: false,
  );
  for (final e in finder.evaluate()) {
    final controller = (e.widget as Scrollable).controller;
    if (controller != null &&
        controller.hasClients &&
        controller.position.viewportDimension > 100) {
      return controller.position;
    }
  }
  throw StateError('chat list scroll position not found');
}

/// Global Y of the top edge of the chat list viewport.
double _chatListTop(WidgetTester tester) {
  final finder = find.descendant(
    of: find.byType(ChatPage),
    matching: find.byType(Scrollable),
    skipOffstage: false,
  );
  for (final e in finder.evaluate()) {
    final controller = (e.widget as Scrollable).controller;
    if (controller != null &&
        controller.hasClients &&
        controller.position.viewportDimension > 100) {
      return (e.renderObject as RenderBox).localToGlobal(Offset.zero).dy;
    }
  }
  throw StateError('chat list not found');
}

/// Pumps the chat page, then loads [messages] into the active conversation
/// and pumps frames until the initial scroll pass has settled.
Future<ProviderContainer> pumpChatWithMessages(
  WidgetTester tester, {
  required List<ChatMessage> messages,
}) async {
  await tester.pumpWidget(createChatTestApp());
  await tester.pump();

  final ctx = tester.element(find.byType(ChatPage));
  final container = ProviderScope.containerOf(ctx);
  container.read(conversationsProvider.notifier).state = [
    Conversation.fromMap({
      'id': 'test-conv-id',
      'title': 'Test Conversation',
      'createdAt': DateTime(2025, 1, 1).toIso8601String(),
      'updatedAt': DateTime(2025, 1, 1).toIso8601String(),
      'messages': messages.map((m) => m.toMap()).toList(),
      'isPinned': false,
      'sortOrder': 0,
    }),
  ];
  // The conversations listener reloads the page in a post-frame; the initial
  // scroll pass then takes a few more frames (each step consumes one frame).
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  return container;
}

/// A testable [ChatStreamManager] that simulates a background streaming
/// conversation without requiring an actual API call (same pattern as
/// chat_reentry_test.dart).
class _TestChatStreamManager extends ChatStreamManager {
  final String _convId;
  final String _msgId;
  final String _fullReply;
  final List<ChatMessage> _history;

  _TestChatStreamManager({
    required String convId,
    required String msgId,
    required String fullReply,
    List<ChatMessage> history = const [],
  })  : _convId = convId,
        _msgId = msgId,
        _fullReply = fullReply,
        _history = history,
        super(null);

  @override
  bool isStreamingFor(String convId) => convId == _convId;

  @override
  String? streamingMsgIdFor(String convId) =>
      convId == _convId ? _msgId : null;

  @override
  String fullReplyFor(String convId) => convId == _convId ? _fullReply : '';

  @override
  List<String> reasoningSectionsFor(String convId) => [];

  @override
  List<ChatMessage> historyFor(String convId) =>
      convId == _convId ? List.unmodifiable(_history) : const [];

  @override
  List<String> textChunksFor(String convId) => const [''];

  @override
  List<ToolCallData> toolCallsFor(String convId) => [];

  @override
  List<int> toolCallRoundStartsFor(String convId) => [];

  @override
  bool hasFirstTokenFor(String convId) => false;

  @override
  String reasoningBufferFor(String convId) => '';

  @override
  void activateConversation(String convId) {}
}

void main() {
  setUp(() {
    // Markdown rendering wraps blocks in VisibilityDetector; its default
    // 500ms debounce timer would remain pending at test teardown.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() {
    VisibilityDetectorController.instance.updateInterval =
        const Duration(milliseconds: 500);
  });

  group('ChatPage initial scroll - last user message positioning', () {
    testWidgets(
        'long conversation tail: top of the LAST USER message lands at the '
        'top of the viewport (not at the bottom)', (tester) async {
      final messages = [
        _msg('u0', 'user', 'Question one', 0),
        _msg('a0', 'assistant', 'Short reply', 1),
        _msg('u1', 'user', 'LAST USER QUESTION', 2),
        _msg(
          'a1',
          'assistant',
          List.filled(90, 'This is a very long assistant reply line.')
              .join('\n'),
          3,
        ),
      ];
      await pumpChatWithMessages(tester, messages: messages);

      final pos = _chatPosition(tester);
      // Not at the bottom: the long reply continues below the viewport.
      expect(
        pos.maxScrollExtent - pos.pixels,
        greaterThan(pos.viewportDimension * 0.5),
        reason: 'expected to be scrolled up from the bottom',
      );

      // The last user message is visible at the very top of the list area.
      final userTextTop = tester.getTopLeft(find.text('LAST USER QUESTION')).dy;
      final listTop = _chatListTop(tester);
      expect(userTextTop, greaterThanOrEqualTo(listTop - 1),
          reason: 'user message must not start above the viewport');
      expect(userTextTop, lessThanOrEqualTo(listTop + 60),
          reason: 'user message must start at the top of the viewport');
      expect(
        tester.getBottomLeft(find.text('LAST USER QUESTION')).dy,
        lessThanOrEqualTo(listTop + pos.viewportDimension + 1),
        reason: 'user message must be fully visible',
      );

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'short conversation tail: scrolls to the bottom (last user message '
        '+ reply fit in one screen)', (tester) async {
      final messages = [
        _msg('u0', 'user', 'Hi', 0),
        _msg('a0', 'assistant', 'Short reply', 1),
      ];
      await pumpChatWithMessages(tester, messages: messages);

      final pos = _chatPosition(tester);
      expect(pos.maxScrollExtent - pos.pixels, lessThanOrEqualTo(1.0),
          reason: 'short content should settle at the bottom');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'conversation without any user message falls back to the bottom',
        (tester) async {
      final messages = [
        _msg(
          'a0',
          'assistant',
          List.filled(90, 'Assistant only line.').join('\n'),
          0,
        ),
      ];
      await pumpChatWithMessages(tester, messages: messages);

      final pos = _chatPosition(tester);
      expect(pos.maxScrollExtent - pos.pixels, lessThanOrEqualTo(1.0),
          reason: 'no user message -> fall back to the bottom');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'entry scroll never overshoots past the bottom (no blank gap below '
        'the last message)', (tester) async {
      final messages = [
        _msg('u0', 'user', 'Question one', 0),
        _msg('a0', 'assistant', 'Short reply', 1),
        _msg('u1', 'user', 'LAST USER QUESTION', 2),
        _msg(
          'a1',
          'assistant',
          List.filled(90, 'This is a very long assistant reply line.')
              .join('\n'),
          3,
        ),
      ];
      await tester.pumpWidget(createChatTestApp());
      await tester.pump();

      final ctx = tester.element(find.byType(ChatPage));
      final container = ProviderScope.containerOf(ctx);
      container.read(conversationsProvider.notifier).state = [
        Conversation.fromMap({
          'id': 'test-conv-id',
          'title': 'Test Conversation',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'updatedAt': DateTime(2025, 1, 1).toIso8601String(),
          'messages': messages.map((m) => m.toMap()).toList(),
          'isPinned': false,
          'sortOrder': 0,
        }),
      ];

      final finder = find.descendant(
        of: find.byType(ChatPage),
        matching: find.byType(Scrollable),
        skipOffstage: false,
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        for (final e in finder.evaluate()) {
          final controller = (e.widget as Scrollable).controller;
          if (controller != null && controller.hasClients) {
            final pos = controller.position;
            expect(
              pos.pixels,
              lessThanOrEqualTo(pos.maxScrollExtent + 0.5),
              reason: 'frame $i: scroll offset must never exceed the bottom',
            );
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'deep target with heterogeneous content: the pass converges on the '
        'last user message even though the bottom estimate is wrong',
        (tester) async {
      // Many short messages first, then the target question, then a long
      // reply. At the top of the list the sliver's maxScrollExtent estimate
      // (short built children x remaining count) badly undershoots the true
      // bottom, so the pass must chase the bottom down before stepping up.
      final messages = <ChatMessage>[];
      for (var i = 0; i < 18; i++) {
        messages.add(_msg('u$i', 'user', 'Short question $i', i * 2));
        messages.add(_msg('a$i', 'assistant', 'Short answer $i', i * 2 + 1));
      }
      messages.add(_msg('u18', 'user', 'DEEP LAST USER QUESTION', 40));
      messages.add(
        _msg(
          'a18',
          'assistant',
          List.filled(90, 'This is a very long assistant reply line.')
              .join('\n'),
          41,
        ),
      );
      await pumpChatWithMessages(tester, messages: messages);

      final pos = _chatPosition(tester);
      expect(
        pos.maxScrollExtent - pos.pixels,
        greaterThan(pos.viewportDimension * 0.5),
        reason: 'expected to be scrolled up from the bottom',
      );

      final userTextTop =
          tester.getTopLeft(find.text('DEEP LAST USER QUESTION')).dy;
      final listTop = _chatListTop(tester);
      expect(userTextTop, greaterThanOrEqualTo(listTop - 1),
          reason: 'user message must not start above the viewport');
      expect(userTextTop, lessThanOrEqualTo(listTop + 60),
          reason: 'user message must start at the top of the viewport');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'last user message outside the loaded controller window falls back '
        'to the bottom', (tester) async {
      // Only the last 20 messages are loaded into the chat controller; the
      // last user message here (index 19) is older than that window, so it
      // can never be laid out — the pass must settle at the bottom.
      final messages = <ChatMessage>[];
      for (var i = 0; i < 20; i++) {
        messages.add(_msg('u$i', 'user', 'Question $i', i * 2));
      }
      for (var i = 0; i < 25; i++) {
        messages.add(_msg('a$i', 'assistant', 'Reply $i', 100 + i));
      }
      await pumpChatWithMessages(tester, messages: messages);

      final pos = _chatPosition(tester);
      expect(pos.maxScrollExtent - pos.pixels, lessThanOrEqualTo(1.0),
          reason: 'unreachable target -> fall back to the bottom');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'entry while a background stream is active: short streaming tail '
        'settles at the bottom with the live reply restored', (tester) async {
      const convId = 'stream-conv';
      const msgId = 'a-live';
      final testManager = _TestChatStreamManager(
        convId: convId,
        msgId: msgId,
        fullReply: 'Partially streamed reply',
        history: [
          _msg('u0', 'user', 'Question one', 0),
          _msg(msgId, 'assistant', 'partial', 1),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatStreamManagerProvider.overrideWith((ref) => testManager),
            conversationsProvider
                .overrideWith((ref) => ConversationsNotifier(ref)),
            activeConversationIdProvider.overrideWith((ref) => convId),
            providerEntriesProvider
                .overrideWith((ref) => ProviderEntriesNotifier()),
          ],
          child: const MaterialApp(home: ChatPage()),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Short streaming tail (question + partial reply) fits one screen,
      // so the entry pass settles at the bottom.
      final pos = _chatPosition(tester);
      expect(pos.maxScrollExtent - pos.pixels, lessThanOrEqualTo(1.0),
          reason: 'short streaming tail should settle at the bottom');

      // The live reply is restored into the controller as the last message.
      final chatWidget = tester.widget<Chat>(find.byType(Chat));
      final messages = chatWidget.chatController.messages;
      expect(messages.map((m) => m.id).toList(), ['u0', msgId],
          reason: 'history order: user question, then live reply');
      expect((messages.last as TextMessage).text, 'Partially streamed reply',
          reason: 'the live streaming reply must be restored with content');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'same-conversation reload keeps today\'s behavior: list settles at '
        'the bottom via the built-in initial jump', (tester) async {
      await pumpChatWithMessages(
        tester,
        messages: createTestMessages(25),
      );

      // Scroll up so the reload happens from a non-bottom position.
      await tester.drag(find.byType(ChatPage), const Offset(0, 200));
      await tester.pump();
      final before = _chatPosition(tester);
      expect(before.maxScrollExtent - before.pixels, greaterThan(80),
          reason: 'precondition: user scrolled up');

      // Simulate a background update (e.g. stream completion) that reloads
      // the SAME conversation with more messages.
      final ctx = tester.element(find.byType(ChatPage));
      final container = ProviderScope.containerOf(ctx);
      container.read(conversationsProvider.notifier).state = [
        Conversation.fromMap({
          'id': 'test-conv-id',
          'title': 'Test Conversation',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'updatedAt': DateTime(2025, 1, 1).toIso8601String(),
          'messages': createTestMessages(30)
              .map((m) => m.toMap())
              .toList(),
          'isPinned': false,
          'sortOrder': 0,
        }),
      ];
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final after = _chatPosition(tester);
      // Same-conversation reloads keep the built-in jump-to-bottom. The
      // built-in jump can land a few px short of the very bottom when
      // markdown blocks relayout after the jump — that is today's behavior
      // and is intentionally preserved here.
      expect(after.maxScrollExtent - after.pixels, lessThanOrEqualTo(150),
          reason: 'same-conversation reload keeps the built-in jump-to-bottom');
      await tester.pumpWidget(const SizedBox());
    });
  });
}
