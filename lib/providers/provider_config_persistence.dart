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
    await DataMigrationOldConfigs.migrateOldChatConfigs(prefs);
  }

  Future<void> _migrateOldCustomParams(SharedPreferences prefs) async {
    try {
      final json = prefs.getString('provider_entries');
      if (json == null || json.isEmpty) return;

      // 兜底：使用 whereType 安全过滤非 Map 条目，避免 `.cast<>()` 或 `as Map` 闪退
      final list = (jsonDecode(json) as List)
          .whereType<Map<String, dynamic>>()
          .toList();
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
    } catch (_) {
      debugPrint('Failed to migrate custom parameter types.');
    }
  }

  /// 迁移旧版推理力度参数：为 isEffortParam 标志出现之前保存的数据
  /// 补上标志（旧语义：第一个非开关推理参数即推理力度）。
  ///
  /// 幂等：仅当全部推理参数都不含 `isEffortParam` 键（即数据诞生于
  /// 该标志之前）时才处理，把第一个「非开关、参数名非空且有选项」的参数
  /// 标记为推理力度（与 [findEffortParam] 的旧数据回退规则一致）。
  /// 现代数据（键已存在，false 表示刻意不设力度）不受影响。
  /// 模型级与供应商级推理参数均处理。
  Future<void> _migrateLegacyEffortParams(SharedPreferences prefs) async {
    try {
      final json = prefs.getString('provider_entries');
      if (json == null || json.isEmpty) return;

      final list = (jsonDecode(json) as List)
          .whereType<Map<String, dynamic>>()
          .toList();
      bool changed = false;

      for (final entry in list) {
        // 推理力度概念只存在于 LLM 模型（聊天侧），其余类型不迁移
        if (entry['type'] != 'llm') continue;
        final configs = entry['configs'] as List?;
        if (configs == null) continue;
        for (final config in configs) {
          if (config is! Map<String, dynamic>) continue;

          // 供应商级推理参数
          final providerParams = config['reasoningParams'] as List?;
          if (providerParams != null &&
              providerParams.isNotEmpty &&
              !providerParams.any(
                (p) => p is Map && p.containsKey('isEffortParam'),
              )) {
            for (final rawParam in providerParams) {
              if (_promoteLegacyEffortParam(rawParam)) {
                changed = true;
                break;
              }
            }
          }

          final models = config['models'] as List?;
          if (models == null) continue;
          for (final model in models) {
            if (model is! Map<String, dynamic>) continue;
            final reasoningParams = model['reasoningParams'] as List?;
            if (reasoningParams == null || reasoningParams.isEmpty) continue;
            // 现代数据：任何参数都带 isEffortParam 键 → 不迁移
            if (reasoningParams.any(
              (p) => p is Map && p.containsKey('isEffortParam'),
            )) {
              continue;
            }
            for (final rawParam in reasoningParams) {
              if (_promoteLegacyEffortParam(rawParam)) {
                changed = true;
                break;
              }
            }
          }
        }
      }

      if (changed) {
        await prefs.setString('provider_entries', jsonEncode(list));
      }
    } catch (_) {
      debugPrint('Failed to migrate legacy effort parameters.');
    }
  }

  /// 将单个旧格式推理参数提升为推理力度（isEffortParam=true）。
  /// 规则与 [findEffortParam] 的旧数据回退一致：非开关、参数名非空、
  /// 有选项（无选项的力度参数无法选择值，promote 后也无法使用）。
  /// 返回是否发生了修改。
  bool _promoteLegacyEffortParam(dynamic rawParam) {
    if (rawParam is! Map<String, dynamic>) return false;
    // defaultValue 时代的旧格式（无 options）：fromMap 会忽略
    // isEffortParam，promote 只会造成持久化与内存解析不一致。
    if (rawParam.containsKey('defaultValue') &&
        !rawParam.containsKey('options')) {
      return false;
    }
    final isToggle = rawParam['isReasoningToggle'] as bool? ?? false;
    if (isToggle) return false;
    final name = rawParam['paramName'] as String? ?? '';
    if (name.trim().isEmpty) return false;
    final options = rawParam['options'];
    if (options is! List || options.isEmpty) return false;
    rawParam['isEffortParam'] = true;
    return true;
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
      groupId: defaultMcpGroupIdForProvider(name),
      host: url ?? '',
      key: '',
      models: [
        ModelConfig(name: name, modelId: transport, typeConfig: typeConfig),
      ],
    );
  }

  /// 迁移：为已有 MCP 条目添加或更新内置 MCP 配置
  Future<bool> _migrateBuiltinMcpConfigs(List<ProviderEntry> entries) async {
    final mcpEntryIdx = entries.indexWhere((e) => e.type == 'mcp');
    if (mcpEntryIdx < 0) return false;

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
            updatedConfig.groupId = existing.groupId ?? updatedConfig.groupId;
            final oldApiKey = _extractApiKeyFromConfig(existing);
            if (oldApiKey.isNotEmpty) {
              updatedConfig.models[0].typeConfig['apiKey'] = oldApiKey;
              // Also update headers/env with the old key
              _applyApiKeyToTypeConfig(
                updatedConfig.models[0].typeConfig,
                oldApiKey,
              );
            }
            final connectivityTest = oldTypeConfig['connectivityTest'];
            if (connectivityTest is Map) {
              updatedConfig.models[0].typeConfig['connectivityTest'] =
                  Map<String, dynamic>.from(connectivityTest);
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
    }
    return changed;
  }

  /// Extract API key from an existing config
  String _extractApiKeyFromConfig(ProviderConfigItem config) {
    final typeConfig = config.models.isNotEmpty
        ? config.models[0].typeConfig
        : <String, dynamic>{};
    // Placeholders ('Bearer ' 前缀等) are treated as unset so the migration
    // never captures a fake key (or the corrupted 'Bearer Bearer' legacy form).
    return McpServerConfig.extractApiKeyFromTypeConfig(typeConfig);
  }

  /// Apply an API key to a typeConfig (update headers/env placeholders)
  void _applyApiKeyToTypeConfig(
    Map<String, dynamic> typeConfig,
    String apiKey,
  ) {
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
    SharedPreferences prefs,
    String corruptJson,
  ) async {
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
        '[ProviderEntriesNotifier] 已备份损坏的 provider_entries 到 $backupKey',
      );
    } catch (_) {
      debugPrint('Failed to back up corrupt provider entries.');
    }
  }

  Future<void> _persist({bool rethrowOnFailure = false}) async {
    SharedPreferences? prefsForRollback;
    String? providerEntriesBeforeMigration;
    String? mcpGroupsBeforeMigration;
    String? attemptedProviderEntries;
    String? attemptedMcpGroups;
    var pairedWriteStarted = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      prefsForRollback = prefs;
      providerEntriesBeforeMigration = prefs.getString('provider_entries');
      mcpGroupsBeforeMigration = prefs.getString('mcp_provider_groups');
      if (_providerEntriesSourceUnreadable) {
        _reloadBeforeNextMutation = true;
        debugPrint(
          'Provider settings were not persisted because stored entries could not be read safely.',
        );
        if (rethrowOnFailure) {
          throw StateError('Stored provider entries require recovery.');
        }
        return;
      }
      final groupsJson = jsonEncode(
        state.mcpGroups.map((group) => group.toMap()).toList(),
      );
      if (!_jsonPreferenceEquals(
        prefs.getString('mcp_provider_groups'),
        mcpGroupsBeforeMigration,
      )) {
        throw StateError('Provider settings changed during persistence.');
      }
      attemptedMcpGroups = groupsJson;
      pairedWriteStarted = true;
      final groupsSaved = await prefs.setString(
        'mcp_provider_groups',
        groupsJson,
      );
      if (!groupsSaved ||
          prefs.getString('mcp_provider_groups') != groupsJson) {
        throw StateError('Failed to persist provider configuration.');
      }

      final persistedSourceEntries = state.entries
          .map((entry) {
            if (entry.type != 'llm') return entry;
            return ProviderEntry(
              id: entry.id,
              type: entry.type,
              name: entry.name,
              enabled: entry.enabled,
              legacyFields: entry.legacyFields,
              configs: entry.configs
                  .where((config) => !isLlmModelGroupProviderConfig(config))
                  .toList(),
            );
          })
          .toList(growable: false);
      _applyCredentialReferencesFromSavedEntries(
        persistedSourceEntries,
        prefs.getString('provider_entries'),
      );
      final migrationInput = jsonEncode(
        persistedSourceEntries
            .map((entry) => entry.toCredentialMigrationMap())
            .toList(),
      );
      try {
        await LlmAccountMigrationService(
          preferences: _SharedPreferencesLlmAccountPreferences(prefs),
          credentialStore: _credentialStore,
        ).migrate(sourceProviderEntriesJson: migrationInput);
      } on LlmAccountMigrationException {
        _reloadBeforeNextMutation = true;
        debugPrint(
          'Secure credential storage is unavailable; provider settings were not persisted.',
        );
        throw StateError('Secure credential migration is unavailable.');
      }

      _applyCredentialReferencesFromSavedEntries(
        state.entries,
        prefs.getString('provider_entries'),
      );
      final persistedEntries = persistedSourceEntries.map((entry) {
        final serialized = entry.toMap();
        if (entry.type == 'llm') {
          serialized.remove('key');
          final configs = serialized['configs'];
          if (configs is List) {
            for (final config in configs.whereType<Map>()) {
              config.remove('key');
            }
          }
        }
        return serialized;
      }).toList();
      final json = jsonEncode(persistedEntries);
      final entriesAfterMigration = prefs.getString('provider_entries');
      final providerEntriesMatch = _jsonPreferenceEquals(
        entriesAfterMigration,
        json,
      );
      final mcpGroupsMatch = _jsonPreferenceEquals(
        prefs.getString('mcp_provider_groups'),
        groupsJson,
      );
      if (!providerEntriesMatch || !mcpGroupsMatch) {
        throw StateError('Provider settings changed during persistence.');
      }
      attemptedProviderEntries = json;
      final entriesAlreadySaved = _jsonPreferenceEquals(
        prefs.getString('provider_entries'),
        json,
      );
      final entriesSaved =
          entriesAlreadySaved ||
          await prefs.setString('provider_entries', json);
      final entriesVerified = _jsonPreferenceEquals(
        prefs.getString('provider_entries'),
        json,
      );
      final groupsVerified =
          prefs.getString('mcp_provider_groups') == groupsJson;
      if (!entriesSaved || !entriesVerified || !groupsVerified) {
        throw StateError('Failed to persist provider configuration.');
      } else {
        _reloadBeforeNextMutation = false;
      }
    } catch (_) {
      if (pairedWriteStarted && prefsForRollback != null) {
        await _rollbackPairedPreferenceWrite(
          prefsForRollback,
          'provider_entries',
          providerEntriesBeforeMigration,
          attemptedProviderEntries,
        );
        await _rollbackPairedPreferenceWrite(
          prefsForRollback,
          'mcp_provider_groups',
          mcpGroupsBeforeMigration,
          attemptedMcpGroups,
        );
      }
      _reloadBeforeNextMutation = true;
      debugPrint('Failed to persist provider entries.');
      if (rethrowOnFailure) rethrow;
    }
  }

  Future<void> _rollbackPairedPreferenceWrite(
    SharedPreferences prefs,
    String key,
    String? previous,
    String? attempted,
  ) async {
    if (attempted == null || attempted == previous) return;
    try {
      if (prefs.getString(key) != attempted) return;
      if (previous == null) {
        final removed = await prefs.remove(key);
        if (!removed || prefs.getString(key) != null) return;
      } else {
        final saved = await prefs.setString(key, previous);
        if (!saved || prefs.getString(key) != previous) return;
      }
    } catch (_) {
      // The notifier is marked for reload by _persist's caller on failure.
    }
  }

  bool _jsonPreferenceEquals(String? left, String? right) {
    if (left == right) return true;
    if (left == null || right == null) return false;
    try {
      return _jsonValueEquals(jsonDecode(left), jsonDecode(right));
    } catch (_) {
      return false;
    }
  }

  bool _jsonValueEquals(Object? left, Object? right) {
    if (left is Map && right is Map) {
      if (left.length != right.length) return false;
      for (final key in left.keys) {
        if (!right.containsKey(key) ||
            !_jsonValueEquals(left[key], right[key])) {
          return false;
        }
      }
      return true;
    }
    if (left is List && right is List) {
      if (left.length != right.length) return false;
      for (var index = 0; index < left.length; index++) {
        if (!_jsonValueEquals(left[index], right[index])) return false;
      }
      return true;
    }
    return left == right;
  }

  void _applyCredentialReferencesFromSavedEntries(
    List<ProviderEntry> entries,
    String? savedJson,
  ) {
    if (savedJson == null) return;
    try {
      final decoded = jsonDecode(savedJson);
      if (decoded is! List) return;
      final referencesByConfigId = <String, String>{};
      for (final entry in decoded.whereType<Map>()) {
        if (entry['type'] != 'llm' || entry['configs'] is! List) continue;
        for (final config in (entry['configs'] as List).whereType<Map>()) {
          final id = config['id'];
          final reference = config['credentialRef'];
          if (id is String && reference is String) {
            referencesByConfigId[id] = reference;
          }
        }
      }
      for (final entry in entries.where((entry) => entry.type == 'llm')) {
        for (final config in entry.configs) {
          if (config.legacyFields['authType'] == 'none' ||
              config.legacyFields['authType'] == 'relay') {
            continue;
          }
          final reference = referencesByConfigId[config.id];
          if (reference != null && config.credentialRef == null) {
            config.credentialRef = reference;
          }
        }
      }
    } catch (_) {
      // The migration has already validated its own persisted JSON. A parse
      // error here only means the legacy state should not be rewritten.
    }
  }
}

class _SharedPreferencesLlmAccountPreferences implements LlmAccountPreferences {
  final SharedPreferences _preferences;

  _SharedPreferencesLlmAccountPreferences(this._preferences);

  @override
  Future<String?> getString(String key) async => _preferences.getString(key);

  @override
  Future<bool> setString(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<bool> remove(String key) => _preferences.remove(key);
}
