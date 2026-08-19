// Widget tests for chat search: markdown must survive search (only the
// matching text is highlighted), and the up/down navigation must jump
// between matches — including jumping to matches in older messages that
// lazy pagination has not loaded yet.

import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' hide ChatMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';

Widget _buildApp({String? initialSearchQuery}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        return ConversationsNotifier(ref);
      }),
      activeConversationIdProvider.overrideWith((ref) => 'test-conv-id'),
      providerEntriesProvider.overrideWith((ref) {
        return ProviderEntriesNotifier();
      }),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ChatPage(initialSearchQuery: initialSearchQuery),
      ),
    ),
  );
}

Future<void> _pumpChat(
  WidgetTester tester, {
  required List<ChatMessage> messages,
  String? initialSearchQuery,
}) async {
  await tester.pumpWidget(_buildApp(initialSearchQuery: initialSearchQuery));
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
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

List<ChatMessage> _messages() {
  return [
    ChatMessage(
      id: 'u1',
      role: 'user',
      content: 'Hello there',
      createdAt: DateTime(2025, 1, 1, 1),
    ),
    ChatMessage(
      id: 'a1',
      role: 'assistant',
      content: '**bold** term here and *em* term too',
      createdAt: DateTime(2025, 1, 1, 2),
    ),
    // A code fence containing the query: that occurrence can never be
    // highlighted (the fence renders as a dedicated code widget), so search
    // must not count it — the counter below would otherwise be 1/4.
    ChatMessage(
      id: 'a2',
      role: 'assistant',
      content: '```\nterm\n```\nterm in prose',
      createdAt: DateTime(2025, 1, 1, 3),
    ),
  ];
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

  group('ChatPage search keeps markdown and highlights matches', () {
    testWidgets('search does not flatten markdown into plain text',
        (tester) async {
      await _pumpChat(tester,
          messages: _messages(), initialSearchQuery: 'term');

      // Search bar is active.
      expect(find.text('搜索当前对话...'), findsOneWidget);

      // The markdown is still parsed: no literal asterisks anywhere.
      expect(find.textContaining('**', findRichText: true), findsNothing,
          reason: 'markdown must not be flattened to raw text during search');

      // The rendered text is the parsed markdown (bold/emphasis applied).
      expect(
        find.textContaining('bold term here and em term too',
            findRichText: true),
        findsOneWidget,
        reason: 'the parsed markdown text must still be rendered',
      );

      // Match counter shows 1 of 3 matches: two prose occurrences in a1 plus
      // one in a2 — the "term" inside a2's code fence is NOT counted.
      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('up/down buttons move the current match counter',
        (tester) async {
      await _pumpChat(tester,
          messages: _messages(), initialSearchQuery: 'term');

      expect(find.text('1/3'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pump();
      await tester.pump();
      expect(find.text('2/3'), findsOneWidget,
          reason: 'down button must advance to the second match');

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pump();
      await tester.pump();
      expect(find.text('3/3'), findsOneWidget,
          reason: 'down button must advance to the third match');

      await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
      await tester.pump();
      await tester.pump();
      expect(find.text('2/3'), findsOneWidget,
          reason: 'up button must go back to the previous match');
    });

    testWidgets('navigation loads older (unloaded) messages to reach a match',
        (tester) async {
      // 35 messages: only the last 20 are inserted into the chat controller
      // initially. The first match lives in message m0, which is unloaded.
      final messages = <ChatMessage>[
        for (var i = 0; i < 35; i++)
          ChatMessage(
            id: 'm$i',
            role: i.isEven ? 'user' : 'assistant',
            content: 'Message $i content',
            createdAt: DateTime(2025, 1, 1).add(Duration(hours: i)),
          ),
      ];
      await _pumpChat(
        tester,
        messages: messages,
        initialSearchQuery: 'Message 0 content',
      );

      // Only one match (message 0), so the counter is 1/1 — and reaching it
      // must have pulled the older page into the controller.
      final chat = tester.widget<Chat>(find.byType(Chat));
      expect(chat.chatController.messages.length, 35,
          reason: 'scrolling to the first match must load the older '
              'messages that contain it');
      expect(find.text('1/1'), findsOneWidget);

      // The observer-based scroll-to-message runs asynchronously (it scrolls
      // towards the target iteratively until the lazy item is built). Pump
      // until message 0's bubble actually appears — scoped to the chat list
      // so the search bar's TextField (which also contains the query text)
      // cannot satisfy the finder — proving the navigation really jumped.
      final matchInChat = find.descendant(
        of: find.byType(Chat),
        matching: find.text('Message 0 content'),
      );
      var scrolledToMatch = false;
      for (var i = 0; i < 80 && !scrolledToMatch; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        scrolledToMatch = tester.any(matchInChat);
      }
      expect(scrolledToMatch, isTrue,
          reason: 'navigation must scroll until the matched message is built');

      // Let the observer finish its final alignment (it scrolls iteratively
      // and then animates to the target position) before measuring.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final bubbleRect = tester.getRect(matchInChat);
      final pageSize = tester.getSize(find.byType(ChatPage));
      expect(bubbleRect.top, lessThan(pageSize.height),
          reason: 'the matched message must be inside the viewport');
      expect(bubbleRect.bottom, greaterThan(0),
          reason: 'the matched message must be inside the viewport');
    });
  });
}
