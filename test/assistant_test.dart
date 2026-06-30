import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';

void main() {
  group('AssistantModel', () {
    test('default settings have correct values', () {
      final settings = AssistantSettings.defaults();
      expect(settings.temperature, 1.0);
      expect(settings.topP, 1.0);
      expect(settings.maxTokens, 4096);
      expect(settings.streamOutput, true);
      expect(settings.enableTemperature, false);
      expect(settings.enableTopP, false);
      expect(settings.enableMaxTokens, false);
      expect(settings.enableWebSearch, false);
      expect(settings.maxToolCalls, 20);
      expect(settings.enableMaxToolCalls, true);
      expect(settings.customParameters, isEmpty);
    });

    test('settings serialization round-trip', () {
      final original = AssistantSettings(
        temperature: 0.7,
        enableTemperature: true,
        topP: 0.9,
        enableTopP: true,
        maxTokens: 2048,
        enableMaxTokens: true,
        streamOutput: false,
        enableWebSearch: true,
        customParameters: [
          CustomParameter(name: 'top_k', type: 'number', value: 40),
          CustomParameter(name: 'verbose', type: 'boolean', value: true),
        ],
      );

      final map = original.toMap();
      final restored = AssistantSettings.fromMap(map);

      expect(restored.temperature, 0.7);
      expect(restored.enableTemperature, true);
      expect(restored.topP, 0.9);
      expect(restored.enableTopP, true);
      expect(restored.maxTokens, 2048);
      expect(restored.enableMaxTokens, true);
      expect(restored.streamOutput, false);
      expect(restored.enableWebSearch, true);
      expect(restored.customParameters.length, 2);
      expect(restored.customParameters[0].name, 'top_k');
      expect(restored.customParameters[1].name, 'verbose');
    });

    test('settings defaults round-trip', () {
      final original = AssistantSettings.defaults();
      final map = original.toMap();
      final restored = AssistantSettings.fromMap(map);

      expect(restored.temperature, original.temperature);
      expect(restored.topP, original.topP);
      expect(restored.maxTokens, original.maxTokens);
      expect(restored.streamOutput, original.streamOutput);
      expect(restored.enableWebSearch, original.enableWebSearch);
    });

    test('settings fromMap ignores legacy reasoningEffort field', () {
      // Legacy data that still has reasoningEffort in the map
      final map = <String, dynamic>{
        'temperature': 0.7,
        'topP': 0.9,
        'reasoningEffort': 'high',
      };
      final restored = AssistantSettings.fromMap(map);
      // Should load without error and reasoningEffort should not exist
      expect(restored.temperature, 0.7);
      expect(restored.topP, 0.9);
    });

    test('settings toMap does not include reasoningEffort', () {
      // Use a fully non-default settings to verify the field is truly absent
      final settings = AssistantSettings(
        temperature: 0.7,
        enableTemperature: true,
        topP: 0.9,
        enableTopP: true,
        maxTokens: 2048,
        enableMaxTokens: true,
        streamOutput: false,
        enableWebSearch: true,
        maxToolCalls: 30,
        enableMaxToolCalls: true,
        frequencyPenalty: 0.5,
        enableFrequencyPenalty: true,
        presencePenalty: 0.3,
        enablePresencePenalty: true,
        seed: 777,
        enableSeed: true,
      );
      final map = settings.toMap();
      expect(map.containsKey('reasoningEffort'), isFalse,
          reason:
              'reasoningEffort should be removed from AssistantSettings toMap');
    });

    test('assistant toMap/fromMap round-trip', () {
      final settings = AssistantSettings(
        temperature: 0.5,
        enableTemperature: true,
        topP: 0.8,
        enableTopP: true,
        maxTokens: 1024,
        enableMaxTokens: true,
        streamOutput: true,
        enableWebSearch: false,
        customParameters: [],
      );

      final original = Assistant(
        name: '测试助手',
        prompt: '你是一个有用的助手。',
        emoji: '🤖',
        description: '一个测试用助手',
        settings: settings,
        modelId: 'provider1::model1',
      );

      final map = original.toMap();
      final restored = Assistant.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.name, '测试助手');
      expect(restored.prompt, '你是一个有用的助手。');
      expect(restored.emoji, '🤖');
      expect(restored.description, '一个测试用助手');
      expect(restored.modelId, 'provider1::model1');
      expect(restored.settings.temperature, 0.5);
      expect(restored.settings.enableTemperature, true);
      expect(restored.settings.topP, 0.8);
    });

    test('assistant defaults use defaults settings', () {
      final assistant = Assistant(
        name: '默认助手',
        prompt: '你好！',
      );

      expect(assistant.settings.temperature, 1.0);
      expect(assistant.settings.streamOutput, true);
      expect(assistant.emoji, '🤖');
      expect(assistant.description, '');
      expect(assistant.modelId, isNull);
    });

    test('assistant with null modelId round-trip', () {
      final original = Assistant(
        name: 'No model',
        prompt: 'Test',
        modelId: null,
      );

      final map = original.toMap();
      final restored = Assistant.fromMap(map);

      expect(restored.modelId, isNull);
      expect(restored.name, 'No model');
    });

    test('custom parameter different types serialization', () {
      final params = [
        CustomParameter(name: 'str_param', type: 'string', value: 'hello'),
        CustomParameter(name: 'num_param', type: 'number', value: 42),
        CustomParameter(name: 'bool_param', type: 'boolean', value: false),
      ];

      for (final p in params) {
        final map = p.toMap();
        final restored = CustomParameter.fromMap(map);
        expect(restored.name, p.name);
        expect(restored.type, p.type);
        expect(restored.value, p.value);
      }
    });

    test('fromMap handles missing settings gracefully', () {
      final map = <String, dynamic>{
        'id': 'test-1',
        'name': 'Legacy',
        'prompt': 'Hello',
      };

      final assistant = Assistant.fromMap(map);
      expect(assistant.settings.temperature, 1.0);
      expect(assistant.settings.streamOutput, true);
    });

    // ========================================================================
    // Avatar: emoji only (image avatar feature removed)
    // ========================================================================

    test('assistant defaults with emoji', () {
      final assistant = Assistant(name: '助手', prompt: '你好');
      expect(assistant.emoji, '🤖');
    });

    test('assistant with custom emoji works', () {
      final original = Assistant(
        name: '表情助手',
        prompt: '你好',
        emoji: '😊',
      );

      final map = original.toMap();
      final restored = Assistant.fromMap(map);

      expect(restored.emoji, '😊');
    });

    test('assistant fromMap handles legacy data gracefully', () {
      final map = <String, dynamic>{
        'id': 'legacy-1',
        'name': '旧助手',
        'prompt': '你好',
        'emoji': '🧠',
        'avatarType': 'image',
        'avatarUrl': 'https://example.com/old.png',
      };

      final assistant = Assistant.fromMap(map);
      // Legacy avatarType and avatarUrl should be ignored, emoji takes precedence
      expect(assistant.emoji, '🧠');
    });

    test('assistant copyWith preserves emoji', () {
      final original = Assistant(
        name: '原版',
        prompt: '你好',
        emoji: '🎨',
      );

      final updated = original.copyWith(
        emoji: '🌟',
      );

      expect(updated.emoji, '🌟');
      expect(updated.id, original.id);
    });

    test('assistant toMap does not include avatarType field', () {
      final original = Assistant(
        name: '助手',
        prompt: '你好',
        emoji: '😊',
      );

      final map = original.toMap();
      expect(map.containsKey('avatarType'), false);
      expect(map.containsKey('avatarUrl'), false);
    });

    test('assistant copyWith defaults to original emoji when not changed', () {
      final original = Assistant(
        name: '助手',
        prompt: '你好',
        emoji: '🎨',
      );

      final updated = original.copyWith(name: '新名称');

      expect(updated.emoji, '🎨');
      expect(updated.name, '新名称');
    });

    // ========================================================================
    // Extended params (frequencyPenalty, presencePenalty, seed)
    // ========================================================================

    test('settings defaults include extended params', () {
      final settings = AssistantSettings.defaults();
      expect(settings.frequencyPenalty, 0.0);
      expect(settings.enableFrequencyPenalty, false);
      expect(settings.presencePenalty, 0.0);
      expect(settings.enablePresencePenalty, false);
      expect(settings.seed, isNull);
      expect(settings.enableSeed, false);
    });

    test('extended params serialization round-trip', () {
      final original = AssistantSettings(
        frequencyPenalty: 0.5,
        enableFrequencyPenalty: true,
        presencePenalty: 0.3,
        enablePresencePenalty: true,
        seed: 42,
        enableSeed: true,
      );

      final map = original.toMap();
      final restored = AssistantSettings.fromMap(map);

      expect(restored.frequencyPenalty, 0.5);
      expect(restored.enableFrequencyPenalty, true);
      expect(restored.presencePenalty, 0.3);
      expect(restored.enablePresencePenalty, true);
      expect(restored.seed, 42);
      expect(restored.enableSeed, true);
    });

    test('extended params defaults round-trip', () {
      final original = AssistantSettings.defaults();
      final map = original.toMap();
      final restored = AssistantSettings.fromMap(map);

      expect(restored.frequencyPenalty, 0.0);
      expect(restored.enableFrequencyPenalty, false);
      expect(restored.presencePenalty, 0.0);
      expect(restored.enablePresencePenalty, false);
      expect(restored.seed, isNull);
      expect(restored.enableSeed, false);
    });

    test('settings with null seed round-trips correctly', () {
      final original = AssistantSettings(seed: null, enableSeed: false);
      final map = original.toMap();
      final restored = AssistantSettings.fromMap(map);

      expect(restored.seed, isNull);
      expect(restored.enableSeed, false);
    });

    test('settings with explicit seed round-trips correctly', () {
      final original = AssistantSettings(seed: 12345, enableSeed: true);
      final map = original.toMap();
      final restored = AssistantSettings.fromMap(map);

      expect(restored.seed, 12345);
      expect(restored.enableSeed, true);
    });

    test('settings copyWith preserves extended params', () {
      final original = AssistantSettings.defaults();
      final updated = original.copyWith(
        frequencyPenalty: 0.7,
        enableFrequencyPenalty: true,
        presencePenalty: 0.5,
        enablePresencePenalty: true,
        seed: 999,
        enableSeed: true,
      );

      expect(updated.frequencyPenalty, 0.7);
      expect(updated.enableFrequencyPenalty, true);
      expect(updated.presencePenalty, 0.5);
      expect(updated.enablePresencePenalty, true);
      expect(updated.seed, 999);
      expect(updated.enableSeed, true);

      // Original should be unchanged
      expect(original.frequencyPenalty, 0.0);
      expect(original.presencePenalty, 0.0);
      expect(original.seed, isNull);
    });

    test('complete settings with extended params serialization', () {
      final original = AssistantSettings(
        temperature: 0.7,
        enableTemperature: true,
        topP: 0.9,
        enableTopP: true,
        maxTokens: 2048,
        enableMaxTokens: true,
        streamOutput: false,
        enableWebSearch: true,
        maxToolCalls: 30,
        enableMaxToolCalls: true,
        frequencyPenalty: 0.5,
        enableFrequencyPenalty: true,
        presencePenalty: 0.3,
        enablePresencePenalty: true,
        seed: 777,
        enableSeed: true,
        customParameters: [
          CustomParameter(name: 'top_k', type: 'number', value: 40),
        ],
      );

      final map = original.toMap();
      final restored = AssistantSettings.fromMap(map);

      expect(restored.frequencyPenalty, 0.5);
      expect(restored.enableFrequencyPenalty, true);
      expect(restored.presencePenalty, 0.3);
      expect(restored.enablePresencePenalty, true);
      expect(restored.seed, 777);
      expect(restored.enableSeed, true);
      expect(restored.temperature, 0.7);
      expect(restored.customParameters.length, 1);
    });
  });

  group('AssistantProvider', () {
    test('createAssistant adds assistant to state', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = AssistantsNotifier();

      final assistant = notifier.createAssistant(
        name: '新助手',
        prompt: '你好！',
        emoji: '😊',
        description: '测试用',
      );

      expect(notifier.state.length, 1);
      expect(notifier.state[0].id, assistant.id);
      expect(notifier.state[0].name, '新助手');
      expect(notifier.state[0].prompt, '你好！');
    });

    test('createAssistant with default emoji when not provided', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = AssistantsNotifier();

      final assistant = notifier.createAssistant(
        name: '助手',
        prompt: 'Test',
      );

      expect(assistant.emoji, '🤖');
    });

    test('updateAssistant updates fields', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = AssistantsNotifier();

      final assistant = notifier.createAssistant(
        name: '原名称',
        prompt: '原提示词',
      );

      notifier.updateAssistant(
        id: assistant.id,
        name: '新名称',
        prompt: '新提示词',
        description: '新的描述',
      );

      final updated = notifier.state.firstWhere((a) => a.id == assistant.id);
      expect(updated.name, '新名称');
      expect(updated.prompt, '新提示词');
      expect(updated.description, '新的描述');
    });

    test('updateAssistantSettings updates only settings', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = AssistantsNotifier();

      final assistant = notifier.createAssistant(
        name: '助手',
        prompt: 'Test',
      );

      notifier.updateAssistantSettings(
        assistantId: assistant.id,
        temperature: 0.3,
        enableTemperature: true,
        enableWebSearch: true,
      );

      final updated = notifier.state.firstWhere((a) => a.id == assistant.id);
      expect(updated.settings.temperature, 0.3);
      expect(updated.settings.enableTemperature, true);
      expect(updated.settings.enableWebSearch, true);
      // Other settings should remain default
      expect(updated.settings.topP, 1.0);
      expect(updated.settings.maxTokens, 4096);
    });

    test('deleteAssistant removes assistant from state', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = AssistantsNotifier();

      final a1 = notifier.createAssistant(name: '助手1', prompt: 'P1');
      final a2 = notifier.createAssistant(name: '助手2', prompt: 'P2');

      expect(notifier.state.length, 2);

      notifier.deleteAssistant(a1.id);
      expect(notifier.state.length, 1);
      expect(notifier.state[0].id, a2.id);
    });

    test('loadFromJson restores saved assistants', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = AssistantsNotifier();

      final a1 = notifier.createAssistant(name: '助手1', prompt: 'P1');
      final a2 = notifier.createAssistant(name: '助手2', prompt: 'P2');

      // Simulate saving and loading
      final json = notifier.toJson();
      final notifier2 = AssistantsNotifier();
      notifier2.loadFromJson(json);

      expect(notifier2.state.length, 2);
      expect(notifier2.state[0].name, '助手1');
      expect(notifier2.state[1].name, '助手2');
      // IDs should match
      expect(notifier2.state[0].id, a1.id);
      expect(notifier2.state[1].id, a2.id);
    });

    test('toJson produces valid JSON array', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = AssistantsNotifier();

      notifier.createAssistant(name: '助手1', prompt: 'P1');
      notifier.createAssistant(name: '助手2', prompt: 'P2');

      final json = notifier.toJson();
      expect(json, startsWith('['));
      expect(json, endsWith(']'));

      // Verify it's valid JSON by parsing
      final decoded = jsonDecode(json) as List;
      expect(decoded.length, 2);
      expect(decoded[0]['name'], '助手1');
      expect(decoded[1]['name'], '助手2');
    });

    test('toJson does not include avatarType field', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = AssistantsNotifier();

      notifier.createAssistant(
        name: '助手',
        prompt: '你好',
        emoji: '😊',
      );

      final json = notifier.toJson();
      final decoded = jsonDecode(json) as List;
      expect(decoded[0].containsKey('avatarType'), false);
      expect(decoded[0].containsKey('avatarUrl'), false);
    });

    test('updateAssistantSettings with extended params', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = AssistantsNotifier();

      final assistant = notifier.createAssistant(
        name: '助手',
        prompt: '你好',
      );

      notifier.updateAssistantSettings(
        assistantId: assistant.id,
        frequencyPenalty: 0.5,
        enableFrequencyPenalty: true,
        presencePenalty: 0.3,
        enablePresencePenalty: true,
        seed: 42,
        enableSeed: true,
      );

      final updated = notifier.state.firstWhere((a) => a.id == assistant.id);
      expect(updated.settings.frequencyPenalty, 0.5);
      expect(updated.settings.enableFrequencyPenalty, true);
      expect(updated.settings.presencePenalty, 0.3);
      expect(updated.settings.enablePresencePenalty, true);
      expect(updated.settings.seed, 42);
      expect(updated.settings.enableSeed, true);

      // Other settings should remain default
      expect(updated.settings.temperature, 1.0);
      expect(updated.settings.topP, 1.0);
    });

    test('updateAssistantSettings with customParameters', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = AssistantsNotifier();

      final assistant = notifier.createAssistant(
        name: '助手',
        prompt: '你好',
      );

      final customParams = [
        CustomParameter(name: 'top_k', type: 'number', value: 40),
        CustomParameter(name: 'verbose', type: 'boolean', value: true),
      ];

      notifier.updateAssistantSettings(
        assistantId: assistant.id,
        customParameters: customParams,
      );

      final updated = notifier.state.firstWhere((a) => a.id == assistant.id);
      expect(updated.settings.customParameters.length, 2);
      expect(updated.settings.customParameters[0].name, 'top_k');
      expect(updated.settings.customParameters[0].value, 40);
      expect(updated.settings.customParameters[1].name, 'verbose');
      expect(updated.settings.customParameters[1].value, true);
    });
  });

  group('Conversation assistantId', () {
    test('conversation can be created with assistantId', () {
      final conv = Conversation(
        title: '对话1',
        assistantId: 'assistant-123',
      );

      expect(conv.assistantId, 'assistant-123');
    });

    test('conversation fromMap restores assistantId', () {
      final map = <String, dynamic>{
        'id': 'conv-1',
        'title': '话题',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': <dynamic>[],
        'isPinned': false,
        'sortOrder': 0,
        'assistantId': 'assistant-456',
      };

      final conv = Conversation.fromMap(map);
      expect(conv.assistantId, 'assistant-456');
    });

    test('conversation toMap includes assistantId when set', () {
      final conv = Conversation(
        title: '话题',
        assistantId: 'assistant-789',
      );

      final map = conv.toMap();
      expect(map['assistantId'], 'assistant-789');
    });

    test('conversation toMap omits assistantId when null (legacy)', () {
      final conv = Conversation(
        title: '话题',
      );

      final map = conv.toMap();
      expect(map.containsKey('assistantId'), false);
    });

    test(
        'legacy conversation (no assistantId) fromMap returns null assistantId',
        () {
      final map = <String, dynamic>{
        'id': 'conv-1',
        'title': '旧话题',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': <dynamic>[],
        'isPinned': false,
        'sortOrder': 0,
      };

      final conv = Conversation.fromMap(map);
      expect(conv.assistantId, isNull);
    });

    test('filter conversations by assistantId', () {
      final conversations = [
        Conversation(title: 'T1', assistantId: 'a1'),
        Conversation(title: 'T2', assistantId: 'a1'),
        Conversation(title: 'T3', assistantId: 'a2'),
        Conversation(title: 'T4'), // no assistant
      ];

      final a1Topics =
          conversations.where((c) => c.assistantId == 'a1').toList();
      final a2Topics =
          conversations.where((c) => c.assistantId == 'a2').toList();
      final nullTopics =
          conversations.where((c) => c.assistantId == null).toList();

      expect(a1Topics.length, 2);
      expect(a2Topics.length, 1);
      expect(nullTopics.length, 1);
    });
  });

  group('Migration: old conversations with null assistantId', () {
    test('migration assigns default assistant id to old conversations',
        () async {
      SharedPreferences.setMockInitialValues({});

      // Pre-populate with a default assistant
      final defaultAssistant = Assistant(
        name: '默认助手',
        prompt: '你是一个有帮助的AI助手。',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'assistants',
        jsonEncode([defaultAssistant.toMap()]),
      );

      // Pre-populate with legacy conversations (no assistantId)
      final legacyConversations = [
        Conversation(title: '旧对话1'),
        Conversation(title: '旧对话2'),
      ];
      await prefs.setString(
        'conversations',
        jsonEncode(legacyConversations.map((c) => c.toMap()).toList()),
      );

      // Run migration
      final migrated = await migrateConversationsFromPrefs(prefs);

      // After migration, conversations should have assistantId
      expect(migrated, isNotNull);
      expect(migrated!.length, 2);
      for (final conv in migrated) {
        expect(conv.assistantId, isNotNull);
        expect(conv.assistantId, defaultAssistant.id);
      }

      // Also verify persisted data
      final conversationsJson = prefs.getString('conversations');
      final conversations =
          (jsonDecode(conversationsJson!) as List).cast<Map<String, dynamic>>();
      expect(conversations[0]['assistantId'], defaultAssistant.id);
      expect(conversations[1]['assistantId'], defaultAssistant.id);
    });

    test('migration does not touch conversations that already have assistantId',
        () async {
      SharedPreferences.setMockInitialValues({});

      final defaultAssistant = Assistant(
        name: '默认助手',
        prompt: '你是一个有帮助的AI助手。',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'assistants',
        jsonEncode([defaultAssistant.toMap()]),
      );

      // Pre-populate with conversations that already have assistantId
      final existingConversations = [
        Conversation(title: '新对话1', assistantId: 'existing-a1'),
        Conversation(title: '新对话2', assistantId: 'existing-a2'),
      ];
      await prefs.setString(
        'conversations',
        jsonEncode(existingConversations.map((c) => c.toMap()).toList()),
      );

      // Run migration
      await migrateConversationsFromPrefs(prefs);

      // Verify assistant IDs preserved
      final conversationsJson = prefs.getString('conversations');
      final conversations =
          (jsonDecode(conversationsJson!) as List).cast<Map<String, dynamic>>();
      expect(conversations[0]['assistantId'], 'existing-a1');
      expect(conversations[1]['assistantId'], 'existing-a2');
    });

    test('migration is idempotent — running twice produces same result',
        () async {
      SharedPreferences.setMockInitialValues({});

      final defaultAssistant = Assistant(
        name: '默认助手',
        prompt: '你是一个有帮助的AI助手。',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'assistants',
        jsonEncode([defaultAssistant.toMap()]),
      );

      // Pre-populate with a legacy conversation
      await prefs.setString(
        'conversations',
        jsonEncode([
          Conversation(title: '旧对话').toMap(),
        ]),
      );

      // First run
      final migrated1 = await migrateConversationsFromPrefs(prefs);
      expect(migrated1, isNotNull);
      expect(migrated1!.first.assistantId, defaultAssistant.id);

      // Second run — should return null (already migrated)
      final migrated2 = await migrateConversationsFromPrefs(prefs);
      expect(migrated2, isNull);

      // Verify data is still correct in prefs
      final conversationsJson = prefs.getString('conversations');
      final conversations =
          (jsonDecode(conversationsJson!) as List).cast<Map<String, dynamic>>();
      expect(conversations.length, 1);
      expect(conversations[0]['assistantId'], defaultAssistant.id);
    });

    test(
        'migration creates default assistant when none exists and migrates conversations',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Pre-populate with legacy conversations (no assistantId)
      final legacyConversations = [
        Conversation(title: '旧对话1'),
        Conversation(title: '旧对话2'),
      ];
      await prefs.setString(
        'conversations',
        jsonEncode(legacyConversations.map((c) => c.toMap()).toList()),
      );

      // No assistants in prefs — migration should create the default assistant
      final result = await migrateConversationsFromPrefs(prefs);
      expect(result, isNotNull);
      expect(result!.length, 2);
      for (final conv in result) {
        expect(conv.assistantId, isNotNull);
      }

      // Verify the default assistant was created in prefs
      final assistantsJson = prefs.getString('assistants');
      expect(assistantsJson, isNotNull);
      final assistants =
          (jsonDecode(assistantsJson!) as List).cast<Map<String, dynamic>>();
      expect(assistants.length, 1);
      expect(assistants[0]['name'], '默认助手');

      // Verify conversations have the new assistant's ID
      final conversationsJson = prefs.getString('conversations');
      final conversations =
          (jsonDecode(conversationsJson!) as List).cast<Map<String, dynamic>>();
      expect(conversations[0]['assistantId'], assistants[0]['id']);
      expect(conversations[1]['assistantId'], assistants[0]['id']);

      // Verify the guard flag is set
      expect(prefs.getBool('migrated_old_conversations'), isTrue);
    });

    test('migration creates default assistant with expected properties',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        'conversations',
        jsonEncode([
          Conversation(title: '旧对话').toMap(),
        ]),
      );

      await migrateConversationsFromPrefs(prefs);

      final assistantsJson = prefs.getString('assistants');
      final assistants =
          (jsonDecode(assistantsJson!) as List).cast<Map<String, dynamic>>();
      expect(assistants.length, 1);
      expect(assistants[0]['name'], '默认助手');
      expect(assistants[0]['emoji'], '🤖');
      expect(assistants[0]['description'], '通用AI助手');
      expect(assistants[0]['prompt'], '你是一个有帮助的AI助手。请用中文回答用户的问题。');
    });

    test(
        'migration does not duplicate default assistant when one already exists',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Pre-populate with an existing assistant
      const existingAssistantId = 'existing-001';
      final existingAssistant = Assistant(
        id: existingAssistantId,
        name: '我的助手',
        prompt: '你好',
        emoji: '😊',
        description: '已有助手',
      );
      await prefs.setString(
        'assistants',
        jsonEncode([existingAssistant.toMap()]),
      );

      // Pre-populate with legacy conversations
      await prefs.setString(
        'conversations',
        jsonEncode([
          Conversation(title: '旧对话').toMap(),
        ]),
      );

      await migrateConversationsFromPrefs(prefs);

      // Verify only ONE assistant exists (no duplicate)
      final assistantsJson = prefs.getString('assistants');
      final assistants =
          (jsonDecode(assistantsJson!) as List).cast<Map<String, dynamic>>();
      expect(assistants.length, 1);
      expect(assistants[0]['id'], existingAssistantId);

      // Verify conversation was migrated to the existing assistant
      final conversationsJson = prefs.getString('conversations');
      final conversations =
          (jsonDecode(conversationsJson!) as List).cast<Map<String, dynamic>>();
      expect(conversations[0]['assistantId'], existingAssistantId);
    });

    test('migration returns null when already migrated', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('migrated_old_conversations', true);

      final result = await migrateConversationsFromPrefs(prefs);
      expect(result, isNull);
    });
  });
}
