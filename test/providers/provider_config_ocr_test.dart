import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/provider_config.dart';

/// 构建只包含 TTS 和 LLM 的已保存数据（模拟旧版本用户升级）
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

/// 构建包含 TTS、LLM 和 OCR 的已保存数据
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

/// 构建包含 TTS、LLM 和 OCR（含配置）的已保存数据
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
            {'name': 'Qwen-VL', 'modelId': 'qwen-vl-max', 'voices': <Map<String, dynamic>>[], 'customParams': <Map<String, dynamic>>[], 'typeConfig': <String, dynamic>{}}
          ],
        },
      ],
    },
  ];
  return jsonEncode(entries);
}

void main() {
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
      // Verify existing entries are still present
      expect(state.entries.length, equals(3));
      expect(state.entries[0].type, equals('tts'));
      expect(state.entries[1].type, equals('llm'));
      expect(state.entries[2].type, equals('ocr'));
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
}
