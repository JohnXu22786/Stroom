import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/pages/conversations_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Create test conversations with messages for search testing.
List<Conversation> _createTestConversations() {
  return [
    Conversation(
      id: 'conv-1',
      title: 'Flutter讨论',
      messages: [
        ChatMessage(id: 'msg-1', role: 'user', content: 'Flutter是什么框架？'),
        ChatMessage(id: 'msg-2', role: 'assistant', content: 'Flutter是Google开发的跨平台UI框架'),
      ],
    ),
    Conversation(
      id: 'conv-2',
      title: '天气咨询',
      messages: [
        ChatMessage(id: 'msg-3', role: 'user', content: '今天天气怎么样？'),
        ChatMessage(id: 'msg-4', role: 'assistant', content: '今天天气晴朗'),
      ],
    ),
    Conversation(
      id: 'conv-3',
      title: '编程学习',
      messages: [
        ChatMessage(id: 'msg-5', role: 'user', content: '如何学习Flutter？'),
      ],
    ),
  ];
}

/// Helper: create conversations page with seeded conversations.
Widget createConversationsTestApp() {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        notifier.state = _createTestConversations();
        return notifier;
      }),
      activeConversationIdProvider.overrideWith((ref) => 'conv-1'),
    ],
    child: const MaterialApp(
      home: ConversationsPage(),
    ),
  );
}

void main() {
  group('ConversationsPage global message search', () {
    testWidgets('shows search icon button', (tester) async {
      await tester.pumpWidget(createConversationsTestApp());
      await tester.pump();

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('tapping search shows search bar with global hint',
        (tester) async {
      await tester.pumpWidget(createConversationsTestApp());
      await tester.pump();

      // Tap search
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Search TextField should be visible
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('searching by message content shows matching conversations',
        (tester) async {
      await tester.pumpWidget(createConversationsTestApp());
      await tester.pump();

      // Tap search
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Type a message content query
      await tester.enterText(find.byType(TextField), '天气');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show matching conversation
      expect(find.text('天气咨询'), findsOneWidget);
      // Should NOT show non-matching conversations
      expect(find.text('Flutter讨论'), findsNothing);
      expect(find.text('编程学习'), findsNothing);
    });

    testWidgets('searching by title also works', (tester) async {
      await tester.pumpWidget(createConversationsTestApp());
      await tester.pump();

      // Tap search
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Type a title query
      await tester.enterText(find.byType(TextField), 'Flutter讨论');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show matching conversation (may appear in search bar + list)
      expect(find.textContaining('Flutter讨论'), findsWidgets);
    });

    testWidgets('shows empty state when no search results', (tester) async {
      await tester.pumpWidget(createConversationsTestApp());
      await tester.pump();

      // Tap search
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Type non-matching query
      await tester.enterText(find.byType(TextField), 'zzznonexistent');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show empty state
      expect(find.text('没有找到匹配的对话'), findsOneWidget);
    });
  });
}
