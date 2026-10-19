import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/llm_account.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/llm_chat_runtime.dart';
import 'package:stroom/services/llm_model_group_provider.dart';
import 'package:stroom/utils/provider_models.dart';

void main() {
  test('only synthesizes selectors for ChatAdapter protocols', () {
    final account = LlmAccount(
      id: 'codex-account',
      connectorType: 'codex',
      authType: 'api_key',
      displayName: 'Codex account',
      models: const [
        LlmUpstreamModel(
          id: 'codex-model',
          upstreamModelId: 'gpt-5-codex',
          displayName: 'GPT 5 Codex',
        ),
      ],
    );
    final group = LlmModelGroup(
      id: 'codex-group',
      displayName: 'Codex group',
      members: const [
        LlmModelGroupMember(
          accountId: 'codex-account',
          localModelId: 'codex-model',
          upstreamModelId: 'gpt-5-codex',
        ),
      ],
    );

    expect(
      buildLlmModelGroupProviderConfigs(accounts: [account], groups: [group]),
      isEmpty,
    );
    expect(llmChatEndpointTypeForConnector(account.connectorType), isNull);
  });

  test(
    'selectors expose stable groups while old model references still resolve',
    () {
      final account = LlmAccount(
        id: 'legacy-account',
        connectorType: 'openai-compatibility',
        authType: 'api_key',
        displayName: 'Legacy provider',
        status: LlmAccountStatus.ready,
        models: [
          LlmUpstreamModel(
            id: 'legacy-local-model',
            upstreamModelId: 'gpt-4o',
            displayName: 'GPT-4o',
            capabilities: {'streaming': true},
            config: const {'id': 'legacy-local-model', 'modelId': 'gpt-4o'},
          ),
        ],
      );
      final groupId = stableLlmModelGroupId(account.id, 'legacy-local-model');
      final group = LlmModelGroup(
        id: groupId,
        displayName: 'GPT-4o',
        members: const [
          LlmModelGroupMember(
            accountId: 'legacy-account',
            upstreamModelId: 'gpt-4o',
            localModelId: 'legacy-local-model',
          ),
        ],
      );
      final legacyConfig = ProviderConfigItem(
        id: account.id,
        providerName: account.displayName,
        host: 'https://legacy.example.test/v1',
        key: 'legacy-secret',
        models: [
          ModelConfig(
            id: 'legacy-local-model',
            name: 'GPT-4o',
            modelId: 'gpt-4o',
          ),
        ],
      );
      final groupConfig = buildLlmModelGroupProviderConfigs(
        accounts: [account],
        groups: [group],
      ).single;
      final customGroupConfig = buildLlmModelGroupProviderConfigs(
        accounts: [account],
        groups: [
          LlmModelGroup(
            id: 'custom-group',
            displayName: 'Preferred group',
            members: group.members,
          ),
        ],
      ).single;
      expect(groupConfig.providerName, account.displayName);
      expect(customGroupConfig.providerName, 'Preferred group');
      expect(customGroupConfig.models.single.name, 'GPT-4o');
      final state = ProviderEntriesState(
        entries: [
          ProviderEntry(
            id: 'llm',
            type: 'llm',
            name: 'LLM',
            configs: [legacyConfig, groupConfig],
          ),
        ],
      );

      final selected = flattenProviderModels(state, 'llm');
      expect(selected, hasLength(1));
      expect(selected.single.config.id, groupId);
      expect(selected.single.model.id, 'legacy-local-model');
      expect(selected.single.config.host, isEmpty);
      expect(selected.single.config.key, isEmpty);
      expect(
        resolveProviderModel(state, 'llm', {
          'configId': account.id,
          'modelId': 'legacy-local-model',
        })?.config,
        same(legacyConfig),
      );
      expect(
        resolveProviderModel(state, 'llm', {
          'configId': groupId,
          'modelId': 'legacy-local-model',
        })?.config,
        same(groupConfig),
      );
      expect(flattenProviderModels(state, 'ocr'), isEmpty);
    },
  );

  test(
    'OCR selector exposes groups with at least one vision capable member',
    () {
      final textOnly = LlmAccount(
        id: 'text-only',
        connectorType: 'openai-compatibility',
        authType: 'none',
        displayName: 'Text only',
        status: LlmAccountStatus.ready,
        models: const [
          LlmUpstreamModel(
            id: 'text-only-model',
            upstreamModelId: 'text-model',
            displayName: 'Text model',
          ),
        ],
      );
      final vision = LlmAccount(
        id: 'vision',
        connectorType: 'openai-compatibility',
        authType: 'none',
        displayName: 'Vision',
        status: LlmAccountStatus.ready,
        models: const [
          LlmUpstreamModel(
            id: 'vision-model',
            upstreamModelId: 'vision-model',
            displayName: 'Vision model',
            capabilities: {'vision': true},
          ),
        ],
      );
      final groups = [
        LlmModelGroup(
          id: 'vision-group',
          displayName: 'Vision group',
          members: const [
            LlmModelGroupMember(
              accountId: 'text-only',
              localModelId: 'ocr-model',
              upstreamModelId: 'text-model',
            ),
            LlmModelGroupMember(
              accountId: 'vision',
              localModelId: 'ocr-model',
              upstreamModelId: 'vision-model',
            ),
          ],
        ),
        LlmModelGroup(
          id: 'text-only-group',
          displayName: 'Text-only group',
          members: const [
            LlmModelGroupMember(
              accountId: 'text-only',
              localModelId: 'text-model',
              upstreamModelId: 'text-model',
            ),
          ],
        ),
      ];
      final state = ProviderEntriesState(
        entries: [
          ProviderEntry(
            id: 'llm',
            type: 'llm',
            name: 'LLM',
            configs: buildLlmModelGroupProviderConfigs(
              accounts: [textOnly, vision],
              groups: groups,
            ),
          ),
        ],
      );

      expect(
        flattenProviderModels(
          state,
          'ocr',
        ).map((option) => option.config.id).toList(),
        ['vision-group'],
      );
    },
  );

  test(
    'selector capabilities follow the first upstream model selected by routing',
    () {
      const duplicateUpstreamId = 'shared-upstream-model';
      final account = LlmAccount(
        id: 'duplicate-model-account',
        connectorType: 'openai-compatibility',
        authType: 'none',
        displayName: 'Duplicate model account',
        status: LlmAccountStatus.ready,
        models: const [
          LlmUpstreamModel(
            id: 'first-local-model',
            upstreamModelId: duplicateUpstreamId,
            displayName: 'First text model',
          ),
          LlmUpstreamModel(
            id: 'second-local-model',
            upstreamModelId: duplicateUpstreamId,
            displayName: 'Second vision model',
            capabilities: {'vision': true},
          ),
        ],
      );
      final group = LlmModelGroup(
        id: 'duplicate-upstream-group',
        displayName: 'Duplicate upstream group',
        members: const [
          LlmModelGroupMember(
            accountId: 'duplicate-model-account',
            localModelId: 'second-local-model',
            upstreamModelId: duplicateUpstreamId,
          ),
        ],
      );
      final config = buildLlmModelGroupProviderConfigs(
        accounts: [account],
        groups: [group],
      ).single;
      final alias = config.models.single;
      final state = ProviderEntriesState(
        entries: [
          ProviderEntry(id: 'llm', type: 'llm', name: 'LLM', configs: [config]),
        ],
      );

      expect(llmModelConfigSupportsCapability(alias, 'vision'), isFalse);
      expect(flattenProviderModels(state, 'ocr'), isEmpty);
    },
  );

  test(
    'OCR selector shadows migrated legacy rows but resolves old references',
    () {
      const sourceConfigId = 'legacy-ocr-provider';
      const localModelId = 'ocr-model';
      const upstreamModelId = 'gpt-4o';
      final account = LlmAccount(
        id: llmOcrAccountIdForConfig(sourceConfigId),
        connectorType: 'openai-compatibility',
        authType: 'none',
        displayName: 'Legacy OCR account',
        models: const [
          LlmUpstreamModel(
            id: localModelId,
            upstreamModelId: upstreamModelId,
            displayName: 'Vision model',
            capabilities: {'vision': true},
          ),
        ],
      );
      final group = LlmModelGroup(
        id: llmOcrModelGroupIdForConfig(sourceConfigId, localModelId),
        displayName: 'Vision model',
        members: [
          LlmModelGroupMember(
            accountId: account.id,
            localModelId: localModelId,
            upstreamModelId: upstreamModelId,
          ),
        ],
      );
      final legacyConfig = ProviderConfigItem(
        id: sourceConfigId,
        providerName: 'Legacy OCR provider',
        host: 'https://legacy.example.test/v1',
        key: 'legacy-secret',
        models: [
          ModelConfig(
            id: localModelId,
            name: 'Vision model',
            modelId: upstreamModelId,
          ),
        ],
      );
      final groupConfig = buildLlmModelGroupProviderConfigs(
        accounts: [account],
        groups: [group],
      ).single;
      final state = ProviderEntriesState(
        entries: [
          ProviderEntry(
            id: 'ocr',
            type: 'ocr',
            name: 'OCR',
            configs: [legacyConfig],
          ),
          ProviderEntry(
            id: 'llm',
            type: 'llm',
            name: 'LLM',
            configs: [groupConfig],
          ),
        ],
      );

      final selectable = flattenProviderModels(state, 'ocr');
      expect(selectable, hasLength(1));
      expect(selectable.single.config.id, group.id);
      expect(
        resolveProviderModel(state, 'ocr', {
          'configId': sourceConfigId,
          'modelId': localModelId,
        })?.config,
        same(legacyConfig),
      );
    },
  );

  test(
    'chat selector requires a streaming member but keeps non-stream groups',
    () {
      final accounts = [
        for (final (accountId, streaming) in [
          ('streaming-capable', true),
          ('streaming-disabled', false),
          ('streaming-unknown', null),
        ])
          LlmAccount(
            id: accountId,
            connectorType: 'openai-compatibility',
            authType: 'none',
            displayName: accountId,
            models: [
              LlmUpstreamModel(
                id: 'local-model',
                upstreamModelId: '$accountId-model',
                displayName: accountId,
                capabilities: streaming == null
                    ? const {}
                    : {'streaming': streaming},
              ),
            ],
          ),
      ];
      final groups = [
        for (final account in accounts)
          LlmModelGroup(
            id: '${account.id}-group',
            displayName: account.id,
            members: [
              LlmModelGroupMember(
                accountId: account.id,
                localModelId: 'local-model',
                upstreamModelId: '${account.id}-model',
              ),
            ],
          ),
      ];
      final configs = buildLlmModelGroupProviderConfigs(
        accounts: accounts,
        groups: groups,
      );
      final state = ProviderEntriesState(
        entries: [
          ProviderEntry(id: 'llm', type: 'llm', name: 'LLM', configs: configs),
        ],
      );

      expect(
        flattenProviderModels(
          state,
          'llm',
        ).map((option) => option.config.id).toList(),
        ['streaming-capable-group'],
      );
      final unavailableConfig = configs.singleWhere(
        (config) => config.id == 'streaming-unknown-group',
      );
      expect(
        llmModelConfigSupportsCapability(
          unavailableConfig.models.single,
          'streaming',
        ),
        isFalse,
      );
      expect(
        resolveProviderModel(state, 'llm', {
          'configId': unavailableConfig.id,
          'modelId': 'local-model',
        })?.config,
        same(unavailableConfig),
      );
    },
  );

  test(
    'old references resolve to a stable group when legacy config has no key',
    () {
      const accountId = 'local-account';
      const localModelId = 'local-model';
      final account = LlmAccount(
        id: accountId,
        connectorType: 'openai-compatibility',
        authType: 'none',
        displayName: 'Local endpoint',
        status: LlmAccountStatus.ready,
        models: const [
          LlmUpstreamModel(
            id: localModelId,
            upstreamModelId: 'local-chat-model',
            displayName: 'Local model',
          ),
        ],
      );
      final groupId = stableLlmModelGroupId(accountId, localModelId);
      final groupConfig = buildLlmModelGroupProviderConfigs(
        accounts: [account],
        groups: [
          LlmModelGroup(
            id: groupId,
            displayName: 'Local model',
            members: const [
              LlmModelGroupMember(
                accountId: accountId,
                upstreamModelId: 'local-chat-model',
                localModelId: localModelId,
              ),
            ],
          ),
        ],
      ).single;
      final state = ProviderEntriesState(
        entries: [
          ProviderEntry(
            id: 'llm',
            type: 'llm',
            name: 'LLM',
            configs: [
              ProviderConfigItem(
                id: accountId,
                providerName: account.displayName,
                host: 'http://localhost:1234/v1',
                models: [
                  ModelConfig(
                    id: localModelId,
                    name: 'Local model',
                    modelId: 'local-chat-model',
                  ),
                ],
              ),
              groupConfig,
            ],
          ),
        ],
      );

      final resolved = resolveProviderModel(state, 'llm', {
        'configId': accountId,
        'modelId': localModelId,
      });
      expect(resolved?.config, same(groupConfig));
    },
  );

  test(
    'stable group keeps its legacy model ID after anchor account removal',
    () {
      const anchorAccountId = 'deleted-anchor';
      const localModelId = 'legacy-local-model';
      final group = LlmModelGroup(
        id: stableLlmModelGroupId(anchorAccountId, localModelId),
        displayName: 'Legacy display name',
        legacyModelId: 'old-upstream-model',
        legacyProviderName: 'Original provider name',
        members: const [
          LlmModelGroupMember(
            accountId: 'fallback-account',
            localModelId: localModelId,
            upstreamModelId: 'new-upstream-model',
          ),
        ],
      );
      final fallback = LlmAccount(
        id: 'fallback-account',
        connectorType: 'openai-compatibility',
        authType: 'none',
        displayName: 'Fallback account',
        status: LlmAccountStatus.ready,
        models: const [
          LlmUpstreamModel(
            id: 'fallback-local-model',
            upstreamModelId: 'new-upstream-model',
            displayName: 'New upstream model',
          ),
        ],
      );

      final config = buildLlmModelGroupProviderConfigs(
        accounts: [fallback],
        groups: [group],
      ).single;

      expect(config.models.single.id, localModelId);
      expect(config.models.single.modelId, 'old-upstream-model');
      expect(config.providerName, 'Original provider name');
      expect(
        resolveProviderModel(
          ProviderEntriesState(
            entries: [
              ProviderEntry(
                id: 'llm',
                type: 'llm',
                name: 'LLM',
                configs: [config],
              ),
            ],
          ),
          'llm',
          {'configId': anchorAccountId, 'modelId': localModelId},
        )?.config.providerName,
        'Original provider name',
      );
    },
  );

  test('only the stable anchor alias keeps the legacy model identity', () {
    const anchorAccountId = 'multi-alias-anchor';
    const legacyLocalModelId = 'legacy-local-model';
    const secondaryLocalModelId = 'secondary-local-model';
    final account = LlmAccount(
      id: anchorAccountId,
      connectorType: 'openai-compatibility',
      authType: 'none',
      displayName: 'Current account name',
      models: const [
        LlmUpstreamModel(
          id: legacyLocalModelId,
          upstreamModelId: 'old-upstream-model',
          displayName: 'Legacy model',
          capabilities: {'vision': true},
        ),
        LlmUpstreamModel(
          id: secondaryLocalModelId,
          upstreamModelId: 'old-upstream-model',
          displayName: 'Secondary model',
        ),
      ],
    );
    final groupId = stableLlmModelGroupId(anchorAccountId, legacyLocalModelId);
    final group = LlmModelGroup(
      id: groupId,
      displayName: 'Multi-alias group',
      legacyModelId: 'old-upstream-model',
      legacyProviderName: 'Original provider name',
      members: const [
        LlmModelGroupMember(
          accountId: anchorAccountId,
          localModelId: legacyLocalModelId,
          upstreamModelId: 'old-upstream-model',
        ),
        LlmModelGroupMember(
          accountId: anchorAccountId,
          localModelId: secondaryLocalModelId,
          upstreamModelId: 'old-upstream-model',
        ),
      ],
    );

    final config = buildLlmModelGroupProviderConfigs(
      accounts: [account],
      groups: [group],
    ).single;
    final legacyAlias = config.models.singleWhere(
      (model) => model.id == legacyLocalModelId,
    );
    final secondaryAlias = config.models.singleWhere(
      (model) => model.id == secondaryLocalModelId,
    );

    expect(config.providerName, 'Original provider name');
    expect(legacyAlias.modelId, 'old-upstream-model');
    expect(secondaryAlias.modelId, isNot('old-upstream-model'));
    expect(llmModelConfigSupportsCapability(legacyAlias, 'vision'), isTrue);
    expect(
      llmModelConfigSupportsCapability(secondaryAlias, 'vision'),
      isTrue,
      reason:
          'routing resolves both aliases through the first shared upstream model',
    );
    expect({
      (config.providerName, legacyAlias.modelId),
      (config.providerName, secondaryAlias.modelId),
    }, hasLength(2));
  });

  test('OCR exposes an aggregated vision fallback behind another protocol', () {
    final anthropic = LlmAccount(
      id: 'anthropic-anchor',
      connectorType: 'claude',
      authType: 'api_key',
      displayName: 'Anthropic anchor',
      models: const [
        LlmUpstreamModel(
          id: 'claude-model',
          upstreamModelId: 'claude-3-7-sonnet',
          displayName: 'Claude model',
        ),
      ],
    );
    final openAiVision = LlmAccount(
      id: 'openai-vision-fallback',
      connectorType: 'openai-compatibility',
      authType: 'none',
      displayName: 'OpenAI vision fallback',
      models: const [
        LlmUpstreamModel(
          id: 'vision-model',
          upstreamModelId: 'gpt-4o',
          displayName: 'Vision model',
          capabilities: {'vision': true},
        ),
      ],
    );
    final state = ProviderEntriesState(
      entries: [
        ProviderEntry(
          id: 'llm',
          type: 'llm',
          name: 'LLM',
          configs: buildLlmModelGroupProviderConfigs(
            accounts: [anthropic, openAiVision],
            groups: [
              LlmModelGroup(
                id: 'mixed-vision-group',
                displayName: 'Mixed protocol group',
                members: const [
                  LlmModelGroupMember(
                    accountId: 'anthropic-anchor',
                    localModelId: 'ocr-model',
                    upstreamModelId: 'claude-3-7-sonnet',
                  ),
                  LlmModelGroupMember(
                    accountId: 'openai-vision-fallback',
                    localModelId: 'ocr-model',
                    upstreamModelId: 'gpt-4o',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    expect(
      flattenProviderModels(
        state,
        'ocr',
      ).map((option) => option.config.id).toList(),
      ['mixed-vision-group'],
    );
  });
}
