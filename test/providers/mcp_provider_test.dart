import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/provider_config.dart';

/// Build saved data without MCP entry (simulating existing user upgrade).
String _savedDataWithoutMcp() {
  final entries = [
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
      'name': '语音识别供应商',
      'configs': <Map<String, dynamic>>[],
    },
  ];
  return jsonEncode(entries);
}

/// Build saved data WITH MCP entry.
String _savedDataWithMcp() {
  final entries = [
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
      'name': '语音识别供应商',
      'configs': <Map<String, dynamic>>[],
    },
    {
      'id': 'builtin_mcp',
      'type': 'mcp',
      'name': 'MCP供应商',
      'configs': <Map<String, dynamic>>[],
    },
  ];
  return jsonEncode(entries);
}

/// Build saved data WITH MCP entry containing a custom SSE server.
String _savedDataWithMcpConfig() {
  final entries = [
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
      'name': '语音识别供应商',
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
          'models': [],
        },
      ],
    },
  ];
  return jsonEncode(entries);
}

void main() {
  group('MCP provider type registration', () {
    test('MCP provider type is registered', () {
      registerBuiltinProviderTypes();
      expect(ProviderTypeRegistry.isRegistered('mcp'), isTrue);
    });

    test('MCP provider type has correct definition', () {
      registerBuiltinProviderTypes();
      final def = ProviderTypeRegistry.get('mcp');
      expect(def, isNotNull);
      expect(def!.type, equals('mcp'));
      expect(def.useLlmModelConfig, isFalse,
          reason: 'MCP servers use typeConfig, not LLM model config');
    });
  });

  group('MCP ProviderEntry', () {
    test('MCP ProviderEntry can be created', () {
      final entry = ProviderEntry(
        id: 'test_mcp',
        type: 'mcp',
        name: 'MCP供应商',
      );
      expect(entry.id, equals('test_mcp'));
      expect(entry.type, equals('mcp'));
      expect(entry.name, equals('MCP供应商'));
    });

    test('MCP ProviderEntry with config', () {
      final config = ProviderConfigItem(
        providerName: 'Test MCP Server',
        host: '',
        key: '',
        models: [],
      );
      final entry = ProviderEntry(
        id: 'mcp_1',
        type: 'mcp',
        name: 'MCP供应商',
        configs: [config],
      );
      expect(entry.configs.length, equals(1));
      expect(entry.configs[0].providerName, equals('Test MCP Server'));
    });

    test('MCP ProviderEntry serialization round-trip', () {
      final config = ProviderConfigItem(
        providerName: 'My MCP Server',
        host: '',
        key: '',
        models: [],
      );
      final entry = ProviderEntry(
        id: 'mcp_roundtrip',
        type: 'mcp',
        name: 'MCP供应商',
        configs: [config],
      );

      final map = entry.toMap();
      expect(map['type'], equals('mcp'));

      final restored = ProviderEntry.fromMap(map);
      expect(restored.id, equals(entry.id));
      expect(restored.type, equals('mcp'));
      expect(restored.configs.length, equals(1));
      expect(restored.configs[0].providerName, equals('My MCP Server'));
    });

    test('MCP entry with typeConfig in model config survives round-trip', () {
      final config = ProviderConfigItem(
        providerName: 'SSE Server',
        host: '',
        key: '',
        models: [
          ModelConfig(
            name: 'Remote',
            modelId: 'sse',
            typeConfig: {
              'transport': 'sse',
              'url': 'https://mcp.example.com/sse',
            },
          ),
        ],
      );
      final entry = ProviderEntry(
        id: 'mcp_sse',
        type: 'mcp',
        name: 'MCP供应商',
        configs: [config],
      );

      final map = entry.toMap();
      final restored = ProviderEntry.fromMap(map);
      final restoredModel = restored.configs[0].models[0];
      expect(restoredModel.typeConfig['transport'], equals('sse'));
      expect(restoredModel.typeConfig['url'], equals('https://mcp.example.com/sse'));
    });
  });

  group('ProviderEntriesNotifier - MCP entry auto-migration', () {
    test('default entries include MCP when no saved data', () async {
      SharedPreferences.setMockInitialValues({});
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
      expect(state.entries.any((e) => e.type == 'mcp'), isTrue);
      expect(state.entries.any((e) => e.id == 'builtin_mcp'), isTrue);
    });

    test('MCP entry is auto-added to saved data that does not have MCP', () async {
      SharedPreferences.setMockInitialValues({
        'provider_entries': _savedDataWithoutMcp(),
      });
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
      expect(state.entries.any((e) => e.type == 'mcp'), isTrue,
          reason: 'MCP entry should be migrated in');
      expect(state.entries.any((e) => e.id == 'builtin_tts'), isTrue,
          reason: 'TTS entry should be preserved');
      expect(state.entries.any((e) => e.id == 'builtin_llm'), isTrue,
          reason: 'LLM entry should be preserved');
      expect(state.entries.any((e) => e.id == 'builtin_ocr'), isTrue,
          reason: 'OCR entry should be preserved');
      expect(state.entries.any((e) => e.id == 'builtin_asr'), isTrue,
          reason: 'ASR entry should be preserved');
    });

    test('MCP entry is not duplicated when it already exists in saved data',
        () async {
      SharedPreferences.setMockInitialValues({
        'provider_entries': _savedDataWithMcp(),
      });
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
      final mcpEntries = state.entries.where((e) => e.type == 'mcp').toList();
      expect(mcpEntries.length, equals(1),
          reason: 'Should have exactly one MCP entry, not duplicated');
    });

    test('MCP entry preserves existing provider configs (TTS, LLM, OCR, ASR)',
        () async {
      SharedPreferences.setMockInitialValues({
        'provider_entries': _savedDataWithoutMcp(),
      });
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
      expect(state.entries.length, equals(5));
      expect(state.entries[0].type, equals('tts'));
      expect(state.entries[1].type, equals('llm'));
      expect(state.entries[2].type, equals('ocr'));
      expect(state.entries[3].type, equals('asr'));
      expect(state.entries[4].type, equals('mcp'));
    });

    test('saved MCP config is preserved through load', () async {
      SharedPreferences.setMockInitialValues({
        'provider_entries': _savedDataWithMcpConfig(),
      });
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
      expect(mcpEntry.id, equals('builtin_mcp'));
      expect(mcpEntry.name, equals('MCP供应商'));
      expect(mcpEntry.configs.length, equals(1));
      expect(mcpEntry.configs[0].providerName, equals('自定义MCP'));
    });
  });
}
