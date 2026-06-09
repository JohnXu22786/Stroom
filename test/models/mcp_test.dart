import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/mcp.dart';

void main() {
  group('McpMessage', () {
    test('creates a request with correct fields', () {
      final msg = McpMessage.request('tools/list', {'cursor': 'abc'});
      expect(msg.jsonrpc, equals('2.0'));
      expect(msg.id, isNotNull);
      expect(msg.method, equals('tools/list'));
      expect(msg.params, equals({'cursor': 'abc'}));
    });

    test('creates a request without params', () {
      final msg = McpMessage.request('tools/list');
      expect(msg.jsonrpc, equals('2.0'));
      expect(msg.id, isNotNull);
      expect(msg.method, equals('tools/list'));
      expect(msg.params, isNull);
    });

    test('creates a response with result', () {
      final msg = McpMessage.response(
        id: 'req-1',
        result: {'tools': []},
      );
      expect(msg.jsonrpc, equals('2.0'));
      expect(msg.id, equals('req-1'));
      expect(msg.result, equals({'tools': []}));
    });

    test('creates a response with error', () {
      final msg = McpMessage.response(
        id: 'req-1',
        error: {'code': -32601, 'message': 'Method not found'},
      );
      expect(msg.jsonrpc, equals('2.0'));
      expect(msg.id, equals('req-1'));
      expect(msg.error, equals({'code': -32601, 'message': 'Method not found'}));
    });

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
      expect(json['error'], equals({'code': -32601, 'message': 'Method not found'}));
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
        'result': {'tools': [
          {'name': 'test_tool', 'description': 'A test tool', 'inputSchema': {'type': 'object'}},
        ]},
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

    test('multiple tools can be created from a list response', () {
      final maps = [
        {'name': 'tool_a', 'inputSchema': {'type': 'object'}},
        {'name': 'tool_b', 'inputSchema': {'type': 'object'}},
        {'name': 'tool_c', 'inputSchema': {'type': 'object'}},
      ];
      final tools = maps.map((m) => McpTool.fromMap(m)).toList();
      expect(tools.length, equals(3));
      expect(tools[0].name, equals('tool_a'));
      expect(tools[2].name, equals('tool_c'));
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
        'content': [{'type': 'text', 'text': 'OK'}],
      };
      final resp = McpToolCallResponse.fromMap(map);
      expect(resp.isError, isFalse);
    });

    test('isError true when set', () {
      final map = {
        'content': [{'type': 'text', 'text': 'Error occurred'}],
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
    test('creates stdio config with command and args', () {
      final config = McpServerConfig.stdio(
        name: 'Filesystem Server',
        command: 'npx',
        args: ['-y', '@modelcontextprotocol/server-filesystem', '/tmp'],
      );
      expect(config.name, equals('Filesystem Server'));
      expect(config.transportType, equals(McpTransportType.stdio));
      expect(config.command, equals('npx'));
      expect(config.args, equals(['-y', '@modelcontextprotocol/server-filesystem', '/tmp']));
    });

    test('creates sse config with url', () {
      final config = McpServerConfig.sse(
        name: 'Remote Server',
        url: 'http://localhost:3001/sse',
      );
      expect(config.name, equals('Remote Server'));
      expect(config.transportType, equals(McpTransportType.sse));
      expect(config.url, equals('http://localhost:3001/sse'));
    });

    test('creates vendor config', () {
      final config = McpServerConfig.vendor(
        name: 'Calculator',
        command: 'npx',
        args: ['-y', '@vendor/mcp-calc'],
      );
      expect(config.name, equals('Calculator'));
      expect(config.isVendor, isTrue);
    });

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

    test('factory constructor creates McpServerConfig from ProviderConfigItem typeConfig', () {
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
}
