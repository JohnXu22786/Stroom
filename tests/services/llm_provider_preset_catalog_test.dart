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
  test('the source-backed presets retain their endpoint and auth metadata', () {
    expect(llmOpenAiProviderPresets.map((preset) => preset.id), [
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
      'baichuan',
      'baidu',
      'baseten',
      'bazaarlink',
      'beatapi',
      'bigmodel',
      'byteplus',
      'cerebras',
      'chutes',
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
        'auriko': 'https://api.auriko.ai/v1/chat/completions',
        'baseten': 'https://inference.baseten.co/v1/chat/completions',
        'baichuan': 'https://api.baichuan-ai.com/v1/chat/completions',
        'baidu': 'https://qianfan.baidubce.com/v2/chat/completions',
        'bigmodel': 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
        'bazaarlink': 'https://bazaarlink.ai/api/v1/chat/completions',
        'beatapi': 'https://api.beatapi.io/v1/chat/completions',
        'byteplus':
            'https://ark.ap-southeast.bytepluses.com/api/v3/chat/completions',
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
          'bazaarlink',
          'beatapi',
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
        'bazaarlink': 'https://bazaarlink.ai/api/v1/models',
        'beatapi': 'https://api.beatapi.io/v1/models',
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

  test('M37 presets retain the pinned source fallback catalog', () {
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
        findLlmOpenAiProviderPreset('baidu')!.fallbackModels.first.capabilities,
        containsPair('contextLength', 131072));
    expect(
        findLlmOpenAiProviderPreset('apmix')!.fallbackModels[39].capabilities,
        containsPair('vision', true));
    expect(
        findLlmOpenAiProviderPreset('bazaarlink')!
            .fallbackModels[22]
            .capabilities,
        containsPair('vision', true));
    // Deferred: open-sse/config/providers/registry/api-airforce/index.ts:13-16
    // requires HTTP-Referer and X-Title headers that presets cannot represent.
    expect(findLlmOpenAiProviderPreset('api-airforce'), isNull);
    // Deferred: open-sse/config/providers/registry/bai/index.ts:16 requires
    // reasoning-content echo, which presets cannot represent.
    expect(findLlmOpenAiProviderPreset('bai'), isNull);
    // `baidu` is the single user-facing choice for the shared Qianfan chat URL.
    expect(findLlmOpenAiProviderPreset('qianfan'), isNull);
  });

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
