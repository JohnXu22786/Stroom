import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/ai_gateway/ai_gateway.dart';
import 'package:stroom/models/llm_account.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/llm_routed_chat_provider.dart';
import 'package:stroom/services/llm_model_group_provider.dart';
import 'package:stroom/services/api_protocol_config.dart';
import 'package:stroom/services/llm_connector_service.dart';
import 'package:stroom/services/llm_account_migration_service.dart';
import 'package:stroom/services/llm_credential_store.dart';
import 'package:stroom/services/llm_provider_preset_catalog.dart';

void main() {
  test(
      'Azure deployments are available through Chat and Task Flow model groups',
      () {
    final account = LlmAccount(
      id: 'm50-azure-group',
      connectorType: 'azure-ai',
      authType: 'api_key',
      displayName: 'Azure Foundry',
      endpointConfig: const {
        'baseUrl': 'https://example.services.ai.azure.com',
        'azureDeploymentId': 'chat-deployment',
        'apiVersion': '2024-12-01-preview',
        'apiProtocol': 'openai.chat_completions',
      },
      models: const [
        LlmUpstreamModel(
          id: 'm50-azure-deployment-model',
          upstreamModelId: 'chat-deployment',
          displayName: 'chat-deployment',
          capabilities: {
            'chat': true,
            'streaming': true,
            'supportedApiProtocols': ['openai.chat_completions'],
          },
          config: {'catalogSource': 'configured-azure-deployment'},
        ),
      ],
    );
    final group = LlmModelGroup(
      id: stableLlmModelGroupId(account.id, 'chat-deployment'),
      displayName: 'Azure production',
      members: const [
        LlmModelGroupMember(
          accountId: 'm50-azure-group',
          upstreamModelId: 'chat-deployment',
          localModelId: 'chat-deployment',
        ),
      ],
    );

    final configs = buildLlmModelGroupProviderConfigs(
      accounts: [account],
      groups: [group],
    );

    expect(LlmConnectorRegistry.chatAdapterEndpointType('azure-ai'), 'openai');
    expect(
        LlmConnectorRegistry.chatAdapterEndpointType('azure-openai'), 'openai');
    expect(builtinDefaultApiProtocolForConnector('azure-ai'),
        'openai.chat_completions');
    expect(
      supportedApiProtocolsForSupplier(null, connectorType: 'azure-openai'),
      {'openai.chat_completions'},
    );
    expect(configs, hasLength(1));
    expect(configs.single.apiProtocol, 'openai.chat_completions');
    expect(configs.single.models.single.modelId, 'chat-deployment');
    expect(
      llmRoutedChatSupportedConnectorTypes('openai.chat_completions'),
      containsAll(['azure-ai', 'azure-openai']),
    );
  });

  test('M49 API-key presets preserve source endpoint and header contracts', () {
    const expected = {
      'api-airforce': (
        'https://api.airforce/v1/chat/completions',
        'Authorization',
        'Bearer',
        {
          'HTTP-Referer': 'https://endpoint-proxy.local',
          'X-Title': 'Endpoint Proxy',
        },
        'https://api.airforce/v1/models',
      ),
      'navy': (
        'https://api.navy/v1/chat/completions',
        'Authorization',
        'Bearer',
        {'User-Agent': 'OmniRoute/1.0'},
        'https://api.navy/v1/models',
      ),
      'pioneer': (
        'https://api.pioneer.ai/v1/chat/completions',
        'X-API-Key',
        '',
        <String, String>{},
        null,
      ),
      'uc-direct': (
        'https://api.uncensored.com/api/v1',
        'X-API-Key',
        '',
        <String, String>{},
        null,
      ),
    };
    for (final entry in expected.entries) {
      final preset = findLlmOpenAiProviderPreset(entry.key)!;
      expect(preset.baseUrl, entry.value.$1, reason: entry.key);
      expect(preset.authType, 'api_key', reason: entry.key);
      expect(preset.authorizationHeader, entry.value.$2, reason: entry.key);
      expect(preset.authorizationScheme, entry.value.$3, reason: entry.key);
      expect(preset.headers, entry.value.$4, reason: entry.key);
      expect(preset.modelsUrl, entry.value.$5, reason: entry.key);
      expect(preset.defaultApiProtocol, 'openai.chat_completions');

      final config = preset.applyToEndpointConfig(const {
        'userSetting': 'preserved',
        'headers': {'X-Workspace': 'personal'},
      });
      expect(config['providerPresetId'], entry.key);
      expect(config['apiKeyHeader'], entry.value.$2);
      expect(config['apiKeyScheme'], entry.value.$3);
      expect(config['headers'], {
        'X-Workspace': 'personal',
        ...entry.value.$4,
      });
      expect(config['userSetting'], 'preserved');
      expect(config.toString(), isNot(contains('api-key-secret')));
    }

    final airforceConfig = findLlmOpenAiProviderPreset('api-airforce')!
        .applyToEndpointConfig(const {
      'headers': {'X-Workspace': 'personal'},
    });
    final switched = findLlmOpenAiProviderPreset('pioneer')!
        .applyToEndpointConfig(airforceConfig);
    expect(switched['headers'], {'X-Workspace': 'personal'});
    expect(switched['apiKeyHeader'], 'X-API-Key');
    expect(switched['apiKeyScheme'], '');

    final custom = LlmProviderPreset.clearFromEndpointConfig(switched);
    expect(custom.containsKey('providerPresetId'), isFalse);
    expect(custom.containsKey('apiKeyHeader'), isFalse);
    expect(custom.containsKey('apiKeyScheme'), isFalse);
    expect(custom['headers'], {'X-Workspace': 'personal'});
  });

  test('M49 API-key requests use the selected dynamic auth header', () {
    final airforce = findLlmOpenAiProviderPreset('api-airforce')!;
    final pioneer = findLlmOpenAiProviderPreset('pioneer')!;
    final builder = LlmNativeRequestBuilder();
    final airforceRequest = builder.build(
      account: LlmAccount(
        id: 'm49-airforce',
        connectorType: 'openai-compatibility',
        authType: 'api_key',
        displayName: airforce.displayName,
        endpointConfig: airforce.applyToEndpointConfig(const {}),
      ),
      credential: 'synthetic-m49-key',
      modelId: 'manual-model',
      body: const {'model': 'manual-model', 'messages': []},
    );
    expect(
        airforceRequest.headers['Authorization'], 'Bearer synthetic-m49-key');
    expect(airforceRequest.headers['HTTP-Referer'],
        'https://endpoint-proxy.local');
    expect(airforceRequest.headers['X-Title'], 'Endpoint Proxy');
    expect(airforceRequest.toString(), isNot(contains('synthetic-m49-key')));

    final pioneerRequest = builder.build(
      account: LlmAccount(
        id: 'm49-pioneer',
        connectorType: 'openai-compatibility',
        authType: 'api_key',
        displayName: pioneer.displayName,
        endpointConfig: pioneer.applyToEndpointConfig(const {}),
      ),
      credential: 'synthetic-m49-key',
      modelId: 'manual-model',
      body: const {'model': 'manual-model', 'messages': []},
    );
    expect(pioneerRequest.headers['X-API-Key'], 'synthetic-m49-key');
    expect(pioneerRequest.headers['Authorization'], isNull);
    expect(
      () => builder.build(
        account: LlmAccount(
          id: 'm49-pioneer-static-auth',
          connectorType: 'openai-compatibility',
          authType: 'api_key',
          displayName: pioneer.displayName,
          endpointConfig: pioneer.applyToEndpointConfig(const {
            'headers': {'X-API-Key': 'static-must-not-win'},
          }),
        ),
        credential: 'synthetic-m49-key',
        modelId: 'manual-model',
        body: const {'model': 'manual-model', 'messages': []},
      ),
      throwsA(isA<LlmAccountConnectorException>()),
    );
    expect(
      () => builder.build(
        account: LlmAccount(
          id: 'm49-airforce-invalid-header',
          connectorType: 'openai-compatibility',
          authType: 'api_key',
          displayName: airforce.displayName,
          endpointConfig: airforce.applyToEndpointConfig(const {
            'headers': {'X-Workspace': 'safe\r\nAuthorization: leaked'},
          }),
        ),
        credential: 'synthetic-m49-key',
        modelId: 'manual-model',
        body: const {'model': 'manual-model', 'messages': []},
      ),
      throwsA(isA<LlmAccountConnectorException>()),
    );
    expect(
      () => builder.build(
        account: LlmAccount(
          id: 'm49-pioneer-invalid-key-header-value',
          connectorType: 'openai-compatibility',
          authType: 'api_key',
          displayName: pioneer.displayName,
          endpointConfig: pioneer.applyToEndpointConfig(const {}),
        ),
        credential: 'synthetic-key\r\nX-Leak: value',
        modelId: 'manual-model',
        body: const {'model': 'manual-model', 'messages': []},
      ),
      throwsA(isA<LlmAccountConnectorException>()),
    );

    final ucDirect = findLlmOpenAiProviderPreset('uc-direct')!;
    final ucRequest = builder.build(
      account: LlmAccount(
        id: 'm49-uc-direct',
        connectorType: 'openai-compatibility',
        authType: 'api_key',
        displayName: ucDirect.displayName,
        endpointConfig: ucDirect.applyToEndpointConfig(const {}),
      ),
      credential: 'synthetic-m49-key',
      modelId: 'manual-model',
      body: const {'model': 'manual-model', 'messages': []},
    );
    expect(ucRequest.uri.path, '/api/v1/chat/completions');
    expect(ucRequest.headers['X-API-Key'], 'synthetic-m49-key');
    expect(ucRequest.headers['Authorization'], isNull);
  });

  test('M49 preset accounts retain secure credentials and protocol overrides',
      () async {
    final service = LlmAccountConnectorService(
      preferences: _MemoryLlmAccountPreferences(),
      credentialStore: _MemoryLlmCredentials(),
    );
    for (final presetId in ['api-airforce', 'navy', 'pioneer', 'uc-direct']) {
      final preset = findLlmOpenAiProviderPreset(presetId)!;
      final account = LlmAccount(
        id: 'm49-$presetId-account',
        connectorType: 'openai-compatibility',
        authType: 'api_key',
        displayName: preset.displayName,
        endpointConfig: preset.applyToEndpointConfig(const {}),
        models: const [
          LlmUpstreamModel(
            id: 'm49-account:manual-model',
            upstreamModelId: 'manual-model',
            displayName: 'Manual model',
            config: {'apiProtocolOverride': 'anthropic.messages'},
          ),
        ],
      );
      await service.saveAccount(account, secret: 'synthetic-m49-key');
      final restored = (await service.getAccount(account.id))!;
      expect(await service.readCredential(account.id), 'synthetic-m49-key');
      expect(restored.endpointConfig['providerPresetId'], presetId);
      expect(restored.endpointConfig['baseUrl'], preset.baseUrl);
      expect(
          restored.endpointConfig['apiKeyHeader'], preset.authorizationHeader);
      expect(
          restored.endpointConfig['apiKeyScheme'], preset.authorizationScheme);
      expect(restored.endpointConfig['headers'],
          preset.headers.isEmpty ? isNull : preset.headers);
      expect(restored.endpointConfig.toString(),
          isNot(contains('synthetic-m49-key')));
      expect(restored.models.single.config['apiProtocolOverride'],
          'anthropic.messages');
      final group = LlmModelGroup(
        id: 'm49-$presetId-group',
        displayName: preset.displayName,
        members: [
          LlmModelGroupMember(
            accountId: restored.id,
            upstreamModelId: restored.models.single.upstreamModelId,
          ),
        ],
      );
      final configs = buildLlmModelGroupProviderConfigs(
        accounts: [restored],
        groups: [group],
      );
      expect(configs.single.apiProtocol, 'openai.chat_completions');
      expect(configs.single.models.single.apiProtocolOverride,
          'anthropic.messages');
    }
  });

  test('M49 model discovery shares provider auth and static headers', () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..httpClientAdapter = _FunctionalAdapter((options) async {
        requests.add(options);
        return ResponseBody.fromString(
          jsonEncode({
            'data': [
              {'id': 'discovered-model'},
            ],
          }),
          200,
          headers: const {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
    final service = LlmAccountConnectorService(
      preferences: _MemoryLlmAccountPreferences(),
      credentialStore: _MemoryLlmCredentials(),
      dio: dio,
    );
    for (final presetId in ['api-airforce', 'navy']) {
      final preset = findLlmOpenAiProviderPreset(presetId)!;
      final account = await service.saveAccount(
        LlmAccount(
          id: 'm49-$presetId-discovery',
          connectorType: 'openai-compatibility',
          authType: 'api_key',
          displayName: preset.displayName,
          endpointConfig: preset.applyToEndpointConfig(const {}),
        ),
        secret: 'synthetic-m49-key',
      );
      await service.discoverModels(account, refreshRemote: true);
      final request = requests.last;
      expect(request.uri.toString(), preset.modelsUrl, reason: presetId);
      expect(request.headers['Authorization'], 'Bearer synthetic-m49-key');
      for (final header in preset.headers.entries) {
        expect(request.headers[header.key], header.value, reason: presetId);
      }
    }
    expect(requests, hasLength(2));
  });

  test('M44 API-key presets retain audited Chat Completions metadata', () {
    const endpoints = {
      'onomeo': 'https://onomeo.com/v1/chat/completions',
      'openadapter': 'https://api.openadapter.in/v1/chat/completions',
      'openvecta': 'https://api.openvecta.com/v1/chat/completions',
      'opper': 'https://api.opper.ai/v3/compat/chat/completions',
      'plamo': 'https://api.platform.preferredai.jp/v1/chat/completions',
      'poe': 'https://api.poe.com/v1/chat/completions',
      'poixe-ai': 'https://api.poixe.com/v1/chat/completions',
    };
    for (final entry in endpoints.entries) {
      final preset = findLlmOpenAiProviderPreset(entry.key)!;
      expect(preset.baseUrl, entry.value, reason: entry.key);
      expect(preset.authType, 'api_key', reason: entry.key);
      expect(preset.authorizationHeader, 'Authorization', reason: entry.key);
      expect(preset.authorizationScheme, 'Bearer', reason: entry.key);
      expect(preset.defaultApiProtocol, 'openai.chat_completions');
    }
    expect({
      for (final id in ['onomeo', 'openadapter', 'opper', 'poixe-ai'])
        id: findLlmOpenAiProviderPreset(id)!.modelsUrl,
    }, {
      'onomeo': 'https://onomeo.com/v1/models',
      'openadapter': 'https://api.openadapter.in/v1/models',
      'opper': 'https://api.opper.ai/v3/compat/models',
      'poixe-ai': 'https://api.poixe.com/v1/models',
    });
    expect(findLlmOpenAiProviderPreset('openadapter')!.fallbackModels.single.id,
        'glm-4.7');
    expect(
      findLlmOpenAiProviderPreset('openadapter')!
          .fallbackModels
          .single
          .capabilities,
      {'contextLength': 128000, 'toolCalling': true},
    );
    expect(
      findLlmOpenAiProviderPreset('openvecta')!.fallbackModels.map((m) => m.id),
      [
        'glm-4.7-flash',
        'claude-sonnet-4.6',
        'deepseek-v4-flash',
        'gpt-oss-120b',
        'gemma-4-31b',
        'kimi-k2.6',
        'llama-3.3-70b-instruct',
        'llama-4-maverick',
        'nemotron-3-super-120b',
      ],
    );
    expect(
      findLlmOpenAiProviderPreset('openvecta')!
          .fallbackModels
          .map((m) => m.capabilities['contextLength']),
      [
        131072,
        1000000,
        131072,
        131072,
        262144,
        200000,
        131072,
        1048576,
        262144
      ],
    );
    expect(findLlmOpenAiProviderPreset('onomeo')!.fallbackModels, isEmpty);
    expect(findLlmOpenAiProviderPreset('opper')!.fallbackModels, isEmpty);
    expect(findLlmOpenAiProviderPreset('poixe-ai')!.fallbackModels, isEmpty);
    expect(
        findLlmOpenAiProviderPreset('plamo')!
            .fallbackModels
            .single
            .capabilities,
        {'contextLength': 262144, 'maxOutputTokens': 20000});
    expect(findLlmOpenAiProviderPreset('poe')!.fallbackModels.map((m) => m.id),
        ['gpt-5.2', 'gemini-3.0-pro']);

    // These pinned modes need an executor translation, fixed provider headers,
    // optional/no-auth semantics, or a non-Bearer key contract.
    for (final id in [
      'oneminai',
      'openrouter',
      'orcarouter',
      'ovhcloud',
      'perplexity',
    ]) {
      expect(findLlmOpenAiProviderPreset(id), isNull, reason: id);
    }
  });

  test('each M44 preset persists and routes through Chat and Task Flow',
      () async {
    final service = LlmAccountConnectorService(
      preferences: _MemoryLlmAccountPreferences(),
      credentialStore: _MemoryLlmCredentials(),
    );
    const presetIds = [
      'onomeo',
      'openadapter',
      'openvecta',
      'opper',
      'plamo',
      'poe',
      'poixe-ai',
    ];
    for (final presetId in presetIds) {
      final preset = findLlmOpenAiProviderPreset(presetId)!;
      final fallback = preset.fallbackModels.firstOrNull;
      final model = LlmUpstreamModel(
        id: 'm44-$presetId:${fallback?.id ?? 'user-model'}',
        upstreamModelId: fallback?.id ?? 'user-model',
        displayName: fallback?.displayName ?? 'User model',
        capabilities: fallback?.capabilities ?? const {},
        config: const {'apiProtocolOverride': 'anthropic.messages'},
      );
      final account = LlmAccount(
        id: 'm44-$presetId',
        connectorType: 'openai-compatibility',
        authType: preset.authType,
        displayName: preset.displayName,
        endpointConfig: preset.applyToEndpointConfig(const {
          'accountOwnedConfig': 'preserved',
        }),
        models: [model],
      );
      await service.saveAccount(account, secret: 'key-$presetId');
      final restored = (await service.getAccount(account.id))!;
      expect(restored.connectorType, 'openai-compatibility', reason: presetId);
      expect(restored.endpointConfig['providerPresetId'], presetId);
      expect(restored.endpointConfig['baseUrl'], preset.baseUrl);
      expect(restored.endpointConfig['modelsUrl'], preset.modelsUrl);
      expect(restored.endpointConfig['apiProtocol'], 'openai.chat_completions');
      expect(restored.endpointConfig['accountOwnedConfig'], 'preserved');
      expect(await service.readCredential(account.id), 'key-$presetId');
      expect(restored.models.single.upstreamModelId, model.upstreamModelId);
      expect(restored.models.single.capabilities, model.capabilities);
      expect(restored.models.single.config['apiProtocolOverride'],
          'anthropic.messages');

      final group = LlmModelGroup(
        id: 'm44-$presetId-group',
        displayName: preset.displayName,
        members: [
          LlmModelGroupMember(
            accountId: restored.id,
            upstreamModelId: restored.models.single.upstreamModelId,
          ),
        ],
      );
      final configs = buildLlmModelGroupProviderConfigs(
        accounts: [restored],
        groups: [group],
      );
      expect(configs, hasLength(1));
      expect(configs.single.apiProtocol, 'openai.chat_completions');
      expect(configs.single.models.single.apiProtocolOverride,
          'anthropic.messages');
    }
  });

  test('M44 discovery presets refresh from audited URLs with bearer auth',
      () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..httpClientAdapter = _FunctionalAdapter((options) async {
        requests.add(options);
        return ResponseBody.fromString(
          jsonEncode({
            'data': [
              {'id': 'discovered-${requests.length}'}
            ]
          }),
          200,
          headers: const {
            Headers.contentTypeHeader: ['application/json']
          },
        );
      });
    final service = LlmAccountConnectorService(
      preferences: _MemoryLlmAccountPreferences(),
      credentialStore: _MemoryLlmCredentials(),
      dio: dio,
    );
    const presetIds = ['onomeo', 'openadapter', 'opper', 'poixe-ai'];
    for (final presetId in presetIds) {
      final preset = findLlmOpenAiProviderPreset(presetId)!;
      final account = await service.saveAccount(
        LlmAccount(
          id: 'm44-$presetId-discovery',
          connectorType: 'openai-compatibility',
          authType: 'api_key',
          displayName: preset.displayName,
          endpointConfig: preset.applyToEndpointConfig(const {}),
        ),
        secret: 'key-$presetId',
      );
      final models = await service.discoverModels(account, refreshRemote: true);
      expect(requests.last.uri.toString(), preset.modelsUrl, reason: presetId);
      expect(requests.last.headers['Authorization'], 'Bearer key-$presetId');
      expect(models.single.upstreamModelId, 'discovered-${requests.length}');
    }
  });

  test('M45 API-key presets match the pinned executable provider registry', () {
    const endpoints = {
      'poolside': 'https://inference.poolside.ai/v1/chat/completions',
      'publicai': 'https://api.publicai.co/v1/chat/completions',
      'regolo': 'https://api.regolo.ai/v1/chat/completions',
      'reka': 'https://api.reka.ai/v1/chat/completions',
      'requesty': 'https://router.requesty.ai/v1/chat/completions',
      'sambanova': 'https://api.sambanova.ai/v1/chat/completions',
      'sarvam': 'https://api.sarvam.ai/v1/chat/completions',
      'scaleway': 'https://api.scaleway.ai/v1/chat/completions',
    };
    for (final entry in endpoints.entries) {
      final preset = findLlmOpenAiProviderPreset(entry.key)!;
      expect(preset.baseUrl, entry.value, reason: entry.key);
      expect(preset.authType, 'api_key', reason: entry.key);
      expect(preset.authorizationHeader, 'Authorization', reason: entry.key);
      expect(preset.authorizationScheme, 'Bearer', reason: entry.key);
      expect(preset.defaultApiProtocol, 'openai.chat_completions');
    }
    expect(
      {
        for (final id in ['poolside', 'regolo', 'requesty'])
          id: findLlmOpenAiProviderPreset(id)!.modelsUrl,
      },
      {
        'poolside': 'https://inference.poolside.ai/v1/models',
        'regolo': 'https://api.regolo.ai/v1/models',
        'requesty': 'https://router.requesty.ai/v1/models',
      },
    );
    expect(
      findLlmOpenAiProviderPreset('poolside')!.fallbackModels.map((m) => m.id),
      ['poolside/laguna-xs-2.1', 'poolside/laguna-s-2.1'],
    );
    expect(
      findLlmOpenAiProviderPreset(
        'poolside',
      )!
          .fallbackModels
          .first
          .capabilities,
      {
        'toolCalling': true,
        'reasoning': true,
        'contextLength': 262144,
        'maxOutputTokens': 32768,
      },
    );
    expect(
      findLlmOpenAiProviderPreset('publicai')!.fallbackModels.map((m) => m.id),
      [
        'swiss-ai/apertus-70b-instruct',
        'swiss-ai/Apertus-8B-Instruct-2509',
        'aisingapore/Qwen-SEA-LION-v4-32B-IT',
        'aisingapore/Gemma-SEA-LION-v4-27B-IT',
        'allenai/Olmo-3-32B-Think',
        'allenai/Olmo-3-7B-Instruct',
        'utter-project/EuroLLM-22B-Instruct-2512',
      ],
    );
    expect(findLlmOpenAiProviderPreset('regolo')!.fallbackModels, isEmpty);
    expect(
      findLlmOpenAiProviderPreset('reka')!.fallbackModels.map((m) => m.id),
      ['reka-flash-3', 'reka-flash', 'reka-edge-2603'],
    );
    expect(
      findLlmOpenAiProviderPreset('reka')!.fallbackModels.first.capabilities,
      {'reasoning': true, 'alwaysReasons': true, 'maxOutputTokens': 8192},
    );
    expect(findLlmOpenAiProviderPreset('requesty')!.fallbackModels, isEmpty);
    expect(
      findLlmOpenAiProviderPreset('sambanova')!.fallbackModels.map((m) => m.id),
      [
        'MiniMax-M2.7',
        'DeepSeek-V3.2',
        'Llama-4-Maverick-17B-128E-Instruct',
        'Meta-Llama-3.3-70B-Instruct',
        'gpt-oss-120b',
        'DeepSeek-V3.1',
        'gemma-4-31B-it',
      ],
    );
    expect(
      findLlmOpenAiProviderPreset('sarvam')!.fallbackModels.map((m) => m.id),
      ['sarvam-105b', 'sarvam-30b'],
    );
    expect(
      findLlmOpenAiProviderPreset(
        'sarvam',
      )!
          .fallbackModels
          .map((m) => m.capabilities['contextLength']),
      [131072, 65536],
    );
    expect(
      findLlmOpenAiProviderPreset('scaleway')!.fallbackModels.map((m) => m.id),
      [
        'qwen3-235b-a22b-instruct-2507',
        'llama-3.1-70b-instruct',
        'llama-3.1-8b-instruct',
        'mistral-small-3.2-24b-instruct-2506',
        'deepseek-v3-0324',
        'gpt-oss-120b',
      ],
    );

    // These source-backed candidates are intentionally deferred: they require
    // a provider-specific executor, fixed request header, unsupported default
    // capability behavior, or lack an executable pinned provider adapter.
    for (final id in [
      'pollinations',
      'predibase',
      'qiniu',
      'routeway',
      'sap',
    ]) {
      expect(findLlmOpenAiProviderPreset(id), isNull, reason: id);
    }
    // `poolside/...` in the catalog is an upstream model ID, not a preset ID.
    expect(findLlmOpenAiProviderPreset('poolside'), isNotNull);
  });

  test(
    'each M45 preset persists and routes through Chat and Task Flow',
    () async {
      final service = LlmAccountConnectorService(
        preferences: _MemoryLlmAccountPreferences(),
        credentialStore: _MemoryLlmCredentials(),
      );
      const presetIds = [
        'poolside',
        'publicai',
        'regolo',
        'reka',
        'requesty',
        'sambanova',
        'sarvam',
        'scaleway',
      ];
      for (final presetId in presetIds) {
        final preset = findLlmOpenAiProviderPreset(presetId)!;
        final fallback = preset.fallbackModels.firstOrNull;
        final model = LlmUpstreamModel(
          id: 'm45-$presetId:${fallback?.id ?? 'user-model'}',
          upstreamModelId: fallback?.id ?? 'user-model',
          displayName: fallback?.displayName ?? 'User model',
          capabilities: fallback?.capabilities ?? const {},
          config: const {'apiProtocolOverride': 'anthropic.messages'},
        );
        final account = LlmAccount(
          id: 'm45-$presetId',
          connectorType: 'openai-compatibility',
          authType: preset.authType,
          displayName: preset.displayName,
          endpointConfig: preset.applyToEndpointConfig(const {
            'accountOwnedConfig': 'preserved',
          }),
          models: [model],
        );
        await service.saveAccount(account, secret: 'key-$presetId');

        final restored = (await service.getAccount(account.id))!;
        expect(
          restored.connectorType,
          'openai-compatibility',
          reason: presetId,
        );
        expect(restored.endpointConfig['providerPresetId'], presetId);
        expect(restored.endpointConfig['baseUrl'], preset.baseUrl);
        expect(restored.endpointConfig['modelsUrl'], preset.modelsUrl);
        expect(
          restored.endpointConfig['apiProtocol'],
          'openai.chat_completions',
        );
        expect(restored.endpointConfig['accountOwnedConfig'], 'preserved');
        expect(await service.readCredential(account.id), 'key-$presetId');
        expect(restored.models.single.upstreamModelId, model.upstreamModelId);
        expect(restored.models.single.capabilities, model.capabilities);
        expect(
          restored.models.single.config['apiProtocolOverride'],
          'anthropic.messages',
        );
        final chatProvider = createChatProviderFromConfig(
          providerName: restored.displayName,
          baseUrl: restored.endpointConfig['baseUrl'] as String,
          apiKey: 'key-$presetId',
          endpointType: restored.endpointConfig['apiProtocol'] as String,
        ) as OpenAICompatibleChatProvider;
        // ignore: invalid_use_of_visible_for_testing_member
        expect(chatProvider.requestUrlForTesting, preset.baseUrl);

        final group = LlmModelGroup(
          id: 'm45-$presetId-group',
          displayName: preset.displayName,
          members: [
            LlmModelGroupMember(
              accountId: restored.id,
              upstreamModelId: restored.models.single.upstreamModelId,
            ),
          ],
        );
        final configs = buildLlmModelGroupProviderConfigs(
          accounts: [restored],
          groups: [group],
        );
        expect(configs, hasLength(1));
        expect(configs.single.apiProtocol, 'openai.chat_completions');
        expect(
          configs.single.models.single.apiProtocolOverride,
          'anthropic.messages',
        );
        expect(
          llmRoutedChatSupportedConnectorTypes('openai.chat_completions'),
          contains('openai-compatibility'),
        );
      }
    },
  );

  test(
    'M45 live catalogs refresh with the source URL and Bearer key',
    () async {
      const presetIds = ['poolside', 'regolo', 'requesty'];
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          requests.add(options);
          return ResponseBody.fromString(
            jsonEncode({
              'data': [
                {'id': 'm45-model-${requests.length}'},
              ],
            }),
            200,
            headers: const {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });
      final service = LlmAccountConnectorService(
        preferences: _MemoryLlmAccountPreferences(),
        credentialStore: _MemoryLlmCredentials(),
        dio: dio,
      );
      for (final presetId in presetIds) {
        final preset = findLlmOpenAiProviderPreset(presetId)!;
        final account = await service.saveAccount(
          LlmAccount(
            id: 'm45-$presetId-discovery',
            connectorType: 'openai-compatibility',
            authType: preset.authType,
            displayName: preset.displayName,
            endpointConfig: preset.applyToEndpointConfig(const {}),
          ),
          secret: 'key-$presetId',
        );
        final models = await service.discoverModels(
          account,
          refreshRemote: true,
        );
        expect(
          requests.last.uri.toString(),
          preset.modelsUrl,
          reason: presetId,
        );
        expect(requests.last.headers['Authorization'], 'Bearer key-$presetId');
        expect(models.single.upstreamModelId, 'm45-model-${requests.length}');
      }
    },
  );

  test('M43 API-key presets retain audited Chat Completions metadata', () {
    const endpoints = {
      'naga-ai': 'https://api.naga.ac/v1/chat/completions',
      'nan': 'https://api.nan.builders/v1/chat/completions',
      'nanogpt': 'https://nano-gpt.com/api/v1/chat/completions',
      'nara': 'https://router.bynara.id/v1/chat/completions',
      'nebius': 'https://api.tokenfactory.nebius.com/v1/chat/completions',
      'nous-research':
          'https://inference-api.nousresearch.com/v1/chat/completions',
      'nscale': 'https://inference.api.nscale.com/v1/chat/completions',
      'nube': 'https://ai.nube.sh/api/v1/chat/completions',
      'oci':
          'https://inference.generativeai.us-chicago-1.oci.oraclecloud.com/openai/v1/chat/completions',
      'ofoxai': 'https://api.ofox.ai/v1/chat/completions',
      'ollama-cloud': 'https://ollama.com/v1/chat/completions',
    };
    for (final entry in endpoints.entries) {
      final preset = findLlmOpenAiProviderPreset(entry.key)!;
      expect(preset.baseUrl, entry.value, reason: entry.key);
      expect(preset.authType, 'api_key', reason: entry.key);
      expect(preset.authorizationHeader, 'Authorization', reason: entry.key);
      expect(preset.authorizationScheme, 'Bearer', reason: entry.key);
      expect(
        preset.defaultApiProtocol,
        'openai.chat_completions',
        reason: entry.key,
      );
    }
    expect(
      {
        for (final id in [
          'naga-ai',
          'nan',
          'nanogpt',
          'nube',
          'oci',
          'ofoxai',
          'ollama-cloud',
        ])
          id: findLlmOpenAiProviderPreset(id)!.modelsUrl,
      },
      {
        'naga-ai': 'https://api.naga.ac/v1/models',
        'nan': 'https://api.nan.builders/v1/models',
        'nanogpt': 'https://nano-gpt.com/api/v1/models',
        'nube': 'https://ai.nube.sh/api/v1/models',
        'oci':
            'https://inference.generativeai.us-chicago-1.oci.oraclecloud.com/openai/v1/models',
        'ofoxai': 'https://api.ofox.ai/v1/models',
        'ollama-cloud': 'https://ollama.com/api/tags',
      },
    );
    expect(findLlmOpenAiProviderPreset('naga-ai')!.fallbackModels, isEmpty);
    expect(
      findLlmOpenAiProviderPreset(
        'nan',
      )!
          .fallbackModels
          .map((model) => model.id),
      [
        'deepseek-v4-flash',
        'mimo-v2.5',
        'mimo-v2.6-flash',
        'qwen3.8-flash',
        'qwen3.6',
        'glm5.3',
        'glm5.3-flash',
        'gemma4',
      ],
    );
    expect(
      findLlmOpenAiProviderPreset(
        'nanogpt',
      )!
          .fallbackModels
          .map((model) => model.id),
      ['chatgpt-4o-latest', 'claude-3.5-sonnet', 'gpt-4o-mini'],
    );
    expect(
      findLlmOpenAiProviderPreset('nara')!.fallbackModels.first.capabilities,
      {
        'contextLength': 262144,
        'toolCalling': true,
        'vision': true,
        'reasoning': true,
      },
    );
    expect(
      findLlmOpenAiProviderPreset('nebius')!.fallbackModels.single.id,
      'meta-llama/Llama-3.3-70B-Instruct',
    );
    expect(
      findLlmOpenAiProviderPreset(
        'nous-research',
      )!
          .fallbackModels
          .map((model) => model.id),
      ['Hermes-4-405B', 'Hermes-4-70B'],
    );
    expect(
      findLlmOpenAiProviderPreset(
        'nscale',
      )!
          .fallbackModels
          .map((model) => model.id),
      [
        'moonshotai/Kimi-K2.5',
        'Qwen/Qwen3-235B-A22B-Instruct-2507',
        'openai/gpt-oss-120b',
        'openai/gpt-oss-20b',
        'meta-llama/Llama-4-Scout-17B-16E-Instruct',
        'meta-llama/Llama-3.3-70B-Instruct',
      ],
    );
    expect(findLlmOpenAiProviderPreset('nube')!.fallbackModels, isEmpty);
    expect(findLlmOpenAiProviderPreset('oci')!.fallbackModels, isEmpty);
    expect(findLlmOpenAiProviderPreset('ofoxai')!.fallbackModels, isEmpty);
    final ollamaCloud = findLlmOpenAiProviderPreset('ollama-cloud')!;
    expect(ollamaCloud.fallbackModels.map((model) => model.id), [
      'gpt-oss:20b',
      'gpt-oss:120b',
      'deepseek-v4-pro',
      'deepseek-v4-flash',
      'kimi-k2.6',
      'glm-5.1',
      'glm-5.2',
      'minimax-m3',
      'minimax-m2.7',
      'gemma4:31b',
      'nemotron-3-super',
      'qwen3.5:397b',
    ]);
    expect(ollamaCloud.fallbackModels.first.capabilities, {
      'reasoning': true,
      'supportedThinkingEfforts': ['low', 'medium', 'high'],
    });

    // NLP Cloud's `/v1/gpu` registry URL cannot be represented by this
    // connector, which appends `/chat/completions` to the configured endpoint.
    expect(findLlmOpenAiProviderPreset('nlpcloud'), isNull);
    // Naga.ai requires an API key; the similarly named Naga.ac registry entry
    // permits anonymous requests and is not the same account mode.
    expect(findLlmOpenAiProviderPreset('naga-ac'), isNull);
  });

  test('M43 fallback-only preset selection clears prior preset discovery URL',
      () {
    final nara = findLlmOpenAiProviderPreset('nara')!;
    final priorModelsUrl = findLlmOpenAiProviderPreset('fireworks')!.modelsUrl;
    final selected = nara.applyToEndpointConfig({
      'providerPresetId': 'fireworks',
      'baseUrl': 'https://api.fireworks.ai/inference/v1/chat/completions',
      'modelsUrl': priorModelsUrl,
      'accountOwnedConfig': 'preserved',
    });

    expect(selected['providerPresetId'], 'nara');
    expect(selected['baseUrl'], nara.baseUrl);
    expect(selected.containsKey('modelsUrl'), isFalse);
    expect(selected['accountOwnedConfig'], 'preserved');

    final customModelsUrl = nara.applyToEndpointConfig({
      'providerPresetId': 'fireworks',
      'modelsUrl': 'https://user.example/models',
    });
    expect(customModelsUrl['modelsUrl'], 'https://user.example/models');
  });

  test('M42 API-key presets retain audited endpoints and model discovery', () {
    const endpoints = {
      'logfare': 'https://logfare.ai/v1/chat/completions',
      'longcat': 'https://api.longcat.chat/openai/v1/chat/completions',
      'lyceum': 'https://api.lyceum.technology/openai/v1/chat/completions',
      'meganova-ai': 'https://api.meganova.ai/v1/chat/completions',
      'mixlayer': 'https://models.mixlayer.ai/v1/chat/completions',
      'mnn-ai': 'https://api.mnnai.ru/v1/chat/completions',
    };
    for (final entry in endpoints.entries) {
      final preset = findLlmOpenAiProviderPreset(entry.key)!;
      expect(preset.baseUrl, entry.value, reason: entry.key);
      expect(preset.authType, 'api_key', reason: entry.key);
      expect(preset.authorizationHeader, 'Authorization', reason: entry.key);
      expect(preset.authorizationScheme, 'Bearer', reason: entry.key);
      expect(preset.defaultApiProtocol, 'openai.chat_completions');
    }
    expect(
      {
        for (final id in [
          'logfare',
          'lyceum',
          'meganova-ai',
          'mixlayer',
          'mnn-ai',
        ])
          id: findLlmOpenAiProviderPreset(id)!.modelsUrl,
      },
      {
        'logfare': 'https://logfare.ai/v1/models',
        'lyceum': 'https://api.lyceum.technology/openai/v1/models',
        'meganova-ai': 'https://api.meganova.ai/v1/models',
        'mixlayer': 'https://models.mixlayer.ai/v1/models',
        'mnn-ai': 'https://api.mnnai.ru/v1/models',
      },
    );
    expect(findLlmOpenAiProviderPreset('longcat')!.modelsUrl, isNull);
    expect(
      findLlmOpenAiProviderPreset('longcat')!.fallbackModels.single.id,
      'LongCat-2.0',
    );
    expect(
      findLlmOpenAiProviderPreset('longcat')!
          .fallbackModels
          .single
          .capabilities,
      {'contextLength': 1048576},
    );
    for (final id in [
      'meta-llama',
      'modal',
      'maritalk',
      'modelscope',
      'monsterapi',
      'morph',
      'naga-ac',
    ]) {
      expect(findLlmOpenAiProviderPreset(id), isNull, reason: id);
    }
  });

  test('the source-backed presets retain their endpoint and auth metadata', () {
    expect(llmOpenAiProviderPresets.map((preset) => preset.id), [
      'api-airforce',
      'navy',
      'pioneer',
      'uc-direct',
      'agnes-cn',
      'ai21',
      'aimlapi',
      'ainative',
      'ainetcafe',
      'aion',
      'alibaba',
      'alibaba-cn',
      'ant-ling',
      'anyapi',
      'apmix',
      'arcee-ai',
      'auriko',
      'bai',
      'baichuan',
      'baidu',
      'bluesminds',
      'baseten',
      'bazaarlink',
      'beatapi',
      'bigmodel',
      'byteplus',
      'bytez',
      'cerebras',
      'charm-hyper',
      'chat-oripe',
      'chatanywhere',
      'chenzk',
      'cheaperinference',
      'chutes',
      'cloudcode-one',
      'codestral',
      'cohere',
      'coze',
      'crof',
      'daoxe',
      'demonroute',
      'dgrid',
      'digitalocean',
      'dit',
      'dxnt',
      'electronhub',
      'eurouter',
      'factory',
      'fastrouter',
      'featherless-ai',
      'deepinfra',
      'doubao',
      'fireworks',
      'groq',
      'huggingface',
      'iflytek',
      'internlm',
      'mistral',
      'novita',
      'nvidia',
      'siliconflow',
      'stepfun-cn',
      'stepfun-international',
      'together',
      'yi',
      'freeaiapikey',
      'freeinference',
      'freemodel-dev',
      'freetheai',
      'friendliai',
      'galadriel',
      'greenpt',
      'hcnsec',
      'helixmind',
      'helyxai',
      'heroku',
      'hyperbolic',
      'inception',
      'inference-net',
      'kenari',
      'kilo-gateway',
      'lambda-ai',
      'liquid',
      'literouter',
      'llamagate',
      'llm-kiwi',
      'llm7',
      'llmgateway',
      'logfare',
      'longcat',
      'lyceum',
      'meganova-ai',
      'mixlayer',
      'mnn-ai',
      'naga-ai',
      'nan',
      'nanogpt',
      'nara',
      'nebius',
      'nous-research',
      'nscale',
      'nube',
      'oci',
      'ofoxai',
      'ollama-cloud',
      'onomeo',
      'openadapter',
      'openvecta',
      'opper',
      'plamo',
      'poe',
      'poixe-ai',
      'poolside',
      'publicai',
      'regolo',
      'reka',
      'requesty',
      'sambanova',
      'sarvam',
      'scaleway',
      'sealion',
      'seekai',
      'sensenova',
      'sparkdesk',
      'speka',
      'synthetic',
      'tokenmarket',
      'tokenreply',
      'typhoon',
      'unifically',
      'unorouter',
      'upstage',
      'v0-vercel',
      'venice',
      'vercel-ai-gateway',
      'void-ai',
      'volcengine',
      'volcengine-agent-plan',
      'volcengine-coding-plan',
      'wandb',
      'writer',
      'xiaomi-mimo',
      'xkiro',
      'y-api',
      'yolo-auto',
      'zerolimitai',
      'zylo-api',
    ]);
    for (final preset in llmOpenAiProviderPresets) {
      expect(preset.baseUrl, startsWith('https://'));
      expect(preset.authType, 'api_key');
      if (const {'pioneer', 'uc-direct'}.contains(preset.id)) {
        expect(preset.authorizationHeader, 'X-API-Key', reason: preset.id);
        expect(preset.authorizationScheme, isEmpty, reason: preset.id);
      } else {
        expect(preset.authorizationHeader, 'Authorization', reason: preset.id);
        expect(preset.authorizationScheme, 'Bearer', reason: preset.id);
      }
      expect(preset.defaultApiProtocol, 'openai.chat_completions');
    }
    expect(
      {
        for (final preset in llmOpenAiProviderPresets)
          preset.id: preset.baseUrl,
      },
      {
        'ai21': 'https://api.ai21.com/studio/v1/chat/completions',
        'aimlapi': 'https://api.aimlapi.com/v1/chat/completions',
        'ainative': 'https://api.ainative.studio/api/v1/chat/completions',
        'ainetcafe': 'https://microquickjs.com/v1/chat/completions',
        'aion': 'https://api.aionlabs.ai/v1/chat/completions',
        'agnes-cn': 'https://api.agnes-ai.cn/v1/chat/completions',
        'alibaba':
            'https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions',
        'alibaba-cn':
            'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
        'arcee-ai': 'https://api.arcee.ai/api/v1/chat/completions',
        'ant-ling': 'https://api.ant-ling.com/v1/chat/completions',
        'anyapi': 'https://api.anyapi.ai/v1/chat/completions',
        'apmix': 'https://api.apmix.ai/v1/chat/completions',
        'api-airforce': 'https://api.airforce/v1/chat/completions',
        'auriko': 'https://api.auriko.ai/v1/chat/completions',
        'bai': 'https://api.b.ai/v1/chat/completions',
        'baseten': 'https://inference.baseten.co/v1/chat/completions',
        'baichuan': 'https://api.baichuan-ai.com/v1/chat/completions',
        'baidu': 'https://qianfan.baidubce.com/v2/chat/completions',
        'bluesminds': 'https://api.bluesminds.com/v1/chat/completions',
        'bigmodel': 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
        'bazaarlink': 'https://bazaarlink.ai/api/v1/chat/completions',
        'beatapi': 'https://api.beatapi.io/v1/chat/completions',
        'byteplus':
            'https://ark.ap-southeast.bytepluses.com/api/v3/chat/completions',
        'bytez': 'https://api.bytez.com/models/v2/openai/v1/chat/completions',
        'charm-hyper': 'https://hyper.charm.land/v1/chat/completions',
        'chat-oripe': 'https://api.oriper.com/v1/chat/completions',
        'chatanywhere': 'https://api.chatanywhere.org/v1/chat/completions',
        'chenzk': 'https://chenzk.top/v1/chat/completions',
        'cheaperinference':
            'https://api.cheaperinference.com/v1/chat/completions',
        'cloudcode-one': 'https://api.cloudcode.one/v1/chat/completions',
        'codestral': 'https://codestral.mistral.ai/v1/chat/completions',
        'cohere': 'https://api.cohere.com/compatibility/v1/chat/completions',
        'coze': 'https://api.coze.com/v1/chat/completions',
        'crof': 'https://crof.ai/v1/chat/completions',
        'daoxe': 'https://api.daoxe.com/v1/chat/completions',
        'demonroute': 'https://api.demonroute.com/v1/chat/completions',
        'dgrid': 'https://api.dgrid.ai/v1/chat/completions',
        'digitalocean': 'https://inference.do-ai.run/v1/chat/completions',
        'dit': 'https://api.dit.ai/v1/chat/completions',
        'dxnt': 'https://www.dxnt.com/v1/chat/completions',
        'electronhub': 'https://api.electronhub.ai/v1/chat/completions',
        'eurouter': 'https://api.eurouter.ai/v1/chat/completions',
        'factory': 'https://api.factory.ai/v1/chat/completions',
        'fastrouter': 'https://api.fastrouter.ai/api/v1/chat/completions',
        'featherless-ai': 'https://api.featherless.ai/v1/chat/completions',
        'cerebras': 'https://api.cerebras.ai/v1/chat/completions',
        'chutes': 'https://llm.chutes.ai/v1/chat/completions',
        'deepinfra': 'https://api.deepinfra.com/v1/openai/chat/completions',
        'doubao': 'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
        'fireworks': 'https://api.fireworks.ai/inference/v1/chat/completions',
        'groq': 'https://api.groq.com/openai/v1/chat/completions',
        'huggingface': 'https://router.huggingface.co/v1/chat/completions',
        'iflytek': 'https://spark-api-open.xf-yun.com/v1/chat/completions',
        'internlm': 'https://chat.intern-ai.org.cn/api/v1/chat/completions',
        'mistral': 'https://api.mistral.ai/v1/chat/completions',
        'novita': 'https://api.novita.ai/openai/v1/chat/completions',
        'nvidia': 'https://integrate.api.nvidia.com/v1/chat/completions',
        'siliconflow': 'https://api.siliconflow.com/v1/chat/completions',
        'stepfun-cn': 'https://api.stepfun.com/v1/chat/completions',
        'stepfun-international': 'https://api.stepfun.ai/v1/chat/completions',
        'together': 'https://api.together.xyz/v1/chat/completions',
        'yi': 'https://api.lingyiwanwu.com/v1/chat/completions',
        'freeaiapikey': 'https://api.freeaiapikey.com/v1/chat/completions',
        'freeinference': 'https://freeinference.org/v1/chat/completions',
        'freemodel-dev': 'https://api.freemodel.dev/v1/chat/completions',
        'freetheai': 'https://api.freetheai.org/v1/chat/completions',
        'friendliai': 'https://api.friendli.ai/serverless/v1/chat/completions',
        'galadriel': 'https://api.galadriel.ai/v1/chat/completions',
        'greenpt': 'https://api.greenpt.ai/v1/chat/completions',
        'hcnsec': 'https://api.hcnsec.cn/v1/chat/completions',
        'helixmind': 'https://helixmind.online/v1/chat/completions',
        'helyxai': 'https://helyxai.space/v1/chat/completions',
        'heroku': 'https://us.inference.heroku.com/v1/chat/completions',
        'hyperbolic': 'https://api.hyperbolic.xyz/v1/chat/completions',
        'inception': 'https://api.inceptionlabs.ai/v1/chat/completions',
        'inference-net': 'https://api.inference.net/v1/chat/completions',
        'kenari': 'https://kenari.id/v1/chat/completions',
        'kilo-gateway': 'https://api.kilo.ai/api/gateway/chat/completions',
        'lambda-ai': 'https://api.lambda.ai/v1/chat/completions',
        'liquid': 'https://inference.liquid.ai/v1/chat/completions',
        'literouter': 'https://api.literouter.com/v1/chat/completions',
        'llamagate': 'https://llamagate.ai/v1/chat/completions',
        'llm-kiwi': 'https://api.llm.kiwi/v1/chat/completions',
        'llm7': 'https://api.llm7.io/v1/chat/completions',
        'llmgateway': 'https://api.llmgateway.io/v1/chat/completions',
        'logfare': 'https://logfare.ai/v1/chat/completions',
        'longcat': 'https://api.longcat.chat/openai/v1/chat/completions',
        'lyceum': 'https://api.lyceum.technology/openai/v1/chat/completions',
        'meganova-ai': 'https://api.meganova.ai/v1/chat/completions',
        'mixlayer': 'https://models.mixlayer.ai/v1/chat/completions',
        'mnn-ai': 'https://api.mnnai.ru/v1/chat/completions',
        'naga-ai': 'https://api.naga.ac/v1/chat/completions',
        'nan': 'https://api.nan.builders/v1/chat/completions',
        'nanogpt': 'https://nano-gpt.com/api/v1/chat/completions',
        'nara': 'https://router.bynara.id/v1/chat/completions',
        'navy': 'https://api.navy/v1/chat/completions',
        'nebius': 'https://api.tokenfactory.nebius.com/v1/chat/completions',
        'nous-research':
            'https://inference-api.nousresearch.com/v1/chat/completions',
        'nscale': 'https://inference.api.nscale.com/v1/chat/completions',
        'nube': 'https://ai.nube.sh/api/v1/chat/completions',
        'oci':
            'https://inference.generativeai.us-chicago-1.oci.oraclecloud.com/openai/v1/chat/completions',
        'ofoxai': 'https://api.ofox.ai/v1/chat/completions',
        'ollama-cloud': 'https://ollama.com/v1/chat/completions',
        'onomeo': 'https://onomeo.com/v1/chat/completions',
        'openadapter': 'https://api.openadapter.in/v1/chat/completions',
        'openvecta': 'https://api.openvecta.com/v1/chat/completions',
        'opper': 'https://api.opper.ai/v3/compat/chat/completions',
        'plamo': 'https://api.platform.preferredai.jp/v1/chat/completions',
        'poe': 'https://api.poe.com/v1/chat/completions',
        'poixe-ai': 'https://api.poixe.com/v1/chat/completions',
        'pioneer': 'https://api.pioneer.ai/v1/chat/completions',
        'poolside': 'https://inference.poolside.ai/v1/chat/completions',
        'publicai': 'https://api.publicai.co/v1/chat/completions',
        'regolo': 'https://api.regolo.ai/v1/chat/completions',
        'reka': 'https://api.reka.ai/v1/chat/completions',
        'requesty': 'https://router.requesty.ai/v1/chat/completions',
        'sambanova': 'https://api.sambanova.ai/v1/chat/completions',
        'sarvam': 'https://api.sarvam.ai/v1/chat/completions',
        'scaleway': 'https://api.scaleway.ai/v1/chat/completions',
        'sealion': 'https://api.sea-lion.ai/v1/chat/completions',
        'seekai': 'https://seekai.cc/v1/chat/completions',
        'sensenova': 'https://token.sensenova.cn/v1/chat/completions',
        'sparkdesk': 'https://spark-api-open.xf-yun.com/v1/chat/completions',
        'speka': 'https://speka.me/v1/chat/completions',
        'synthetic': 'https://api.synthetic.new/openai/v1/chat/completions',
        'tokenmarket': 'https://api.tokensmarket.ai/v1/chat/completions',
        'tokenreply': 'https://api.tokenreply.com/v1/chat/completions',
        'typhoon': 'https://api.opentyphoon.ai/v1/chat/completions',
        'uc-direct': 'https://api.uncensored.com/api/v1',
        'unifically': 'https://api.unifically.com/v1/chat/completions',
        'unorouter': 'https://api.unorouter.com/v1/chat/completions',
        'upstage': 'https://api.upstage.ai/v1/chat/completions',
        'v0-vercel': 'https://api.v0.dev/v1/chat/completions',
        'venice': 'https://api.venice.ai/api/v1/chat/completions',
        'vercel-ai-gateway': 'https://ai-gateway.vercel.sh/v1/chat/completions',
        'void-ai': 'https://api.voidai.app/v1/chat/completions',
        'volcengine':
            'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
        'volcengine-agent-plan':
            'https://ark.cn-beijing.volces.com/api/plan/v3/chat/completions',
        'volcengine-coding-plan':
            'https://ark.cn-beijing.volces.com/api/coding/v3/chat/completions',
        'wandb': 'https://api.inference.wandb.ai/v1/chat/completions',
        'writer': 'https://api.writer.com/v1/chat/completions',
        'xiaomi-mimo': 'https://api.xiaomimimo.com/v1/chat/completions',
        'xkiro': 'https://api.xkiro.com/v1/chat/completions',
        'y-api': 'https://api.y-api.bestvirtualgoods.com/v1/chat/completions',
        'yolo-auto': 'https://yolo-auto.com/v1/chat/completions',
        'zerolimitai': 'https://www.zerolimitai.com/api/v1/chat/completions',
        'zylo-api': 'https://api.zyloai.net/v1/chat/completions',
      },
    );
    expect(
      findLlmOpenAiProviderPreset('alibaba')?.modelsUrl,
      'https://dashscope-intl.aliyuncs.com/compatible-mode/v1/models',
    );
    expect(
      findLlmOpenAiProviderPreset('alibaba-cn')?.modelsUrl,
      'https://dashscope.aliyuncs.com/compatible-mode/v1/models',
    );
    expect(
      findLlmOpenAiProviderPreset('byteplus')?.modelsUrl,
      'https://ark.ap-southeast.bytepluses.com/api/v3/models',
    );
    expect(
      {
        for (final id in [
          'kenari',
          'kilo-gateway',
          'liquid',
          'literouter',
          'llm-kiwi',
          'llm7',
          'llmgateway',
          'logfare',
          'lyceum',
          'meganova-ai',
          'mixlayer',
          'mnn-ai',
        ])
          id: findLlmOpenAiProviderPreset(id)!.modelsUrl,
      },
      {
        'kenari': 'https://kenari.id/v1/models',
        'kilo-gateway': 'https://api.kilo.ai/api/gateway/models',
        'liquid': 'https://inference.liquid.ai/v1/models',
        'literouter': 'https://api.literouter.com/v1/models',
        'llm-kiwi': 'https://api.llm.kiwi/v1/models',
        'llm7': 'https://api.llm7.io/v1/models',
        'llmgateway': 'https://api.llmgateway.io/v1/models',
        'logfare': 'https://logfare.ai/v1/models',
        'lyceum': 'https://api.lyceum.technology/openai/v1/models',
        'meganova-ai': 'https://api.meganova.ai/v1/models',
        'mixlayer': 'https://models.mixlayer.ai/v1/models',
        'mnn-ai': 'https://api.mnnai.ru/v1/models',
      },
    );
    expect(
      {
        for (final id in [
          'inception',
          'inference-net',
          'lambda-ai',
          'llamagate'
        ])
          id: findLlmOpenAiProviderPreset(id)!.modelsUrl,
      },
      {
        'inception': null,
        'inference-net': null,
        'lambda-ai': null,
        'llamagate': null,
      },
    );
    expect(
      findLlmOpenAiProviderPreset('inception')!.fallbackModels.map(
            (model) => [model.id, model.capabilities],
          ),
      [
        [
          'mercury-2',
          {'contextLength': 128000, 'maxOutputTokens': 50000},
        ],
        [
          'mercury-2.5',
          {'contextLength': 260000, 'maxOutputTokens': 65536},
        ],
      ],
    );
    expect(
      {
        for (final id in ['bytez', 'codestral', 'coze'])
          id: findLlmOpenAiProviderPreset(id)!.modelsUrl,
      },
      {'bytez': null, 'codestral': null, 'coze': null},
    );
    expect(
      {
        for (final id in [
          'crof',
          'daoxe',
          'demonroute',
          'dgrid',
          'digitalocean',
          'dit',
          'dxnt',
          'electronhub',
          'eurouter',
          'factory',
          'fastrouter',
          'featherless-ai',
        ])
          id: findLlmOpenAiProviderPreset(id)!.modelsUrl,
      },
      {
        'crof': null,
        'daoxe': 'https://api.daoxe.com/v1/models',
        'demonroute': 'https://api.demonroute.com/v1/models',
        'dgrid': 'https://api.dgrid.ai/v1/models',
        'digitalocean': 'https://inference.do-ai.run/v1/models',
        'dit': 'https://api.dit.ai/v1/models',
        'dxnt': 'https://www.dxnt.com/v1/models',
        'electronhub': 'https://api.electronhub.ai/v1/models',
        'eurouter': 'https://api.eurouter.ai/v1/models',
        'factory': null,
        'fastrouter': 'https://api.fastrouter.ai/api/v1/models',
        'featherless-ai': null,
      },
    );
    expect(
      {
        for (final id in [
          'crof',
          'daoxe',
          'demonroute',
          'dgrid',
          'digitalocean',
          'dit',
          'dxnt',
          'electronhub',
          'eurouter',
          'factory',
          'fastrouter',
          'featherless-ai',
        ])
          id: findLlmOpenAiProviderPreset(id)!
              .fallbackModels
              .map((model) => model.id)
              .toList(),
      },
      {
        'crof': [
          'deepseek-v4-pro',
          'deepseek-v4-flash',
          'deepseek-v4-flash-0731',
          'deepseek-v3.2',
          'kimi-k2.6',
          'kimi-k2.7-code',
          'kimi-k3',
          'kimi-k3-eco',
          'glm-5.1',
          'glm-5.2',
          'mimo-v2.5-pro',
          'gemma-4-31b-it',
          'qwen3.6-27b',
          'qwen3.5-397b-a17b',
          'qwen3.5-9b',
        ],
        'daoxe': [
          'claude-sonnet-4-6',
          'claude-opus-4-8',
          'claude-haiku-4-5-20251001',
          'gpt-5.5',
          'gpt-5.4',
          'gemini-3.1-pro-preview',
          'grok-4.5',
          'grok-4.3',
          'kimi-k2.5',
        ],
        'demonroute': [
          'dphn/Dolphin3.0-Llama3.1-8B',
          'dphn/Dolphin-Mistral-24B-Venice-Edition',
          'TheDrummer/Artemis-31B-v1.2',
          'TheDrummer/Cydonia-24B-v4.3',
          'huihui-ai/Huihui-Qwen3.6-35B-A3B-abliterated',
          'huihui-ai/Huihui-gemma-4-31B-it-abliterated-v2',
          'dphn/dolphin-2.9.3-mistral-nemo-12b',
        ],
        'dgrid': ['dgridai/free'],
        'digitalocean': <String>[],
        'dit': ['gpt-5.4', 'claude-sonnet-4-6'],
        'dxnt': <String>[],
        'electronhub': <String>[],
        'eurouter': <String>[],
        'factory': ['auto'],
        'fastrouter': <String>[],
        'featherless-ai': [
          'featherless-ai/Qwerky-72B',
          'featherless-ai/Qwerky-QwQ-32B'
        ],
      },
    );
    final crofModels = findLlmOpenAiProviderPreset('crof')!.fallbackModels;
    final crofReasoningModelIds = {
      'deepseek-v4-pro',
      'deepseek-v4-flash',
      'deepseek-v4-flash-0731',
      'kimi-k2.6',
      'kimi-k2.7-code',
      'kimi-k3',
      'kimi-k3-eco',
      'glm-5.1',
      'glm-5.2',
      'mimo-v2.5-pro',
      'gemma-4-31b-it',
      'qwen3.6-27b',
      'qwen3.5-397b-a17b',
      'qwen3.5-9b',
    };
    expect(
      crofModels
          .where((model) => model.capabilities['reasoning'] == true)
          .map((model) => model.id)
          .toSet(),
      crofReasoningModelIds,
    );
    for (final model in crofModels.where(
      (model) => crofReasoningModelIds.contains(model.id),
    )) {
      expect(model.capabilities, {
        'reasoning': true,
        'supportedThinkingEfforts': ['none', 'low', 'medium', 'high', 'max'],
      });
    }
    expect(
      {
        for (final id in [
          'crof',
          'daoxe',
          'demonroute',
          'dgrid',
          'digitalocean',
          'dit',
          'dxnt',
          'electronhub',
          'eurouter',
          'factory',
          'fastrouter',
          'featherless-ai',
        ])
          id: {
            for (final model in findLlmOpenAiProviderPreset(id)!.fallbackModels)
              model.id: model.displayName,
          },
      },
      {
        'crof': {
          'deepseek-v4-pro': 'DeepSeek V4 Pro',
          'deepseek-v4-flash': 'DeepSeek V4 Flash',
          'deepseek-v4-flash-0731': 'DeepSeek V4 Flash 0731',
          'deepseek-v3.2': 'DeepSeek V3.2',
          'kimi-k2.6': 'Kimi K2.6',
          'kimi-k2.7-code': 'Kimi K2.7 Code',
          'kimi-k3': 'Kimi K3',
          'kimi-k3-eco': 'Kimi K3 Eco',
          'glm-5.1': 'GLM 5.1',
          'glm-5.2': 'GLM 5.2',
          'mimo-v2.5-pro': 'Mimo 2.5 Pro',
          'gemma-4-31b-it': 'Gemma 4 31B',
          'qwen3.6-27b': 'Qwen3.6 27B',
          'qwen3.5-397b-a17b': 'Qwen3.5 397B A17B',
          'qwen3.5-9b': 'Qwen3.5 9B',
        },
        'daoxe': {
          'claude-sonnet-4-6': 'Claude Sonnet 4.6',
          'claude-opus-4-8': 'Claude Opus 4.8',
          'claude-haiku-4-5-20251001': 'Claude Haiku 4.5',
          'gpt-5.5': 'GPT-5.5',
          'gpt-5.4': 'GPT-5.4',
          'gemini-3.1-pro-preview': 'Gemini 3.1 Pro Preview',
          'grok-4.5': 'Grok 4.5',
          'grok-4.3': 'Grok 4.3',
          'kimi-k2.5': 'Kimi K2.5',
        },
        'demonroute': {
          'dphn/Dolphin3.0-Llama3.1-8B': 'Dolphin 3.0 Llama 3.1 8B',
          'dphn/Dolphin-Mistral-24B-Venice-Edition':
              'Dolphin Mistral 24B Venice',
          'TheDrummer/Artemis-31B-v1.2': 'Artemis 31B v1.2',
          'TheDrummer/Cydonia-24B-v4.3': 'Cydonia 24B v4.3',
          'huihui-ai/Huihui-Qwen3.6-35B-A3B-abliterated':
              'Huihui Qwen 3.6 35B A3B Abliterated',
          'huihui-ai/Huihui-gemma-4-31B-it-abliterated-v2':
              'Huihui Gemma 4 31B Abliterated v2',
          'dphn/dolphin-2.9.3-mistral-nemo-12b':
              'Dolphin 2.9.3 Mistral Nemo 12B',
        },
        'dgrid': {'dgridai/free': 'DGrid Free Models Router'},
        'digitalocean': <String, String>{},
        'dit': {
          'gpt-5.4': 'GPT-5.4 (DIT.ai)',
          'claude-sonnet-4-6': 'Claude Sonnet 4.6 (DIT.ai)',
        },
        'dxnt': <String, String>{},
        'electronhub': <String, String>{},
        'eurouter': <String, String>{},
        'factory': {'auto': 'Factory Auto (best model)'},
        'fastrouter': <String, String>{},
        'featherless-ai': {
          'featherless-ai/Qwerky-72B': 'featherless-ai/Qwerky-72B',
          'featherless-ai/Qwerky-QwQ-32B': 'featherless-ai/Qwerky-QwQ-32B',
        },
      },
    );
    expect(
      findLlmOpenAiProviderPreset('crof')!.fallbackModels.first.capabilities,
      {
        'reasoning': true,
        'supportedThinkingEfforts': ['none', 'low', 'medium', 'high', 'max']
      },
    );
    expect(
        findLlmOpenAiProviderPreset('dgrid')!
            .fallbackModels
            .single
            .capabilities,
        {'contextLength': 128000});
    expect(
      findLlmOpenAiProviderPreset('dit')!.fallbackModels.first.capabilities,
      {
        'contextLength': 400000,
        'toolCalling': true,
        'reasoning': true,
        'vision': true
      },
    );
    expect(
      findLlmOpenAiProviderPreset('dit')!.fallbackModels[1].capabilities,
      {
        'contextLength': 200000,
        'toolCalling': true,
        'reasoning': true,
        'vision': true,
        'supportedThinkingEfforts': ['low', 'medium', 'high', 'max'],
      },
    );
    expect(
      findLlmOpenAiProviderPreset('fireworks')?.modelsUrl,
      'https://api.fireworks.ai/v1/accounts/fireworks/models?filter=supports_serverless=true',
    );
    expect(
      findLlmOpenAiProviderPreset('fireworks')?.modelIdPrefix,
      'accounts/fireworks/models/',
    );
    expect(
      findLlmOpenAiProviderPreset('huggingface')?.modelsUrl,
      'https://router.huggingface.co/v1/models',
    );
    expect(
      findLlmOpenAiProviderPreset('novita')?.modelsUrl,
      'https://api.novita.ai/openai/v1/models',
    );
    expect(
      {
        for (final id in [
          'agnes-cn',
          'ainative',
          'ainetcafe',
          'aion',
          'ant-ling',
          'anyapi',
          'apmix',
          'auriko',
          'baidu',
          'bluesminds',
          'bazaarlink',
          'beatapi',
          'charm-hyper',
          'chat-oripe',
          'chatanywhere',
          'cloudcode-one',
          'cohere',
        ])
          id: findLlmOpenAiProviderPreset(id)!.modelsUrl,
      },
      {
        'agnes-cn': 'https://api.agnes-ai.cn/v1/models',
        'ainative': 'https://api.ainative.studio/api/v1/models',
        'ainetcafe': 'https://microquickjs.com/v1/models',
        'aion': 'https://api.aionlabs.ai/v1/models',
        'ant-ling': null,
        'anyapi': 'https://api.anyapi.ai/v1/models',
        'apmix': 'https://api.apmix.ai/v1/models',
        'auriko': 'https://api.auriko.ai/v1/models',
        'baidu': null,
        'bluesminds': 'https://api.bluesminds.com/v1/models',
        'bazaarlink': 'https://bazaarlink.ai/api/v1/models',
        'beatapi': 'https://api.beatapi.io/v1/models',
        'charm-hyper': 'https://hyper.charm.land/v1/models',
        'chat-oripe': 'https://api.oriper.com/v1/models',
        'chatanywhere': 'https://api.chatanywhere.org/v1/models',
        'cloudcode-one': 'https://api.cloudcode.one/v1/models',
        'cohere': 'https://api.cohere.com/compatibility/v1/models',
      },
    );
    for (final id in [
      'agnes-cn',
      'ainative',
      'ainetcafe',
      'aion',
      'ant-ling',
      'anyapi',
      'apmix',
      'auriko',
      'baidu',
      'bazaarlink',
      'beatapi',
    ]) {
      expect(findLlmOpenAiProviderPreset(id)!.modelIdPrefix, isEmpty);
    }
    expect(findLlmOpenAiProviderPreset('baidu')!.displayName,
        'Baidu ERNIE (Qianfan)');
    final stepfunChina = findLlmOpenAiProviderPreset('stepfun-cn')!;
    final stepfunInternational =
        findLlmOpenAiProviderPreset('stepfun-international')!;
    expect(stepfunChina.displayName, 'StepFun China (.com)');
    expect(stepfunChina.modelsUrl, 'https://api.stepfun.com/v1/models');
    expect(stepfunInternational.displayName, 'StepFun International (.ai)');
    expect(stepfunInternational.modelsUrl, isNull);
    for (final preset in [stepfunChina, stepfunInternational]) {
      expect(preset.authType, 'api_key');
      expect(preset.authorizationHeader, 'Authorization');
      expect(preset.authorizationScheme, 'Bearer');
      expect(preset.defaultApiProtocol, 'openai.chat_completions');
      expect(preset.fallbackModels.map((model) => model.id), [
        'step-5-preview',
        'step-3.7-flash',
        'step-3.5-flash',
        'step-3.5-flash-2603',
        'step-1o-turbo-vision',
        'step-1v',
      ]);
      expect(preset.fallbackModels.map((model) => model.displayName), [
        'Step 5 Preview',
        'Step 3.7 Flash',
        'Step 3.5 Flash',
        'Step 3.5 Flash 2603',
        'Step 1o Turbo Vision',
        'Step 1V',
      ]);
    }
    expect(stepfunChina.fallbackModels.first.capabilities, {
      'contextLength': 1024000,
      'reasoning': true,
      'supportedThinkingEfforts': ['low', 'medium', 'high'],
      'vision': true,
      'toolCalling': true,
    });
    expect(
      stepfunChina.fallbackModels
          .map((model) => model.capabilities['contextLength'])
          .toList(),
      [1024000, 262144, 262144, 262144, 32768, null],
    );
    expect(
      findLlmOpenAiProviderPreset('ai21')!
          .fallbackModels
          .map((model) => model.id),
      containsAll(['jamba-large-1.7', 'jamba-mini-2']),
    );
    expect(
      findLlmOpenAiProviderPreset('bigmodel')!.fallbackModels.first.id,
      'glm-5.3',
    );
    expect(
      findLlmOpenAiProviderPreset('byteplus')!
          .fallbackModels
          .first
          .capabilities,
      {'contextLength': 128000},
    );
    expect(
      findLlmOpenAiProviderPreset('iflytek')!.fallbackModels.first.id,
      '4.0Ultra',
    );
    expect(
      findLlmOpenAiProviderPreset('siliconflow')!.fallbackModels.first.id,
      'deepseek-ai/DeepSeek-V3.2',
    );
    expect(
      findLlmOpenAiProviderPreset('siliconflow')!
          .fallbackModels
          .first
          .displayName,
      'DeepSeek V3.2',
    );
    expect(
      findLlmOpenAiProviderPreset('deepinfra')!.fallbackModels[7].id,
      'nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning',
    );
  });

  test(
    'M41 candidates match pinned registry endpoints, models, and deferrals',
    () {
      const expectedModelsUrls = {
        'inception': null,
        'inference-net': null,
        'kenari': 'https://kenari.id/v1/models',
        'kilo-gateway': 'https://api.kilo.ai/api/gateway/models',
        'lambda-ai': null,
        'liquid': 'https://inference.liquid.ai/v1/models',
        'literouter': 'https://api.literouter.com/v1/models',
        'llamagate': null,
        'llm-kiwi': 'https://api.llm.kiwi/v1/models',
        'llm7': 'https://api.llm7.io/v1/models',
        'llmgateway': 'https://api.llmgateway.io/v1/models',
      };
      for (final entry in expectedModelsUrls.entries) {
        final preset = findLlmOpenAiProviderPreset(entry.key)!;
        expect(preset.modelsUrl, entry.value, reason: entry.key);
        expect(preset.authType, 'api_key', reason: entry.key);
        expect(preset.authorizationHeader, 'Authorization', reason: entry.key);
        expect(preset.authorizationScheme, 'Bearer', reason: entry.key);
        expect(
          preset.defaultApiProtocol,
          'openai.chat_completions',
          reason: entry.key,
        );
      }
      expect(
        {
          for (final id in [
            'inception',
            'inference-net',
            'kenari',
            'kilo-gateway',
            'lambda-ai',
            'liquid',
            'literouter',
            'llamagate',
            'llm-kiwi',
            'llm7',
            'llmgateway',
          ])
            id: findLlmOpenAiProviderPreset(id)!
                .fallbackModels
                .map((model) => model.id)
                .toList(),
        },
        {
          'inception': ['mercury-2', 'mercury-2.5'],
          'inference-net': [
            'meta-llama/Llama-3.3-70B-Instruct',
            'deepseek-ai/DeepSeek-R1',
            'Qwen/Qwen2.5-72B-Instruct',
          ],
          'kenari': <String>[],
          'kilo-gateway': [
            'kilo-auto/frontier',
            'kilo-auto/balanced',
            'kilo-auto/free',
            'nvidia/nemotron-3-super-120b-a12b:free',
            'minimax/minimax-m2.5:free',
            'arcee-ai/trinity-large-preview:free',
          ],
          'lambda-ai': [
            'deepseek-r1-671b',
            'llama3.3-70b-instruct-fp8',
            'qwen25-coder-32b-instruct',
          ],
          'liquid': ['liquid-lfm-40b'],
          'literouter': <String>[],
          'llamagate': [
            'qwen2.5-coder-7b',
            'deepseek-coder-6.7b',
            'qwen3-vl-8b',
          ],
          'llm-kiwi': ['auto', 'hrLLM'],
          'llm7': [
            'gpt-4o-mini-2024-07-18',
            'gpt-4.1-nano-2025-04-14',
            'deepseek-r1-0528',
            'qwen2.5-coder-32b-instruct',
          ],
          'llmgateway': <String>[],
        },
      );
      expect(
        findLlmOpenAiProviderPreset('inception')!
            .fallbackModels
            .map((model) => model.capabilities),
        [
          {'contextLength': 128000, 'maxOutputTokens': 50000},
          {'contextLength': 260000, 'maxOutputTokens': 65536},
        ],
      );
      // Deferred: open-sse/config/providers/registry/kimi/index.ts:4-15 uses
      // executor "moonshot" and forces streaming, outside the shared default
      // OpenAI Chat Completions preset path.
      // Deferred: open-sse/config/providers/registry/kimi/coding-apikey/index.ts:4-9
      // inherits the Claude format, Anthropic endpoint, and x-api-key header.
      // The separate Kimi Code OAuth/session mode still needs its later approved
      // auth/provider unit; this API-key deferral does not cover that work.
      expect(findLlmOpenAiProviderPreset('kimi'), isNull);
      expect(findLlmOpenAiProviderPreset('kimi-coding-apikey'), isNull);
    },
  );

  test('M40 presets match pinned runtime endpoints, discovery, and models', () {
    const expectedModelsUrls = {
      'freeaiapikey': 'https://api.freeaiapikey.com/v1/models',
      'freeinference': 'https://freeinference.org/v1/models',
      'freemodel-dev': 'https://api.freemodel.dev/v1/models',
      'freetheai': 'https://api.freetheai.org/v1/models',
      'friendliai': 'https://api.friendli.ai/serverless/v1/models',
      'galadriel': null,
      'greenpt': 'https://api.greenpt.ai/v1/models',
      'hcnsec': 'https://api.hcnsec.cn/v1/models',
      'helixmind': 'https://helixmind.online/v1/models',
      'helyxai': 'https://helyxai.space/v1/models',
      'heroku': null,
      'hyperbolic': null,
    };
    final m40Presets = [
      for (final id in expectedModelsUrls.keys)
        findLlmOpenAiProviderPreset(id)!,
    ];
    expect(m40Presets.map((preset) => preset.baseUrl).toSet(), hasLength(12));
    for (final entry in expectedModelsUrls.entries) {
      final preset = findLlmOpenAiProviderPreset(entry.key)!;
      expect(preset.modelsUrl, entry.value, reason: entry.key);
      expect(preset.baseUrl, startsWith('https://'));
      expect(preset.authType, 'api_key');
      expect(preset.authorizationHeader, 'Authorization');
      expect(preset.authorizationScheme, 'Bearer');
      expect(preset.defaultApiProtocol, 'openai.chat_completions');
    }
    expect(
      findLlmOpenAiProviderPreset('freeaiapikey')!
          .fallbackModels
          .map((model) => model.id),
      [
        'openai/gpt-4o',
        'openai/gpt-5.4',
        'openai/gpt-5.5',
        'openai/gpt-5.6-sol',
        'anthropic/claude-opus-4.6',
        'anthropic/claude-opus-4.7',
        'anthropic/claude-opus-4.8',
        'anthropic/claude-opus-5',
        'anthropic/claude-sonnet-4.6',
        'anthropic/claude-sonnet-5',
      ],
    );
    final freeAiModels =
        findLlmOpenAiProviderPreset('freeaiapikey')!.fallbackModels;
    expect(
      freeAiModels.map((model) => model.capabilities['contextLength']),
      [
        128000,
        128000,
        128000,
        128000,
        1000000,
        128000,
        128000,
        128000,
        1000000,
        128000,
      ],
    );
    expect(
      freeAiModels[4].capabilities,
      {
        'contextLength': 1000000,
        'reasoning': true,
        'supportedThinkingEfforts': ['low', 'medium', 'high', 'max'],
      },
    );
    expect(
      findLlmOpenAiProviderPreset('freeinference')!.fallbackModels,
      isEmpty,
    );
    expect(
      findLlmOpenAiProviderPreset('freemodel-dev')!
          .fallbackModels
          .map((model) => model.id),
      ['gpt-5.5', 'gpt-5.4', 'gpt-5.4-mini', 'gpt-5.3-codex'],
    );
    expect(
      findLlmOpenAiProviderPreset('freemodel-dev')!
          .fallbackModels
          .map((model) => model.capabilities['contextLength']),
      [400000, 400000, 128000, 128000],
    );
    expect(
      findLlmOpenAiProviderPreset('freetheai')!
          .fallbackModels
          .map((model) => model.id),
      ['fta/zai/glm-5.3', 'fta/kimi/k3'],
    );
    expect(
      findLlmOpenAiProviderPreset('freetheai')!
          .fallbackModels
          .map((model) => model.capabilities['contextLength']),
      [128000, 128000],
    );
    expect(
      findLlmOpenAiProviderPreset('friendliai')!
          .fallbackModels
          .map((model) => model.id),
      ['meta-llama-3.1-70b-instruct', 'meta-llama-3.1-8b-instruct'],
    );
    expect(
      findLlmOpenAiProviderPreset('galadriel')!
          .fallbackModels
          .map((model) => model.id),
      ['galadriel-latest'],
    );
    expect(
      findLlmOpenAiProviderPreset('heroku')!
          .fallbackModels
          .map((model) => model.id),
      [
        'claude-opus-4-7',
        'claude-4-6-sonnet',
        'claude-4-5-haiku',
        'glm-4-7',
        'kimi-k2-5',
        'minimax-m2-1',
        'deepseek-v3-2',
        'qwen3-coder-480b',
        'qwen3-235b',
        'gpt-oss-120b',
        'nova-pro',
        'nova-2-lite',
      ],
    );
    expect(
      findLlmOpenAiProviderPreset('hyperbolic')!
          .fallbackModels
          .map((model) => model.id),
      [
        'Qwen/QwQ-32B',
        'deepseek-ai/DeepSeek-R1',
        'deepseek-ai/DeepSeek-V3',
        'meta-llama/Llama-3.3-70B-Instruct',
        'meta-llama/Llama-3.2-3B-Instruct',
        'Qwen/Qwen2.5-72B-Instruct',
        'Qwen/Qwen2.5-Coder-32B-Instruct',
        'NousResearch/Hermes-3-Llama-3.1-70B',
      ],
    );
    // Deferred: pinned registry/glm/t/index.ts:4-16 selects `executor: glm`,
    // the +08:00 reset timezone, request defaults, and a custom timeout. The
    // registered GLM provider routes through executors/default.ts:448-455, while
    // executors/default.ts:583-590 emits the GLM-specific x-api-key header.
    // `REGISTRY.glmt` at config/providers/index.ts:313 confirms runtime registration.
    expect(findLlmOpenAiProviderPreset('glmt'), isNull);
  });

  test(
    'M37 presets retain the pinned source fallback catalog',
    () {
      final fallbackIds = {
        for (final id in [
          'agnes-cn',
          'ainative',
          'ainetcafe',
          'aion',
          'ant-ling',
          'anyapi',
          'apmix',
          'auriko',
          'baidu',
          'bazaarlink',
          'beatapi',
        ])
          id: findLlmOpenAiProviderPreset(id)!
              .fallbackModels
              .map((model) => model.id)
              .toList(),
      };
      expect(fallbackIds, {
        'agnes-cn': ['agnes-2.0-flash', 'agnes-2.5-flash', 'agnes-3.0-flash'],
        'ainative': [
          'qwen3-235b-cerebras',
          'qwen3-32b',
          'qwen3-14b',
          'qwen3-8b',
          'llama-4-maverick',
          'llama3.1-8b-cerebras',
          'deepseek-r1',
          'nous-coder',
          'gemini-flash',
        ],
        'ainetcafe': <String>[],
        'aion': [
          'aion-labs/aion-3.0',
          'aion-labs/aion-3.0-mini',
          'aion-labs/aion-2.5',
          'aion-labs/aion-2.0',
          'aion-labs/aion-rp-llama-3.1-8b',
        ],
        'ant-ling': ['Ling-2.6-1T', 'Ring-2.6-1T', 'Ling-2.6-flash'],
        'anyapi': <String>[],
        'apmix': [
          'claude-haiku-4-5',
          'claude-sonnet-5',
          'claude-opus-5',
          'claude-opus-4-8',
          'claude-opus-4-7',
          'claude-opus-4-6',
          'claude-fable-5',
          'claude-sonnet-4-6',
          'gpt-5.6-terra',
          'gpt-5.6-sol',
          'gpt-5.6-luna',
          'gpt-5.5',
          'gpt-6-astra',
          'gpt-6-sol',
          'gpt-6-luna',
          'gpt-6-luna-free',
          'gemini-3.8-flash',
          'gemini-3.7-flash',
          'gemini-3.6-flash',
          'gemini-3.1-pro',
          'grok-4.5',
          'grok-4.6',
          'grok-4.7',
          'deepseek-v4-pro',
          'deepseek-v4-flash',
          'deepseek-v4.1-flash',
          'deepseek-v4-flash-free',
          'qwen3.8-flash',
          'qwen3.8-max',
          'glm-5.3-flash',
          'glm-5.3',
          'glm-5.2',
          'glm-5-turbo',
          'kimi-k2.7-code',
          'kimi-k3',
          'mimo-v2.5-pro',
          'mimo-v2.5',
          'hy4-preview',
          'composer-2.5-fast',
          'minimax-m3',
          'muse-spark-1.3',
        ],
        'auriko': <String>[],
        'baidu': [
          'ernie-5.1',
          'ernie-5.0',
          'ernie-x1.1',
          'ernie-4.5-turbo-128k',
          'ernie-4.5-turbo-32k',
          'ernie-4.5-turbo-vl',
          'ernie-4.5-21b-a3b',
          'ernie-4.5-0.3b',
          'ernie-4.0-8k',
          'ernie-4.0-turbo-128k',
          'ernie-4.0-turbo-8k',
          'ernie-3.5-8k',
          'ernie-speed-128k',
          'ernie-speed-8k',
          'ernie-lite-8k',
          'ernie-tiny-8k',
        ],
        'bazaarlink': [
          'auto:free',
          'claude-opus-4.7',
          'claude-sonnet-4.6',
          'claude-haiku-4.5',
          'gpt-5.5',
          'gpt-5.4',
          'gpt-5.4-mini',
          'gpt-5.4-nano',
          'grok-4.3',
          'grok-4.20',
          'gemini-3.1-pro-preview',
          'gemini-3-flash-preview',
          'gemini-3.1-flash-lite-preview',
          'gemma-4-31b-it',
          'gemma-4-26b-a4b-it',
          'deepseek-v3.2',
          'kimi-k2.6',
          'kimi-k2.5',
          'glm-5.1',
          'glm-5',
          'mimo-v2.5-pro',
          'mimo-v2.5',
          'minimax-m3',
          'minimax-m2.7',
          'minimax-m2.5',
          'llama-4-maverick',
          'llama-4-scout',
          'llama-3.3-70b-instruct',
          'qwen3.6-plus',
          'mistral-large-2512',
          'mistral-medium-3.1',
          'mistral-small-2603',
          'nemotron-3-super-120b-a12b',
        ],
        'beatapi': <String>[],
      });
      expect(
          findLlmOpenAiProviderPreset('agnes-cn')!
              .fallbackModels
              .first
              .capabilities,
          containsPair('reasoning', true));
      expect(
          findLlmOpenAiProviderPreset('ainative')!
              .fallbackModels
              .first
              .capabilities,
          containsPair('toolCalling', true));
      expect(
          findLlmOpenAiProviderPreset('baidu')!
              .fallbackModels
              .first
              .capabilities,
          containsPair('contextLength', 131072));
      expect(
          findLlmOpenAiProviderPreset('apmix')!.fallbackModels[39].capabilities,
          containsPair('vision', true));
      expect(
          findLlmOpenAiProviderPreset('bazaarlink')!
              .fallbackModels[22]
              .capabilities,
          containsPair('vision', true));
      expect(
        findLlmOpenAiProviderPreset('bluesminds')!
            .fallbackModels
            .firstWhere((model) => model.id == 'deepseek-reasoner')
            .capabilities,
        {'contextLength': 128000, 'reasoning': true},
      );
      expect(
        {
          for (final model
              in findLlmOpenAiProviderPreset('bluesminds')!.fallbackModels)
            model.id: model.displayName,
        },
        {
          'gpt-4o': 'GPT-4o',
          'gpt-4o-mini': 'GPT-4o Mini',
          'gpt-4.1': 'GPT-4.1',
          'gpt-4.1-mini': 'GPT-4.1 Mini',
          'gpt-4.1-nano': 'GPT-4.1 Nano',
          'claude-sonnet-4-5': 'Claude Sonnet 4.5',
          'claude-haiku-4-5': 'Claude Haiku 4.5',
          'gemini-2.0-flash': 'Gemini 2.0 Flash',
          'gemini-2.0-flash-exp': 'Gemini 2.0 Flash (Exp)',
          'deepseek-reasoner': 'DeepSeek Reasoner',
          'deepseek-chat': 'DeepSeek Chat',
          'qwen-plus': 'Qwen Plus',
          'qwen-turbo': 'Qwen Turbo',
          'kimi-k2': 'Kimi K2',
          'kimi-k2-thinking': 'Kimi K2 Thinking',
          'glm-4.7': 'GLM 4.7',
          'glm-4-flash': 'GLM 4 Flash',
          'minimax-m2.5': 'MiniMax M2.5',
          'claude-opus-4-5': 'Claude Opus 4.5 (VIP)',
          'gemini-2.5-pro': 'Gemini 2.5 Pro (VIP)',
          'grok-3': 'Grok-3 (VIP)',
          'qwen-max': 'Qwen Max (VIP)',
        },
      );
      expect(
        findLlmOpenAiProviderPreset('bluesminds')!
            .fallbackModels
            .firstWhere((model) => model.id == 'gemini-2.5-pro')
            .capabilities,
        {'contextLength': 1048576},
      );
      expect(
        {
          for (final id in [
            'bluesminds',
            'bytez',
            'charm-hyper',
            'chat-oripe',
            'chatanywhere',
            'cloudcode-one',
            'codestral',
            'cohere',
            'coze',
          ])
            id: findLlmOpenAiProviderPreset(id)!
                .fallbackModels
                .map((model) => model.id)
                .toList(),
        },
        {
          'bluesminds': [
            'gpt-4o',
            'gpt-4o-mini',
            'gpt-4.1',
            'gpt-4.1-mini',
            'gpt-4.1-nano',
            'claude-sonnet-4-5',
            'claude-haiku-4-5',
            'gemini-2.0-flash',
            'gemini-2.0-flash-exp',
            'deepseek-reasoner',
            'deepseek-chat',
            'qwen-plus',
            'qwen-turbo',
            'kimi-k2',
            'kimi-k2-thinking',
            'glm-4.7',
            'glm-4-flash',
            'minimax-m2.5',
            'claude-opus-4-5',
            'gemini-2.5-pro',
            'grok-3',
            'qwen-max',
          ],
          'bytez': [
            'meta-llama/Llama-3.3-70B-Instruct',
            'mistralai/Mistral-7B-Instruct-v0.3',
            'Qwen/Qwen2.5-72B-Instruct',
          ],
          'charm-hyper': ['hyper/auto'],
          'chat-oripe': <String>[],
          'chatanywhere': <String>[],
          'cloudcode-one': ['glm-4.7-flash', 'glm-4.6v-flash'],
          'codestral': ['codestral-2508', 'codestral-latest'],
          'cohere': [
            'command-a-reasoning-08-2025',
            'command-a-vision-07-2025',
            'command-a-03-2025',
            'command-r7b-12-2024',
            'command-r-plus-08-2024',
            'command-r-08-2024',
          ],
          'coze': ['claude-3-7-sonnet-20250514'],
        },
      );
      // Deferred: registry/blackbox/index.ts:4,6,7,14-18 documents 404s for
      // both audited URLs and an account-gated enterprise host;
      // registry/cloudflare-ai/index.ts:4,6,7,9-11,17
      // and executors/cloudflare-ai.ts:17-56 require an account ID in the URL
      // and a provider-specific executor.
      for (final id in [
        'blackbox',
        'cloudflare-ai',
      ]) {
        expect(findLlmOpenAiProviderPreset(id), isNull);
      }
      final bai = findLlmOpenAiProviderPreset('bai')!;
      expect(bai.baseUrl, 'https://api.b.ai/v1/chat/completions');
      expect(bai.modelsUrl, 'https://api.b.ai/v1/models');
      expect(bai.fallbackModels.map((model) => model.id), [
        'deepseek-reasoner',
      ]);
      // `baidu` is the single user-facing choice for the shared Qianfan chat URL.
      expect(findLlmOpenAiProviderPreset('qianfan'), isNull);
      // The eligible M38 registry entries use distinct chat URLs, so no aliases
      // in this cohort need to collapse to a single user-facing choice.
    },
  );

  test('each M37 eligible preset saves and reloads source defaults', () async {
    final preferences = _MemoryLlmAccountPreferences();
    final credentials = _MemoryLlmCredentials();
    final service = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: credentials,
    );
    const presetIds = [
      'agnes-cn',
      'ainative',
      'ainetcafe',
      'aion',
      'ant-ling',
      'anyapi',
      'apmix',
      'auriko',
      'baidu',
      'bazaarlink',
      'beatapi',
    ];
    for (final presetId in presetIds) {
      final preset = findLlmOpenAiProviderPreset(presetId)!;
      final fallback = preset.fallbackModels;
      final account = LlmAccount(
        id: 'm37-$presetId',
        connectorType: 'openai-compatibility',
        authType: preset.authType,
        displayName: preset.displayName,
        endpointConfig: preset.applyToEndpointConfig(const {
          'customHeader': 'preserved',
        }),
        models: [
          for (final model in fallback)
            LlmUpstreamModel(
              id: 'm37-$presetId:${model.id}',
              upstreamModelId: model.id,
              displayName: model.displayName,
              capabilities: model.capabilities,
              config: const {'apiProtocolOverride': 'anthropic.messages'},
            ),
          if (fallback.isEmpty)
            LlmUpstreamModel(
              id: 'm37-$presetId:user-model',
              upstreamModelId: 'user-model',
              displayName: 'User model',
              config: const {'apiProtocolOverride': 'anthropic.messages'},
            ),
        ],
      );
      await service.saveAccount(account, secret: 'key-$presetId');

      final restored = (await service.getAccount(account.id))!;
      expect(restored.connectorType, 'openai-compatibility');
      expect(restored.endpointConfig['providerPresetId'], presetId);
      expect(restored.endpointConfig['baseUrl'], preset.baseUrl);
      expect(restored.endpointConfig['modelsUrl'], preset.modelsUrl);
      expect(restored.endpointConfig['apiProtocol'], 'openai.chat_completions');
      expect(restored.endpointConfig['customHeader'], 'preserved');
      expect(await service.readCredential(account.id), 'key-$presetId');
      expect(
        restored.models.map((model) => model.upstreamModelId),
        fallback.isEmpty ? ['user-model'] : fallback.map((model) => model.id),
      );
      if (fallback.isNotEmpty) {
        expect(restored.models.first.capabilities, fallback.first.capabilities);
      }
      final model = restored.models.first;
      final group = LlmModelGroup(
        id: 'm37-$presetId-group',
        displayName: preset.displayName,
        members: [
          LlmModelGroupMember(
            accountId: restored.id,
            upstreamModelId: model.upstreamModelId,
          ),
        ],
      );
      final providerConfigs = buildLlmModelGroupProviderConfigs(
        accounts: [restored],
        groups: [group],
      );
      expect(providerConfigs, hasLength(1));
      expect(providerConfigs.single.apiProtocol, 'openai.chat_completions');
      expect(
        providerConfigs.single.models.single.apiProtocolOverride,
        'anthropic.messages',
      );
    }
  });

  test(
      'each M38 eligible preset saves, reloads, and routes through Chat and Task Flow',
      () async {
    final preferences = _MemoryLlmAccountPreferences();
    final credentials = _MemoryLlmCredentials();
    final service = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: credentials,
    );
    const presetIds = [
      'bluesminds',
      'bytez',
      'charm-hyper',
      'chat-oripe',
      'chatanywhere',
      'cloudcode-one',
      'codestral',
      'cohere',
      'coze',
    ];
    for (final presetId in presetIds) {
      final preset = findLlmOpenAiProviderPreset(presetId)!;
      final models = preset.fallbackModels;
      final account = LlmAccount(
        id: 'm38-$presetId',
        connectorType: 'openai-compatibility',
        authType: preset.authType,
        displayName: preset.displayName,
        endpointConfig: preset.applyToEndpointConfig(const {
          'customHeader': 'preserved',
        }),
        models: [
          for (final model in models)
            LlmUpstreamModel(
              id: 'm38-$presetId:${model.id}',
              upstreamModelId: model.id,
              displayName: model.displayName,
              capabilities: model.capabilities,
              config: const {'apiProtocolOverride': 'anthropic.messages'},
            ),
          if (models.isEmpty)
            LlmUpstreamModel(
              id: 'm38-$presetId:user-model',
              upstreamModelId: 'user-model',
              displayName: 'User model',
              config: const {'apiProtocolOverride': 'anthropic.messages'},
            ),
        ],
      );
      await service.saveAccount(account, secret: 'key-$presetId');

      final restored = (await service.getAccount(account.id))!;
      expect(restored.connectorType, 'openai-compatibility');
      expect(restored.endpointConfig['providerPresetId'], presetId);
      expect(restored.endpointConfig['baseUrl'], preset.baseUrl);
      expect(restored.endpointConfig['modelsUrl'], preset.modelsUrl);
      expect(restored.endpointConfig['apiProtocol'], 'openai.chat_completions');
      expect(restored.endpointConfig['customHeader'], 'preserved');
      expect(await service.readCredential(account.id), 'key-$presetId');
      expect(
        restored.models.map((model) => model.upstreamModelId),
        models.isEmpty ? ['user-model'] : models.map((model) => model.id),
      );
      expect(
        restored.models.first.config['apiProtocolOverride'],
        'anthropic.messages',
      );

      final group = LlmModelGroup(
        id: 'm38-$presetId-group',
        displayName: preset.displayName,
        members: [
          LlmModelGroupMember(
            accountId: restored.id,
            upstreamModelId: restored.models.first.upstreamModelId,
          ),
        ],
      );
      final providerConfigs = buildLlmModelGroupProviderConfigs(
        accounts: [restored],
        groups: [group],
      );
      expect(providerConfigs, hasLength(1));
      expect(providerConfigs.single.apiProtocol, 'openai.chat_completions');
      expect(
        providerConfigs.single.models.single.apiProtocolOverride,
        'anthropic.messages',
      );
    }
  });

  test(
    'preset identity and defaults survive account save and reload',
    () async {
      final preset = findLlmOpenAiProviderPreset('fireworks')!;
      final preferences = _MemoryLlmAccountPreferences();
      final credentials = _MemoryLlmCredentials();
      final service = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: credentials,
      );
      final original = LlmAccount(
        id: 'fireworks-account',
        connectorType: 'openai-compatibility',
        authType: preset.authType,
        displayName: preset.displayName,
        endpointConfig: preset.applyToEndpointConfig({
          'customHeader': 'kept',
          'apiProtocol': preset.defaultApiProtocol,
        }),
        models: [
          for (final model in preset.fallbackModels)
            LlmUpstreamModel(
              id: 'fireworks-account:${preset.modelIdPrefix}${model.id}',
              upstreamModelId: '${preset.modelIdPrefix}${model.id}',
              displayName: model.displayName,
              capabilities: model.capabilities,
            ),
        ],
      );
      await service.saveAccount(original, secret: 'example-api-key');
      final restored = (await service.getAccount(original.id))!;

      expect(restored.connectorType, 'openai-compatibility');
      expect(restored.authType, 'api_key');
      expect(await service.readCredential(restored.id), 'example-api-key');
      expect(restored.endpointConfig['providerPresetId'], 'fireworks');
      expect(restored.endpointConfig['baseUrl'], preset.baseUrl);
      expect(restored.endpointConfig['modelsUrl'], preset.modelsUrl);
      expect(restored.endpointConfig['apiProtocol'], 'openai.chat_completions');
      expect(restored.endpointConfig['customHeader'], 'kept');
      expect(
        restored.models.map((model) => model.upstreamModelId),
        contains('accounts/fireworks/models/deepseek-v4-flash'),
      );
    },
  );

  test('each M35 preset saves and reloads its own endpoint and model',
      () async {
    final preferences = _MemoryLlmAccountPreferences();
    final credentials = _MemoryLlmCredentials();
    final service = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: credentials,
    );
    const m35PresetIds = [
      'alibaba',
      'alibaba-cn',
      'baichuan',
      'bigmodel',
      'byteplus',
      'chutes',
      'deepinfra',
      'doubao',
      'iflytek',
      'internlm',
      'siliconflow',
      'yi',
    ];

    for (final presetId in m35PresetIds) {
      final preset = findLlmOpenAiProviderPreset(presetId)!;
      final model = preset.fallbackModels.first;
      final account = LlmAccount(
        id: 'm35-$presetId',
        connectorType: 'openai-compatibility',
        authType: preset.authType,
        displayName: preset.displayName,
        endpointConfig: preset.applyToEndpointConfig(const {}),
        models: [
          LlmUpstreamModel(
            id: 'm35-$presetId-model',
            upstreamModelId: '${preset.modelIdPrefix}${model.id}',
            displayName: model.displayName,
            capabilities: model.capabilities,
          ),
        ],
      );
      await service.saveAccount(account, secret: 'key-$presetId');

      final restored = (await service.getAccount(account.id))!;
      expect(restored.endpointConfig['providerPresetId'], presetId);
      expect(restored.endpointConfig['baseUrl'], preset.baseUrl);
      expect(restored.endpointConfig['modelsUrl'], preset.modelsUrl);
      expect(restored.endpointConfig['apiProtocol'], 'openai.chat_completions');
      expect(restored.models.single.upstreamModelId, model.id);
      expect(restored.models.single.displayName, model.displayName);
      expect(restored.models.single.capabilities, model.capabilities);
      expect(await service.readCredential(account.id), 'key-$presetId');
    }
  });

  test('preset model discovery uses its source URL and bearer API key',
      () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..httpClientAdapter = _FunctionalAdapter((options) async {
        requests.add(options);
        return ResponseBody.fromString(
          jsonEncode({
            'data': [
              {'id': 'accounts/fireworks/models/test-model'},
            ],
          }),
          200,
          headers: const {
            Headers.contentTypeHeader: ['application/json']
          },
        );
      });
    final preferences = _MemoryLlmAccountPreferences();
    final credentials = _MemoryLlmCredentials();
    final service = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: credentials,
      dio: dio,
    );
    final preset = findLlmOpenAiProviderPreset('fireworks')!;
    final account = await service.saveAccount(
      LlmAccount(
        id: 'fireworks-discovery',
        connectorType: 'openai-compatibility',
        authType: 'api_key',
        displayName: preset.displayName,
        endpointConfig: preset.applyToEndpointConfig(const {}),
      ),
      secret: 'example-api-key',
    );

    final models = await service.discoverModels(account, refreshRemote: true);

    expect(requests, hasLength(1));
    expect(requests.single.uri.toString(), preset.modelsUrl);
    expect(requests.single.headers['Authorization'], 'Bearer example-api-key');
    expect(
        models.single.upstreamModelId, 'accounts/fireworks/models/test-model');
  });

  test('M41 discoverable presets refresh from their pinned URL with key auth',
      () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..httpClientAdapter = _FunctionalAdapter((options) async {
        requests.add(options);
        final providerId = [
          'kenari',
          'kilo-gateway',
          'liquid',
          'literouter',
          'llm-kiwi',
          'llm7',
          'llmgateway',
        ][requests.length - 1];
        return ResponseBody.fromString(
          jsonEncode({
            'data': [
              {'id': '$providerId-model'},
            ],
          }),
          200,
          headers: const {
            Headers.contentTypeHeader: ['application/json']
          },
        );
      });
    final service = LlmAccountConnectorService(
      preferences: _MemoryLlmAccountPreferences(),
      credentialStore: _MemoryLlmCredentials(),
      dio: dio,
    );
    const presetIds = [
      'kenari',
      'kilo-gateway',
      'liquid',
      'literouter',
      'llm-kiwi',
      'llm7',
      'llmgateway',
    ];
    for (final presetId in presetIds) {
      final preset = findLlmOpenAiProviderPreset(presetId)!;
      final account = await service.saveAccount(
        LlmAccount(
          id: 'm41-$presetId-discovery',
          connectorType: 'openai-compatibility',
          authType: preset.authType,
          displayName: preset.displayName,
          endpointConfig: preset.applyToEndpointConfig(const {}),
        ),
        secret: 'key-$presetId',
      );

      final models = await service.discoverModels(account, refreshRemote: true);

      expect(requests.last.uri.toString(), preset.modelsUrl, reason: presetId);
      expect(requests.last.headers['Authorization'], 'Bearer key-$presetId');
      expect(models.single.upstreamModelId, '$presetId-model');
    }
    expect(requests, hasLength(presetIds.length));
  });

  test(
    'model protocol override remains independent of preset supplier default',
    () {
      final account = LlmAccount(
        id: 'mistral-account',
        connectorType: 'openai-compatibility',
        authType: 'api_key',
        displayName: 'Mistral',
        endpointConfig: const {
          'providerPresetId': 'mistral',
          'baseUrl': 'https://api.mistral.ai/v1/chat/completions',
          'apiProtocol': 'openai.chat_completions',
        },
        models: const [
          LlmUpstreamModel(
            id: 'mistral-account:anthropic-model',
            upstreamModelId: 'anthropic-model',
            displayName: 'Anthropic compatible model',
            config: {'apiProtocolOverride': 'anthropic.messages'},
          ),
        ],
      );
      final gatewayAccount = AiGatewayAccount(
        id: account.id,
        connectorType: account.connectorType,
        authType: account.authType,
        displayName: account.displayName,
        endpointConfig: account.endpointConfig,
        models: [
          for (final model in account.models)
            AiGatewayUpstreamModel(
              id: model.id,
              upstreamModelId: model.upstreamModelId,
              displayName: model.displayName,
              capabilities: model.capabilities,
              config: model.config,
            ),
        ],
      );

      expect(
        llmRoutedChatProtocolForAccountModel(
          account: gatewayAccount,
          upstreamModelId: 'anthropic-model',
          endpointType: 'openai',
        ),
        'anthropic.messages',
      );
      expect(account.endpointConfig['apiProtocol'], 'openai.chat_completions');
    },
  );

  test(
      'preset models are exposed through the shared Chat and Task Flow model config',
      () {
    final preset = findLlmOpenAiProviderPreset('groq')!;
    final account = LlmAccount(
      id: 'groq-account',
      connectorType: 'openai-compatibility',
      authType: 'api_key',
      displayName: preset.displayName,
      endpointConfig: preset.applyToEndpointConfig(const {
        'apiProtocol': 'openai.chat_completions',
      }),
      models: [
        for (final model in preset.fallbackModels)
          LlmUpstreamModel(
            id: 'groq-account:${model.id}',
            upstreamModelId: model.id,
            displayName: model.displayName,
            capabilities: model.capabilities,
          ),
      ],
    );
    final group = LlmModelGroup(
      id: 'groq-group',
      displayName: 'Groq',
      members: [
        LlmModelGroupMember(
          accountId: account.id,
          upstreamModelId: account.models.first.upstreamModelId,
        ),
      ],
    );

    final configs = buildLlmModelGroupProviderConfigs(
      accounts: [account],
      groups: [group],
    );

    expect(configs, hasLength(1));
    expect(configs.single.apiProtocol, 'openai.chat_completions');
    expect(configs.single.models, hasLength(1));
    expect(
      llmRoutedChatSupportedConnectorTypes('openai.chat_completions'),
      contains('openai-compatibility'),
    );
    expect(
      llmRoutedChatSupportedConnectorTypesForModelOverride(
        'openai.chat_completions',
      ),
      contains('openai-compatibility'),
    );
    expect(
      AiGateway.defaultProviderCatalog.findProvider('openai-compatibility'),
      isNotNull,
    );
  });

  test('each M40 preset persists and routes through Chat and Task Flow',
      () async {
    final preferences = _MemoryLlmAccountPreferences();
    final credentials = _MemoryLlmCredentials();
    final service = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: credentials,
    );
    const presetIds = [
      'freeaiapikey',
      'freeinference',
      'freemodel-dev',
      'freetheai',
      'friendliai',
      'galadriel',
      'greenpt',
      'hcnsec',
      'helixmind',
      'helyxai',
      'heroku',
      'hyperbolic',
    ];
    for (final presetId in presetIds) {
      final preset = findLlmOpenAiProviderPreset(presetId)!;
      final model = preset.fallbackModels.isEmpty
          ? LlmUpstreamModel(
              id: 'm40-$presetId:user-model',
              upstreamModelId: 'user-model',
              displayName: 'User model',
              config: const {'apiProtocolOverride': 'anthropic.messages'},
            )
          : LlmUpstreamModel(
              id: 'm40-$presetId:${preset.fallbackModels.first.id}',
              upstreamModelId: preset.fallbackModels.first.id,
              displayName: preset.fallbackModels.first.displayName,
              capabilities: preset.fallbackModels.first.capabilities,
              config: const {'apiProtocolOverride': 'anthropic.messages'},
            );
      final account = LlmAccount(
        id: 'm40-$presetId',
        connectorType: 'openai-compatibility',
        authType: preset.authType,
        displayName: preset.displayName,
        endpointConfig: preset.applyToEndpointConfig(const {
          'customEndpointFlag': 'preserved',
        }),
        models: [model],
      );
      await service.saveAccount(account, secret: 'key-$presetId');

      final restored = (await service.getAccount(account.id))!;
      expect(restored.connectorType, 'openai-compatibility');
      expect(restored.endpointConfig['providerPresetId'], presetId);
      expect(restored.endpointConfig['baseUrl'], preset.baseUrl);
      if (preset.modelsUrl == null) {
        expect(restored.endpointConfig.containsKey('modelsUrl'), isFalse);
      } else {
        expect(restored.endpointConfig['modelsUrl'], preset.modelsUrl);
      }
      expect(restored.endpointConfig['apiProtocol'], 'openai.chat_completions');
      expect(restored.endpointConfig['customEndpointFlag'], 'preserved');
      expect(await service.readCredential(account.id), 'key-$presetId');
      expect(restored.models.single.upstreamModelId, model.upstreamModelId);
      expect(restored.models.single.capabilities, model.capabilities);
      final group = LlmModelGroup(
        id: 'm40-$presetId-group',
        displayName: preset.displayName,
        members: [
          LlmModelGroupMember(
            accountId: restored.id,
            upstreamModelId: restored.models.single.upstreamModelId,
          ),
        ],
      );
      final configs = buildLlmModelGroupProviderConfigs(
        accounts: [restored],
        groups: [group],
      );
      expect(configs, hasLength(1));
      expect(configs.single.apiProtocol, 'openai.chat_completions');
      expect(configs.single.models.single.apiProtocolOverride,
          'anthropic.messages');
    }
  });

  test('each M41 preset persists and routes through Chat and Task Flow',
      () async {
    final preferences = _MemoryLlmAccountPreferences();
    final credentials = _MemoryLlmCredentials();
    final service = LlmAccountConnectorService(
      preferences: preferences,
      credentialStore: credentials,
    );
    const presetIds = [
      'inception',
      'inference-net',
      'kenari',
      'kilo-gateway',
      'lambda-ai',
      'liquid',
      'literouter',
      'llamagate',
      'llm-kiwi',
      'llm7',
      'llmgateway',
    ];
    for (final presetId in presetIds) {
      final preset = findLlmOpenAiProviderPreset(presetId)!;
      final fallbackModel = preset.fallbackModels.firstOrNull;
      final model = LlmUpstreamModel(
        id: 'm41-$presetId:${fallbackModel?.id ?? 'user-model'}',
        upstreamModelId: fallbackModel?.id ?? 'user-model',
        displayName: fallbackModel?.displayName ?? 'User model',
        capabilities: fallbackModel?.capabilities ?? const {},
        config: const {'apiProtocolOverride': 'anthropic.messages'},
      );
      final account = LlmAccount(
        id: 'm41-$presetId',
        connectorType: 'openai-compatibility',
        authType: preset.authType,
        displayName: preset.displayName,
        endpointConfig: preset.applyToEndpointConfig({
          'accountOwnedConfig': 'preserved',
        }),
        models: [model],
      );
      await service.saveAccount(account, secret: 'key-$presetId');

      final restored = (await service.getAccount(account.id))!;
      expect(restored.connectorType, 'openai-compatibility', reason: presetId);
      expect(restored.endpointConfig['providerPresetId'], presetId);
      expect(restored.endpointConfig['baseUrl'], preset.baseUrl);
      expect(restored.endpointConfig['modelsUrl'], preset.modelsUrl);
      expect(restored.endpointConfig['apiProtocol'], 'openai.chat_completions');
      expect(restored.endpointConfig['accountOwnedConfig'], 'preserved');
      expect(await service.readCredential(account.id), 'key-$presetId');
      expect(restored.models.single.upstreamModelId, model.upstreamModelId);
      expect(
        restored.models.single.config['apiProtocolOverride'],
        'anthropic.messages',
      );

      final group = LlmModelGroup(
        id: 'm41-$presetId-group',
        displayName: preset.displayName,
        members: [
          LlmModelGroupMember(
            accountId: restored.id,
            upstreamModelId: restored.models.single.upstreamModelId,
          ),
        ],
      );
      final configs = buildLlmModelGroupProviderConfigs(
        accounts: [restored],
        groups: [group],
      );
      expect(configs, hasLength(1));
      expect(configs.single.apiProtocol, 'openai.chat_completions');
      expect(configs.single.models.single.apiProtocolOverride,
          'anthropic.messages');
    }
  });

  test(
    'each M43 preset persists and routes through Chat and Task Flow',
    () async {
      final service = LlmAccountConnectorService(
        preferences: _MemoryLlmAccountPreferences(),
        credentialStore: _MemoryLlmCredentials(),
      );
      const presetIds = [
        'naga-ai',
        'nan',
        'nanogpt',
        'nara',
        'nebius',
        'nous-research',
        'nscale',
        'nube',
        'oci',
        'ofoxai',
        'ollama-cloud',
      ];
      for (final presetId in presetIds) {
        final preset = findLlmOpenAiProviderPreset(presetId)!;
        final model = preset.fallbackModels.isEmpty
            ? LlmUpstreamModel(
                id: 'm43-$presetId:user-model',
                upstreamModelId: 'user-model',
                displayName: 'User model',
                config: const {'apiProtocolOverride': 'anthropic.messages'},
              )
            : LlmUpstreamModel(
                id: 'm43-$presetId:${preset.fallbackModels.first.id}',
                upstreamModelId: preset.fallbackModels.first.id,
                displayName: preset.fallbackModels.first.displayName,
                capabilities: preset.fallbackModels.first.capabilities,
                config: const {'apiProtocolOverride': 'anthropic.messages'},
              );
        final account = LlmAccount(
          id: 'm43-$presetId',
          connectorType: 'openai-compatibility',
          authType: preset.authType,
          displayName: preset.displayName,
          endpointConfig: preset.applyToEndpointConfig(const {
            'accountOwnedConfig': 'preserved',
          }),
          models: [model],
        );
        await service.saveAccount(account, secret: 'key-$presetId');

        final restored = (await service.getAccount(account.id))!;
        expect(
          restored.connectorType,
          'openai-compatibility',
          reason: presetId,
        );
        expect(restored.endpointConfig['providerPresetId'], presetId);
        expect(restored.endpointConfig['baseUrl'], preset.baseUrl);
        if (preset.modelsUrl == null) {
          expect(restored.endpointConfig.containsKey('modelsUrl'), isFalse);
        } else {
          expect(restored.endpointConfig['modelsUrl'], preset.modelsUrl);
        }
        expect(
          restored.endpointConfig['apiProtocol'],
          'openai.chat_completions',
        );
        expect(restored.endpointConfig['accountOwnedConfig'], 'preserved');
        expect(await service.readCredential(account.id), 'key-$presetId');
        expect(restored.models.single.upstreamModelId, model.upstreamModelId);
        expect(restored.models.single.capabilities, model.capabilities);
        expect(
          restored.models.single.config['apiProtocolOverride'],
          'anthropic.messages',
        );

        final group = LlmModelGroup(
          id: 'm43-$presetId-group',
          displayName: preset.displayName,
          members: [
            LlmModelGroupMember(
              accountId: restored.id,
              upstreamModelId: restored.models.single.upstreamModelId,
            ),
          ],
        );
        final configs = buildLlmModelGroupProviderConfigs(
          accounts: [restored],
          groups: [group],
        );
        expect(configs, hasLength(1));
        expect(configs.single.apiProtocol, 'openai.chat_completions');
        expect(
          configs.single.models.single.apiProtocolOverride,
          'anthropic.messages',
        );
      }
    },
  );

  test('M43 discovery URLs refresh with bearer keys', () async {
    const presetIds = [
      'naga-ai',
      'nan',
      'nanogpt',
      'nube',
      'oci',
      'ofoxai',
      'ollama-cloud',
    ];
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..httpClientAdapter = _FunctionalAdapter((options) async {
        requests.add(options);
        final id = presetIds[requests.length - 1];
        final payload = id == 'ollama-cloud'
            ? {
                'models': [
                  {'name': 'qwen-test'},
                ],
              }
            : {
                'data': [
                  {'id': '$id-model'},
                ],
              };
        return ResponseBody.fromString(
          jsonEncode(payload),
          200,
          headers: const {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
    final service = LlmAccountConnectorService(
      preferences: _MemoryLlmAccountPreferences(),
      credentialStore: _MemoryLlmCredentials(),
      dio: dio,
    );
    for (final presetId in presetIds) {
      final preset = findLlmOpenAiProviderPreset(presetId)!;
      final account = await service.saveAccount(
        LlmAccount(
          id: 'm43-$presetId-discovery',
          connectorType: 'openai-compatibility',
          authType: preset.authType,
          displayName: preset.displayName,
          endpointConfig: preset.applyToEndpointConfig(const {}),
        ),
        secret: 'key-$presetId',
      );
      final models = await service.discoverModels(account, refreshRemote: true);

      expect(requests.last.uri.toString(), preset.modelsUrl, reason: presetId);
      expect(requests.last.headers['Authorization'], 'Bearer key-$presetId');
      expect(
        models.single.upstreamModelId,
        presetId == 'ollama-cloud' ? 'qwen-test' : '$presetId-model',
      );
    }
  });

  test('M39 presets use the shared Chat and Task Flow route', () {
    final preset = findLlmOpenAiProviderPreset('daoxe')!;
    final account = LlmAccount(
      id: 'daoxe-account',
      connectorType: 'openai-compatibility',
      authType: preset.authType,
      displayName: preset.displayName,
      endpointConfig: preset.applyToEndpointConfig(const {}),
      models: [
        for (final model in preset.fallbackModels)
          LlmUpstreamModel(
            id: 'daoxe-account:${model.id}',
            upstreamModelId: model.id,
            displayName: model.displayName,
            capabilities: model.capabilities,
          ),
      ],
    );
    final group = LlmModelGroup(
      id: 'daoxe-group',
      displayName: 'DaoXE',
      members: [
        LlmModelGroupMember(
          accountId: account.id,
          upstreamModelId: account.models.first.upstreamModelId,
        ),
      ],
    );

    final configs = buildLlmModelGroupProviderConfigs(
      accounts: [account],
      groups: [group],
    );

    expect(configs, hasLength(1));
    expect(configs.single.apiProtocol, 'openai.chat_completions');
    expect(configs.single.models, hasLength(1));
    expect(
      llmRoutedChatSupportedConnectorTypes('openai.chat_completions'),
      contains('openai-compatibility'),
    );
    expect(
      AiGateway.defaultProviderCatalog.findProvider('openai-compatibility'),
      isNotNull,
    );
  });

  test(
    'StepFun regional presets save, reload, and stay Chat and Task Flow eligible',
    () async {
      final preferences = _MemoryLlmAccountPreferences();
      final credentials = _MemoryLlmCredentials();
      final service = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: credentials,
      );

      for (final presetId in ['stepfun-cn', 'stepfun-international']) {
        final preset = findLlmOpenAiProviderPreset(presetId)!;
        final model = preset.fallbackModels.first;
        final account = LlmAccount(
          id: 'stepfun-$presetId-account',
          connectorType: 'openai-compatibility',
          authType: preset.authType,
          displayName: preset.displayName,
          endpointConfig: preset.applyToEndpointConfig(const {}),
          models: [
            LlmUpstreamModel(
              id: 'stepfun-$presetId-model',
              upstreamModelId: model.id,
              displayName: model.displayName,
              capabilities: model.capabilities,
              config: const {'apiProtocolOverride': 'anthropic.messages'},
            ),
          ],
        );
        await service.saveAccount(account, secret: 'key-$presetId');

        final restored = (await service.getAccount(account.id))!;
        expect(restored.connectorType, 'openai-compatibility');
        expect(restored.endpointConfig['providerPresetId'], presetId);
        expect(restored.endpointConfig['baseUrl'], preset.baseUrl);
        expect(restored.endpointConfig['modelsUrl'], preset.modelsUrl);
        expect(
            restored.endpointConfig['apiProtocol'], 'openai.chat_completions');
        expect(
          restored.models.single.config['apiProtocolOverride'],
          'anthropic.messages',
        );
        expect(await service.readCredential(account.id), 'key-$presetId');

        final group = LlmModelGroup(
          id: 'stepfun-$presetId-group',
          displayName: preset.displayName,
          members: [
            LlmModelGroupMember(
              accountId: restored.id,
              upstreamModelId: restored.models.single.upstreamModelId,
            ),
          ],
        );
        final configs = buildLlmModelGroupProviderConfigs(
          accounts: [restored],
          groups: [group],
        );
        expect(configs, hasLength(1));
        expect(configs.single.apiProtocol, 'openai.chat_completions');
        expect(
          configs.single.models.single.apiProtocolOverride,
          'anthropic.messages',
        );
      }
    },
  );

  test('M46 API-key presets retain pinned registry metadata', () {
    const endpoints = {
      'sealion': 'https://api.sea-lion.ai/v1/chat/completions',
      'seekai': 'https://seekai.cc/v1/chat/completions',
      'sensenova': 'https://token.sensenova.cn/v1/chat/completions',
      'sparkdesk': 'https://spark-api-open.xf-yun.com/v1/chat/completions',
      'speka': 'https://speka.me/v1/chat/completions',
      'synthetic': 'https://api.synthetic.new/openai/v1/chat/completions',
      'tokenmarket': 'https://api.tokensmarket.ai/v1/chat/completions',
      'tokenreply': 'https://api.tokenreply.com/v1/chat/completions',
    };
    for (final entry in endpoints.entries) {
      final preset = findLlmOpenAiProviderPreset(entry.key)!;
      expect(preset.baseUrl, entry.value, reason: entry.key);
      expect(preset.authType, 'api_key', reason: entry.key);
      expect(preset.authorizationHeader, 'Authorization', reason: entry.key);
      expect(preset.authorizationScheme, 'Bearer', reason: entry.key);
      expect(preset.defaultApiProtocol, 'openai.chat_completions');
    }
    expect(
      {
        for (final id in [
          'seekai',
          'speka',
          'synthetic',
          'tokenmarket',
          'tokenreply',
        ])
          id: findLlmOpenAiProviderPreset(id)!.modelsUrl,
      },
      {
        'seekai': 'https://seekai.cc/v1/models',
        'speka': 'https://speka.me/v1/models',
        'synthetic': 'https://api.synthetic.new/openai/v1/models',
        'tokenmarket': 'https://api.tokensmarket.ai/v1/models',
        'tokenreply': 'https://api.tokenreply.com/v1/models',
      },
    );
    expect(
      findLlmOpenAiProviderPreset('sealion')!.fallbackModels.map((m) => m.id),
      [
        'aisingapore/Llama-SEA-LION-v3.5-70B-R',
        'aisingapore/Llama-SEA-LION-v3-70B-IT',
        'aisingapore/Gemma-SEA-LION-v4-27B-IT',
        'aisingapore/Qwen-SEA-LION-v4.5-27B-IT',
        'aisingapore/Qwen-SEA-LION-v4-32B-IT',
      ],
    );
    expect(
      findLlmOpenAiProviderPreset('sensenova')!.fallbackModels.map((m) => m.id),
      ['sensenova-6.7-flash-lite', 'deepseek-v4-flash', 'glm-5.2'],
    );
    expect(
      findLlmOpenAiProviderPreset('sensenova')!.fallbackModels[1].capabilities,
      {
        'contextLength': 1048576,
        'maxOutputTokens': 65536,
        'reasoning': true,
        'supportedThinkingEfforts': ['none', 'low', 'medium', 'high'],
        'supportsXHighEffort': false,
        'interleavedField': 'reasoning_content',
      },
    );
    expect(
      findLlmOpenAiProviderPreset('sparkdesk')!.fallbackModels.map((m) => m.id),
      ['4.0Ultra', 'generalv3', 'pro-128k', 'lite'],
    );
    expect(
      findLlmOpenAiProviderPreset('synthetic')!.fallbackModels.map((m) => m.id),
      [
        'hf:openai/gpt-oss-120b',
        'hf:zai-org/GLM-5.2',
        'hf:moonshotai/Kimi-K2.7-Code',
        'hf:Qwen/Qwen3.6-27B',
        'hf:MiniMaxAI/MiniMax-M3',
        'hf:zai-org/GLM-4.7-Flash',
        'hf:nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4',
      ],
    );
    expect(
      findLlmOpenAiProviderPreset('synthetic')!.fallbackModels[2].capabilities,
      {
        'contextLength': 262144,
        'maxOutputTokens': 65536,
        'toolCalling': true,
        'reasoning': true,
        'vision': true,
      },
    );
    expect(findLlmOpenAiProviderPreset('tokenmarket')!.fallbackModels, isEmpty);
    expect(findLlmOpenAiProviderPreset('tokenreply')!.fallbackModels, isEmpty);

    // These M46 rows are deferred because their pinned runtime has no matching
    // executable adapter or has provider-wide metadata the preset contract
    // cannot retain on discovered models.
    for (final id in [
      'sumopod',
      'tencent',
      'thebai',
      'token-kiosk',
      'tokenrouter',
    ]) {
      expect(findLlmOpenAiProviderPreset(id), isNull, reason: id);
    }
  });

  test(
    'each M46 preset persists and routes through Chat and Task Flow',
    () async {
      final service = LlmAccountConnectorService(
        preferences: _MemoryLlmAccountPreferences(),
        credentialStore: _MemoryLlmCredentials(),
      );
      const presetIds = [
        'sealion',
        'seekai',
        'sensenova',
        'sparkdesk',
        'speka',
        'synthetic',
        'tokenmarket',
        'tokenreply',
      ];
      for (final presetId in presetIds) {
        final preset = findLlmOpenAiProviderPreset(presetId)!;
        final fallback = preset.fallbackModels.firstOrNull;
        final model = LlmUpstreamModel(
          id: 'm46-$presetId:${fallback?.id ?? 'user-model'}',
          upstreamModelId: fallback?.id ?? 'user-model',
          displayName: fallback?.displayName ?? 'User model',
          capabilities: fallback?.capabilities ?? const {},
          config: const {'apiProtocolOverride': 'anthropic.messages'},
        );
        final account = LlmAccount(
          id: 'm46-$presetId',
          connectorType: 'openai-compatibility',
          authType: preset.authType,
          displayName: preset.displayName,
          endpointConfig: preset.applyToEndpointConfig(const {
            'accountOwnedConfig': 'preserved',
          }),
          models: [model],
        );
        await service.saveAccount(account, secret: 'key-$presetId');
        final restored = (await service.getAccount(account.id))!;
        expect(
          restored.connectorType,
          'openai-compatibility',
          reason: presetId,
        );
        expect(restored.endpointConfig['providerPresetId'], presetId);
        expect(restored.endpointConfig['baseUrl'], preset.baseUrl);
        expect(restored.endpointConfig['modelsUrl'], preset.modelsUrl);
        expect(
          restored.endpointConfig['apiProtocol'],
          'openai.chat_completions',
        );
        expect(restored.endpointConfig['accountOwnedConfig'], 'preserved');
        expect(await service.readCredential(account.id), 'key-$presetId');
        expect(restored.models.single.upstreamModelId, model.upstreamModelId);
        expect(restored.models.single.capabilities, model.capabilities);
        expect(
          restored.models.single.config['apiProtocolOverride'],
          'anthropic.messages',
        );

        final group = LlmModelGroup(
          id: 'm46-$presetId-group',
          displayName: preset.displayName,
          members: [
            LlmModelGroupMember(
              accountId: restored.id,
              upstreamModelId: restored.models.single.upstreamModelId,
            ),
          ],
        );
        final configs = buildLlmModelGroupProviderConfigs(
          accounts: [restored],
          groups: [group],
        );
        expect(configs, hasLength(1));
        expect(configs.single.apiProtocol, 'openai.chat_completions');
        expect(
          configs.single.models.single.apiProtocolOverride,
          'anthropic.messages',
        );
        expect(
          llmRoutedChatSupportedConnectorTypes('openai.chat_completions'),
          contains('openai-compatibility'),
        );
      }
    },
  );

  test('M46 discovery presets refresh model lists using bearer auth', () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..httpClientAdapter = _FunctionalAdapter((options) async {
        requests.add(options);
        return ResponseBody.fromString(
          jsonEncode({
            'data': [
              {'id': 'discovered-${requests.length}'},
            ],
          }),
          200,
          headers: const {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
    final service = LlmAccountConnectorService(
      preferences: _MemoryLlmAccountPreferences(),
      credentialStore: _MemoryLlmCredentials(),
      dio: dio,
    );
    const presetIds = [
      'seekai',
      'speka',
      'synthetic',
      'tokenmarket',
      'tokenreply',
    ];
    for (final presetId in presetIds) {
      final preset = findLlmOpenAiProviderPreset(presetId)!;
      final account = await service.saveAccount(
        LlmAccount(
          id: 'm46-$presetId-discovery',
          connectorType: 'openai-compatibility',
          authType: preset.authType,
          displayName: preset.displayName,
          endpointConfig: preset.applyToEndpointConfig(const {}),
        ),
        secret: 'key-$presetId',
      );
      final models = await service.discoverModels(account, refreshRemote: true);
      expect(requests.last.uri.toString(), preset.modelsUrl, reason: presetId);
      expect(requests.last.headers['Authorization'], 'Bearer key-$presetId');
      expect(models.single.upstreamModelId, 'discovered-${requests.length}');
    }
  });

  test('M47 eligible presets retain pinned chat endpoints and catalogs', () {
    const endpoints = {
      'typhoon': 'https://api.opentyphoon.ai/v1/chat/completions',
      'unifically': 'https://api.unifically.com/v1/chat/completions',
      'unorouter': 'https://api.unorouter.com/v1/chat/completions',
      'upstage': 'https://api.upstage.ai/v1/chat/completions',
      'v0-vercel': 'https://api.v0.dev/v1/chat/completions',
      'venice': 'https://api.venice.ai/api/v1/chat/completions',
      'vercel-ai-gateway': 'https://ai-gateway.vercel.sh/v1/chat/completions',
      'void-ai': 'https://api.voidai.app/v1/chat/completions',
      'volcengine': 'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
      'volcengine-agent-plan':
          'https://ark.cn-beijing.volces.com/api/plan/v3/chat/completions',
      'volcengine-coding-plan':
          'https://ark.cn-beijing.volces.com/api/coding/v3/chat/completions',
      'wandb': 'https://api.inference.wandb.ai/v1/chat/completions',
    };
    for (final entry in endpoints.entries) {
      final preset = findLlmOpenAiProviderPreset(entry.key)!;
      expect(preset.baseUrl, entry.value, reason: entry.key);
      expect(preset.authType, 'api_key', reason: entry.key);
      expect(preset.authorizationHeader, 'Authorization', reason: entry.key);
      expect(preset.authorizationScheme, 'Bearer', reason: entry.key);
      expect(preset.defaultApiProtocol, 'openai.chat_completions');
    }
    expect({
      for (final id in [
        'unifically',
        'unorouter',
        'void-ai',
        'volcengine-coding-plan',
      ])
        id: findLlmOpenAiProviderPreset(id)!.modelsUrl,
    }, {
      'unifically': 'https://api.unifically.com/v1/models?category=llm',
      'unorouter': 'https://api.unorouter.com/v1/models',
      'void-ai': 'https://api.voidai.app/v1/models',
      'volcengine-coding-plan':
          'https://ark.cn-beijing.volces.com/api/coding/v3/models',
    });
    expect(findLlmOpenAiProviderPreset('typhoon')!.fallbackModels.single.id,
        'typhoon-v2.5-30b-a3b-instruct');
    expect(
      findLlmOpenAiProviderPreset('typhoon')!
          .fallbackModels
          .single
          .capabilities,
      {'contextLength': 131072},
    );
    expect(
      findLlmOpenAiProviderPreset('upstage')!.fallbackModels.map((m) => m.id),
      ['solar-pro3', 'solar-mini'],
    );
    expect(
      findLlmOpenAiProviderPreset('v0-vercel')!.fallbackModels.map((m) => m.id),
      ['v0-1.0-md', 'v0-1.5-lg', 'v0-1.5-md'],
    );
    expect(findLlmOpenAiProviderPreset('venice')!.fallbackModels.single.id,
        'venice-latest');
    expect(
      findLlmOpenAiProviderPreset('vercel-ai-gateway')!
          .fallbackModels
          .map((m) => m.id),
      [
        'openai/gpt-4.1',
        'anthropic/claude-4-sonnet',
        'google/gemini-2.5-pro',
        'moonshotai/kimi-k2',
        'vercel/v0-1.5-md',
      ],
    );
    expect(
      findLlmOpenAiProviderPreset('volcengine')!
          .fallbackModels
          .map((m) => m.id),
      [
        'deepseek-v3-2-251201',
        'doubao-seed-2-0-pro-260215',
        'doubao-seed-2-0-code-preview-260215',
        'kimi-k2-5-260127',
        'glm-4-7-251222',
        'DeepSeek-V4-Flash',
        'DeepSeek-V4-Pro',
      ],
    );
    expect(
      findLlmOpenAiProviderPreset('wandb')!.fallbackModels.map((m) => m.id),
      [
        'openai/gpt-oss-120b',
        'Qwen/Qwen3-Coder-480B-A35B-Instruct',
        'deepseek-ai/DeepSeek-V3.1',
      ],
    );
    expect(
      findLlmOpenAiProviderPreset('volcengine-agent-plan')!
          .fallbackModels
          .map((m) => m.id),
      [
        'doubao-seed-evolving',
        'doubao-seed-2-1-turbo-260628',
        'doubao-seed-2-0-lite-260215',
        'doubao-seed-2-0-mini-260215',
        'deepseek-v4-flash-ga-260731',
        'kimi-k3',
        'glm-5-2-260617',
        'kimi-k2.7-code',
        'minimax-m3',
        'deepseek-v4-pro-260425',
        'minimax-m2.7',
        'kimi-k2.6',
      ],
    );
    expect(
      findLlmOpenAiProviderPreset('volcengine-agent-plan')!
          .fallbackModels
          .first
          .capabilities,
      {
        'contextLength': 1048576,
        'toolCalling': true,
        'vision': true,
        'reasoning': true,
      },
    );
    expect(
      findLlmOpenAiProviderPreset('volcengine-coding-plan')!
          .fallbackModels
          .first
          .capabilities,
      {
        'contextLength': 262144,
        'toolCalling': true,
        'vision': true,
        'reasoning': true,
      },
    );
    for (final presetId in [
      'volcengine-agent-plan',
      'volcengine-coding-plan'
    ]) {
      final preset = findLlmOpenAiProviderPreset(presetId)!;
      for (final modelId in ['minimax-m2.7', 'kimi-k2.6']) {
        final model = preset.fallbackModels.singleWhere(
          (model) => model.id == modelId,
        );
        expect(model.capabilities, {
          'contextLength': 1048576,
          'toolCalling': true,
          'reasoning': true,
        });
      }
    }
  });

  test(
      'each M47 eligible preset saves, reloads, and routes through Chat and Task Flow',
      () async {
    final service = LlmAccountConnectorService(
      preferences: _MemoryLlmAccountPreferences(),
      credentialStore: _MemoryLlmCredentials(),
    );
    const presetIds = [
      'typhoon',
      'unifically',
      'unorouter',
      'upstage',
      'v0-vercel',
      'venice',
      'vercel-ai-gateway',
      'void-ai',
      'volcengine',
      'volcengine-agent-plan',
      'volcengine-coding-plan',
      'wandb',
    ];
    for (final presetId in presetIds) {
      final preset = findLlmOpenAiProviderPreset(presetId)!;
      final fallback = preset.fallbackModels.firstOrNull;
      final model = LlmUpstreamModel(
        id: 'm47-$presetId:${fallback?.id ?? 'user-model'}',
        upstreamModelId: fallback?.id ?? 'user-model',
        displayName: fallback?.displayName ?? 'User model',
        capabilities: fallback?.capabilities ?? const {},
        config: const {'apiProtocolOverride': 'anthropic.messages'},
      );
      final account = LlmAccount(
        id: 'm47-$presetId',
        connectorType: 'openai-compatibility',
        authType: preset.authType,
        displayName: preset.displayName,
        endpointConfig: preset.applyToEndpointConfig(const {
          'accountOwnedConfig': 'preserved',
        }),
        models: [model],
      );
      await service.saveAccount(account, secret: 'key-$presetId');
      final restored = (await service.getAccount(account.id))!;
      expect(restored.connectorType, 'openai-compatibility', reason: presetId);
      expect(restored.endpointConfig['providerPresetId'], presetId);
      expect(restored.endpointConfig['baseUrl'], preset.baseUrl);
      expect(restored.endpointConfig['modelsUrl'], preset.modelsUrl);
      expect(restored.endpointConfig['apiProtocol'], 'openai.chat_completions');
      expect(restored.endpointConfig['accountOwnedConfig'], 'preserved');
      expect(await service.readCredential(account.id), 'key-$presetId');
      expect(restored.models.single.upstreamModelId, model.upstreamModelId);
      expect(restored.models.single.capabilities, model.capabilities);
      expect(
        restored.models.single.config['apiProtocolOverride'],
        'anthropic.messages',
      );

      final group = LlmModelGroup(
        id: 'm47-$presetId-group',
        displayName: preset.displayName,
        members: [
          LlmModelGroupMember(
            accountId: restored.id,
            upstreamModelId: restored.models.single.upstreamModelId,
          ),
        ],
      );
      final configs = buildLlmModelGroupProviderConfigs(
        accounts: [restored],
        groups: [group],
      );
      expect(configs, hasLength(1));
      expect(configs.single.apiProtocol, 'openai.chat_completions');
      expect(
        configs.single.models.single.apiProtocolOverride,
        'anthropic.messages',
      );
      expect(
        llmRoutedChatSupportedConnectorTypes('openai.chat_completions'),
        contains('openai-compatibility'),
      );
    }
  });

  test(
      'M47 discovery presets refresh provider-owned model lists with bearer auth',
      () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..httpClientAdapter = _FunctionalAdapter((options) async {
        requests.add(options);
        return ResponseBody.fromString(
          jsonEncode({
            'data': [
              {'id': 'discovered-${requests.length}'},
            ],
          }),
          200,
          headers: const {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
    final service = LlmAccountConnectorService(
      preferences: _MemoryLlmAccountPreferences(),
      credentialStore: _MemoryLlmCredentials(),
      dio: dio,
    );
    const presetIds = [
      'unifically',
      'unorouter',
      'void-ai',
      'volcengine-coding-plan',
    ];
    for (final presetId in presetIds) {
      final preset = findLlmOpenAiProviderPreset(presetId)!;
      final account = await service.saveAccount(
        LlmAccount(
          id: 'm47-$presetId-discovery',
          connectorType: 'openai-compatibility',
          authType: preset.authType,
          displayName: preset.displayName,
          endpointConfig: preset.applyToEndpointConfig(const {}),
        ),
        secret: 'key-$presetId',
      );
      final models = await service.discoverModels(account, refreshRemote: true);
      expect(requests.last.uri.toString(), preset.modelsUrl, reason: presetId);
      expect(requests.last.headers['Authorization'], 'Bearer key-$presetId');
      expect(models.single.upstreamModelId, 'discovered-${requests.length}');
    }
  });
  test('M48 catalog uses audited routes and preserves the Yi M35 entry', () {
    const endpoints = {
      'writer': 'https://api.writer.com/v1/chat/completions',
      'xiaomi-mimo': 'https://api.xiaomimimo.com/v1/chat/completions',
      'xkiro': 'https://api.xkiro.com/v1/chat/completions',
      'y-api': 'https://api.y-api.bestvirtualgoods.com/v1/chat/completions',
      'yolo-auto': 'https://yolo-auto.com/v1/chat/completions',
      'zerolimitai': 'https://www.zerolimitai.com/api/v1/chat/completions',
      'zylo-api': 'https://api.zyloai.net/v1/chat/completions',
    };
    for (final entry in endpoints.entries) {
      final preset = findLlmOpenAiProviderPreset(entry.key)!;
      expect(preset.baseUrl, entry.value, reason: entry.key);
      expect(preset.authType, 'api_key', reason: entry.key);
      expect(preset.authorizationHeader, 'Authorization', reason: entry.key);
      expect(preset.authorizationScheme, 'Bearer', reason: entry.key);
      expect(preset.defaultApiProtocol, 'openai.chat_completions');
    }
    expect(findLlmOpenAiProviderPreset('watsonx'), isNull);
    expect(findLlmOpenAiProviderPreset('x5lab'), isNull);
    expect(findLlmOpenAiProviderPreset('zenmux'), isNull);
    expect(findLlmOpenAiProviderPreset('xiaomi-mimo-token-plan'), isNull);
    expect(findLlmOpenAiProviderPreset('yi'), isNotNull);
    expect(
      llmOpenAiProviderPresets.where((preset) => preset.id == 'yi'),
      hasLength(1),
    );
    expect(
      {
        for (final id in [
          'y-api',
          'yolo-auto',
          'zerolimitai',
          'zylo-api',
        ])
          id: findLlmOpenAiProviderPreset(id)!.modelsUrl,
      },
      {
        'y-api': 'https://api.y-api.bestvirtualgoods.com/v1/models',
        'yolo-auto': 'https://yolo-auto.com/v1/models',
        'zerolimitai': 'https://www.zerolimitai.com/api/v1/models',
        'zylo-api': 'https://api.zyloai.net/v1/models',
      },
    );
    expect(
      findLlmOpenAiProviderPreset(
        'writer',
      )!
          .fallbackModels
          .map((model) => model.id),
      ['palmyra-x5', 'palmyra-x4'],
    );
    expect(findLlmOpenAiProviderPreset('xkiro')!.fallbackModels, hasLength(39));
    expect(
      findLlmOpenAiProviderPreset('xkiro')!.fallbackModels.first.capabilities,
      {'contextLength': 262144, 'toolCalling': true, 'vision': true},
    );
    expect(
      findLlmOpenAiProviderPreset(
        'xiaomi-mimo',
      )!
          .fallbackModels
          .first
          .capabilities,
      {'contextLength': 1048576, 'maxOutputTokens': 131072},
    );
  });

  test(
    'M48 presets save and route through shared Chat and Task Flow',
    () async {
      final service = LlmAccountConnectorService(
        preferences: _MemoryLlmAccountPreferences(),
        credentialStore: _MemoryLlmCredentials(),
      );
      const presetIds = [
        'writer',
        'xiaomi-mimo',
        'xkiro',
        'y-api',
        'yolo-auto',
        'zerolimitai',
        'zylo-api',
      ];
      for (final presetId in presetIds) {
        final preset = findLlmOpenAiProviderPreset(presetId)!;
        final fallback = preset.fallbackModels.firstOrNull;
        final model = LlmUpstreamModel(
          id: 'm48-$presetId:${fallback?.id ?? 'user-model'}',
          upstreamModelId: fallback?.id ?? 'user-model',
          displayName: fallback?.displayName ?? 'User model',
          capabilities: fallback?.capabilities ?? const {},
          config: const {'apiProtocolOverride': 'anthropic.messages'},
        );
        final account = LlmAccount(
          id: 'm48-$presetId',
          connectorType: 'openai-compatibility',
          authType: preset.authType,
          displayName: preset.displayName,
          endpointConfig: preset.applyToEndpointConfig(const {
            'accountOwnedConfig': 'preserved',
          }),
          models: [model],
        );
        await service.saveAccount(account, secret: 'key-$presetId');
        final restored = (await service.getAccount(account.id))!;
        expect(restored.endpointConfig['providerPresetId'], presetId);
        expect(restored.endpointConfig['baseUrl'], preset.baseUrl);
        expect(restored.endpointConfig['modelsUrl'], preset.modelsUrl);
        expect(
          restored.endpointConfig['apiProtocol'],
          'openai.chat_completions',
        );
        expect(restored.endpointConfig['accountOwnedConfig'], 'preserved');
        expect(await service.readCredential(account.id), 'key-$presetId');
        expect(restored.models.single.upstreamModelId, model.upstreamModelId);
        expect(
          restored.models.single.config['apiProtocolOverride'],
          'anthropic.messages',
        );

        final group = LlmModelGroup(
          id: 'm48-$presetId-group',
          displayName: preset.displayName,
          members: [
            LlmModelGroupMember(
              accountId: restored.id,
              upstreamModelId: restored.models.single.upstreamModelId,
            ),
          ],
        );
        final configs = buildLlmModelGroupProviderConfigs(
          accounts: [restored],
          groups: [group],
        );
        expect(configs, hasLength(1));
        expect(configs.single.apiProtocol, 'openai.chat_completions');
        expect(
          configs.single.models.single.apiProtocolOverride,
          'anthropic.messages',
        );
        expect(
          llmRoutedChatSupportedConnectorTypes('openai.chat_completions'),
          contains('openai-compatibility'),
        );
      }
    },
  );

  test(
    'M48 dynamic catalogs refresh from audited endpoints with bearer auth',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          requests.add(options);
          return ResponseBody.fromString(
            jsonEncode({
              'data': [
                {'id': 'discovered-${requests.length}'},
              ],
            }),
            200,
            headers: const {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });
      final service = LlmAccountConnectorService(
        preferences: _MemoryLlmAccountPreferences(),
        credentialStore: _MemoryLlmCredentials(),
        dio: dio,
      );
      const presetIds = [
        'y-api',
        'yolo-auto',
        'zerolimitai',
        'zylo-api',
      ];
      for (final presetId in presetIds) {
        final preset = findLlmOpenAiProviderPreset(presetId)!;
        final account = await service.saveAccount(
          LlmAccount(
            id: 'm48-$presetId-discovery',
            connectorType: 'openai-compatibility',
            authType: preset.authType,
            displayName: preset.displayName,
            endpointConfig: preset.applyToEndpointConfig(const {}),
          ),
          secret: 'key-$presetId',
        );
        final models = await service.discoverModels(
          account,
          refreshRemote: true,
        );
        expect(
          requests.last.uri.toString(),
          preset.modelsUrl,
          reason: presetId,
        );
        expect(requests.last.headers['Authorization'], 'Bearer key-$presetId');
        expect(models.single.upstreamModelId, 'discovered-${requests.length}');
      }
    },
  );

  test('M53 Chenzk preset matches the pinned provider contract', () {
    final preset = findLlmOpenAiProviderPreset('chenzk')!;

    expect(preset.displayName, 'Chenzk');
    expect(preset.baseUrl, 'https://chenzk.top/v1/chat/completions');
    expect(preset.modelsUrl, 'https://chenzk.top/v1/models');
    expect(preset.authType, 'api_key');
    expect(preset.authorizationHeader, 'Authorization');
    expect(preset.authorizationScheme, 'Bearer');
    expect(preset.defaultApiProtocol, 'openai.chat_completions');
    expect(preset.fallbackModels, isEmpty);
  });

  test(
    'M53 Chenzk account stores its key securely, discovers models, and routes',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _FunctionalAdapter((options) async {
          requests.add(options);
          return ResponseBody.fromString(
            jsonEncode({
              'data': [
                {'id': 'chenzk-discovered-model'},
              ],
            }),
            200,
            headers: const {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });
      final credentials = _MemoryLlmCredentials();
      final service = LlmAccountConnectorService(
        preferences: _MemoryLlmAccountPreferences(),
        credentialStore: credentials,
        dio: dio,
      );
      final preset = findLlmOpenAiProviderPreset('chenzk')!;
      final saved = await service.saveAccount(
        LlmAccount(
          id: 'm53-chenzk',
          connectorType: 'openai-compatibility',
          authType: preset.authType,
          displayName: preset.displayName,
          endpointConfig: preset.applyToEndpointConfig(const {}),
          models: const [
            LlmUpstreamModel(
              id: 'm53-chenzk-override',
              upstreamModelId: 'chenzk-discovered-model',
              displayName: 'Chenzk discovered model',
              config: {'apiProtocolOverride': 'openai.chat_completions'},
            ),
          ],
        ),
        secret: 'chenzk-secret',
      );

      expect(await service.readCredential('m53-chenzk'), 'chenzk-secret');
      expect(saved.endpointConfig['providerPresetId'], 'chenzk');
      expect(saved.endpointConfig['apiProtocol'], 'openai.chat_completions');
      expect(saved.endpointConfig.toString(), isNot(contains('chenzk-secret')));

      final discovered = await service.discoverModels(
        saved,
        refreshRemote: true,
      );
      expect(requests.single.uri.toString(), 'https://chenzk.top/v1/models');
      expect(requests.single.headers['Authorization'], 'Bearer chenzk-secret');
      expect(discovered.single.upstreamModelId, 'chenzk-discovered-model');

      final restored = (await service.getAccount(saved.id))!;
      expect(await service.readCredential(restored.id), 'chenzk-secret');
      expect(
        restored.models.single.config['apiProtocolOverride'],
        'openai.chat_completions',
      );
      final group = LlmModelGroup(
        id: 'm53-chenzk-group',
        displayName: 'Chenzk',
        members: const [
          LlmModelGroupMember(
            accountId: 'm53-chenzk',
            upstreamModelId: 'chenzk-discovered-model',
          ),
        ],
      );
      final configs = buildLlmModelGroupProviderConfigs(
        accounts: [restored],
        groups: [group],
      );
      expect(configs, hasLength(1));
      expect(configs.single.apiProtocol, 'openai.chat_completions');
      expect(
        configs.single.models.single.apiProtocolOverride,
        'openai.chat_completions',
      );
      expect(
        llmRoutedChatSupportedConnectorTypes('openai.chat_completions'),
        contains('openai-compatibility'),
      );
    },
  );
}

class _MemoryLlmAccountPreferences implements LlmAccountPreferences {
  final _values = <String, String>{};

  @override
  Future<String?> getString(String key) async => _values[key];

  @override
  Future<bool> setString(String key, String value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async => _values.remove(key) != null;
}

class _MemoryLlmCredentials implements LlmCredentialStore {
  final _values = <String, String>{};

  @override
  Future<String?> read(String reference) async => _values[reference];

  @override
  Future<void> write(String reference, String secret) async {
    _values[reference] = secret;
  }

  @override
  Future<void> delete(String reference) async {
    _values.remove(reference);
  }
}

class _FunctionalAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  _FunctionalAdapter(this.onFetch);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      onFetch(options);

  @override
  void close({bool force = false}) {}
}
