// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/providers/conversation_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'manual unread state survives persistence reload and opens as read',
    () async {
      final conversation = Conversation(
        id: 'saved',
        title: 'Saved',
        messages: [
          ChatMessage(id: 'assistant-1', role: 'assistant', content: 'Hi'),
        ],
        lastReadMessageId: 'assistant-1',
        isManuallyUnread: true,
      );
      SharedPreferences.setMockInitialValues({
        'conversations': jsonEncode([conversation.toMap()]),
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(conversationsProvider.notifier).ready;
      final notifier = container.read(conversationsProvider.notifier);
      expect(notifier.state.single.isManuallyUnread, isTrue);

      notifier.selectConversation('saved');
      await Future<void>.delayed(const Duration(milliseconds: 650));
      expect(notifier.state.single.isManuallyUnread, isFalse);
      expect(notifier.state.single.lastReadMessageId, 'assistant-1');

      final saved =
          (jsonDecode(
                (await SharedPreferences.getInstance()).getString(
                  'conversations',
                )!,
              ) as List).single
              as Map<String, dynamic>;
      expect(saved['isManuallyUnread'], isNot(true));
    },
  );

  test('marking read advances latest successful assistant marker', () async {
    final conversation = Conversation(
      id: 'manual',
      title: 'Manual',
      messages: [
        ChatMessage(id: 'old', role: 'assistant', content: 'Old'),
        ChatMessage(id: 'new', role: 'assistant', content: 'New'),
      ],
      lastReadMessageId: 'old',
      isManuallyUnread: true,
    );
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        conversationsProvider.overrideWith((ref) {
          final notifier = ConversationsNotifier(ref);
          notifier.state = [conversation];
          return notifier;
        }),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(conversationsProvider.notifier);
    notifier.toggleConversationReadState('manual', isUnread: false);
    expect(conversation.isManuallyUnread, isTrue);
    notifier.toggleConversationReadState('manual', isUnread: true);

    expect(conversation.isManuallyUnread, isFalse);
    expect(conversation.lastReadMessageId, 'new');
  });

  test('marking an errored conversation read preserves its error marker', () async {
    final conversation = Conversation(
      id: 'error',
      title: 'Error',
      messages: [
        ChatMessage(
          id: 'previous-success',
          role: 'assistant',
          content: 'Succeeded',
        ),
        ChatMessage(
          id: 'failed',
          role: 'assistant',
          content: 'Failed',
          isError: true,
        ),
      ],
      lastReadMessageId: 'earlier-read',
      isManuallyUnread: true,
    );
    final container = ProviderContainer(overrides: [
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        notifier.state = [conversation];
        return notifier;
      }),
    ]);
    addTearDown(container.dispose);

    container
        .read(conversationsProvider.notifier)
        .toggleConversationReadState('error', isUnread: true);

    expect(conversation.isManuallyUnread, isFalse);
    expect(conversation.lastReadMessageId, 'previous-success');
    expect(conversation.messages.last.isError, isTrue);
  });
}
