import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/mcp_client.dart';
import 'package:stroom/models/mcp.dart';

void main() {
  group('JsonRpcUtils', () {
    test('parses valid JSON-RPC response', () {
      final json = '{"jsonrpc":"2.0","id":"1","result":{"tools":[]}}';
      final msg = JsonRpcUtils.parseResponse(json);
      expect(msg, isNotNull);
      expect(msg!.id, equals('1'));
      expect(msg!.result, isNotNull);
    });

    test('returns null for invalid JSON', () {
      final msg = JsonRpcUtils.parseResponse('not json');
      expect(msg, isNull);
    });

    test('returns null for empty string', () {
      final msg = JsonRpcUtils.parseResponse('');
      expect(msg, isNull);
    });

    test('parses response with error', () {
      final json =
          '{"jsonrpc":"2.0","id":"1","error":{"code":-32601,"message":"Method not found"}}';
      final msg = JsonRpcUtils.parseResponse(json);
      expect(msg, isNotNull);
      expect(msg!.error, isNotNull);
    });

    test('extracts tools from list response', () {
      final result = {
        'tools': [
          {
            'name': 'tool1',
            'inputSchema': {'type': 'object'}
          },
          {
            'name': 'tool2',
            'inputSchema': {'type': 'object'}
          },
        ],
      };
      final tools = JsonRpcUtils.extractTools(result);
      expect(tools.length, equals(2));
      expect(tools[0].name, equals('tool1'));
      expect(tools[1].name, equals('tool2'));
    });

    test('extracts tools from empty list', () {
      final result = {'tools': <Map<String, dynamic>>[]};
      final tools = JsonRpcUtils.extractTools(result);
      expect(tools, isEmpty);
    });

    test('extracts tools from null result', () {
      final tools = JsonRpcUtils.extractTools(null);
      expect(tools, isEmpty);
    });

    test('extracts call result text', () {
      final result = {
        'content': [
          {'type': 'text', 'text': 'Hello World'},
        ],
      };
      final response = JsonRpcUtils.extractCallResult(result);
      expect(response, isNotNull);
      expect(response!.text, equals('Hello World'));
      expect(response.isError, isFalse);
    });

    test('extracts call result with error', () {
      final result = {
        'content': [
          {'type': 'text', 'text': 'Error occurred'},
        ],
        'isError': true,
      };
      final response = JsonRpcUtils.extractCallResult(result);
      expect(response, isNotNull);
      expect(response!.text, equals('Error occurred'));
      expect(response.isError, isTrue);
    });

    test('extracts call result from null result', () {
      final response = JsonRpcUtils.extractCallResult(null);
      expect(response, isNull);
    });

    test('builds tools/list request JSON', () {
      final json = JsonRpcUtils.buildRequest('tools/list');
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['jsonrpc'], equals('2.0'));
      expect(decoded['method'], equals('tools/list'));
      expect(decoded.containsKey('id'), isTrue);
      expect(decoded.containsKey('params'), isFalse);
    });

    test('builds tools/call request JSON', () {
      final json = JsonRpcUtils.buildRequest('tools/call', {
        'name': 'test_tool',
        'arguments': {'key': 'value'},
      });
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['jsonrpc'], equals('2.0'));
      expect(decoded['method'], equals('tools/call'));
      expect(
          decoded['params'],
          equals({
            'name': 'test_tool',
            'arguments': {'key': 'value'},
          }));
    });

    test('builds initialize request', () {
      final json = JsonRpcUtils.buildRequest('initialize', {
        'protocolVersion': '2024-11-05',
        'capabilities': {},
        'clientInfo': {
          'name': 'stroom',
          'version': '0.2.13',
        },
      });
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['method'], equals('initialize'));
      expect(decoded['params']['protocolVersion'], equals('2024-11-05'));
    });

    test('builds notifications/initialized request (no params)', () {
      final json = JsonRpcUtils.buildRequest('notifications/initialized');
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['method'], equals('notifications/initialized'));
      expect(decoded.containsKey('params'), isFalse);
    });
  });

  group('McpClient creation', () {
    test('creates client with SSE config', () {
      final config = McpServerConfig.sse(
        name: 'Test SSE',
        url: 'http://localhost:3001/sse',
      );
      final client = McpClient(config: config);
      expect(client, isNotNull);
      expect(client.config.name, equals('Test SSE'));
      expect(client.isConnected, isFalse);
      expect(client.isDisposed, isFalse);
    });

    test('throws on empty URL for SSE config', () {
      final config = McpServerConfig.sse(name: 'Bad SSE', url: '');
      expect(() => McpClient(config: config), throwsArgumentError);
    });

    test('creates client with stdio config', () {
      final config = McpServerConfig.stdio(
        name: 'Test Stdio',
        command: 'echo',
        args: ['hello'],
      );
      final client = McpClient(config: config);
      expect(client, isNotNull);
      expect(client.config.name, equals('Test Stdio'));
    });

    test('throws on empty command for stdio config', () {
      final config =
          McpServerConfig.stdio(name: 'Bad Stdio', command: '', args: []);
      expect(() => McpClient(config: config), throwsArgumentError);
    });

    test('client is properly disposed', () {
      final config = McpServerConfig.sse(
        name: 'Test',
        url: 'http://localhost:3001/sse',
      );
      final client = McpClient(config: config);
      client.dispose();
      expect(client.isDisposed, isTrue);
      expect(client.isConnected, isFalse);
    });

    test('connect returns false when already disposed', () async {
      final config = McpServerConfig.sse(
        name: 'Test',
        url: 'http://localhost:3001/sse',
      );
      final client = McpClient(config: config);
      client.dispose();
      final connected = await client.connect();
      expect(connected, isFalse);
    });
  });

  group('McpClientManager', () {
    test('creates empty manager', () {
      final manager = McpClientManager();
      expect(manager.clients, isEmpty);
    });

    test('adds and removes clients', () {
      final manager = McpClientManager();
      final config = McpServerConfig.sse(
        name: 'Test',
        url: 'http://localhost:3001/sse',
      );
      final client = McpClient(config: config);
      manager.addClient('server_1', client);
      expect(manager.clients.length, equals(1));
      expect(manager.getClient('server_1'), same(client));

      manager.removeClient('server_1');
      expect(manager.clients, isEmpty);
    });

    test('getClient returns null for unknown id', () {
      final manager = McpClientManager();
      expect(manager.getClient('unknown'), isNull);
    });

    test('disposeAll disposes all clients', () {
      final manager = McpClientManager();
      final config1 = McpServerConfig.sse(name: 'A', url: 'http://a/sse');
      final config2 = McpServerConfig.sse(name: 'B', url: 'http://b/sse');
      final client1 = McpClient(config: config1);
      final client2 = McpClient(config: config2);
      manager.addClient('a', client1);
      manager.addClient('b', client2);
      manager.disposeAll();
      expect(client1.isDisposed, isTrue);
      expect(client2.isDisposed, isTrue);
      expect(manager.clients, isEmpty);
    });

    test('removeClient disposes the removed client', () {
      final manager = McpClientManager();
      final config = McpServerConfig.sse(name: 'Test', url: 'http://test/sse');
      final client = McpClient(config: config);
      manager.addClient('test', client);
      manager.removeClient('test');
      expect(client.isDisposed, isTrue);
    });

    test('addClient with existing id replaces and disposes old client', () {
      final manager = McpClientManager();
      final oldClient = McpClient(
        config: McpServerConfig.sse(name: 'Old', url: 'http://old/sse'),
      );
      final newClient = McpClient(
        config: McpServerConfig.sse(name: 'New', url: 'http://new/sse'),
      );
      manager.addClient('dup', oldClient);
      manager.addClient('dup', newClient);
      expect(oldClient.isDisposed, isTrue);
      expect(manager.getClient('dup'), same(newClient));
    });
  });
}
