// Merged from:
//   - conversations_ordering_test.dart
//   - conversations_search_test.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/stroom_conversation.dart';
import 'package:stroom/pages/conversations_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/services/conversation_repository.dart';

class _DeferredFailureRepository extends MemoryConversationRepository {
  final readStarted = Completer<void>();
  final pendingRead = Completer<List<StroomMessage>>();

  @override
  Future<List<StroomMessage>> getMessages(
    String conversationId, {
    int offset = 0,
    int limit = 50,
  }) {
    if (!readStarted.isCompleted) readStarted.complete();
    return pendingRead.future;
  }
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
          content: 'Flutter是Google开发的跨平台UI框架',
        ),
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
    child: const MaterialApp(home: ConversationsPage()),
  );
}

void main() {
  // ===========================================================================
  // 2. conversations_search_test.dart
  // ===========================================================================
  group('ConversationsPage global message search', () {
    testWidgets('closing search ignores a later repository failure', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final repository = _DeferredFailureRepository();
      await repository.initialize();
      await repository.upsertConversation(
        StroomConversation(id: 'pending-search', title: 'Pending search'),
      );
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          activeConversationIdProvider.overrideWith((ref) => 'pending-search'),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.close();
      });
      await container.read(conversationsProvider.notifier).ready;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ConversationsPage()),
        ),
      );
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'pending');
      await tester.pump(const Duration(milliseconds: 300));
      await repository.readStarted.future;

      await tester.tap(find.byIcon(Icons.close));
      repository.pendingRead.completeError(StateError('read failed'));
      await tester.pump();

      expect(find.text('搜索失败'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('searching by message content shows matching conversations', (
      tester,
    ) async {
      await tester.pumpWidget(createSearchTestApp());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField), '天气');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('没有找到匹配的对话'), findsOneWidget);
    });
  });
}
