import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/providers/provider_preset_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:stroom/providers/provider_config.dart';

class _FailingProviderCorruptBackupStore
    extends InMemorySharedPreferencesStore {
  _FailingProviderCorruptBackupStore(
    Map<String, Object> data, {
    this.failedBackupCount,
  }) : super.withData(data);

  int? failedBackupCount;

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (key.startsWith('flutter.provider_entries_corrupt_')) {
      if (failedBackupCount == null || failedBackupCount! > 0) {
        failedBackupCount =
            failedBackupCount == null ? null : failedBackupCount! - 1;
        return Future<bool>.value(false);
      }
    }
    return super.setValue(valueType, key, value);
  }
}

class _ThrowingProviderCorruptBackupStore
    extends InMemorySharedPreferencesStore {
  _ThrowingProviderCorruptBackupStore(Map<String, Object> data)
      : super.withData(data);

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (key.startsWith('flutter.provider_entries_corrupt_')) {
      throw StateError('backup unavailable');
    }
    return super.setValue(valueType, key, value);
  }
}

class _FailingProviderEntriesStore extends InMemorySharedPreferencesStore {
  _FailingProviderEntriesStore(
    Map<String, Object> data, {
    this.failedKey = 'flutter.provider_entries',
    this.failedWriteCount = 0,
  }) : super.withData(data);

  final String failedKey;
  int failedWriteCount;

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (key == failedKey && failedWriteCount > 0) {
      failedWriteCount--;
      return Future<bool>.value(false);
    }
    return super.setValue(valueType, key, value);
  }
}

class _FailingProviderRollbackStore extends InMemorySharedPreferencesStore {
  _FailingProviderRollbackStore(Map<String, Object> data)
      : super.withData(data);

  bool isArmed = false;
  int providerEntriesWrites = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (isArmed && key == 'flutter.provider_entries') {
      providerEntriesWrites++;
      if (providerEntriesWrites == 2) return Future<bool>.value(false);
    }
    if (isArmed && key == 'flutter.mcp_provider_groups') {
      return Future<bool>.value(false);
    }
    return super.setValue(valueType, key, value);
  }
}

class _GatedProviderEntriesStore extends InMemorySharedPreferencesStore {
  _GatedProviderEntriesStore(Map<String, Object> data) : super.withData(data);

  final firstProviderEntriesWriteStarted = Completer<void>();
  final releaseFirstProviderEntriesWrite = Completer<void>();
  bool isArmed = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (isArmed &&
        key == 'flutter.provider_entries' &&
        !firstProviderEntriesWriteStarted.isCompleted) {
      firstProviderEntriesWriteStarted.complete();
      await releaseFirstProviderEntriesWrite.future;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ProviderEntriesNotifier.load - corrupt data handling', () {
    test('non-list legacy chat_configs are backed up before removal', () async {
      const legacyJson = '{"providerName":"Recover me","key":"secret"}';
      SharedPreferences.setMockInitialValues({'chat_configs': legacyJson});

      final notifier = ProviderEntriesNotifier();
      await notifier.load();

      final prefs = await SharedPreferences.getInstance();
      final backupKeys = prefs
          .getKeys()
          .where((key) => key.startsWith('provider_entries_corrupt_'))
          .toList();
      expect(backupKeys, hasLength(1));
      expect(prefs.getString(backupKeys.single), legacyJson);
      expect(prefs.getString('chat_configs'), isNull);
    });

    test('invalid-only legacy chat_configs are backed up before removal',
        () async {
      final legacyJson = jsonEncode(['invalid row', 42, null]);
      SharedPreferences.setMockInitialValues({'chat_configs': legacyJson});

      final notifier = ProviderEntriesNotifier();
      await notifier.load();

      final prefs = await SharedPreferences.getInstance();
      final backupKeys = prefs
          .getKeys()
          .where((key) => key.startsWith('provider_entries_corrupt_'))
          .toList();
      expect(backupKeys, hasLength(1));
      expect(prefs.getString(backupKeys.single), legacyJson);
      expect(prefs.getString('chat_configs'), isNull);
      expect(
        notifier.state.entries.any((entry) => entry.id == 'migrated_llm'),
        isFalse,
      );
    });

    test('legacy configs with invalid model rows are backed up before removal',
        () async {
      final legacyJson = jsonEncode([
        {
          'providerName': 'Legacy provider',
          'models': [
            'recover this model',
            {'modelId': 'migrated-model'},
          ],
        },
      ]);
      SharedPreferences.setMockInitialValues({'chat_configs': legacyJson});

      final notifier = ProviderEntriesNotifier();
      await notifier.load();

      final prefs = await SharedPreferences.getInstance();
      final backupKeys = prefs
          .getKeys()
          .where((key) => key.startsWith('provider_entries_corrupt_'))
          .toList();
      expect(backupKeys, hasLength(1));
      expect(prefs.getString(backupKeys.single), legacyJson);
      expect(prefs.getString('chat_configs'), isNull);
      final migrated = notifier.state.entries.singleWhere(
        (entry) => entry.id == 'migrated_llm',
      );
      expect(migrated.configs.single.models.single.modelId, 'migrated-model');
    });

    test(
        'legacy configs with invalid models values are backed up before removal',
        () async {
      final legacyJson = jsonEncode([
        {
          'providerName': 'Legacy provider',
          'models': 'recoverable model data',
        },
      ]);
      SharedPreferences.setMockInitialValues({'chat_configs': legacyJson});

      final notifier = ProviderEntriesNotifier();
      await notifier.load();

      final prefs = await SharedPreferences.getInstance();
      final backupKeys = prefs
          .getKeys()
          .where((key) => key.startsWith('provider_entries_corrupt_'))
          .toList();
      expect(backupKeys, hasLength(1));
      expect(prefs.getString(backupKeys.single), legacyJson);
      expect(prefs.getString('chat_configs'), isNull);
    });

    test('valid legacy chat_configs still migrate normally', () async {
      SharedPreferences.setMockInitialValues({
        'chat_configs': jsonEncode([
          {
            'providerName': 'Legacy provider',
            'host': 'https://legacy.example.com',
            'key': 'legacy-key',
            'models': [
              {'modelId': 'legacy-model'},
            ],
          },
        ]),
      });

      final notifier = ProviderEntriesNotifier();
      await notifier.load();

      final prefs = await SharedPreferences.getInstance();
      final migrated = notifier.state.entries.singleWhere(
        (entry) => entry.id == 'migrated_llm',
      );
      expect(migrated.configs.single.providerName, 'Legacy provider');
      expect(prefs.getString('chat_configs'), isNull);
      expect(
        prefs
            .getKeys()
            .where((key) => key.startsWith('provider_entries_corrupt_')),
        isEmpty,
      );
    });

    test('corrupt provider and legacy payloads keep separate backups',
        () async {
      const corruptProviderEntries = '{"provider":"recover me"}';
      final legacyJson = jsonEncode([
        {
          'providerName': 'Legacy provider',
          'models': 'recoverable model data',
        },
      ]);
      SharedPreferences.setMockInitialValues({
        'provider_entries': corruptProviderEntries,
        'chat_configs': legacyJson,
      });

      final notifier = ProviderEntriesNotifier();
      await notifier.load();

      final prefs = await SharedPreferences.getInstance();
      final backups = prefs
          .getKeys()
          .where((key) => key.startsWith('provider_entries_corrupt_'))
          .map((key) => prefs.getString(key))
          .toSet();
      expect(backups, containsAll([corruptProviderEntries, legacyJson]));
    });

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

    test('mixed valid and corrupt entries are backed up before persistence',
        () async {
      final original = jsonEncode([
        {
          'id': 'valid_llm',
          'type': 'llm',
          'name': 'LLM供应商',
          'configs': [],
        },
        {
          'id': 'corrupt_provider',
          'type': 'llm',
          'name': 'Corrupt provider',
          'configs': 'invalid configs',
          'apiKey': 'recover-me',
        },
      ]);
      SharedPreferences.setMockInitialValues({'provider_entries': original});

      final notifier = ProviderEntriesNotifier();
      await notifier.load();
      await notifier.addFirst(
        ProviderEntry(id: 'new_provider', type: 'llm', name: 'New provider'),
      );

      final prefs = await SharedPreferences.getInstance();
      final corruptKeys = prefs
          .getKeys()
          .where((key) => key.startsWith('provider_entries_corrupt_'))
          .toList();
      expect(corruptKeys, hasLength(1));
      expect(prefs.getString(corruptKeys.single), original);
      expect(
        (jsonDecode(prefs.getString('provider_entries')!) as List)
            .whereType<Map>()
            .any((entry) => entry['id'] == 'new_provider'),
        isTrue,
      );
    });

    test('legacy configs survive a malformed non-built-in LLM entry', () async {
      SharedPreferences.setMockInitialValues({
        'provider_entries': jsonEncode([
          {
            'id': 'corrupt_llm',
            'type': 'llm',
            'name': 'Corrupt LLM',
            'configs': 'invalid configs',
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

      final notifier = ProviderEntriesNotifier();
      await notifier.load();

      final migrated = notifier.state.entries
          .where((entry) => entry.id == 'migrated_llm')
          .toList();
      expect(migrated, hasLength(1));
      expect(migrated.single.configs, hasLength(1));
      expect(migrated.single.configs.single.providerName, 'Legacy provider');
      expect(migrated.single.configs.single.key, 'legacy-key');
      expect(
        migrated.single.configs.single.models.single.modelId,
        'legacy-model',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('chat_configs'), isNull);
      expect(
        prefs.getKeys().where(
              (key) => key.startsWith('provider_entries_corrupt_'),
            ),
        isNotEmpty,
        reason: 'the corrupt current entry should remain recoverable',
      );
    });

    test(
      'top-level corrupt provider entries and legacy settings survive failed backup',
      () async {
        const legacyChatConfigsJson = '[{"providerName":"Legacy provider",'
            '"host":"https://legacy.example.com","key":"legacy-key",'
            '"models":[{"modelId":"legacy-model"}]}]';
        const corruptProviderEntries = [
          '{"not":"an array"}',
          'not-json{{{',
        ];

        for (final originalProviderEntries in corruptProviderEntries) {
          SharedPreferences.setMockInitialValues({});
          final previousStore = SharedPreferencesStorePlatform.instance;
          SharedPreferencesStorePlatform.instance =
              _FailingProviderCorruptBackupStore({
            'flutter.provider_entries': originalProviderEntries,
            'flutter.chat_configs': legacyChatConfigsJson,
          });
          try {
            final notifier = ProviderEntriesNotifier();
            await notifier.load();

            final prefs = await SharedPreferences.getInstance();
            expect(
              prefs.getString('provider_entries'),
              originalProviderEntries,
              reason:
                  'A failed backup must not overwrite corrupt provider data',
            );
            expect(
              prefs.getString('chat_configs'),
              legacyChatConfigsJson,
              reason: 'Legacy provider data must remain available for recovery',
            );
          } finally {
            SharedPreferencesStorePlatform.instance = previousStore;
          }
        }
      },
    );

    test('CRUD does not overwrite corrupt entries when backup returns false',
        () async {
      final corruptProviderEntries = <String>[
        'not-json{{{',
        jsonEncode([
          {'id': 'corrupt_provider', 'type': 'llm', 'configs': 'invalid'},
        ]),
        jsonEncode([
          {'id': 'valid_llm', 'type': 'llm', 'name': 'LLM', 'configs': []},
          {
            'id': 'corrupt_provider',
            'type': 'llm',
            'name': 'Corrupt provider',
            'configs': 'invalid configs',
            'apiKey': 'recover-me',
          },
        ]),
      ];

      for (final original in corruptProviderEntries) {
        SharedPreferences.setMockInitialValues({});
        final previousStore = SharedPreferencesStorePlatform.instance;
        SharedPreferencesStorePlatform.instance =
            _FailingProviderCorruptBackupStore({
          'flutter.provider_entries': original,
        });
        try {
          final notifier = ProviderEntriesNotifier();
          await notifier.load();
          final loadedIds =
              notifier.state.entries.map((entry) => entry.id).toList();

          await expectLater(
            notifier.addFirst(
              ProviderEntry(id: 'new_provider', type: 'llm', name: 'New'),
            ),
            throwsA(isA<StateError>()),
          );

          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('provider_entries'), original);
          expect(
            notifier.state.entries.map((entry) => entry.id).toList(),
            loadedIds,
          );
        } finally {
          SharedPreferencesStorePlatform.instance = previousStore;
        }
      }
    });

    test('CRUD does not overwrite corrupt entries when backup throws',
        () async {
      const original = 'not-json{{{';
      SharedPreferences.setMockInitialValues({});
      final previousStore = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance =
          _ThrowingProviderCorruptBackupStore({
        'flutter.provider_entries': original,
      });
      try {
        final notifier = ProviderEntriesNotifier();
        await notifier.load();
        final loadedIds =
            notifier.state.entries.map((entry) => entry.id).toList();

        await expectLater(
          notifier.addFirst(
            ProviderEntry(id: 'new_provider', type: 'llm', name: 'New'),
          ),
          throwsA(isA<StateError>()),
        );

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('provider_entries'), original);
        expect(
          notifier.state.entries.map((entry) => entry.id).toList(),
          loadedIds,
        );
      } finally {
        SharedPreferencesStorePlatform.instance = previousStore;
      }
    });

    test('CRUD proceeds after a later corrupt backup succeeds', () async {
      const original = 'not-json{{{';
      SharedPreferences.setMockInitialValues({});
      final previousStore = SharedPreferencesStorePlatform.instance;
      final store = _FailingProviderCorruptBackupStore(
        {'flutter.provider_entries': original},
        failedBackupCount: 1,
      );
      SharedPreferencesStorePlatform.instance = store;
      try {
        final notifier = ProviderEntriesNotifier();
        await notifier.load();
        store.failedBackupCount = 0;

        await notifier.addFirst(
          ProviderEntry(id: 'new_provider', type: 'llm', name: 'New'),
        );

        final prefs = await SharedPreferences.getInstance();
        final backupKeys = prefs
            .getKeys()
            .where((key) => key.startsWith('provider_entries_corrupt_'))
            .toList();
        expect(
          backupKeys.any((key) => prefs.getString(key) == original),
          isTrue,
        );
        expect(
          (jsonDecode(prefs.getString('provider_entries')!) as List)
              .whereType<Map>()
              .any((entry) => entry['id'] == 'new_provider'),
          isTrue,
        );
        expect(
          notifier.state.entries.any((entry) => entry.id == 'new_provider'),
          isTrue,
        );
      } finally {
        SharedPreferencesStorePlatform.instance = previousStore;
      }
    });

    test('usable LLM entry does not suppress unmatched legacy configs',
        () async {
      final existingEntriesJson = jsonEncode([
        {
          'id': 'existing_llm',
          'type': 'llm',
          'name': 'Custom LLM',
          'providerName': 'Existing provider',
          'host': 'https://existing.example.com',
          'key': 'existing-key',
          'models': [
            {'modelId': 'existing-model'},
          ],
        },
        'corrupt entry',
      ]);
      SharedPreferences.setMockInitialValues({
        'provider_entries': existingEntriesJson,
        'chat_configs': jsonEncode([
          {
            'providerName': 'Legacy provider',
            'host': 'https://legacy.example.com',
            'key': 'legacy-key',
            'models': [
              {'modelId': 'legacy-model', 'supportStream': true},
            ],
          },
          {
            'providerName': 'Legacy provider',
            'host': 'https://legacy.example.com',
            'key': 'legacy-key',
            'models': [
              {'modelId': 'legacy-model', 'supportStream': true},
            ],
          },
        ]),
      });

      final notifier = ProviderEntriesNotifier();
      await notifier.load();

      final llmEntries =
          notifier.state.entries.where((entry) => entry.type == 'llm').toList();
      expect(llmEntries, hasLength(1));
      expect(llmEntries.single.id, 'existing_llm');
      expect(llmEntries.single.configs, hasLength(2));
      expect(
        llmEntries.single.configs.map((config) => config.providerName),
        containsAll(['Existing provider', 'Legacy provider']),
      );
      expect(
        llmEntries.single.configs.last.models.single.modelId,
        'legacy-model',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('chat_configs'), isNull);
      final corruptKeys = prefs
          .getKeys()
          .where((key) => key.startsWith('provider_entries_corrupt_'))
          .toList();
      expect(corruptKeys, hasLength(1));
      expect(prefs.getString(corruptKeys.single), existingEntriesJson);

      final backupFailureEntriesJson = jsonEncode([
        {
          'id': 'existing_llm',
          'type': 'llm',
          'name': 'Custom LLM',
          'configs': [
            {
              'id': 'existing_config',
              'providerName': 'Existing provider',
              'host': 'https://existing.example.com',
              'key': 'existing-key',
              'models': [
                {'modelId': 'existing-model'},
              ],
            },
          ],
        },
        {'id': 'existing_ocr', 'type': 'ocr', 'name': 'OCR', 'configs': []},
        {'id': 'existing_asr', 'type': 'asr', 'name': 'ASR', 'configs': []},
        'corrupt entry',
      ]);
      const legacyChatConfigsJson = '[{"providerName":"Legacy provider",'
          '"host":"https://legacy.example.com","key":"legacy-key",'
          '"models":[{"modelId":"legacy-model"}]}]';
      final failedBackupStoreData = <String, Object>{
        'flutter.provider_entries': backupFailureEntriesJson,
        'flutter.chat_configs': legacyChatConfigsJson,
      };
      SharedPreferences.setMockInitialValues({});
      final previousStore = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance =
          _FailingProviderCorruptBackupStore(failedBackupStoreData);
      try {
        final failureNotifier = ProviderEntriesNotifier();
        await failureNotifier.load();

        final failurePrefs = await SharedPreferences.getInstance();
        expect(failurePrefs.getString('chat_configs'), legacyChatConfigsJson);
      } finally {
        SharedPreferencesStorePlatform.instance = previousStore;
      }
    });

    test('legacy configs with distinct model settings are preserved once',
        () async {
      final representedConfig = {
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
            'configs': [representedConfig],
          },
        ]),
        'chat_configs': jsonEncode([
          legacyConfig(0.2),
          legacyConfig(0.7),
          legacyConfig(0.7),
        ]),
      });

      final notifier = ProviderEntriesNotifier();
      await notifier.load();

      final llmEntry = notifier.state.entries.singleWhere(
        (entry) => entry.id == 'existing_llm',
      );
      expect(llmEntry.configs, hasLength(3));
      expect(
        llmEntry.configs
            .map((config) => config.models.single.typeConfig['temperature']),
        orderedEquals([0.2, 0.2, 0.7]),
      );
      expect(
        llmEntry.configs
            .map((config) => config.models.single.typeConfig['customSetting']),
        orderedEquals([0.2, 0.2, 0.7]),
      );
      expect(
        llmEntry.configs.map((config) => config.models.single.supportStream),
        orderedEquals([false, true, true]),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('chat_configs'), isNull);
    });

    test('legacy LLM entries preserve represented model settings', () async {
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

      final notifier = ProviderEntriesNotifier();
      await notifier.load();

      final llmEntry = notifier.state.entries.singleWhere(
        (entry) => entry.id == 'existing_llm',
      );
      expect(llmEntry.configs, hasLength(3));
      expect(
        llmEntry.configs
            .map((config) => config.models.single.typeConfig['temperature']),
        orderedEquals([0.2, 0.2, 0.7]),
      );
      expect(
        llmEntry.configs.first.models.single.typeConfig['context'],
        4000,
      );
      expect(
        llmEntry.configs[1].models.single.typeConfig['context'],
        isNull,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('chat_configs'), isNull);
    });

    test('new migrated entry deduplicates identical legacy configs', () async {
      final legacyConfig = {
        'providerName': 'Legacy provider',
        'host': 'https://legacy.example.com',
        'key': 'legacy-key',
        'models': [
          {
            'modelId': 'legacy-model',
            'temperature': 0.7,
          },
        ],
      };
      SharedPreferences.setMockInitialValues({
        'chat_configs': jsonEncode([legacyConfig, legacyConfig]),
      });

      final notifier = ProviderEntriesNotifier();
      await notifier.load();

      final migrated = notifier.state.entries.singleWhere(
        (entry) => entry.id == 'migrated_llm',
      );
      expect(migrated.configs, hasLength(1));
      expect(
        migrated.configs.single.models.single.typeConfig['temperature'],
        0.7,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('chat_configs'), isNull);
    });

    test('represented legacy configs are not duplicated during migration',
        () async {
      final config = {
        'id': 'existing_config',
        'providerName': 'Legacy provider',
        'host': 'https://legacy.example.com',
        'key': 'legacy-key',
        'models': [
          {'modelId': 'legacy-model', 'supportStream': true},
        ],
      };
      SharedPreferences.setMockInitialValues({
        'provider_entries': jsonEncode([
          {
            'id': 'existing_llm',
            'type': 'llm',
            'name': 'Custom LLM',
            'configs': [config],
          },
        ]),
        'chat_configs': jsonEncode([
          {
            'providerName': 'Legacy provider',
            'host': 'https://legacy.example.com',
            'key': 'legacy-key',
            'models': [
              {'modelId': 'legacy-model', 'supportStream': true},
            ],
          },
        ]),
      });

      final notifier = ProviderEntriesNotifier();
      await notifier.load();

      final llmEntry = notifier.state.entries.singleWhere(
        (entry) => entry.id == 'existing_llm',
      );
      expect(llmEntry.configs, hasLength(1));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('chat_configs'), isNull);
    });
  });

  test('removing an MCP group rolls back when persistence fails', () async {
    const groupId = 'custom_group';
    final originalEntries = [
      ProviderEntry(
        id: 'mcp',
        type: 'mcp',
        name: 'MCP',
        configs: [ProviderConfigItem(id: 'server', groupId: groupId)],
      ),
      ProviderEntry(id: 'ocr', type: 'ocr', name: 'OCR'),
      ProviderEntry(id: 'asr', type: 'asr', name: 'ASR'),
    ];
    final originalGroups = [
      ...builtinMcpProviderGroups,
      const McpProviderGroup(id: groupId, name: 'Custom'),
    ];
    final initialEntries =
        jsonEncode(originalEntries.map((entry) => entry.toMap()).toList());
    final initialGroups =
        jsonEncode(originalGroups.map((group) => group.toMap()).toList());
    SharedPreferences.setMockInitialValues({
      'provider_entries': initialEntries,
      'mcp_provider_groups': initialGroups,
    });
    final previousStore = SharedPreferencesStorePlatform.instance;
    final store = _FailingProviderEntriesStore(
      {
        'flutter.provider_entries': initialEntries,
        'flutter.mcp_provider_groups': initialGroups,
      },
      failedKey: 'flutter.mcp_provider_groups',
    );
    SharedPreferencesStorePlatform.instance = store;
    try {
      final notifier = ProviderEntriesNotifier();
      await notifier.load();
      store.failedWriteCount = 1;
      final prefs = await SharedPreferences.getInstance();
      final savedEntriesBeforeRemoval = prefs.getString('provider_entries');
      final savedGroupsBeforeRemoval = prefs.getString('mcp_provider_groups');

      await expectLater(
        notifier.removeMcpGroup(groupId),
        throwsA(isA<StateError>()),
      );

      expect(
        notifier.state.mcpGroups.map((group) => group.id),
        contains(groupId),
      );
      expect(
        notifier.state.entries
            .singleWhere((entry) => entry.id == 'mcp')
            .configs
            .firstWhere((config) => config.id == 'server')
            .groupId,
        groupId,
      );
      expect(prefs.getString('provider_entries'), savedEntriesBeforeRemoval);
      expect(prefs.getString('mcp_provider_groups'), savedGroupsBeforeRemoval);
      await prefs.reload();
      expect(prefs.getString('provider_entries'), savedEntriesBeforeRemoval);
      expect(prefs.getString('mcp_provider_groups'), savedGroupsBeforeRemoval);
    } finally {
      SharedPreferencesStorePlatform.instance = previousStore;
    }
  });

  test('removing an MCP group reports when rollback also fails', () async {
    const groupId = 'custom_group';
    final originalEntries = [
      ProviderEntry(
        id: 'mcp',
        type: 'mcp',
        name: 'MCP',
        configs: [ProviderConfigItem(id: 'server', groupId: groupId)],
      ),
      ProviderEntry(id: 'ocr', type: 'ocr', name: 'OCR'),
      ProviderEntry(id: 'asr', type: 'asr', name: 'ASR'),
    ];
    final originalGroups = [
      ...builtinMcpProviderGroups,
      const McpProviderGroup(id: groupId, name: 'Custom'),
    ];
    final initialEntries =
        jsonEncode(originalEntries.map((entry) => entry.toMap()).toList());
    final initialGroups =
        jsonEncode(originalGroups.map((group) => group.toMap()).toList());
    SharedPreferences.setMockInitialValues({
      'provider_entries': initialEntries,
      'mcp_provider_groups': initialGroups,
    });
    final previousStore = SharedPreferencesStorePlatform.instance;
    final store = _FailingProviderRollbackStore({
      'flutter.provider_entries': initialEntries,
      'flutter.mcp_provider_groups': initialGroups,
    });
    SharedPreferencesStorePlatform.instance = store;
    try {
      final notifier = ProviderEntriesNotifier();
      await notifier.load();
      final prefs = await SharedPreferences.getInstance();
      final savedEntriesBeforeRemoval = prefs.getString('provider_entries');
      final savedGroupsBeforeRemoval = prefs.getString('mcp_provider_groups');
      store.isArmed = true;

      await expectLater(
        notifier.removeMcpGroup(groupId),
        throwsA(isA<ProviderEntriesRollbackException>()),
      );

      expect(
        notifier.state.mcpGroups.map((group) => group.id),
        contains(groupId),
      );
      expect(
        notifier.state.entries
            .singleWhere((entry) => entry.id == 'mcp')
            .configs
            .firstWhere((config) => config.id == 'server')
            .groupId,
        groupId,
      );
      await prefs.reload();
      final persistedEntries =
          jsonDecode(prefs.getString('provider_entries')!) as List;
      final persistedMcpEntry = persistedEntries
          .whereType<Map>()
          .singleWhere((entry) => entry['id'] == 'mcp');
      final persistedServer = (persistedMcpEntry['configs'] as List)
          .whereType<Map>()
          .singleWhere((config) => config['id'] == 'server');
      expect(persistedServer['groupId'], builtinMcpServicesGroupId);
      expect(
        prefs.getString('provider_entries'),
        isNot(savedEntriesBeforeRemoval),
      );
      expect(prefs.getString('mcp_provider_groups'), savedGroupsBeforeRemoval);
    } finally {
      SharedPreferencesStorePlatform.instance = previousStore;
    }
  });

  test('provider update surfaces a failed persistence write', () async {
    const savedEntries = '[{"id":"existing_llm","type":"llm",'
        '"name":"Before","configs":[]}]';
    SharedPreferences.setMockInitialValues({});
    final previousStore = SharedPreferencesStorePlatform.instance;
    final store = _FailingProviderEntriesStore({
      'flutter.provider_entries': savedEntries,
    });
    SharedPreferencesStorePlatform.instance = store;
    try {
      final notifier = ProviderEntriesNotifier();
      await notifier.load();
      final prefs = await SharedPreferences.getInstance();
      final savedEntriesBeforeUpdate = prefs.getString('provider_entries')!;
      store.failedWriteCount = 1;

      await expectLater(
        notifier.update(
          'existing_llm',
          ProviderEntry(
            id: 'existing_llm',
            type: 'llm',
            name: 'After',
          ),
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        notifier.state.entries
            .singleWhere((entry) => entry.id == 'existing_llm')
            .name,
        'Before',
      );
      expect(prefs.getString('provider_entries'), savedEntriesBeforeUpdate);
      await prefs.reload();
      expect(prefs.getString('provider_entries'), savedEntriesBeforeUpdate);
    } finally {
      SharedPreferencesStorePlatform.instance = previousStore;
    }
  });

  test('provider addition does not publish when persistence fails', () async {
    SharedPreferences.setMockInitialValues({});
    final previousStore = SharedPreferencesStorePlatform.instance;
    final store = _FailingProviderEntriesStore(
      const {},
      failedWriteCount: 1,
    );
    SharedPreferencesStorePlatform.instance = store;
    try {
      final notifier = ProviderEntriesNotifier();
      await notifier.load();
      final originalEntries = notifier.state.entries;

      await expectLater(
        notifier.addFirst(
          ProviderEntry(id: 'new_llm', type: 'llm', name: 'New provider'),
        ),
        throwsA(isA<StateError>()),
      );

      expect(notifier.state.entries, same(originalEntries));
      expect(
        notifier.state.entries.any((entry) => entry.id == 'new_llm'),
        isFalse,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('provider_entries'), isNull);
      await prefs.reload();
      expect(prefs.getString('provider_entries'), isNull);
    } finally {
      SharedPreferencesStorePlatform.instance = previousStore;
    }
  });

  test('provider addition is published only after persistence completes',
      () async {
    SharedPreferences.setMockInitialValues({});
    final previousStore = SharedPreferencesStorePlatform.instance;
    final store = _GatedProviderEntriesStore(const {});
    SharedPreferencesStorePlatform.instance = store;
    try {
      final notifier = ProviderEntriesNotifier();
      await notifier.load();
      final originalEntries = notifier.state.entries;
      store.isArmed = true;

      final add = notifier.addFirst(
        ProviderEntry(id: 'new_llm', type: 'llm', name: 'New provider'),
      );
      await store.firstProviderEntriesWriteStarted.future;

      expect(notifier.state.entries, same(originalEntries));
      expect(
        notifier.state.entries.any((entry) => entry.id == 'new_llm'),
        isFalse,
      );

      store.releaseFirstProviderEntriesWrite.complete();
      await add;

      expect(
        notifier.state.entries.any((entry) => entry.id == 'new_llm'),
        isTrue,
      );
    } finally {
      if (!store.releaseFirstProviderEntriesWrite.isCompleted) {
        store.releaseFirstProviderEntriesWrite.complete();
      }
      SharedPreferencesStorePlatform.instance = previousStore;
    }
  });

  test('provider update ignores an unrelated group write failure', () async {
    const savedEntries = '[{"id":"existing_llm","type":"llm",'
        '"name":"Before","configs":[]}]';
    SharedPreferences.setMockInitialValues({});
    final previousStore = SharedPreferencesStorePlatform.instance;
    final store = _FailingProviderEntriesStore(
      {'flutter.provider_entries': savedEntries},
      failedKey: 'flutter.mcp_provider_groups',
    );
    SharedPreferencesStorePlatform.instance = store;
    try {
      final notifier = ProviderEntriesNotifier();
      await notifier.load();
      store.failedWriteCount = 1;

      await notifier.update(
        'existing_llm',
        ProviderEntry(
          id: 'existing_llm',
          type: 'llm',
          name: 'After',
        ),
      );

      expect(
        notifier.state.entries
            .singleWhere((entry) => entry.id == 'existing_llm')
            .name,
        'After',
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        (jsonDecode(prefs.getString('provider_entries')!) as List)
            .whereType<Map>()
            .singleWhere((entry) => entry['id'] == 'existing_llm')['name'],
        'After',
      );
    } finally {
      SharedPreferencesStorePlatform.instance = previousStore;
    }
  });

  test('overlapping provider updates retain both edits', () async {
    final savedEntries = jsonEncode([
      {'id': 'first', 'type': 'llm', 'name': 'First before', 'configs': []},
      {'id': 'second', 'type': 'llm', 'name': 'Second before', 'configs': []},
    ]);
    SharedPreferences.setMockInitialValues({});
    final previousStore = SharedPreferencesStorePlatform.instance;
    final store = _GatedProviderEntriesStore({
      'flutter.provider_entries': savedEntries,
    });
    SharedPreferencesStorePlatform.instance = store;
    try {
      final notifier = ProviderEntriesNotifier();
      await notifier.load();
      store.isArmed = true;

      final firstUpdate = notifier.update(
        'first',
        ProviderEntry(id: 'first', type: 'llm', name: 'First after'),
      );
      await store.firstProviderEntriesWriteStarted.future;
      final secondUpdate = notifier.update(
        'second',
        ProviderEntry(id: 'second', type: 'llm', name: 'Second after'),
      );
      store.releaseFirstProviderEntriesWrite.complete();
      await Future.wait([firstUpdate, secondUpdate]);

      expect(
        notifier.state.entries.map((entry) => entry.name),
        containsAll(['First after', 'Second after']),
      );
      final prefs = await SharedPreferences.getInstance();
      final persistedNames =
          (jsonDecode(prefs.getString('provider_entries')!) as List)
              .map((entry) => entry['name']);
      expect(persistedNames, containsAll(['First after', 'Second after']));
    } finally {
      SharedPreferencesStorePlatform.instance = previousStore;
    }
  });

  test('concurrent provider addition is retained during update persistence',
      () async {
    const savedEntries = '[{"id":"existing_llm","type":"llm",'
        '"name":"Before","configs":[]}]';
    SharedPreferences.setMockInitialValues({});
    final previousStore = SharedPreferencesStorePlatform.instance;
    final store = _GatedProviderEntriesStore({
      'flutter.provider_entries': savedEntries,
    });
    SharedPreferencesStorePlatform.instance = store;
    try {
      final notifier = ProviderEntriesNotifier();
      await notifier.load();
      store.isArmed = true;

      final update = notifier.update(
        'existing_llm',
        ProviderEntry(
          id: 'existing_llm',
          type: 'llm',
          name: 'After',
        ),
      );
      await store.firstProviderEntriesWriteStarted.future;
      final add = notifier.addFirst(
        ProviderEntry(id: 'new_llm', type: 'llm', name: 'New'),
      );
      store.releaseFirstProviderEntriesWrite.complete();
      await Future.wait([update, add]);

      expect(
        notifier.state.entries.map((entry) => entry.id),
        containsAll(['existing_llm', 'new_llm']),
      );
      expect(
        notifier.state.entries
            .singleWhere((entry) => entry.id == 'existing_llm')
            .name,
        'After',
      );
      final prefs = await SharedPreferences.getInstance();
      final persistedIds =
          (jsonDecode(prefs.getString('provider_entries')!) as List)
              .map((entry) => entry['id']);
      expect(persistedIds, containsAll(['existing_llm', 'new_llm']));
    } finally {
      SharedPreferencesStorePlatform.instance = previousStore;
    }
  });

  group('built-in provider display localization', () {
    const presets = <String, (String, String)>{
      'Exa': (
        '通过 Exa MCP 接口进行网络搜索、内容提取和深度研究，支持语义搜索与关键词搜索',
        '请在 Exa 官网获取 API Key',
      ),
      'Tavily': (
        'AI 原生搜索引擎，专为大语言模型优化的实时网络搜索服务',
        '请在 Tavily 官网获取 API Key，支持 ?tavilyApiKey= 或 Authorization: Bearer',
      ),
      'Jina AI': (
        '多模态 AI 服务，支持网页内容提取、Embedding 和搜索结果抓取',
        '请在 Jina AI 官网获取 API Key (Bearer Token)',
      ),
      'Firecrawl': (
        '网页抓取与内容提取服务，可将任意网页转为干净的 Markdown 或结构化数据',
        '请在 Firecrawl 官网获取 API Key，也可免 Key 试用（免费版有限额）',
      ),
      'Zhipu': (
        '智谱 AI 开放平台的网页阅读器 MCP 服务，支持网页内容抓取与理解',
        '请在智谱 AI 开放平台获取 API Key (Bearer Token)',
      ),
      'Brave Search': (
        '隐私优先的独立搜索引擎，提供高质量网络搜索结果（需配置 API Key）',
        '请在 Brave Search 官网获取 API Key',
      ),
      'Bocha': (
        '博查 AI 网络搜索服务，提供智能化的中文网页搜索结果',
        '请在博查 AI 开放平台获取 API Key (Bearer Token)',
      ),
      'Querit': (
        'Querit AI 搜索服务，提供智能搜索与内容发现能力',
        '请在 Querit 官网获取 API Key (Bearer Token)',
      ),
      'Searxng': (
        '自托管的元搜索引擎，聚合多种搜索源，注重隐私保护（需自建实例）',
        '设置 SearXNG 实例 URL（如 http://your-instance:8080），可选 API Key',
      ),
    };

    test('localizes all built-in descriptions and setup hints', () async {
      final english = await AppLocalizations.delegate.load(const Locale('en'));
      final chinese = await AppLocalizations.delegate.load(const Locale('zh'));
      final chineseDescriptions = {
        'Exa': chinese.providerPresetExaDescription,
        'Tavily': chinese.providerPresetTavilyDescription,
        'Jina AI': chinese.providerPresetJinaDescription,
        'Firecrawl': chinese.providerPresetFirecrawlDescription,
        'Zhipu': chinese.providerPresetZhipuDescription,
        'Brave Search': chinese.providerPresetBraveSearchDescription,
        'Bocha': chinese.providerPresetBochaDescription,
        'Querit': chinese.providerPresetQueritDescription,
        'Searxng': chinese.providerPresetSearxngDescription,
      };
      final chineseHints = {
        'Exa': chinese.providerPresetExaApiKeyHint,
        'Tavily': chinese.providerPresetTavilyApiKeyHint,
        'Jina AI': chinese.providerPresetJinaApiKeyHint,
        'Firecrawl': chinese.providerPresetFirecrawlApiKeyHint,
        'Zhipu': chinese.providerPresetZhipuApiKeyHint,
        'Brave Search': chinese.providerPresetBraveSearchApiKeyHint,
        'Bocha': chinese.providerPresetBochaApiKeyHint,
        'Querit': chinese.providerPresetQueritApiKeyHint,
        'Searxng': chinese.providerPresetSearxngApiKeyHint,
      };

      expect(presets, hasLength(9));
      for (final entry in presets.entries) {
        final (description, hint) = entry.value;
        final englishDescription = localizedProviderPresetDescription(
          english,
          entry.key,
          description,
          isVendor: true,
        );
        final englishHint = localizedProviderPresetApiKeyHint(
          english,
          entry.key,
          hint,
          isVendor: true,
        );
        expect(englishDescription, isNot(description), reason: entry.key);
        expect(englishHint, isNot(hint), reason: entry.key);
        expect(englishDescription, isNotEmpty, reason: entry.key);
        expect(englishHint, isNotEmpty, reason: entry.key);
        expect(
          localizedProviderPresetDescription(
            chinese,
            entry.key,
            description,
            isVendor: true,
          ),
          chineseDescriptions[entry.key],
          reason: entry.key,
        );
        expect(
          localizedProviderPresetApiKeyHint(
            chinese,
            entry.key,
            hint,
            isVendor: true,
          ),
          chineseHints[entry.key],
          reason: entry.key,
        );
      }
    });

    test('preserves user-authored descriptions and hints verbatim', () async {
      final english = await AppLocalizations.delegate.load(const Locale('en'));

      expect(
        localizedProviderPresetDescription(
          english,
          'Exa',
          'My custom notes',
          isVendor: false,
        ),
        'My custom notes',
      );
      expect(
        localizedProviderPresetDescription(
          english,
          'Exa',
          presets['Exa']!.$1,
          isVendor: false,
        ),
        presets['Exa']!.$1,
        reason: 'a custom provider named Exa must keep its own description',
      );
      expect(
        localizedProviderPresetApiKeyHint(
          english,
          'Exa',
          'Use our internal credential vault',
          isVendor: false,
        ),
        'Use our internal credential vault',
      );
      expect(
        localizedProviderPresetApiKeyHint(
          english,
          'Exa',
          presets['Exa']!.$2,
          isVendor: false,
        ),
        presets['Exa']!.$2,
        reason: 'a custom provider named Exa must keep its own hint',
      );
      expect(
        localizedProviderPresetDescription(
          english,
          'Custom Provider',
          'Text',
          isVendor: false,
        ),
        'Text',
      );
    });
  });
}
