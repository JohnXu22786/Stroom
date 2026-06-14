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
  group('Conversation model - draftText serialization', () {
    test('draftText is empty by default', () {
      final conv = Conversation(id: 'test', title: 'Test');
      expect(conv.draftText, '');
    });

    test('draftText is preserved in toMap/fromMap round-trip', () {
      final conv = Conversation(
        id: 'test',
        title: 'Test',
        draftText: 'This is a draft message that was not sent yet',
      );
      final map = conv.toMap();
      final restored = Conversation.fromMap(map);
      expect(restored.draftText, 'This is a draft message that was not sent yet');
    });

    test('draftText survives toMap/fromMap round-trip with empty draft', () {
      final conv = Conversation(id: 'test', title: 'Test');
      final map = conv.toMap();
      final restored = Conversation.fromMap(map);
      expect(restored.draftText, '');
    });

    test('missing draftText in map defaults to empty string', () {
      final map = <String, dynamic>{
        'id': 'test',
        'title': 'Test',
        'createdAt': '2026-01-01T00:00:00.000',
        'updatedAt': '2026-01-01T00:00:00.000',
        'messages': [],
        'isPinned': false,
        'sortOrder': 0,
      };
      final restored = Conversation.fromMap(map);
      expect(restored.draftText, '');
    });

    test('draftText with special characters survives round-trip', () {
      final conv = Conversation(
        id: 'test',
        title: 'Test',
        draftText: 'Hello\nWorld\tTest 你好 🎉 \$100',
      );
      final map = conv.toMap();
      final restored = Conversation.fromMap(map);
      expect(restored.draftText, 'Hello\nWorld\tTest 你好 🎉 \$100');
    });
  });

  group('ConversationsNotifier - saveDraft', () {
    test('saveDraft stores draft for the correct conversation', () {
      final conv1 = Conversation(id: 'conv-1', title: 'First');
      final conv2 = Conversation(id: 'conv-2', title: 'Second');
      final container = _createContainer(initialState: [conv1, conv2]);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.saveDraft('conv-1', 'Hello, this is a draft');

      expect(notifier.state[0].draftText, 'Hello, this is a draft');
      expect(notifier.state[1].draftText, '');
    });

    test('different conversations have independent drafts', () {
      final conv1 = Conversation(id: 'conv-1', title: 'First');
      final conv2 = Conversation(id: 'conv-2', title: 'Second');
      final container = _createContainer(initialState: [conv1, conv2]);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.saveDraft('conv-1', 'Draft for conversation 1');
      notifier.saveDraft('conv-2', 'Draft for conversation 2');

      expect(notifier.state[0].draftText, 'Draft for conversation 1');
      expect(notifier.state[1].draftText, 'Draft for conversation 2');
    });

    test('saveDraft with empty string clears the draft', () {
      final conv = Conversation(
        id: 'test',
        title: 'Test',
        draftText: 'Old draft content',
      );
      final container = _createContainer(initialState: [conv]);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.saveDraft('test', '');

      expect(notifier.state[0].draftText, '');
    });

    test('saveDraft on non-existent conversation does not crash', () {
      final conv = Conversation(id: 'test', title: 'Test');
      final container = _createContainer(initialState: [conv]);
      final notifier = container.read(conversationsProvider.notifier);

      // Should not throw
      notifier.saveDraft('non-existent', 'Some draft');

      // Existing conversation should be unaffected
      expect(notifier.state[0].draftText, '');
    });

    test('updating draft multiple times keeps only the latest value', () {
      final conv = Conversation(id: 'test', title: 'Test');
      final container = _createContainer(initialState: [conv]);
      final notifier = container.read(conversationsProvider.notifier);

      notifier.saveDraft('test', 'First version');
      notifier.saveDraft('test', 'Second version');
      notifier.saveDraft('test', 'Third version');

      expect(notifier.state[0].draftText, 'Third version');
    });

    test('sending a message (via updateMessages) does NOT clear draftText', () async {
      final conv = Conversation(
        id: 'test',
        title: 'Test',
        draftText: 'Unsent draft',
      );
      final container = _createContainer(initialState: [conv]);
      final notifier = container.read(conversationsProvider.notifier);

      await notifier.updateMessages('test', [
        ChatMessage(id: 'm1', role: 'user', content: 'Sent message'),
      ]);

      // Draft text should be preserved when sending a message via updateMessages
      // (the composer will clear it separately via saveDraft)
      expect(notifier.state[0].draftText, 'Unsent draft');
    });
  });
}
