import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/models/chat_message.dart';

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
  group('ConversationsNotifier - createConversation prepends', () {
    testWidgets('new conversation is prepended at index 0', (tester) async {
      final container = _createContainer(initialState: []);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.createConversation();
      expect(notifier.state.length, 1);
      final firstId = notifier.state[0].id;

      notifier.createConversation();
      expect(notifier.state.length, 2);

      // CLIENT REQUIREMENT: New conversations should be at the top
      // Currently: appended to end → this test FAILS until we prepend
      expect(notifier.state[0].id, isNot(firstId));
      expect(notifier.state[1].id, firstId);
    });

    testWidgets('conversations maintain reverse-chronological order from prepend',
        (tester) async {
      final container = _createContainer(initialState: []);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.createConversation();
      final id1 = notifier.state[0].id;
      notifier.createConversation();
      final id2 = notifier.state[0].id;
      notifier.createConversation();
      final id3 = notifier.state[0].id;

      // CLIENT REQUIREMENT: newest at top (prepended)
      // Currently: appended → this test FAILS
      expect(notifier.state[0].id, id3);
      expect(notifier.state[1].id, id2);
      expect(notifier.state[2].id, id1);
    });
  });

  group('ConversationsNotifier - selectConversation does not update updatedAt', () {
    testWidgets('calling selectConversation keeps updatedAt unchanged',
        (tester) async {
      final conv = Conversation(
        id: 'test-conv',
        title: 'Test',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        messages: [],
      );
      final container = _createContainer(initialState: [conv]);
      final notifier = container.read(conversationsProvider.notifier);

      final originalUpdatedAt = notifier.state[0].updatedAt;

      notifier.selectConversation('test-conv');
      // CLIENT REQUIREMENT: selecting a conversation should NOT change its time
      expect(notifier.state[0].updatedAt, originalUpdatedAt);
    });
  });

  group('ConversationsNotifier - updateMessages preserves list position', () {
    testWidgets('updateMessages does not reorder conversations',
        (tester) async {
      final conv1 = Conversation(
        id: 'conv-1',
        title: 'First',
        createdAt: DateTime(2026, 1, 10),
        updatedAt: DateTime(2026, 1, 10),
        messages: [],
      );
      final conv2 = Conversation(
        id: 'conv-2',
        title: 'Second',
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 1, 15),
        messages: [],
      );
      final container = _createContainer(initialState: [conv1, conv2]);
      final notifier = container.read(conversationsProvider.notifier);

      // Update messages in conv1
      await notifier.updateMessages('conv-1', [
        ChatMessage(id: 'msg-1', role: 'user', content: 'Hello'),
        ChatMessage(id: 'msg-2', role: 'assistant', content: 'Hi there'),
      ]);
      // Let the persist timer complete
      await tester.pump(const Duration(milliseconds: 600));

      // CLIENT REQUIREMENT: updating messages should NOT move conversation to top
      expect(notifier.state[0].id, 'conv-1');
      expect(notifier.state[1].id, 'conv-2');
    });

    testWidgets('updateMessages does update updatedAt timestamp',
        (tester) async {
      final conv = Conversation(
        id: 'test',
        title: 'Test',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final container = _createContainer(initialState: [conv]);
      final notifier = container.read(conversationsProvider.notifier);

      final before = notifier.state[0].updatedAt;

      // selectConversation should NOT change updatedAt
      notifier.selectConversation('test');
      expect(notifier.state[0].updatedAt, before);

      // updateMessages SHOULD change updatedAt (for metadata/timestamp purposes)
      // but should NOT change list position
      await notifier.updateMessages('test', [
        ChatMessage(id: 'm1', role: 'user', content: 'Hi'),
      ]);
      // Let the persist timer complete
      await tester.pump(const Duration(milliseconds: 600));
      expect(notifier.state[0].updatedAt.isAfter(before), isTrue);
      // Position should remain unchanged
      expect(notifier.state[0].id, 'test');
    });
  });

  group('ConversationsNotifier - reorderConversation', () {
    testWidgets('reorderConversation preserves manually set order',
        (tester) async {
      final container = _createContainer(initialState: []);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.createConversation();
      notifier.createConversation();
      notifier.createConversation();

      final ids = notifier.state.map((c) => c.id).toList();

      // Move the last item to index 0 (top)
      notifier.reorderConversation(2, 0);
      await tester.pump(const Duration(milliseconds: 600));

      // CLIENT REQUIREMENT: manual reordering should be preserved
      expect(notifier.state[0].id, ids[2]);
      expect(notifier.state[1].id, ids[0]);
      expect(notifier.state[2].id, ids[1]);
    });

    testWidgets('pinned conversations can be reordered like any other',
        (tester) async {
      final conv1 = Conversation(
        id: 'conv-pin',
        title: 'Pinned',
        isPinned: true,
      );
      final conv2 = Conversation(
        id: 'conv-normal',
        title: 'Normal',
      );
      final container = _createContainer(initialState: [conv1, conv2]);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.reorderConversation(0, 1);
      await tester.pump(const Duration(milliseconds: 600));

      expect(notifier.state[0].id, 'conv-normal');
      expect(notifier.state[1].id, 'conv-pin');
    });
  });
}
