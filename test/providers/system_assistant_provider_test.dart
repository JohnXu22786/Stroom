import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/built_in_assistants.dart';
import 'package:stroom/providers/system_assistant_provider.dart';

/// 轮询读取 provider 实时状态，直到 [cond] 为真（异步 _load 完成后返回）。
/// 注意：container.read 返回的是快照，必须反复重读才能感知异步加载。
Future<SystemAssistantSettings> _waitForSettings(
  ProviderContainer container,
  bool Function(SystemAssistantSettings s) cond,
) async {
  late SystemAssistantSettings current;
  for (var i = 0; i < 200; i++) {
    current = container.read(systemAssistantSettingsProvider);
    if (cond(current)) return current;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return current;
}

/// 轮询等待 prefs 满足 [cond]（迁移删除旧 key 等异步写完成后断言）。
Future<void> _waitForPrefs(bool Function(SharedPreferences prefs) cond) async {
  final prefs = await SharedPreferences.getInstance();
  for (var i = 0; i < 200 && !cond(prefs); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SystemAssistantTaskConfig', () {
    test('hasModel/hasPrompt reflect the reference fields', () {
      expect(const SystemAssistantTaskConfig().hasModel, isFalse);
      expect(const SystemAssistantTaskConfig().hasPrompt, isFalse);
      expect(
        const SystemAssistantTaskConfig(modelId: 'gpt-4o').hasModel,
        isTrue,
      );
      expect(
        const SystemAssistantTaskConfig(modelDisplayName: 'X | Y').hasModel,
        isTrue,
      );
      expect(
        const SystemAssistantTaskConfig(prompt: 'hi').hasPrompt,
        isTrue,
      );
    });

    test('copyWithModel replaces and clears the model reference', () {
      const base = SystemAssistantTaskConfig(
        modelId: 'a',
        providerName: 'P',
        modelDisplayName: 'A | P',
        prompt: 'custom',
      );
      final replaced = base.copyWithModel(
        modelId: 'b',
        providerName: 'Q',
        modelDisplayName: 'B | Q',
      );
      expect(replaced.modelId, 'b');
      expect(replaced.providerName, 'Q');
      expect(replaced.modelDisplayName, 'B | Q');
      // prompt 不受模型字段影响
      expect(replaced.prompt, 'custom');

      final cleared = base.copyWithModel(clearModel: true);
      expect(cleared.hasModel, isFalse);
      expect(cleared.prompt, 'custom');
    });

    test('copyWithPrompt replaces the prompt only', () {
      const base = SystemAssistantTaskConfig(
        modelId: 'a',
        providerName: 'P',
        prompt: 'custom',
      );
      final withPrompt = base.copyWithPrompt('new');
      expect(withPrompt.prompt, 'new');
      expect(withPrompt.modelId, 'a');
      final reset = base.copyWithPrompt(null);
      expect(reset.hasPrompt, isFalse);
      expect(reset.modelId, 'a');
    });
  });

  group('resolveSystemAssistantPrompt', () {
    test('returns custom prompt when set, built-in otherwise', () {
      const task = SystemAssistantTaskConfig(prompt: '我的自定义提示词');
      expect(
        resolveSystemAssistantPrompt(task,
            defaultAssistantId: kBuiltInTitleAssistantId),
        '我的自定义提示词',
      );
      expect(
        resolveSystemAssistantPrompt(const SystemAssistantTaskConfig(),
            defaultAssistantId: kBuiltInTitleAssistantId),
        builtInSystemAssistantById(kBuiltInTitleAssistantId)!.prompt,
      );
      expect(
        resolveSystemAssistantPrompt(const SystemAssistantTaskConfig(),
            defaultAssistantId: kBuiltInCompactionAssistantId),
        builtInSystemAssistantById(kBuiltInCompactionAssistantId)!.prompt,
      );
    });
  });

  group('SystemAssistantSettingsNotifier persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('setTitleTask persists model ref + prompt and clears on null',
        () async {
      final notifier = SystemAssistantSettingsNotifier();
      await notifier.setTitleTask(
        const SystemAssistantTaskConfig(
          modelId: 'gpt-4o',
          providerName: 'OpenAI',
          modelDisplayName: 'GPT-4o | OpenAI',
          prompt: '标题提示词',
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('system_title_model_id'), 'gpt-4o');
      expect(prefs.getString('system_title_model_provider'), 'OpenAI');
      expect(prefs.getString('system_title_model_name'), 'GPT-4o | OpenAI');
      expect(prefs.getString('system_title_prompt'), '标题提示词');

      // 清空模型 + 恢复默认提示词 → 相关 key 删除
      await notifier.setTitleTask(const SystemAssistantTaskConfig());
      expect(prefs.getString('system_title_model_id'), isNull);
      expect(prefs.getString('system_title_prompt'), isNull);
    });

    test('setters do not disturb the other task', () async {
      final notifier = SystemAssistantSettingsNotifier();
      await notifier.setCompactionTask(
        const SystemAssistantTaskConfig(prompt: '压缩提示词'),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('system_compaction_prompt'), '压缩提示词');
      expect(prefs.getString('system_title_prompt'), isNull);
    });

    test('load round-trips the new-format keys', () async {
      SharedPreferences.setMockInitialValues({
        'system_title_model_id': 'gpt-4o',
        'system_title_model_provider': 'OpenAI',
        'system_title_model_name': 'GPT-4o | OpenAI',
        'system_title_prompt': '标题提示词',
        'system_compaction_prompt': '压缩提示词',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final settings = await _waitForSettings(
        container,
        (s) => s.title.hasModel && s.title.hasPrompt && s.compaction.hasPrompt,
      );
      expect(settings.title.modelId, 'gpt-4o');
      expect(settings.title.providerName, 'OpenAI');
      expect(settings.title.modelDisplayName, 'GPT-4o | OpenAI');
      expect(settings.title.prompt, '标题提示词');
      expect(settings.compaction.prompt, '压缩提示词');
      expect(settings.compaction.hasModel, isFalse);
    });
  });

  group('legacy v1 migration (assistant id → prompt)', () {
    Future<String> assistantsJson(String id, String prompt) async {
      final a = Assistant(name: '自定义助手', prompt: prompt);
      final map = a.toMap();
      map['id'] = id;
      return jsonEncode([map]);
    }

    test(
        'user assistant is migrated to a custom prompt and legacy key '
        'removed', () async {
      SharedPreferences.setMockInitialValues({
        'system_title_assistant_id': 'legacy-assistant-1',
        'assistants':
            await assistantsJson('legacy-assistant-1', '这个助手是我的标题提示词'),
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(systemAssistantSettingsProvider); // 触发异步 _load
      final settings = await _waitForSettings(
        container,
        (s) => s.title.hasPrompt,
      );
      expect(settings.title.prompt, '这个助手是我的标题提示词');
      await _waitForPrefs(
          (prefs) => prefs.getString('system_title_assistant_id') == null);
      final prefs = await SharedPreferences.getInstance();
      // 幂等：旧 key 删除
      expect(prefs.getString('system_title_assistant_id'), isNull);
      expect(prefs.getString('system_title_prompt'), '这个助手是我的标题提示词');
    });

    test('built-in assistant leaves prompt default and removes legacy key',
        () async {
      SharedPreferences.setMockInitialValues({
        'system_title_assistant_id': kBuiltInTitleAssistantId,
        'system_compaction_assistant_id': kBuiltInCompactionAssistantId,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(systemAssistantSettingsProvider); // 触发异步 _load
      await _waitForPrefs((prefs) =>
          prefs.getString('system_title_assistant_id') == null &&
          prefs.getString('system_compaction_assistant_id') == null);
      final settings = container.read(systemAssistantSettingsProvider);
      expect(settings.title.prompt, isNull);
      expect(settings.compaction.prompt, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('system_title_assistant_id'), isNull);
      expect(prefs.getString('system_compaction_assistant_id'), isNull);
      expect(prefs.getString('system_title_prompt'), isNull);
    });

    test('unknown assistant id resolves no prompt and removes legacy key',
        () async {
      SharedPreferences.setMockInitialValues({
        'system_compaction_assistant_id': 'gone-assistant',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(systemAssistantSettingsProvider); // 触发异步 _load
      await _waitForPrefs(
          (prefs) => prefs.getString('system_compaction_assistant_id') == null);
      final settings = container.read(systemAssistantSettingsProvider);
      expect(settings.compaction.prompt, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('system_compaction_assistant_id'), isNull);
    });

    test('migration does not overwrite an existing new-format prompt',
        () async {
      SharedPreferences.setMockInitialValues({
        'system_title_assistant_id': 'legacy-assistant-1',
        'system_title_prompt': '已保存的新格式提示词',
        'assistants': await assistantsJson('legacy-assistant-1', '旧助手提示词'),
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(systemAssistantSettingsProvider); // 触发异步 _load
      final settings = await _waitForSettings(
        container,
        (s) => s.title.hasPrompt,
      );
      expect(settings.title.prompt, '已保存的新格式提示词');
      await _waitForPrefs(
          (prefs) => prefs.getString('system_title_assistant_id') == null);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('system_title_prompt'), '已保存的新格式提示词');
      expect(prefs.getString('system_title_assistant_id'), isNull);
    });

    test('assistants JSON 解析失败时保留旧 key（下次启动重试）', () async {
      SharedPreferences.setMockInitialValues({
        'system_title_assistant_id': 'legacy-assistant-1',
        'assistants': '{broken',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(systemAssistantSettingsProvider); // 触发异步 _load
      // 给迁移留出执行窗口：期间旧 key 不得被删除
      // （否则唯一一份 v1 绑定永久丢失）。
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('system_title_assistant_id'), 'legacy-assistant-1',
          reason: 'assistants 解析失败时不能删除旧 key');
      expect(prefs.getString('system_title_prompt'), isNull);
    });

    test('迁移时去掉助手提示词首尾空白', () async {
      SharedPreferences.setMockInitialValues({
        'system_compaction_assistant_id': 'legacy-assistant-2',
        'assistants': await assistantsJson('legacy-assistant-2', '  压缩助手提示词  '),
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(systemAssistantSettingsProvider); // 触发异步 _load
      final settings = await _waitForSettings(
        container,
        (s) => s.compaction.hasPrompt,
      );
      expect(settings.compaction.prompt, '压缩助手提示词');
      await _waitForPrefs(
          (prefs) => prefs.getString('system_compaction_assistant_id') == null);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('system_compaction_prompt'), '压缩助手提示词');
    });
  });
}
