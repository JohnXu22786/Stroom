import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
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
      'defaults legacy tool capability to supported but preserves explicit false',
      () async {
        final entries = _decodeList(_legacyProviderEntries());
        final legacyConfigs = _configsFor(entries, 'llm');
        final explicitCapabilities = legacyConfigs[1]['models'] as List;
        (explicitCapabilities.first as Map<String, dynamic>)['capabilities'] =
            const {'tools': false};
        final preferences = _MemoryLlmPreferences({
          'provider_entries': jsonEncode(entries),
        });

        await _service(preferences, _MemoryCredentialStore()).migrate();

        final migratedAccounts = _records(
          preferences.values[LlmAccountMigrationService.accountsPreferenceKey]!,
        ).map(LlmAccount.fromMap).toList();
        expect(
          migratedAccounts
              .singleWhere((account) => account.id == 'provider-config-1')
              .models
              .single
              .capabilities['tools'],
          isTrue,
        );
        expect(
          migratedAccounts
              .singleWhere((account) => account.id == 'provider-config-2')
              .models
              .single
              .capabilities['tools'],
          isFalse,
        );
      },
    );

    test(
      'keeps legacy models streaming-capable when supportStream is false by default',
      () async {
        final entries = _decodeList(_legacyProviderEntries());
        final legacyConfigs = _configsFor(entries, 'llm');
        final legacyModels = legacyConfigs.first['models'] as List;
        (legacyModels.first as Map<String, dynamic>)['supportStream'] = false;
        final explicitCapabilities = legacyConfigs[1]['models'] as List;
        (explicitCapabilities.first as Map<String, dynamic>)['capabilities'] =
            const {'streaming': false};
        final preferences = _MemoryLlmPreferences({
          'provider_entries': jsonEncode(entries),
        });
        final credentials = _MemoryCredentialStore();

        await _service(preferences, credentials).migrate();

        final accountRecords = _records(
          preferences.values[LlmAccountMigrationService.accountsPreferenceKey]!,
        );
        final migratedAccounts = accountRecords
            .map(LlmAccount.fromMap)
            .toList();
        expect(
          migratedAccounts
              .singleWhere((account) => account.id == 'provider-config-1')
              .models
              .single
              .capabilities['streaming'],
          isTrue,
        );
        expect(
          migratedAccounts
              .singleWhere((account) => account.id == 'provider-config-2')
              .models
              .single
              .capabilities['streaming'],
          isFalse,
        );
      },
    );

    test(
      'migrates every LLM config and preserves legacy model identities',
      () async {
        final source = _legacyProviderEntries();
        final preferences = _MemoryLlmPreferences({
          'provider_entries': source,
          LlmAccountMigrationService.accountsPreferenceKey: jsonEncode({
            'version': 1,
            'items': [
              {
                'id': 'provider-config-1',
                'remainingQuota': {
                  'state': 'reported',
                  'value': 250,
                  'unit': 'credits',
                  'source': 'existing.connector',
                  'observedAt': DateTime.utc(2026, 10, 17).toIso8601String(),
                },
                'quotaSignals': {
                  'dailyRemainingPercent': {
                    'state': 'reported',
                    'value': 75,
                    'unit': 'percent',
                    'source': 'existing.daily',
                    'observedAt': DateTime.utc(2026, 10, 17).toIso8601String(),
                  },
                },
              },
            ],
          }),
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
        final rawAccountRecords = {
          for (final record in accountRecords) record['id']: record,
        };
        expect(
          rawAccountRecords['provider-config-1']!['remainingQuota']['value'],
          250,
        );
        expect(
          rawAccountRecords['provider-config-1']!['quotaSignals']['dailyRemainingPercent']['value'],
          75,
        );
        expect(
          rawAccountRecords['provider-config-2']!['remainingQuota']['state'],
          'unknown',
        );
        expect(
          rawAccountRecords['provider-config-2']!['quotaSignals'],
          isEmpty,
        );
        expect(account.credentialRef, llmConfigs[0]['credentialRef']);
        expect(account.endpointConfig['host'], 'https://api.example.test');
        expect(account.endpointConfig.containsKey('key'), isFalse);
        expect(account.models.single.upstreamModelId, 'claude-model');
        expect(account.models.single.capabilities['streaming'], isTrue);
        expect(account.models.single.config['typeConfig']['temperature'], 0.2);
        expect(credentials.values[account.credentialRef] == _secret, isTrue);

        final groups = _records(
          preferences.values[LlmAccountMigrationService
              .modelGroupsPreferenceKey]!,
        );
        expect(groups, hasLength(2));
        final claudeGroup = groups
            .map(LlmModelGroup.fromMap)
            .singleWhere(
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
      'preserves explicit capabilities when account editor syncs models',
      () async {
        final sourceEntries = _decodeList(_legacyProviderEntries());
        final llmEntry = sourceEntries.whereType<Map>().firstWhere(
          (entry) => entry['type'] == 'llm',
        );
        final config = (llmEntry['configs'] as List).first as Map;
        final model = (config['models'] as List).first as Map;
        model['capabilities'] = {'vision': true, 'tools': false};
        final preferences = _MemoryLlmPreferences({
          'provider_entries': jsonEncode(sourceEntries),
        });

        await _service(preferences, _MemoryCredentialStore()).migrate();

        final accounts = _records(
          preferences.values[LlmAccountMigrationService.accountsPreferenceKey]!,
        );
        final migrated = accounts.firstWhere(
          (account) => account['id'] == config['id'],
        );
        final capabilities =
            ((migrated['models'] as List).first as Map)['capabilities'] as Map;
        expect(capabilities['vision'], isTrue);
        expect(capabilities['tools'], isFalse);
      },
    );

    test(
      'account-edited capability maps keep unknown streaming and tools unknown',
      () async {
        final sourceEntries = _decodeList(_legacyProviderEntries());
        final legacyConfigs = _configsFor(sourceEntries, 'llm');
        final editedModel =
            (legacyConfigs.first['models'] as List).first
                as Map<String, dynamic>;
        // The account editor writes its capability map back to the legacy
        // row. An empty map means the user left these values unknown.
        editedModel['capabilities'] = <String, dynamic>{};
        editedModel['accountCapabilitiesEdited'] = true;
        final preferences = _MemoryLlmPreferences({
          'provider_entries': jsonEncode(sourceEntries),
        });

        await _service(preferences, _MemoryCredentialStore()).migrate();

        final accounts = _records(
          preferences.values[LlmAccountMigrationService.accountsPreferenceKey]!,
        ).map(LlmAccount.fromMap).toList();
        final edited = accounts.singleWhere(
          (account) => account.id == legacyConfigs.first['id'],
        );
        final untouchedLegacy = accounts.singleWhere(
          (account) => account.id == legacyConfigs[1]['id'],
        );

        expect(
          edited.models.single.capabilities.containsKey('streaming'),
          isFalse,
        );
        expect(edited.models.single.capabilities.containsKey('tools'), isFalse);
        expect(untouchedLegacy.models.single.capabilities['streaming'], isTrue);
        expect(untouchedLegacy.models.single.capabilities['tools'], isTrue);
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
        final preferences = _MemoryLlmPreferences({'provider_entries': source});
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

    test(
      'ordinary provider serialization never emits entry-level LLM keys',
      () {
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
      },
    );

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
        final preferences = _MemoryLlmPreferences({'provider_entries': source});
        final credentials = _MemoryCredentialStore();

        await expectLater(
          _service(preferences, credentials).migrate(),
          throwsA(isA<LlmAccountMigrationException>()),
        );

        expect(preferences.values['provider_entries'] == source, isTrue);
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
        final preferences = _MemoryLlmPreferences({'provider_entries': source});
        final credentials = _MemoryCredentialStore();

        await expectLater(
          _service(preferences, credentials).migrate(),
          throwsA(isA<LlmAccountMigrationException>()),
        );

        expect(preferences.values['provider_entries'], source);
        expect(
          credentials.values.containsKey('shared-credential-ref'),
          isFalse,
        );
        expect(credentials.writeReferences, isEmpty);
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
        final preferences = _MemoryLlmPreferences({'provider_entries': source});
        final credentials = _MemoryCredentialStore()
          ..values['shared-credential-ref'] = existingSecret;

        await expectLater(
          _service(preferences, credentials).migrate(),
          throwsA(isA<LlmAccountMigrationException>()),
        );

        expect(preferences.values['provider_entries'], source);
        expect(credentials.values['shared-credential-ref'], existingSecret);
        expect(credentials.writeReferences, isEmpty);
        expect(
          preferences.values[LlmAccountMigrationService.migrationStateKey],
          isNull,
        );
      },
    );

    test(
      'rejects a keyless shared reference before writing a later inline key',
      () async {
        final source = jsonEncode([
          {
            'id': 'shared-llm-entry',
            'type': 'llm',
            'name': 'Shared LLM entry',
            'configs': [
              {
                'id': 'keyless-provider',
                'providerName': 'Existing provider',
                'credentialRef': 'shared-credential-ref',
                'models': [],
              },
              {
                'id': 'keyed-provider',
                'providerName': 'New provider',
                'key': 'sk_new_shared_reference',
                'credentialRef': 'shared-credential-ref',
                'models': [],
              },
            ],
          },
        ]);
        final preferences = _MemoryLlmPreferences({'provider_entries': source});
        final credentials = _MemoryCredentialStore();

        await expectLater(
          _service(preferences, credentials).migrate(),
          throwsA(isA<LlmAccountMigrationException>()),
        );

        expect(preferences.values['provider_entries'], source);
        expect(
          preferences.values[LlmAccountMigrationService.accountsPreferenceKey],
          isNull,
        );
        expect(credentials.values, isEmpty);
        expect(credentials.writeReferences, isEmpty);
      },
    );

    test(
      'preserves an orphan account credential reference during conflict preflight',
      () async {
        const reference = 'shared-orphan-account-credential-ref';
        const existingSecret = 'sk_existing_orphan_account_secret';
        const incomingSecret = 'sk_incoming_orphan_account_secret';
        final source = jsonEncode([
          {
            'id': 'llm-entry',
            'type': 'llm',
            'configs': [
              {
                'id': 'incoming-account',
                'providerName': 'Incoming provider',
                'credentialRef': reference,
                'key': incomingSecret,
                'models': [],
              },
            ],
          },
        ]);
        final accounts = jsonEncode({
          'version': 1,
          'items': [
            {
              'id': 'retained-orphan-account',
              'credentialRef': reference,
              'models': [],
            },
          ],
        });
        final preferences = _MemoryLlmPreferences({
          'provider_entries': source,
          LlmAccountMigrationService.accountsPreferenceKey: accounts,
        });
        final credentials = _MemoryCredentialStore()
          ..values[reference] = existingSecret;

        await expectLater(
          _service(preferences, credentials).migrate(),
          throwsA(isA<LlmAccountMigrationException>()),
        );

        expect(preferences.values['provider_entries'], source);
        expect(
          preferences.values[LlmAccountMigrationService.accountsPreferenceKey],
          accounts,
        );
        expect(credentials.values[reference], existingSecret);
        expect(credentials.writeReferences, isEmpty);
      },
    );

    test(
      'rejects conflicting config and account credential references',
      () async {
        const accountId = 'conflicting-reference-account';
        const sourceReference = 'source-credential-reference';
        const accountReference = 'account-credential-reference';
        final source = jsonEncode([
          {
            'id': 'llm-entry',
            'type': 'llm',
            'configs': [
              {'id': accountId, 'credentialRef': sourceReference, 'models': []},
            ],
          },
        ]);
        final accounts = jsonEncode({
          'version': 1,
          'items': [
            {'id': accountId, 'credentialRef': accountReference, 'models': []},
          ],
        });
        final preferences = _MemoryLlmPreferences({
          'provider_entries': source,
          LlmAccountMigrationService.accountsPreferenceKey: accounts,
          LlmAccountMigrationService.modelGroupsPreferenceKey:
              '{"version":1,"items":[]}',
        });
        final credentials = _MemoryCredentialStore()
          ..values[sourceReference] = 'sk_source_reference_secret'
          ..values[accountReference] = 'sk_account_reference_secret';

        await expectLater(
          _service(preferences, credentials).migrate(),
          throwsA(isA<LlmAccountMigrationException>()),
        );

        expect(preferences.values['provider_entries'], source);
        expect(
          preferences.values[LlmAccountMigrationService.accountsPreferenceKey],
          accounts,
        );
        expect(
          credentials.values[sourceReference],
          'sk_source_reference_secret',
        );
        expect(
          credentials.values[accountReference],
          'sk_account_reference_secret',
        );
        expect(credentials.writeReferences, isEmpty);
      },
    );

    test(
      'does not accept credential fields elsewhere in a completed account envelope',
      () async {
        const secret = 'sk_envelope_auth_header_secret';
        const source = '[{"id":"llm-entry","type":"llm","configs":[]}]';
        const accounts =
            '{"version":1,"items":[],"authorizationHeader":"$secret"}';
        final preferences = _MemoryLlmPreferences({
          'provider_entries': source,
          LlmAccountMigrationService.accountsPreferenceKey: accounts,
          LlmAccountMigrationService.modelGroupsPreferenceKey:
              '{"version":1,"items":[]}',
          LlmAccountMigrationService.migrationStateKey:
              '{"version":1,"status":"complete"}',
        });

        await expectLater(
          _service(preferences, _MemoryCredentialStore()).migrate(),
          throwsA(isA<LlmAccountMigrationException>()),
        );

        expect(
          preferences.values[LlmAccountMigrationService
                  .accountsPreferenceKey] ==
              accounts,
          isTrue,
        );
        expect(preferences.values['provider_entries'] == source, isTrue);
      },
    );

    test(
      'rejects a complete-marker drift repair with a missing secure credential',
      () async {
        const source =
            '[{"id":"llm-entry","type":"llm","configs":[{"id":"drifted-account","credentialRef":"missing-secret-ref","models":[]}]}]';
        const accounts = '{"version":1,"items":[]}';
        const groups = '{"version":1,"items":[]}';
        final preferences = _MemoryLlmPreferences({
          'provider_entries': source,
          LlmAccountMigrationService.accountsPreferenceKey: accounts,
          LlmAccountMigrationService.modelGroupsPreferenceKey: groups,
          LlmAccountMigrationService.migrationStateKey:
              '{"version":1,"status":"complete"}',
        });

        await expectLater(
          _service(preferences, _MemoryCredentialStore()).migrate(),
          throwsA(isA<LlmAccountMigrationException>()),
        );

        expect(preferences.values['provider_entries'] == source, isTrue);
        expect(
          preferences.values[LlmAccountMigrationService.accountsPreferenceKey],
          accounts,
        );
        expect(
          preferences.values[LlmAccountMigrationService
              .modelGroupsPreferenceKey],
          groups,
        );
      },
    );

    test(
      'rejects nested model credential fields before copying model data',
      () async {
        const nestedSecret = 'sk_model_subscription_key_secret';
        const functionsKeySecret = 'sk_model_functions_key_secret';
        const proxyAuthorizationSecret = 'sk_model_proxy_authorization_secret';
        final source = jsonEncode([
          {
            'id': 'nested-credential-entry',
            'type': 'llm',
            'configs': [
              {
                'id': 'nested-credential-account',
                'key': _secret,
                'models': [
                  {
                    'id': 'safe-model-id',
                    'modelId': 'safe-upstream-model',
                    'headers': {
                      'Ocp-Apim-Subscription-Key': nestedSecret,
                      'x-functions-key': functionsKeySecret,
                      'proxy-authorization': proxyAuthorizationSecret,
                    },
                  },
                ],
              },
            ],
          },
        ]);
        final preferences = _MemoryLlmPreferences({'provider_entries': source});
        final credentials = _MemoryCredentialStore();

        await expectLater(
          _service(preferences, credentials).migrate(),
          throwsA(isA<LlmAccountMigrationException>()),
        );

        expect(preferences.values['provider_entries'] == source, isTrue);
        expect(
          preferences.values[LlmAccountMigrationService.accountsPreferenceKey],
          isNull,
        );
        expect(credentials.values, isEmpty);
        expect(credentials.writeReferences, isEmpty);
      },
    );

    test(
      'rejects function and proxy authorization headers before secure writes',
      () async {
        const headerCases = <Map<String, String>>[
          {'x-functions-key': 'sk_functions_header_secret'},
          {'proxy-authorization': 'sk_proxy_authorization_header_secret'},
        ];

        for (final headers in headerCases) {
          final source = jsonEncode([
            {
              'id': 'header-credential-entry',
              'type': 'llm',
              'configs': [
                {
                  'id': 'header-credential-account',
                  'key': _secret,
                  'models': [
                    {
                      'id': 'safe-model-id',
                      'modelId': 'safe-upstream-model',
                      'headers': headers,
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

          await expectLater(
            _service(preferences, credentials).migrate(),
            throwsA(isA<LlmAccountMigrationException>()),
          );

          expect(preferences.values['provider_entries'], source);
          expect(credentials.values, isEmpty);
          expect(credentials.writeReferences, isEmpty);
        }
      },
    );

    test(
      'removes stale generated members for the migrated account only',
      () async {
        const accountId = 'model-group-account';
        const localModelId = 'current-model';
        final groupId =
            'stroom.model-group.${Uri.encodeComponent(accountId).length}:$accountId${Uri.encodeComponent(localModelId).length}:$localModelId';
        final source = jsonEncode([
          {
            'id': 'llm-entry',
            'type': 'llm',
            'configs': [
              {
                'id': accountId,
                'models': [
                  {
                    'id': localModelId,
                    'modelId': 'new-upstream-model',
                    'name': 'Current model',
                  },
                ],
              },
            ],
          },
        ]);
        final preferences = _MemoryLlmPreferences({
          'provider_entries': source,
          LlmAccountMigrationService.modelGroupsPreferenceKey: jsonEncode({
            'version': 1,
            'items': [
              {
                'id': groupId,
                'displayName': 'User group name',
                'policy': {'strategy': 'balanceLower'},
                'members': [
                  {
                    'accountId': accountId,
                    'localModelId': localModelId,
                    'upstreamModelId': 'stale-upstream-model',
                    'priorityTier': 3,
                  },
                  {
                    'accountId': 'other-account',
                    'localModelId': localModelId,
                    'upstreamModelId': 'other-upstream-model',
                    'priorityTier': 2,
                  },
                ],
              },
            ],
          }),
        });

        await _service(preferences, _MemoryCredentialStore()).migrate();

        final savedGroup = _records(
          preferences.values[LlmAccountMigrationService
              .modelGroupsPreferenceKey]!,
        ).single;
        final members = (savedGroup['members'] as List).cast<Map>();
        expect(
          members.where((member) => member['accountId'] == accountId),
          hasLength(1),
        );
        expect(
          members.singleWhere(
            (member) => member['accountId'] == accountId,
          )['upstreamModelId'],
          'new-upstream-model',
        );
        expect(
          members.any((member) => member['accountId'] == 'other-account'),
          isTrue,
        );
        expect(savedGroup['displayName'], 'User group name');
        expect(savedGroup['policy'], {'strategy': 'balanceLower'});
      },
    );

    test(
      'removes stale membership when a migrated account has no models',
      () async {
        const accountId = 'empty-model-account';
        const staleModelId = 'removed-model';
        final groupId =
            'stroom.model-group.${Uri.encodeComponent(accountId).length}:$accountId${Uri.encodeComponent(staleModelId).length}:$staleModelId';
        final source = jsonEncode([
          {
            'id': 'llm-entry',
            'type': 'llm',
            'configs': [
              {'id': accountId, 'models': []},
            ],
          },
        ]);
        final preferences = _MemoryLlmPreferences({
          'provider_entries': source,
          LlmAccountMigrationService.modelGroupsPreferenceKey: jsonEncode({
            'version': 1,
            'items': [
              {
                'id': groupId,
                'displayName': 'Keep display name',
                'policy': {'strategy': 'priority'},
                'members': [
                  {
                    'accountId': accountId,
                    'localModelId': staleModelId,
                    'upstreamModelId': 'stale-upstream-model',
                    'priorityTier': 4,
                  },
                  {
                    'accountId': 'other-account',
                    'localModelId': staleModelId,
                    'upstreamModelId': 'other-model',
                    'priorityTier': 2,
                  },
                ],
              },
            ],
          }),
        });

        await _service(preferences, _MemoryCredentialStore()).migrate();

        final savedGroup = _records(
          preferences.values[LlmAccountMigrationService
              .modelGroupsPreferenceKey]!,
        ).single;
        final members = (savedGroup['members'] as List).cast<Map>();
        expect(
          members.any((member) => member['accountId'] == accountId),
          isFalse,
        );
        expect(members.single['accountId'], 'other-account');
        expect(savedGroup['displayName'], 'Keep display name');
        expect(savedGroup['policy'], {'strategy': 'priority'});
      },
    );

    test(
      'preserves cross-account model group membership during reconciliation',
      () async {
        const accountA = 'fallback-account';
        const accountB = 'group-owner-account';
        const localModelA = 'fallback-model';
        const localModelB = 'owner-model';
        String groupId(String accountId, String modelId) =>
            'stroom.model-group.${Uri.encodeComponent(accountId).length}:$accountId${Uri.encodeComponent(modelId).length}:$modelId';
        final ownerGroupId = groupId(accountB, localModelB);
        final source = jsonEncode([
          {
            'id': 'llm-entry',
            'type': 'llm',
            'configs': [
              {
                'id': accountA,
                'models': [
                  {
                    'id': localModelA,
                    'modelId': 'fallback-upstream-model',
                    'name': 'Fallback model',
                  },
                ],
              },
              {
                'id': accountB,
                'models': [
                  {
                    'id': localModelB,
                    'modelId': 'owner-upstream-model',
                    'name': 'Owner model',
                  },
                ],
              },
            ],
          },
        ]);
        final preferences = _MemoryLlmPreferences({
          'provider_entries': source,
          LlmAccountMigrationService.modelGroupsPreferenceKey: jsonEncode({
            'version': 1,
            'items': [
              {
                'id': ownerGroupId,
                'displayName': 'Owner group',
                'policy': {'strategy': 'priority'},
                'members': [
                  {
                    'accountId': accountB,
                    'localModelId': localModelB,
                    'upstreamModelId': 'owner-upstream-model',
                    'priorityTier': 0,
                  },
                  {
                    'accountId': accountA,
                    'localModelId': localModelA,
                    'upstreamModelId': 'fallback-upstream-model',
                    'priorityTier': 1,
                  },
                ],
              },
            ],
          }),
        });

        await _service(preferences, _MemoryCredentialStore()).migrate();

        final savedGroup = _records(
          preferences.values[LlmAccountMigrationService
              .modelGroupsPreferenceKey]!,
        ).singleWhere((group) => group['id'] == ownerGroupId);
        final members = (savedGroup['members'] as List).cast<Map>();
        expect(
          members.any(
            (member) =>
                member['accountId'] == accountA &&
                member['upstreamModelId'] == 'fallback-upstream-model',
          ),
          isTrue,
        );
        expect(
          members.any(
            (member) =>
                member['accountId'] == accountB &&
                member['upstreamModelId'] == 'owner-upstream-model',
          ),
          isTrue,
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
          preferences.values[LlmAccountMigrationService
              .modelGroupsPreferenceKey]!,
        );
        expect(groups, hasLength(2));
        expect(groups[0]['id'], isNot(groups[1]['id']));
        expect(groups.map((group) => group['legacyProviderName']).toList(), [
          'First provider',
          'Second provider',
        ]);
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
        preferences.values['provider_entries']!.contains(_secret),
        isFalse,
      );
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
          expect(
            failure.toString().contains(_secret),
            isFalse,
            reason: boundary,
          );
          expect(
            preferences.values['provider_entries'] == source,
            isTrue,
            reason: boundary,
          );
          expect(credentials.values.isEmpty, isTrue, reason: boundary);

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
      'retains a new secure value when source preference rollback is incomplete',
      () async {
        final source = _legacyProviderEntries();
        final preferences = _MemoryLlmPreferences({'provider_entries': source});
        preferences.failWriteWhen = (key, value) =>
            key == LlmAccountMigrationService.migrationStateKey ||
            (key == 'provider_entries' && value == source);
        final credentials = _MemoryCredentialStore();

        await expectLater(
          _service(preferences, credentials).migrate(),
          throwsA(isA<LlmAccountMigrationException>()),
        );

        final savedSource = _decodeList(
          preferences.values['provider_entries']!,
        );
        expect(
          _configsFor(savedSource, 'llm').first.containsKey('key'),
          isFalse,
        );
        expect(credentials.values.values.contains(_secret), isTrue);
        expect(
          preferences.values[LlmAccountMigrationService.migrationStateKey],
          isNull,
        );
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
      'keeps settings unavailable and retries after secure reads recover',
      () async {
        SharedPreferences.setMockInitialValues({
          'provider_entries': _legacyProviderEntries(),
        });
        final credentials = _MemoryCredentialStore();
        final initialNotifier = ProviderEntriesNotifier(
          credentialStore: credentials,
        );
        await initialNotifier.load();
        final originalConfig = initialNotifier.state.entries
            .singleWhere((entry) => entry.id == 'llm-entry')
            .configs
            .first;
        final originalReference = originalConfig.credentialRef!;

        credentials.failReads = true;
        final notifier = ProviderEntriesNotifier(credentialStore: credentials);
        await notifier.load();
        expect(notifier.state.isLoaded, isFalse);
        expect(notifier.state.entries, isEmpty);
        final prefs = await SharedPreferences.getInstance();
        final savedConfig = _configsFor(
          _decodeList(prefs.getString('provider_entries')!),
          'llm',
        ).first;
        expect(savedConfig['credentialRef'], originalReference);
        expect(savedConfig.containsKey('key'), isFalse);
        expect(credentials.values[originalReference], _secret);

        credentials.failReads = false;
        await notifier.load();

        expect(notifier.state.isLoaded, isTrue);
        final loadedConfig = notifier.state.entries
            .singleWhere((item) => item.id == 'llm-entry')
            .configs
            .first;
        expect(loadedConfig.key == _secret, isTrue);
        expect(loadedConfig.credentialRef, originalReference);
        final account = _records(
          prefs.getString(LlmAccountMigrationService.accountsPreferenceKey)!,
        ).singleWhere((item) => item['id'] == loadedConfig.id);
        expect(account['credentialRef'], originalReference);
      },
    );

    test(
      'marks previously loaded settings unavailable after secure migration fails',
      () async {
        SharedPreferences.setMockInitialValues({
          'provider_entries': _legacyProviderEntries(),
        });
        final credentials = _MemoryCredentialStore();
        final notifier = ProviderEntriesNotifier(credentialStore: credentials);
        await notifier.load();
        expect(notifier.state.isLoaded, isTrue);

        final prefs = await SharedPreferences.getInstance();
        final entries = _decodeList(prefs.getString('provider_entries')!);
        final llmEntry = entries.singleWhere(
          (entry) => entry['id'] == 'llm-entry',
        );
        final config =
            (llmEntry['configs'] as List).first as Map<String, dynamic>;
        config['host'] = 'https://recovered-settings.example.test';
        await prefs.setString('provider_entries', jsonEncode(entries));

        credentials.failReads = true;
        await notifier.load();

        expect(notifier.state.isLoaded, isFalse);
        expect(notifier.state.entries, isEmpty);

        credentials.failReads = false;
        await notifier.update(
          'builtin_ocr',
          ProviderEntry(
            id: 'builtin_ocr',
            type: 'ocr',
            name: 'Recovered OCR provider',
          ),
        );

        expect(notifier.state.isLoaded, isTrue);
        expect(
          notifier.state.entries
              .singleWhere((entry) => entry.id == 'builtin_ocr')
              .name,
          'Recovered OCR provider',
        );
        expect(
          notifier.state.entries
              .singleWhere((entry) => entry.id == 'llm-entry')
              .configs
              .first
              .host,
          'https://recovered-settings.example.test',
        );
      },
    );

    test(
      'keeps settings unavailable and retries after secure hydration fails',
      () async {
        SharedPreferences.setMockInitialValues({
          'provider_entries': _legacyProviderEntries(),
        });
        final credentials = _MemoryCredentialStore();
        final notifier = ProviderEntriesNotifier(credentialStore: credentials);
        await notifier.load();
        expect(notifier.state.isLoaded, isTrue);

        // A completed migration reads the referenced credential during
        // migration preflight and reference validation, then notifier
        // hydration reads it a third time.
        credentials.readCount = 0;
        credentials.failOnReadNumber = 3;
        await notifier.load();

        expect(credentials.readCount, 3);
        expect(notifier.state.isLoaded, isFalse);
        expect(notifier.state.entries, isEmpty);

        credentials.failOnReadNumber = null;
        await notifier.update(
          'builtin_ocr',
          ProviderEntry(
            id: 'builtin_ocr',
            type: 'ocr',
            name: 'Recovered OCR provider',
          ),
        );

        expect(notifier.state.isLoaded, isTrue);
        expect(
          notifier.state.entries
              .singleWhere((entry) => entry.id == 'builtin_ocr')
              .name,
          'Recovered OCR provider',
        );
      },
    );

    test(
      'does not persist provider entries when the group preference write fails',
      () async {
        SharedPreferences.setMockInitialValues({
          'provider_entries': _legacyProviderEntries(),
        });
        final credentials = _MemoryCredentialStore();
        final notifier = ProviderEntriesNotifier(credentialStore: credentials);
        await notifier.load();
        final prefs = await SharedPreferences.getInstance();
        final entriesBefore = prefs.getString('provider_entries')!;
        final groupsBefore = prefs.getString('mcp_provider_groups');
        final previousStore = SharedPreferencesStorePlatform.instance;
        final initialValues = <String, Object>{
          for (final key in prefs.getKeys()) 'flutter.$key': prefs.get(key)!,
        };
        SharedPreferencesStorePlatform.instance =
            _RejectOnePreferenceWriteStore(
              initialValues,
              rejectedKey: 'mcp_provider_groups',
            );
        addTearDown(
          () => SharedPreferencesStorePlatform.instance = previousStore,
        );

        final entry = notifier.state.entries.singleWhere(
          (item) => item.id == 'llm-entry',
        );
        final oldConfig = entry.configs.first;
        final attemptedConfig = oldConfig.copy()
          ..host = 'https://failed-paired-write.example.test';
        final attemptedEntry = ProviderEntry(
          id: entry.id,
          type: entry.type,
          name: entry.name,
          configs: [attemptedConfig, ...entry.configs.skip(1)],
        );

        await expectLater(
          notifier.update(entry.id, attemptedEntry),
          throwsA(isA<StateError>()),
        );

        expect(
          notifier.state.entries
              .singleWhere((item) => item.id == 'llm-entry')
              .configs
              .first
              .host,
          oldConfig.host,
        );
        final persistedConfig = _configsFor(
          _decodeList(prefs.getString('provider_entries')!),
          'llm',
        ).first;
        expect(persistedConfig['host'], oldConfig.host);
        expect(prefs.getString('mcp_provider_groups'), groupsBefore);
      },
    );

    test(
      'rolls back MCP groups when secure migration fails during load persistence',
      () async {
        SharedPreferences.setMockInitialValues({
          'provider_entries': _legacyProviderEntries(),
        });
        final credentials = _MemoryCredentialStore();
        final notifier = ProviderEntriesNotifier(credentialStore: credentials);
        notifier.addListener((state) {
          if (state.isLoaded) credentials.failReads = true;
        });

        await notifier.load();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('mcp_provider_groups'), isNull);
      },
    );

    test(
      'does not restore stale state when an earlier concurrent mutation fails',
      () async {
        SharedPreferences.setMockInitialValues({
          'provider_entries': _legacyProviderEntries(),
        });
        final credentials = _MemoryCredentialStore();
        final notifier = ProviderEntriesNotifier(credentialStore: credentials);
        await notifier.load();

        final prefs = await SharedPreferences.getInstance();
        final previousStore = SharedPreferencesStorePlatform.instance;
        final initialValues = <String, Object>{
          for (final key in prefs.getKeys()) 'flutter.$key': prefs.get(key)!,
        };
        final blockingStore = _BlockFirstMcpGroupWriteStore(initialValues);
        SharedPreferencesStorePlatform.instance = blockingStore;
        addTearDown(
          () => SharedPreferencesStorePlatform.instance = previousStore,
        );

        ProviderEntry named(ProviderEntry source, String name) => ProviderEntry(
          id: source.id,
          type: source.type,
          name: name,
          configs: source.configs.map((config) => config.copy()).toList(),
          enabled: source.enabled,
          legacyFields: source.legacyFields,
        );

        final ocr = notifier.state.entries.singleWhere(
          (entry) => entry.id == 'builtin_ocr',
        );
        final asr = notifier.state.entries.singleWhere(
          (entry) => entry.id == 'builtin_asr',
        );
        final first = notifier.update(
          ocr.id,
          named(ocr, 'First successful edit'),
        );
        await blockingStore.firstMcpGroupWriteStarted.future;

        await notifier.update(asr.id, named(asr, 'Later successful edit'));
        blockingStore.releaseFirstMcpGroupWrite.complete();
        await expectLater(first, throwsA(isA<StateError>()));

        expect(
          notifier.state.entries
              .singleWhere((entry) => entry.id == ocr.id)
              .name,
          'First successful edit',
        );
        expect(
          notifier.state.entries
              .singleWhere((entry) => entry.id == asr.id)
              .name,
          'Later successful edit',
        );
        final persisted = _decodeList(prefs.getString('provider_entries')!);
        expect(
          persisted.singleWhere((entry) => entry['id'] == ocr.id)['name'],
          'First successful edit',
        );
        expect(
          persisted.singleWhere((entry) => entry['id'] == asr.id)['name'],
          'Later successful edit',
        );
      },
    );

    test(
      'serializes concurrent migrations that reuse one credential reference',
      () async {
        const reference = 'stroom.llm.credential.concurrent-reference';
        String sourceFor(String key) => jsonEncode([
          {
            'id': 'concurrent-llm-entry',
            'type': 'llm',
            'configs': [
              {
                'id': 'concurrent-account',
                'credentialRef': reference,
                'key': key,
                'models': [],
              },
            ],
          },
        ]);

        final preferences = _MemoryLlmPreferences({'provider_entries': '[]'});
        final credentials = _MemoryCredentialStore();
        final firstWriteStarted = Completer<void>();
        final releaseFirstWrite = Completer<void>();
        var writesObserved = 0;
        credentials.onWrite = (writtenReference, _) async {
          if (writtenReference != reference) return;
          writesObserved++;
          if (writesObserved == 1) {
            firstWriteStarted.complete();
            await releaseFirstWrite.future;
          }
        };

        final first = _service(preferences, credentials).migrate(
          sourceProviderEntriesJson: sourceFor('sk_first_concurrent_value'),
        );
        await firstWriteStarted.future;
        final second = _service(preferences, credentials).migrate(
          sourceProviderEntriesJson: sourceFor('sk_second_concurrent_value'),
        );
        await Future<void>.delayed(Duration.zero);
        final overlappingWrite = writesObserved > 1;
        releaseFirstWrite.complete();
        await Future.wait([first, second]);

        expect(overlappingWrite, isFalse);
        expect(writesObserved, 2);
        final persistedSource =
            jsonDecode(preferences.values['provider_entries']!) as List;
        final persistedConfig =
            ((persistedSource.single as Map)['configs'] as List).single as Map;
        expect(persistedConfig['credentialRef'], reference);
        expect(persistedConfig.containsKey('key'), isFalse);
        expect(credentials.values[reference], 'sk_second_concurrent_value');
      },
    );

    test(
      'secure-store failure keeps legacy credentials and safe diagnostics',
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
        final persistedEntries =
            jsonDecode(prefs.getString('provider_entries')!) as List;
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
        expect(notifier.state.isLoaded, isFalse);

        credentials.failAllWrites = false;
        await notifier.load();

        expect(notifier.state.isLoaded, isTrue);
        expect(
          notifier.state.entries
              .singleWhere((entry) => entry.id == 'llm-entry')
              .configs
              .first
              .key,
          _secret,
        );
      },
    );

    test(
      'default update reports failure and restores the prior state',
      () async {
        SharedPreferences.setMockInitialValues({
          'provider_entries': _legacyProviderEntries(),
        });
        final credentials = _MemoryCredentialStore();
        final notifier = ProviderEntriesNotifier(credentialStore: credentials);
        await notifier.load();

        final previousEntry = notifier.state.entries.singleWhere(
          (entry) => entry.id == 'llm-entry',
        );
        final previousConfig = previousEntry.configs.first;
        credentials.failAllWrites = true;
        final changedConfig = previousConfig.copy()
          ..key = 'sk_failed_default_update';
        final changedEntry = ProviderEntry(
          id: previousEntry.id,
          type: previousEntry.type,
          name: previousEntry.name,
          configs: [changedConfig, ...previousEntry.configs.skip(1)],
        );

        await expectLater(
          notifier.update(previousEntry.id, changedEntry),
          throwsA(isA<StateError>()),
        );

        expect(
          notifier.state.entries
              .singleWhere((entry) => entry.id == previousEntry.id)
              .configs
              .first
              .key,
          _secret,
        );
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs
              .getString('provider_entries')!
              .contains('sk_failed_default_update'),
          isFalse,
        );
      },
    );

    test(
      'addFirst reports secure migration failure and restores prior state',
      () async {
        SharedPreferences.setMockInitialValues({
          'provider_entries': _legacyProviderEntries(),
        });
        final credentials = _MemoryCredentialStore();
        final notifier = ProviderEntriesNotifier(credentialStore: credentials);
        await notifier.load();

        final previousIds = notifier.state.entries
            .map((entry) => entry.id)
            .toSet();
        credentials.failReads = true;
        final added = ProviderEntry(
          id: 'failed-add-first-entry',
          type: 'ocr',
          name: 'New OCR provider',
        );

        await expectLater(notifier.addFirst(added), throwsA(isA<StateError>()));

        expect(
          notifier.state.entries.map((entry) => entry.id).toSet(),
          previousIds,
        );
        final prefs = await SharedPreferences.getInstance();
        expect(
          (jsonDecode(prefs.getString('provider_entries')!) as List)
              .whereType<Map>()
              .any((entry) => entry['id'] == added.id),
          isFalse,
        );
      },
    );

    test(
      'reloads concurrent settings before the next mutation after failure',
      () async {
        final initialEntries = _decodeList(_legacyProviderEntries())
          ..add({
            'id': 'other-entry',
            'type': 'ocr',
            'name': 'Original OCR',
            'configs': <Map<String, dynamic>>[],
          });
        SharedPreferences.setMockInitialValues({
          'provider_entries': jsonEncode(initialEntries),
        });
        final credentials = _MemoryCredentialStore();
        final notifier = ProviderEntriesNotifier(credentialStore: credentials);
        await notifier.load();

        final prefs = await SharedPreferences.getInstance();
        final externalEntries = _decodeList(
          prefs.getString('provider_entries')!,
        );
        final externalLlm = externalEntries.singleWhere(
          (entry) => entry['id'] == 'llm-entry',
        );
        final externalConfig =
            (externalLlm['configs'] as List).first as Map<String, dynamic>;
        externalConfig['host'] = 'https://concurrent.example.test';
        externalLlm['name'] = 'Concurrent LLM settings';
        final externalJson = jsonEncode(externalEntries);
        credentials.onWrite = (_, __) async {
          await prefs.setString('provider_entries', externalJson);
          throw const LlmCredentialStoreException();
        };

        final llmEntry = notifier.state.entries.singleWhere(
          (entry) => entry.id == 'llm-entry',
        );
        final changedLlmConfig = llmEntry.configs.first.copy()
          ..key = 'sk_concurrent_failed_write';
        await expectLater(
          notifier.update(
            llmEntry.id,
            ProviderEntry(
              id: llmEntry.id,
              type: llmEntry.type,
              name: llmEntry.name,
              configs: [changedLlmConfig, ...llmEntry.configs.skip(1)],
            ),
          ),
          throwsA(isA<StateError>()),
        );

        credentials.onWrite = null;
        final otherEntry = notifier.state.entries.singleWhere(
          (entry) => entry.id == 'other-entry',
        );
        await notifier.update(
          otherEntry.id,
          ProviderEntry(
            id: otherEntry.id,
            type: otherEntry.type,
            name: 'Updated OCR',
            configs: otherEntry.configs,
          ),
        );

        final persisted = _decodeList(prefs.getString('provider_entries')!);
        final savedLlm = persisted.singleWhere(
          (entry) => entry['id'] == 'llm-entry',
        );
        final savedConfig = (savedLlm['configs'] as List).first as Map;
        expect(savedLlm['name'], 'Concurrent LLM settings');
        expect(savedConfig['host'], 'https://concurrent.example.test');
      },
    );
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
  {'id': 'builtin_tts', 'type': 'tts', 'name': 'TTS providers', 'configs': []},
]);

List<Map<String, dynamic>> _decodeList(String value) =>
    (jsonDecode(value) as List).cast<Map<String, dynamic>>();

List<Map<String, dynamic>> _configsFor(
  List<Map<String, dynamic>> entries,
  String type,
) => [
  for (final entry in entries.where((item) => item['type'] == type))
    ...(entry['configs'] as List).cast<Map<String, dynamic>>(),
];

List<Map<String, dynamic>> _records(String envelopeJson) =>
    (jsonDecode(envelopeJson) as Map<String, dynamic>)['items']
            .cast<Map<String, dynamic>>()
        as List<Map<String, dynamic>>;

LlmAccountMigrationService _service(
  _MemoryLlmPreferences preferences,
  _MemoryCredentialStore credentials,
) => LlmAccountMigrationService(
  preferences: preferences,
  credentialStore: credentials,
);

class _MemoryLlmPreferences implements LlmAccountPreferences {
  final Map<String, String> values;
  final List<String> writeHistory = [];
  String? failNextWriteKey;
  bool Function(String key, String value)? failWriteWhen;

  _MemoryLlmPreferences([Map<String, String>? initialValues])
    : values = Map<String, String>.from(initialValues ?? {});

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<bool> setString(String key, String value) async {
    writeHistory.add(key);
    if (failNextWriteKey == key || failWriteWhen?.call(key, value) == true) {
      failNextWriteKey = null;
      return false;
    }
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }
}

class _MemoryCredentialStore implements LlmCredentialStore {
  final Map<String, String> values = {};
  final List<String> writeReferences = [];
  Future<void> Function(String reference, String secret)? onWrite;
  bool failNextWrite = false;
  bool failAllWrites = false;
  bool failReads = false;
  int readCount = 0;
  int? failOnReadNumber;

  int get writeCount => writeReferences.length;

  @override
  Future<String?> read(String reference) async {
    readCount++;
    if (failReads || readCount == failOnReadNumber) {
      throw const LlmCredentialStoreException();
    }
    return values[reference];
  }

  @override
  Future<void> write(String reference, String secret) async {
    writeReferences.add(reference);
    await onWrite?.call(reference, secret);
    if (failNextWrite || failAllWrites) {
      failNextWrite = false;
      throw const LlmCredentialStoreException();
    }
    values[reference] = secret;
  }

  @override
  Future<void> delete(String reference) async => values.remove(reference);
}

class _RejectOnePreferenceWriteStore extends InMemorySharedPreferencesStore {
  final String rejectedKey;
  bool _rejected = false;

  _RejectOnePreferenceWriteStore(
    Map<String, Object> values, {
    required this.rejectedKey,
  }) : super.withData(values);

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (!_rejected && key == 'flutter.$rejectedKey') {
      _rejected = true;
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}

class _BlockFirstMcpGroupWriteStore extends InMemorySharedPreferencesStore {
  final Completer<void> firstMcpGroupWriteStarted = Completer<void>();
  final Completer<void> releaseFirstMcpGroupWrite = Completer<void>();
  var _blocked = false;

  _BlockFirstMcpGroupWriteStore(Map<String, Object> values)
    : super.withData(values);

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (!_blocked && key == 'flutter.mcp_provider_groups') {
      _blocked = true;
      firstMcpGroupWriteStarted.complete();
      await releaseFirstMcpGroupWrite.future;
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}
