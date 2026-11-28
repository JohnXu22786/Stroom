import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/data_migration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DataMigrationOldConfigs.fixNullIdsInProviderEntries', () {
    test('non-array provider_entries is quarantined and reset to empty list',
        () async {
      // 顶层损坏：`as List` 强转会中断修复；必须隔离原始数据并重置，
      // 否则 ProviderEntry 解析持续闪退。
      SharedPreferences.setMockInitialValues({
        'provider_entries': '{"not": "an array"}',
      });
      final prefs = await SharedPreferences.getInstance();

      await DataMigrationOldConfigs.fixNullIdsInProviderEntries(prefs);

      expect(prefs.getString('provider_entries'), '[]');
      final corruptKeys = prefs
          .getKeys()
          .where((k) => k.startsWith('provider_entries_corrupt_'))
          .toList();
      expect(corruptKeys, isNotEmpty);
      expect(
        corruptKeys.any((k) => prefs.getString(k) == '{"not": "an array"}'),
        isTrue,
      );
    });

    test('fixes null/empty ids and types without crashing on bad field types',
        () async {
      // 字段值类型损坏（id 为 int）：`as String?` 强转会中断整个修复。
      SharedPreferences.setMockInitialValues({
        'provider_entries': jsonEncode([
          {'id': 123, 'type': null, 'name': 'Bad', 'configs': []},
          {'id': '', 'type': 'llm', 'name': 'Empty', 'configs': []},
          {'id': 'ok', 'type': 'tts', 'name': 'OK', 'configs': []},
        ]),
      });
      final prefs = await SharedPreferences.getInstance();

      await DataMigrationOldConfigs.fixNullIdsInProviderEntries(prefs);

      final entries = jsonDecode(prefs.getString('provider_entries')!) as List;
      expect(entries, hasLength(3));
      // 两条损坏条目都被修复（id 非空、type 非空），没有中断。
      for (final e in entries) {
        final m = e as Map<String, dynamic>;
        expect(m['id'], isA<String>());
        expect(m['id'], isNotEmpty);
        expect(m['type'], isA<String>());
        expect(m['type'], isNotEmpty);
      }
    });

    test('persists provider cleanup when malformed entries are filtered',
        () async {
      final validEntry = {'id': 'kept', 'type': 'tts'};
      SharedPreferences.setMockInitialValues({
        'provider_entries': jsonEncode([null, validEntry]),
      });
      final prefs = await SharedPreferences.getInstance();

      await DataMigrationOldConfigs.fixNullIdsInProviderEntries(prefs);

      expect(
        jsonDecode(prefs.getString('provider_entries')!),
        [validEntry],
      );
    });
  });

  group('DataMigrationOldConfigs.migrateOldChatConfigs', () {
    test('quarantines malformed mixed entries before migrating valid configs',
        () async {
      final legacyConfigs = [
        {
          'providerName': 'Recoverable provider',
          'host': 'https://legacy.example.com',
          'key': 'legacy-key',
          'models': [
            {'modelId': 'legacy-model'},
          ],
        },
        null,
        'malformed entry',
      ];
      final rawLegacyConfigs = jsonEncode(legacyConfigs);
      SharedPreferences.setMockInitialValues({
        'chat_configs': rawLegacyConfigs,
        'chat_selected_config_id': 'legacy-selection',
      });
      final prefs = await SharedPreferences.getInstance();

      await DataMigrationOldConfigs.migrateOldChatConfigs(prefs);

      final quarantinedKeys = prefs
          .getKeys()
          .where((key) => key.startsWith('chat_configs_corrupt_'))
          .toList();
      expect(quarantinedKeys, hasLength(1));
      expect(prefs.getString(quarantinedKeys.single), rawLegacyConfigs);
      final entries = jsonDecode(prefs.getString('provider_entries')!) as List;
      final migratedConfig =
          ((entries.single as Map<String, dynamic>)['configs'] as List).single
              as Map<String, dynamic>;
      expect(migratedConfig['providerName'], 'Recoverable provider');
      expect(prefs.getString('chat_configs'), isNull);
      expect(prefs.getString('chat_selected_config_id'), isNull);
    });

    test('valid legacy config migration does not create a corruption backup',
        () async {
      SharedPreferences.setMockInitialValues({
        'chat_configs': jsonEncode([
          {
            'providerName': 'Valid provider',
            'host': 'https://legacy.example.com',
            'key': 'legacy-key',
            'models': [
              {'modelId': 'legacy-model'},
            ],
          },
        ]),
      });
      final prefs = await SharedPreferences.getInstance();

      await DataMigrationOldConfigs.migrateOldChatConfigs(prefs);

      expect(
        prefs.getKeys().where((key) => key.startsWith('chat_configs_corrupt_')),
        isEmpty,
      );
      final entries = jsonDecode(prefs.getString('provider_entries')!) as List;
      final migratedConfig =
          ((entries.single as Map<String, dynamic>)['configs'] as List).single
              as Map<String, dynamic>;
      expect(migratedConfig['providerName'], 'Valid provider');
      expect(prefs.getString('chat_configs'), isNull);
    });

    test('non-array chat_configs is dropped without crashing', () async {
      SharedPreferences.setMockInitialValues({
        'chat_configs': '{"not": "an array"}',
        'chat_selected_config_id': 'x',
      });
      final prefs = await SharedPreferences.getInstance();

      await DataMigrationOldConfigs.migrateOldChatConfigs(prefs);

      expect(prefs.getString('chat_configs'), isNull,
          reason: '损坏的旧配置必须被清理，避免每次启动重复解析');
      expect(prefs.getString('chat_selected_config_id'), isNull);
    });

    test('corrupt existing provider_entries is quarantined before overwrite',
        () async {
      // 回归：chat_configs 存在时迁移会重写 provider_entries ——
      // 现有数据已损坏（非数组）时必须先隔离再覆盖。
      SharedPreferences.setMockInitialValues({
        'provider_entries': '{"not": "an array"}',
        'chat_configs': jsonEncode([
          {
            'providerName': 'Old',
            'host': '',
            'key': '',
            'models': [
              {'modelId': 'm1', 'temperature': 0.5},
            ],
          },
        ]),
      });
      final prefs = await SharedPreferences.getInstance();

      await DataMigrationOldConfigs.migrateOldChatConfigs(prefs);

      final corruptKeys = prefs
          .getKeys()
          .where((k) => k.startsWith('provider_entries_corrupt_'))
          .toList();
      expect(corruptKeys, isNotEmpty, reason: '覆盖前必须隔离原始损坏数据');
      expect(
        corruptKeys.any((k) => prefs.getString(k) == '{"not": "an array"}'),
        isTrue,
      );
      // 迁移结果正常写入。
      final entries = jsonDecode(prefs.getString('provider_entries')!) as List;
      expect(entries, isNotEmpty);
    });

    test('malformed non-built-in LLM entry does not discard legacy configs',
        () async {
      SharedPreferences.setMockInitialValues({
        'provider_entries': jsonEncode([
          {
            'id': 'corrupt_llm',
            'type': 'llm',
            'name': 'Corrupt LLM',
            'configs': [
              {
                'customParams': [
                  {
                    'paramName': 'legacy_param',
                    'options': [123]
                  },
                ],
              },
            ],
          },
        ]),
        'chat_configs': jsonEncode([
          {
            'providerName': 'Legacy provider',
            'host': 'https://legacy.example.com',
            'key': 'legacy-key',
            'models': [
              {'modelId': 'legacy-model', 'temperature': 0.5},
            ],
          },
        ]),
      });
      final prefs = await SharedPreferences.getInstance();

      await DataMigrationOldConfigs.migrateOldChatConfigs(prefs);

      final entries = jsonDecode(prefs.getString('provider_entries')!) as List;
      final migrated = entries
          .whereType<Map<String, dynamic>>()
          .firstWhere((entry) => entry['id'] == 'migrated_llm');
      final configs = migrated['configs'] as List;
      final provider = configs.single as Map<String, dynamic>;
      expect(provider['providerName'], 'Legacy provider');
      expect(provider['key'], 'legacy-key');
      expect(
        ((provider['models'] as List).single
            as Map<String, dynamic>)['modelId'],
        'legacy-model',
      );
      expect(prefs.getString('chat_configs'), isNull);
    });

    test('merges legacy model settings into a usable LLM entry', () async {
      final existingConfig = {
        'id': 'existing_config',
        'providerName': 'Legacy provider',
        'host': 'https://legacy.example.com',
        'key': 'legacy-key',
        'models': [
          {
            'modelId': 'legacy-model',
            'typeConfig': {
              'temperature': 0.2,
              'customSetting': 0.2,
            },
          },
        ],
      };
      Map<String, dynamic> legacyConfig(double temperature) => {
            'providerName': 'Legacy provider',
            'host': 'https://legacy.example.com',
            'key': 'legacy-key',
            'models': [
              {
                'modelId': 'legacy-model',
                'temperature': temperature,
                'typeConfig': {'customSetting': temperature},
              },
            ],
          };
      SharedPreferences.setMockInitialValues({
        'provider_entries': jsonEncode([
          {
            'id': 'existing_llm',
            'type': 'llm',
            'name': 'Custom LLM',
            'configs': [existingConfig],
          },
        ]),
        'chat_configs': jsonEncode([
          legacyConfig(0.2),
          legacyConfig(0.7),
          legacyConfig(0.7),
        ]),
      });
      final prefs = await SharedPreferences.getInstance();

      await DataMigrationOldConfigs.migrateOldChatConfigs(prefs);

      final entries = jsonDecode(prefs.getString('provider_entries')!) as List;
      final llmEntry = entries
          .whereType<Map<String, dynamic>>()
          .singleWhere((entry) => entry['id'] == 'existing_llm');
      final configs = llmEntry['configs'] as List;
      expect(configs, hasLength(3));
      final temperatures = configs.map((config) {
        final model = ((config as Map<String, dynamic>)['models'] as List)
            .single as Map<String, dynamic>;
        return (model['typeConfig'] as Map<String, dynamic>)['temperature'];
      });
      expect(temperatures, orderedEquals([0.2, 0.2, 0.7]));
      final customSettings = configs.map((config) {
        final model = ((config as Map<String, dynamic>)['models'] as List)
            .single as Map<String, dynamic>;
        return (model['typeConfig'] as Map<String, dynamic>)['customSetting'];
      });
      expect(customSettings, orderedEquals([0.2, 0.2, 0.7]));
      final supportStream = configs.map((config) {
        final model = ((config as Map<String, dynamic>)['models'] as List)
            .single as Map<String, dynamic>;
        return model['supportStream'] ?? false;
      });
      expect(supportStream, orderedEquals([false, true, true]));
      expect(prefs.getString('chat_configs'), isNull);
    });

    test('normalizes legacy top-level LLM model settings before merging',
        () async {
      SharedPreferences.setMockInitialValues({
        'provider_entries': jsonEncode([
          {
            'id': 'existing_llm',
            'type': 'llm',
            'name': 'Legacy LLM',
            'providerName': 'Legacy provider',
            'host': 'https://legacy.example.com',
            'key': 'legacy-key',
            'models': [
              {
                'modelId': 'legacy-model',
                'temperature': 0.2,
                'typeConfig': {'context': 4000},
              },
            ],
          },
        ]),
        'chat_configs': jsonEncode([
          {
            'providerName': 'Legacy provider',
            'host': 'https://legacy.example.com',
            'key': 'legacy-key',
            'models': [
              {'modelId': 'legacy-model', 'temperature': 0.2},
            ],
          },
          {
            'providerName': 'Legacy provider',
            'host': 'https://legacy.example.com',
            'key': 'legacy-key',
            'models': [
              {'modelId': 'legacy-model', 'temperature': 0.7},
            ],
          },
        ]),
      });
      final prefs = await SharedPreferences.getInstance();

      await DataMigrationOldConfigs.migrateOldChatConfigs(prefs);

      final entries = jsonDecode(prefs.getString('provider_entries')!) as List;
      final llmEntry = entries
          .whereType<Map<String, dynamic>>()
          .singleWhere((entry) => entry['id'] == 'existing_llm');
      final configs = llmEntry['configs'] as List;
      expect(configs, hasLength(3));
      final temperatures = configs.map((config) {
        final model = ((config as Map<String, dynamic>)['models'] as List)
            .single as Map<String, dynamic>;
        return (model['typeConfig'] as Map<String, dynamic>)['temperature'];
      });
      expect(temperatures, orderedEquals([0.2, 0.2, 0.7]));
      expect(
        ((configs.first as Map<String, dynamic>)['models'] as List)
            .single['typeConfig']['context'],
        4000,
      );
      expect(prefs.getString('chat_configs'), isNull);
    });

    test('migrates per-model context/maxTokens into typeConfig', () async {
      // 回归：旧数据把压缩阈值挂在 model 上，不迁移则自动压缩静默失效。
      SharedPreferences.setMockInitialValues({
        'chat_configs': jsonEncode([
          {
            'providerName': 'Old',
            'host': '',
            'key': '',
            'models': [
              {
                'modelId': 'm1',
                'maxTokens': 4000,
                'temperature': 0.5,
                'typeConfig': {'customSetting': 'carry-forward'},
              },
            ],
          },
        ]),
      });
      final prefs = await SharedPreferences.getInstance();

      await DataMigrationOldConfigs.migrateOldChatConfigs(prefs);

      final entries = jsonDecode(prefs.getString('provider_entries')!) as List;
      final migrated =
          (entries.first as Map<String, dynamic>)['configs'] as List;
      final models = (migrated.first as Map<String, dynamic>)['models'] as List;
      final typeConfig =
          (models.first as Map<String, dynamic>)['typeConfig'] as Map;
      expect(typeConfig['context'], 4000);
      expect(typeConfig['customSetting'], 'carry-forward');
    });
  });
}
