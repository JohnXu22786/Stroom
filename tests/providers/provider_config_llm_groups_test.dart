import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/llm_account.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/llm_account_migration_service.dart';
import 'package:stroom/services/llm_chat_runtime.dart';
import 'package:stroom/services/llm_credential_store.dart';
import 'package:stroom/services/llm_model_group_provider.dart';
import 'package:stroom/utils/provider_models.dart';

void main() {
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
  @override
  Future<void> delete(String reference) async {}

  @override
  Future<String?> read(String reference) async => null;

  @override
  Future<void> write(String reference, String value) async {}
}
