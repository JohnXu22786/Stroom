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

    test('fromMap migrates legacy todoread pref to todowrite', () {
      // 旧版本把 todo 拆成 todowrite / todoread 两个工具；合并为单一
      // todowrite 后，显式只开启 todoread 的对话必须迁移为新工具名，
      // 否则 todo 工具在该对话中会静默失效。
      final legacyMap = {
        'id': 'legacy-id',
        'title': 'Legacy',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': <Map<String, dynamic>>[],
        'isPinned': false,
        'sortOrder': 0,
        'enabledMcpToolNames': ['todoread', 'web_search'],
        'hasExplicitEnabledMcpTools': true,
      };

      final conv = Conversation.fromMap(legacyMap);
      expect(conv.enabledMcpToolNames, equals({'todowrite', 'web_search'}),
          reason: '旧 todoread 偏好应迁移为 todowrite，且不丢失其它工具');
    });

    test('fromMap leaves already-migrated todowrite pref untouched', () {
      final map = {
        'id': 'new-id',
        'title': 'New',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': <Map<String, dynamic>>[],
        'isPinned': false,
        'sortOrder': 0,
        'enabledMcpToolNames': ['todowrite', 'web_search'],
        'hasExplicitEnabledMcpTools': true,
      };

      final conv = Conversation.fromMap(map);
      expect(conv.enabledMcpToolNames, equals({'todowrite', 'web_search'}));
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

    test('roundtrip preserves absolute model id and provider name', () {
      final conv = Conversation(
        id: 'test-id',
        title: 'Test',
        messages: [],
        lastUsedModelName: 'GPT-4o | OpenAI',
        lastUsedModelId: 'gpt-4o',
        lastUsedProviderName: 'OpenAI',
      );

      final map = conv.toMap();
      final restored = Conversation.fromMap(map);

      expect(restored.lastUsedModelName, equals('GPT-4o | OpenAI'));
      expect(restored.lastUsedModelId, equals('gpt-4o'));
      expect(restored.lastUsedProviderName, equals('OpenAI'));
    });

    test('toMap omits lastUsedModelId/ProviderName when null or empty', () {
      final conv = Conversation(
        id: 'test-id',
        title: 'Test',
        messages: [],
        lastUsedModelId: '',
        lastUsedProviderName: '',
      );
      final map = conv.toMap();
      expect(map.containsKey('lastUsedModelId'), isFalse);
      expect(map.containsKey('lastUsedProviderName'), isFalse);
    });

    test('fromMap handles missing absolute fields gracefully (old data)', () {
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
        // 旧数据只有显示名，没有绝对身份字段
        'lastUsedModelName': 'GPT-4o | OpenAI',
      };

      final conv = Conversation.fromMap(oldMap);
      expect(conv.lastUsedModelName, equals('GPT-4o | OpenAI'));
      expect(conv.lastUsedModelId, isNull);
      expect(conv.lastUsedProviderName, isNull);
    });
  });
}
