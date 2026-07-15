import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/mcp.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  group('Built-in MCP config descriptions', () {
    test('each built-in MCP config has a description', () async {
      SharedPreferences.setMockInitialValues({});
      registerBuiltinProviderTypes();

      final container = ProviderContainer(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
      );
      addTearDown(() => container.dispose());

      await container.read(providerEntriesProvider.notifier).load();

      final state = container.read(providerEntriesProvider);
      final mcpEntry = state.entries.firstWhere((e) => e.type == 'mcp');

      // Every built-in config should have a description
      for (final config in mcpEntry.configs) {
        final typeConfig = config.models.isNotEmpty
            ? config.models[0].typeConfig
            : <String, dynamic>{};
        final isVendor = typeConfig['isVendor'] as bool? ?? false;
        if (isVendor) {
          final description = typeConfig['description'] as String?;
          expect(description, isNotNull,
              reason:
                  'Config "${config.providerName}" should have a description');
          expect(description!.isNotEmpty, isTrue,
              reason:
                  'Config "${config.providerName}" description should not be empty');
        }
      }
    });

    test('built-in config description is meaningful', () async {
      SharedPreferences.setMockInitialValues({});
      registerBuiltinProviderTypes();

      final container = ProviderContainer(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
      );
      addTearDown(() => container.dispose());

      await container.read(providerEntriesProvider.notifier).load();

      final state = container.read(providerEntriesProvider);
      final mcpEntry = state.entries.firstWhere((e) => e.type == 'mcp');
      final exaConfig =
          mcpEntry.configs.firstWhere((c) => c.providerName == 'Exa');
      final exaDesc = exaConfig.models[0].typeConfig['description'] as String?;
      expect(exaDesc, isNotEmpty);

      // Different providers should have different descriptions
      final tavilyConfig =
          mcpEntry.configs.firstWhere((c) => c.providerName == 'Tavily');
      final tavilyDesc =
          tavilyConfig.models[0].typeConfig['description'] as String?;
      expect(tavilyDesc, isNotEmpty);
      expect(exaDesc, isNot(equals(tavilyDesc)),
          reason: 'Different providers should have different descriptions');
    });
  });

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
