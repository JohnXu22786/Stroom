import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/llm_credential_store.dart';

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
      expect(notifier.state.entries.any((e) => e.id == 'migrated_llm'), isTrue);
    });

    test(
      'unparseable provider_entries is quarantined and defaults loaded',
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
      },
    );

    test(
      'persists a fresh non-LLM provider edit without an LLM key change',
      () async {
        SharedPreferences.setMockInitialValues({});
        final notifier = ProviderEntriesNotifier();
        await notifier.load();

        final added = ProviderEntry(
          id: 'fresh-ocr-entry',
          type: 'ocr',
          name: 'Fresh OCR provider',
        );
        await notifier.addFirst(added);

        final prefs = await SharedPreferences.getInstance();
        final stored =
            jsonDecode(prefs.getString('provider_entries')!) as List<dynamic>;
        expect(
          stored.whereType<Map>().any((entry) => entry['id'] == added.id),
          isTrue,
        );
      },
    );

    test('does not overwrite provider settings changed after load', () async {
      const initialEntries =
          '[{"id":"original-tts","type":"tts","name":"Original TTS","configs":[]}]';
      const externalEntries =
          '[{"id":"external-tts","type":"tts","name":"External TTS","configs":[]}]';
      SharedPreferences.setMockInitialValues({
        'provider_entries': initialEntries,
      });

      final notifier = ProviderEntriesNotifier();
      addTearDown(notifier.dispose);
      await notifier.load();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('provider_entries', externalEntries);

      await expectLater(
        notifier.addFirst(
          ProviderEntry(
            id: 'stale-added-tts',
            type: 'tts',
            name: 'Stale added TTS',
          ),
        ),
        throwsA(isA<StateError>()),
      );
      expect(prefs.getString('provider_entries'), externalEntries);
    });

    test('required updates fail when the provider entry was removed', () async {
      SharedPreferences.setMockInitialValues({
        'provider_entries': jsonEncode([
          {
            'id': 'removed-entry',
            'type': 'tts',
            'name': 'Removed entry',
            'configs': [],
          },
        ]),
      });
      final notifier = ProviderEntriesNotifier();
      addTearDown(notifier.dispose);
      await notifier.load();
      await notifier.remove('removed-entry');

      await expectLater(
        notifier.update(
          'removed-entry',
          ProviderEntry(id: 'removed-entry', type: 'tts', name: 'Stale save'),
          requirePersistence: true,
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        notifier.state.entries.any((entry) => entry.id == 'removed-entry'),
        isFalse,
      );
    });

    test(
      'does not retry a stale required update after a persistence conflict',
      () async {
        SharedPreferences.setMockInitialValues({});
        final notifier = ProviderEntriesNotifier();
        addTearDown(notifier.dispose);
        await notifier.load();

        final prefs = await SharedPreferences.getInstance();
        final originalTts = notifier.state.entries.firstWhere(
          (entry) => entry.id == 'builtin_tts',
        );
        final staleUpdate = ProviderEntry(
          id: originalTts.id,
          type: originalTts.type,
          name: 'Stale TTS edit',
          configs: originalTts.configs.map((config) => config.copy()).toList(),
          legacyFields: originalTts.legacyFields,
        );
        final externallyUpdatedEntries = notifier.state.entries
            .map((entry) {
              if (entry.id != originalTts.id) return entry;
              return ProviderEntry(
                id: entry.id,
                type: entry.type,
                name: 'Newer external TTS edit',
                configs: [
                  ProviderConfigItem(
                    id: 'newer-external-config',
                    providerName: 'Newer external config',
                  ),
                ],
                legacyFields: entry.legacyFields,
              );
            })
            .map((entry) => entry.toMap())
            .toList();
        final externalJson = jsonEncode(externallyUpdatedEntries);
        await prefs.setString('provider_entries', externalJson);

        await expectLater(
          notifier.update(
            originalTts.id,
            staleUpdate,
            requirePersistence: true,
          ),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          notifier.update(
            originalTts.id,
            staleUpdate,
            requirePersistence: true,
          ),
          throwsA(isA<StateError>()),
        );

        final savedEntries =
            jsonDecode(prefs.getString('provider_entries')!) as List<dynamic>;
        final savedTts = savedEntries.whereType<Map>().singleWhere(
              (entry) => entry['id'] == originalTts.id,
            );
        expect(savedTts['name'], 'Newer external TTS edit');
        expect(
          (savedTts['configs'] as List).single['id'],
          'newer-external-config',
        );
      },
    );

    test(
      'does not retry a stale update after a provider source change during credential migration',
      () async {
        const accountId = 'racing-account';
        const credentialRef = 'stroom.llm.credential.racing-account';
        SharedPreferences.setMockInitialValues({
          'provider_entries': jsonEncode([
            {
              'id': 'racing-llm-entry',
              'type': 'llm',
              'name': 'Original entry',
              'configs': [
                {
                  'id': accountId,
                  'providerName': 'Original provider',
                  'key': 'migration-secret',
                  'models': [],
                },
              ],
            },
          ]),
        });
        final prefs = await SharedPreferences.getInstance();
        final credentialStore = _RacingCredentialStore(
          prefs: prefs,
          credentialRef: credentialRef,
          externalEntries: jsonEncode([
            {
              'id': 'racing-llm-entry',
              'type': 'llm',
              'name': 'Newer external entry',
              'configs': [
                {
                  'id': accountId,
                  'providerName': 'Newer external provider',
                  'credentialRef': credentialRef,
                  'models': [],
                },
              ],
            },
          ]),
        );
        final notifier = ProviderEntriesNotifier(
          credentialStore: credentialStore,
        );
        addTearDown(notifier.dispose);
        await notifier.load();

        final original = notifier.state.entries.singleWhere(
          (entry) => entry.id == 'racing-llm-entry',
        );
        final staleUpdate = ProviderEntry(
          id: original.id,
          type: original.type,
          name: 'Stale update',
          configs: original.configs.map((config) => config.copy()).toList(),
          legacyFields: original.legacyFields,
        );
        credentialStore.arm();

        await expectLater(
          notifier.update(original.id, staleUpdate, requirePersistence: true),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          notifier.update(original.id, staleUpdate, requirePersistence: true),
          throwsA(isA<StateError>()),
        );

        final savedEntries =
            jsonDecode(prefs.getString('provider_entries')!) as List<dynamic>;
        final savedEntry = savedEntries
            .whereType<Map>()
            .singleWhere((entry) => entry['id'] == 'racing-llm-entry');
        expect(savedEntry['name'], 'Newer external entry');
        expect(
          ((savedEntry['configs'] as List).single as Map)['providerName'],
          'Newer external provider',
        );
      },
    );
  });
}

class _RacingCredentialStore implements LlmCredentialStore {
  final SharedPreferences prefs;
  final String credentialRef;
  final String externalEntries;
  final Map<String, String> values = {};
  var _armed = false;
  var _sourceChanged = false;

  _RacingCredentialStore({
    required this.prefs,
    required this.credentialRef,
    required this.externalEntries,
  });

  void arm() => _armed = true;

  @override
  Future<String?> read(String reference) async {
    if (_armed && !_sourceChanged && reference == credentialRef) return null;
    return values[reference];
  }

  @override
  Future<void> write(String reference, String secret) async {
    if (_armed && !_sourceChanged && reference == credentialRef) {
      _sourceChanged = true;
      await prefs.setString('provider_entries', externalEntries);
    }
    values[reference] = secret;
  }

  @override
  Future<void> delete(String reference) async {
    values.remove(reference);
  }
}
