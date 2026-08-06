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
  /// 对内置供应商（isVendor=true）的 MCP 服务器，即使连接失败也会创建占位工具定义，
  /// 确保所有 MCP 供应商的工具都在工具列表中可见，不会区分"纯 Dart HTTP 工具"和
  /// "SSE MCP 工具"。
  Future<void> initializeMcpServers(ProviderEntriesState entriesState) async {
    // Skip if config hasn't changed since last init (prevents redundant
    // network discovery on every page mount after IndexedStack removal).
    // Only skip when tools were actually discovered: if the cache is empty
    // (first run, a previously failed run, or disposeMcp cleared it), always
    // re-discover so the tool list never gets stuck at built-in-only.
    final hash = Object.hashAll(entriesState.entries.map((e) => e.hashCode));
    if (_lastMcpEntriesHash == hash && _mcpToolDefinitions.isNotEmpty) return;

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

    final mcpEntry =
        entriesState.entries.where((e) => e.type == 'mcp').firstOrNull;
    if (mcpEntry == null || mcpEntry.configs.isEmpty) return;

    // Build MCP server configs (skip HTTP tools — handled by initializeBuiltinTools)
    // and capture vendor descriptions for placeholder tool creation.
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

    // Create clients and discover tools from MCP servers
    final allTools = <ToolDefinition>[];

    // First pass: add placeholder tool definitions for vendor MCP providers
    // so they always appear in the tool list even if servers are unreachable.
    // This ensures no distinction between "pure Dart" HTTP tools and SSE MCP tools.
    for (final entry in mcpConfigs) {
      if (entry.config.isVendor && entry.description.isNotEmpty) {
        allTools.add(ToolDefinition(
          name: '${entry.config.name.toLowerCase().replaceAll(' ', '_')}_mcp',
          description: entry.description,
          parameters: const {
            'type': 'object',
            'properties': {},
            'required': <String>[],
          },
        ));
      }
    }

    // Second pass: connect to MCP servers and discover actual tools.
    // When a server connects successfully, replace its placeholder with
    // the actual tool definitions returned by the server.
    // Only remove the placeholder when actual tools are discovered;
    // otherwise keep the placeholder so the provider remains visible.
    for (final entry in mcpConfigs) {
      try {
        final client = McpClient(config: entry.config);
        _mcpClientManager.addClient(entry.config.name, client);

        // Try to connect and list tools
        final tools = await client.listTools();
        final toolDefs = tools.map((t) => t.toToolDefinition()).toList();

        if (toolDefs.isNotEmpty) {
          // Actual tools were discovered — remove the placeholder
          // and use the server-provided definitions instead.
          if (entry.config.isVendor && entry.description.isNotEmpty) {
            allTools.removeWhere(
              (t) =>
                  t.name ==
                  '${entry.config.name.toLowerCase().replaceAll(' ', '_')}_mcp',
            );
          }
          allTools.addAll(toolDefs);
        }

        debugPrint(
          'MCP[${entry.config.name}]: discovered ${toolDefs.length} tools',
        );
      } catch (e) {
        debugPrint('MCP[${entry.config.name}]: init error: $e');
      }
    }
    _mcpToolDefinitions = allTools;
  }

  /// 释放 MCP 资源
  void disposeMcp() {
    _mcpClientManager.disposeAll();
    _mcpToolDefinitions = [];
    _mcpInitFuture = null;
  }
}
