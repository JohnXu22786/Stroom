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
        if (client.isConnected == false &&
            client.isDisposed == false &&
            !client.hasConnectedBefore) {
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
