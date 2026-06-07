import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      expect(settings.reasoningEffort, 'default');
      expect(settings.enableWebSearch, false);
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
        reasoningEffort: 'high',
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
      expect(restored.reasoningEffort, 'high');
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

    test('assistant toMap/fromMap round-trip', () {
      final settings = AssistantSettings(
        temperature: 0.5,
        enableTemperature: true,
        topP: 0.8,
        enableTopP: true,
        maxTokens: 1024,
        enableMaxTokens: true,
        streamOutput: true,
        reasoningEffort: 'low',
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

    test('conversation toMap omits assistantId when null', () {
      final conv = Conversation(
        title: '话题',
      );

      final map = conv.toMap();
      expect(map.containsKey('assistantId'), false);
    });

    test('legacy conversation (no assistantId) fromMap returns null assistantId', () {
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

      final a1Topics = conversations.where((c) => c.assistantId == 'a1').toList();
      final a2Topics = conversations.where((c) => c.assistantId == 'a2').toList();
      final nullTopics = conversations.where((c) => c.assistantId == null).toList();

      expect(a1Topics.length, 2);
      expect(a2Topics.length, 1);
      expect(nullTopics.length, 1);
    });
  });

  group('Migration: old conversations to default assistant', () {
    test('migrates old conversations (null assistantId) to default assistant', () async {
      final defaultAssistant = Assistant(
        name: '默认助手',
        prompt: '你是一个有帮助的AI助手。',
      );

      SharedPreferences.setMockInitialValues({
        'conversations': jsonEncode([
          {
            'id': 'old-conv-1',
            'title': '旧对话1',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
            'messages': <dynamic>[],
            'isPinned': false,
            'sortOrder': 0,
          },
          {
            'id': 'old-conv-2',
            'title': '旧对话2',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
            'messages': <dynamic>[],
            'isPinned': false,
            'sortOrder': 0,
          },
        ]),
        'assistants': jsonEncode([defaultAssistant.toMap()]),
      });

      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      // Trigger assistant provider first — migration runs during _load()
      container.read(assistantProvider);
      await Future(() => null);

      // Then trigger conversation provider — reads already-migrated data
      container.read(conversationsProvider);
      await Future(() => null);

      final conversations = container.read(conversationsProvider);
      expect(conversations.length, 2);
      for (final conv in conversations) {
        expect(conv.assistantId, defaultAssistant.id,
            reason: 'Conversation "${conv.title}" should have default assistant ID');
      }

      // Migration flag should be set
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('migrated_old_conversations'), true);
    });

    test('creates default assistant then migrates when no assistants exist', () async {
      SharedPreferences.setMockInitialValues({
        'conversations': jsonEncode([
          {
            'id': 'old-conv-1',
            'title': '旧对话1',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
            'messages': <dynamic>[],
            'isPinned': false,
            'sortOrder': 0,
          },
        ]),
      });

      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      // Trigger assistant provider first — creates default assistant + migration
      container.read(assistantProvider);
      await Future(() => null);

      // Then trigger conversation provider
      container.read(conversationsProvider);
      await Future(() => null);

      final conversations = container.read(conversationsProvider);
      expect(conversations.length, 1);
      expect(conversations.first.assistantId, isNotNull);

      // Verify a default assistant was created
      final assistants = container.read(assistantProvider);
      expect(assistants.length, 1);
      expect(assistants.first.name, '默认助手');

      // The conversation should reference the same default assistant
      expect(
        assistants.any((a) => a.id == conversations.first.assistantId),
        true,
        reason: 'Conversation should reference the default assistant ID',
      );
    });

    test('migration flag prevents re-running on subsequent loads', () async {
      SharedPreferences.setMockInitialValues({
        'conversations': jsonEncode([
          {
            'id': 'old-conv-1',
            'title': '旧对话1',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
            'messages': <dynamic>[],
            'isPinned': false,
            'sortOrder': 0,
          },
        ]),
        'migrated_old_conversations': true, // Already migrated
      });

      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      container.read(assistantProvider);
      await Future(() => null);

      container.read(conversationsProvider);
      await Future(() => null);

      // Conversations with null assistantId should stay null
      final conversations = container.read(conversationsProvider);
      expect(conversations.length, 1);
      expect(conversations.first.assistantId, isNull);
    });

    test('conversations with existing assistantId are left unchanged', () async {
      final defaultAssistant = Assistant(
        name: '默认助手',
        prompt: 'Test',
      );

      SharedPreferences.setMockInitialValues({
        'conversations': jsonEncode([
          {
            'id': 'conv-with-assistant',
            'title': '已有助手的对话',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
            'messages': <dynamic>[],
            'isPinned': false,
            'sortOrder': 0,
            'assistantId': 'custom-assistant-id',
          },
          {
            'id': 'old-conv',
            'title': '旧对话',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
            'messages': <dynamic>[],
            'isPinned': false,
            'sortOrder': 0,
          },
        ]),
        'assistants': jsonEncode([defaultAssistant.toMap()]),
      });

      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      container.read(assistantProvider);
      await Future(() => null);

      container.read(conversationsProvider);
      await Future(() => null);

      final conversations = container.read(conversationsProvider);
      expect(conversations.length, 2);

      // The conversation that already had an assistantId should keep it
      final withAssistant =
          conversations.firstWhere((c) => c.id == 'conv-with-assistant');
      expect(withAssistant.assistantId, 'custom-assistant-id');

      // The old conversation should be migrated
      final oldConv = conversations.firstWhere((c) => c.id == 'old-conv');
      expect(oldConv.assistantId, defaultAssistant.id);
    });

    test('handles empty conversations list gracefully', () async {
      SharedPreferences.setMockInitialValues({
        'conversations': jsonEncode(<dynamic>[]),
      });

      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      container.read(assistantProvider);
      await Future(() => null);
      await Future(() => null);

      container.read(conversationsProvider);
      await Future(() => null);
      await Future(() => null);

      // No conversations — nothing to migrate, but no crash either
      final conversations = container.read(conversationsProvider);
      expect(conversations, isEmpty);

      // Migration flag should still be set
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('migrated_old_conversations'), true);
    });
  });

  // ============================================================================
  // New feature tests: Enhanced emoji/image + extended parameters
  // ============================================================================

  group('Assistant avatar support', () {
    test('assistant defaults use emoji with no avatarPath', () {
      final assistant = Assistant(
        name: '测试头像',
        prompt: '你好！',
      );

      expect(assistant.emoji, '🤖');
      expect(assistant.avatarPath, isNull);
    });

    test('assistant toMap/fromMap preserves avatarPath', () {
      final original = Assistant(
        name: '图片助手',
        prompt: 'Test',
        emoji: '📷',
        avatarPath: '/path/to/avatar.png',
      );

      final map = original.toMap();
      final restored = Assistant.fromMap(map);

      expect(restored.avatarPath, '/path/to/avatar.png');
      expect(restored.emoji, '📷');
    });

    test('assistant with avatarPath toMap includes it', () {
      final assistant = Assistant(
        name: '助手',
        prompt: 'Test',
        avatarPath: '/data/avatars/img1.jpg',
      );

      final map = assistant.toMap();
      expect(map['avatarPath'], '/data/avatars/img1.jpg');
    });

    test('assistant without avatarPath omits from map', () {
      final assistant = Assistant(
        name: '助手',
        prompt: 'Test',
      );

      final map = assistant.toMap();
      expect(map.containsKey('avatarPath'), false);
    });

    test('legacy assistant (no avatarPath) fromMap returns null avatarPath', () {
      final map = <String, dynamic>{
        'id': 'legacy-id',
        'name': '旧助手',
        'prompt': 'Hello',
        'emoji': '🤖',
        'description': '',
        'settings': AssistantSettings.defaults().toMap(),
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final assistant = Assistant.fromMap(map);
      expect(assistant.avatarPath, isNull);
      expect(assistant.emoji, '🤖');
    });
  });

  group('AssistantSettings extended params', () {
    test('default settings have new extended values', () {
      final settings = AssistantSettings.defaults();

      // Existing fields
      expect(settings.temperature, 1.0);
      expect(settings.enableTemperature, false);

      // New fields
      expect(settings.topK, 0);
      expect(settings.enableTopK, false);
      expect(settings.frequencyPenalty, 0.0);
      expect(settings.enableFrequencyPenalty, false);
      expect(settings.presencePenalty, 0.0);
      expect(settings.enablePresencePenalty, false);
      expect(settings.overrideModelSettings, false);
    });

    test('extended settings serialization round-trip', () {
      final original = AssistantSettings(
        temperature: 0.7,
        enableTemperature: true,
        topP: 0.9,
        enableTopP: true,
        maxTokens: 4096,
        enableMaxTokens: true,
        topK: 40,
        enableTopK: true,
        frequencyPenalty: 0.5,
        enableFrequencyPenalty: true,
        presencePenalty: -0.2,
        enablePresencePenalty: true,
        overrideModelSettings: true,
        customParameters: [
          CustomParameter(name: 'top_k', type: 'number', value: 40),
        ],
      );

      final map = original.toMap();
      final restored = AssistantSettings.fromMap(map);

      expect(restored.topK, 40);
      expect(restored.enableTopK, true);
      expect(restored.frequencyPenalty, 0.5);
      expect(restored.enableFrequencyPenalty, true);
      expect(restored.presencePenalty, -0.2);
      expect(restored.enablePresencePenalty, true);
      expect(restored.overrideModelSettings, true);
    });

    test('extended settings defaults round-trip', () {
      final original = AssistantSettings.defaults();
      final map = original.toMap();
      final restored = AssistantSettings.fromMap(map);

      expect(restored.topK, original.topK);
      expect(restored.enableTopK, original.enableTopK);
      expect(restored.frequencyPenalty, original.frequencyPenalty);
      expect(restored.enableFrequencyPenalty, original.enableFrequencyPenalty);
      expect(restored.presencePenalty, original.presencePenalty);
      expect(restored.enablePresencePenalty, original.enablePresencePenalty);
      expect(restored.overrideModelSettings, original.overrideModelSettings);
    });

    test('copyWith preserves new fields', () {
      final original = AssistantSettings.defaults();
      final modified = original.copyWith(
        topK: 50,
        enableTopK: true,
        overrideModelSettings: true,
      );

      expect(modified.topK, 50);
      expect(modified.enableTopK, true);
      expect(modified.overrideModelSettings, true);
      // Other fields unchanged
      expect(modified.temperature, 1.0);
      expect(modified.frequencyPenalty, 0.0);
    });

    test('legacy map (no new fields) loads defaults', () {
      final map = <String, dynamic>{
        'temperature': 0.5,
        'enableTemperature': true,
        'topP': 0.8,
        'enableTopP': false,
        'maxTokens': 2048,
        'enableMaxTokens': true,
        'streamOutput': true,
        'reasoningEffort': 'default',
        'enableWebSearch': false,
        'maxToolCalls': 20,
        'enableMaxToolCalls': true,
        'customParameters': <dynamic>[],
      };

      final settings = AssistantSettings.fromMap(map);
      expect(settings.topK, 0);
      expect(settings.enableTopK, false);
      expect(settings.frequencyPenalty, 0.0);
      expect(settings.enableFrequencyPenalty, false);
      expect(settings.presencePenalty, 0.0);
      expect(settings.enablePresencePenalty, false);
      expect(settings.overrideModelSettings, false);
      // Existing fields still work
      expect(settings.temperature, 0.5);
    });
  });

  group('Provider extended params update', () {
    test('updateAssistantSettings handles new params', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = AssistantsNotifier();

      final assistant = notifier.createAssistant(
        name: '扩展参数助手',
        prompt: 'Test',
      );

      notifier.updateAssistantSettings(
        assistantId: assistant.id,
        topK: 50,
        enableTopK: true,
        frequencyPenalty: 0.3,
        enableFrequencyPenalty: true,
        presencePenalty: -0.1,
        enablePresencePenalty: true,
        overrideModelSettings: true,
      );

      final updated = notifier.state.firstWhere((a) => a.id == assistant.id);
      expect(updated.settings.topK, 50);
      expect(updated.settings.enableTopK, true);
      expect(updated.settings.frequencyPenalty, 0.3);
      expect(updated.settings.enableFrequencyPenalty, true);
      expect(updated.settings.presencePenalty, -0.1);
      expect(updated.settings.enablePresencePenalty, true);
      expect(updated.settings.overrideModelSettings, true);
      // Other fields unchanged
      expect(updated.settings.temperature, 1.0);
      expect(updated.settings.topP, 1.0);
    });

    test('updateAssistant with avatarPath updates field', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = AssistantsNotifier();

      final assistant = notifier.createAssistant(
        name: '头像助手',
        prompt: 'Test',
      );

      notifier.updateAssistant(
        id: assistant.id,
        avatarPath: '/new/avatar.png',
      );

      final updated = notifier.state.firstWhere((a) => a.id == assistant.id);
      expect(updated.avatarPath, '/new/avatar.png');
      expect(updated.emoji, '🤖'); // emoji unchanged
    });
  });
}
