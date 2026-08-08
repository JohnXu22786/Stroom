import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_service.dart';

void main() {
  group('default MCP entry - built-in configs', () {
    test('default MCP entry has pre-populated built-in configs', () async {
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
      expect(mcpEntry.configs.length, greaterThan(0));

      // Verify at least Exa, Tavily, Jina AI are present
      final providerNames = mcpEntry.configs.map((c) => c.providerName).toSet();
      expect(providerNames, contains('Exa'));
      expect(providerNames, contains('Tavily'));
      expect(providerNames, contains('Jina AI'));
      expect(providerNames, contains('Firecrawl'));
      expect(providerNames, contains('Brave Search'));
      expect(providerNames, contains('Searxng'));
      // REST APIs should also be present
      expect(providerNames, contains('Bocha'));
      expect(providerNames, contains('Querit'));
      expect(providerNames, contains('Zhipu'));
    });

    test('existing configs are not overwritten by built-in migration',
        () async {
      // Set up existing MCP entry with a custom config
      final savedEntries = [
        {
          'id': 'builtin_tts',
          'type': 'tts',
          'name': 'TTS供应商',
          'configs': <Map<String, dynamic>>[],
        },
        {
          'id': 'builtin_llm',
          'type': 'llm',
          'name': 'LLM供应商',
          'configs': <Map<String, dynamic>>[],
        },
        {
          'id': 'builtin_ocr',
          'type': 'ocr',
          'name': 'OCR供应商',
          'configs': <Map<String, dynamic>>[],
        },
        {
          'id': 'builtin_asr',
          'type': 'asr',
          'name': '音频转写供应商',
          'configs': <Map<String, dynamic>>[],
        },
        {
          'id': 'builtin_mcp',
          'type': 'mcp',
          'name': 'MCP供应商',
          'configs': [
            {
              'providerName': '自定义MCP',
              'host': '',
              'key': '',
              'models': <Map<String, dynamic>>[],
            },
          ],
        },
      ];

      SharedPreferences.setMockInitialValues({
        'provider_entries': jsonEncode(savedEntries),
      });
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

      // The custom config should still be there
      final customConfig =
          mcpEntry.configs.where((c) => c.providerName == '自定义MCP').toList();
      expect(customConfig.length, equals(1),
          reason: 'Custom config should be preserved');

      // Built-in configs should also be present
      final exaConfig =
          mcpEntry.configs.where((c) => c.providerName == 'Exa').toList();
      expect(exaConfig.length, equals(1),
          reason: 'Exa built-in config should be added');
    });
  });

  group('built-in config API key extraction', () {
    test('migration does not treat "Bearer " header placeholder as an API key',
        () async {
      // Old-format Bocha config (isRestApi era) whose Authorization header
      // only contains the "Bearer " prefix placeholder — no real key.
      // The migration replaces it (isRestApi → isHttpTool) and must NOT
      // capture the 6-char "Bearer" placeholder as the user's API key.
      final savedEntries = [
        {
          'id': 'builtin_tts',
          'type': 'tts',
          'name': 'TTS供应商',
          'configs': <Map<String, dynamic>>[],
        },
        {
          'id': 'builtin_llm',
          'type': 'llm',
          'name': 'LLM供应商',
          'configs': <Map<String, dynamic>>[],
        },
        {
          'id': 'builtin_ocr',
          'type': 'ocr',
          'name': 'OCR供应商',
          'configs': <Map<String, dynamic>>[],
        },
        {
          'id': 'builtin_asr',
          'type': 'asr',
          'name': '音频转写供应商',
          'configs': <Map<String, dynamic>>[],
        },
        {
          'id': 'builtin_mcp',
          'type': 'mcp',
          'name': 'MCP供应商',
          'configs': [
            {
              'providerName': 'Bocha',
              'host': 'https://api.bochaai.com/v1/web-search',
              'key': '',
              'models': [
                {
                  'name': 'Bocha',
                  'modelId': 'sse',
                  'typeConfig': {
                    'transport': 'sse',
                    'isRestApi': true,
                    'url': 'https://api.bochaai.com/v1/web-search',
                    'headers': {'Authorization': 'Bearer '},
                  },
                },
              ],
            },
          ],
        },
      ];

      SharedPreferences.setMockInitialValues({
        'provider_entries': jsonEncode(savedEntries),
      });
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
      final bocha =
          mcpEntry.configs.firstWhere((c) => c.providerName == 'Bocha');
      final typeConfig = bocha.models[0].typeConfig;

      // The placeholder must NOT be captured as the user's API key...
      expect(typeConfig['apiKey'], isNull,
          reason: 'the "Bearer " placeholder must not be migrated into the '
              'apiKey field (regression: 6-char "Bearer" was captured)');
      // ...the placeholder header must survive intact (no double-prefix)...
      final headers = typeConfig['headers'] as Map;
      expect(headers['Authorization'], 'Bearer ',
          reason: 'migration must not apply "Bearer" on top of the existing '
              '"Bearer " placeholder');
      // ...and the replacement migration must actually have run
      // (isRestApi → isHttpTool), so the test cannot pass vacuously.
      expect(typeConfig['isHttpTool'], isTrue,
          reason: 'the old isRestApi config must be replaced by the '
              'isHttpTool built-in during migration');
    });

    test('migration preserves a real "Bearer <key>" header as the API key',
        () async {
      // Old-format Bocha config with a REAL key in the Authorization header.
      // The migration replaces it (isRestApi → isHttpTool) and must keep the
      // user's key, not drop it or double-prefix it.
      final savedEntries = [
        {
          'id': 'builtin_tts',
          'type': 'tts',
          'name': 'TTS供应商',
          'configs': <Map<String, dynamic>>[],
        },
        {
          'id': 'builtin_llm',
          'type': 'llm',
          'name': 'LLM供应商',
          'configs': <Map<String, dynamic>>[],
        },
        {
          'id': 'builtin_ocr',
          'type': 'ocr',
          'name': 'OCR供应商',
          'configs': <Map<String, dynamic>>[],
        },
        {
          'id': 'builtin_asr',
          'type': 'asr',
          'name': '音频转写供应商',
          'configs': <Map<String, dynamic>>[],
        },
        {
          'id': 'builtin_mcp',
          'type': 'mcp',
          'name': 'MCP供应商',
          'configs': [
            {
              'providerName': 'Bocha',
              'host': 'https://api.bochaai.com/v1/web-search',
              'key': '',
              'models': [
                {
                  'name': 'Bocha',
                  'modelId': 'sse',
                  'typeConfig': {
                    'transport': 'sse',
                    'isRestApi': true,
                    'url': 'https://api.bochaai.com/v1/web-search',
                    'headers': {'Authorization': 'Bearer sk-123'},
                  },
                },
              ],
            },
          ],
        },
      ];

      SharedPreferences.setMockInitialValues({
        'provider_entries': jsonEncode(savedEntries),
      });
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
      final bocha =
          mcpEntry.configs.firstWhere((c) => c.providerName == 'Bocha');
      final typeConfig = bocha.models[0].typeConfig;

      // The real key must be preserved (apiKey field + header), not doubled.
      expect(typeConfig['apiKey'], 'sk-123');
      final headers = typeConfig['headers'] as Map;
      expect(headers['Authorization'], 'Bearer sk-123');
    });
  });

  group('Calculator removal', () {
    test('calculator tool is not registered by default', () {
      // After removing the calculator registration from chat_page.dart,
      // ChatService should have no built-in tools by default
      final defs = ChatService.getRegisteredToolDefinitions();
      final calcDef = defs.where((d) => d.name == 'calculator').toList();
      expect(calcDef, isEmpty,
          reason: 'Calculator should not be registered as a built-in tool');
    });
  });
}
