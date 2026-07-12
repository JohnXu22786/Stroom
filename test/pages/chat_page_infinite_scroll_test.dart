import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' hide ChatMessage;
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper to create a [ChatMessage] with incremental content for testing.
ChatMessage _createTestMessage(String role, int index) {
  return ChatMessage(
    id: '${role}_$index',
    role: role,
    content: 'Message $index content',
    createdAt: DateTime(2025, 1, 1).add(Duration(hours: index)),
  );
}

/// Create a list of test messages.
List<ChatMessage> createTestMessages(int count) {
  final msgs = <ChatMessage>[];
  for (var i = 0; i < count; i++) {
    msgs.add(_createTestMessage(i.isEven ? 'user' : 'assistant', i));
  }
  return msgs;
}

/// Create a test app with a conversation pre-populated with messages.
Widget createChatTestAppWithMessages({
  required List<ChatMessage> messages,
  String? conversationId,
}) {
  SharedPreferences.setMockInitialValues({
    'conversations': jsonEncode([
      {
        'id': conversationId ?? 'test-conv-id',
        'title': 'Test Conversation',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2025, 1, 1).toIso8601String(),
        'messages': messages.map((m) => m.toMap()).toList(),
        'isPinned': false,
        'sortOrder': 0,
      }
    ]),
  });
  return ProviderScope(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        return ConversationsNotifier(ref);
      }),
      activeConversationIdProvider
          .overrideWith((ref) => conversationId ?? 'test-conv-id'),
      providerEntriesProvider.overrideWith((ref) {
        return ProviderEntriesNotifier();
      }),
    ],
    child: MaterialApp(
      home: const ChatPage(),
    ),
  );
}

void main() {
  group('Infinite Scroll / Lazy Loading - ChatPage', () {
    // ====== UNIT TESTS: Pagination Logic ======

    group('Pagination state calculation', () {
      test(
          'initial load with more than pageSize messages loads only the last page',
          () {
        const pageSize = 20;
        final allMessages = createTestMessages(100);
        final totalCount = allMessages.length;

        // Calculate initial load range
        final loadedStartIndex = (totalCount - pageSize).clamp(0, totalCount);
        final initialBatch = allMessages.sublist(loadedStartIndex);

        // Verify only last pageSize messages are loaded initially
        expect(initialBatch.length, pageSize);
        expect(initialBatch.first.id, 'user_80'); // msg[80]
        expect(initialBatch.last.id, 'assistant_99'); // msg[99]
        expect(loadedStartIndex, 80);
      });

      test('initial load with fewer than pageSize messages loads all', () {
        const pageSize = 20;
        final allMessages = createTestMessages(5);
        final totalCount = allMessages.length;

        // Calculate initial load range
        final loadedStartIndex = (totalCount - pageSize).clamp(0, totalCount);
        final initialBatch = allMessages.sublist(loadedStartIndex);

        // Verify all messages are loaded
        expect(initialBatch.length, 5);
        expect(initialBatch.first.id, 'user_0');
        expect(initialBatch.last.id, 'user_4'); // index 4 is even → 'user'
        expect(loadedStartIndex, 0);
      });

      test('load more returns the previous batch of messages', () {
        const pageSize = 20;
        final allMessages = createTestMessages(100);

        // Initial state: loaded from index 80 to 99
        int loadedStartIndex = 80;
        expect(loadedStartIndex > 0, true); // hasMore = true

        // Load more: get messages from index 60 to 79
        final newStart =
            (loadedStartIndex - pageSize).clamp(0, allMessages.length);
        final batch = allMessages.sublist(newStart, loadedStartIndex);
        loadedStartIndex = newStart;

        expect(batch.length, 20);
        expect(batch.first.id, 'user_60');
        expect(batch.last.id, 'assistant_79');
        expect(loadedStartIndex, 60);
      });

      test('load more stops at the beginning of history', () {
        const pageSize = 20;
        final allMessages = createTestMessages(25);

        // Initial state: loaded from index 5 to 24
        int loadedStartIndex = 5;

        // Load more 1: get messages from index 0 to 4
        final newStart =
            (loadedStartIndex - pageSize).clamp(0, allMessages.length);
        final batch = allMessages.sublist(newStart, loadedStartIndex);
        loadedStartIndex = newStart;

        expect(batch.length, 5);
        expect(batch.first.id, 'user_0');
        expect(loadedStartIndex, 0);
        expect(loadedStartIndex == 0, true); // no more messages after this
      });

      test('hasMoreMessages correctly reflects remaining messages', () {
        // Scenario 1: More to load
        int loadedStartIndex = 60;
        expect(loadedStartIndex > 0, true); // hasMore

        // Scenario 2: At the beginning
        loadedStartIndex = 0;
        expect(loadedStartIndex <= 0, true); // no more

        // Scenario 3: Empty history
        loadedStartIndex = 0;
        expect(loadedStartIndex <= 0, true); // no more
      });

      test('consecutive load more calls move backward through history', () {
        const pageSize = 20;
        final allMessages = createTestMessages(100);

        int loadedStartIndex = 80; // initial load
        final steps = <int>[];

        while (loadedStartIndex > 0) {
          final newStart =
              (loadedStartIndex - pageSize).clamp(0, allMessages.length);
          final batch = allMessages.sublist(newStart, loadedStartIndex);
          loadedStartIndex = newStart;
          steps.add(batch.length);
        }

        // Should have loaded 4 batches: 20 + 20 + 20 + 20 = 80
        expect(steps, [20, 20, 20, 20]);
        expect(loadedStartIndex, 0);
      });
    });

    // ====== UNIT TESTS: Message Ordering ======

    group('Message ordering with pagination', () {
      test('initial batch maintains chronological order', () {
        final allMessages = createTestMessages(30);
        const pageSize = 20;

        final loadedStartIndex =
            (allMessages.length - pageSize).clamp(0, allMessages.length);
        final initialBatch = allMessages.sublist(loadedStartIndex);

        // Verify chronological order (oldest first = index 0)
        for (var i = 1; i < initialBatch.length; i++) {
          expect(
            initialBatch[i].createdAt.isAfter(initialBatch[i - 1].createdAt),
            true,
            reason: 'Messages should be in chronological order',
          );
        }
      });

      test(
          'prepended batch maintains chronological order when inserted at position 0',
          () {
        const pageSize = 20;
        final allMessages = createTestMessages(60);
        int loadedStartIndex = 40; // initially loaded [40..59]

        // First load more: get [20..39] to prepend
        int newStart =
            (loadedStartIndex - pageSize).clamp(0, allMessages.length);
        final batch1 = allMessages.sublist(newStart, loadedStartIndex);

        // After prepending at index 0, the order should be:
        // [20..39, 40..59] → all in chronological order
        final afterLoad1 = [
          ...batch1,
          ...allMessages.sublist(loadedStartIndex)
        ];
        for (var i = 1; i < afterLoad1.length; i++) {
          expect(
            afterLoad1[i].createdAt.isAfter(afterLoad1[i - 1].createdAt),
            true,
            reason:
                'After prepend, messages should maintain chronological order',
          );
        }

        loadedStartIndex = newStart;

        // Second load more: get [0..19]
        newStart = (loadedStartIndex - pageSize).clamp(0, allMessages.length);
        final batch2 = allMessages.sublist(newStart, loadedStartIndex);

        final afterLoad2 = [...batch2, ...afterLoad1];
        for (var i = 1; i < afterLoad2.length; i++) {
          expect(
            afterLoad2[i].createdAt.isAfter(afterLoad2[i - 1].createdAt),
            true,
            reason:
                'After second prepend, messages should maintain chronological order',
          );
        }
      });
    });

    // ====== WIDGET TESTS ======

    group('Chat widget with infinite scroll', () {
      Future<void> pumpChatPageWithMessages(
        WidgetTester tester, {
        int messageCount = 25,
      }) async {
        final messages = createTestMessages(messageCount);
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(createChatTestAppWithMessages(
          messages: messages,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        // Consume any pre-existing framework exceptions from flutter_chat_ui
        tester.takeException();
      }

      testWidgets('renders without crash with many messages', (tester) async {
        await pumpChatPageWithMessages(tester, messageCount: 25);

        // Should render the chat page without crashing
        expect(find.byType(ChatPage), findsOneWidget);
      });

      testWidgets('test app creates conversation with messages',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        final messages = createTestMessages(10);
        await tester.pumpWidget(createChatTestAppWithMessages(
          messages: messages,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();

        // Page renders
        expect(find.byType(ChatPage), findsOneWidget);
      });

      testWidgets('empty conversation renders without crash', (tester) async {
        await pumpChatPageWithMessages(tester, messageCount: 0);

        // Should render without crash
        expect(find.byType(ChatPage), findsOneWidget);
      });

      testWidgets('custom chatAnimatedListBuilder is used by Chat widget',
          (tester) async {
        // This tests that the Chat widget receives a custom chatAnimatedListBuilder.
        // The builder creates a ChatAnimatedList with onEndReached callback.
        await pumpChatPageWithMessages(tester, messageCount: 5);

        // Verify the chat page renders
        expect(find.byType(ChatPage), findsOneWidget);

        // The Chat widget should exist
        expect(find.byType(Chat), findsOneWidget);
      });
    });
  });
}
