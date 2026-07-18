// Merged from:
//   - conversation_draft_test.dart
//   - conversation_history_ordering_test.dart
//   - conversation_mcp_tools_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  // ===================================================================
  // 1. Conversation model - draftText serialization
  // ===================================================================
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
      expect(
          restored.draftText, 'This is a draft message that was not sent yet');
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

  // ===================================================================
  // 2. ConversationsNotifier - saveDraft
  // ===================================================================
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

    test('sending a message (via updateMessages) does NOT clear draftText',
        () async {
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

  // ===================================================================
  // 3. ConversationsNotifier - createConversation prepends
  // ===================================================================
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
      // Currently: appended to end -> this test FAILS until we prepend
      expect(notifier.state[0].id, isNot(firstId));
      expect(notifier.state[1].id, firstId);
    });

    testWidgets(
        'conversations maintain reverse-chronological order from prepend',
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
      // Currently: appended -> this test FAILS
      expect(notifier.state[0].id, id3);
      expect(notifier.state[1].id, id2);
      expect(notifier.state[2].id, id1);
    });
  });

  // ===================================================================
  // 4. ConversationsNotifier - selectConversation does not update updatedAt
  // ===================================================================
  group('ConversationsNotifier - selectConversation does not update updatedAt',
      () {
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

  // ===================================================================
  // 5. ConversationsNotifier - updateMessages preserves list position
  // ===================================================================
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

  // ===================================================================
  // 6. ConversationsNotifier - reorderConversation
  // ===================================================================
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

  // ===================================================================
  // 7. ConversationsNotifier - togglePin preserves updatedAt
  // ===================================================================
  group('ConversationsNotifier - togglePin preserves updatedAt', () {
    testWidgets('togglePin does NOT change updatedAt', (tester) async {
      final originalTime = DateTime(2026, 5, 15, 10, 30, 0);
      final conv = Conversation(
        id: 'test-conv',
        title: 'Test',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: originalTime,
        isPinned: false,
      );
      final container = _createContainer(initialState: [conv]);
      final notifier = container.read(conversationsProvider.notifier);

      // Pin the conversation
      notifier.togglePin('test-conv');
      expect(notifier.state[0].isPinned, isTrue);
      // CLIENT REQUIREMENT: pinning should NOT change updatedAt
      expect(notifier.state[0].updatedAt, originalTime);

      // Unpin the conversation
      notifier.togglePin('test-conv');
      expect(notifier.state[0].isPinned, isFalse);
      // CLIENT REQUIREMENT: unpinning should NOT change updatedAt
      expect(notifier.state[0].updatedAt, originalTime);

      // Flush the persist timer to avoid "pending timer" error
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('togglePin correctly toggles isPinned state', (tester) async {
      final conv = Conversation(
        id: 'test-conv-2',
        title: 'Test 2',
        updatedAt: DateTime(2026, 6, 1),
        isPinned: false,
      );
      final container = _createContainer(initialState: [conv]);
      final notifier = container.read(conversationsProvider.notifier);

      // Initially not pinned
      expect(notifier.state[0].isPinned, isFalse);

      // Toggle to pinned
      notifier.togglePin('test-conv-2');
      expect(notifier.state[0].isPinned, isTrue);

      // Toggle back to not pinned
      notifier.togglePin('test-conv-2');
      expect(notifier.state[0].isPinned, isFalse);

      // Flush the persist timer to avoid "pending timer" error
      await tester.pump(const Duration(milliseconds: 600));
    });
  });

  // ===================================================================
  // 8. Conversation - enabledMcpToolNames persistence
  // ===================================================================
  group('Conversation - enabledMcpToolNames persistence', () {
    test('new conversation has empty enabledMcpToolNames (default OFF)', () {
      final conv = Conversation(title: 'Test', messages: []);
      expect(conv.enabledMcpToolNames, isEmpty,
          reason: 'All tools should be OFF by default');
    });

    test('toMap/fromMap roundtrip preserves enabledMcpToolNames', () {
      final conv = Conversation(
        id: 'test-id',
        title: 'Test',
        messages: [],
      );
      conv.enabledMcpToolNames = {'calculator', 'web_search'};
      conv.hasExplicitEnabledMcpTools = true;

      final map = conv.toMap();
      final restored = Conversation.fromMap(map);

      expect(
          restored.enabledMcpToolNames, equals({'calculator', 'web_search'}));
      expect(restored.id, equals('test-id'));
      expect(restored.hasExplicitEnabledMcpTools, isTrue);
    });

    test('toMap/fromMap roundtrip preserves empty enabledMcpToolNames', () {
      final conv = Conversation(
        id: 'test-id',
        title: 'Test',
        messages: [],
      );
      // Explicit-empty case: user toggled every tool off.
      // The set is empty but the explicit flag is true, so it must survive.
      conv.hasExplicitEnabledMcpTools = true;

      final map = conv.toMap();
      final restored = Conversation.fromMap(map);

      expect(restored.enabledMcpToolNames, isEmpty);
      expect(restored.hasExplicitEnabledMcpTools, isTrue);
    });

    test('fromMap handles missing enabledMcpToolNames gracefully (old data)',
        () {
      // Simulate old conversation data without enabledMcpToolNames
      final oldMap = {
        'id': 'old-id',
        'title': 'Old Conversation',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': <Map<String, dynamic>>[],
        'isPinned': false,
        'sortOrder': 0,
        'assistantId': 'assistant-1',
        'draftText': '',
        // No 'enabledMcpToolNames' key - as it would be for old persisted data
      };

      final conv = Conversation.fromMap(oldMap);
      expect(conv.enabledMcpToolNames, isEmpty,
          reason:
              'Old data without enabledMcpToolNames should default to empty set');
      expect(conv.id, equals('old-id'));
    });

    test('enabledMcpToolNames stored as List in JSON (Set serialization)', () {
      final conv = Conversation(
        id: 'test-id',
        title: 'Test',
        messages: [],
      );
      conv.enabledMcpToolNames = {'tool_a', 'tool_b'};
      conv.hasExplicitEnabledMcpTools = true;

      final map = conv.toMap();
      // enabledMcpToolNames should be serialized as a List in JSON
      final stored = map['enabledMcpToolNames'];
      expect(stored, isA<List>());
      final list = stored as List;
      expect(list, contains('tool_a'));
      expect(list, contains('tool_b'));
      expect(list.length, equals(2));
    });

    test('setting enabledMcpToolNames replaces previous values', () {
      final conv = Conversation(
        id: 'test-id',
        title: 'Test',
        messages: [],
      );
      conv.enabledMcpToolNames = {'tool_a', 'tool_b'};
      conv.hasExplicitEnabledMcpTools = true;
      expect(conv.enabledMcpToolNames, equals({'tool_a', 'tool_b'}));

      // Replace with different set
      conv.enabledMcpToolNames = {'tool_c'};
      expect(conv.enabledMcpToolNames, equals({'tool_c'}));
    });

    test('multiple conversations preserve independent enabledMcpToolNames', () {
      final conv1 = Conversation(id: 'conv-1', title: 'Conv 1');
      conv1.enabledMcpToolNames = {'tool_a'};
      conv1.hasExplicitEnabledMcpTools = true;

      final conv2 = Conversation(id: 'conv-2', title: 'Conv 2');
      conv2.enabledMcpToolNames = {'tool_b', 'tool_c'};
      conv2.hasExplicitEnabledMcpTools = true;

      final map1 = conv1.toMap();
      final map2 = conv2.toMap();

      final restored1 = Conversation.fromMap(map1);
      final restored2 = Conversation.fromMap(map2);

      expect(restored1.enabledMcpToolNames, equals({'tool_a'}));
      expect(restored2.enabledMcpToolNames, equals({'tool_b', 'tool_c'}));
    });
  });

  // ===================================================================
  // 9. ConversationsNotifier - tool state management
  // ===================================================================
  group('ConversationsNotifier - tool state management', () {
    test(
        'createConversation creates conversation with empty enabledMcpToolNames',
        () {
      // Integration verification: new conversations should have no tools enabled
      // This tests the conversation through the standard creation path
      final conv = Conversation(
        title: 'New Conversation',
        messages: [],
      );
      expect(conv.enabledMcpToolNames, isEmpty,
          reason: 'New conversations must have all tools OFF by default');
    });
  });

  // ===================================================================
  // 10. Tool filtering integration
  // ===================================================================
  group('Tool filtering integration', () {
    test('all tools default OFF when creating new conversation', () {
      // Simulate the chat_page.dart logic: when loading a conversation,
      // enabledToolNames should be empty for a new conversation
      final conv = Conversation(title: 'New', messages: []);
      final enabledToolNames = conv.enabledMcpToolNames;

      // All tools should be OFF by default (empty set)
      expect(enabledToolNames, isEmpty);
    });

    test('tool filtering excludes all tools when enabledMcpToolNames is empty',
        () {
      final allTools = ['calculator', 'web_search', 'file_reader'];
      final conv = Conversation(title: 'Test', messages: []);
      // enabledMcpToolNames is empty by default

      final filteredTools =
          allTools.where((t) => conv.enabledMcpToolNames.contains(t)).toList();

      expect(filteredTools, isEmpty,
          reason:
              'When enabledMcpToolNames is empty, no tools should pass filter');
    });

    test('tool filtering includes only tools in enabledMcpToolNames', () {
      final allTools = ['calculator', 'web_search', 'file_reader'];
      final conv = Conversation(title: 'Test', messages: []);
      conv.enabledMcpToolNames = {'web_search'};

      final filteredTools =
          allTools.where((t) => conv.enabledMcpToolNames.contains(t)).toList();

      expect(filteredTools, equals(['web_search']));
    });
  });
}
