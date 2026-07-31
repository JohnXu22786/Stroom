import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' hide ChatMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/tool_call.dart' show ToolCallData;
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/chat_stream_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_stream_manager.dart';
import 'package:stroom/providers/chat_manager_provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

ChatMessage _message({
  required String id,
  required String role,
  required String content,
}) {
  return ChatMessage(id: id, role: role, content: content);
}

/// A testable [ChatStreamManager] that simulates a background streaming
/// conversation without requiring an actual API call.
class _TestChatStreamManager extends ChatStreamManager {
  final String _convId;
  final String _msgId;
  final String _fullReply;

  _TestChatStreamManager({
    required String convId,
    required String msgId,
    required String fullReply,
  })  : _convId = convId,
        _msgId = msgId,
        _fullReply = fullReply,
        super(null);

  @override
  bool isStreamingFor(String convId) => convId == _convId;

  @override
  String? streamingMsgIdFor(String convId) => convId == _convId ? _msgId : null;

  @override
  String fullReplyFor(String convId) => convId == _convId ? _fullReply : '';

  @override
  List<String> reasoningSectionsFor(String convId) => [];

  @override
  List<ChatMessage> historyFor(String convId) => [];

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
  group('ChatPage streaming re-entry history merge', () {
    test('keeps a newly sent user message missing from persisted history', () {
      final persisted = [
        _message(id: 'u1', role: 'user', content: 'first'),
        _message(id: 'a1', role: 'assistant', content: 'partial answer'),
      ];
      final live = [
        ...persisted,
        _message(id: 'u2', role: 'user', content: 'second'),
      ];

      final merged = mergeStreamingHistory(persisted, live);

      expect(merged.map((message) => message.id), ['u1', 'a1', 'u2']);
      expect(merged.last.content, 'second');
    });

    test('prefers the live assistant snapshot over an older persisted copy',
        () {
      final persisted = [
        _message(id: 'u1', role: 'user', content: 'first'),
        _message(id: 'a1', role: 'assistant', content: 'old partial'),
      ];
      final live = [
        _message(id: 'u1', role: 'user', content: 'first'),
        _message(id: 'a1', role: 'assistant', content: 'latest answer'),
      ];

      final merged = mergeStreamingHistory(persisted, live);

      expect(merged.map((message) => message.id), ['u1', 'a1']);
      expect(merged.last.content, 'latest answer');
    });

    test('handles empty persisted or live history without duplicates', () {
      final live = [
        _message(id: 'u1', role: 'user', content: 'first'),
      ];
      final duplicateLive = [
        ...live,
        _message(id: 'u2', role: 'user', content: 'second'),
        _message(id: 'u2', role: 'user', content: 'second (latest)'),
      ];

      expect(
        mergeStreamingHistory(const [], duplicateLive)
            .map((message) => message.id),
        ['u1', 'u2'],
      );
      expect(
        mergeStreamingHistory(const [], duplicateLive).last.content,
        'second (latest)',
      );
      expect(mergeStreamingHistory(const [], live), equals(live));
      expect(mergeStreamingHistory(live, const []), equals(live));
    });
  });

  group('ChatPage streaming re-entry message type', () {
    setUp(() {
      // Disable visibility_detector's 500ms debounce timer in tests,
      // otherwise it leaves a pending timer that fails test teardown.
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
    });

    tearDown(() {
      VisibilityDetectorController.instance.updateInterval =
          const Duration(milliseconds: 500);
    });
    // Regression test: prevents the white-background flash from
    // https://github.com/JohnXu22786/Stroom/releases/tag/v0.4.50-alpha-2
    //
    // The bug: when re-entering a page with an active background stream,
    // _loadConversationMessages inserted Message.textStream, which
    // dispatches to textStreamMessageBuilder — a raw white-background
    // Markdown render without the gray assistant bubble, tool-call cards,
    // or reasoning buttons. ~0.5s later, a provider update converted it
    // to Message.text (normal gray bubble). The fix: insert Message.text
    // directly from the restored fullReply.
    testWidgets(
        'restored streaming message is TextMessage (gray bubble) '
        'not TextStreamMessage (raw white Markdown)', (tester) async {
      SharedPreferences.setMockInitialValues({});

      const testConvId = 'conv-stream-1';
      const testMsgId = 'a-streaming-1';
      const testFullReply = 'This is the partially streamed reply';

      final testManager = _TestChatStreamManager(
        convId: testConvId,
        msgId: testMsgId,
        fullReply: testFullReply,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatStreamManagerProvider.overrideWith((ref) => testManager),
            conversationsProvider
                .overrideWith((ref) => ConversationsNotifier(ref)),
            activeConversationIdProvider.overrideWith((ref) => testConvId),
            providerEntriesProvider
                .overrideWith((ref) => ProviderEntriesNotifier()),
          ],
          child: const MaterialApp(home: ChatPage()),
        ),
      );

      // Wait for _initialize → _restoreStreamingState →
      // _loadConversationMessages to complete. This includes the
      // post-frame callback scheduling and the async DB read.
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // The Chat widget should be rendered with a controller.
      final chatFinder = find.byType(Chat);
      expect(chatFinder, findsOneWidget,
          reason: 'Chat widget should be present after initialization');

      final chatWidget = tester.widget<Chat>(chatFinder);
      final controller = chatWidget.chatController;
      final messages = controller.messages;

      // The streaming assistant message should be in the controller.
      final streamingMsg = messages.where((m) => m.id == testMsgId).firstOrNull;
      expect(streamingMsg, isNotNull,
          reason: 'Streaming assistant message should be in the controller');

      // Core assertion: it must be TextMessage (Message.text), which
      // uses textMessageBuilder → gray bubble + segments. It must NOT
      // be TextStreamMessage (Message.textStream), which would use
      // textStreamMessageBuilder → raw white-background Markdown.
      expect(streamingMsg, isA<TextMessage>(),
          reason: 'Restored streaming message must be TextMessage '
              '(Message.text), not TextStreamMessage (Message.textStream). '
              'TextStreamMessage would render as raw white-background '
              'Markdown without the gray assistant bubble, tool-call '
              'cards, or reasoning buttons.');
      expect(streamingMsg, isNot(isA<TextStreamMessage>()),
          reason: 'Restored streaming message must NOT be TextStreamMessage');

      // The restored message should carry the live fullReply text.
      final textContent = switch (streamingMsg!) {
        TextMessage m => m.text,
        _ => '',
      };
      expect(textContent, testFullReply,
          reason: 'Restored message should preserve the streaming '
              'fullReply content');
    });
  });
}
