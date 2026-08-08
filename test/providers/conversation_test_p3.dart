part of 'conversation_test.dart';

void conversationGroup3() {
  // ===================================================================
  // 8. Conversation - enabledMcpToolNames persistence
  // ===================================================================
  group('Conversation - enabledMcpToolNames persistence', () {
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
  // 9. Conversation - lastUsedModelName persistence
  // ===================================================================
  group('Conversation - lastUsedModelName persistence', () {
    test('toMap/fromMap roundtrip preserves lastUsedModelName', () {
      final conv = Conversation(
        id: 'test-id',
        title: 'Test',
        messages: [],
        lastUsedModelName: 'GPT-4o | OpenAI',
      );

      final map = conv.toMap();
      final restored = Conversation.fromMap(map);

      expect(restored.lastUsedModelName, equals('GPT-4o | OpenAI'));
      expect(restored.id, equals('test-id'));
    });

    test('toMap omits lastUsedModelName when null', () {
      final conv = Conversation(
        id: 'test-id',
        title: 'Test',
        messages: [],
      );
      final map = conv.toMap();
      expect(map.containsKey('lastUsedModelName'), isFalse);
    });

    test('toMap omits lastUsedModelName when empty string', () {
      final conv = Conversation(
        id: 'test-id',
        title: 'Test',
        messages: [],
        lastUsedModelName: '',
      );
      final map = conv.toMap();
      expect(map.containsKey('lastUsedModelName'), isFalse);
    });

    test('fromMap handles missing lastUsedModelName gracefully (old data)', () {
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
      };

      final conv = Conversation.fromMap(oldMap);
      expect(conv.lastUsedModelName, isNull);
      expect(conv.id, equals('old-id'));
    });

    test('multiple conversations preserve independent lastUsedModelName', () {
      final conv1 = Conversation(id: 'conv-1', title: 'Conv 1');
      conv1.lastUsedModelName = 'GPT-4o | OpenAI';

      final conv2 = Conversation(id: 'conv-2', title: 'Conv 2');
      conv2.lastUsedModelName = 'Claude 3 | Anthropic';

      final map1 = conv1.toMap();
      final map2 = conv2.toMap();

      final restored1 = Conversation.fromMap(map1);
      final restored2 = Conversation.fromMap(map2);

      expect(restored1.lastUsedModelName, equals('GPT-4o | OpenAI'));
      expect(restored2.lastUsedModelName, equals('Claude 3 | Anthropic'));
    });
  });
}
