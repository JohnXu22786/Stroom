import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/mcp.dart';
import 'package:stroom/services/mcp_client.dart';

void main() {
  group('SSE response routing via _handleMessage', () {
    test('JSON-RPC error response is properly parsed', () {
      final json =
          '{"jsonrpc":"2.0","id":"req-1","error":{"code":-32601,"message":"Method not found"}}';
      final msg = JsonRpcUtils.parseResponse(json);
      expect(msg, isNotNull);
      expect(msg!.error, isNotNull);
      expect(msg.error!['code'], equals(-32601));
      expect(msg.error!['message'], equals('Method not found'));
      expect(msg.result, isNull);
    });
  });

  group('MCP tool definition enrichment', () {
    test('ToolDefinition can be created with description', () {
      final toolDef = JsonRpcUtils.extractTools({
        'tools': [
          {
            'name': 'web_search',
            'description': 'Search the web for information',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'query': {'type': 'string'},
              },
            },
          },
        ],
      });
      expect(toolDef.length, equals(1));
      expect(toolDef[0].name, equals('web_search'));
      expect(toolDef[0].description, equals('Search the web for information'));
    });

    test('ToolDefinition with empty description', () {
      final toolDef = JsonRpcUtils.extractTools({
        'tools': [
          {
            'name': 'no_desc_tool',
            'inputSchema': {'type': 'object'},
          },
        ],
      });
      expect(toolDef.length, equals(1));
      expect(toolDef[0].description, isEmpty);
    });
  });

  group('McpClient cached tools', () {
    test('cachedTools is unmodifiable', () {
      final config = McpServerConfig.sse(
        name: 'Test',
        url: 'http://localhost:3001/sse',
      );
      final client = McpClient(config: config);
      expect(() => (client.cachedTools as dynamic).add(null),
          throwsA(isA<Error>()));
    });

    test('dispose clears cached tools', () {
      final config = McpServerConfig.sse(
        name: 'Test',
        url: 'http://localhost:3001/sse',
      );
      final client = McpClient(config: config);
      client.dispose();
      expect(client.cachedTools, isEmpty);
      expect(client.isDisposed, isTrue);
    });
  });
}
