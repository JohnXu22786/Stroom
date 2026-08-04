part of 'provider_config.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

/// 损坏备份上限（对齐 conversations 的 _maxCorruptBackups）。
const int _maxCorruptProviderBackups = 3;

extension _ProviderEntriesNotifierPersistenceExt on ProviderEntriesNotifier {
  /// 迁移旧版 chat_configs（被重构删除的 ChatProviderConfigItem 格式）到 provider_entries
  Future<void> _migrateOldChatConfigs(SharedPreferences prefs) async {
    final oldJson = prefs.getString('chat_configs');
    if (oldJson == null || oldJson.isEmpty) return;

    try {
      // 顶层也需防御：chat_configs 整体不是数组时，`as List?` 强转
      // 抛 TypeError 会静默中断迁移。
      final decoded = jsonDecode(oldJson);
      if (decoded is! List) {
        debugPrint('chat_configs 不是合法数组，跳过旧配置迁移');
        await prefs.remove('chat_configs');
        await prefs.remove('chat_selected_config_id');
        return;
      }
      // 兜底：使用 whereType 安全过滤，避免非 Map 条目导致的闪退
      final oldList = decoded.whereType<Map<String, dynamic>>().toList();
      if (oldList.isEmpty) {
        await prefs.remove('chat_configs');
        await prefs.remove('chat_selected_config_id');
        return;
      }

      final migratedConfigs = <ProviderConfigItem>[];
      for (final oldItem in oldList) {
        // 兜底：安全过滤 oldItem['models']。
        // 注意：oldItem['models'] 本身可能是非 List（损坏数据），
        // 用 `is! List` 判断而不是 `as List?` 强转（强转抛 TypeError
        // 会静默中断迁移，chat_configs 永不清理、每次启动重复迁移）。
        final rawModels = oldItem['models'];
        final oldModels = rawModels is List
            ? rawModels.whereType<Map<String, dynamic>>().toList()
            : <Map<String, dynamic>>[];

        final models = oldModels.map((m) {
          final typeConfig = <String, dynamic>{};
          // 与 startup 迁移副本保持一致：迁移 per-model 的
          // context/maxTokens（旧数据把压缩阈值挂在 model 上，
          // 不迁移则老用户的自动压缩静默失效）。
          final context = m['maxTokens'] ?? m['context'];
          if (context != null) typeConfig['context'] = context;
          final temperature = m['temperature'];
          if (temperature != null) typeConfig['temperature'] = temperature;

          // `is! String`/`is! bool` 而非强转：损坏数据中字段值可能
          // 是任意类型。
          final modelId = m['modelId'];
          return ModelConfig(
            name: modelId is String ? modelId : '',
            modelId: modelId is String ? modelId : '',
            supportStream:
                m['supportStream'] is bool ? m['supportStream'] as bool : true,
            typeConfig: typeConfig,
          );
        }).toList();

        migratedConfigs.add(
          ProviderConfigItem(
            providerName: oldItem['providerName'] is String
                ? oldItem['providerName']
                : '',
            host: oldItem['host'] is String ? oldItem['host'] : '',
            key: oldItem['key'] is String ? oldItem['key'] : '',
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
          final decoded = jsonDecode(existingJson);
          if (decoded is! List) {
            // 现有 provider_entries 整体损坏（非数组）：先备份原始
            // 数据再覆盖 —— 否则这里的写入会永久销毁损坏现场。
            await _backupCorruptProviderEntries(prefs, existingJson);
            existingEntries = [];
          } else {
            // 兜底：使用 whereType 安全过滤非 Map 条目
            existingEntries =
                decoded.whereType<Map<String, dynamic>>().toList();
          }
        } catch (_) {
          // 现有数据损坏，忽略并用空列表重新开始
          try {
            await _backupCorruptProviderEntries(prefs, existingJson);
          } catch (_) {}
          existingEntries = [];
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
        description: '通过 Exa MCP 接口进行网络搜索、内容提取和深度研究，支持语义搜索与关键词搜索',
      ),
      _buildMcpConfig(
        name: 'Tavily',
        transport: 'sse',
        url: 'https://mcp.tavily.com/mcp/',
        headers: {},
        env: {},
        apiKeyHint:
            '请在 Tavily 官网获取 API Key，支持 ?tavilyApiKey= 或 Authorization: Bearer',
        description: 'AI 原生搜索引擎，专为大语言模型优化的实时网络搜索服务',
      ),
      _buildMcpConfig(
        name: 'Jina AI',
        transport: 'sse',
        url: 'https://mcp.jina.ai/sse',
        headers: {'Authorization': 'Bearer '},
        env: {},
        apiKeyHint: '请在 Jina AI 官网获取 API Key (Bearer Token)',
        description: '多模态 AI 服务，支持网页内容提取、Embedding 和搜索结果抓取',
      ),
      _buildMcpConfig(
        name: 'Firecrawl',
        transport: 'sse',
        url: 'https://mcp.firecrawl.dev/v2/mcp',
        headers: {},
        env: {},
        apiKeyHint: '请在 Firecrawl 官网获取 API Key，也可免 Key 试用（免费版有限额）',
        description: '网页抓取与内容提取服务，可将任意网页转为干净的 Markdown 或结构化数据',
      ),
      _buildMcpConfig(
        name: 'Zhipu',
        transport: 'sse',
        url: 'https://open.bigmodel.cn/api/mcp/web_reader/mcp',
        headers: {'Authorization': 'Bearer '},
        env: {},
        apiKeyHint: '请在智谱 AI 开放平台获取 API Key (Bearer Token)',
        description: '智谱 AI 开放平台的网页阅读器 MCP 服务，支持网页内容抓取与理解',
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
        description: '隐私优先的独立搜索引擎，提供高质量网络搜索结果（需配置 API Key）',
      ),
      _buildMcpConfig(
        name: 'Bocha',
        transport: 'http',
        url: 'https://api.bochaai.com/v1/web-search',
        headers: {'Authorization': 'Bearer '},
        env: {},
        isHttpTool: true,
        apiKeyHint: '请在博查 AI 开放平台获取 API Key (Bearer Token)',
        description: '博查 AI 网络搜索服务，提供智能化的中文网页搜索结果',
      ),
      _buildMcpConfig(
        name: 'Querit',
        transport: 'http',
        url: 'https://api.querit.ai/v1/search',
        headers: {'Authorization': 'Bearer '},
        env: {},
        isHttpTool: true,
        apiKeyHint: '请在 Querit 官网获取 API Key (Bearer Token)',
        description: 'Querit AI 搜索服务，提供智能搜索与内容发现能力',
      ),
      _buildMcpConfig(
        name: 'Searxng',
        transport: 'http',
        url: 'http://localhost:8080',
        headers: {},
        env: {},
        isHttpTool: true,
        apiKeyHint: '设置 SearXNG 实例 URL（如 http://your-instance:8080），可选 API Key',
        description: '自托管的元搜索引擎，聚合多种搜索源，注重隐私保护（需自建实例）',
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
    String? description,
  }) {
    final typeConfig = <String, dynamic>{
      'transport': transport,
      'isVendor': true,
      'apiKeyHint': apiKeyHint,
    };
    if (description != null && description.isNotEmpty) {
      typeConfig['description'] = description;
    }
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
        if (oldTransport != newTransport ||
            oldIsRestApi ||
            oldIsHttpTool != newIsHttpTool) {
          final idx = mcpEntry.configs.indexOf(existing);
          if (idx >= 0) {
            // Preserve user's API key if they had one
            final updatedConfig = builtinConfig.copy();
            final oldApiKey = _extractApiKeyFromConfig(existing);
            if (oldApiKey.isNotEmpty) {
              updatedConfig.models[0].typeConfig['apiKey'] = oldApiKey;
              // Also update headers/env with the old key
              _applyApiKeyToTypeConfig(
                  updatedConfig.models[0].typeConfig, oldApiKey);
            }
            mcpEntry.configs[idx] = updatedConfig;
            changed = true;
          }
        } else {
          // 补充缺失的描述信息（新添加字段）
          final oldDesc = oldTypeConfig['description'] as String?;
          final newDesc = newTypeConfig['description'] as String?;
          if ((oldDesc == null || oldDesc.isEmpty) &&
              newDesc != null &&
              newDesc.isNotEmpty) {
            final idx = mcpEntry.configs.indexOf(existing);
            if (idx >= 0) {
              final updatedConfig = existing.copy();
              final models = updatedConfig.models;
              if (models.isNotEmpty) {
                models[0].typeConfig['description'] = newDesc;
              }
              mcpEntry.configs[idx] = updatedConfig;
              changed = true;
            }
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
  void _applyApiKeyToTypeConfig(
      Map<String, dynamic> typeConfig, String apiKey) {
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

  /// 损坏的 provider_entries 原始数据备份（对齐 conversations 的
  /// _backupCorruptConversationsFile 模式）：结构性损坏或全部条目损坏
  /// 时把原始 JSON 存到独立 key，最多保留 [_maxCorruptProviderBackups] 份，
  /// 避免回退默认后后续 _persist 把含 API key 的原始配置永久覆盖。
  Future<void> _backupCorruptProviderEntries(
      SharedPreferences prefs, String corruptJson) async {
    try {
      final backupKey =
          'provider_entries_corrupt_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(backupKey, corruptJson);
      // 只保留最近的 N 份
      final keys = prefs.getKeys().toList()
        ..sort()
        ..retainWhere((k) => k.startsWith('provider_entries_corrupt_'));
      while (keys.length > _maxCorruptProviderBackups) {
        await prefs.remove(keys.removeAt(0));
      }
      debugPrint(
          '[ProviderEntriesNotifier] 已备份损坏的 provider_entries 到 $backupKey');
    } catch (e) {
      debugPrint('Failed to back up corrupt provider entries: $e');
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
}
