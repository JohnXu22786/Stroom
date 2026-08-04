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
  });

  group('DataMigrationOldConfigs.migrateOldChatConfigs', () {
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

    test('migrates per-model context/maxTokens into typeConfig', () async {
      // 回归：旧数据把压缩阈值挂在 model 上，不迁移则自动压缩静默失效。
      SharedPreferences.setMockInitialValues({
        'chat_configs': jsonEncode([
          {
            'providerName': 'Old',
            'host': '',
            'key': '',
            'models': [
              {'modelId': 'm1', 'maxTokens': 4000, 'temperature': 0.5},
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
    });
  });
}
