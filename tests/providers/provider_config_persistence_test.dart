import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ProviderEntriesNotifier.load - corrupt data handling', () {
    test(
        'non-array provider_entries is quarantined before migration '
        'overwrite', () async {
      // 回归：chat_configs 存在时 _migrateOldChatConfigs 会重写
      // provider_entries —— 现有数据损坏（非数组）必须先隔离再覆盖，
      // 否则损坏现场被永久销毁（备份恢复都救不回来）。
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

      final notifier = ProviderEntriesNotifier();
      await notifier.load();

      final prefs = await SharedPreferences.getInstance();
      final corruptKeys = prefs
          .getKeys()
          .where((k) => k.startsWith('provider_entries_corrupt_'))
          .toList();
      expect(corruptKeys, isNotEmpty, reason: '覆盖前必须隔离原始损坏数据');
      expect(
        corruptKeys.any((k) => prefs.getString(k) == '{"not": "an array"}'),
        isTrue,
      );
      // 迁移后的 llm 条目被加载进状态。
      expect(
        notifier.state.entries.any((e) => e.id == 'migrated_llm'),
        isTrue,
      );
    });

    test('unparseable provider_entries is quarantined and defaults loaded',
        () async {
      SharedPreferences.setMockInitialValues({
        'provider_entries': 'not-json{{{',
      });

      final notifier = ProviderEntriesNotifier();
      await notifier.load();

      final prefs = await SharedPreferences.getInstance();
      final corruptKeys = prefs
          .getKeys()
          .where((k) => k.startsWith('provider_entries_corrupt_'))
          .toList();
      expect(corruptKeys, isNotEmpty);
      expect(
        corruptKeys.any((k) => prefs.getString(k) == 'not-json{{{'),
        isTrue,
        reason: '原始损坏数据必须保留（含 API key 的配置不可恢复地丢失）',
      );
      // 回退默认预置，应用仍可正常使用。
      expect(notifier.state.entries, isNotEmpty);
    });
  });
}
