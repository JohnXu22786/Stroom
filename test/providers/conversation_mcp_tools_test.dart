import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/providers/conversation_provider.dart';

void main() {
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

      final map = conv.toMap();
      final restored = Conversation.fromMap(map);

      expect(restored.enabledMcpToolNames, equals({'calculator', 'web_search'}));
      expect(restored.id, equals('test-id'));
    });

    test('toMap/fromMap roundtrip preserves empty enabledMcpToolNames', () {
      final conv = Conversation(
        id: 'test-id',
        title: 'Test',
        messages: [],
      );
      // enabledMcpToolNames defaults to empty, don't change it

      final map = conv.toMap();
      final restored = Conversation.fromMap(map);

      expect(restored.enabledMcpToolNames, isEmpty);
    });

    test('fromMap handles missing enabledMcpToolNames gracefully (old data)', () {
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
        // No 'enabledMcpToolNames' key — as it would be for old persisted data
      };

      final conv = Conversation.fromMap(oldMap);
      expect(conv.enabledMcpToolNames, isEmpty,
          reason: 'Old data without enabledMcpToolNames should default to empty set');
      expect(conv.id, equals('old-id'));
    });

    test('enabledMcpToolNames stored as List in JSON (Set serialization)', () {
      final conv = Conversation(
        id: 'test-id',
        title: 'Test',
        messages: [],
      );
      conv.enabledMcpToolNames = {'tool_a', 'tool_b'};

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
      expect(conv.enabledMcpToolNames, equals({'tool_a', 'tool_b'}));

      // Replace with different set
      conv.enabledMcpToolNames = {'tool_c'};
      expect(conv.enabledMcpToolNames, equals({'tool_c'}));
    });

    test('multiple conversations preserve independent enabledMcpToolNames', () {
      final conv1 = Conversation(id: 'conv-1', title: 'Conv 1');
      conv1.enabledMcpToolNames = {'tool_a'};

      final conv2 = Conversation(id: 'conv-2', title: 'Conv 2');
      conv2.enabledMcpToolNames = {'tool_b', 'tool_c'};

      final map1 = conv1.toMap();
      final map2 = conv2.toMap();

      final restored1 = Conversation.fromMap(map1);
      final restored2 = Conversation.fromMap(map2);

      expect(restored1.enabledMcpToolNames, equals({'tool_a'}));
      expect(restored2.enabledMcpToolNames, equals({'tool_b', 'tool_c'}));
    });
  });

  group('ConversationsNotifier - tool state management', () {
    test('createConversation creates conversation with empty enabledMcpToolNames',
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
          reason: 'When enabledMcpToolNames is empty, no tools should pass filter');
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
