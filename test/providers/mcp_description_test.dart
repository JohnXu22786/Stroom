import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/mcp.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  group('Custom MCP config with description', () {
    test('McpServerConfig serializes description in toMap', () {
      final config = McpServerConfig.sse(
        name: 'Custom Server',
        url: 'http://example.com/sse',
      );
      final map = config.toMap();
      // description should be optional
      expect(map.containsKey('description'), isFalse);
    });

    test('McpServerConfig fromProviderConfig handles description field', () {
      final typeConfig = <String, dynamic>{
        'transport': 'sse',
        'url': 'http://example.com/sse',
        'description': 'My custom MCP server',
      };

      final config = McpServerConfig.fromProviderConfig(
        providerName: 'Custom',
        typeConfig: typeConfig,
      );
      expect(config, isNotNull);
      expect(config!.url, equals('http://example.com/sse'));
      // description is stored in typeConfig but not in McpServerConfig itself
    });

    test('ProviderConfigItem round-trip preserves description in typeConfig',
        () async {
      SharedPreferences.setMockInitialValues({});
      registerBuiltinProviderTypes();

      final config = ProviderConfigItem(
        providerName: 'My Server',
        host: '',
        key: '',
        models: [
          ModelConfig(
            name: 'My Server',
            modelId: 'sse',
            typeConfig: {
              'transport': 'sse',
              'url': 'http://example.com/sse',
              'description': 'A custom description',
            },
          ),
        ],
      );

      final map = config.toMap();
      final restored = ProviderConfigItem.fromMap(map);
      final typeConfig = restored.models[0].typeConfig;
      expect(typeConfig['description'], equals('A custom description'));
      expect(typeConfig['transport'], equals('sse'));
      expect(typeConfig['url'], equals('http://example.com/sse'));
    });
  });
}
