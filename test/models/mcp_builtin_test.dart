import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/mcp.dart';

void main() {
  group('McpServerConfig - apiKey and headers fields', () {
    test('apiKey and headers are preserved through toMap/fromMap round-trip', () {
      final config = McpServerConfig.sse(
        name: 'Exa',
        url: 'https://mcp.exa.ai/mcp',
        apiKey: 'test-api-key',
        headers: {'x-api-key': 'test-api-key'},
      );

      final map = config.toMap();
      expect(map['apiKey'], equals('test-api-key'));
      expect(map['headers'], equals({'x-api-key': 'test-api-key'}));

      final restored = McpServerConfig.fromMap(map);
      expect(restored, isNotNull);
      expect(restored!.name, equals('Exa'));
      expect(restored.apiKey, equals('test-api-key'));
      expect(restored.headers, equals({'x-api-key': 'test-api-key'}));
    });

    test('stdio config with apiKey round-trips correctly', () {
      final config = McpServerConfig.stdio(
        name: 'Jina AI',
        command: 'npx',
        args: ['-y', '@jina-ai/mcp-server'],
        env: {'JINA_API_KEY': 'test-key'},
        apiKey: 'test-key',
      );

      final map = config.toMap();
      expect(map['apiKey'], equals('test-key'));

      final restored = McpServerConfig.fromMap(map);
      expect(restored, isNotNull);
      expect(restored!.name, equals('Jina AI'));
      expect(restored.apiKey, equals('test-key'));
      expect(restored.env, containsPair('JINA_API_KEY', 'test-key'));
    });

    test('null apiKey is excluded from toMap output', () {
      final config = McpServerConfig.sse(
        name: 'Remote',
        url: 'https://example.com/mcp',
      );

      final map = config.toMap();
      expect(map.containsKey('apiKey'), isFalse);
    });

    test('empty headers is excluded from toMap output', () {
      final config = McpServerConfig.sse(
        name: 'Remote',
        url: 'https://example.com/mcp',
      );

      final map = config.toMap();
      expect(map.containsKey('headers'), isFalse);
    });

    test('fromProviderConfig handles apiKey and headers', () {
      final config = McpServerConfig.fromProviderConfig(
        providerName: 'Exa',
        typeConfig: {
          'transport': 'sse',
          'url': 'https://mcp.exa.ai/mcp',
          'apiKey': 'test-key',
          'headers': {'x-api-key': 'test-key'},
        },
      );

      expect(config, isNotNull);
      expect(config!.name, equals('Exa'));
      expect(config.apiKey, equals('test-key'));
      expect(config.headers, equals({'x-api-key': 'test-key'}));
      expect(config.transportType, equals(McpTransportType.sse));
    });

    test('vendor config with apiKey serialization preserves isVendor', () {
      final config = McpServerConfig.sse(
        name: 'Tavily',
        url: 'https://mcp.tavily.com/mcp/?tavilyApiKey=tvly-YOUR_KEY',
        apiKey: 'tvly-test-key',
        isVendor: true,
      );

      final map = config.toMap();
      expect(map['isVendor'], isTrue);
      expect(map['apiKey'], equals('tvly-test-key'));

      final restored = McpServerConfig.fromMap(map);
      expect(restored, isNotNull);
      expect(restored!.isVendor, isTrue);
      expect(restored.apiKey, equals('tvly-test-key'));
    });
  });
}
