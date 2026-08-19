import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/mcp.dart';

void main() {
  group('McpMessage', () {
    test('toJson serializes request correctly', () {
      final msg = McpMessage.request('tools/list', {'cursor': 'abc'});
      final json = msg.toJson();
      expect(json['jsonrpc'], equals('2.0'));
      expect(json['method'], equals('tools/list'));
      expect(json['params'], equals({'cursor': 'abc'}));
      expect(json.containsKey('id'), isTrue);
    });

    test('toJson serializes response correctly', () {
      final msg = McpMessage.response(
        id: 'req-1',
        result: {'tools': []},
      );
      final json = msg.toJson();
      expect(json['jsonrpc'], equals('2.0'));
      expect(json['id'], equals('req-1'));
      expect(json['result'], equals({'tools': []}));
      expect(json.containsKey('error'), isFalse);
    });

    test('toJson serializes error response correctly', () {
      final msg = McpMessage.response(
        id: 'req-1',
        error: {'code': -32601, 'message': 'Method not found'},
      );
      final json = msg.toJson();
      expect(json['jsonrpc'], equals('2.0'));
      expect(json['id'], equals('req-1'));
      expect(json['error'],
          equals({'code': -32601, 'message': 'Method not found'}));
      expect(json.containsKey('result'), isFalse);
    });

    test('fromJson parses request', () {
      final json = {
        'jsonrpc': '2.0',
        'id': 'req-1',
        'method': 'tools/list',
        'params': {'cursor': 'abc'},
      };
      final msg = McpMessage.fromJson(json);
      expect(msg.jsonrpc, equals('2.0'));
      expect(msg.id, equals('req-1'));
      expect(msg.method, equals('tools/list'));
      expect(msg.params, equals({'cursor': 'abc'}));
      expect(msg.result, isNull);
      expect(msg.error, isNull);
    });

    test('fromJson parses response', () {
      final json = {
        'jsonrpc': '2.0',
        'id': 'req-1',
        'result': {
          'tools': [
            {
              'name': 'test_tool',
              'description': 'A test tool',
              'inputSchema': {'type': 'object'}
            },
          ]
        },
      };
      final msg = McpMessage.fromJson(json);
      expect(msg.jsonrpc, equals('2.0'));
      expect(msg.id, equals('req-1'));
      expect(msg.result, isNotNull);
      expect(msg.method, isNull);
    });

    test('fromJson parses error response', () {
      final json = {
        'jsonrpc': '2.0',
        'id': 'req-1',
        'error': {'code': -32601, 'message': 'Method not found'},
      };
      final msg = McpMessage.fromJson(json);
      expect(msg.jsonrpc, equals('2.0'));
      expect(msg.id, equals('req-1'));
      expect(msg.error, isNotNull);
      expect(msg.error!['code'], equals(-32601));
    });
  });

  group('McpTool', () {
    test('creates from map with all fields', () {
      final map = {
        'name': 'read_file',
        'description': 'Read a file from disk',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': 'File path'},
          },
          'required': ['path'],
        },
      };
      final tool = McpTool.fromMap(map);
      expect(tool.name, equals('read_file'));
      expect(tool.description, equals('Read a file from disk'));
      expect(tool.inputSchema['type'], equals('object'));
    });

    test('creates from map with minimal fields', () {
      final map = {
        'name': 'simple_tool',
        'inputSchema': {'type': 'object'},
      };
      final tool = McpTool.fromMap(map);
      expect(tool.name, equals('simple_tool'));
      expect(tool.description, isEmpty);
      expect(tool.inputSchema['type'], equals('object'));
    });

    test('toToolDefinition converts to ToolDefinition correctly', () {
      final map = {
        'name': 'read_file',
        'description': 'Read a file from disk',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': 'File path'},
          },
          'required': ['path'],
        },
      };
      final tool = McpTool.fromMap(map);
      final def = tool.toToolDefinition();
      expect(def.name, equals('read_file'));
      expect(def.description, equals('Read a file from disk'));
      expect(def.parameters['type'], equals('object'));
    });
  });

  group('McpToolCallResponse', () {
    test('creates from map with text content', () {
      final map = {
        'content': [
          {'type': 'text', 'text': 'File contents here'},
        ],
        'isError': false,
      };
      final resp = McpToolCallResponse.fromMap(map);
      expect(resp.content.length, equals(1));
      expect(resp.content[0]['text'], equals('File contents here'));
      expect(resp.isError, isFalse);
      expect(resp.text, equals('File contents here'));
    });

    test('creates from map with multiple content items', () {
      final map = {
        'content': [
          {'type': 'text', 'text': 'Part 1'},
          {'type': 'text', 'text': 'Part 2'},
        ],
      };
      final resp = McpToolCallResponse.fromMap(map);
      expect(resp.content.length, equals(2));
      expect(resp.text, equals('Part 1\nPart 2'));
    });

    test('default isError is false', () {
      final map = {
        'content': [
          {'type': 'text', 'text': 'OK'}
        ],
      };
      final resp = McpToolCallResponse.fromMap(map);
      expect(resp.isError, isFalse);
    });

    test('isError true when set', () {
      final map = {
        'content': [
          {'type': 'text', 'text': 'Error occurred'}
        ],
        'isError': true,
      };
      final resp = McpToolCallResponse.fromMap(map);
      expect(resp.isError, isTrue);
    });

    test('empty content produces empty text', () {
      final map = {'content': <Map<String, dynamic>>[]};
      final resp = McpToolCallResponse.fromMap(map);
      expect(resp.text, isEmpty);
    });

    test('missing content produces empty text', () {
      final map = <String, dynamic>{};
      final resp = McpToolCallResponse.fromMap(map);
      expect(resp.text, isEmpty);
    });
  });

  group('McpServerConfig', () {
    test('toMap and fromMap round-trip for stdio config', () {
      final original = McpServerConfig.stdio(
        name: 'Test Server',
        command: 'npx',
        args: ['-y', 'test-server'],
        env: {'KEY': 'value'},
      );
      final map = original.toMap();
      final restored = McpServerConfig.fromMap(map);
      expect(restored, isNotNull);
      expect(restored!.name, equals(original.name));
      expect(restored.transportType, equals(original.transportType));
      expect(restored.command, equals(original.command));
      expect(restored.args, equals(original.args));
      expect(restored.env, equals(original.env));
      expect(restored.isVendor, isFalse);
    });

    test('toMap and fromMap round-trip for sse config', () {
      final original = McpServerConfig.sse(
        name: 'Remote Server',
        url: 'https://mcp.example.com/sse',
      );
      final map = original.toMap();
      final restored = McpServerConfig.fromMap(map);
      expect(restored, isNotNull);
      expect(restored!.name, equals(original.name));
      expect(restored.transportType, equals(original.transportType));
      expect(restored.url, equals(original.url));
    });

    test('toMap and fromMap round-trip for vendor config', () {
      final original = McpServerConfig.vendor(
        name: 'Built-in Calc',
        command: 'npx',
        args: ['calc'],
      );
      final map = original.toMap();
      final restored = McpServerConfig.fromMap(map);
      expect(restored, isNotNull);
      expect(restored!.name, equals(original.name));
      expect(restored.isVendor, isTrue);
    });

    test('fromMap returns null for empty map', () {
      final result = McpServerConfig.fromMap({});
      expect(result, isNull);
    });

    test('fromMap returns null for missing transport', () {
      final result = McpServerConfig.fromMap({'name': 'test'});
      expect(result, isNull);
    });

    test('vendor configs have default env for stdio path', () {
      final config = McpServerConfig.vendor(
        name: 'Vendor Tool',
        command: 'npx',
        args: ['tool'],
      );
      expect(config.env.containsKey('PATH'), isTrue,
          reason: 'Vendor stdio configs should include PATH');
    });

    test(
        'factory constructor creates McpServerConfig from ProviderConfigItem typeConfig',
        () {
      final factoryConfig = McpServerConfig.fromProviderConfig(
        providerName: 'My MCP',
        typeConfig: {
          'transport': 'sse',
          'url': 'https://mcp.example.com/sse',
        },
      );
      expect(factoryConfig, isNotNull);
      expect(factoryConfig!.name, equals('My MCP'));
      expect(factoryConfig.transportType, equals(McpTransportType.sse));
      expect(factoryConfig.url, equals('https://mcp.example.com/sse'));
    });

    test('factory constructor returns null for non-MCP typeConfig', () {
      final result = McpServerConfig.fromProviderConfig(
        providerName: 'LLM',
        typeConfig: {},
      );
      expect(result, isNull);
    });
  });

  group('McpServerConfig.extractApiKeyFromTypeConfig', () {
    test('returns empty for null/empty typeConfig', () {
      expect(McpServerConfig.extractApiKeyFromTypeConfig(null), isEmpty);
      expect(McpServerConfig.extractApiKeyFromTypeConfig({}), isEmpty);
    });

    test('returns empty for "Bearer " header placeholder', () {
      expect(
        McpServerConfig.extractApiKeyFromTypeConfig({
          'headers': {'Authorization': 'Bearer '},
        }),
        isEmpty,
        reason: 'the "Bearer " prefix placeholder must not be extracted as '
            'the 6-char "Bearer" API key',
      );
    });

    test('returns empty for corrupted legacy apiKey field "Bearer"', () {
      expect(
        McpServerConfig.extractApiKeyFromTypeConfig({
          'apiKey': 'Bearer',
        }),
        isEmpty,
        reason: 'the corrupted legacy apiKey value must self-heal to unset',
      );
    });

    test('returns empty for corrupted legacy "Bearer Bearer" header', () {
      expect(
        McpServerConfig.extractApiKeyFromTypeConfig({
          'headers': {'Authorization': 'Bearer Bearer'},
        }),
        isEmpty,
        reason: 'the corrupted legacy double-prefixed header must self-heal '
            'to unset',
      );
    });

    test('returns empty for empty header and path-like env values', () {
      expect(
        McpServerConfig.extractApiKeyFromTypeConfig({
          'headers': {'x-api-key': ''},
        }),
        isEmpty,
      );
      expect(
        McpServerConfig.extractApiKeyFromTypeConfig({
          'env': {'PATH': '/usr/local/bin:/usr/bin:/bin', 'HOME': '/root'},
        }),
        isEmpty,
        reason: 'known non-API-key env vars must be skipped',
      );
      expect(
        McpServerConfig.extractApiKeyFromTypeConfig({
          'env': {'API_KEY': 'Bearer'},
        }),
        isEmpty,
        reason: 'an env value that is only the "Bearer" placeholder must be '
            'treated as unset',
      );
    });

    test('env key survives when headers only hold a placeholder', () {
      expect(
        McpServerConfig.extractApiKeyFromTypeConfig({
          'env': {'BRAVE_API_KEY': 'bsa-789'},
          'headers': {'Authorization': 'Bearer '},
        }),
        'bsa-789',
        reason: 'a real stdio env key must still be extracted when headers '
            'carry only the "Bearer " placeholder',
      );
    });

    test('extracts a real key from a "Bearer <key>" header', () {
      expect(
        McpServerConfig.extractApiKeyFromTypeConfig({
          'headers': {'Authorization': 'Bearer sk-123'},
        }),
        'sk-123',
      );
    });

    test('extracts a real key from the apiKey field', () {
      expect(
        McpServerConfig.extractApiKeyFromTypeConfig({
          'apiKey': 'sk-456',
        }),
        'sk-456',
      );
    });

    test('extracts a real key from env values', () {
      expect(
        McpServerConfig.extractApiKeyFromTypeConfig({
          'env': {'BRAVE_API_KEY': 'bsa-789'},
        }),
        'bsa-789',
      );
    });

    test('prefers the apiKey field over headers', () {
      expect(
        McpServerConfig.extractApiKeyFromTypeConfig({
          'apiKey': 'sk-field',
          'headers': {'Authorization': 'Bearer sk-header'},
        }),
        'sk-field',
      );
    });
  });
}
