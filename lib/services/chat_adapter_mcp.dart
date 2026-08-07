part of 'chat_adapter.dart';

/// Internal pairing of an McpServerConfig with its vendor description.
///
/// Used by [ChatAdapter.initializeMcpServers] to carry the description
/// from the provider config's typeConfig alongside the server config,
/// so that placeholder tool definitions can be created for vendors
/// whose servers are unreachable.
class _McpConfigEntry {
  final McpServerConfig config;
  final String description;

  const _McpConfigEntry({
    required this.config,
    required this.description,
  });
}

/// MCP 服务器初始化逻辑（SSE / stdio 连接与工具发现）。
extension ChatAdapterMcpExt on ChatAdapter {
  /// 初始化 MCP 客户端（SSE / stdio）并发现工具。
  ///
  /// 仅处理非 HTTP 工具的 MCP 服务器配置。HTTP 工具由 [ChatAdapter.initializeBuiltinTools] 独立处理。
  /// MCP 服务器连接失败不会影响已注册的内置工具。
  ///
  /// 对所有 MCP 服务器（内置供应商或用户添加、SSE 或 stdio、有无描述），
  /// 都会在发起任何网络连接之前同步发布占位工具定义，确保每个 MCP
  /// 供应商的工具都立刻出现在工具列表中，不区分"纯 Dart HTTP 工具"、
  /// "SSE MCP 工具"或"本地 stdio 工具"。连接成功的服务器会用真实工具
  /// 替换自己的占位符。
  Future<void> initializeMcpServers(ProviderEntriesState entriesState) async {
    // Skip if config hasn't changed since last init (prevents redundant
    // network discovery on every page mount after IndexedStack removal).
    // 只在缓存非空、没有发现运行在进行、且上一轮发现到了真实工具时
    // 才跳过：缓存为空（首次运行、disposeMcp 清空）必须重发现；发现
    // 进行中时（页面 _initialize 与 provider-change listener 并发）必须
    // 加入进行中的运行，等待其完成后由调用方（页面）基于最终工具列表
    // 重解析启用集——直接跳过会让新挂载的页面停留在占位符工具名上；
    // 上一轮只有占位符（服务器临时不可达）时也要重试，让恢复后的
    // 服务器能加载真实工具。
    final hash = Object.hashAll(entriesState.entries.map((e) => e.hashCode));
    if (_lastMcpEntriesHash == hash &&
        _mcpInitFuture == null &&
        _mcpToolDefinitions.isNotEmpty &&
        _lastMcpDiscoveryFoundTools) {
      return;
    }

    // Serialize concurrent discovery: a second call (e.g. page _initialize +
    // provider-change listener, or a config edit landing during a slow
    // discovery) must wait for the in-flight run instead of racing it.
    // Otherwise the second call's addClient would dispose the first call's
    // in-flight client, silently losing that server's tools. After the
    // in-flight run finishes, re-check the guard — if it already covered
    // this config and populated the cache, nothing more to do.
    final inFlight = _mcpInitFuture;
    if (inFlight != null) {
      await inFlight;
      if (_lastMcpEntriesHash == hash && _mcpToolDefinitions.isNotEmpty) {
        return;
      }
    }

    _lastMcpEntriesHash = hash;
    final future = _discoverMcpTools(entriesState);
    _mcpInitFuture = future;
    try {
      await future;
    } finally {
      if (identical(_mcpInitFuture, future)) _mcpInitFuture = null;
    }
  }

  Future<void> _discoverMcpTools(ProviderEntriesState entriesState) async {
    // 本轮运行代号：disposeMcp 或新一轮发现会递增代号，使本运行在
    // 完成时不得再写入工具列表。
    final run = ++_mcpDiscoveryGeneration;

    final mcpEntry =
        entriesState.entries.where((e) => e.type == 'mcp').firstOrNull;
    if (mcpEntry == null || mcpEntry.configs.isEmpty) {
      // 没有配置任何 MCP 服务器：发布空列表并释放旧客户端，避免上一份
      // 配置的工具/连接残留在工具列表与客户端管理器中。
      _mcpToolDefinitions = [];
      _lastMcpDiscoveryFoundTools = false;
      _mcpClientManager.disposeAll();
      return;
    }

    // Build MCP server configs (skip HTTP tools — handled by initializeBuiltinTools)
    // and capture descriptions for placeholder tool creation.
    final mcpConfigs = <_McpConfigEntry>[];

    for (final config in mcpEntry.configs) {
      final typeConfig =
          config.models.isNotEmpty ? config.models[0].typeConfig : null;

      // Skip HTTP tools (pure Dart, not MCP)
      final isHttpTool = typeConfig?['isHttpTool'] as bool? ?? false;
      if (isHttpTool) continue;

      final serverConfig = McpServerConfig.fromProviderConfig(
        providerName: config.providerName,
        typeConfig: typeConfig,
      );
      if (serverConfig != null) {
        final description = typeConfig?['description'] as String? ?? '';
        mcpConfigs.add(_McpConfigEntry(
          config: serverConfig,
          description: description,
        ));
      }
    }

    if (mcpConfigs.isEmpty) {
      // 只剩 HTTP 工具等非 MCP 配置：清空并释放旧客户端。
      _mcpToolDefinitions = [];
      _lastMcpDiscoveryFoundTools = false;
      _mcpClientManager.disposeAll();
      return;
    }

    // 同步发布占位工具定义（不做任何网络等待）：每个配置的 MCP 服务器
    // 都先以一个占位工具出现在工具列表中。连接成功的服务器随后用真实
    // 工具替换占位符，连接失败/不可达的服务器保留占位符保持可见。
    // 写入同样只属于本轮运行：同步执行时 run 必为最新代号（防御性，
    // 防止未来重构把发布移到 await 之后引入竞争）。
    final placeholders = <ToolDefinition>[
      for (final entry in mcpConfigs)
        ToolDefinition(
          name: _mcpPlaceholderName(entry.config.name),
          description: entry.description.isNotEmpty
              ? entry.description
              : 'MCP 服务器工具：${entry.config.name}',
          parameters: const {
            'type': 'object',
            'properties': {},
            'required': <String>[],
          },
        ),
    ];
    if (run == _mcpDiscoveryGeneration) {
      _mcpToolDefinitions = List.from(placeholders);
    }

    // 并行连接所有服务器并发现真实工具：单个服务器的失败（不可达、
    // 鉴权失败、超时）不影响其它服务器。客户端键带序号，避免同名
    // 配置（用户复制出的重复项）在并发行中互相 dispose 对方的客户端。
    final results = await Future.wait(
      mcpConfigs.asMap().entries.map((entry) async {
        final i = entry.key;
        final mcpEntryCfg = entry.value;
        try {
          final client = McpClient(config: mcpEntryCfg.config);
          _mcpClientManager.addClient('${mcpEntryCfg.config.name}#$i', client);

          // Try to connect and list tools
          final tools = await client.listTools();
          debugPrint(
            'MCP[${mcpEntryCfg.config.name}]: '
            'discovered ${tools.length} tools',
          );
          return tools.map((t) => t.toToolDefinition()).toList();
        } catch (e) {
          debugPrint('MCP[${mcpEntryCfg.config.name}]: init error: $e');
          return <ToolDefinition>[];
        }
      }),
    );

    // 每个服务器按配置顺序输出：发现到真实工具用真实工具替换占位符，
    // 否则保留占位符让该供应商始终可见。同名工具（重复配置、或两个
    // 服务器都提供同名工具）只保留第一份，与 _executeTool 按名称路由
    // 的语义一致，也避免重复工具名被 API 拒绝。
    final allTools = <ToolDefinition>[];
    final seenNames = <String>{};
    for (var i = 0; i < mcpConfigs.length; i++) {
      final toolDefs = results[i];
      if (toolDefs.isNotEmpty) {
        for (final def in toolDefs) {
          if (seenNames.add(def.name)) allTools.add(def);
        }
      } else {
        final placeholder = placeholders[i];
        if (seenNames.add(placeholder.name)) allTools.add(placeholder);
      }
    }
    // 已被 disposeMcp 或新一轮发现取代的运行不得写入（避免在 dispose
    // 之后复活旧工具，或旧占位符覆盖新发现的真实工具）。
    if (run != _mcpDiscoveryGeneration) return;
    _mcpToolDefinitions = allTools;
    _lastMcpDiscoveryFoundTools = results.any((r) => r.isNotEmpty);

    // 清理本运行未覆盖的旧客户端：配置增删/重排后，旧序号键
    // （如 'Exa#0'）的客户端会残留在管理器中——既占用连接，又可能在
    // 工具路由时被优先命中（_executeTool 按插入顺序遍历，会先查到旧
    // 端点）。运行之间严格串行（_mcpInitFuture），此处安全。
    final currentKeys = <String>{
      for (var i = 0; i < mcpConfigs.length; i++)
        '${mcpConfigs[i].config.name}#$i',
    };
    for (final key in _mcpClientManager.clients.keys.toList()) {
      if (!currentKeys.contains(key)) {
        _mcpClientManager.removeClient(key);
      }
    }
  }

  /// 生成 MCP 服务器的占位工具名（如 "Jina AI" → "jina_ai_mcp"）。
  static String _mcpPlaceholderName(String serverName) =>
      '${serverName.toLowerCase().replaceAll(' ', '_')}_mcp';

  /// 释放 MCP 资源
  void disposeMcp() {
    _mcpClientManager.disposeAll();
    _mcpToolDefinitions = [];
    _mcpInitFuture = null;
    _lastMcpDiscoveryFoundTools = false;
    // 使进行中的发现运行作废：其完成时不得再写入工具列表。
    _mcpDiscoveryGeneration++;
  }
}
