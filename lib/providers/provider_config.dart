import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tts_models.dart';

export '../models/tts_models.dart';

// ============================================================================
// 供应商类型注册表 — 每种类型可注册默认值，新增类型只需注册一次
// ============================================================================

/// 模型配置页面的样式
enum ModelConfigStyle {
  /// TTS 样式：音色、音量、语速、裁切、流式输出、instruction 等
  tts,

  /// LLM 样式：模型ID、上下文长度、自定义参数
  llm,

  /// 简洁样式：模型ID、自定义参数（无上下文长度要求），用于 OCR、ASR
  simple,
}

class ProviderTypeDefinition {
  final String type;
  final String? defaultHost;
  final String? hostHint;
  final List<ModelConfig> defaultModels;
  final ModelConfigStyle modelConfigStyle;

  bool get useLlmModelConfig => modelConfigStyle == ModelConfigStyle.llm;

  const ProviderTypeDefinition({
    required this.type,
    this.defaultHost,
    this.hostHint,
    this.defaultModels = const [],
    this.modelConfigStyle = ModelConfigStyle.tts,
  });
}

class ProviderTypeRegistry {
  static final Map<String, ProviderTypeDefinition> _registry = {};

  static void register(ProviderTypeDefinition def) {
    _registry[def.type] = def;
  }

  static ProviderTypeDefinition? get(String type) => _registry[type];

  static bool isRegistered(String type) => _registry.containsKey(type);
}

void registerBuiltinProviderTypes() {
  ProviderTypeRegistry.register(
    const ProviderTypeDefinition(
      type: 'llm',
      hostHint: '例如: https://api.openai.com/v1/chat/completions',
      modelConfigStyle: ModelConfigStyle.llm,
    ),
  );
  ProviderTypeRegistry.register(
    const ProviderTypeDefinition(
      type: 'tts',
      hostHint: '例如: https://api.openai.com/v1/audio/speech',
      modelConfigStyle: ModelConfigStyle.tts,
    ),
  );
  ProviderTypeRegistry.register(
    const ProviderTypeDefinition(
      type: 'ocr',
      hostHint: '例如: https://api.openai.com/v1/chat/completions',
      modelConfigStyle: ModelConfigStyle.simple,
    ),
  );
  ProviderTypeRegistry.register(
    const ProviderTypeDefinition(
      type: 'asr',
      hostHint: '例如: https://api.openai.com/v1/audio/transcriptions',
      modelConfigStyle: ModelConfigStyle.simple,
    ),
  );
  ProviderTypeRegistry.register(
    const ProviderTypeDefinition(
      type: 'mcp',
      hostHint: '例如: http://localhost:3001/sse',
    ),
  );
}

// ============================================================================
// 供应商条目列表状态
// ============================================================================

class ProviderEntriesState {
  final List<ProviderEntry> entries;

  const ProviderEntriesState({this.entries = const []});
}

/// 供应商条目列表提供器（持久化）
final providerEntriesProvider =
    StateNotifierProvider<ProviderEntriesNotifier, ProviderEntriesState>((ref) {
      final notifier = ProviderEntriesNotifier();
      notifier.load();
      return notifier;
    });

class ProviderEntriesNotifier extends StateNotifier<ProviderEntriesState> {
  ProviderEntriesNotifier() : super(const ProviderEntriesState());

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 第1步：迁移旧版 chat_configs → provider_entries
      await _migrateOldChatConfigs(prefs);

      // 第2步：迁移旧版 CustomParam 缺少 type 字段的问题
      await _migrateOldCustomParams(prefs);

      // 第3步：正常加载 provider_entries
      final json = prefs.getString('provider_entries');
      if (json != null) {
        final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
        final entries = list.map((m) => ProviderEntry.fromMap(m)).toList();

        // 第4步：确保 OCR 条目存在（已有用户升级时自动迁移）
        final hasOcr = entries.any((e) => e.type == 'ocr');
        if (!hasOcr) {
          entries.add(
            ProviderEntry(id: 'builtin_ocr', type: 'ocr', name: 'OCR供应商'),
          );
          await prefs.setString(
            'provider_entries',
            jsonEncode(entries.map((e) => e.toMap()).toList()),
          );
        }

        // 第5步：确保 ASR（语音识别）条目存在（已有用户升级时自动迁移）
        final hasAsr = entries.any((e) => e.type == 'asr');
        if (!hasAsr) {
          entries.add(
            ProviderEntry(id: 'builtin_asr', type: 'asr', name: '音频转写供应商'),
          );
          await prefs.setString(
            'provider_entries',
            jsonEncode(entries.map((e) => e.toMap()).toList()),
          );
        }

        // 第6步：确保 MCP 条目存在（已有用户升级时自动迁移）
        final hasMcp = entries.any((e) => e.type == 'mcp');
        if (!hasMcp) {
          entries.add(
            ProviderEntry(id: 'builtin_mcp', type: 'mcp', name: 'MCP供应商'),
          );
          await prefs.setString(
            'provider_entries',
            jsonEncode(entries.map((e) => e.toMap()).toList()),
          );
        }

        state = ProviderEntriesState(entries: entries);
        return;
      }
    } catch (e) {
      debugPrint('Failed to load provider entries: $e');
    }

    // 默认预置
    state = ProviderEntriesState(
      entries: [
        ProviderEntry(id: 'builtin_tts', type: 'tts', name: 'TTS供应商'),
        ProviderEntry(id: 'builtin_llm', type: 'llm', name: 'LLM供应商'),
        ProviderEntry(id: 'builtin_ocr', type: 'ocr', name: 'OCR供应商'),
        ProviderEntry(id: 'builtin_asr', type: 'asr', name: '音频转写供应商'),
        ProviderEntry(id: 'builtin_mcp', type: 'mcp', name: 'MCP供应商'),
      ],
    );
  }

  /// 迁移旧版 chat_configs（被重构删除的 ChatProviderConfigItem 格式）到 provider_entries
  Future<void> _migrateOldChatConfigs(SharedPreferences prefs) async {
    final oldJson = prefs.getString('chat_configs');
    if (oldJson == null || oldJson.isEmpty) return;

    try {
      final oldList = (jsonDecode(oldJson) as List)
          .cast<Map<String, dynamic>>();
      if (oldList.isEmpty) return;

      final migratedConfigs = <ProviderConfigItem>[];
      for (final oldItem in oldList) {
        final oldModels =
            (oldItem['models'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        final models = oldModels.map((m) {
          final typeConfig = <String, dynamic>{};
          final maxTokens = m['maxTokens'] ?? m['context'];
          if (maxTokens != null) typeConfig['context'] = maxTokens;
          final temperature = m['temperature'];
          if (temperature != null) typeConfig['temperature'] = temperature;

          return ModelConfig(
            name: m['modelId'] as String? ?? '',
            modelId: m['modelId'] as String? ?? '',
            supportStream: m['supportStream'] as bool? ?? true,
            typeConfig: typeConfig,
          );
        }).toList();

        migratedConfigs.add(
          ProviderConfigItem(
            providerName: oldItem['providerName'] as String? ?? '',
            host: oldItem['host'] as String? ?? '',
            key: oldItem['key'] as String? ?? '',
            models: models,
          ),
        );
      }

      if (migratedConfigs.isEmpty) return;

      // 读取或初始化当前 provider_entries
      String? existingJson;
      try {
        existingJson = prefs.getString('provider_entries');
      } catch (_) {}

      List<Map<String, dynamic>> existingEntries = [];
      if (existingJson != null && existingJson.isNotEmpty) {
        existingEntries = (jsonDecode(existingJson) as List)
            .cast<Map<String, dynamic>>();
      }

      // 如果已有 llm 类型条目则不覆盖
      final hasLlmEntry = existingEntries.any(
        (e) => e['type'] == 'llm' && e['id'] != 'builtin_llm',
      );
      if (!hasLlmEntry) {
        existingEntries.add({
          'id': 'migrated_llm',
          'type': 'llm',
          'name': 'LLM供应商',
          'configs': migratedConfigs.map((c) => c.toMap()).toList(),
        });

        await prefs.setString('provider_entries', jsonEncode(existingEntries));
      }

      // 删除旧数据，防止重复迁移
      await prefs.remove('chat_configs');
      await prefs.remove('chat_selected_config_id');
      debugPrint(
        'Migrated ${oldList.length} old chat config(s) to provider_entries',
      );
    } catch (e) {
      debugPrint('Failed to migrate old chat configs: $e');
    }
  }

  Future<void> _migrateOldCustomParams(SharedPreferences prefs) async {
    try {
      final json = prefs.getString('provider_entries');
      if (json == null || json.isEmpty) return;

      final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
      bool changed = false;

      for (final entry in list) {
        final configs = entry['configs'] as List?;
        if (configs == null) continue;
        for (final config in configs) {
          final configMap = config as Map<String, dynamic>;
          final models = configMap['models'] as List?;
          if (models == null) continue;
          for (final model in models) {
            final modelMap = model as Map<String, dynamic>;
            final customParams = modelMap['customParams'] as List?;
            if (customParams == null) continue;
            for (int i = 0; i < customParams.length; i++) {
              final param = customParams[i] as Map<String, dynamic>;
              if (param['type'] == null) {
                param['type'] = 'string';
                changed = true;
              }
            }
          }
        }
      }

      if (changed) {
        await prefs.setString('provider_entries', jsonEncode(list));
      }
    } catch (e) {
      debugPrint('Failed to migrate custom param types: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(state.entries.map((e) => e.toMap()).toList());
      await prefs.setString('provider_entries', json);
    } catch (e) {
      debugPrint('Failed to persist provider entries: $e');
    }
  }

  /// 在列表第一个位置添加新条目
  Future<void> addFirst(ProviderEntry entry) async {
    state = ProviderEntriesState(entries: [entry, ...state.entries]);
    await _persist();
  }

  /// 更新条目
  Future<void> update(String id, ProviderEntry updated) async {
    state = ProviderEntriesState(
      entries: state.entries.map((e) => e.id == id ? updated : e).toList(),
    );
    await _persist();
  }

  /// 删除条目
  Future<void> remove(String id) async {
    state = ProviderEntriesState(
      entries: state.entries.where((e) => e.id != id).toList(),
    );
    await _persist();
  }
}
