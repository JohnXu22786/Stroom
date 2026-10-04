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
    final isDisabled = ChatService._disabledToolNames.contains(name);

    // First check locally registered tools
    // A disabled provider may have a placeholder name that matches an active
    // MCP server's real tool. Let enabled MCP routes resolve before reporting
    // the disabled name, while still blocking the local handler itself.
    final entry = isDisabled ? null : ChatService._toolRegistries[name];
    if (entry != null) {
      final handler =
          entry['handler'] as dynamic Function(Map<String, dynamic>);
      final result = handler(args);
      // Handle both sync and async handlers
      if (result is Future<String>) {
        return await result;
      }
      return result as String;
    }

    // Then check MCP clients (lazy: connect + list tools on demand)
    if (ChatService._mcpClientManager != null) {
      final manager = ChatService._mcpClientManager!;
      // A discovered real tool may share another server's placeholder name.
      // Honor its explicit route before interpreting the name as a placeholder.
      final routedClientName = manager.getToolClientName(name);
      if (routedClientName != null) {
        final client = manager.getClient(routedClientName);
        if (client != null &&
            !client.isDisposed &&
            client.cachedTools.any((tool) => tool.name == name)) {
          if (!client.isConnected && !await client.connect()) {
            return 'Error: MCP 服务器 "${client.config.name}" 重新连接失败。';
          }
          if (client.isConnected) return client.callTool(name, args);
        }
      }

      final placeholderClientName = manager.getPlaceholderClientName(name);
      if (placeholderClientName != null) {
        final client = manager.getClient(placeholderClientName);
        if (client == null || client.isDisposed) {
          return 'Error: MCP 服务器 "$placeholderClientName" 当前不可用。';
        }
        var tools = client.cachedTools;
        if (tools.isEmpty) {
          // listTools 内部会按需 connect()（未连接时），失败返回 []。
          tools = await client.listTools();
        }
        if (tools.isEmpty) {
          return 'Error: MCP 服务器 "${client.config.name}" 连接失败或未返回任何工具，请检查服务器配置。';
        }
        manager.routeToolsToClient(
          placeholderClientName,
          tools.map((tool) => tool.name),
        );
        // 极少数服务器真实提供了与占位符同名的工具：直接执行，
        // 避免模型陷入"调用占位符 → 报错列出同名工具 → 再调用"的死循环。
        if (tools.any((t) => t.name == name)) {
          return client.callTool(name, args);
        }
        final available = tools.map((t) => t.name).join(', ');
        return 'Error: MCP 服务器 "${client.config.name}" 没有名为 "$name" 的工具。'
            '该服务器可用的工具: $available。请改用这些工具名调用。';
      }

      for (final entry in manager.clients.entries) {
        final client = entry.value;
        if (client.isDisposed) continue;

        // 真实工具名：工具已在缓存中（上一次占位符调用发现过，或会话中
        // 曾发现过）→ 确保连接后调用。会话中掉线时 connect() 会重连。
        final hasTool = client.cachedTools.any((t) => t.name == name);
        if (hasTool) {
          if (!client.isConnected) {
            final connected = await client.connect();
            if (!connected) {
              // 重连失败：继续下一个客户端
              continue;
            }
          }
          if (client.isConnected) {
            return client.callTool(name, args);
          }
        }
      }
    }

    if (isDisabled) {
      return 'Error: Tool "$name" is disabled.';
    }
    return 'Error: Unknown tool "$name"';
  }
}
