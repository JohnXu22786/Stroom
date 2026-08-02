part of 'chat_service.dart';

extension _ChatServiceToolsExt on ChatService {
  Future<String> _executeTool(String name, Map<String, dynamic> args) async {
    // First check locally registered tools
    final entry = ChatService._toolRegistries[name];
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

    // Then check MCP clients
    if (ChatService._mcpClientManager != null) {
      for (final entry in ChatService._mcpClientManager!.clients.entries) {
        final client = entry.value;
        if (client.isDisposed) continue;
        // 已连过但当前断开（会话中掉线）：cachedTools 里可能有该工具，
        // 尝试重连而非直接跳过（跳过会误报 Unknown tool 且慢工具
        // 的失败原因被掩盖）。
        if (!client.isConnected && client.hasConnectedBefore) {
          try {
            await client.connect();
          } catch (_) {
            // 重连失败：继续下一个客户端
            continue;
          }
        }
        if (!client.isConnected && !client.hasConnectedBefore) {
          await client.connect();
        }
        if (client.isConnected) {
          // Check if this MCP server has the tool
          final cachedTools = client.cachedTools;
          final hasTool = cachedTools.any((t) => t.name == name);
          if (hasTool) {
            return client.callTool(name, args);
          }
        }
      }
    }

    return 'Error: Unknown tool "$name"';
  }
}
