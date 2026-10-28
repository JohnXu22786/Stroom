import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' hide ChatMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/message_block.dart';
import 'package:stroom/models/stroom_conversation.dart';
import 'package:stroom/models/tool_call.dart'
    show ToolCallData, ToolCallStatus, ToolDefinition;
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/chat_manager_provider.dart';
import 'package:stroom/providers/chat_stream_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_stream_manager.dart'
    show ChatStreamManager, StreamResult;
import 'package:stroom/services/conversation_repository.dart';
import 'package:stroom/services/conversation_record_adapter.dart';
import 'package:stroom/services/conversation_repository_memory.dart';
import 'package:stroom/widgets/llm/tool_call_card.dart';

import 'chat_page_test.dart' show createChatTestApp;

/// Load-more indicator key — the widget must not exist in the tree at all
/// while no pagination load is running (an indeterminate
/// CircularProgressIndicator keeps animating as long as it is mounted).
const loadMoreIndicatorKey = ValueKey('chat-load-more-indicator');

const noMoreMessagesText = '没有更多内容了';

List<ChatMessage> _msgs(int count) {
  return [
    for (var i = 0; i < count; i++)
      ChatMessage(
        id: 'm$i',
        role: i.isEven ? 'user' : 'assistant',
        content: 'Message $i content',
        createdAt: DateTime(2025, 1, 1).add(Duration(hours: i)),
      ),
  ];
}

/// Pumps the chat page with a conversation of [messageCount] messages and
/// settles the initial positioning pass.
Future<ProviderContainer> pumpConversation(
  WidgetTester tester, {
  required int messageCount,
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
      'messages': _msgs(messageCount).map((m) => m.toMap()).toList(),
      'isPinned': false,
      'sortOrder': 0,
    }),
  ];
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  return container;
}

/// Drags the chat list far down so it reaches the very top (which triggers
/// the library's onEndReached / load-more path). Two pumps are needed: the
/// library's scroll anchoring awaits a layout pass before it calls
/// onEndReached, so the load (and its indicator) only materialize one frame
/// after the drag.
Future<void> dragToTop(WidgetTester tester) async {
  await tester.drag(find.byType(ChatPage), const Offset(0, 6000));
  await tester.pump();
  await tester.pump();
}

/// Lets the library's post-pagination scroll anchoring converge: it jumps
/// to the anchor message, then corrects the offset over the next few frames
/// as the sliver's extent estimate settles. Without these frames the
/// correction can still be running when the next drag starts.
Future<void> settleAnchor(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

class _CompletingStreamManager extends ChatStreamManager {
  _CompletingStreamManager() : super(null);

  final receivedHistories = <List<ChatMessage>>[];

  @override
  void activateConversation(String convId) {}

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
    ProviderEntriesState? entriesStateOverride,
  }) async {
    receivedHistories.add(List<ChatMessage>.from(history));
    final reply = ChatMessage(
      id: streamingMsgId ?? 'assistant-after-send',
      role: 'assistant',
      content: 'Reply',
      createdAt: DateTime(2026),
    );
    return StreamResult(
      history: [...history, reply],
      assistantMessage: reply,
      fullReply: reply.content,
    );
  }
}

class _SearchStreamManager extends ChatStreamManager {
  _SearchStreamManager(this._history) : super(null);

  final List<ChatMessage> _history;

  @override
  bool isStreamingFor(String convId) => convId == 'code-search';

  @override
  String? streamingMsgIdFor(String convId) =>
      convId == 'code-search' ? _history.last.id : null;

  @override
  String fullReplyFor(String convId) =>
      convId == 'code-search' ? _history.last.content : '';

  @override
  List<ChatMessage> historyFor(String convId) =>
      convId == 'code-search' ? _history : const [];

  @override
  List<String> reasoningSectionsFor(String convId) => const [];

  @override
  List<String> textChunksFor(String convId) => const [];

  @override
  List<ToolCallData> toolCallsFor(String convId) => const [];

  @override
  List<int> toolCallRoundStartsFor(String convId) => const [];

  @override
  bool hasFirstTokenFor(String convId) => false;

  @override
  String reasoningBufferFor(String convId) => '';

  @override
  void activateConversation(String convId) {}
}

class _ToggleFailingMessageMemoryRepository
    extends MemoryConversationRepository {
  bool failMessageReads = false;
  int messageReadCount = 0;

  @override
  Future<List<StroomMessage>> getMessages(
    String conversationId, {
    int offset = 0,
    int limit = 50,
  }) {
    messageReadCount++;
    if (failMessageReads) throw StateError('simulated message read failure');
    return super.getMessages(conversationId, offset: offset, limit: limit);
  }
}

class _DeferredMessageMemoryRepository extends MemoryConversationRepository {
  bool deferReads = false;
  final readStarted = Completer<void>();
  final pendingRead = Completer<List<StroomMessage>>();

  @override
  Future<List<StroomMessage>> getMessages(
    String conversationId, {
    int offset = 0,
    int limit = 50,
  }) {
    if (deferReads && conversationId == 'search-old') {
      if (!readStarted.isCompleted) readStarted.complete();
      return pendingRead.future;
    }
    return super.getMessages(conversationId, offset: offset, limit: limit);
  }
}

class _DeferredFullHistoryMemoryRepository
    extends MemoryConversationRepository {
  bool deferFullReads = false;
  final readStarted = Completer<void>();
  final pendingRead = Completer<List<StroomMessage>>();

  @override
  Future<List<StroomMessage>> getMessages(
    String conversationId, {
    int offset = 0,
    int limit = 50,
  }) {
    if (deferFullReads && limit == 100 && conversationId == 'retry-old') {
      if (!readStarted.isCompleted) readStarted.complete();
      return pendingRead.future;
    }
    return super.getMessages(conversationId, offset: offset, limit: limit);
  }
}

class _DelayedRemoveChatController extends InMemoryChatController {
  final firstRemovalStarted = Completer<void>();
  final finishFirstRemoval = Completer<void>();

  @override
  Future<void> removeMessage(Message message, {bool animated = true}) async {
    if (!firstRemovalStarted.isCompleted) {
      firstRemovalStarted.complete();
      await finishFirstRemoval.future;
    }
    await super.removeMessage(message, animated: animated);
  }
}

void main() {
  setUp(() {
    // Markdown rendering wraps blocks in VisibilityDetector; its default
    // 500ms debounce timer would remain pending at test teardown.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() {
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
  });

  group('ChatPage load-more indicator', () {
    test(
      'stream completion stops removing messages after the page changes',
      () async {
        final controller = _DelayedRemoveChatController();
        final messages = [
          Message.text(
            id: 'latest',
            authorId: 'user',
            text: 'Latest',
            createdAt: DateTime(2026),
          ),
        ];
        await controller.setMessages(messages);
        var pageIsCurrent = true;

        final cleanup = removeMessagesWhilePageOwned(
          controller: controller,
          messages: messages,
          isPageOwner: () => pageIsCurrent,
        );
        await controller.firstRemovalStarted.future;
        pageIsCurrent = false;
        controller.finishFirstRemoval.complete();

        expect(await cleanup, isFalse);
        expect(controller.messages, isEmpty);
        controller.dispose();
      },
    );

    testWidgets('current conversation search finds paged-out messages', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'active_conversation_id': 'paged-search',
      });
      final repository = MemoryConversationRepository();
      await repository.initialize();
      await repository.importConversation(
        ConversationRecordAdapter.fromLegacyMap({
          'id': 'paged-search',
          'title': 'Paged search',
          'messages': [
            for (var index = 0; index < 240; index++)
              ChatMessage(
                id: 's$index',
                role: index.isEven ? 'user' : 'assistant',
                content: index == 0
                    ? 'needle exists only in earliest page'
                    : 'Message $index content',
                createdAt: DateTime(2025, 1, 1).add(Duration(hours: index)),
              ).toMap(),
          ],
        }),
      );
      addTearDown(repository.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationRepositoryProvider.overrideWithValue(repository),
            activeConversationIdProvider.overrideWith((ref) => 'paged-search'),
            providerEntriesProvider.overrideWith((ref) {
              return ProviderEntriesNotifier();
            }),
          ],
          child: const MaterialApp(home: Material(child: ChatPage())),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.byTooltip('搜索消息'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, ' needle ');
      await tester.pump(const Duration(milliseconds: 300));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('1/1'), findsOneWidget);
      final chat = tester.widget<Chat>(find.byType(Chat));
      expect(
        chat.chatController.messages.map((message) => message.id),
        contains('s0'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('global search navigates to code-only assistant matches', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'active_conversation_id': 'code-search',
      });
      final repository = MemoryConversationRepository();
      await repository.initialize();
      await repository.importConversation(
        ConversationRecordAdapter.fromLegacyMap({
          'id': 'code-search',
          'title': 'Code Search Conversation',
          'messages': [
            for (var index = 0; index < 80; index++)
              ChatMessage(
                id: 'code-search-$index',
                role: index == 0 ? 'assistant' : 'user',
                content: index == 0
                    ? '```dart\nneedle-code-only\n```'
                    : 'Ordinary message $index',
                createdAt: DateTime(2025, 1, 1).add(Duration(hours: index)),
              ).toMap(),
          ],
        }),
      );
      addTearDown(repository.close);
      final streamManager = _SearchStreamManager([
        ChatMessage(
          id: 'code-search-live-user',
          role: 'user',
          content: 'Live question',
          createdAt: DateTime(2025, 1, 5),
        ),
        ChatMessage(
          id: 'code-search-live-assistant',
          role: 'assistant',
          content: 'Live reply',
          createdAt: DateTime(2025, 1, 6),
        ),
      ]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationRepositoryProvider.overrideWithValue(repository),
            chatStreamManagerProvider.overrideWith((ref) => streamManager),
            activeConversationIdProvider.overrideWith((ref) => 'code-search'),
            providerEntriesProvider.overrideWith((ref) {
              return ProviderEntriesNotifier();
            }),
          ],
          child: const MaterialApp(home: Material(child: ChatPage())),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.byTooltip('搜索消息'));
      await tester.pump();
      await tester.tap(find.text('所有对话'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('全局消息搜索'), findsOneWidget);
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == '搜索所有对话中的消息...',
        ),
        'needle-code-only',
      );
      await tester.pump(const Duration(milliseconds: 300));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Code Search Conversation'), findsOneWidget);

      await tester.tap(find.text('Code Search Conversation'));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final chat = tester.widget<Chat>(find.byType(Chat));
      expect(
        chat.chatController.messages.map((message) => message.id),
        contains('code-search-0'),
      );
      expect(find.text('1/1'), findsNothing);
      final target = find.descendant(
        of: find.byType(Chat),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText &&
              (widget.data?.contains('needle-code-only') ?? false),
        ),
      );
      expect(target, findsOneWidget);
      expect(
        tester.getRect(target).overlaps(tester.getRect(find.byType(Chat))),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('current conversation search can retry repository failures', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'active_conversation_id': 'search-retry',
      });
      final repository = _ToggleFailingMessageMemoryRepository();
      await repository.initialize();
      await repository.importConversation(
        ConversationRecordAdapter.fromLegacyMap({
          'id': 'search-retry',
          'title': 'Search retry',
          'messages': [
            ChatMessage(
              id: 'retry-message',
              role: 'user',
              content: 'needle after recovery',
              createdAt: DateTime(2025),
            ).toMap(),
          ],
        }),
      );
      addTearDown(repository.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationRepositoryProvider.overrideWithValue(repository),
            activeConversationIdProvider.overrideWith((ref) => 'search-retry'),
            providerEntriesProvider.overrideWith((ref) {
              return ProviderEntriesNotifier();
            }),
          ],
          child: const MaterialApp(home: Material(child: ChatPage())),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      repository.failMessageReads = true;
      await tester.tap(find.byTooltip('搜索消息'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'needle');
      await tester.pump(const Duration(milliseconds: 300));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('搜索失败'), findsOneWidget);
      repository.failMessageReads = false;
      await tester.tap(find.byTooltip('重试搜索'));
      await tester.pump(const Duration(milliseconds: 300));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('搜索失败'), findsNothing);
      expect(find.text('1/1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('closing global search clears its pending message target', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'active_conversation_id': 'stale-search-target',
      });
      final repository = MemoryConversationRepository();
      await repository.initialize();
      await repository.importConversation(
        ConversationRecordAdapter.fromLegacyMap({
          'id': 'stale-search-target',
          'title': 'Stale Search Target',
          'messages': [
            for (var index = 0; index < 80; index++)
              ChatMessage(
                id: 'stale-search-$index',
                role: index == 0 ? 'assistant' : 'user',
                content: index == 0
                    ? '```dart\nneedle-code-only\n```'
                    : 'Ordinary message $index',
                createdAt: DateTime(2025, 1, 1).add(Duration(hours: index)),
              ).toMap(),
          ],
        }),
      );
      addTearDown(repository.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationRepositoryProvider.overrideWithValue(repository),
            activeConversationIdProvider.overrideWith(
              (ref) => 'stale-search-target',
            ),
            providerEntriesProvider.overrideWith((ref) {
              return ProviderEntriesNotifier();
            }),
          ],
          child: const MaterialApp(home: Material(child: ChatPage())),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.byTooltip('搜索消息'));
      await tester.pump();
      await tester.tap(find.text('所有对话'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == '搜索所有对话中的消息...',
        ),
        'needle-code-only',
      );
      await tester.pump(const Duration(milliseconds: 300));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.tap(find.text('Stale Search Target'));
      // Advance frames without advancing the 250 ms local-search debounce.
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      expect(find.byTooltip('关闭搜索'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.search_off));
      await tester.pump();
      await tester.tap(find.byTooltip('搜索消息'));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'no-local-match');
      await tester.pump(const Duration(milliseconds: 300));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final staleTarget = find.descendant(
        of: find.byType(Chat),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText &&
              (widget.data?.contains('needle-code-only') ?? false),
        ),
      );
      expect(staleTarget, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('closing search cancels pending repository lookup', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'active_conversation_id': 'search-close',
      });
      final repository = _ToggleFailingMessageMemoryRepository();
      await repository.initialize();
      await repository.importConversation(
        ConversationRecordAdapter.fromLegacyMap({
          'id': 'search-close',
          'title': 'Search close',
          'messages': [
            ChatMessage(
              id: 'search-close-message',
              role: 'user',
              content: 'needle',
              createdAt: DateTime(2025),
            ).toMap(),
          ],
        }),
      );
      addTearDown(repository.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationRepositoryProvider.overrideWithValue(repository),
            activeConversationIdProvider.overrideWith((ref) => 'search-close'),
            providerEntriesProvider.overrideWith((ref) {
              return ProviderEntriesNotifier();
            }),
          ],
          child: const MaterialApp(home: Material(child: ChatPage())),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      repository.messageReadCount = 0;

      await tester.tap(find.byTooltip('搜索消息'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'needle');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byIcon(Icons.search_off));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repository.messageReadCount, 0);
      expect(find.byTooltip('关闭搜索'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('old conversation search failure is ignored after switching', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'active_conversation_id': 'search-old',
      });
      final repository = _DeferredMessageMemoryRepository();
      await repository.initialize();
      await repository.importConversation(
        ConversationRecordAdapter.fromLegacyMap({
          'id': 'search-old',
          'title': 'Old conversation',
          'messages': [
            ChatMessage(
              id: 'old-message',
              role: 'user',
              content: 'needle',
              createdAt: DateTime(2025),
            ).toMap(),
          ],
        }),
      );
      await repository.importConversation(
        ConversationRecordAdapter.fromLegacyMap({
          'id': 'new-conversation',
          'title': 'New conversation',
          'messages': [
            ChatMessage(
              id: 'new-message',
              role: 'user',
              content: 'new conversation',
              createdAt: DateTime(2025),
            ).toMap(),
          ],
        }),
      );
      addTearDown(repository.close);
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          chatStreamManagerProvider.overrideWith((ref) {
            return _CompletingStreamManager();
          }),
          activeConversationIdProvider.overrideWith((ref) => 'search-old'),
          providerEntriesProvider.overrideWith((ref) {
            return ProviderEntriesNotifier();
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(conversationsProvider.notifier).ready;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Material(child: ChatPage())),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      repository.deferReads = true;

      await tester.tap(find.byTooltip('搜索消息'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'needle');
      await tester.pump(const Duration(milliseconds: 300));
      await repository.readStarted.future;

      container.read(activeConversationIdProvider.notifier).state =
          'new-conversation';
      repository.pendingRead.completeError(StateError('old read failed'));
      await tester.pump();

      expect(find.text('搜索失败'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'editing a paged message truncates complete repository history',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'active_conversation_id': 'paged-edit',
        });
        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = MemoryConversationRepository();
        await repository.initialize();
        await repository.importConversation(
          ConversationRecordAdapter.fromLegacyMap({
            'id': 'paged-edit',
            'title': 'Paged edit',
            'messages': [
              for (var index = 0; index < 45; index++)
                ChatMessage(
                  id: 'e$index',
                  role: index == 10 ? 'user' : 'assistant',
                  content: 'Message $index content',
                  createdAt: DateTime(2025, 1, 1).add(Duration(hours: index)),
                ).toMap(),
            ],
          }),
        );
        addTearDown(repository.close);
        final manager = _CompletingStreamManager();
        final container = ProviderContainer(
          overrides: [
            conversationRepositoryProvider.overrideWithValue(repository),
            chatStreamManagerProvider.overrideWith((ref) => manager),
            activeConversationIdProvider.overrideWith((ref) => 'paged-edit'),
            providerEntriesProvider.overrideWith((ref) {
              return ProviderEntriesNotifier();
            }),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(conversationsProvider.notifier);
        await notifier.ready;
        expect(
          await notifier.loadMessagesAroundMessage('paged-edit', 'e10'),
          isTrue,
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: ChatPage()),
          ),
        );
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        await tester.tap(find.byTooltip('编辑'));
        await tester.pump();
        await tester.enterText(find.byType(TextField).first, 'Edited message');
        await tester.pump();
        final sendButton = tester
            .widgetList<IconButton>(
              find.widgetWithIcon(IconButton, Icons.send_rounded),
            )
            .firstWhere((button) => button.onPressed != null);
        await tester.tap(find.byWidget(sendButton));
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(manager.receivedHistories, hasLength(1));
        expect(manager.receivedHistories.single.first.id, 'e0');
        expect(manager.receivedHistories.single, hasLength(11));
        expect(manager.receivedHistories.single.last.content, 'Edited message');
        expect(
          (await repository.getMessages(
            'paged-edit',
          ))
              .map((message) => message.id),
          isNot(contains('e10')),
        );
        expect(
          (await repository.getMessages(
            'paged-edit',
          ))
              .map((message) => message.id),
          isNot(contains('e44')),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'retry after opening a long conversation retains full context',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'active_conversation_id': 'paged-retry',
        });
        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = MemoryConversationRepository();
        await repository.initialize();
        await repository.importConversation(
          StroomConversation(
            id: 'paged-retry',
            title: 'Paged retry',
            messages: [
              for (var index = 0; index < 45; index++)
                StroomMessage(
                  id: 'r$index',
                  role: index == 25 ? 'assistant' : 'user',
                  sequence: index,
                  createdAt: DateTime(2025, 1, 1).add(Duration(hours: index)),
                  content: [StroomContentPart.text('Message $index content')],
                ),
            ],
          ),
        );
        addTearDown(repository.close);
        final manager = _CompletingStreamManager();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              conversationRepositoryProvider.overrideWithValue(repository),
              chatStreamManagerProvider.overrideWith((ref) => manager),
              activeConversationIdProvider.overrideWith((ref) => 'paged-retry'),
              providerEntriesProvider.overrideWith((ref) {
                return ProviderEntriesNotifier();
              }),
            ],
            child: const MaterialApp(home: ChatPage()),
          ),
        );
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        final retryButtons = find.byIcon(Icons.refresh);
        expect(retryButtons, findsWidgets);
        await tester.tap(retryButtons.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('确定'));
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(manager.receivedHistories, hasLength(1));
        expect(manager.receivedHistories.single.first.id, 'r0');
        expect(manager.receivedHistories.single, hasLength(25));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('retry stops if the active conversation changes during load', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'active_conversation_id': 'retry-old',
      });
      final repository = _DeferredFullHistoryMemoryRepository();
      await repository.initialize();
      await repository.importConversation(
        StroomConversation(
          id: 'retry-old',
          title: 'Old retry conversation',
          messages: [
            for (var index = 0; index < 45; index++)
              StroomMessage(
                id: 'old-r$index',
                role: index == 44 ? 'assistant' : 'user',
                sequence: index,
                createdAt: DateTime(2025, 1, 1).add(Duration(hours: index)),
                content: [StroomContentPart.text('Old message $index')],
              ),
          ],
        ),
      );
      await repository.importConversation(
        StroomConversation(
          id: 'retry-new',
          title: 'New retry conversation',
          messages: [
            StroomMessage(
              id: 'new-r0',
              role: 'user',
              sequence: 0,
              createdAt: DateTime(2025),
              content: [StroomContentPart.text('New conversation message')],
            ),
          ],
        ),
      );
      final oldRows = await repository.getMessages('retry-old', limit: 100);
      addTearDown(repository.close);
      final manager = _CompletingStreamManager();
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          chatStreamManagerProvider.overrideWith((ref) => manager),
          activeConversationIdProvider.overrideWith((ref) => 'retry-old'),
          providerEntriesProvider.overrideWith((ref) {
            return ProviderEntriesNotifier();
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(conversationsProvider.notifier).ready;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Material(child: ChatPage())),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      repository.deferFullReads = true;

      await tester.tap(find.byIcon(Icons.refresh).first);
      await tester.pump();
      await tester.tap(find.text('确定'));
      await tester.pump();
      await repository.readStarted.future;

      container.read(activeConversationIdProvider.notifier).state = 'retry-new';
      repository.pendingRead.complete(oldRows);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(manager.receivedHistories, isEmpty);
      expect(await repository.countMessages(conversationId: 'retry-old'), 45);
      expect(await repository.countMessages(conversationId: 'retry-new'), 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('sending after loading an older page does not duplicate it', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'active_conversation_id': 'paged-send',
      });
      final repository = MemoryConversationRepository();
      await repository.initialize();
      await repository.importConversation(
        ConversationRecordAdapter.fromLegacyMap({
          'id': 'paged-send',
          'title': 'Paged send',
          'messages': [
            for (var index = 0; index < 45; index++)
              ChatMessage(
                id: 'm$index',
                role: index == 5 || index == 6
                    ? 'assistant'
                    : index.isEven
                        ? 'user'
                        : 'assistant',
                content: index == 6
                    ? 'Repeated paged text'
                    : 'Message $index content',
                createdAt: DateTime(2025, 1, 1).add(Duration(hours: index)),
                reasoningSections:
                    index == 5 ? ['Reasoning for paged message'] : null,
                textSections: index == 5 ? ['Message $index content'] : null,
                toolCalls: index == 5
                    ? [
                        ToolCallData(
                          id: 'call-$index',
                          name: 'web_search',
                          arguments: const {'query': 'paged history'},
                          status: ToolCallStatus.completed,
                          result: 'Paged result',
                        ),
                      ]
                    : null,
                toolCallRoundStarts: index == 5 ? const [0] : null,
                blocks: index == 6
                    ? const [TextBlock(text: 'Repeated paged text')]
                    : null,
              ).toMap(),
          ],
        }),
      );
      addTearDown(repository.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationRepositoryProvider.overrideWithValue(repository),
            chatStreamManagerProvider.overrideWith(
              (ref) => _CompletingStreamManager(),
            ),
            activeConversationIdProvider.overrideWith((ref) => 'paged-send'),
            providerEntriesProvider.overrideWith((ref) {
              return ProviderEntriesNotifier();
            }),
          ],
          child: const MaterialApp(home: ChatPage()),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await dragToTop(tester);
      await tester.pump(const Duration(milliseconds: 600));
      await settleAnchor(tester);
      var chat = tester.widget<Chat>(find.byType(Chat));
      expect(chat.chatController.messages.map((message) => message.id), [
        for (var i = 5; i < 45; i++) 'm$i',
      ]);

      final loadedPageMessage =
          ProviderScope.containerOf(tester.element(find.byType(ChatPage)))
              .read(conversationsProvider)
              .single
              .messages
              .singleWhere((message) => message.id == 'm5');
      expect(loadedPageMessage.toolCalls?.single.name, 'web_search');
      await dragToTop(tester);
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(find.byType(ToolCallCard), findsOneWidget);
      expect(find.text('Repeated paged text'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      final sendButtons = tester
          .widgetList<IconButton>(
            find.widgetWithIcon(IconButton, Icons.send_rounded),
          )
          .where((button) => button.onPressed != null);
      await tester.tap(find.byWidget(sendButtons.first));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      chat = tester.widget<Chat>(find.byType(Chat));
      final latestWindowIds =
          chat.chatController.messages.map((message) => message.id).toList();
      expect(latestWindowIds, isNot(contains('m5')));
      expect(latestWindowIds, isNot(contains('m24')));
      expect(latestWindowIds.toSet(), hasLength(latestWindowIds.length));

      await dragToTop(tester);
      await tester.pump(const Duration(milliseconds: 600));
      chat = tester.widget<Chat>(find.byType(Chat));
      final pagedIds =
          chat.chatController.messages.map((message) => message.id).toList();
      expect(pagedIds.toSet(), hasLength(pagedIds.length));
      expect(pagedIds, contains('m6'));
      expect(pagedIds, contains('m25'));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'spinner exists only while actually loading and is removed from the '
      'tree when the load ends',
      (tester) async {
        await pumpConversation(tester, messageCount: 35);

        // Idle: the indicator must not be in the widget tree at all, so its
        // animation cannot run while it is not displayed.
        expect(
          find.byKey(loadMoreIndicatorKey),
          findsNothing,
          reason: 'no pagination load running -> no spinner in the tree',
        );

        // Scroll to the top: the first page of older messages loads.
        await dragToTop(tester);
        expect(
          find.byKey(loadMoreIndicatorKey),
          findsOneWidget,
          reason: 'spinner must show while the older-messages load runs',
        );

        // The load itself is instantaneous; only the minimum display window
        // keeps the spinner alive. It must still be up 250ms later...
        await tester.pump(const Duration(milliseconds: 250));
        expect(
          find.byKey(loadMoreIndicatorKey),
          findsOneWidget,
          reason: 'spinner must stay visible at least 500ms after the '
              'load finished',
        );

        // ...and must be gone once the minimum display window has passed.
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.byKey(loadMoreIndicatorKey),
          findsNothing,
          reason: 'spinner is removed from the tree when the load ends',
        );
        final chat = tester.widget<Chat>(find.byType(Chat));
        expect(
          chat.chatController.messages.length,
          35,
          reason: 'the older-messages page was inserted after the '
              'minimum display window',
        );

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
        'no-more-content hint appears only after reaching the top with '
        'nothing left to load', (tester) async {
      await pumpConversation(tester, messageCount: 35);

      // First pass to the top: a page of older messages is still available,
      // so the hint must not appear.
      await dragToTop(tester);
      await tester.pump(const Duration(milliseconds: 600));
      // Let the library's anchor scroll corrections settle before the next
      // drag (the fake clock skips the 500ms minimum display in one frame,
      // so those frame-based corrections have not run yet).
      await settleAnchor(tester);
      expect(
        find.text(noMoreMessagesText),
        findsNothing,
        reason: 'no hint while older pages remain',
      );

      // Second pass to the top: everything is loaded now, so the hint
      // appears above the first message.
      await dragToTop(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.text(noMoreMessagesText),
        findsOneWidget,
        reason: 'hint appears at the top when there is no more content',
      );

      await tester.pumpWidget(const SizedBox());
    });
    testWidgets(
      'no hint while scrolling mid-list in a fully loaded conversation',
      (tester) async {
        // 15 messages < one page: everything is loaded, but the content is
        // tall enough to scroll.
        await pumpConversation(tester, messageCount: 15);

        // A short upward drag that stays mid-list must not arm the hint
        // (the UserScrollNotification path is gated on being near the top).
        await tester.drag(find.byType(ChatPage), const Offset(0, 100));
        await tester.pump();
        await tester.pump();
        expect(
          find.text(noMoreMessagesText),
          findsNothing,
          reason: 'mid-list upward drag must not show the hint',
        );

        // Reaching the actual top does.
        await tester.drag(find.byType(ChatPage), const Offset(0, 6000));
        await tester.pump();
        await tester.pump();
        expect(
          find.text(noMoreMessagesText),
          findsOneWidget,
          reason: 'reaching the top of a fully loaded conversation shows '
              'the hint',
        );

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
        'short conversation: no hint on entry; hint appears only after '
        'the user pulls at the top', (tester) async {
      // Fewer messages than one page: everything is loaded from the start,
      // so reaching the top means "no more content" — but only after the
      // user actually reaches it, not on entry.
      await pumpConversation(tester, messageCount: 5);
      expect(
        find.text(noMoreMessagesText),
        findsNothing,
        reason: 'no hint on entry, before any user scroll',
      );

      // The list cannot scroll (all content fits), so the user's pull at
      // the top produces no pixel change — the UserScrollNotification path
      // must surface the hint.
      await tester.drag(find.byType(ChatPage), const Offset(0, 200));
      await tester.pump();
      await tester.pump();
      expect(
        find.text(noMoreMessagesText),
        findsOneWidget,
        reason: 'pull at the top of a fully-loaded conversation shows '
            'the hint',
      );

      await tester.pumpWidget(const SizedBox());
    });
  });
}
