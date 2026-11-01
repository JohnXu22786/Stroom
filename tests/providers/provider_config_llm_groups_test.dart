import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/llm_account.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/llm_account_migration_service.dart';
import 'package:stroom/services/llm_chat_runtime.dart';
import 'package:stroom/services/llm_credential_store.dart';
import 'package:stroom/services/llm_connector_service.dart';
import 'package:stroom/services/llm_routing_service.dart';
import 'package:stroom/services/llm_model_group_provider.dart';
import 'package:stroom/utils/provider_models.dart';

void main() {
  test('requires the OAuth flow for auth identity changes', () async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final gateway = await _createTestGateway();
    final codexApiKey = await gateway.accountManagement.saveAccount(
      AiGatewayAccount(
        id: 'codex-auth-transition',
        connectorType: 'codex',
        authType: 'api_key',
        displayName: 'Codex',
      ),
      secret: 'codex-api-key',
    );
    final claudeApiKey = await gateway.accountManagement.saveAccount(
      AiGatewayAccount(
        id: 'claude-unsupported-oauth',
        connectorType: 'claude',
        authType: 'api_key',
        displayName: 'Claude',
      ),
      secret: 'claude-api-key',
    );

    await expectLater(
      gateway.accountManagement.saveAccount(
        AiGatewayAccount(
          id: codexApiKey.id,
          connectorType: 'codex',
          authType: 'oauth',
          displayName: 'Codex',
        ),
      ),
      throwsA(isA<AiGatewayOAuthException>()),
    );
    await expectLater(
      gateway.accountManagement.saveAccount(
        AiGatewayAccount(
          id: codexApiKey.id,
          connectorType: 'codex',
          authType: 'oauth',
          displayName: 'Codex',
        ),
        secret: jsonEncode({'access_token': 'fabricated-access-token'}),
      ),
      throwsA(isA<AiGatewayOAuthException>()),
    );
    await expectLater(
      gateway.accountManagement.saveAccount(
        AiGatewayAccount(
          id: claudeApiKey.id,
          connectorType: 'claude',
          authType: 'oauth',
          displayName: 'Claude Code',
        ),
        secret: jsonEncode({'access_token': 'cli-only-token'}),
      ),
      throwsA(isA<AiGatewayOAuthException>()),
    );
  });

  test('Gateway account and group DTOs project into selector configs', () {
    final account = AiGatewayAccount(
      id: 'account-a',
      connectorType: 'openai',
      authType: 'api_key',
      displayName: 'Account A',
      models: [
        AiGatewayUpstreamModel(
          id: 'upstream-model',
          upstreamModelId: 'gpt-4.1',
          displayName: 'GPT 4.1',
          capabilities: const {'vision': true, 'streaming': true},
        ),
      ],
    );
    final group = AiGatewayModelGroup(
      id: stableLlmModelGroupId('account-a', 'local-model'),
      displayName: 'Local model',
      members: const [
        AiGatewayModelGroupMember(
          accountId: 'account-a',
          upstreamModelId: 'gpt-4.1',
          localModelId: 'local-model',
        ),
      ],
    );

    final config = buildGatewayModelGroupProviderConfigs(
      accounts: [account],
      groups: [group],
      providerCatalog: _GatewayProviderCatalog(),
    ).single;

    expect(config.id, group.id);
    expect(config.models.single.id, 'local-model');
    expect(config.models.single.modelId, 'gpt-4.1');
    expect(
      llmModelConfigSupportsCapability(config.models.single, 'vision'),
      isTrue,
    );
  });

  test(
    'legacy rows for unsupported native connectors stay out of chat selectors',
    () async {
      final legacyEntry = ProviderEntry(
        id: 'legacy-llm-entry',
        type: 'llm',
        name: 'Legacy LLM',
        configs: [
          ProviderConfigItem(
            id: 'legacy-codex-account',
            providerName: 'Legacy Codex',
            host: 'https://legacy.example.test/v1',
            key: 'codex-secret',
            endpointType: 'openai',
            legacyFields: {'connectorType': 'codex', 'authType': 'api_key'},
            models: [
              ModelConfig(
                id: 'codex-local-model',
                name: 'Codex model',
                modelId: 'gpt-5-codex',
              ),
            ],
          ),
        ],
      );
      SharedPreferences.setMockInitialValues({
        'provider_entries': jsonEncode([legacyEntry.toMap()]),
      });
      final container = ProviderContainer(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(
              credentialStore: _MemoryCredentialStore(),
              gatewayFactory: _createTestGateway,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(providerEntriesProvider.notifier).load();
      final state = container.read(providerEntriesProvider);

      expect(flattenProviderModels(state, 'llm'), isEmpty);
    },
  );

  test(
    'legacy rows return to chat selectors after switching to a supported connector',
    () {
      final legacyConfig = ProviderConfigItem(
        id: 'legacy-account',
        providerName: 'Legacy account',
        host: 'https://legacy.example.test/v1',
        key: 'legacy-secret',
        endpointType: 'openai',
        legacyFields: {'connectorType': 'codex', 'authType': 'api_key'},
        models: [
          ModelConfig(
            id: 'legacy-model',
            name: 'Legacy model',
            modelId: 'gpt-5-codex',
          ),
        ],
      );
      final unsupportedAccount = LlmAccount(
        id: legacyConfig.id,
        connectorType: 'codex',
        authType: 'api_key',
        displayName: 'Legacy account',
      );
      final marked = markUnsupportedLegacyLlmConfigs(
        [legacyConfig],
        [unsupportedAccount],
      ).single;
      expect(isUnsupportedLegacyLlmSelectorConfig(marked), isTrue);

      final supportedAccount = LlmAccount(
        id: legacyConfig.id,
        connectorType: 'openai-compatibility',
        authType: 'api_key',
        displayName: 'Legacy account',
      );
      final restored = markUnsupportedLegacyLlmConfigs(
        [marked],
        [supportedAccount],
      ).single;

      expect(isUnsupportedLegacyLlmSelectorConfig(restored), isFalse);
      expect(restored.host, legacyConfig.host);
      expect(restored.key, legacyConfig.key);
      expect(restored.models, hasLength(1));
      expect(
        flattenProviderModels(
          ProviderEntriesState(
            entries: [
              ProviderEntry(
                id: 'llm-entry',
                type: 'llm',
                name: 'LLM',
                configs: [restored],
              ),
            ],
          ),
          'llm',
        ),
        hasLength(1),
      );
    },
  );

  test(
    'removes the legacy OCR source before its migrated account is deleted',
    () {
      const sourceConfigId = 'legacy-ocr-provider';
      final account = LlmAccount(
        id: 'ocr-$sourceConfigId',
        connectorType: 'openai-compatibility',
        authType: 'api_key',
        displayName: 'Legacy OCR account',
        endpointConfig: {'legacyOcrProviderConfigId': sourceConfigId},
      );
      final state = ProviderEntriesState(
        entries: [
          ProviderEntry(
            id: 'llm-entry',
            type: 'llm',
            name: 'LLM',
            configs: [
              ProviderConfigItem(id: account.id),
              ProviderConfigItem(id: 'other-llm'),
            ],
          ),
          ProviderEntry(
            id: 'ocr-entry',
            type: 'ocr',
            name: 'OCR',
            configs: [
              ProviderConfigItem(id: sourceConfigId),
              ProviderConfigItem(id: 'other-ocr'),
            ],
          ),
        ],
      );

      final updated = removeLegacyLlmAccountSourceConfigs(state, account);

      expect(
        updated.entries
            .firstWhere((entry) => entry.type == 'llm')
            .configs
            .map((config) => config.id),
        ['other-llm'],
      );
      expect(
        updated.entries
            .firstWhere((entry) => entry.type == 'ocr')
            .configs
            .map((config) => config.id),
        ['other-ocr'],
      );
    },
  );

  test(
    'model-group selector adapters are never written to provider entries',
    () async {
      const accountId = 'group-account';
      const localModelId = 'local-model';
      final groupId = stableLlmModelGroupId(accountId, localModelId);
      final account = LlmAccount(
        id: accountId,
        connectorType: 'openai-compatibility',
        authType: 'none',
        displayName: 'Group account',
        status: LlmAccountStatus.ready,
        models: const [
          LlmUpstreamModel(
            id: localModelId,
            upstreamModelId: 'gpt-4o-mini',
            displayName: 'GPT-4o mini',
          ),
        ],
      );
      final group = LlmModelGroup(
        id: groupId,
        displayName: 'GPT-4o mini',
        members: const [
          LlmModelGroupMember(
            accountId: accountId,
            upstreamModelId: 'gpt-4o-mini',
            localModelId: localModelId,
          ),
        ],
      );
      SharedPreferences.setMockInitialValues({
        LlmAccountMigrationService.accountsPreferenceKey: jsonEncode({
          'version': 1,
          'items': [account.toMap()],
        }),
        LlmAccountMigrationService.modelGroupsPreferenceKey: jsonEncode({
          'version': 1,
          'items': [group.toMap()],
        }),
      });
      final container = ProviderContainer(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(
              credentialStore: _MemoryCredentialStore(),
              gatewayFactory: _createTestGateway,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(providerEntriesProvider.notifier);
      await notifier.load();
      final state = container.read(providerEntriesProvider);
      final groupConfig = state.entries
          .firstWhere((entry) => entry.type == 'llm')
          .configs
          .singleWhere(isLlmModelGroupProviderConfig);
      expect(groupConfig.id, groupId);
      expect(groupConfig.host, isEmpty);
      expect(groupConfig.key, isEmpty);

      await notifier.update(
        'builtin_llm',
        ProviderEntry(
          id: 'builtin_llm',
          type: 'llm',
          name: 'Updated LLM entry',
          configs: [groupConfig],
        ),
      );

      final preferences = await SharedPreferences.getInstance();
      final persisted = preferences.getString('provider_entries')!;
      expect(persisted, isNot(contains(kLlmModelGroupConfigField)));
      expect(persisted, isNot(contains(groupId)));
      expect(
        preferences.getString(
          LlmAccountMigrationService.modelGroupsPreferenceKey,
        ),
        contains(groupId),
      );
    },
  );
}

class _MemoryCredentialStore implements LlmCredentialStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String reference) async {
    values.remove(reference);
  }

  @override
  Future<String?> read(String reference) async => values[reference];

  @override
  Future<void> write(String reference, String value) async {
    values[reference] = value;
  }
}

class _GatewayProviderCatalog implements AiGatewayProviderCatalog {
  @override
  Iterable<AiGatewayProviderDefinition> get providers => const [
        AiGatewayProviderDefinition(
          id: 'openai',
          displayName: 'OpenAI',
          supportedAuthTypes: {'api_key'},
          supportsChatAdapter: true,
          chatProtocolId: 'openai',
        ),
      ];

  @override
  AiGatewayProviderDefinition? findProvider(String providerId) {
    for (final provider in providers) {
      if (provider.id == providerId) return provider;
    }
    return null;
  }
}

Future<AiGatewayFacade> _createTestGateway() async {
  final preferences = await SharedPreferences.getInstance();
  final accountService = LlmAccountConnectorService(
    preferences: _SharedPreferencesLlmAccountPreferences(preferences),
    credentialStore: _MemoryCredentialStore(),
  );
  return LlmChatRoutingRuntime(
    accountService: accountService,
    routingService: LlmRoutingService(accountService: accountService),
  );
}

class _SharedPreferencesLlmAccountPreferences implements LlmAccountPreferences {
  final SharedPreferences _preferences;

  const _SharedPreferencesLlmAccountPreferences(this._preferences);

  @override
  Future<String?> getString(String key) async => _preferences.getString(key);

  @override
  Future<bool> remove(String key) => _preferences.remove(key);

  @override
  Future<bool> setString(String key, String value) =>
      _preferences.setString(key, value);
}
