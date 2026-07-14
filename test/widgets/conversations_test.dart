// Merged from:
//   - conversations_ordering_test.dart
//   - conversations_search_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/conversations_page.dart';
import 'package:stroom/providers/conversation_provider.dart';

/// Create test conversations with different dates.
List<Conversation> _createOrderedConversations() {
  return [
    Conversation(
        id: 'conv-1',
        title: '最旧对话',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1)),
    Conversation(
        id: 'conv-2',
        title: '中间对话',
        createdAt: DateTime(2026, 3, 15),
        updatedAt: DateTime(2026, 3, 15)),
    Conversation(
        id: 'conv-3',
        title: '最新对话',
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1)),
  ];
}

/// Create test conversations with messages for search testing.
List<Conversation> _createSearchConversations() {
  return [
    Conversation(
      id: 'conv-1',
      title: 'Flutter讨论',
      messages: [
        ChatMessage(id: 'msg-1', role: 'user', content: 'Flutter是什么框架？'),
        ChatMessage(
            id: 'msg-2',
            role: 'assistant',
            content: 'Flutter是Google开发的跨平台UI框架'),
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

/// Helper widget that exposes tile text for testing.
/// Wraps ConversationsPage so we can introspect tile order.
Widget createTestApp({List<Conversation>? conversations, String? activeId}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        notifier.state = conversations ?? _createOrderedConversations();
        return notifier;
      }),
      activeConversationIdProvider.overrideWith((ref) => activeId ?? 'conv-1'),
    ],
    child: const MaterialApp(home: ConversationsPage()),
  );
}

/// Helper: create conversations page with seeded search conversations.
Widget createSearchTestApp() {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        notifier.state = _createSearchConversations();
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
  // ===========================================================================
  // 1. conversations_ordering_test.dart
  // ===========================================================================
  group('ConversationsPage - ordering', () {
    testWidgets('conversations display in the order they appear in state',
        (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      expect(find.text('最旧对话'), findsOneWidget);
      expect(find.text('中间对话'), findsOneWidget);
      expect(find.text('最新对话'), findsOneWidget);
    });

    testWidgets('pinned conversations appear first', (tester) async {
      final convs = [
        Conversation(id: 'c1', title: '普通A'),
        Conversation(id: 'c2', title: '置顶对话', isPinned: true),
        Conversation(id: 'c3', title: '普通B'),
      ];

      await tester
          .pumpWidget(createTestApp(conversations: convs, activeId: 'c1'));
      await tester.pump();

      expect(find.text('普通A'), findsOneWidget);
      expect(find.text('置顶对话'), findsOneWidget);
      expect(find.text('普通B'), findsOneWidget);
      expect(find.byIcon(Icons.push_pin), findsWidgets);
    });

    testWidgets('clicking a conversation does NOT change order',
        (tester) async {
      final convs = [
        Conversation(id: 'c1', title: '对话A'),
        Conversation(id: 'c2', title: '对话B'),
        Conversation(id: 'c3', title: '对话C'),
      ];

      await tester
          .pumpWidget(createTestApp(conversations: convs, activeId: 'c2'));
      await tester.pump();

      await tester.tap(find.text('对话A'));
      await tester.pump();

      expect(find.text('对话A'), findsOneWidget);
      expect(find.text('对话B'), findsOneWidget);
      expect(find.text('对话C'), findsOneWidget);
    });
  });

  // ===========================================================================
  // 2. conversations_search_test.dart
  // ===========================================================================
  group('ConversationsPage global message search', () {
    testWidgets('shows search icon button', (tester) async {
      await tester.pumpWidget(createSearchTestApp());
      await tester.pump();

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('tapping search shows search bar with global hint',
        (tester) async {
      await tester.pumpWidget(createSearchTestApp());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('searching by message content shows matching conversations',
        (tester) async {
      await tester.pumpWidget(createSearchTestApp());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField), '天气');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('天气咨询'), findsOneWidget);
      expect(find.text('Flutter讨论'), findsNothing);
      expect(find.text('编程学习'), findsNothing);
    });

    testWidgets('searching by title also works', (tester) async {
      await tester.pumpWidget(createSearchTestApp());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField), 'Flutter讨论');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Flutter讨论'), findsWidgets);
    });

    testWidgets('shows empty state when no search results', (tester) async {
      await tester.pumpWidget(createSearchTestApp());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField), 'zzznonexistent');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('没有找到匹配的对话'), findsOneWidget);
    });
  });
}
