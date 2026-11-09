part of 'chat_service.dart';

extension _ChatServiceToolsExt on ChatService {
  /// 执行工具。MCP 服务器是**懒连接**的：进入对话页面时只发布占位工具
  /// 定义（见 chat_adapter_mcp.dart），不发起任何网络连接。真正连接与
  /// 工具发现在这里按需进行：
  ///
  /// - 调用名命中某服务器的占位工具名（如 "exa_mcp"）：按需连接该服务器
  ///   并列出真实工具，然后用错误信息把可用工具名告知模型（占位符不是
  ///   真实工具，模型需要改用真实工具名重试）。
  /// - 调用名已在某服务器的工具缓存中（模型从上一条错误信息得知的真实
  ///   工具名）：确保连接后直接调用。
  Future<String> _executeTool(String name, Map<String, dynamic> args) async {
    final locale = _localeOverride?.call();
    final l10n = appLocalizationsForLocale(locale);
    final routeSeparator = l10n.localeName.startsWith('en') ? ', ' : '、';
    final isDisabled = ChatService._disabledToolNames.contains(name);

    // First check locally registered tools
    // A disabled provider may have a placeholder name that matches an active
    // MCP server's real tool. Let enabled MCP routes resolve before reporting
    // the disabled name, while still blocking the local handler itself.
    final entry = isDisabled ? null : ChatService._toolRegistries[name];
    if (entry != null) {
      final localizedHandler = entry['localizedHandler'] as dynamic Function(
          Map<String, dynamic>, Locale?)?;
      final result = localizedHandler != null
          ? localizedHandler(args, _localeOverride?.call())
          : (entry['handler'] as dynamic Function(Map<String, dynamic>))(args);
      // Handle both sync and async handlers
      if (result is Future<String>) {
        return await result;
      }
      return result as String;
    }

    // Then check MCP clients (lazy: connect + list tools on demand)
    if (ChatService._mcpClientManager != null) {
      final manager = ChatService._mcpClientManager!;
      // A discovered tool may have a stable alias when its real name conflicts
      // with a placeholder or another server's tool. Resolve the published
      // name first, then call the original MCP name on its owning client.
      final routedClientName = manager.getToolClientName(name);
      if (routedClientName != null) {
        final client = manager.getClient(routedClientName);
        final actualToolName = manager.getActualToolName(name);
        if (client != null &&
            !client.isDisposed &&
            client.cachedTools.any((tool) => tool.name == actualToolName)) {
          if (!client.isConnected && !await client.connect()) {
            return l10n.toolResultMcpReconnectFailed(client.config.name);
          }
          if (client.isConnected) {
            return client.callTool(actualToolName, args, locale: locale);
          }
        }
      }

      final placeholderClientName = manager.getPlaceholderClientName(name);
      if (placeholderClientName != null) {
        final client = manager.getClient(placeholderClientName);
        if (client == null || client.isDisposed) {
          return l10n.toolResultMcpUnavailable(placeholderClientName);
        }
        var tools = client.cachedTools;
        if (tools.isEmpty) {
          // listTools 内部会按需 connect()（未连接时），失败返回 []。
          tools = await client.listTools();
        }
        if (tools.isEmpty) {
          return l10n.toolResultMcpNoTools(client.config.name);
        }
        manager.routeToolsToClient(
          placeholderClientName,
          tools.map((tool) => tool.name),
        );
        // If this server's real tool has the same name as its placeholder and
        // the name is otherwise unambiguous, execute it directly. A collision
        // alias must still be honored so the placeholder name remains reserved.
        if (tools.any(
          (tool) =>
              tool.name == name &&
              manager.getPublishedToolName(placeholderClientName, tool.name) ==
                  name,
        )) {
          return client.callTool(name, args, locale: locale);
        }
        final available = tools
            .map(
              (tool) => manager.getPublishedToolName(
                placeholderClientName,
                tool.name,
              ),
            )
            .join(routeSeparator);
        final toolGuidance = <String>{};
        for (final tool in tools) {
          final publishedName = manager.getPublishedToolName(
            placeholderClientName,
            tool.name,
          );
          if (publishedName != tool.name) {
            toolGuidance.add(
              l10n.toolResultMcpAliasedName(tool.name, publishedName),
            );
          }
          final clientNames = manager.getToolClientNames(tool.name);
          if (clientNames.length < 2) continue;
          final routes = clientNames
              .map(
                (clientName) =>
                    '"${manager.getPublishedToolName(clientName, tool.name)}" '
                    '${l10n.toolResultMcpServerRoute(clientName)}',
              )
              .join(routeSeparator);
          toolGuidance.add(l10n.toolResultMcpDuplicateNames(tool.name, routes));
        }
        final collisionGuidance = toolGuidance.join(' ');
        final hasAliasedRequestedName = tools.any(
          (tool) =>
              tool.name == name &&
              manager.getPublishedToolName(placeholderClientName, tool.name) !=
                  name,
        );
        final missingToolMessage = hasAliasedRequestedName
            ? l10n.toolResultMcpAliasedConflict(name)
            : l10n.toolResultMcpMissingTool(client.config.name, name);
        return '$missingToolMessage\n'
            '${l10n.toolResultMcpAvailableTools(available)}'
            '${collisionGuidance.isEmpty ? '' : ' $collisionGuidance'}';
      }

      for (final entry in manager.clients.entries) {
        final client = entry.value;
        if (client.isDisposed) continue;

        // 真实工具名：工具已在缓存中（上一次占位符调用发现过，或会话中
        // 曾发现过）→ 确保连接后调用。会话中掉线时 connect() 会重连。
        final hasTool = client.cachedTools.any(
          (tool) =>
              tool.name == manager.getActualToolName(name) &&
              manager.getPublishedToolName(entry.key, tool.name) == name,
        );
        if (hasTool) {
          if (!client.isConnected) {
            final connected = await client.connect();
            if (!connected) {
              // 重连失败：继续下一个客户端
              continue;
            }
          }
          if (client.isConnected) {
            return client.callTool(
              manager.getActualToolName(name),
              args,
              locale: locale,
            );
          }
        }
      }

      final knownOwners = manager.getToolClientNames(name);
      if (knownOwners.isNotEmpty) {
        final routes = knownOwners
            .map(
              (clientName) =>
                  '"${manager.getPublishedToolName(clientName, name)}" '
                  '${l10n.toolResultMcpServerRoute(clientName)}',
            )
            .join(routeSeparator);
        return l10n.toolResultMcpAliasConflict(name, routes);
      }
    }

    if (isDisabled) {
      return l10n.toolResultToolDisabled(name);
    }
    return l10n.toolResultToolUnknown(name);
  }
}
