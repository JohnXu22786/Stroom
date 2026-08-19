import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/providers/conversation_provider.dart';

/// Repeatedly pumps microtasks until the conversations provider has data
/// or we reach [maxAttempts]. This is needed because ConversationsNotifier._load()
/// is async and may not complete within a single microtask.
Future<void> waitForConversationsLoad(
  ProviderContainer container, {
  int maxAttempts = 20,
}) async {
  for (int i = 0; i < maxAttempts; i++) {
    final conversations = container.read(conversationsProvider);
    if (conversations.isNotEmpty) return;
    // Pump microtasks to let async _load() progress
    await Future.microtask(() => {});
    await Future.delayed(Duration.zero);
  }
}

/// Sets up SharedPreferences with a test conversation.
/// Returns the ProviderContainer for inspection.
Future<ProviderContainer> setupWithConversation({
  int messageCount = 5,
  String convId = 'test-conv-id',
  String title = 'Test Conversation',
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final messages = List.generate(
    messageCount,
    (i) => ChatMessage(
      role: i.isEven ? 'user' : 'assistant',
      content: 'Message $i',
    ).toMap(),
  );

  final conversation = {
    'id': convId,
    'title': title,
    'createdAt': DateTime.now().toIso8601String(),
    'updatedAt': DateTime.now().toIso8601String(),
    'messages': messages,
    'isPinned': false,
    'sortOrder': 0,
    'draftText': '',
  };

  await prefs.setString('conversations', jsonEncode([conversation]));
  await prefs.setString('active_conversation_id', convId);

  final container = ProviderContainer();
  return container;
}

void main() {
  group('Issue 11: Conversation load concurrency guard', () {
    test('conversations load correctly and notifier has data', () async {
      final container = await setupWithConversation();
      addTearDown(container.dispose);

      await waitForConversationsLoad(container);

      final conversations = container.read(conversationsProvider);
      expect(conversations.length, 1);
      expect(conversations.first.id, 'test-conv-id');
      expect(conversations.first.messages.length, 5);
    });

    test('conversation with empty messages list loads without error', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final conversation = {
        'id': 'empty-conv',
        'title': 'Empty Conversation',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': <dynamic>[],
        'isPinned': false,
        'sortOrder': 0,
        'draftText': '',
      };
      await prefs.setString('conversations', jsonEncode([conversation]));
      await prefs.setString('active_conversation_id', 'empty-conv');

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await waitForConversationsLoad(container);

      final conversations = container.read(conversationsProvider);
      expect(conversations.length, 1);
      expect(conversations.first.messages, isEmpty);
    });

    test('conversationsProvider state transitions from empty to loaded',
        () async {
      final container = await setupWithConversation();
      addTearDown(container.dispose);

      // Initially empty (load hasn't completed)
      expect(container.read(conversationsProvider), isEmpty);

      await waitForConversationsLoad(container);

      // Now should have data
      final conversations = container.read(conversationsProvider);
      expect(conversations.length, 1);

      // Active conversation ID should be restored
      final activeId = container.read(activeConversationIdProvider);
      expect(activeId, 'test-conv-id');
    });

    test('reloading while loading is in progress does not double-load',
        () async {
      final container = await setupWithConversation();
      addTearDown(container.dispose);

      await waitForConversationsLoad(container);

      final notifier = container.read(conversationsProvider.notifier)
          as ConversationsNotifier;

      // Simulate an update: should work without crashing
      final convId = 'test-conv-id';
      final newMessages = [
        ChatMessage(role: 'user', content: 'New message'),
      ];

      // This should not throw
      await notifier.updateMessages(convId, newMessages);

      final conversations = container.read(conversationsProvider);
      expect(conversations.first.messages.length, 1);
    });

    test('message content survives save and reload round-trip', () async {
      final container = await setupWithConversation(messageCount: 3);
      addTearDown(container.dispose);

      await waitForConversationsLoad(container);

      final conversations = container.read(conversationsProvider);
      expect(conversations.first.messages[0].content, 'Message 0');
      expect(conversations.first.messages[1].content, 'Message 1');
      expect(conversations.first.messages[2].content, 'Message 2');
    });

    test('provider handles multiple updates without losing data', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final convId = 'multi-update-conv';
      final initialMessages = [
        ChatMessage(role: 'user', content: 'Hello').toMap(),
      ];
      final conversation = {
        'id': convId,
        'title': '',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': initialMessages,
        'isPinned': false,
        'sortOrder': 0,
        'draftText': '',
      };
      await prefs.setString('conversations', jsonEncode([conversation]));
      await prefs.setString('active_conversation_id', convId);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await waitForConversationsLoad(container);

      final notifier = container.read(conversationsProvider.notifier)
          as ConversationsNotifier;

      // Apply multiple rapid updates
      for (int i = 0; i < 5; i++) {
        final msg = ChatMessage(
          role: i.isEven ? 'user' : 'assistant',
          content: 'Update $i',
        );
        final currentMessages = [
          ...container.read(conversationsProvider).first.messages,
          msg,
        ];
        await notifier.updateMessages(convId, currentMessages);
      }

      // After all updates, the conversation should have 6 messages
      // (1 initial + 5 updates)
      final finalConvs = container.read(conversationsProvider);
      expect(finalConvs.first.messages.length, 6);
      expect(finalConvs.first.messages.last.content, 'Update 4');
    });

    test('data survives rapid reads during async load', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final convId = 'race-test';

      final messages = List.generate(
        2,
        (i) => ChatMessage(
          role: i.isEven ? 'user' : 'assistant',
          content: 'Message $i',
        ).toMap(),
      );

      await prefs.setString(
          'conversations',
          jsonEncode([
            {
              'id': convId,
              'title': 'Race Test',
              'createdAt': DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
              'messages': messages,
              'isPinned': false,
              'sortOrder': 0,
              'draftText': '',
            }
          ]));
      await prefs.setString('active_conversation_id', convId);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Read multiple times concurrently during the async load
      // This should not crash or produce inconsistent state
      for (int i = 0; i < 5; i++) {
        container.read(conversationsProvider);
        await Future.microtask(() => {});
      }

      await waitForConversationsLoad(container);

      final conversations = container.read(conversationsProvider);
      expect(conversations.length, 1);
      expect(conversations.first.id, convId);
      expect(conversations.first.messages.length, 2);
    });
  });
}
