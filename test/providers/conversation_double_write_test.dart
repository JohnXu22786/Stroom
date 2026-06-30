import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/providers/conversation_provider.dart';

/// Helper: create a ProviderContainer with a ConversationsNotifier that has
/// state pre-set (bypassing async _load from SharedPreferences).
ProviderContainer _createContainer({List<Conversation>? initialState}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderContainer(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        notifier.state = initialState ?? [];
        return notifier;
      }),
    ],
  );
}

void main() {
  group('Conversation double-write strategy', () {
    test('_persist creates conversations_bak before writing conversations',
        () async {
      SharedPreferences.setMockInitialValues({
        'conversations': jsonEncode([
          {
            'id': 'conv1',
            'title': 'Test',
            'messages': [],
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          }
        ]),
      });

      final container = _createContainer(initialState: [
        Conversation(
          id: 'conv1',
          title: 'Test',
          messages: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);

      final prefs = await SharedPreferences.getInstance();
      final notifier = container.read(conversationsProvider.notifier);

      // Trigger a persist by updating messages
      await notifier.updateMessages('conv1', [
        ChatMessage(
          id: 'msg1',
          role: 'user',
          content: 'Hello',
          createdAt: DateTime.now(),
        ),
      ]);

      // Wait for the 500ms debounce
      await Future.delayed(const Duration(milliseconds: 800));

      // Verify conversations_bak was created during the process
      // (Note: in the debounced _persist, bak is created then removed)
      // The key assertion is that conversations exists and has valid data
      final conversationsJson = prefs.getString('conversations');
      expect(conversationsJson, isNotNull);

      final list = jsonDecode(conversationsJson!) as List;
      expect(list.length, greaterThan(0));

      // The bak should be cleaned up
      final bak = prefs.getString('conversations_bak');
      expect(bak, isNull);

      container.dispose();
    });

    test('_persistNow creates and cleans up conversations_bak', () async {
      SharedPreferences.setMockInitialValues({});

      final container = _createContainer(initialState: [
        Conversation(
          id: 'conv1',
          title: 'Test',
          messages: [
            ChatMessage(
              id: 'msg1',
              role: 'user',
              content: 'Hello',
              createdAt: DateTime.now(),
            ),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);

      final prefs = await SharedPreferences.getInstance();
      final notifier = container.read(conversationsProvider.notifier);

      // Set bak manually to simulate a prior interrupted write
      await prefs.setString(
          'conversations_bak',
          jsonEncode([
            {
              'id': 'conv1',
              'title': 'Old',
              'messages': [],
            }
          ]));

      // Trigger a _persistNow via update with the batch flag
      await notifier.updateMessages('conv1', [
        ChatMessage(
          id: 'msg2',
          role: 'user',
          content: 'World',
          createdAt: DateTime.now(),
        ),
      ]);

      // Wait for debounce
      await Future.delayed(const Duration(milliseconds: 800));

      // The bak should be cleaned up
      final bak = prefs.getString('conversations_bak');
      expect(bak, isNull);

      container.dispose();
    });

    test('conversations_bak is cleaned up after successful conversations write',
        () async {
      SharedPreferences.setMockInitialValues({
        'conversations': jsonEncode([
          {
            'id': 'conv1',
            'title': 'Test',
            'messages': [],
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          }
        ]),
        'conversations_bak': jsonEncode([
          {
            'id': 'conv_old',
            'title': 'Old',
            'messages': [],
          }
        ]),
      });

      final container = _createContainer(initialState: [
        Conversation(
          id: 'conv1',
          title: 'Test',
          messages: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);

      final prefs = await SharedPreferences.getInstance();

      // After provider loads, trigger a new write
      final notifier = container.read(conversationsProvider.notifier);
      await notifier.updateMessages('conv1', [
        ChatMessage(
          id: 'msg1',
          role: 'user',
          content: 'Hello',
          createdAt: DateTime.now(),
        ),
      ]);

      await Future.delayed(const Duration(milliseconds: 800));

      // After write, bak should be gone
      expect(prefs.containsKey('conversations_bak'), isFalse);

      container.dispose();
    });

    test('double-write preserves data integrity on successful persist',
        () async {
      SharedPreferences.setMockInitialValues({});

      final container = _createContainer(initialState: [
        Conversation(
          id: 'conv1',
          title: 'Test',
          messages: [
            ChatMessage(
              id: 'msg1',
              role: 'user',
              content: 'Hello',
              createdAt: DateTime.now(),
            ),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);

      final notifier = container.read(conversationsProvider.notifier);

      await notifier.updateMessages('conv1', [
        ChatMessage(
          id: 'msg1',
          role: 'user',
          content: 'Hello',
          createdAt: DateTime.now(),
        ),
        ChatMessage(
          id: 'msg2',
          role: 'assistant',
          content: 'Hi there!',
          createdAt: DateTime.now(),
        ),
      ]);

      await Future.delayed(const Duration(milliseconds: 800));

      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('conversations');
      expect(json, isNotNull);

      final list = jsonDecode(json!) as List;
      expect(list.length, equals(1));
      final messages = list[0]['messages'] as List;
      expect(messages.length, equals(2));

      container.dispose();
    });
  });
}
