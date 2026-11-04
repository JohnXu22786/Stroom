import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/ai_gateway/ai_gateway.dart';
import 'package:stroom/ai_gateway/ai_gateway_contracts.dart';
import 'package:stroom/models/llm_account.dart';
import 'package:stroom/providers/llm_routed_chat_provider.dart';
import 'package:stroom/services/llm_model_group_provider.dart';
import 'package:stroom/services/llm_connector_service.dart';
import 'package:stroom/services/llm_account_migration_service.dart';
import 'package:stroom/services/llm_credential_store.dart';
import 'package:stroom/services/llm_provider_preset_catalog.dart';

void main() {
  test('the 12 presets retain their pinned endpoint and auth metadata', () {
    expect(llmOpenAiProviderPresets.map((preset) => preset.id), [
      'ai21',
      'aimlapi',
      'arcee-ai',
      'baseten',
      'cerebras',
      'fireworks',
      'groq',
      'huggingface',
      'mistral',
      'novita',
      'nvidia',
      'together',
    ]);
    for (final preset in llmOpenAiProviderPresets) {
      expect(preset.baseUrl, startsWith('https://'));
      expect(preset.authType, 'api_key');
      expect(preset.authorizationHeader, 'Authorization');
      expect(preset.authorizationScheme, 'Bearer');
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
        'arcee-ai': 'https://api.arcee.ai/api/v1/chat/completions',
        'baseten': 'https://inference.baseten.co/v1/chat/completions',
        'cerebras': 'https://api.cerebras.ai/v1/chat/completions',
        'fireworks': 'https://api.fireworks.ai/inference/v1/chat/completions',
        'groq': 'https://api.groq.com/openai/v1/chat/completions',
        'huggingface': 'https://router.huggingface.co/v1/chat/completions',
        'mistral': 'https://api.mistral.ai/v1/chat/completions',
        'novita': 'https://api.novita.ai/openai/v1/chat/completions',
        'nvidia': 'https://integrate.api.nvidia.com/v1/chat/completions',
        'together': 'https://api.together.xyz/v1/chat/completions',
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
      findLlmOpenAiProviderPreset('ai21')!
          .fallbackModels
          .map((model) => model.id),
      containsAll(['jamba-large-1.7', 'jamba-mini-2']),
    );
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
