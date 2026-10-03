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

    if (!keepExistingClients) {
      // MCP 条目变化时配置可能包含新 URL/命令，旧客户端作废。
      _mcpClientManager.disposeAll();
      _lastMcpConfigSourcesByName = {};
    }

    // 为每个 MCP 服务器创建客户端但**不连接**：连接延迟到工具被调用时。
    // 按配置顺序选择每个名称下第一个能创建客户端的启用配置，保证
    // source map 和实际客户端总是同一份配置。同名配置中首个无效时，
    // 继续尝试后续配置；失败的配置仍保留占位符。
    final selectedConfigSourcesByName = <String, Object>{};
    for (final entry in mcpConfigs) {
      final name = entry.config.name;
      if (selectedConfigSourcesByName.containsKey(name)) continue;
      final existingClient = _mcpClientManager.getClient(name);
      if (existingClient != null &&
          identical(_lastMcpConfigSourcesByName[name], entry.sourceConfig)) {
        selectedConfigSourcesByName[name] = entry.sourceConfig;
        continue;
      }
      try {
        _mcpClientManager.addClient(
          name,
          McpClient(config: entry.config),
        );
      } catch (e) {
        debugPrint('MCP[$name]: 无效配置，跳过客户端: $e');
        continue;
      }
      selectedConfigSourcesByName[name] = entry.sourceConfig;
    }
    for (final name in _mcpClientManager.clients.keys.toList()) {
      if (!selectedConfigSourcesByName.containsKey(name)) {
        _mcpClientManager.removeClient(name);
      }
    }
    // Group toggles can append a newly enabled earlier config after retained
    // clients. Preserve instances while restoring configured dispatch order.
    _mcpClientManager.reorderClients(selectedConfigSourcesByName.keys);
    _lastMcpConfigSourcesByName = selectedConfigSourcesByName;

    // 同步发布占位工具定义（不做任何网络等待）：每个配置的 MCP 服务器
    // 都先以一个占位工具出现在工具列表中。占位工具不是真实工具——模型
    // 调用占位符时 _executeTool 会按需连接该服务器、列出真实工具并把
    // 可用工具名告知模型。按生成的工具名去重，避免不同服务器名规范化后
    // 重复；同一工具名优先使用成功注册的客户端配置。
    final placeholderEntriesByToolName = <String, _McpConfigEntry>{};
    final placeholderClientNamesByToolName = <String, String>{};
    final selectedPlaceholderToolNames = <String>{};
    for (final entry in mcpConfigs) {
      final selectedSource = selectedConfigSourcesByName[entry.config.name];
      if (selectedSource != null &&
          !identical(selectedSource, entry.sourceConfig)) {
        continue;
      }
      final toolName = McpServerConfig.placeholderToolName(entry.config.name);
      if (selectedSource != null) {
        if (selectedPlaceholderToolNames.add(toolName)) {
          placeholderEntriesByToolName[toolName] = entry;
          placeholderClientNamesByToolName[toolName] = entry.config.name;
        }
      } else {
        if (!placeholderEntriesByToolName.containsKey(toolName)) {
          placeholderEntriesByToolName[toolName] = entry;
          placeholderClientNamesByToolName[toolName] = entry.config.name;
        }
      }
    }
    _mcpClientManager.setPlaceholderClientNames(
      placeholderClientNamesByToolName,
    );
    _mcpToolDefinitions = [
      for (final placeholder in placeholderEntriesByToolName.entries)
        ToolDefinition(
          name: placeholder.key,
          description: placeholder.value.description.isNotEmpty
              ? placeholder.value.description
              : 'MCP 服务器工具：${placeholder.value.config.name}',
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
