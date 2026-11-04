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
    // registry/cheaperinference/index.ts:240-252 declares Responses-target
    // models and executor-specific routing; registry/chenzk/index.ts:4,6-11,13-14
    // sets defaultContextLength for runtime-discovered models, which this
    // catalog cannot represent; registry/cloudflare-ai/index.ts:4,6,7,9-11,17
    // and executors/cloudflare-ai.ts:17-56 require an account ID in the URL
    // and a provider-specific executor.
    for (final id in [
      'blackbox',
      'cheaperinference',
      'chenzk',
      'cloudflare-ai',
    ]) {
      expect(findLlmOpenAiProviderPreset(id), isNull);
    }
    // Deferred: open-sse/config/providers/registry/api-airforce/index.ts:13-16
    // requires HTTP-Referer and X-Title headers that presets cannot represent.
    expect(findLlmOpenAiProviderPreset('api-airforce'), isNull);
    // Deferred: open-sse/config/providers/registry/bai/index.ts:16 requires
    // reasoning-content echo, which presets cannot represent.
    expect(findLlmOpenAiProviderPreset('bai'), isNull);
    // `baidu` is the single user-facing choice for the shared Qianfan chat URL.
    expect(findLlmOpenAiProviderPreset('qianfan'), isNull);
    // The eligible M38 registry entries use distinct chat URLs, so no aliases
    // in this cohort need to collapse to a single user-facing choice.
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
