import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/built_in_prompts.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';

void main() {
  group('AssistantModel', () {
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

    // ========================================================================
    // Extended params (frequencyPenalty, presencePenalty, seed)
    // ========================================================================

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

  group('BuiltInPrompt', () {
    test('every built-in prompt has required fields', () {
      for (final p in builtInPrompts) {
        expect(p.name, isNotEmpty, reason: 'Prompt name must not be empty');
        expect(p.prompt, isNotEmpty, reason: 'Prompt text must not be empty');
        expect(p.emoji, isNotEmpty, reason: 'Prompt emoji must not be empty');
        // description is optional (can be empty)
      }
    });

    test('builtInPrompts have unique names', () {
      final names = builtInPrompts.map((p) => p.name).toList();
      expect(names.toSet().length, names.length,
          reason: 'Each built-in prompt must have a unique name');
    });
  });

  group('AssistantProvider', () {
    test('updateAssistantDefaults can clear model and tool defaults', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = AssistantsNotifier();

      final a1 = notifier.createAssistant(name: '助手1', prompt: 'P1');
      notifier.updateAssistantDefaults(
        id: a1.id,
        defaultModelName: 'gpt-4o | OpenAI',
        defaultToolNames: {'web_search'},
      );
      notifier.updateAssistantDefaults(
        id: a1.id,
        defaultModelName: null,
        defaultToolNames: {},
      );

      final updated = notifier.state.firstWhere((a) => a.id == a1.id);
      expect(updated.defaultModelName, isNull);
      expect(updated.defaultToolNames, isEmpty);
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

    test('updateAssistantDefaults updates only the target assistant', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = AssistantsNotifier();

      final a1 = notifier.createAssistant(name: '助手1', prompt: 'P1');
      final a2 = notifier.createAssistant(name: '助手2', prompt: 'P2');

      notifier.updateAssistantDefaults(
        id: a1.id,
        defaultModelName: 'gpt-4o | OpenAI',
        defaultToolNames: {'web_search'},
      );

      final updated = notifier.state.firstWhere((a) => a.id == a1.id);
      expect(updated.defaultModelName, 'gpt-4o | OpenAI');
      expect(updated.defaultToolNames, {'web_search'});

      // The other assistant is untouched
      final other = notifier.state.firstWhere((a) => a.id == a2.id);
      expect(other.defaultModelName, isNull);
      expect(other.defaultToolNames, isNull);
    });

    test('updateAssistantDefaults can return to never-configured (null)', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = AssistantsNotifier();

      final a1 = notifier.createAssistant(name: '助手1', prompt: 'P1');
      notifier.updateAssistantDefaults(
        id: a1.id,
        defaultModelName: 'gpt-4o | OpenAI',
        defaultToolNames: {'web_search'},
      );
      notifier.updateAssistantDefaults(
        id: a1.id,
        defaultModelName: null,
        clearDefaultToolNames: true,
      );

      final updated = notifier.state.firstWhere((a) => a.id == a1.id);
      expect(updated.defaultModelName, isNull);
      expect(updated.defaultToolNames, isNull,
          reason: 'clearDefaultToolNames 使助手回到"从未配置"（null）状态，'
              '新话题重新自动启用全部工具');
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

    test('updateAssistantMcpVisibility toggles only the target assistant', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = AssistantsNotifier();

      final a1 = notifier.createAssistant(name: '助手1', prompt: 'P1');
      final a2 = notifier.createAssistant(name: '助手2', prompt: 'P2');

      notifier.updateAssistantMcpVisibility(
        id: a1.id,
        mcpToolsVisible: false,
      );

      expect(
        notifier.state.firstWhere((a) => a.id == a1.id).mcpToolsVisible,
        isFalse,
      );
      expect(
        notifier.state.firstWhere((a) => a.id == a2.id).mcpToolsVisible,
        isTrue,
      );

      // 可再开启
      notifier.updateAssistantMcpVisibility(
        id: a1.id,
        mcpToolsVisible: true,
      );
      expect(
        notifier.state.firstWhere((a) => a.id == a1.id).mcpToolsVisible,
        isTrue,
      );
    });

    test(
        'createAssistant defaults to visible before any provider master-switch '
        'toggle', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = AssistantsNotifier();

      final a1 = notifier.createAssistant(name: '助手1', prompt: 'P1');
      expect(a1.mcpToolsVisible, isTrue,
          reason: '未切换过 MCP总开关时新建助手默认可见（保持原有行为）');
    });

    test(
        'resetMcpToolsVisibility resets all assistants to off and new '
        'assistants default to off afterwards', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = AssistantsNotifier();

      final a1 = notifier.createAssistant(name: '助手1', prompt: 'P1');
      final a2 = notifier.createAssistant(name: '助手2', prompt: 'P2');
      // 模拟用户在助手页手动开启过显示开关
      notifier.updateAssistantMcpVisibility(
        id: a1.id,
        mcpToolsVisible: true,
      );
      expect(notifier.state.every((a) => a.mcpToolsVisible), isTrue);

      // 在 Provider 页切换过 MCP总开关 → 全部重置为关闭
      await notifier.resetMcpToolsVisibility();
      expect(notifier.state.every((a) => !a.mcpToolsVisible), isTrue,
          reason: '切换后助手页显示开关以关闭为基准，而不是以上一次状态为基准');

      // 之后新建的助手默认也是关闭
      final a3 = notifier.createAssistant(name: '助手3', prompt: 'P3');
      expect(a3.mcpToolsVisible, isFalse);

      // 持久化标记已写入
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('mcp_master_switch_toggled'), isTrue);
    });

    test('mcpToolsVisible survives loadFromJson round-trip', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = AssistantsNotifier();

      final a1 = notifier.createAssistant(name: '助手1', prompt: 'P1');
      notifier.updateAssistantMcpVisibility(
        id: a1.id,
        mcpToolsVisible: false,
      );

      final json = notifier.toJson();
      final notifier2 = AssistantsNotifier();
      notifier2.loadFromJson(json);

      expect(notifier2.state.first.mcpToolsVisible, isFalse);
    });

    test('updateAssistantDefaults preserves mcpToolsVisible', () {
      SharedPreferences.setMockInitialValues({});
      final notifier = AssistantsNotifier();

      final a1 = notifier.createAssistant(name: '助手1', prompt: 'P1');
      notifier.updateAssistantMcpVisibility(
        id: a1.id,
        mcpToolsVisible: false,
      );

      // 更新默认工具/默认模型不应把显示开关重置回可见
      notifier.updateAssistantDefaults(
        id: a1.id,
        defaultModelName: 'gpt-4o | OpenAI',
        defaultToolNames: {'web_search'},
      );

      final updated = notifier.state.firstWhere((a) => a.id == a1.id);
      expect(updated.mcpToolsVisible, isFalse,
          reason: 'updateAssistantDefaults 重建 Assistant 时必须保留显示开关');
      expect(updated.defaultToolNames, {'web_search'});
    });
  });

  // ========================================================================
  // 助手默认值：新建话题的默认模型 + 默认启用工具
  // ========================================================================
  group('Assistant conversation defaults', () {
    test('defaults survive toMap/fromMap round-trip', () {
      final original = Assistant(
        name: '助手',
        prompt: '你好',
        defaultModelName: 'gpt-4o | OpenAI',
        defaultToolNames: {'web_search', 'todowrite'},
      );

      final map = original.toMap();
      final restored = Assistant.fromMap(map);

      expect(restored.defaultModelName, 'gpt-4o | OpenAI');
      expect(restored.defaultToolNames, {'web_search', 'todowrite'});
    });

    test('configured-empty tool set round-trips as non-null empty', () {
      final original = Assistant(
        name: '助手',
        prompt: '你好',
        defaultModelName: null,
        defaultToolNames: {},
      );

      final map = original.toMap();
      final restored = Assistant.fromMap(map);

      expect(restored.defaultModelName, isNull);
      expect(restored.defaultToolNames, isNotNull,
          reason: '配置过但全关（空集合）必须与"从未配置"（null）区分，'
              '否则新话题会退回自动启用全部工具');
      expect(restored.defaultToolNames, isEmpty);
    });

    test('unconfigured tool set round-trips as null', () {
      final original = Assistant(name: '助手', prompt: '你好');

      final map = original.toMap();
      final restored = Assistant.fromMap(map);

      expect(restored.defaultToolNames, isNull);
    });

    test('legacy assistant map without new fields parses with defaults', () {
      final map = <String, dynamic>{
        'id': 'legacy-1',
        'name': '旧助手',
        'prompt': '你好',
      };

      final assistant = Assistant.fromMap(map);
      expect(assistant.defaultModelName, isNull);
      expect(assistant.defaultToolNames, isNull);
    });

    test('mcpToolsVisible survives toMap/fromMap round-trip', () {
      final original = Assistant(
        name: '助手',
        prompt: '你好',
        mcpToolsVisible: false,
      );

      final map = original.toMap();
      expect(map['mcpToolsVisible'], isFalse);

      final restored = Assistant.fromMap(map);
      expect(restored.mcpToolsVisible, isFalse);
    });

    test('legacy assistant map without mcpToolsVisible parses as visible', () {
      final map = <String, dynamic>{
        'id': 'legacy-1',
        'name': '旧助手',
        'prompt': '你好',
      };

      final assistant = Assistant.fromMap(map);
      expect(assistant.mcpToolsVisible, isTrue,
          reason: '旧数据缺省可见，保持原有行为（MCP 工具在对话页可选用）');
    });
  });

  group('Conversation assistantId', () {
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
      expect(assistants[0]['description'], '');
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
