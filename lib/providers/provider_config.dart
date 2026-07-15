import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/legacy.dart';
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
        // 兜底：安全过滤非 Map 条目，避免 `.cast<Map>()` 的类型转换闪退
        final rawList = jsonDecode(json) as List;
        final list = rawList.whereType<Map<String, dynamic>>().toList();
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
            ProviderEntry(
              id: 'builtin_mcp',
              type: 'mcp',
              name: 'MCP供应商',
              configs: _createBuiltinMcpConfigs(),
            ),
          );
          await prefs.setString(
            'provider_entries',
            jsonEncode(entries.map((e) => e.toMap()).toList()),
          );
        } else {
          // 第7步：确保已有的 MCP 条目包含内置 MCP 配置
          await _migrateBuiltinMcpConfigs(prefs, entries);
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
        ProviderEntry(
          id: 'builtin_mcp',
          type: 'mcp',
          name: 'MCP供应商',
          configs: _createBuiltinMcpConfigs(),
        ),
      ],
    );
  }

  /// 迁移旧版 chat_configs（被重构删除的 ChatProviderConfigItem 格式）到 provider_entries
  Future<void> _migrateOldChatConfigs(SharedPreferences prefs) async {
    final oldJson = prefs.getString('chat_configs');
    if (oldJson == null || oldJson.isEmpty) return;

    try {
      // 兜底：使用 whereType 安全过滤，避免非 Map 条目导致的闪退
      final oldList = (jsonDecode(oldJson) as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      if (oldList.isEmpty) return;

      final migratedConfigs = <ProviderConfigItem>[];
      for (final oldItem in oldList) {
        // 兜底：安全过滤 oldItem['models']
        final oldModels = (oldItem['models'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            [];

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
        try {
          // 兜底：使用 whereType 安全过滤非 Map 条目
          existingEntries = (jsonDecode(existingJson) as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        } catch (_) {
          // 现有数据损坏，忽略并用空列表重新开始
        }
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

      // 兜底：使用 whereType 安全过滤非 Map 条目，避免 `.cast<>()` 或 `as Map` 闪退
      final list =
          (jsonDecode(json) as List).whereType<Map<String, dynamic>>().toList();
      bool changed = false;

      for (final entry in list) {
        final configs = entry['configs'] as List?;
        if (configs == null) continue;
        for (final config in configs) {
          // 兜底：跳过非 Map 的 config 条目
          if (config is! Map<String, dynamic>) continue;
          final configMap = config;
          final models = configMap['models'] as List?;
          if (models == null) continue;
          for (final model in models) {
            // 兜底：跳过非 Map 的 model 条目
            if (model is! Map<String, dynamic>) continue;
            final modelMap = model;
            final customParams = modelMap['customParams'] as List?;
            if (customParams == null) continue;
            for (int i = 0; i < customParams.length; i++) {
              // 兜底：跳过非 Map 的 customParam 条目
              if (customParams[i] is! Map<String, dynamic>) continue;
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

  /// 创建内置 MCP 配置列表（预置的供应商 MCP 服务 + HTTP 工具配置）
  List<ProviderConfigItem> _createBuiltinMcpConfigs() {
    return [
      // ================================================================
      // Remote MCP (SSE) — 有官方托管 Remote MCP 服务，全端可用
      // ================================================================
      _buildMcpConfig(
        name: 'Exa',
        transport: 'sse',
        url: 'https://mcp.exa.ai/mcp',
        headers: {'x-api-key': ''},
        env: {},
        apiKeyHint: '请在 Exa 官网获取 API Key',
      ),
      _buildMcpConfig(
        name: 'Tavily',
        transport: 'sse',
        url: 'https://mcp.tavily.com/mcp/',
        headers: {},
        env: {},
        apiKeyHint: '请在 Tavily 官网获取 API Key，支持 ?tavilyApiKey= 或 Authorization: Bearer',
      ),
      _buildMcpConfig(
        name: 'Jina AI',
        transport: 'sse',
        url: 'https://mcp.jina.ai/sse',
        headers: {'Authorization': 'Bearer '},
        env: {},
        apiKeyHint: '请在 Jina AI 官网获取 API Key (Bearer Token)',
      ),
      _buildMcpConfig(
        name: 'Firecrawl',
        transport: 'sse',
        url: 'https://mcp.firecrawl.dev/v2/mcp',
        headers: {},
        env: {},
        apiKeyHint: '请在 Firecrawl 官网获取 API Key，也可免 Key 试用（免费版有限额）',
      ),
      _buildMcpConfig(
        name: 'Zhipu',
        transport: 'sse',
        url: 'https://open.bigmodel.cn/api/mcp/web_reader/mcp',
        headers: {'Authorization': 'Bearer '},
        env: {},
        apiKeyHint: '请在智谱 AI 开放平台获取 API Key (Bearer Token)',
      ),

      // ================================================================
      // HTTP Tools（纯 Dart 实现，无 MCP 协议，直接调 HTTP API）
      // ================================================================
      _buildMcpConfig(
        name: 'Brave Search',
        transport: 'http',
        url: 'https://api.search.brave.com/res/v1/web/search',
        headers: {'X-Subscription-Token': ''},
        env: {},
        isHttpTool: true,
        apiKeyHint: '请在 Brave Search 官网获取 API Key',
      ),
      _buildMcpConfig(
        name: 'Bocha',
        transport: 'http',
        url: 'https://api.bochaai.com/v1/web-search',
        headers: {'Authorization': 'Bearer '},
        env: {},
        isHttpTool: true,
        apiKeyHint: '请在博查 AI 开放平台获取 API Key (Bearer Token)',
      ),
      _buildMcpConfig(
        name: 'Querit',
        transport: 'http',
        url: 'https://api.querit.ai/v1/search',
        headers: {'Authorization': 'Bearer '},
        env: {},
        isHttpTool: true,
        apiKeyHint: '请在 Querit 官网获取 API Key (Bearer Token)',
      ),
      _buildMcpConfig(
        name: 'Searxng',
        transport: 'http',
        url: 'http://localhost:8080',
        headers: {},
        env: {},
        isHttpTool: true,
        apiKeyHint: '设置 SearXNG 实例 URL（如 http://your-instance:8080），可选 API Key',
      ),
    ];
  }

  /// 构建单个内置 MCP 配置项
  ProviderConfigItem _buildMcpConfig({
    required String name,
    required String transport,
    String? command,
    List<String>? args,
    String? url,
    Map<String, String>? headers,
    Map<String, String>? env,
    String? apiKeyHint,
    bool isHttpTool = false,
  }) {
    final typeConfig = <String, dynamic>{
      'transport': transport,
      'isVendor': true,
      'apiKeyHint': apiKeyHint,
    };
    if (command != null) typeConfig['command'] = command;
    if (args != null && args.isNotEmpty) typeConfig['args'] = args;
    if (url != null) typeConfig['url'] = url;
    if (headers != null && headers.isNotEmpty) typeConfig['headers'] = headers;
    if (env != null && env.isNotEmpty) typeConfig['env'] = env;
    if (isHttpTool) typeConfig['isHttpTool'] = true;

    return ProviderConfigItem(
      providerName: name,
      host: url ?? '',
      key: '',
      models: [
        ModelConfig(
          name: name,
          modelId: transport,
          typeConfig: typeConfig,
        ),
      ],
    );
  }

  /// 迁移：为已有 MCP 条目添加或更新内置 MCP 配置
  Future<void> _migrateBuiltinMcpConfigs(
    SharedPreferences prefs,
    List<ProviderEntry> entries,
  ) async {
    final mcpEntryIdx = entries.indexWhere((e) => e.type == 'mcp');
    if (mcpEntryIdx < 0) return;

    final mcpEntry = entries[mcpEntryIdx];
    final builtin = _createBuiltinMcpConfigs();
    final existingByName = {
      for (final c in mcpEntry.configs) c.providerName: c,
    };
    bool changed = false;

    for (final builtinConfig in builtin) {
      final existing = existingByName[builtinConfig.providerName];
      if (existing == null) {
        // 新增的配置
        mcpEntry.configs.add(builtinConfig);
        changed = true;
      } else {
        // 已有配置：检查是否需要更新（transport 或类型变化）
        final oldTypeConfig = existing.models.isNotEmpty
            ? existing.models[0].typeConfig
            : <String, dynamic>{};
        final newTypeConfig = builtinConfig.models.isNotEmpty
            ? builtinConfig.models[0].typeConfig
            : <String, dynamic>{};

        final oldTransport = oldTypeConfig['transport'] as String?;
        final oldIsRestApi = oldTypeConfig['isRestApi'] as bool? ?? false;
        final oldIsHttpTool = oldTypeConfig['isHttpTool'] as bool? ?? false;
        final newTransport = newTypeConfig['transport'] as String?;
        final newIsHttpTool = newTypeConfig['isHttpTool'] as bool? ?? false;

        // 如果 transport 变了（如 stdio→sse），或从 isRestApi 变成 isHttpTool，替换为新版
        if (oldTransport != newTransport || oldIsRestApi || oldIsHttpTool != newIsHttpTool) {
          final idx = mcpEntry.configs.indexOf(existing);
          if (idx >= 0) {
            // Preserve user's API key if they had one
            final updatedConfig = builtinConfig.copy();
            final oldApiKey = _extractApiKeyFromConfig(existing);
            if (oldApiKey.isNotEmpty) {
              updatedConfig.models[0].typeConfig['apiKey'] = oldApiKey;
              // Also update headers/env with the old key
              _applyApiKeyToTypeConfig(updatedConfig.models[0].typeConfig, oldApiKey);
            }
            mcpEntry.configs[idx] = updatedConfig;
            changed = true;
          }
        }
      }
    }

    if (changed) {
      entries[mcpEntryIdx] = mcpEntry;
      await prefs.setString(
        'provider_entries',
        jsonEncode(entries.map((e) => e.toMap()).toList()),
      );
    }
  }

  /// Extract API key from an existing config
  String _extractApiKeyFromConfig(ProviderConfigItem config) {
    final typeConfig = config.models.isNotEmpty
        ? config.models[0].typeConfig
        : <String, dynamic>{};
    // Check apiKey field first
    final apiKey = typeConfig['apiKey'] as String?;
    if (apiKey != null && apiKey.isNotEmpty) return apiKey;
    // Check env values
    final envRaw = typeConfig['env'];
    if (envRaw is Map) {
      for (final val in envRaw.values) {
        final s = val.toString();
        if (s.isNotEmpty && !s.contains('/usr/') && !s.contains('/bin')) {
          return s;
        }
      }
    }
    // Check header values
    final headersRaw = typeConfig['headers'];
    if (headersRaw is Map) {
      for (final val in headersRaw.values) {
        final s = val.toString().trim();
        if (s.isNotEmpty && s.length > 3) {
          if (s.startsWith('Bearer ')) return s.substring(7).trim();
          return s;
        }
      }
    }
    return '';
  }

  /// Apply an API key to a typeConfig (update headers/env placeholders)
  void _applyApiKeyToTypeConfig(Map<String, dynamic> typeConfig, String apiKey) {
    if (apiKey.isEmpty) return;
    typeConfig['apiKey'] = apiKey;
    // Update headers
    final headersRaw = typeConfig['headers'];
    if (headersRaw is Map) {
      for (final key in headersRaw.keys.toList()) {
        final val = headersRaw[key].toString();
        if (val.isEmpty || val.endsWith(' ')) {
          if (key.toLowerCase() == 'authorization') {
            headersRaw[key] = 'Bearer $apiKey';
          } else {
            headersRaw[key] = apiKey;
          }
        }
      }
    }
    // Update env
    final envRaw = typeConfig['env'];
    if (envRaw is Map) {
      for (final key in envRaw.keys.toList()) {
        final val = envRaw[key].toString();
        if (val.isEmpty) envRaw[key] = apiKey;
      }
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
