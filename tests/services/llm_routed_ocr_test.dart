import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/llm_account.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/llm_account_migration_service.dart';
import 'package:stroom/services/llm_chat_runtime.dart';
import 'package:stroom/services/llm_connector_http_client.dart';
import 'package:stroom/services/llm_connector_service.dart';
import 'package:stroom/services/llm_credential_store.dart';
import 'package:stroom/services/llm_routing_service.dart';
import 'package:stroom/services/ocr_service.dart';
import 'package:stroom/services/llm_model_group_provider.dart';
import 'package:stroom/utils/http_timeout.dart';

void main() {
  test(
    'OCR requests use the selected stable group and its upstream model',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      await accounts.saveAccount(
        LlmAccount(
          id: 'ocr-account',
          connectorType: 'openai-compatibility',
          authType: 'none',
          displayName: 'OCR account',
          status: LlmAccountStatus.ready,
          models: const [
            LlmUpstreamModel(
              id: 'account-model',
              upstreamModelId: 'gpt-4o-mini',
              displayName: 'GPT-4o mini',
              capabilities: {'vision': true},
            ),
          ],
        ),
      );
      await accounts.saveModelGroup(
        LlmModelGroup(
          id: 'ocr-group',
          displayName: 'OCR vision model',
          members: const [
            LlmModelGroupMember(
              accountId: 'ocr-account',
              upstreamModelId: 'gpt-4o-mini',
              localModelId: 'ocr-local-model',
            ),
          ],
        ),
      );
      await accounts.saveAccount(
        LlmAccount(
          id: 'other-ocr-account',
          connectorType: 'openai-compatibility',
          authType: 'none',
          displayName: 'Other OCR account',
          status: LlmAccountStatus.ready,
          models: const [
            LlmUpstreamModel(
              id: 'other-account-model',
              upstreamModelId: 'other-vision-model',
              displayName: 'Other vision model',
              capabilities: {'vision': true},
            ),
          ],
        ),
      );
      await accounts.saveModelGroup(
        LlmModelGroup(
          id: 'other-ocr-group',
          displayName: 'Other OCR vision model',
          members: const [
            LlmModelGroupMember(
              accountId: 'other-ocr-account',
              upstreamModelId: 'other-vision-model',
              localModelId: 'ocr-local-model',
            ),
          ],
        ),
      );
      final connector = _FakeConnectorClient(accounts);
      final runtime = LlmChatRoutingRuntime(
        accountService: accounts,
        routingService: LlmRoutingService(
          accountService: accounts,
          stateStore: LlmRoutingStateStore(preferences: preferences),
          concurrency: LlmConcurrencyReservations(),
        ),
        connectorClient: connector,
      );

      final service = OcrService(
        config: OcrConfig(
          host: '',
          apiKey: '',
          model: 'gpt-4o',
          routingGroupId: 'ocr-group',
          routingLocalModelId: 'ocr-local-model',
        ),
        routingRuntime: Future.value(runtime),
      );
      final result = await service.recognize(
        imageBytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(result.text, 'recognized');
      expect(connector.requestedAccountId, 'ocr-account');
      expect(connector.requestedModelId, 'gpt-4o-mini');
      expect(connector.requestBody?['model'], 'gpt-4o-mini');
      expect(service.lastRequestBody?['model'], 'gpt-4o-mini');
    },
  );

  test(
    'routed OCR preserves image upload and long response timeouts',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      await accounts.saveAccount(
        LlmAccount(
          id: 'timeout-account',
          connectorType: 'openai-compatibility',
          authType: 'none',
          displayName: 'Timeout account',
          status: LlmAccountStatus.ready,
          models: const [
            LlmUpstreamModel(
              id: 'timeout-model',
              upstreamModelId: 'vision-model',
              displayName: 'Vision model',
              capabilities: {'vision': true},
            ),
          ],
        ),
      );
      await accounts.saveModelGroup(
        LlmModelGroup(
          id: 'timeout-group',
          displayName: 'Timeout group',
          members: const [
            LlmModelGroupMember(
              accountId: 'timeout-account',
              localModelId: 'ocr-local-model',
              upstreamModelId: 'vision-model',
            ),
          ],
        ),
      );
      final connector = _FakeConnectorClient(accounts);
      final runtime = LlmChatRoutingRuntime(
        accountService: accounts,
        routingService: LlmRoutingService(
          accountService: accounts,
          stateStore: LlmRoutingStateStore(preferences: preferences),
          concurrency: LlmConcurrencyReservations(),
        ),
        connectorClient: connector,
      );
      const connectTimeout = Duration(seconds: 45);
      const receiveTimeout = Duration(minutes: 60);

      await OcrService(
        config: const OcrConfig(
          host: '',
          apiKey: '',
          model: 'vision-model',
          routingGroupId: 'timeout-group',
          routingLocalModelId: 'ocr-local-model',
        ),
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        routingRuntime: Future.value(runtime),
      ).recognize(imageBytes: Uint8List.fromList([1, 2, 3]));

      expect(connector.requestConnectTimeout, connectTimeout);
      expect(
        connector.requestSendTimeout,
        sendTimeoutForBytes(
          utf8.encode(jsonEncode(connector.requestBody)).length,
        ),
      );
      expect(connector.requestReceiveTimeout, receiveTimeout);
    },
  );

  test(
    'routed OCR forwards connector upload progress before waiting',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      await accounts.saveAccount(
        LlmAccount(
          id: 'progress-account',
          connectorType: 'openai-compatibility',
          authType: 'none',
          displayName: 'Progress account',
          status: LlmAccountStatus.ready,
          models: const [
            LlmUpstreamModel(
              id: 'progress-model',
              upstreamModelId: 'vision-model',
              displayName: 'Vision model',
              capabilities: {'vision': true},
            ),
          ],
        ),
      );
      await accounts.saveModelGroup(
        LlmModelGroup(
          id: 'progress-group',
          displayName: 'Progress group',
          members: const [
            LlmModelGroupMember(
              accountId: 'progress-account',
              localModelId: 'ocr-local-model',
              upstreamModelId: 'vision-model',
            ),
          ],
        ),
      );
      final connector = _FakeConnectorClient(
        accounts,
        reportedSendProgress: const [(3, 10), (10, 10)],
      );
      final runtime = LlmChatRoutingRuntime(
        accountService: accounts,
        routingService: LlmRoutingService(
          accountService: accounts,
          stateStore: LlmRoutingStateStore(preferences: preferences),
          concurrency: LlmConcurrencyReservations(),
        ),
        connectorClient: connector,
      );
      final progress = <(int, int)>[];
      final stages = <OcrRequestStage>[];

      await OcrService(
        config: const OcrConfig(
          host: '',
          apiKey: '',
          model: 'vision-model',
          routingGroupId: 'progress-group',
          routingLocalModelId: 'ocr-local-model',
        ),
        routingRuntime: Future.value(runtime),
      ).recognize(
        imageBytes: Uint8List.fromList([1, 2, 3]),
        onSendProgress: (sent, total) => progress.add((sent, total)),
        onStage: stages.add,
      );

      expect(progress, contains((3, 10)));
      expect(stages.first, OcrRequestStage.uploading);
      expect(
        stages.indexOf(OcrRequestStage.waiting),
        greaterThan(stages.indexOf(OcrRequestStage.uploading, 1)),
      );
      expect(stages.last, OcrRequestStage.parsing);
    },
  );

  test('OCR retries another member after a structured 429 rejection', () async {
    final preferences = _MemoryPreferences();
    final accounts = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );
    for (final (id, modelId) in [
      ('ocr-a', 'vision-model-a'),
      ('ocr-b', 'vision-model-b'),
    ]) {
      await accounts.saveAccount(
        LlmAccount(
          id: id,
          connectorType: 'openai-compatibility',
          authType: 'none',
          displayName: id,
          status: LlmAccountStatus.ready,
          models: [
            LlmUpstreamModel(
              id: '$id-local',
              upstreamModelId: modelId,
              displayName: modelId,
              capabilities: const {'vision': true},
            ),
          ],
        ),
      );
    }
    await accounts.saveModelGroup(
      LlmModelGroup(
        id: 'ocr-fallback-group',
        displayName: 'OCR fallback group',
        policy: LlmRoutingPolicy(fallbackScope: LlmFallbackScope.modelGroup),
        members: const [
          LlmModelGroupMember(
            accountId: 'ocr-a',
            localModelId: 'ocr-local-model',
            upstreamModelId: 'vision-model-a',
          ),
          LlmModelGroupMember(
            accountId: 'ocr-b',
            localModelId: 'ocr-local-model',
            upstreamModelId: 'vision-model-b',
          ),
        ],
      ),
    );
    final connector = _FakeConnectorClient(
      accounts,
      failFirstRequestWith429: true,
    );
    final runtime = LlmChatRoutingRuntime(
      accountService: accounts,
      routingService: LlmRoutingService(
        accountService: accounts,
        stateStore: LlmRoutingStateStore(preferences: preferences),
        concurrency: LlmConcurrencyReservations(),
      ),
      connectorClient: connector,
    );

    final service = OcrService(
      config: const OcrConfig(
        host: '',
        apiKey: '',
        model: 'gpt-4o',
        routingGroupId: 'ocr-fallback-group',
        routingLocalModelId: 'ocr-local-model',
      ),
      routingRuntime: Future.value(runtime),
    );
    final result = await service.recognize(
      imageBytes: Uint8List.fromList([1, 2, 3]),
    );

    expect(result.text, 'recognized');
    expect(connector.requests, hasLength(2));
    expect(connector.requests.map((request) => request.account.id).toSet(), {
      'ocr-a',
      'ocr-b',
    });
  });

  test(
    'OCR preserves 4xx rate-limit metadata for same-group retry cooldown',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      for (final accountId in ['ocr-http-a', 'ocr-http-b']) {
        await accounts.saveAccount(
          LlmAccount(
            id: accountId,
            connectorType: 'openai-compatibility',
            authType: 'none',
            displayName: accountId,
            status: LlmAccountStatus.ready,
            models: [
              LlmUpstreamModel(
                id: '$accountId-model',
                upstreamModelId: '$accountId-upstream',
                displayName: accountId,
                capabilities: const {'vision': true},
              ),
            ],
          ),
        );
      }
      await accounts.saveModelGroup(
        LlmModelGroup(
          id: 'ocr-http-fallback-group',
          displayName: 'OCR HTTP fallback group',
          policy: LlmRoutingPolicy(fallbackScope: LlmFallbackScope.modelGroup),
          members: const [
            LlmModelGroupMember(
              accountId: 'ocr-http-a',
              localModelId: 'ocr-http-local',
              upstreamModelId: 'ocr-http-a-upstream',
            ),
            LlmModelGroupMember(
              accountId: 'ocr-http-b',
              localModelId: 'ocr-http-local',
              upstreamModelId: 'ocr-http-b-upstream',
            ),
          ],
        ),
      );
      final now = DateTime.utc(2026, 10, 18, 12);
      final stateStore = LlmRoutingStateStore(
        preferences: preferences,
        clock: () => now,
      );
      final connector = _FakeConnectorClient(
        accounts,
        firstRequestError: const _HttpExceptionWithHeaders(
          statusCode: 400,
          code: 'rate_limit_exceeded',
          headers: {'retry-after': '75'},
        ),
      );
      final runtime = LlmChatRoutingRuntime(
        accountService: accounts,
        routingService: LlmRoutingService(
          accountService: accounts,
          stateStore: stateStore,
          clock: () => now,
          concurrency: LlmConcurrencyReservations(),
        ),
        connectorClient: connector,
      );

      final result = await OcrService(
        config: const OcrConfig(
          host: '',
          apiKey: '',
          model: 'ocr-http-a-upstream',
          routingGroupId: 'ocr-http-fallback-group',
          routingLocalModelId: 'ocr-http-local',
        ),
        routingRuntime: Future.value(runtime),
      ).recognize(imageBytes: Uint8List.fromList([1, 2, 3]));

      expect(result.text, 'recognized');
      expect(connector.requests.map((request) => request.account.id), [
        'ocr-http-a',
        'ocr-http-b',
      ]);
      expect(
        (await stateStore.load()).cooldowns['ocr-http-a']?.until,
        now.add(const Duration(seconds: 75)),
      );
    },
  );

  test('OCR retries a member after a 2xx rate-limit error object', () async {
    final preferences = _MemoryPreferences();
    final accounts = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );
    for (final (id, modelId) in [
      ('ocr-body-error-a', 'vision-model-a'),
      ('ocr-body-error-b', 'vision-model-b'),
    ]) {
      await accounts.saveAccount(
        LlmAccount(
          id: id,
          connectorType: 'openai-compatibility',
          authType: 'none',
          displayName: id,
          status: LlmAccountStatus.ready,
          models: [
            LlmUpstreamModel(
              id: '$id-local',
              upstreamModelId: modelId,
              displayName: modelId,
              capabilities: const {'vision': true},
            ),
          ],
        ),
      );
    }
    await accounts.saveModelGroup(
      LlmModelGroup(
        id: 'ocr-body-error-group',
        displayName: 'OCR body-error fallback group',
        policy: LlmRoutingPolicy(fallbackScope: LlmFallbackScope.modelGroup),
        members: const [
          LlmModelGroupMember(
            accountId: 'ocr-body-error-a',
            localModelId: 'ocr-body-error-local',
            upstreamModelId: 'vision-model-a',
          ),
          LlmModelGroupMember(
            accountId: 'ocr-body-error-b',
            localModelId: 'ocr-body-error-local',
            upstreamModelId: 'vision-model-b',
          ),
        ],
      ),
    );
    final connector = _FakeConnectorClient(
      accounts,
      responseBodies: [
        const {
          'error': {'message': 'slow down', 'code': 'rate_limit_exceeded'},
        },
        const {
          'choices': [
            {
              'finish_reason': 'stop',
              'message': {'content': 'recognized'},
            },
          ],
        },
      ],
    );
    final runtime = LlmChatRoutingRuntime(
      accountService: accounts,
      routingService: LlmRoutingService(
        accountService: accounts,
        stateStore: LlmRoutingStateStore(preferences: preferences),
        concurrency: LlmConcurrencyReservations(),
      ),
      connectorClient: connector,
    );
    final service = OcrService(
      config: const OcrConfig(
        host: '',
        apiKey: '',
        model: 'gpt-4o',
        routingGroupId: 'ocr-body-error-group',
        routingLocalModelId: 'ocr-body-error-local',
      ),
      routingRuntime: Future.value(runtime),
    );

    final result = await service.recognize(
      imageBytes: Uint8List.fromList([1, 2, 3]),
    );

    expect(result.text, 'recognized');
    expect(connector.requests, hasLength(2));
    expect(connector.requests.map((request) => request.account.id).toSet(), {
      'ocr-body-error-a',
      'ocr-body-error-b',
    });
  });

  test(
    'OCR falls back after a connection error before request dispatch',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      for (final accountId in ['ocr-pre-send-a', 'ocr-pre-send-b']) {
        await accounts.saveAccount(
          LlmAccount(
            id: accountId,
            connectorType: 'openai-compatibility',
            authType: 'none',
            displayName: accountId,
            status: LlmAccountStatus.ready,
            models: [
              LlmUpstreamModel(
                id: '$accountId-model',
                upstreamModelId: '$accountId-upstream',
                displayName: accountId,
                capabilities: const {'vision': true},
              ),
            ],
          ),
        );
      }
      await accounts.saveModelGroup(
        LlmModelGroup(
          id: 'ocr-pre-send-group',
          displayName: 'OCR pre-send fallback group',
          policy: LlmRoutingPolicy(fallbackScope: LlmFallbackScope.modelGroup),
          members: const [
            LlmModelGroupMember(
              accountId: 'ocr-pre-send-a',
              localModelId: 'ocr-pre-send-local',
              upstreamModelId: 'ocr-pre-send-a-upstream',
            ),
            LlmModelGroupMember(
              accountId: 'ocr-pre-send-b',
              localModelId: 'ocr-pre-send-local',
              upstreamModelId: 'ocr-pre-send-b-upstream',
            ),
          ],
        ),
      );
      final connector = _FakeConnectorClient(
        accounts,
        failFirstRequestBeforeSend: true,
      );
      final runtime = LlmChatRoutingRuntime(
        accountService: accounts,
        routingService: LlmRoutingService(
          accountService: accounts,
          stateStore: LlmRoutingStateStore(preferences: preferences),
          concurrency: LlmConcurrencyReservations(),
        ),
        connectorClient: connector,
      );

      final result = await OcrService(
        config: const OcrConfig(
          host: '',
          apiKey: '',
          model: 'vision-model',
          routingGroupId: 'ocr-pre-send-group',
          routingLocalModelId: 'ocr-pre-send-local',
        ),
        routingRuntime: Future.value(runtime),
      ).recognize(imageBytes: Uint8List.fromList([1, 2, 3]));

      expect(result.text, 'recognized');
      expect(connector.requests.map((request) => request.account.id), [
        'ocr-pre-send-a',
        'ocr-pre-send-b',
      ]);
    },
  );

  test(
    'legacy OCR provider selection is registered and routed as an account',
    () async {
      final preferences = _MemoryPreferences();
      final credentials = _MemoryCredentialStore();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: credentials,
      );
      const configId = 'legacy-ocr-config';
      const localModelId = 'legacy-ocr-model';
      final accountId = llmOcrAccountIdForConfig(configId);
      final groupId = stableLlmModelGroupId(accountId, localModelId);
      final connector = _FakeConnectorClient(accounts);
      final runtime = LlmChatRoutingRuntime(
        accountService: accounts,
        routingService: LlmRoutingService(
          accountService: accounts,
          stateStore: LlmRoutingStateStore(preferences: preferences),
          concurrency: LlmConcurrencyReservations(),
        ),
        connectorClient: connector,
      );

      final service = OcrService(
        config: OcrConfig(
          host: 'https://legacy.example.test/v1/chat/completions',
          apiKey: 'legacy-key',
          model: 'legacy-upstream-model',
          routingAccountId: accountId,
          routingGroupId: groupId,
          routingLocalModelId: localModelId,
          routingDisplayName: 'Legacy OCR model',
        ),
        routingRuntime: Future.value(runtime),
      );
      final result = await service.recognize(
        imageBytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(result.text, 'recognized');
      expect(connector.requestedAccountId, accountId);
      expect(connector.requestedModelId, 'legacy-upstream-model');
      expect(connector.requestBody?['model'], 'legacy-upstream-model');
      expect(await accounts.readCredential(accountId), 'legacy-key');
      expect(
        (await accounts.getAccount(accountId))?.status,
        LlmAccountStatus.unknown,
      );
      expect((await accounts.listModelGroups()).single.id, groupId);
    },
  );

  test(
    'routed legacy OCR preserves its complete custom endpoint URL',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      const accountId = 'ocr-custom-endpoint';
      const localModelId = 'custom-vision';
      final groupId = stableLlmModelGroupId(accountId, localModelId);
      final connector = _FakeConnectorClient(accounts);
      final runtime = LlmChatRoutingRuntime(
        accountService: accounts,
        routingService: LlmRoutingService(
          accountService: accounts,
          stateStore: LlmRoutingStateStore(preferences: preferences),
          concurrency: LlmConcurrencyReservations(),
        ),
        connectorClient: connector,
      );

      final service = OcrService(
        config: OcrConfig(
          host: 'https://legacy.example.test/ocr/v2/complete?tenant=alpha',
          apiKey: 'legacy-key',
          model: 'vision-model',
          routingAccountId: accountId,
          routingGroupId: groupId,
          routingLocalModelId: localModelId,
        ),
        routingRuntime: Future.value(runtime),
      );
      await service.recognize(imageBytes: Uint8List.fromList([1, 2, 3]));

      expect(
        connector.requestedUri.toString(),
        'https://legacy.example.test/ocr/v2/complete?tenant=alpha',
      );
    },
  );

  test('legacy OCR editor syncs only fields changed in the source', () async {
    final preferences = _MemoryPreferences();
    final accounts = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: _MemoryCredentialStore(),
    );
    final runtime = LlmChatRoutingRuntime(
      accountService: accounts,
      routingService: LlmRoutingService(
        accountService: accounts,
        stateStore: LlmRoutingStateStore(preferences: preferences),
        concurrency: LlmConcurrencyReservations(),
      ),
    );
    const configId = 'legacy-ocr-before-delete';
    const localModelId = 'legacy-ocr-model';
    final legacyConfig = ProviderConfigItem(
      id: configId,
      providerName: 'Legacy OCR provider',
      host: 'https://ocr.example.test/v1',
      key: 'legacy-key',
      models: [
        ModelConfig(
          id: localModelId,
          name: 'Legacy OCR model',
          modelId: 'old-vision-model',
        ),
      ],
    );

    await ensureLegacyOcrProviderConfigGroups(
      runtime: runtime,
      config: legacyConfig,
    );

    final groupId = llmOcrModelGroupIdForConfig(configId, localModelId);
    expect((await accounts.listModelGroups()).single.id, groupId);
    expect(
      await accounts.readCredential(llmOcrAccountIdForConfig(configId)),
      'legacy-key',
    );

    final importedAccount = (await accounts.getAccount(
      llmOcrAccountIdForConfig(configId),
    ))!;
    await accounts.saveAccount(
      LlmAccount(
        id: importedAccount.id,
        connectorType: importedAccount.connectorType,
        authType: importedAccount.authType,
        displayName: importedAccount.displayName,
        status: importedAccount.status,
        credentialRef: importedAccount.credentialRef,
        endpointConfig: importedAccount.endpointConfig,
        models: [
          LlmUpstreamModel(
            id: localModelId,
            upstreamModelId: 'account-edited-model',
            displayName: 'Account edited model',
            capabilities: importedAccount.models.single.capabilities,
          ),
        ],
        policy: importedAccount.policy,
        usageByWindow: importedAccount.usageByWindow,
      ),
      secret: 'account-edited-key',
    );

    final editedConfig = ProviderConfigItem(
      id: configId,
      providerName: 'Edited OCR provider',
      host: 'https://edited-ocr.example.test/ocr/v2/complete',
      key: 'legacy-key',
      models: [
        ModelConfig(
          id: localModelId,
          name: 'Legacy OCR model',
          modelId: 'old-vision-model',
        ),
      ],
    );
    await ensureLegacyOcrProviderConfigGroups(
      runtime: runtime,
      config: editedConfig,
      previousConfig: legacyConfig,
    );

    final account = (await accounts.listAccounts()).single;
    final group = (await accounts.listModelGroups()).single;
    expect(
      account.endpointConfig['baseUrl'],
      'https://edited-ocr.example.test/ocr/v2/complete',
    );
    expect(account.models.single.upstreamModelId, 'account-edited-model');
    expect(group.members.single.upstreamModelId, 'account-edited-model');
    expect(await accounts.readCredential(account.id), 'account-edited-key');

    final groupConfigs = buildLlmModelGroupProviderConfigs(
      accounts: [account],
      groups: [group],
    );
    expect(groupConfigs.single.id, groupId);
  });

  test(
    'OCR records response cost when connector observation reports tokens',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      await accounts.saveAccount(
        LlmAccount(
          id: 'usage-account',
          connectorType: 'openai-compatibility',
          authType: 'none',
          displayName: 'Usage account',
          status: LlmAccountStatus.ready,
          models: const [
            LlmUpstreamModel(
              id: 'usage-model',
              upstreamModelId: 'vision-model',
              displayName: 'Vision model',
              capabilities: {'vision': true},
            ),
          ],
        ),
      );
      await accounts.saveModelGroup(
        LlmModelGroup(
          id: 'usage-group',
          displayName: 'Usage group',
          members: const [
            LlmModelGroupMember(
              accountId: 'usage-account',
              upstreamModelId: 'vision-model',
              localModelId: 'ocr-local-model',
            ),
          ],
        ),
      );
      final observedAt = DateTime.utc(2026, 10, 18);
      final connector = _FakeConnectorClient(
        accounts,
        responseBody: {
          'choices': [
            {
              'finish_reason': 'stop',
              'message': {'content': 'recognized'},
            },
          ],
          'usage': {'prompt_tokens': 10, 'completion_tokens': 4, 'cost': 0.02},
        },
        observation: LlmConnectorObservation(
          requestUsage: const LlmMetricObservation.reported(
            14,
            unit: 'tokens',
            source: 'openai-compatibility',
          ),
          remainingQuota: LlmMetricObservation.reported(
            80,
            unit: 'credits',
            source: 'test.connector',
            observedAt: observedAt,
          ),
          quotaSignals: {
            'weeklyRemainingPercent': LlmMetricObservation.reported(
              35,
              unit: 'percent',
              source: 'test.weekly',
              observedAt: observedAt,
            ),
          },
        ),
      );
      final stateStore = LlmRoutingStateStore(preferences: preferences);
      final runtime = LlmChatRoutingRuntime(
        accountService: accounts,
        routingService: LlmRoutingService(
          accountService: accounts,
          stateStore: stateStore,
          concurrency: LlmConcurrencyReservations(),
        ),
        connectorClient: connector,
      );

      await OcrService(
        config: const OcrConfig(
          host: '',
          apiKey: '',
          model: 'vision-model',
          routingGroupId: 'usage-group',
          routingLocalModelId: 'ocr-local-model',
        ),
        routingRuntime: Future.value(runtime),
      ).recognize(imageBytes: Uint8List.fromList([1, 2, 3]));

      final measurements = (await stateStore.load()).events.single.measurements;
      expect(
        measurements.where((item) => item.unit == 'tokens').single.value,
        14,
      );
      expect(
        measurements.where((item) => item.unit == 'usd').single.value,
        0.02,
      );
      final accountsEnvelope =
          jsonDecode(
                preferences.values[LlmAccountMigrationService
                    .accountsPreferenceKey]!,
              )
              as Map;
      final savedAccount = Map<String, dynamic>.from(
        (accountsEnvelope['items'] as List).single as Map,
      );
      expect(savedAccount['remainingQuota']['value'], 80);
      expect(
        savedAccount['quotaSignals']['weeklyRemainingPercent']['value'],
        35,
      );
      expect(savedAccount['usageByWindow']['week']['remaining']['value'], 35);
    },
  );
}

class _FakeConnectorClient extends LlmConnectorHttpClient {
  _FakeConnectorClient(
    LlmAccountConnectorService accountService, {
    this.failFirstRequestWith429 = false,
    this.failFirstRequestBeforeSend = false,
    this.firstRequestError,
    this.responseBody,
    this.responseBodies,
    LlmConnectorObservation? observation,
    this.reportedSendProgress = const [],
  }) : observation = observation ?? LlmConnectorObservation(),
       super(accountService: accountService);

  final bool failFirstRequestWith429;
  final bool failFirstRequestBeforeSend;
  final LlmConnectorHttpException? firstRequestError;
  final Object? responseBody;
  final List<Object?>? responseBodies;
  final LlmConnectorObservation observation;
  final List<(int, int)> reportedSendProgress;
  final requests = <({LlmAccount account, String modelId, Object? body})>[];
  String? requestedModelId;
  String? requestedAccountId;
  Uri? requestedUri;
  Map<String, dynamic>? requestBody;
  Duration? requestSendTimeout;
  Duration? requestReceiveTimeout;
  Duration? requestConnectTimeout;

  @override
  Future<LlmConnectorResponse> request({
    required LlmAccount account,
    required String modelId,
    required Object? body,
    bool stream = false,
    String? nativeFormat,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Future<void> Function()? onRequestSent,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  }) async {
    requests.add((account: account, modelId: modelId, body: body));
    requestedAccountId = account.id;
    requestedModelId = modelId;
    requestBody = Map<String, dynamic>.from(body! as Map);
    requestConnectTimeout = connectTimeout;
    requestSendTimeout = sendTimeout;
    requestReceiveTimeout = receiveTimeout;
    final configuredEndpoint =
        account.endpointConfig['baseUrl'] ??
        account.endpointConfig['host'] ??
        account.endpointConfig['apiBase'];
    if (configuredEndpoint is String && configuredEndpoint.trim().isNotEmpty) {
      requestedUri = LlmNativeRequestBuilder()
          .build(
            account: account,
            credential: await accountService.readCredential(account.id),
            modelId: modelId,
            body: body,
            stream: stream,
            nativeFormat: nativeFormat,
          )
          .uri;
    }
    for (final (sent, total) in reportedSendProgress) {
      onSendProgress?.call(sent, total);
    }
    if (failFirstRequestBeforeSend && requests.length == 1) {
      throw const LlmConnectorHttpException(code: 'connection_error');
    }
    if (failFirstRequestWith429 && requests.length == 1) {
      await onRequestSent?.call();
      throw const LlmConnectorHttpException(statusCode: 429);
    }
    await onRequestSent?.call();
    if (requests.length == 1 && firstRequestError != null) {
      throw firstRequestError!;
    }
    final response = responseBodies == null
        ? responseBody ??
              {
                'choices': [
                  {
                    'finish_reason': 'stop',
                    'message': {'content': 'recognized'},
                  },
                ],
              }
        : responseBodies![requests.length - 1];
    return LlmConnectorResponse(
      statusCode: 200,
      body: response,
      observation: observation,
    );
  }
}

class _HttpExceptionWithHeaders extends LlmConnectorHttpException {
  const _HttpExceptionWithHeaders({
    required super.statusCode,
    required super.code,
    required super.headers,
  });
}

class _MemoryPreferences implements LlmAccountPreferences {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<bool> remove(String key) async => values.remove(key) != null;

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }
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
