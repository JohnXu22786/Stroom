import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/provider_config.dart';

/// 构建只包含 TTS 和 LLM 的已保存数据（模拟旧版本用户升级，无 OCR 和 ASR）
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

/// 构建包含 TTS、LLM、OCR 和 ASR 的已保存数据
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
      'name': '语音识别供应商',
      'configs': <Map<String, dynamic>>[],
    },
  ];
  return jsonEncode(entries);
}

/// 构建包含 TTS、LLM、OCR 和 ASR（含配置）的已保存数据
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
      'name': '我的语音识别',
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
            }
          ],
        },
      ],
    },
  ];
  return jsonEncode(entries);
}

void main() {
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
      final entry = ProviderEntry(
        id: 'test_asr',
        type: 'asr',
        name: '语音识别供应商',
      );
      expect(entry.id, equals('test_asr'));
      expect(entry.type, equals('asr'));
      expect(entry.name, equals('语音识别供应商'));
    });

    test('ASR provider entry with config', () {
      final config = ProviderConfigItem(
        providerName: 'Test ASR',
        host: 'https://api.test.com/v1',
        key: 'test-key',
        models: [
          ModelConfig(
            name: 'whisper-1',
            modelId: 'whisper-1',
          ),
        ],
      );
      final entry = ProviderEntry(
        id: 'asr_1',
        type: 'asr',
        name: '语音识别供应商',
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
        models: [
          ModelConfig(name: 'whisper-1', modelId: 'whisper-1'),
        ],
      );
      final entry = ProviderEntry(
        id: 'asr_roundtrip',
        type: 'asr',
        name: '语音识别供应商',
        configs: [config],
      );

      // Serialize to map
      final map = entry.toMap();
      expect(map['type'], equals('asr'));
      expect(map['name'], equals('语音识别供应商'));

      // Deserialize back
      final restored = ProviderEntry.fromMap(map);
      expect(restored.id, equals(entry.id));
      expect(restored.type, equals('asr'));
      expect(restored.configs.length, equals(1));
      expect(restored.configs[0].host, equals('https://asr.example.com'));
    });
  });

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
      expect(state.entries.any((e) => e.type == 'asr'), isTrue,
          reason: 'ASR entry should be migrated in');
      expect(state.entries.any((e) => e.id == 'builtin_tts'), isTrue,
          reason: 'TTS entry should be preserved');
      expect(state.entries.any((e) => e.id == 'builtin_llm'), isTrue,
          reason: 'LLM entry should be preserved');
      expect(state.entries.any((e) => e.id == 'builtin_ocr'), isTrue,
          reason: 'OCR entry should be preserved');
    });

    test('ASR entry is not duplicated when it already exists in saved data',
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
      expect(asrEntries.length, equals(1),
          reason: 'Should have exactly one ASR entry, not duplicated');
    });

    test('ASR entry preserves existing provider configs (TTS, LLM, OCR)',
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
    });

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
      expect(asrEntry.name, equals('我的语音识别'));
      expect(asrEntry.configs.length, equals(1));
      expect(asrEntry.configs[0].host, equals('https://asr.example.com'));
      expect(asrEntry.configs[0].key, equals('sk-asr-test'));
    });
  });

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

    test('ocr type has ModelConfigStyle.simple', () {
      registerBuiltinProviderTypes();
      final def = ProviderTypeRegistry.get('ocr');
      expect(def!.modelConfigStyle, equals(ModelConfigStyle.simple));
    });

    test('asr type has ModelConfigStyle.simple', () {
      registerBuiltinProviderTypes();
      final def = ProviderTypeRegistry.get('asr');
      expect(def!.modelConfigStyle, equals(ModelConfigStyle.simple));
    });
  });
}
