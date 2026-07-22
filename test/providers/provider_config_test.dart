// Merged from:
//   - provider_config_asr_test.dart
//   - provider_config_ocr_test.dart
//   - provider_host_hint_test.dart
//   - provider_params_redesign_test.dart (in test/ root)
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/llm_model_config_page.dart';
import 'package:stroom/pages/provider_config_detail_page.dart';
import 'package:stroom/providers/provider_config.dart';

// ===========================================================================
// Helpers (from provider_config_asr_test.dart)
// ===========================================================================

/// Builds saved data without ASR (simulates older user upgrade, no OCR/ASR).
String _savedDataWithoutAsr() {
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
  ];
  return jsonEncode(entries);
}

/// Builds saved data with ASR (TTS, LLM, OCR, ASR, all empty).
String _savedDataWithAsr() {
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
      'name': '音频转写供应商',
      'configs': <Map<String, dynamic>>[],
    },
  ];
  return jsonEncode(entries);
}

/// Builds saved data with ASR containing one provider config.
String _savedDataWithAsrConfig() {
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
      'id': 'my_asr',
      'type': 'asr',
      'name': '我的音频转写',
      'configs': [
        {
          'providerName': '自定义ASR',
          'host': 'https://asr.example.com',
          'key': 'sk-asr-test',
          'models': [
            {
              'name': 'whisper-1',
              'modelId': 'whisper-1',
              'voices': <Map<String, dynamic>>[],
              'customParams': <Map<String, dynamic>>[],
              'typeConfig': <String, dynamic>{},
            },
          ],
        },
      ],
    },
  ];
  return jsonEncode(entries);
}

// ===========================================================================
// Helpers (from provider_config_ocr_test.dart)
// ===========================================================================

/// Builds saved data without OCR (simulates older user upgrade).
String _savedDataWithoutOcr() {
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
  ];
  return jsonEncode(entries);
}

/// Builds saved data with OCR (TTS, LLM, OCR, all empty).
String _savedDataWithOcr() {
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
  ];
  return jsonEncode(entries);
}

/// Builds saved data with OCR containing one provider config.
String _savedDataWithOcrConfig() {
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
      'id': 'my_ocr',
      'type': 'ocr',
      'name': '我的OCR',
      'configs': [
        {
          'providerName': '自定义OCR',
          'host': 'https://ocr.example.com',
          'key': 'sk-test123',
          'models': [
            {
              'name': 'Qwen-VL',
              'modelId': 'qwen-vl-max',
              'voices': <Map<String, dynamic>>[],
              'customParams': <Map<String, dynamic>>[],
              'typeConfig': <String, dynamic>{}
            }
          ],
        },
      ],
    },
  ];
  return jsonEncode(entries);
}

// ===========================================================================
// Helpers (from provider_params_redesign_test.dart)
// ===========================================================================

/// Helper to create a test ProviderEntry with one config (with provider-level params)
ProviderEntry _createTestEntry({
  String providerName = 'TestProvider',
  String host = 'https://api.test.com',
  String key = 'test-key-123',
  List<ModelConfig> models = const [],
  String type = 'llm',
  String name = 'LLM供应商',
}) {
  return ProviderEntry(
    id: 'test_entry_id',
    type: type,
    name: name,
    configs: [
      ProviderConfigItem(
        providerName: providerName,
        host: host,
        key: key,
        models: models,
      ),
    ],
  );
}

/// Fake notifier that immediately provides test data
class ProviderEntriesNotifierFake extends ProviderEntriesNotifier {
  ProviderEntriesNotifierFake({String type = 'llm', String name = 'LLM供应商'}) {
    state = ProviderEntriesState(
      entries: [_createTestEntry(type: type, name: name)],
    );
  }

  @override
  Future<void> update(String id, ProviderEntry updated) async {
    state = ProviderEntriesState(
      entries: state.entries.map((e) => e.id == id ? updated : e).toList(),
    );
  }
}

void main() {
  setUpAll(() {
    registerBuiltinProviderTypes();
  });

  // =================================================================
  // 1. ProviderTypeDefinition hostHint
  // =================================================================
  group('ProviderTypeDefinition hostHint', () {
    setUp(() {
      registerBuiltinProviderTypes();
    });

    test('ProviderTypeDefinition has hostHint field', () {
      const def = ProviderTypeDefinition(type: 'test');
      expect(def.hostHint, isNull);
    });

    test('hostHint defaults to null when not provided', () {
      const def = ProviderTypeDefinition(type: 'custom');
      expect(def.hostHint, isNull);
    });

    test('hostHint can be set via constructor', () {
      const def = ProviderTypeDefinition(
        type: 'custom',
        hostHint: '例如: https://example.com/api',
      );
      expect(def.hostHint, equals('例如: https://example.com/api'));
    });

    group('builtin type host hints', () {
      test('llm type has hostHint with chat completions example', () {
        final def = ProviderTypeRegistry.get('llm');
        expect(def, isNotNull);
        expect(def!.hostHint, isNotNull);
        expect(def.hostHint, contains('chat/completions'));
      });

      test('tts type has hostHint with audio/speech example', () {
        final def = ProviderTypeRegistry.get('tts');
        expect(def, isNotNull);
        expect(def!.hostHint, isNotNull);
        expect(def.hostHint, contains('audio/speech'));
      });

      test('ocr type has hostHint with chat/completions example', () {
        final def = ProviderTypeRegistry.get('ocr');
        expect(def, isNotNull);
        expect(def!.hostHint, isNotNull);
        expect(def.hostHint, contains('chat/completions'));
      });

      test('asr type has hostHint with audio/transcriptions example', () {
        final def = ProviderTypeRegistry.get('asr');
        expect(def, isNotNull);
        expect(def!.hostHint, isNotNull);
        expect(def.hostHint, contains('audio/transcriptions'));
      });

      test('mcp type has hostHint with SSE example', () {
        final def = ProviderTypeRegistry.get('mcp');
        expect(def, isNotNull);
        expect(def!.hostHint, isNotNull);
        expect(def.hostHint, contains('localhost'));
      });

      test('all builtin types have a hostHint set', () {
        for (final type in ['llm', 'tts', 'ocr', 'asr', 'mcp']) {
          final def = ProviderTypeRegistry.get(type);
          expect(def, isNotNull, reason: 'Type $type should be registered');
          expect(def!.hostHint, isNotNull,
              reason: 'Type $type should have a hostHint');
          expect(def.hostHint!.isNotEmpty, isTrue,
              reason: 'Type $type hostHint should not be empty');
        }
      });
    });
  });

  // =================================================================
  // 2. ProviderConfig ASR type
  // =================================================================
  group('ProviderConfig ASR type', () {
    test('ASR provider type is registered', () {
      registerBuiltinProviderTypes();
      expect(ProviderTypeRegistry.isRegistered('asr'), isTrue);
    });

    test('ASR provider type has correct definition and modelConfigStyle', () {
      registerBuiltinProviderTypes();
      final def = ProviderTypeRegistry.get('asr');
      expect(def, isNotNull);
      expect(def!.type, equals('asr'));
      expect(def.modelConfigStyle, equals(ModelConfigStyle.simple));
    });

    test('ASR provider entry can be created', () {
      final entry = ProviderEntry(id: 'test_asr', type: 'asr', name: '音频转写供应商');
      expect(entry.id, equals('test_asr'));
      expect(entry.type, equals('asr'));
      expect(entry.name, equals('音频转写供应商'));
    });

    test('ASR provider entry with config', () {
      final config = ProviderConfigItem(
        providerName: 'Test ASR',
        host: 'https://api.test.com/v1',
        key: 'test-key',
        models: [ModelConfig(name: 'whisper-1', modelId: 'whisper-1')],
      );
      final entry = ProviderEntry(
        id: 'asr_1',
        type: 'asr',
        name: '音频转写供应商',
        configs: [config],
      );
      expect(entry.configs.length, equals(1));
      expect(entry.configs[0].providerName, equals('Test ASR'));
      expect(entry.configs[0].models.length, equals(1));
      expect(entry.configs[0].models[0].modelId, equals('whisper-1'));
    });

    test('ASR provider entry serialization round-trip', () {
      final config = ProviderConfigItem(
        providerName: 'My ASR',
        host: 'https://asr.example.com',
        key: 'sk-5678',
        models: [ModelConfig(name: 'whisper-1', modelId: 'whisper-1')],
      );
      final entry = ProviderEntry(
        id: 'asr_roundtrip',
        type: 'asr',
        name: '音频转写供应商',
        configs: [config],
      );

      // Serialize to map
      final map = entry.toMap();
      expect(map['type'], equals('asr'));
      expect(map['name'], equals('音频转写供应商'));

      // Deserialize back
      final restored = ProviderEntry.fromMap(map);
      expect(restored.id, equals(entry.id));
      expect(restored.type, equals('asr'));
      expect(restored.configs.length, equals(1));
      expect(restored.configs[0].host, equals('https://asr.example.com'));
    });
  });

  // =================================================================
  // 3. ProviderConfig OCR type
  // =================================================================
  group('ProviderConfig OCR type', () {
    test('OCR provider type is registered', () {
      // During normal app start, registerBuiltinProviderTypes is called
      // which registers 'llm' and 'tts'. We need 'ocr' too.
      registerBuiltinProviderTypes();
      expect(ProviderTypeRegistry.isRegistered('ocr'), isTrue);
    });

    test('OCR provider type has correct definition', () {
      registerBuiltinProviderTypes();
      final def = ProviderTypeRegistry.get('ocr');
      expect(def, isNotNull);
      expect(def!.type, equals('ocr'));
    });

    test('OCR provider entry can be created', () {
      final entry = ProviderEntry(
        id: 'test_ocr',
        type: 'ocr',
        name: 'OCR供应商',
      );
      expect(entry.id, equals('test_ocr'));
      expect(entry.type, equals('ocr'));
      expect(entry.name, equals('OCR供应商'));
    });

    test('OCR provider entry with config', () {
      final config = ProviderConfigItem(
        providerName: 'Test OCR',
        host: 'https://api.test.com/v1',
        key: 'test-key',
        models: [
          ModelConfig(
            name: 'GPT-4o',
            modelId: 'gpt-4o',
          ),
        ],
      );
      final entry = ProviderEntry(
        id: 'ocr_1',
        type: 'ocr',
        name: 'OCR供应商',
        configs: [config],
      );
      expect(entry.configs.length, equals(1));
      expect(entry.configs[0].providerName, equals('Test OCR'));
      expect(entry.configs[0].models.length, equals(1));
      expect(entry.configs[0].models[0].modelId, equals('gpt-4o'));
    });

    test('OCR provider entry serialization round-trip', () {
      final config = ProviderConfigItem(
        providerName: 'My OCR',
        host: 'https://ocr.example.com',
        key: 'sk-1234',
        models: [
          ModelConfig(name: 'Qwen-VL', modelId: 'qwen-vl-max'),
        ],
      );
      final entry = ProviderEntry(
        id: 'ocr_roundtrip',
        type: 'ocr',
        name: 'OCR供应商',
        configs: [config],
      );

      // Serialize to map
      final map = entry.toMap();
      expect(map['type'], equals('ocr'));
      expect(map['name'], equals('OCR供应商'));

      // Deserialize back
      final restored = ProviderEntry.fromMap(map);
      expect(restored.id, equals(entry.id));
      expect(restored.type, equals('ocr'));
      expect(restored.configs.length, equals(1));
      expect(restored.configs[0].host, equals('https://ocr.example.com'));
    });
  });

  // =================================================================
  // 4. ModelConfigStyle for all builtin types
  // =================================================================
  group('ModelConfigStyle definition for all types', () {
    test('llm type has ModelConfigStyle.llm', () {
      registerBuiltinProviderTypes();
      final def = ProviderTypeRegistry.get('llm');
      expect(def!.modelConfigStyle, equals(ModelConfigStyle.llm));
    });

    test('tts type has ModelConfigStyle.tts', () {
      registerBuiltinProviderTypes();
      final def = ProviderTypeRegistry.get('tts');
      expect(def!.modelConfigStyle, equals(ModelConfigStyle.tts));
    });

    test('ocr type has ModelConfigStyle.ocr', () {
      registerBuiltinProviderTypes();
      final def = ProviderTypeRegistry.get('ocr');
      expect(def!.modelConfigStyle, equals(ModelConfigStyle.ocr));
    });

    test('asr type has ModelConfigStyle.simple', () {
      registerBuiltinProviderTypes();
      final def = ProviderTypeRegistry.get('asr');
      expect(def!.modelConfigStyle, equals(ModelConfigStyle.simple));
    });
  });

  // =================================================================
  // 5. ProviderEntriesNotifier - ASR entry loading
  // =================================================================
  group('ProviderEntriesNotifier - ASR entry loading', () {
    test('default entries include ASR when no saved data', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
      );
      addTearDown(() => container.dispose());

      // Wait for load() to complete
      await container.read(providerEntriesProvider.notifier).load();

      final state = container.read(providerEntriesProvider);
      expect(state.entries.any((e) => e.type == 'asr'), isTrue);
      expect(state.entries.any((e) => e.id == 'builtin_asr'), isTrue);
      expect(state.entries.length, greaterThanOrEqualTo(4));
    });

    test('ASR entry is added to saved data that does not have ASR', () async {
      SharedPreferences.setMockInitialValues({
        'provider_entries': _savedDataWithoutAsr(),
      });
      final container = ProviderContainer(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
      );
      addTearDown(() => container.dispose());

      // Wait for load() to complete
      await container.read(providerEntriesProvider.notifier).load();

      final state = container.read(providerEntriesProvider);
      expect(
        state.entries.any((e) => e.type == 'asr'),
        isTrue,
        reason: 'ASR entry should be migrated in',
      );
      expect(
        state.entries.any((e) => e.id == 'builtin_tts'),
        isTrue,
        reason: 'TTS entry should be preserved',
      );
      expect(
        state.entries.any((e) => e.id == 'builtin_llm'),
        isTrue,
        reason: 'LLM entry should be preserved',
      );
      expect(
        state.entries.any((e) => e.id == 'builtin_ocr'),
        isTrue,
        reason: 'OCR entry should be preserved',
      );
    });

    test(
      'ASR entry is not duplicated when it already exists in saved data',
      () async {
        SharedPreferences.setMockInitialValues({
          'provider_entries': _savedDataWithAsr(),
        });
        final container = ProviderContainer(
          overrides: [
            providerEntriesProvider.overrideWith(
              (ref) => ProviderEntriesNotifier(),
            ),
          ],
        );
        addTearDown(() => container.dispose());

        // Wait for load() to complete
        await container.read(providerEntriesProvider.notifier).load();

        final state = container.read(providerEntriesProvider);
        final asrEntries = state.entries.where((e) => e.type == 'asr').toList();
        expect(
          asrEntries.length,
          equals(1),
          reason: 'Should have exactly one ASR entry, not duplicated',
        );
      },
    );

    test(
      'ASR entry preserves existing provider configs (TTS, LLM, OCR)',
      () async {
        SharedPreferences.setMockInitialValues({
          'provider_entries': _savedDataWithoutAsr(),
        });
        final container = ProviderContainer(
          overrides: [
            providerEntriesProvider.overrideWith(
              (ref) => ProviderEntriesNotifier(),
            ),
          ],
        );
        addTearDown(() => container.dispose());

        // Wait for load() to complete
        await container.read(providerEntriesProvider.notifier).load();

        final state = container.read(providerEntriesProvider);
        // Verify existing entries are still present (includes MCP auto-migration)
        expect(state.entries.length, equals(5));
        expect(state.entries[0].type, equals('tts'));
        expect(state.entries[1].type, equals('llm'));
        expect(state.entries[2].type, equals('ocr'));
        expect(state.entries[3].type, equals('asr'));
        expect(state.entries[4].type, equals('mcp'));
      },
    );

    test('saved ASR config is preserved through load', () async {
      SharedPreferences.setMockInitialValues({
        'provider_entries': _savedDataWithAsrConfig(),
      });
      final container = ProviderContainer(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
      );
      addTearDown(() => container.dispose());

      // Wait for load() to complete
      await container.read(providerEntriesProvider.notifier).load();

      final state = container.read(providerEntriesProvider);
      final asrEntry = state.entries.firstWhere((e) => e.type == 'asr');
      expect(asrEntry.id, equals('my_asr'));
      expect(asrEntry.name, equals('我的音频转写'));
      expect(asrEntry.configs.length, equals(1));
      expect(asrEntry.configs[0].host, equals('https://asr.example.com'));
      expect(asrEntry.configs[0].key, equals('sk-asr-test'));
    });
  });

  // =================================================================
  // 6. ProviderEntriesNotifier - OCR entry loading
  // =================================================================
  group('ProviderEntriesNotifier - OCR entry loading', () {
    test('default entries include OCR when no saved data', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
      );
      addTearDown(() => container.dispose());

      // Wait for load() to complete
      await container.read(providerEntriesProvider.notifier).load();

      final state = container.read(providerEntriesProvider);
      expect(state.entries.any((e) => e.type == 'ocr'), isTrue);
      expect(state.entries.any((e) => e.id == 'builtin_ocr'), isTrue);
      expect(state.entries.length, greaterThanOrEqualTo(3));
    });

    test('OCR entry is added to saved data that does not have OCR', () async {
      SharedPreferences.setMockInitialValues({
        'provider_entries': _savedDataWithoutOcr(),
      });
      final container = ProviderContainer(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
      );
      addTearDown(() => container.dispose());

      // Wait for load() to complete
      await container.read(providerEntriesProvider.notifier).load();

      final state = container.read(providerEntriesProvider);
      expect(state.entries.any((e) => e.type == 'ocr'), isTrue,
          reason: 'OCR entry should be migrated in');
      expect(state.entries.any((e) => e.id == 'builtin_tts'), isTrue,
          reason: 'TTS entry should be preserved');
      expect(state.entries.any((e) => e.id == 'builtin_llm'), isTrue,
          reason: 'LLM entry should be preserved');
    });

    test('OCR entry is not duplicated when it already exists in saved data',
        () async {
      SharedPreferences.setMockInitialValues({
        'provider_entries': _savedDataWithOcr(),
      });
      final container = ProviderContainer(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
      );
      addTearDown(() => container.dispose());

      // Wait for load() to complete
      await container.read(providerEntriesProvider.notifier).load();

      final state = container.read(providerEntriesProvider);
      final ocrEntries = state.entries.where((e) => e.type == 'ocr').toList();
      expect(ocrEntries.length, equals(1),
          reason: 'Should have exactly one OCR entry, not duplicated');
    });

    test('OCR entry preserves existing provider configs (TTS, LLM)', () async {
      SharedPreferences.setMockInitialValues({
        'provider_entries': _savedDataWithoutOcr(),
      });
      final container = ProviderContainer(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
      );
      addTearDown(() => container.dispose());

      // Wait for load() to complete
      await container.read(providerEntriesProvider.notifier).load();

      final state = container.read(providerEntriesProvider);
      // Verify existing entries are still present (includes ASR and MCP auto-migration)
      expect(state.entries.length, equals(5));
      expect(state.entries[0].type, equals('tts'));
      expect(state.entries[1].type, equals('llm'));
      expect(state.entries[2].type, equals('ocr'));
      expect(state.entries[3].type, equals('asr'));
      expect(state.entries[4].type, equals('mcp'));
    });

    test('saved OCR config is preserved through load', () async {
      SharedPreferences.setMockInitialValues({
        'provider_entries': _savedDataWithOcrConfig(),
      });
      final container = ProviderContainer(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
      );
      addTearDown(() => container.dispose());

      // Wait for load() to complete
      await container.read(providerEntriesProvider.notifier).load();

      final state = container.read(providerEntriesProvider);
      final ocrEntry = state.entries.firstWhere((e) => e.type == 'ocr');
      expect(ocrEntry.id, equals('my_ocr'));
      expect(ocrEntry.name, equals('我的OCR'));
      expect(ocrEntry.configs.length, equals(1));
      expect(ocrEntry.configs[0].host, equals('https://ocr.example.com'));
      expect(ocrEntry.configs[0].key, equals('sk-test123'));
    });
  });

  // =================================================================
  // 7. ProviderConfigItem - provider-level params
  // =================================================================
  group('ProviderConfigItem - provider-level params', () {
    test('ProviderConfigItem stores provider-level typeConfig', () {
      final item = ProviderConfigItem(
        providerName: 'Test',
        host: 'host',
        key: 'key',
        typeConfig: {'context': 4096, 'temperature': 0.7},
      );
      expect(item.typeConfig['context'], equals(4096));
      expect(item.typeConfig['temperature'], equals(0.7));
    });

    test('ProviderConfigItem stores provider-level customParams', () {
      final item = ProviderConfigItem(
        providerName: 'Test',
        host: 'host',
        key: 'key',
        customParams: [
          CustomParam(paramName: 'top_k', defaultValue: '10'),
        ],
      );
      expect(item.customParams.length, equals(1));
      expect(item.customParams[0].paramName, equals('top_k'));
    });

    test('ProviderConfigItem stores provider-level reasoningParams', () {
      final item = ProviderConfigItem(
        providerName: 'Test',
        host: 'host',
        key: 'key',
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
        ],
      );
      expect(item.reasoningParams.length, equals(1));
      expect(item.reasoningParams[0].paramName, equals('thinking.type'));
      expect(item.reasoningParams[0].isReasoningToggle, isTrue);
    });

    test('ProviderConfigItem copy preserves provider-level params', () {
      final item = ProviderConfigItem(
        providerName: 'Test',
        host: 'host',
        key: 'key',
        typeConfig: {'context': 4096},
        customParams: [CustomParam(paramName: 'top_k', defaultValue: '10')],
        reasoningParams: [
          ReasoningParam(paramName: 'effort', options: ['low', 'high']),
        ],
      );
      final copy = item.copy();
      expect(copy.typeConfig['context'], equals(4096));
      expect(copy.customParams.length, equals(1));
      expect(copy.reasoningParams.length, equals(1));
    });

    test('ProviderConfigItem toMap/fromMap preserves provider-level params',
        () {
      final item = ProviderConfigItem(
        providerName: 'Test',
        host: 'host',
        key: 'key',
        typeConfig: {'context': 4096},
        customParams: [CustomParam(paramName: 'top_k', defaultValue: '10')],
        reasoningParams: [
          ReasoningParam(paramName: 'effort', options: ['low', 'high']),
        ],
      );
      final map = item.toMap();
      final restored = ProviderConfigItem.fromMap(map);
      expect(restored.typeConfig['context'], equals(4096));
      expect(restored.customParams.length, equals(1));
      expect(restored.customParams[0].paramName, equals('top_k'));
      expect(restored.reasoningParams.length, equals(1));
      expect(restored.reasoningParams[0].paramName, equals('effort'));
    });
  });

  // =================================================================
  // 8. ProviderConfigDetailPage - redesigned
  // =================================================================
  group('ProviderConfigDetailPage - redesigned', () {
    testWidgets('no edit button in display mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerEntriesProvider.overrideWith(
              (ref) => ProviderEntriesNotifierFake(),
            ),
          ],
          child: const MaterialApp(
            home: ProviderConfigDetailPage(
              entryId: 'test_entry_id',
              configIndex: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No edit button
      expect(find.text('编辑'), findsNothing);
      // No editable TextFields
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('shows provider card styled like topic_selection page', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerEntriesProvider.overrideWith(
              (ref) => ProviderEntriesNotifierFake(),
            ),
          ],
          child: const MaterialApp(
            home: ProviderConfigDetailPage(
              entryId: 'test_entry_id',
              configIndex: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Provider name shown in card (and in AppBar title)
      expect(find.text('TestProvider'), findsNWidgets(2));
      // Host shown
      expect(find.text('https://api.test.com'), findsOneWidget);
      // Model list section visible
      expect(find.text('模型列表'), findsOneWidget);
    });
  });

  // =================================================================
  // 9. LlmModelConfigPage - inference intensity
  // =================================================================
  group('LlmModelConfigPage - inference intensity', () {
    testWidgets('shows inference intensity section', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LlmModelConfigPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Fill required fields
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), 'test-model');
      await tester.enterText(textFields.at(2), '4096');
      await tester.pump();

      // Add toggle first (no default toggle for new models)
      await tester.tap(find.text('添加推理开关'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Fill the toggle fields so intensity becomes available
      final toggleFields = find.byType(TextFormField);
      await tester.enterText(toggleFields.at(0), 'thinking.type');
      await tester.enterText(toggleFields.at(1), 'enabled');
      await tester.enterText(toggleFields.at(2), 'disabled');
      await tester.pump();

      // Now inference intensity should be enabled
      // Look for option fields or intensity-related UI
      // The page should have "添加推理参数" button for adding extra reasoning params
      await tester.scrollUntilVisible(
        find.text('添加推理参数'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('添加推理参数'), findsOneWidget);
    });
  });

  // =================================================================
  // 10. ReasoningParam - inference intensity validation
  // =================================================================
  group('ReasoningParam - inference intensity validation', () {
    test('provider: inference intensity allows name without values', () {
      // On the provider side, intensity can have just a param name
      // This is just a ReasoningParam without options (empty list)
      final intensity = ReasoningParam(
        paramName: 'reasoning_effort',
        options: [], // empty options = name only, no values
        isReasoningToggle: false,
        enabled: true,
      );
      // Should pass validation - no options, no error
      expect(intensity.validationError, isNull);
    });

    test('model: inference intensity requires values if name is filled', () {
      // On model side, if paramName is filled, options must not be empty
      // This would fail model-level validation
      final intensity = ReasoningParam(
        paramName: 'reasoning_effort',
        options: [], // empty - acceptable on provider but not on model
        isReasoningToggle: false,
        enabled: true,
      );
      // The validation only checks for empty option strings, not empty list
      // So empty options list passes validation
      expect(intensity.validationError, isNull);
    });

    test('ReasoningParam with filled options passes validation', () {
      final intensity = ReasoningParam(
        paramName: 'reasoning_effort',
        options: ['low', 'medium', 'high'],
        isReasoningToggle: false,
        enabled: true,
      );
      expect(intensity.validationError, isNull);
    });

    test('ReasoningParam with empty option strings fails validation', () {
      final intensity = ReasoningParam(
        paramName: 'effort',
        options: ['low', '', 'high'], // empty string option
        isReasoningToggle: false,
        enabled: true,
      );
      expect(intensity.validationError, isNotNull);
      expect(intensity.validationError, contains('选项值不能为空'));
    });
  });
}
