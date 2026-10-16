import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/llm_account.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/llm_account_migration_service.dart';
import 'package:stroom/services/llm_credential_store.dart';

const _secret = 'sk_live_migration_secret_7421';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LLM account domain serialization', () {
    test('round-trips account policy and explicit quota knowledge', () {
      final account = LlmAccount(
        id: 'account-1',
        connectorType: 'anthropic',
        authType: 'api_key',
        displayName: 'Anthropic personal',
        status: LlmAccountStatus.unknown,
        credentialRef: 'stroom.llm.credential.account-1',
        endpointConfig: const {
          'host': 'https://api.example.test',
          'endpointType': 'anthropic',
        },
        models: [
          LlmUpstreamModel(
            id: 'account-1:0',
            upstreamModelId: 'claude-model',
            displayName: 'Claude Model',
            capabilities: const {'streaming': true, 'vision': false},
            config: const {
              'typeConfig': {'temperature': 0.2},
            },
          ),
        ],
        policy: LlmRoutingPolicy(
          fallbackScope: LlmFallbackScope.modelGroup,
          strategy: LlmSelectionStrategy.balanceLower,
          windows: {
            LlmUsageWindow.fiveHour: LlmWindowPolicy(
              mode: LlmWindowMode.calendar,
              timeZone: 'America/Los_Angeles',
              reserveFloor: const LlmLimitThreshold.percentage(20),
              usageCeiling: const LlmLimitThreshold.fixed(
                500,
                unit: 'requests',
              ),
            ),
          },
          concurrencyLimit: 4,
        ),
        usageByWindow: {
          LlmUsageWindow.week: LlmUsageWindowState(
            quota: const LlmMetricObservation.unknown(),
            used: LlmMetricObservation.reported(
              1240,
              unit: 'tokens',
              source: 'local',
              observedAt: DateTime.utc(2026, 10, 11, 12),
            ),
            remaining: const LlmMetricObservation.unknown(),
            resetAt: DateTime.utc(2026, 10, 12),
            source: 'local',
          ),
        },
      );

      final decoded = LlmAccount.fromMap(account.toMap());

      expect(decoded.id, 'account-1');
      expect(decoded.credentialRef, 'stroom.llm.credential.account-1');
      expect(decoded.models.single.upstreamModelId, 'claude-model');
      expect(decoded.policy.fallbackScope, LlmFallbackScope.modelGroup);
      expect(decoded.policy.strategy, LlmSelectionStrategy.balanceLower);
      expect(
        decoded.policy.windows[LlmUsageWindow.fiveHour]!.mode,
        LlmWindowMode.calendar,
      );
      expect(
        decoded.policy.windows[LlmUsageWindow.fiveHour]!.timeZone,
        'America/Los_Angeles',
      );
      expect(
        decoded.policy.windows[LlmUsageWindow.fiveHour]!.reserveFloor!.kind,
        LlmLimitKind.percentage,
      );
      expect(
        decoded.policy.windows[LlmUsageWindow.fiveHour]!.usageCeiling!.unit,
        'requests',
      );
      expect(decoded.policy.concurrencyLimit, 4);
      expect(
        decoded.usageByWindow[LlmUsageWindow.week]!.quota.isKnown,
        isFalse,
      );
      expect(decoded.usageByWindow[LlmUsageWindow.week]!.used.isKnown, isTrue);
      expect(decoded.usageByWindow[LlmUsageWindow.week]!.used.value, 1240);
      expect(decoded.usageByWindow[LlmUsageWindow.week]!.used.source, 'local');
      expect(
        decoded.usageByWindow[LlmUsageWindow.week]!.resetAt,
        DateTime.utc(2026, 10, 12),
      );
    });
  });

  group('LLM account migration', () {
    test(
      'migrates every LLM config and preserves legacy model identities',
      () async {
        final source = _legacyProviderEntries();
        final preferences = _MemoryLlmPreferences({
          'provider_entries': source,
          'conversations': '[{"modelRef":"provider-config-1/claude-model"}]',
          'assistants': '[{"modelRef":"provider-config-1/claude-model"}]',
        });
        final credentials = _MemoryCredentialStore();

        await _service(preferences, credentials).migrate();

        final migratedEntries = _decodeList(
          preferences.values['provider_entries']!,
        );
        final llmConfigs = _configsFor(migratedEntries, 'llm');
        expect(llmConfigs, hasLength(2));
        expect(llmConfigs[0]['id'], 'provider-config-1');
        expect(llmConfigs[0].containsKey('key'), isFalse);
        expect(llmConfigs[0]['credentialRef'], isA<String>());
        expect(llmConfigs[0]['host'], 'https://api.example.test');
        expect(llmConfigs[0]['endpointType'], 'anthropic');
        expect(llmConfigs[0]['customParams'], [
          {
            'paramName': 'seed',
            'defaultValue': 'saved',
            'legacyParamExtension': 'keep',
          },
        ]);
        expect(llmConfigs[0]['models'][0]['modelId'], 'claude-model');
        expect(llmConfigs[0]['models'][0]['typeConfig']['temperature'], 0.2);
        expect(
          preferences.values['provider_entries']!.contains(_secret),
          isFalse,
        );
        expect(
          preferences.values['conversations'],
          '[{"modelRef":"provider-config-1/claude-model"}]',
        );
        expect(
          preferences.values['assistants'],
          '[{"modelRef":"provider-config-1/claude-model"}]',
        );

        final accountRecords = _records(
          preferences.values[LlmAccountMigrationService.accountsPreferenceKey]!,
        );
        final accounts = accountRecords.map(LlmAccount.fromMap).toList();
        expect(
          accounts.map((account) => account.id),
          containsAll(['provider-config-1', 'provider-config-2']),
        );
        final account = accounts.singleWhere(
          (item) => item.id == 'provider-config-1',
        );
        expect(account.credentialRef, llmConfigs[0]['credentialRef']);
        expect(account.endpointConfig['host'], 'https://api.example.test');
        expect(account.endpointConfig.containsKey('key'), isFalse);
        expect(account.models.single.upstreamModelId, 'claude-model');
        expect(account.models.single.capabilities['streaming'], isTrue);
        expect(account.models.single.config['typeConfig']['temperature'], 0.2);
        expect(credentials.values[account.credentialRef] == _secret, isTrue);

        final groups = _records(
          preferences
              .values[LlmAccountMigrationService.modelGroupsPreferenceKey]!,
        );
        expect(groups, hasLength(2));
        final claudeGroup = groups.map(LlmModelGroup.fromMap).singleWhere(
              (group) => group.members.single.upstreamModelId == 'claude-model',
            );
        expect(claudeGroup.members.single.accountId, 'provider-config-1');
        expect(claudeGroup.members.single.priorityTier, 0);
        expect(
          claudeGroup.policy.windows.keys,
          containsAll(LlmUsageWindow.values),
        );
        expect(
          claudeGroup.policy.windows.values.every(
            (window) => window.mode == LlmWindowMode.rolling,
          ),
          isTrue,
        );

        expect(
          preferences.values[LlmAccountMigrationService.migrationStateKey],
          contains('complete'),
        );
        expect(
          preferences.values[LlmAccountMigrationService.accountsPreferenceKey]!
              .contains(_secret),
          isFalse,
        );
        expect(
          preferences
              .values[LlmAccountMigrationService.modelGroupsPreferenceKey]!
              .contains(_secret),
          isFalse,
        );
      },
    );

    test(
      're-running a completed migration changes no records or credentials',
      () async {
        final preferences = _MemoryLlmPreferences({
          'provider_entries': _legacyProviderEntries(),
        });
        final credentials = _MemoryCredentialStore();
        final service = _service(preferences, credentials);

        await service.migrate();
        final savedValues = Map<String, String>.from(preferences.values);
        final savedWriteHistory = List<String>.from(preferences.writeHistory);
        final savedCredentialWrites = credentials.writeCount;

        await service.migrate();

        expect(preferences.values, savedValues);
        expect(preferences.writeHistory, savedWriteHistory);
        expect(credentials.writeCount, savedCredentialWrites);
      },
    );

    test(
      'moves a top-level legacy key from a mixed-format LLM entry',
      () async {
        final source = jsonEncode([
          {
            'id': 'mixed-llm-entry',
            'type': 'llm',
            'name': 'Mixed LLM entry',
            'key': _secret,
            'configs': [
              {
                'id': 'mixed-provider-config',
                'providerName': 'Legacy provider',
                'host': 'https://api.example.test',
                'models': [
                  {
                    'id': 'mixed-model',
                    'name': 'Mixed model',
                    'modelId': 'mixed-model-id',
                  },
                ],
              },
            ],
          },
        ]);
        final preferences = _MemoryLlmPreferences({
          'provider_entries': source,
        });
        final credentials = _MemoryCredentialStore();

        await _service(preferences, credentials).migrate();

        final migratedEntry = _decodeList(
          preferences.values['provider_entries']!,
        ).single;
        expect(migratedEntry.containsKey('key'), isFalse);
        final config = _configsFor([migratedEntry], 'llm').single;
        expect(config.containsKey('key'), isFalse);
        expect(config['credentialRef'], isA<String>());
        expect(credentials.values[config['credentialRef']] == _secret, isTrue);
        expect(
          preferences.values['provider_entries']!.contains(_secret),
          isFalse,
        );
      },
    );

    test(
      'detects a restored top-level key even after the migration marker',
      () async {
        final source = jsonEncode([
          {
            'id': 'restored-llm-entry',
            'type': 'llm',
            'name': 'Restored LLM entry',
            'key': _secret,
            'configs': [
              {
                'id': 'restored-provider-config',
                'providerName': 'Legacy provider',
                'models': [],
              },
            ],
          },
        ]);
        final preferences = _MemoryLlmPreferences({
          'provider_entries': source,
          LlmAccountMigrationService.migrationStateKey:
              '{"version":1,"status":"complete"}',
        });
        final credentials = _MemoryCredentialStore();

        await _service(preferences, credentials).migrate();

        final migratedEntry = _decodeList(
          preferences.values['provider_entries']!,
        ).single;
        final config = _configsFor([migratedEntry], 'llm').single;
        expect(migratedEntry.containsKey('key'), isFalse);
        expect(config.containsKey('key'), isFalse);
        expect(config['credentialRef'], isA<String>());
        expect(credentials.values[config['credentialRef']] == _secret, isTrue);
        expect(
          preferences.values['provider_entries']!.contains(_secret),
          isFalse,
        );
      },
    );

    test('ordinary provider serialization never emits entry-level LLM keys', () {
      final entry = ProviderEntry.fromMap({
        'id': 'legacy-entry',
        'type': 'llm',
        'name': 'Legacy LLM',
        'key': _secret,
        'configs': [
          {'id': 'legacy-config', 'providerName': 'Legacy provider'},
        ],
      });

      expect(entry.toMap().containsKey('key'), isFalse);
      expect(entry.toCredentialMigrationMap()['key'], _secret);
    });

    test(
      'keeps conflicting top-level and per-config keys recoverable',
      () async {
        final source = jsonEncode([
          {
            'id': 'mixed-llm-entry',
            'type': 'llm',
            'name': 'Mixed LLM entry',
            'key': _secret,
            'configs': [
              {
                'id': 'mixed-provider-config',
                'providerName': 'Legacy provider',
                'key': 'sk_other_mixed_secret',
                'models': [],
              },
            ],
          },
        ]);
        final preferences = _MemoryLlmPreferences({
          'provider_entries': source,
        });
        final credentials = _MemoryCredentialStore();

        await expectLater(
          _service(preferences, credentials).migrate(),
          throwsA(isA<LlmAccountMigrationException>()),
        );

        expect(preferences.values['provider_entries'], source);
        expect(credentials.values.values, isEmpty);
        expect(
          preferences.values[LlmAccountMigrationService.migrationStateKey],
          isNull,
        );
      },
    );

    test(
      'does not overwrite one credential reference with conflicting secrets',
      () async {
        final source = jsonEncode([
          {
            'id': 'shared-llm-entry',
            'type': 'llm',
            'name': 'Shared LLM entry',
            'configs': [
              {
                'id': 'shared-provider-config-1',
                'providerName': 'First provider',
                'key': 'sk_first_shared_reference',
                'credentialRef': 'shared-credential-ref',
                'models': [],
              },
              {
                'id': 'shared-provider-config-2',
                'providerName': 'Second provider',
                'key': 'sk_second_shared_reference',
                'credentialRef': 'shared-credential-ref',
                'models': [],
              },
            ],
          },
        ]);
        final preferences = _MemoryLlmPreferences({
          'provider_entries': source,
        });
        final credentials = _MemoryCredentialStore();

        await expectLater(
          _service(preferences, credentials).migrate(),
          throwsA(isA<LlmAccountMigrationException>()),
        );

        expect(preferences.values['provider_entries'], source);
        expect(
          credentials.values['shared-credential-ref'],
          'sk_first_shared_reference',
        );
        expect(
          preferences.values[LlmAccountMigrationService.migrationStateKey],
          isNull,
        );
      },
    );

    test(
      'preserves an existing shared credential when a keyless config reuses it',
      () async {
        const existingSecret = 'sk_existing_shared_reference';
        final source = jsonEncode([
          {
            'id': 'shared-llm-entry',
            'type': 'llm',
            'name': 'Shared LLM entry',
            'configs': [
              {
                'id': 'shared-provider-config-1',
                'providerName': 'Existing provider',
                'credentialRef': 'shared-credential-ref',
                'models': [],
              },
              {
                'id': 'shared-provider-config-2',
                'providerName': 'Conflicting provider',
                'key': 'sk_conflicting_shared_reference',
                'credentialRef': 'shared-credential-ref',
                'models': [],
              },
            ],
          },
        ]);
        final preferences = _MemoryLlmPreferences({
          'provider_entries': source,
        });
        final credentials = _MemoryCredentialStore()
          ..values['shared-credential-ref'] = existingSecret;

        await expectLater(
          _service(preferences, credentials).migrate(),
          throwsA(isA<LlmAccountMigrationException>()),
        );

        expect(preferences.values['provider_entries'], source);
        expect(
          credentials.values['shared-credential-ref'],
          existingSecret,
        );
        expect(credentials.writeReferences, isEmpty);
        expect(
          preferences.values[LlmAccountMigrationService.migrationStateKey],
          isNull,
        );
      },
    );

    test(
      'creates different model groups for delimiter-containing identities',
      () async {
        final preferences = _MemoryLlmPreferences({
          'provider_entries': jsonEncode([
            {
              'id': 'llm-entry',
              'type': 'llm',
              'name': 'LLM providers',
              'configs': [
                {
                  'id': 'a.b',
                  'providerName': 'First provider',
                  'models': [
                    {'id': 'c', 'modelId': 'first-model'},
                  ],
                },
                {
                  'id': 'a',
                  'providerName': 'Second provider',
                  'models': [
                    {'id': 'b.c', 'modelId': 'second-model'},
                  ],
                },
              ],
            },
          ]),
        });

        await _service(preferences, _MemoryCredentialStore()).migrate();

        final groups = _records(
          preferences.values[
            LlmAccountMigrationService.modelGroupsPreferenceKey
          ]!,
        );
        expect(groups, hasLength(2));
        expect(groups[0]['id'], isNot(groups[1]['id']));
      },
    );

    test('a completed marker does not skip a restored legacy backup', () async {
      final preferences = _MemoryLlmPreferences({
        'provider_entries': _legacyProviderEntries(),
        LlmAccountMigrationService.migrationStateKey:
            '{"version":1,"status":"complete"}',
      });
      final credentials = _MemoryCredentialStore();

      await _service(preferences, credentials).migrate();

      expect(credentials.values.values.contains(_secret), isTrue);
      expect(
          preferences.values['provider_entries']!.contains(_secret), isFalse);
      expect(
        preferences.values[LlmAccountMigrationService.accountsPreferenceKey],
        contains('provider-config-1'),
      );
    });

    test(
      'a failed persistent write can be retried without losing credentials',
      () async {
        final preferenceBoundaries = [
          LlmAccountMigrationService.accountsPreferenceKey,
          LlmAccountMigrationService.modelGroupsPreferenceKey,
          'provider_entries',
          LlmAccountMigrationService.migrationStateKey,
        ];

        for (final boundary in ['credential', ...preferenceBoundaries]) {
          final source = _legacyProviderEntries();
          final preferences = _MemoryLlmPreferences({
            'provider_entries': source,
          });
          final credentials = _MemoryCredentialStore();
          if (boundary == 'credential') {
            credentials.failNextWrite = true;
          } else {
            preferences.failNextWriteKey = boundary;
          }

          Object? failure;
          try {
            await _service(preferences, credentials).migrate();
          } catch (error) {
            failure = error;
          }
          expect(
            failure,
            isA<LlmAccountMigrationException>(),
            reason: boundary,
          );
          expect(failure.toString().contains(_secret), isFalse,
              reason: boundary);
          if (boundary != LlmAccountMigrationService.migrationStateKey) {
            expect(preferences.values['provider_entries'] == source, isTrue,
                reason: boundary);
          } else {
            expect(
              preferences.values['provider_entries']!.contains(_secret),
              isFalse,
            );
            expect(credentials.values.values.contains(_secret), isTrue);
          }

          final retried = await _service(preferences, credentials).migrate();
          expect(retried.completed, isTrue, reason: boundary);
          expect(
            preferences.values['provider_entries']!.contains(_secret),
            isFalse,
          );
          expect(credentials.values.values.contains(_secret), isTrue);
          expect(
            preferences.values[LlmAccountMigrationService.migrationStateKey],
            contains('complete'),
            reason: boundary,
          );
        }
      },
    );

    test(
      'provider notifier hydrates legacy callers but persists only references',
      () async {
        SharedPreferences.setMockInitialValues({
          'provider_entries': _legacyProviderEntries(),
        });
        final credentials = _MemoryCredentialStore();
        final notifier = ProviderEntriesNotifier(credentialStore: credentials);

        await notifier.load();

        final entry = notifier.state.entries.singleWhere(
          (item) => item.id == 'llm-entry',
        );
        final config = entry.configs.first;
        expect(config.key == _secret, isTrue);
        expect(config.credentialRef, isNotNull);
        expect(config.legacyFields['legacyExtension'], {'preserve': true});
        final prefs = await SharedPreferences.getInstance();
        var persisted = prefs.getString('provider_entries')!;
        expect(persisted.contains(_secret), isFalse);
        expect(persisted, contains(config.credentialRef!));

        final changedConfig = config.copy()
          ..key = 'sk_rotated_migration_secret';
        final changedEntry = ProviderEntry(
          id: entry.id,
          type: entry.type,
          name: entry.name,
          configs: [changedConfig, ...entry.configs.skip(1)],
        );
        await notifier.update(entry.id, changedEntry, requirePersistence: true);

        persisted = prefs.getString('provider_entries')!;
        expect(persisted.contains(_secret), isFalse);
        expect(persisted.contains('sk_rotated_migration_secret'), isFalse);
        expect(
          _configsFor(_decodeList(persisted), 'llm').first['legacyExtension'],
          {'preserve': true},
        );
        expect(
          (_configsFor(_decodeList(persisted), 'llm').first['customParams']
                  as List)
              .first['legacyParamExtension'],
          'keep',
        );
        expect(
          credentials.values[config.credentialRef] ==
              'sk_rotated_migration_secret',
          isTrue,
        );
        expect(
          notifier.state.entries.first.configs.first.key ==
              'sk_rotated_migration_secret',
          isTrue,
        );
      },
    );

    test(
      'settings saves retain references after secure reads temporarily fail',
      () async {
        SharedPreferences.setMockInitialValues({
          'provider_entries': _legacyProviderEntries(),
        });
        final credentials = _MemoryCredentialStore();
        final initialNotifier =
            ProviderEntriesNotifier(credentialStore: credentials);
        await initialNotifier.load();
        final originalConfig = initialNotifier.state.entries
            .singleWhere((entry) => entry.id == 'llm-entry')
            .configs
            .first;
        final originalReference = originalConfig.credentialRef!;

        credentials.failReads = true;
        final notifier = ProviderEntriesNotifier(credentialStore: credentials);
        await notifier.load();
        final entry = notifier.state.entries
            .singleWhere((item) => item.id == 'llm-entry');
        final loadedConfig = entry.configs.first;
        expect(loadedConfig.key, isEmpty);

        final editedConfig = ProviderConfigItem(
          id: loadedConfig.id,
          providerName: loadedConfig.providerName,
          host: loadedConfig.host,
          models: loadedConfig.models.map((model) => model.copy()).toList(),
        );
        await notifier.update(
          entry.id,
          ProviderEntry(
            id: entry.id,
            type: entry.type,
            name: entry.name,
            configs: [editedConfig, ...entry.configs.skip(1)],
          ),
          requirePersistence: true,
        );

        final prefs = await SharedPreferences.getInstance();
        final savedConfig = _configsFor(
          _decodeList(prefs.getString('provider_entries')!),
          'llm',
        ).first;
        expect(savedConfig['credentialRef'], originalReference);
        final account = _records(
          prefs.getString(LlmAccountMigrationService.accountsPreferenceKey)!,
        ).singleWhere((item) => item['id'] == loadedConfig.id);
        expect(account['credentialRef'], originalReference);
        expect(credentials.values[originalReference], _secret);
      },
    );

    test('secure-store failure keeps legacy credentials and safe diagnostics',
        () async {
      final source = _legacyProviderEntries();
      SharedPreferences.setMockInitialValues({'provider_entries': source});
      final credentials = _MemoryCredentialStore()..failAllWrites = true;
      final notifier = ProviderEntriesNotifier(credentialStore: credentials);
      final logs = <String>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) logs.add(message);
      };

      try {
        await notifier.load();
      } finally {
        debugPrint = previousDebugPrint;
      }

      final prefs = await SharedPreferences.getInstance();
      final persistedEntries = jsonDecode(
        prefs.getString('provider_entries')!,
      ) as List;
      final persistedConfig =
          (persistedEntries.first as Map)['configs'][0] as Map;
      expect(persistedConfig['key'] == _secret, isTrue);
      expect(
        prefs.getString(LlmAccountMigrationService.accountsPreferenceKey),
        isNull,
      );
      expect(
        prefs.getString(LlmAccountMigrationService.migrationStateKey),
        isNull,
      );
      expect(logs.join('\n').contains(_secret), isFalse);
    });
  });
}

String _legacyProviderEntries() => jsonEncode([
      {
        'id': 'llm-entry',
        'type': 'llm',
        'name': 'LLM providers',
        'configs': [
          {
            'id': 'provider-config-1',
            'providerName': 'Anthropic personal',
            'host': 'https://api.example.test',
            'key': _secret,
            'endpointType': 'anthropic',
            'typeConfig': {'requestMode': 'legacy'},
            'customParams': [
              {
                'paramName': 'seed',
                'defaultValue': 'saved',
                'legacyParamExtension': 'keep',
              },
            ],
            'reasoningParams': [],
            'models': [
              {
                'name': 'Claude Model',
                'modelId': 'claude-model',
                'supportStream': true,
                'typeConfig': {'temperature': 0.2},
                'customParams': [],
                'reasoningParams': [],
              },
            ],
            'legacyExtension': {'preserve': true},
          },
          {
            'id': 'provider-config-2',
            'providerName': 'OpenAI compatible',
            'host': 'https://openai.example.test/v1',
            'key': '',
            'endpointType': 'openai',
            'typeConfig': {'requestMode': 'legacy'},
            'customParams': [],
            'reasoningParams': [],
            'models': [
              {
                'name': 'Chat Model',
                'modelId': 'chat-model',
                'supportStream': true,
                'typeConfig': {'maxTokens': 8192},
                'customParams': [],
                'reasoningParams': [],
              },
            ],
          },
        ],
      },
      {
        'id': 'builtin_tts',
        'type': 'tts',
        'name': 'TTS providers',
        'configs': []
      },
    ]);

List<Map<String, dynamic>> _decodeList(String value) =>
    (jsonDecode(value) as List).cast<Map<String, dynamic>>();

List<Map<String, dynamic>> _configsFor(
  List<Map<String, dynamic>> entries,
  String type,
) =>
    [
      for (final entry in entries.where((item) => item['type'] == type))
        ...(entry['configs'] as List).cast<Map<String, dynamic>>(),
    ];

List<Map<String, dynamic>> _records(String envelopeJson) =>
    (jsonDecode(envelopeJson) as Map<String, dynamic>)['items']
        .cast<Map<String, dynamic>>() as List<Map<String, dynamic>>;

LlmAccountMigrationService _service(
  _MemoryLlmPreferences preferences,
  _MemoryCredentialStore credentials,
) =>
    LlmAccountMigrationService(
      preferences: preferences,
      credentialStore: credentials,
    );

class _MemoryLlmPreferences implements LlmAccountPreferences {
  final Map<String, String> values;
  final List<String> writeHistory = [];
  String? failNextWriteKey;

  _MemoryLlmPreferences([Map<String, String>? initialValues])
      : values = Map<String, String>.from(initialValues ?? {});

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<bool> setString(String key, String value) async {
    writeHistory.add(key);
    if (failNextWriteKey == key) {
      failNextWriteKey = null;
      return false;
    }
    values[key] = value;
    return true;
  }
}

class _MemoryCredentialStore implements LlmCredentialStore {
  final Map<String, String> values = {};
  final List<String> writeReferences = [];
  bool failNextWrite = false;
  bool failAllWrites = false;
  bool failReads = false;

  int get writeCount => writeReferences.length;

  @override
  Future<String?> read(String reference) async {
    if (failReads) throw const LlmCredentialStoreException();
    return values[reference];
  }

  @override
  Future<void> write(String reference, String secret) async {
    writeReferences.add(reference);
    if (failNextWrite || failAllWrites) {
      failNextWrite = false;
      throw const LlmCredentialStoreException();
    }
    values[reference] = secret;
  }

  @override
  Future<void> delete(String reference) async => values.remove(reference);
}
