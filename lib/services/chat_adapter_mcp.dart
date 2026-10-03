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
  final Object sourceConfig;

  const _McpConfigEntry({
    required this.config,
    required this.description,
    required this.sourceConfig,
  });
}

/// MCP 服务器初始化逻辑（SSE / stdio 连接与工具发现）。
extension ChatAdapterMcpExt on ChatAdapter {
  /// 初始化 MCP 客户端（SSE / stdio）。
  ///
  /// 仅处理非 HTTP 工具的 MCP 服务器配置。HTTP 工具由 [ChatAdapter.initializeBuiltinTools] 独立处理。
  ///
  /// 进入对话页面时**不会**发起任何网络连接：只同步发布每个 MCP 服务器
  /// （内置供应商或用户添加、SSE 或 stdio、有无描述）的占位工具定义，
  /// 并预先创建未连接的 [McpClient] 实例。连接与工具发现延迟到工具被
  /// 实际调用时按需进行（见 chat_service_tools.dart 的 _executeTool），
  /// 避免页面进入时对每个服务器发起连接尝试（真实端点可能数十秒超时）。
  ///
  /// MCP 条目的 [ProviderEntry.enabled]（MCP总开关）或某个配置所属的组别
  /// 关闭时，不发布对应占位工具并释放旧客户端。
  Future<void> initializeMcpServers(ProviderEntriesState entriesState) async {
    final mcpEntry =
        entriesState.entries.where((e) => e.type == 'mcp').firstOrNull;
    // MCP 配置未变（同一实例）：占位符与客户端都无需重建。页面重复进入、
    // 或其它供应商（TTS/OCR 等）配置变更时，MCP 条目实例不变，跳过。
    if (identical(_lastMcpEntry, mcpEntry) &&
        identical(_lastMcpGroups, entriesState.mcpGroups)) {
      return;
    }
    final keepExistingClients = identical(_lastMcpEntry, mcpEntry);
    _lastMcpEntry = mcpEntry;
    _lastMcpGroups = entriesState.mcpGroups;

    if (mcpEntry == null || mcpEntry.configs.isEmpty || !mcpEntry.enabled) {
      // 没有配置任何 MCP 服务器，或 MCP总开关已关闭：发布空列表并释放
      // 旧客户端，避免上一份配置的工具/连接残留在工具列表与客户端管理器中。
      _mcpToolDefinitions = [];
      _mcpClientManager.disposeAll();
      _lastMcpConfigSourcesByName = {};
      return;
    }

    // Build MCP server configs (skip HTTP tools — handled by initializeBuiltinTools)
    // and capture descriptions for placeholder tool creation.
    final mcpConfigs = <_McpConfigEntry>[];

    for (final config in mcpEntry.configs) {
      if (!isMcpProviderConfigEnabled(config, entriesState.mcpGroups)) continue;
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
          sourceConfig: config,
        ));
      }
    }

    if (mcpConfigs.isEmpty) {
      // 只剩 HTTP 工具等非 MCP 配置，或所有 MCP 配置都属于关闭组别。
      // 清空占位工具并释放旧客户端。
      _mcpToolDefinitions = [];
      _mcpClientManager.disposeAll();
      _lastMcpConfigSourcesByName = {};
      return;
    }

    // MCP 条目没变时只有组别列表发生了变化：仅释放已关闭组别的客户端，
    // 或改由同名的另一份配置提供服务时替换对应客户端；仍有效的客户端继续复用。
    final activeConfigSourcesByName = <String, Object>{};
    for (final entry in mcpConfigs) {
      activeConfigSourcesByName.putIfAbsent(
        entry.config.name,
        () => entry.sourceConfig,
      );
    }
    if (keepExistingClients) {
      for (final name in _mcpClientManager.clients.keys.toList()) {
        if (!identical(
          _lastMcpConfigSourcesByName[name],
          activeConfigSourcesByName[name],
        )) {
          _mcpClientManager.removeClient(name);
        }
      }
    } else {
      // MCP 条目变化时配置可能包含新 URL/命令，旧客户端作废。
      _mcpClientManager.disposeAll();
    }

    // 为每个 MCP 服务器创建客户端但**不连接**：连接延迟到工具被调用时。
    // 无效配置（缺 URL/命令，McpClient 构造会抛 ArgumentError）跳过其
    // 客户端但仍保留占位符，避免单条损坏配置让整个工具列表消失。
    for (final entry in mcpConfigs) {
      if (_mcpClientManager.getClient(entry.config.name) != null) continue;
      try {
        _mcpClientManager.addClient(
          entry.config.name,
          McpClient(config: entry.config),
        );
      } catch (e) {
        debugPrint('MCP[${entry.config.name}]: 无效配置，跳过客户端: $e');
      }
    }
    _lastMcpConfigSourcesByName = activeConfigSourcesByName;

    // 同步发布占位工具定义（不做任何网络等待）：每个配置的 MCP 服务器
    // 都先以一个占位工具出现在工具列表中。占位工具不是真实工具——模型
    // 调用占位符时 _executeTool 会按需连接该服务器、列出真实工具并把
    // 可用工具名告知模型。同名服务器只保留第一份占位符，避免重复工具名
    // 被 API 拒绝。
    final seenNames = <String>{};
    _mcpToolDefinitions = [
      for (final entry in mcpConfigs)
        if (seenNames.add(
          McpServerConfig.placeholderToolName(entry.config.name),
        ))
          ToolDefinition(
            name: McpServerConfig.placeholderToolName(entry.config.name),
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
  }

  /// 释放 MCP 资源
  void disposeMcp() {
    _mcpClientManager.disposeAll();
    _mcpToolDefinitions = [];
    _lastMcpEntry = null;
    _lastMcpGroups = null;
    _lastMcpConfigSourcesByName = {};
  }
}
