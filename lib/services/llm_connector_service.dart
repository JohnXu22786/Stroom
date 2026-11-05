import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/googleapis_auth.dart'
    show ServiceAccountCredentials;
import 'package:uuid/uuid.dart';

import '../models/llm_account.dart';
import 'aws_bedrock_converse.dart';
import 'aws_credential_chain.dart';
import 'aws_sigv4.dart';
import 'llm_account_migration_service.dart';
import 'llm_credential_store.dart';
import 'llm_connector_model_catalog.dart';
import 'cloudflare_workers_ai_connector.dart';
import 'llm_provider_preset_catalog.dart';
import 'ai_horde_connector.dart';
import 'llm_oauth_flow.dart';
import 'llm_oauth_token_client.dart';
import 'devin_connect_rpc.dart';
import 'qoder_cli_service.dart';
import 'cursor_connect_rpc.dart';
import 'cursor_http2_transport.dart';
import 'trae_solo_connector.dart';
import 'zed_hosted_connector.dart';
import 'amazon_q_connector.dart';
import 'azure_openai_endpoint.dart';
import 'clova_studio_protocol.dart';

/// Frozen upstream implementation used to define this connector catalog.
const String kLlmConnectorReferenceRevision =
    'd318bcc3afb9ea8782862f5e8cdb541afdc9dfa5';

const _claudeOAuthClientId = LlmOAuthAuthorizationAttempt.claudeCodeClientId;
const _kimiOAuthClientId = LlmOAuthAuthorizationAttempt.kimiCodeClientId;
const _xaiOAuthClientId = 'b1a00492-073a-47ea-816f-4c329264a828';
const _grokBuildClientHeaders = <String, String>{
  'X-XAI-Token-Auth': 'xai-grok-cli',
  'x-grok-client-version': '1.0.46',
  'x-grok-client-identifier': 'grok-shell',
  'x-grok-client-mode': 'headless',
  'x-authenticateresponse': 'authenticate-response',
};

const kLlmAntigravityRequestUserAgent = 'antigravity/hub/2.9.1 darwin/arm64';

const _openCodeGoBaseUrl = 'https://opencode.ai/zen/go/v1';
const _openCodeGoAnthropicBaseUrl = 'https://opencode.ai/zen/go';
const _openCodeZenBaseUrl = 'https://opencode.ai/zen/v1';
const _openCodeZenAnthropicBaseUrl = 'https://opencode.ai/zen';
const kCommandCodeBaseUrl = 'https://api.commandcode.ai/provider/v1';
const _uncloseAiBaseUrl = 'https://hermes.ai.unturf.com/v1';
const _uncloseAiChatModelId = 'turboderp/Qwen3.8-27B-exl3';
const _uncloseAiDefaultContextLength = 65536;

const _commandCodeProtocolByEndpoint = <String, String>{
  '/chat/completions': 'openai.chat_completions',
  '/responses': 'openai.responses',
  '/messages': 'anthropic.messages',
};

String _qoderRuntimeArchitecture() {
  final match = RegExp(r'\bon "([^"]+)"').firstMatch(Platform.version);
  final runtimeId = match?.group(1) ?? '';
  final separator = runtimeId.lastIndexOf('_');
  return separator < 0 ? '' : runtimeId.substring(separator + 1);
}

const _qwenCloudRegions = {
  'ap-southeast-1',
  'cn-beijing',
  'eu-central-1',
  'cn-hongkong',
  'ap-northeast-1',
  'us-east-1',
};

String _amazonQRegion(LlmAccount account, Map<String, dynamic> credential) {
  final configured = account.endpointConfig['region'];
  final credentialRegion =
      credential['region'] ?? credential['regionId'] ?? credential['region_id'];
  final value = configured is String && configured.trim().isNotEmpty
      ? configured
      : credentialRegion is String && credentialRegion.trim().isNotEmpty
          ? credentialRegion
          : 'us-east-1';
  final region = value.trim().toLowerCase();
  if (!AmazonQConnector.isSupportedRegion(region)) {
    throw const LlmAccountConnectorException();
  }
  return region;
}

void _addTencentClientHeaders(
  String connectorType,
  Map<String, String> headers, {
  bool discovery = false,
  Object? body,
  String? conversationId,
}) {
  switch (connectorType) {
    case 'codebuddy-cn':
      headers.addAll({
        'User-Agent': 'CLI/2.108.1 CodeBuddy/2.108.1',
        'X-Product': 'SaaS',
        'X-IDE-Type': 'CLI',
        'X-IDE-Name': 'CLI',
        'X-Requested-With': 'XMLHttpRequest',
        'x-codebuddy-request': '1',
        'Accept': 'text/event-stream',
      });
    case 'codebuddy-intl':
      headers.addAll({
        'User-Agent': 'IDE/2.108.1 CodeBuddy/2.108.1',
        'X-Product': 'SaaS',
        'X-IDE-Type': 'IDE',
        'X-IDE-Name': 'IDE',
        'X-Requested-With': 'XMLHttpRequest',
        'x-codebuddy-request': '1',
        'Accept': 'text/event-stream',
      });
      if (!discovery) _addConversationHeaders(headers, body);
    case 'workbuddy':
      headers.addAll({
        'User-Agent': 'WorkBuddy/5.5.6',
        'X-Product': 'SaaS',
        'X-IDE-Type': 'WorkBuddy',
        'X-IDE-Name': 'WorkBuddy',
        'X-IDE-Version': '5.5.6',
        'X-Requested-With': 'XMLHttpRequest',
        'X-Domain': 'www.workbuddy.ai',
        'Accept': discovery ? 'application/json' : 'text/event-stream',
      });
      if (!discovery) {
        headers.addAll({
          'X-Agent-Intent': 'craft',
          'X-Agent-Purpose': 'conversation',
          'X-Agent-Type': 'main',
        });
        _addConversationHeaders(
          headers,
          body,
          workbuddy: true,
          conversationId: conversationId,
        );
      }
  }
}

void _addConversationHeaders(
  Map<String, String> headers,
  Object? body, {
  bool workbuddy = false,
  String? conversationId,
}) {
  final map = body is Map ? body : const <Object?, Object?>{};
  String key = conversationId?.trim().isNotEmpty == true
      ? conversationId!.trim()
      : [map['session_id'], map['prompt_cache_key'], map['conversation_id']]
          .whereType<String>()
          .map((value) => value.trim())
          .firstWhere((value) => value.isNotEmpty, orElse: () => '');
  if (key.isEmpty && !workbuddy) {
    final messages = map['messages'];
    if (messages is Iterable) {
      final firstUser = messages.whereType<Map>().firstWhere(
            (message) => message['role'] == 'user',
            orElse: () => const {},
          );
      if (firstUser.isNotEmpty) key = jsonEncode(firstUser);
    }
  }
  final resolvedConversationId = key.isEmpty
      ? const Uuid().v4()
      : crypto.sha256.convert(utf8.encode(key)).toString().substring(0, 32);
  headers['X-Conversation-ID'] = resolvedConversationId;
  headers['X-Conversation-Request-ID'] = const Uuid().v4();
  final messageId = const Uuid().v4();
  headers['X-Conversation-Message-ID'] = messageId;
  if (workbuddy || headers.containsKey('X-Conversation-ID')) {
    headers['X-Request-ID'] = messageId;
  }
}

Map<String, Object?> _staticTencentModelCapabilities(
  String connectorType,
  String modelId,
) {
  final visualModels = connectorType == 'codebuddy-cn'
      ? const {
          'glm-5v-turbo',
          'minimax-m3',
          'minimax-m2.7',
          'kimi-k2.7',
          'kimi-k2.6',
          'kimi-k2.5',
          'hy3-preview',
          'hy3',
          'deepseek-v4-pro',
          'deepseek-v4-flash',
        }
      : const {
          'hy4-preview',
          'hy3',
          'gemini-3.5-flash',
          'glm-5v-turbo',
          'minimax-m3',
          'kimi-k3',
          'kimi-k2.7',
          'kimi-k2.6',
          'deepseek-v4.1-flash',
        };
  return {
    'chat': true,
    'streaming': true,
    'reasoning': true,
    if (visualModels.contains(modelId)) 'vision': true,
  };
}

List<String>? _commandCodeProtocolsForModel(Map<String, dynamic> model) {
  final endpoints = model['supported_endpoints'];
  if (endpoints is! Iterable) return null;
  final protocols = <String>[];
  for (final endpoint in endpoints.whereType<String>()) {
    final normalized = endpoint.trim().toLowerCase().replaceFirst(
          RegExp(r'/+$'),
          '',
        );
    for (final entry in _commandCodeProtocolByEndpoint.entries) {
      if (normalized.endsWith(entry.key) && !protocols.contains(entry.value)) {
        protocols.add(entry.value);
      }
    }
  }
  return protocols.isEmpty ? null : protocols;
}

String _qwenCloudBaseUrl(Map<String, dynamic> config) {
  final configured = config['baseUrl'];
  if (configured is String && configured.trim().isNotEmpty) {
    final parsed = Uri.tryParse(configured.trim());
    if (parsed == null || parsed.host.isEmpty || parsed.userInfo.isNotEmpty) {
      throw const LlmAccountConnectorException();
    }
    return parsed.replace(path: '/compatible-mode/v1', query: null).toString();
  }
  final rawRegion = config['region'];
  final region = rawRegion is String && rawRegion.trim().isNotEmpty
      ? rawRegion.trim()
      : 'ap-southeast-1';
  if (!_qwenCloudRegions.contains(region)) {
    throw const LlmAccountConnectorException();
  }
  return 'https://$region.maas.qwencloudapi.com/compatible-mode/v1';
}

String _qwenCloudProtocolBaseUrl(
  String connectorType,
  Map<String, dynamic> config,
  String? nativeFormat,
) {
  final host = connectorType == 'qwen-cloud-token-plan'
      ? 'token-plan.maas.qwencloudapi.com'
      : Uri.parse(_qwenCloudBaseUrl(config)).host;
  final path =
      nativeFormat == 'anthropic' ? '/apps/anthropic' : '/compatible-mode/v1';
  return 'https://$host$path';
}

enum LlmNativeProtocol {
  clovaStudioChat,
  openAIResponses,
  anthropicMessages,
  antigravityGenerateContent,
  kimiChatCompletions,
  xaiResponses,
  grokBuildResponses,
  xaiOAuthResponses,
  devinConnectRpc,
  devinCliAcp,
  cursorAgentConnectRpc,
  metaResponses,
  geminiGenerateContent,
  geminiInteractions,
  vertexGenerateContent,
  openAIChatCompletions,
  kiloCodeChatCompletions,
  ollamaChat,
  bedrockConverse,
  amazonQChat,
}

enum LlmQuotaAvailability { accountQuota, requestUsageOnly, unknown }

class LlmConnectorDefinition {
  final String id;
  final String displayName;
  final LlmNativeProtocol protocol;
  final Set<String> authTypes;
  final List<String> modelCatalog;
  final bool canRefreshCredentials;
  final LlmQuotaAvailability quotaAvailability;

  const LlmConnectorDefinition({
    required this.id,
    required this.displayName,
    required this.protocol,
    required this.authTypes,
    this.modelCatalog = const [],
    this.canRefreshCredentials = false,
    this.quotaAvailability = LlmQuotaAvailability.unknown,
  });
}

/// Registry built from CLIProxyAPI's core auth-manager and executor
/// registrations at [kLlmConnectorReferenceRevision].
///
/// The aliases intentionally include the three Kimi identifiers registered by
/// the source. There is no Gemini CLI authenticator in that snapshot.
abstract final class LlmConnectorRegistry {
  static bool isConversationalModel(
    String modelId,
    Map<String, dynamic> metadata,
  ) {
    final task = [
      metadata['taskType'],
      metadata['task_type'],
      metadata['modelType'],
      metadata['type'],
    ].whereType<String>().join(' ').toLowerCase();
    final methods = metadata['supportedGenerationMethods'];
    final methodsExcludeChat = methods is Iterable &&
        !methods.contains('generateContent') &&
        !methods.contains('streamGenerateContent');
    return metadata['chat'] != false &&
        !RegExp(
          r'embed|rerank|re-rank|ranking|classification|image[- ]generation',
        ).hasMatch(task) &&
        !methodsExcludeChat &&
        isConversationalModelId(modelId);
  }

  static bool isConversationalModelId(String modelId) => !RegExp(
        r'(^|[._:/-])(embed(?:ding)?|rerank(?:er)?|re-rank|whisper|tts|transcrib|imagen|dall-e)([._:/-]|$)|(^|[._:/-])grok(?:[._:/-][a-z0-9]+)*[._:/-]image([._:/-]|$)',
        caseSensitive: false,
      ).hasMatch(modelId);

  static const List<LlmConnectorDefinition> all = [
    LlmConnectorDefinition(
      id: 'clova-studio',
      displayName: 'Naver CLOVA Studio',
      protocol: LlmNativeProtocol.clovaStudioChat,
      authTypes: {'api_key'},
      modelCatalog: kClovaStudioModelIds,
    ),
    LlmConnectorDefinition(
      id: 'amazon-q',
      displayName: 'Amazon Q Developer',
      protocol: LlmNativeProtocol.amazonQChat,
      authTypes: {'oauth'},
      canRefreshCredentials: true,
    ),
    LlmConnectorDefinition(
      id: 'github',
      displayName: 'GitHub Copilot',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'oauth'},
      canRefreshCredentials: true,
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'ghe-copilot',
      displayName: 'GitHub Enterprise Copilot',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'oauth'},
      canRefreshCredentials: true,
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'gitlab-duo',
      displayName: 'GitLab Duo',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'pat', 'oauth'},
      modelCatalog: kPinnedGitLabDuoModels,
      canRefreshCredentials: true,
    ),
    LlmConnectorDefinition(
      id: 'zed-hosted',
      displayName: 'Zed Hosted Models',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'oauth'},
    ),
    LlmConnectorDefinition(
      id: 'codex',
      displayName: 'OpenAI Codex',
      protocol: LlmNativeProtocol.openAIResponses,
      authTypes: {'oauth', 'api_key'},
      modelCatalog: kPinnedCodexModels,
      canRefreshCredentials: true,
      quotaAvailability: LlmQuotaAvailability.accountQuota,
    ),
    LlmConnectorDefinition(
      id: 'claude',
      displayName: 'Anthropic Claude Code',
      protocol: LlmNativeProtocol.anthropicMessages,
      authTypes: {'oauth', 'setup_token', 'api_key'},
      modelCatalog: kPinnedClaudeModels,
      canRefreshCredentials: true,
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'antigravity',
      displayName: 'Google Antigravity',
      protocol: LlmNativeProtocol.antigravityGenerateContent,
      authTypes: {'oauth'},
      modelCatalog: kPinnedAntigravityModels,
      canRefreshCredentials: true,
      quotaAvailability: LlmQuotaAvailability.accountQuota,
    ),
    LlmConnectorDefinition(
      id: 'kimi',
      displayName: 'Moonshot Kimi',
      protocol: LlmNativeProtocol.kimiChatCompletions,
      authTypes: {'oauth'},
      modelCatalog: kPinnedKimiModels,
      canRefreshCredentials: true,
    ),
    LlmConnectorDefinition(
      id: 'kimi-coding',
      displayName: 'Kimi Code CLI',
      protocol: LlmNativeProtocol.kimiChatCompletions,
      authTypes: {'oauth'},
      modelCatalog: kPinnedKimiCodeModels,
      canRefreshCredentials: true,
    ),
    LlmConnectorDefinition(
      id: 'kimi-ai',
      displayName: 'Moonshot Kimi.ai',
      protocol: LlmNativeProtocol.kimiChatCompletions,
      authTypes: {'oauth'},
      modelCatalog: kPinnedKimiModels,
      canRefreshCredentials: true,
    ),
    LlmConnectorDefinition(
      id: 'kimi.ai',
      displayName: 'Moonshot Kimi.ai',
      protocol: LlmNativeProtocol.kimiChatCompletions,
      authTypes: {'oauth'},
      modelCatalog: kPinnedKimiModels,
      canRefreshCredentials: true,
    ),
    LlmConnectorDefinition(
      id: 'xai',
      displayName: 'xAI Grok',
      protocol: LlmNativeProtocol.xaiResponses,
      authTypes: {'api_key'},
      modelCatalog: kPinnedXaiModels,
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'grok-cli',
      displayName: 'xAI Grok Build',
      protocol: LlmNativeProtocol.grokBuildResponses,
      authTypes: {'oauth'},
      modelCatalog: kPinnedGrokBuildModels,
      canRefreshCredentials: true,
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'xai-oauth',
      displayName: 'xAI API OAuth',
      protocol: LlmNativeProtocol.xaiOAuthResponses,
      authTypes: {'oauth'},
      canRefreshCredentials: true,
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'devin',
      displayName: 'Devin',
      protocol: LlmNativeProtocol.devinConnectRpc,
      authTypes: {'oauth', 'session_token'},
      modelCatalog: kPinnedDevinModels,
      quotaAvailability: LlmQuotaAvailability.accountQuota,
    ),
    LlmConnectorDefinition(
      id: 'devin-cli-agentic',
      displayName: 'Devin CLI Agentic Bridge',
      protocol: LlmNativeProtocol.devinCliAcp,
      authTypes: {'cli_session'},
      modelCatalog: kPinnedDevinCliModels,
    ),
    LlmConnectorDefinition(
      id: 'cursor',
      displayName: 'Cursor',
      protocol: LlmNativeProtocol.cursorAgentConnectRpc,
      authTypes: {'oauth', 'api_key'},
      modelCatalog: kPinnedCursorModels,
      canRefreshCredentials: true,
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'trae',
      displayName: 'Trae SOLO',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'session_token'},
      canRefreshCredentials: true,
    ),
    LlmConnectorDefinition(
      id: 'meta',
      displayName: 'Meta Muse Code',
      protocol: LlmNativeProtocol.metaResponses,
      authTypes: {'api_key'},
      modelCatalog: kPinnedMetaModels,
      canRefreshCredentials: true,
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'muse-code',
      displayName: 'Meta Muse Code OAuth',
      protocol: LlmNativeProtocol.metaResponses,
      authTypes: {'oauth'},
      modelCatalog: kPinnedMuseCodeModels,
      canRefreshCredentials: true,
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'openference',
      displayName: 'Openference',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'oauth'},
      modelCatalog: kPinnedOpenferenceModels,
      canRefreshCredentials: true,
    ),
    LlmConnectorDefinition(
      id: 'openference-api',
      displayName: 'Openference API',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'api_key'},
      modelCatalog: kPinnedOpenferenceModels,
    ),
    LlmConnectorDefinition(
      id: 'cline',
      displayName: 'Cline',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'oauth', 'api_key'},
      modelCatalog: kPinnedClineModels,
      canRefreshCredentials: true,
    ),
    LlmConnectorDefinition(
      id: 'clinepass',
      displayName: 'ClinePass',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'oauth', 'api_key'},
      modelCatalog: kPinnedClinePassModels,
      canRefreshCredentials: true,
    ),
    LlmConnectorDefinition(
      id: 'codebuddy-cn',
      displayName: 'CodeBuddy（中国）',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'oauth', 'api_key'},
      modelCatalog: kPinnedCodeBuddyCnModels,
      canRefreshCredentials: true,
    ),
    LlmConnectorDefinition(
      id: 'codebuddy-intl',
      displayName: 'CodeBuddy International',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'oauth', 'api_key'},
      modelCatalog: kPinnedCodeBuddyIntlModels,
      canRefreshCredentials: true,
    ),
    LlmConnectorDefinition(
      id: 'workbuddy',
      displayName: 'WorkBuddy',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'oauth'},
      canRefreshCredentials: true,
    ),
    LlmConnectorDefinition(
      id: 'qoder',
      displayName: 'Qoder',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'api_key', 'oauth', 'pat'},
      modelCatalog: kPinnedQoderModels,
    ),
    LlmConnectorDefinition(
      id: 'kilocode',
      displayName: 'Kilo Code',
      protocol: LlmNativeProtocol.kiloCodeChatCompletions,
      authTypes: {'oauth', 'api_key', 'none'},
      modelCatalog: kPinnedKiloCodeModels,
    ),
    LlmConnectorDefinition(
      id: 'gemini',
      displayName: 'Google Gemini API',
      protocol: LlmNativeProtocol.geminiGenerateContent,
      authTypes: {'api_key', 'oauth'},
      modelCatalog: kPinnedGeminiModels,
      canRefreshCredentials: true,
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'openai-api',
      displayName: 'OpenAI API',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'api_key'},
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'cloudflare-ai',
      displayName: 'Cloudflare Workers AI',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'api_key'},
      modelCatalog: kCloudflareWorkersAiModelIds,
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'azure-ai',
      displayName: 'Azure AI Foundry',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'api_key'},
    ),
    LlmConnectorDefinition(
      id: 'azure-openai',
      displayName: 'Azure OpenAI',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'api_key'},
    ),
    LlmConnectorDefinition(
      id: 'opencode-go',
      displayName: 'OpenCode Go',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'api_key'},
    ),
    LlmConnectorDefinition(
      id: 'opencode-zen',
      displayName: 'OpenCode Zen',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'api_key'},
    ),
    LlmConnectorDefinition(
      id: 'command-code',
      displayName: 'Command Code',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'api_key'},
    ),
    LlmConnectorDefinition(
      id: 'moonshot',
      displayName: 'Moonshot AI (Kimi API)',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'api_key'},
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'glm',
      displayName: 'Zhipu GLM API',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'api_key'},
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'glm-cn',
      displayName: 'GLM Coding (China)',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'api_key'},
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'deepseek',
      displayName: 'DeepSeek API',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'api_key'},
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'minimax',
      displayName: 'MiniMax API',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'api_key'},
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'minimax-cn',
      displayName: 'MiniMax (China)',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'api_key'},
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'qwen',
      displayName: 'Qwen Cloud API',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'api_key'},
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'qwen-cloud',
      displayName: 'Qwen Cloud',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'api_key'},
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'qwen-cloud-token-plan',
      displayName: 'Qwen Cloud Token Plan',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'api_key'},
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'bedrock',
      displayName: 'AWS Bedrock',
      protocol: LlmNativeProtocol.bedrockConverse,
      authTypes: {'aws_credentials', 'aws_credential_chain', 'api_key'},
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'gemini-interactions',
      displayName: 'Google Gemini Interactions',
      protocol: LlmNativeProtocol.geminiInteractions,
      authTypes: {'api_key'},
      modelCatalog: kPinnedGeminiModels,
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'ollama',
      displayName: 'Ollama',
      protocol: LlmNativeProtocol.ollamaChat,
      authTypes: {'none', 'api_key'},
    ),
    LlmConnectorDefinition(
      id: 'aistudio',
      displayName: 'Google AI Studio',
      protocol: LlmNativeProtocol.geminiGenerateContent,
      authTypes: {'api_key', 'oauth'},
      modelCatalog: kPinnedAistudioModels,
      canRefreshCredentials: true,
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'vertex',
      displayName: 'Google Vertex AI',
      protocol: LlmNativeProtocol.vertexGenerateContent,
      authTypes: {'service_account', 'api_key'},
      modelCatalog: kPinnedVertexModels,
      canRefreshCredentials: true,
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'aihorde',
      displayName: 'AI Horde',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'none', 'api_key'},
    ),
    LlmConnectorDefinition(
      id: 'uncloseai',
      displayName: 'UncloseAI',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'none', 'api_key'},
      modelCatalog: [_uncloseAiChatModelId],
    ),
    LlmConnectorDefinition(
      id: 'openai-compatibility',
      displayName: 'OpenAI-compatible endpoint',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'api_key', 'none'},
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
  ];

  static LlmConnectorDefinition? find(String id) {
    final normalized = switch (id.trim().toLowerCase()) {
      'anthropic' => 'claude',
      'openai' => 'openai-compatibility',
      'cf' => 'cloudflare-ai',
      final value => value,
    };
    for (final connector in all) {
      if (connector.id == normalized) return connector;
    }
    return null;
  }

  /// M1 migrated legacy provider names before M2's provider registry existed.
  /// Keep those records routable while preserving their account IDs and refs.
  static String canonicalId(String id) => switch (id.trim()) {
        'anthropic' => 'claude',
        'clova' => 'clova-studio',
        'openai' => 'openai-compatibility',
        'cf' => 'cloudflare-ai',
        'glmt' => 'glm',
        final normalized => normalized,
      };

  static String? chatAdapterEndpointType(String connectorType) =>
      switch (canonicalId(connectorType)) {
        'codex' => 'openai',
        'clova-studio' => 'clova.studio.chat',
        'amazon-q' => 'amazon-q.chat',
        'xai' ||
        'grok-cli' ||
        'xai-oauth' ||
        'openference' ||
        'openference-api' ||
        'cline' ||
        'clinepass' ||
        'meta' ||
        'muse-code' ||
        'codebuddy-cn' ||
        'codebuddy-intl' ||
        'workbuddy' ||
        'github' ||
        'ghe-copilot' ||
        'azure-ai' ||
        'azure-openai' ||
        'gitlab-duo' ||
        'zed-hosted' ||
        'qoder' ||
        'kilocode' =>
          'openai',
        'claude' => 'anthropic',
        'gemini' => 'google.gemini.generate_content',
        'aistudio' => 'google.gemini.generate_content',
        'gemini-interactions' => 'google.gemini.interactions',
        'vertex' => 'google.gemini.generate_content',
        'ollama' => 'ollama.chat',
        'devin' => 'devin.connect_rpc',
        'devin-cli-agentic' => 'devin.acp',
        'cursor' => 'cursor.agent_connect_rpc',
        'trae' => 'openai',
        'bedrock' => 'openai',
        'openai-compatibility' ||
        'openai-api' ||
        'cloudflare-ai' ||
        'azure-ai' ||
        'azure-openai' ||
        'opencode-go' ||
        'opencode-zen' ||
        'aihorde' ||
        'uncloseai' ||
        'command-code' ||
        'moonshot' ||
        'kimi-coding' ||
        'glm' ||
        'deepseek' ||
        'minimax' ||
        'qwen' ||
        'glm-cn' ||
        'minimax-cn' ||
        'qwen-cloud' ||
        'qwen-cloud-token-plan' ||
        'kimi' ||
        'kimi-ai' ||
        'kimi.ai' =>
          'openai',
        _ => null,
      };

  /// Codex's ChatAdapter route is specifically its OAuth Responses contract.
  /// Legacy/API-key Codex records remain manageable but use the dedicated
  /// OpenAI API or OpenAI-compatible connector path instead.
  static bool isChatAdapterAuthTypeSupported(
    String connectorType,
    String authType,
  ) {
    final connector = find(connectorType);
    if (connector == null || !connector.authTypes.contains(authType)) {
      return false;
    }
    return switch (canonicalId(connectorType)) {
      'codex' => authType == 'oauth',
      'xai' || 'meta' => authType == 'api_key',
      'muse-code' => authType == 'oauth',
      'grok-cli' || 'xai-oauth' => authType == 'oauth',
      'devin-cli-agentic' => authType == 'cli_session',
      'cursor' => {'oauth', 'api_key'}.contains(authType),
      'qoder' => {'api_key', 'oauth', 'pat'}.contains(authType),
      _ => true,
    };
  }
}

/// Result of a capability observation. Unknown quota is represented by a
/// null value and is never converted into an available or unlimited balance.
class LlmConnectorObservation {
  final LlmMetricObservation requestUsage;
  final LlmMetricObservation remainingQuota;
  final Map<String, LlmMetricObservation> quotaSignals;

  LlmConnectorObservation({
    this.requestUsage = const LlmMetricObservation.unknown(),
    this.remainingQuota = const LlmMetricObservation.unknown(),
    Map<String, LlmMetricObservation> quotaSignals = const {},
  }) : quotaSignals = Map.unmodifiable(quotaSignals);
}

/// Owns CRUD for M1 account records and their secure credential references.
/// Credentials are committed to secure storage before ordinary preferences are
/// updated. Mutations share the M1 transaction lease with migration and backup.
class LlmAccountConnectorService {
  static const _maxModelDiscoveryPages = 100;

  final LlmAccountPreferences preferences;
  final LlmCredentialStore credentialStore;
  final Dio _dio;
  final QoderCliService? _qoderCliOverride;
  late final QoderCliService _qoderCli =
      _qoderCliOverride ?? QoderCliService(readCredential: readCredential);

  LlmAccountConnectorService({
    required this.preferences,
    required this.credentialStore,
    Dio? dio,
    QoderCliService? qoderCliService,
  })  : _qoderCliOverride = qoderCliService,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  Future<List<LlmAccount>> listAccounts() async {
    final lease =
        await LlmAccountMigrationService.acquireCredentialTransaction();
    try {
      final records = await _readAccounts();
      final accounts = records.map(LlmAccount.fromMap).toList();
      for (var index = 0; index < accounts.length; index++) {
        final account = accounts[index];
        if (account.connectorType != 'qoder' ||
            account.authType != 'oauth' ||
            account.status == LlmAccountStatus.paused ||
            account.status == LlmAccountStatus.needsAttention ||
            !await _qoderOAuthNeedsReauthorization(account)) {
          continue;
        }
        accounts[index] = LlmAccount(
          id: account.id,
          connectorType: account.connectorType,
          authType: account.authType,
          displayName: account.displayName,
          status: LlmAccountStatus.needsAttention,
          credentialRef: account.credentialRef,
          endpointConfig: account.endpointConfig,
          models: account.models,
          policy: account.policy,
          usageByWindow: account.usageByWindow,
          remainingQuota: account.remainingQuota,
          quotaSignals: account.quotaSignals,
        );
      }
      return accounts;
    } on LlmAccountConnectorException {
      rethrow;
    } catch (_) {
      throw const LlmAccountConnectorException();
    } finally {
      lease.release();
    }
  }

  Future<LlmAccount?> getAccount(String accountId) async {
    final accounts = await listAccounts();
    for (final account in accounts) {
      if (account.id == accountId) return account;
    }
    return null;
  }

  Future<bool> _qoderOAuthNeedsReauthorization(LlmAccount account) async {
    final reference = account.credentialRef;
    if (reference == null) return true;
    final secret = await _readSecureValue(reference);
    if (secret == null || secret.trim().isEmpty) return true;
    final bundle = _decodeCredentialBundle(secret);
    if (LlmNativeRequestBuilder._credentialBundleString(secret, const [
              'access_token',
              'accessToken',
            ]) ==
            null ||
        LlmNativeRequestBuilder._credentialBundleString(secret, const [
              'api_key',
              'apiKey',
            ]) ==
            null) {
      return true;
    }
    final expiryValue = bundle['expires_at'] ?? bundle['expired'];
    if (expiryValue == null) return false;
    final expiry = expiryValue is String
        ? DateTime.tryParse(expiryValue)
        : expiryValue is num
            ? DateTime.fromMillisecondsSinceEpoch(
                expiryValue > 100000000000
                    ? expiryValue.toInt()
                    : expiryValue.toInt() * 1000,
                isUtc: true,
              )
            : null;
    return expiry == null ||
        !expiry.isAfter(
          DateTime.now().toUtc().add(const Duration(seconds: 30)),
        );
  }

  Future<List<LlmModelGroup>> listModelGroups() async {
    final lease =
        await LlmAccountMigrationService.acquireCredentialTransaction();
    try {
      final records = await _readEnvelope(
        await preferences.getString(
          LlmAccountMigrationService.modelGroupsPreferenceKey,
        ),
      );
      return records.map(LlmModelGroup.fromMap).toList(growable: false);
    } on LlmAccountConnectorException {
      rethrow;
    } catch (_) {
      throw const LlmAccountConnectorException();
    } finally {
      lease.release();
    }
  }

  /// Imports one legacy OCR model and its stable group as a single transaction.
  /// Existing account settings remain authoritative unless the legacy OCR
  /// editor explicitly marks one of its changed source fields for syncing.
  Future<void> ensureLegacyOcrModelGroup({
    required String accountId,
    required String sourceConfigId,
    required String groupId,
    required String localModelId,
    required String upstreamModelId,
    required String displayName,
    required String baseUrl,
    required String apiKey,
    bool synchronizeEndpoint = false,
    bool synchronizeCredential = false,
    bool synchronizeModel = false,
  }) async {
    final lease =
        await LlmAccountMigrationService.acquireCredentialTransaction();
    const accountsKey = LlmAccountMigrationService.accountsPreferenceKey;
    const groupsKey = LlmAccountMigrationService.modelGroupsPreferenceKey;
    String? previousAccounts;
    String? previousGroups;
    String? credentialReference;
    String? credentialToDelete;
    String? previousCredential;
    var credentialWriteAttempted = false;
    var accountsWriteAttempted = false;
    var groupsWriteAttempted = false;
    try {
      if (sourceConfigId.trim().isEmpty ||
          accountId != 'ocr-$sourceConfigId' ||
          groupId != _modelGroupId(accountId, localModelId) ||
          localModelId.trim().isEmpty ||
          upstreamModelId.trim().isEmpty ||
          displayName.trim().isEmpty ||
          baseUrl.trim().isEmpty ||
          (apiKey.isNotEmpty && apiKey.trim().isEmpty)) {
        throw const LlmAccountConnectorException();
      }

      previousAccounts = await preferences.getString(accountsKey);
      previousGroups = await preferences.getString(groupsKey);
      final accountRecords = await _readAccounts();
      final groupRecords = await _readEnvelope(previousGroups);
      final accountIndex = accountRecords.indexWhere(
        (record) => record['id'] == accountId,
      );
      final previousRecord =
          accountIndex < 0 ? null : accountRecords[accountIndex];
      final existing =
          previousRecord == null ? null : LlmAccount.fromMap(previousRecord);
      if (existing != null &&
          existing.endpointConfig['legacyOcrProviderConfigId'] !=
              sourceConfigId) {
        throw const LlmAccountConnectorException();
      }

      final existingModel = existing?.models
          .where((model) => model.id == localModelId)
          .firstOrNull;
      final refreshEndpoint = existing != null && synchronizeEndpoint;
      final refreshCredential = existing != null && synchronizeCredential;
      final refreshModel = existing != null && synchronizeModel;
      final model = existingModel == null
          ? LlmUpstreamModel(
              id: localModelId,
              upstreamModelId: upstreamModelId,
              displayName: displayName,
              capabilities: const {'vision': true},
            )
          : refreshModel
              ? LlmUpstreamModel(
                  id: existingModel.id,
                  upstreamModelId: upstreamModelId,
                  displayName: displayName,
                  capabilities: existingModel.capabilities,
                  config: existingModel.config,
                )
              : existingModel;
      final endpointConfig = <String, dynamic>{
        ...?existing?.endpointConfig,
        if (existing == null || refreshEndpoint) 'baseUrl': baseUrl.trim(),
        'legacyOcrProviderConfigId': sourceConfigId,
        if (existing == null || refreshEndpoint) 'legacyOcrFullEndpoint': true,
      };
      final models = existingModel == null
          ? [...?existing?.models, model]
          : refreshModel
              ? [
                  for (final existingModel in existing.models)
                    existingModel.id == localModelId ? model : existingModel,
                ]
              : existing!.models;
      var authType =
          existing?.authType ?? (apiKey.isEmpty ? 'none' : 'api_key');
      String? effectiveCredentialReference = existing?.credentialRef;
      if (existing == null && apiKey.isNotEmpty) {
        final newReference = _newCredentialReference(accountId);
        credentialReference = newReference;
        if (accountRecords.any(
          (record) => record['credentialRef'] == newReference,
        )) {
          throw const LlmAccountConnectorException();
        }
        effectiveCredentialReference = newReference;
        authType = 'api_key';
        previousCredential = await credentialStore.read(newReference);
      } else if (refreshCredential) {
        if (apiKey.isEmpty) {
          authType = 'none';
          final previousReference = existing.credentialRef;
          if (previousReference != null &&
              !accountRecords.any(
                (record) =>
                    record['id'] != accountId &&
                    record['credentialRef'] == previousReference,
              )) {
            credentialToDelete = previousReference;
            previousCredential = await credentialStore.read(previousReference);
          }
          effectiveCredentialReference = null;
        } else {
          authType = 'api_key';
          effectiveCredentialReference ??= _newCredentialReference(accountId);
          final currentCredentialReference = effectiveCredentialReference;
          final currentCredential = await credentialStore.read(
            currentCredentialReference,
          );
          final isSharedCredential = accountRecords.any(
            (record) =>
                record['id'] != accountId &&
                record['credentialRef'] == currentCredentialReference,
          );
          if (isSharedCredential && currentCredential != apiKey) {
            effectiveCredentialReference = _newCredentialReference(accountId);
          }
          if (accountRecords.any(
            (record) =>
                record['id'] != accountId &&
                record['credentialRef'] == effectiveCredentialReference,
          )) {
            throw const LlmAccountConnectorException();
          }
          credentialReference = effectiveCredentialReference;
          previousCredential = await credentialStore.read(
            effectiveCredentialReference,
          );
          if (previousCredential != apiKey) {
            credentialWriteAttempted = true;
            await credentialStore.write(effectiveCredentialReference, apiKey);
            if (await credentialStore.read(effectiveCredentialReference) !=
                apiKey) {
              throw const LlmAccountConnectorException();
            }
          }
        }
      }

      final connectionIdentityChanged = existing != null &&
          (existing.authType != authType ||
              (refreshEndpoint &&
                  existing.endpointConfig['baseUrl'] != baseUrl.trim()) ||
              (refreshCredential && previousCredential != apiKey));

      var account = LlmAccount(
        id: accountId,
        connectorType: existing?.connectorType ?? 'openai-compatibility',
        authType: authType,
        displayName: existing?.displayName ?? displayName,
        status: existing?.status ?? LlmAccountStatus.unknown,
        credentialRef: effectiveCredentialReference,
        endpointConfig: endpointConfig,
        models: models,
        policy: existing?.policy,
        usageByWindow:
            connectionIdentityChanged ? const {} : existing?.usageByWindow,
        remainingQuota: connectionIdentityChanged
            ? const LlmMetricObservation.unknown()
            : existing?.remainingQuota ?? const LlmMetricObservation.unknown(),
        quotaSignals: connectionIdentityChanged
            ? const {}
            : existing?.quotaSignals ?? const {},
      );

      if (existing == null && apiKey.isNotEmpty) {
        _validateCredential(account, apiKey);
        final reference = effectiveCredentialReference!;
        credentialWriteAttempted = true;
        await credentialStore.write(reference, apiKey);
        if (await credentialStore.read(reference) != apiKey) {
          throw const LlmAccountConnectorException();
        }
      }

      account = _canonicalAccount(account);
      _validateAccount(account);
      final accountRecord = <String, dynamic>{
        ...?previousRecord,
        ...account.toMap(),
      };
      if (account.credentialRef == null) {
        accountRecord.remove('credentialRef');
      }
      final accountChanged = existing == null ||
          jsonEncode(existing.toMap()) != jsonEncode(account.toMap());
      if (accountChanged) {
        if (accountIndex < 0) {
          accountRecords.add(accountRecord);
        } else {
          accountRecords[accountIndex] = accountRecord;
        }
      }

      final groupIndex = groupRecords.indexWhere(
        (record) => record['id'] == groupId,
      );
      final previousGroupRecord =
          groupIndex < 0 ? null : groupRecords[groupIndex];
      final existingGroup = previousGroupRecord == null
          ? null
          : LlmModelGroup.fromMap(previousGroupRecord);
      final hasMember = existingGroup?.members.any(
            (member) =>
                member.accountId == accountId &&
                member.localModelId == localModelId,
          ) ??
          false;
      final group = LlmModelGroup(
        id: groupId,
        displayName: refreshModel
            ? displayName
            : existingGroup?.displayName ?? displayName,
        members: [
          for (final member in existingGroup?.members ?? const [])
            if (member.accountId == accountId &&
                member.localModelId == localModelId)
              LlmModelGroupMember(
                accountId: member.accountId,
                upstreamModelId: refreshModel
                    ? model.upstreamModelId
                    : member.upstreamModelId,
                priorityTier: member.priorityTier,
                localModelId: member.localModelId,
              )
            else
              member,
          if (!hasMember)
            LlmModelGroupMember(
              accountId: accountId,
              localModelId: localModelId,
              upstreamModelId: model.upstreamModelId,
            ),
        ],
        policy: existingGroup?.policy,
        legacyModelId: refreshModel
            ? model.upstreamModelId
            : existingGroup?.legacyModelId ?? upstreamModelId,
        legacyProviderName: existingGroup?.legacyProviderName,
      );
      _validateModelGroupIdentity(group);
      final accountsById = {
        for (final record in accountRecords)
          if (record['id'] is String)
            record['id'] as String: LlmAccount.fromMap(record),
      };
      _validateModelGroupMembers(group, accountsById);
      final groupRecord = group.toMap();
      final groupChanged = existingGroup == null ||
          jsonEncode(existingGroup.toMap()) != jsonEncode(groupRecord);
      if (groupChanged) {
        if (groupIndex < 0) {
          groupRecords.add(groupRecord);
        } else {
          groupRecords[groupIndex] = groupRecord;
        }
      }

      if (accountChanged) {
        final encoded = _encodeEnvelope(accountRecords);
        accountsWriteAttempted = true;
        if (!await preferences.setString(accountsKey, encoded) ||
            await preferences.getString(accountsKey) != encoded) {
          throw const LlmAccountConnectorException();
        }
      }
      if (groupChanged) {
        final encoded = _encodeEnvelope(groupRecords);
        groupsWriteAttempted = true;
        if (!await preferences.setString(groupsKey, encoded) ||
            await preferences.getString(groupsKey) != encoded) {
          throw const LlmAccountConnectorException();
        }
      }
      if (credentialToDelete != null) {
        credentialWriteAttempted = true;
        await credentialStore.delete(credentialToDelete);
        if (await credentialStore.read(credentialToDelete) != null) {
          throw const LlmAccountConnectorException();
        }
      }
    } catch (_) {
      if (groupsWriteAttempted) {
        await _restorePreference(groupsKey, previousGroups);
      }
      if (accountsWriteAttempted) {
        await _restorePreference(accountsKey, previousAccounts);
      }
      if (credentialWriteAttempted) {
        final restoreReference = credentialReference ?? credentialToDelete;
        if (restoreReference != null) {
          await _restoreCredential(restoreReference, previousCredential);
        }
      }
      throw const LlmAccountConnectorException();
    } finally {
      lease.release();
    }
  }

  /// Removes models imported from a legacy OCR provider after their source
  /// config no longer contains them. Saving through [saveAccount] also removes
  /// their group members while preserving stable group identity for older
  /// conversation references.
  Future<void> synchronizeLegacyOcrModelSet({
    required String accountId,
    required String sourceConfigId,
    required Set<String> localModelIds,
  }) async {
    if (accountId != 'ocr-$sourceConfigId') {
      throw const LlmAccountConnectorException();
    }
    final account = await getAccount(accountId);
    if (account == null) return;
    if (account.endpointConfig['legacyOcrProviderConfigId'] != sourceConfigId) {
      throw const LlmAccountConnectorException();
    }
    final retainedModelIds = localModelIds.map((id) => id.trim()).toSet();
    final models = account.models
        .where((model) => retainedModelIds.contains(model.id))
        .toList(growable: false);
    if (models.length == account.models.length) return;
    await saveAccount(
      LlmAccount(
        id: account.id,
        connectorType: account.connectorType,
        authType: account.authType,
        displayName: account.displayName,
        status: account.status,
        credentialRef: account.credentialRef,
        endpointConfig: account.endpointConfig,
        models: models,
        policy: account.policy,
        usageByWindow: account.usageByWindow,
        remainingQuota: account.remainingQuota,
        quotaSignals: account.quotaSignals,
      ),
    );
  }

  /// Saves one stable model group after validating every account/model mapping.
  /// Local model IDs are aliases resolved by ChatAdapter and may intentionally
  /// differ from an account's own model-record ID.
  Future<LlmModelGroup> saveModelGroup(LlmModelGroup group) async {
    final lease =
        await LlmAccountMigrationService.acquireCredentialTransaction();
    final key = LlmAccountMigrationService.modelGroupsPreferenceKey;
    String? previous;
    var writeAttempted = false;
    try {
      _validateModelGroupIdentity(group);
      previous = await preferences.getString(key);
      final groupRecords = await _readEnvelope(previous);
      final accountRecords = await _readAccounts();
      final accounts = {
        for (final record in accountRecords)
          if (record['id'] is String)
            record['id'] as String: LlmAccount.fromMap(record),
      };
      _validateModelGroupMembers(group, accounts);

      final index = groupRecords.indexWhere(
        (record) => record['id'] == group.id,
      );
      final saved = group.toMap();
      if (index < 0) {
        groupRecords.add(saved);
      } else {
        groupRecords[index] = saved;
      }
      final encoded = _encodeEnvelope(groupRecords);
      writeAttempted = true;
      if (!await preferences.setString(key, encoded) ||
          await preferences.getString(key) != encoded) {
        throw const LlmAccountConnectorException();
      }
      return LlmModelGroup.fromMap(saved);
    } catch (_) {
      if (writeAttempted) await _restorePreference(key, previous);
      throw const LlmAccountConnectorException();
    } finally {
      lease.release();
    }
  }

  Future<void> deleteModelGroup(String groupId) async {
    final lease =
        await LlmAccountMigrationService.acquireCredentialTransaction();
    final key = LlmAccountMigrationService.modelGroupsPreferenceKey;
    String? previous;
    var writeAttempted = false;
    try {
      if (groupId.trim().isEmpty) {
        throw const LlmAccountConnectorException();
      }
      previous = await preferences.getString(key);
      final records = await _readEnvelope(previous);
      final updated =
          records.where((record) => record['id'] != groupId).toList();
      if (updated.length == records.length) return;
      final encoded = _encodeEnvelope(updated);
      writeAttempted = true;
      if (!await preferences.setString(key, encoded) ||
          await preferences.getString(key) != encoded) {
        throw const LlmAccountConnectorException();
      }
    } catch (_) {
      if (writeAttempted) await _restorePreference(key, previous);
      throw const LlmAccountConnectorException();
    } finally {
      lease.release();
    }
  }

  static void _validateModelGroupIdentity(LlmModelGroup group) {
    // M1 stable IDs URI-encode arbitrary account/model identities and can be
    // longer than custom UUID-based group IDs.
    final validId = RegExp(r'^[^\s\x00-\x1f\x7f]{1,1024}$');
    if (!validId.hasMatch(group.id) || group.displayName.trim().isEmpty) {
      throw const LlmAccountConnectorException();
    }
  }

  bool _synchronizeGroupModelMappingsForAccount({
    required LlmAccount previous,
    required LlmAccount updated,
    required List<Map<String, dynamic>> groups,
  }) {
    final updatedById = {for (final model in updated.models) model.id: model};
    var changed = false;
    for (final group in groups) {
      final rawMembers = group['members'];
      if (rawMembers is! List) continue;
      final nextMembers = <dynamic>[];
      var groupChanged = false;
      String? removedStableLocalModelId;
      LlmUpstreamModel? removedStableModel;
      for (final rawMember in rawMembers) {
        if (rawMember is! Map || rawMember['accountId'] != updated.id) {
          nextMembers.add(rawMember);
          continue;
        }
        final upstreamModelId = rawMember['upstreamModelId'];
        if (upstreamModelId is! String) {
          nextMembers.add(rawMember);
          continue;
        }
        final candidates = previous.models
            .where((model) => model.upstreamModelId == upstreamModelId)
            .toList(growable: false);
        if (candidates.isEmpty) {
          nextMembers.add(rawMember);
          continue;
        }
        final localModelId = rawMember['localModelId'];
        final localMatch = localModelId is String
            ? candidates.where((model) => model.id == localModelId).firstOrNull
            : null;
        if (localMatch == null && candidates.length != 1) {
          if (updated.models.any(
            (model) => model.upstreamModelId == upstreamModelId,
          )) {
            nextMembers.add(rawMember);
            continue;
          }
          throw const LlmAccountConnectorException();
        }

        final previousModel = localMatch ?? candidates.single;
        final updatedModel = updatedById[previousModel.id];
        if (updatedModel == null) {
          if (updated.models.any(
            (model) => model.upstreamModelId == upstreamModelId,
          )) {
            nextMembers.add(rawMember);
          } else {
            if (group['id'] == _modelGroupId(updated.id, previousModel.id)) {
              removedStableLocalModelId = previousModel.id;
              removedStableModel = previousModel;
            }
            groupChanged = true;
          }
          continue;
        }
        if (updatedModel.upstreamModelId == upstreamModelId) {
          nextMembers.add(rawMember);
          continue;
        }
        nextMembers.add({
          ...Map<String, dynamic>.from(rawMember),
          'upstreamModelId': updatedModel.upstreamModelId,
        });
        groupChanged = true;
      }
      if (removedStableLocalModelId != null && removedStableModel != null) {
        if (group['legacyProviderName'] == null &&
            previous.displayName.isNotEmpty) {
          group['legacyProviderName'] = previous.displayName;
          groupChanged = true;
        }
        if (group['legacyModelId'] == null &&
            removedStableModel.upstreamModelId.isNotEmpty) {
          group['legacyModelId'] = removedStableModel.upstreamModelId;
          groupChanged = true;
        }
        final hasLegacyAlias = nextMembers.any(
          (member) =>
              member is Map &&
              member['localModelId'] == removedStableLocalModelId,
        );
        final survivingMember = nextMembers.whereType<Map>().firstOrNull;
        if (!hasLegacyAlias && survivingMember != null) {
          nextMembers.add({
            ...Map<String, dynamic>.from(survivingMember),
            'localModelId': removedStableLocalModelId,
          });
          groupChanged = true;
        }
      }
      if (groupChanged) {
        group['members'] = nextMembers;
        changed = true;
      }
    }
    return changed;
  }

  static void _validateModelGroupMembers(
    LlmModelGroup group,
    Map<String, LlmAccount> accounts,
  ) {
    final seenMappings = <String>{};
    final endpointByLocalModel = <String, String>{};
    for (final member in group.members) {
      final account = accounts[member.accountId];
      if (account == null ||
          member.upstreamModelId.trim().isEmpty ||
          (member.localModelId != null &&
              member.localModelId!.trim().isEmpty)) {
        throw const LlmAccountConnectorException();
      }
      final mappingId =
          '${member.accountId}\u0000${member.localModelId ?? group.id}';
      final localModelId = member.localModelId ?? group.id;
      final endpointType = LlmConnectorRegistry.chatAdapterEndpointType(
        account.connectorType,
      );
      final existingEndpoint = endpointByLocalModel[localModelId];
      if (!seenMappings.add(mappingId) ||
          (endpointType != null &&
              existingEndpoint != null &&
              existingEndpoint != endpointType) ||
          !account.models.any(
            (model) => model.upstreamModelId == member.upstreamModelId,
          )) {
        throw const LlmAccountConnectorException();
      }
      if (endpointType != null) {
        endpointByLocalModel[localModelId] = endpointType;
      }
    }
  }

  Future<String?> readCredential(String accountId) async {
    final account = await getAccount(accountId);
    final reference = account?.credentialRef;
    if (reference == null) return null;
    try {
      return await credentialStore.read(reference);
    } catch (_) {
      throw const LlmAccountConnectorException();
    }
  }

  /// Returns the persisted model mapping when present, otherwise the pinned
  /// upstream catalog. OpenAI-compatible endpoints and Gemini API keys can
  /// query their native model-list endpoint when [refreshRemote] is true.
  Future<List<LlmUpstreamModel>> discoverModels(
    LlmAccount account, {
    bool refreshRemote = false,
  }) async {
    account = _canonicalAccount(account);
    final savedAccount = await getAccount(account.id);
    if (savedAccount != null) {
      if (LlmConnectorRegistry.canonicalId(savedAccount.connectorType) !=
          account.connectorType) {
        throw const LlmAccountConnectorException();
      }
      account = savedAccount;
    }
    final connector = LlmConnectorRegistry.find(account.connectorType);
    if (connector == null || connector.id != account.connectorType) {
      throw const LlmAccountConnectorException();
    }
    if (account.connectorType == 'vertex' && account.authType == 'oauth') {
      throw const LlmAccountConnectorException();
    }
    if (account.connectorType == 'azure-ai' ||
        account.connectorType == 'azure-openai') {
      final deploymentId = LlmNativeRequestBuilder._configString(
        account.endpointConfig,
        'azureDeploymentId',
      );
      final baseUrl = LlmNativeRequestBuilder._configString(
        account.endpointConfig,
        'baseUrl',
      );
      final apiVersion = LlmNativeRequestBuilder._configString(
            account.endpointConfig,
            'apiVersion',
          ) ??
          AzureOpenAiEndpoint.defaultApiVersion;
      if (deploymentId == null || baseUrl == null) {
        throw const LlmAccountConnectorException();
      }
      try {
        AzureOpenAiEndpoint.chatCompletionsUri(
          resourceUrl: baseUrl,
          deploymentId: deploymentId,
          apiVersion: apiVersion,
        );
      } on FormatException {
        throw const LlmAccountConnectorException();
      }
      final configuredModel = LlmUpstreamModel(
        id: '${account.id}:azure-deployment:${Uri.encodeComponent(deploymentId)}',
        upstreamModelId: deploymentId,
        displayName: deploymentId,
        capabilities: const {
          'chat': true,
          'streaming': true,
          'supportedApiProtocols': ['openai.chat_completions'],
        },
        config: const {'catalogSource': 'configured-azure-deployment'},
      );
      return List.unmodifiable(
        _mergeModelMappings([configuredModel], account.models),
      );
    }
    if (account.connectorType == 'uncloseai' && !refreshRemote) {
      if (account.models.isNotEmpty) return List.unmodifiable(account.models);
      final modelId = connector.modelCatalog.single;
      return [
        LlmUpstreamModel(
          id: '${account.id}:catalog:0',
          upstreamModelId: modelId,
          displayName: 'Qwen3.8 27B exl3 (Free)',
          capabilities: const {
            'chat': true,
            'streaming': true,
            'contextLength': _uncloseAiDefaultContextLength,
            'supportedApiProtocols': ['openai.chat_completions'],
          },
          config: const {
            'catalogSource':
                'pinned_provider_registry@$kLlmConnectorReferenceRevision',
          },
        ),
      ];
    }
    if (account.connectorType == 'cloudflare-ai') {
      final accountId = account.endpointConfig['cloudflareAccountId'];
      if (account.authType != 'api_key' || accountId is! String) {
        throw const LlmAccountConnectorException();
      }
      try {
        CloudflareWorkersAiConnector.buildChatCompletionsUri(accountId);
      } on ArgumentError {
        throw const LlmAccountConnectorException();
      }
      return List.unmodifiable(
        cloudflareWorkersAiModelCatalog(account.id),
      );
    }
    if (account.connectorType == 'amazon-q') {
      if (account.authType != 'oauth' || account.credentialRef == null) {
        throw const LlmAccountConnectorException();
      }
      final rawSecret = await _readSecureValue(account.credentialRef!);
      if (rawSecret == null || rawSecret.isEmpty) {
        throw const LlmAccountConnectorException();
      }
      final credential = _decodeCredentialBundle(rawSecret);
      var token = _firstString(credential, const [
        'access_token',
        'accessToken',
      ]);
      if (token == null && await refreshCredential(account)) {
        final refreshed = await readCredential(account.id);
        token = _firstString(_decodeCredentialBundle(refreshed ?? ''), const [
          'access_token',
          'accessToken',
        ]);
      }
      if (token == null) throw const LlmAccountConnectorException();
      final region = _amazonQRegion(account, credential);
      Future<Response<Object?>> fetchModels() => _dio.getUri<Object?>(
            AmazonQConnector.modelsUri(region),
            options: Options(
              headers: {'Authorization': 'Bearer $token'},
              followRedirects: false,
              validateStatus: (status) => status != null,
            ),
          );
      var response = await fetchModels();
      if (response.statusCode == 401 && await refreshCredential(account)) {
        final refreshed = await readCredential(account.id);
        if (refreshed == null) throw const LlmAccountConnectorException();
        token = _firstString(_decodeCredentialBundle(refreshed), const [
          'access_token',
          'accessToken',
        ]);
        if (token == null) throw const LlmAccountConnectorException();
        response = await fetchModels();
      }
      if ((response.statusCode ?? 0) < 200 ||
          (response.statusCode ?? 0) >= 300) {
        throw const LlmAccountConnectorException();
      }
      final discovered = AmazonQConnector.parseModels(response.data)
          .map(
            (model) => LlmUpstreamModel(
              id: '${account.id}:amazon-q:${model.upstreamModelId}',
              upstreamModelId: model.upstreamModelId,
              displayName: model.displayName,
              capabilities: model.capabilities,
              config: model.config,
            ),
          )
          .toList();
      return _mergeModelMappings(discovered, account.models);
    }
    final hasRemoteCatalog = {
      'aihorde',
      'uncloseai',
      'openai-compatibility',
      'openai-api',
      'opencode-go',
      'opencode-zen',
      'command-code',
      if (account.connectorType == 'claude' && account.authType == 'api_key')
        'claude',
      'gemini',
      'aistudio',
      'gemini-interactions',
      'moonshot',
      'glm',
      'glm-cn',
      'deepseek',
      'minimax',
      'minimax-cn',
      'qwen',
      'qwen-cloud',
      'qwen-cloud-token-plan',
      'grok-cli',
      'xai-oauth',
      'muse-code',
      'workbuddy',
      'github',
      'ghe-copilot',
      'zed-hosted',
      'kilocode',
      'openference',
      'openference-api',
      'cline',
      'clinepass',
      'bedrock',
      'vertex',
      'ollama',
      'trae',
    }.contains(account.connectorType);
    if (hasRemoteCatalog && savedAccount == null) {
      throw const LlmAccountConnectorException();
    }
    final accountEntitlementCatalog = account.connectorType == 'github' ||
        account.connectorType == 'ghe-copilot' ||
        account.connectorType == 'zed-hosted' ||
        account.connectorType == 'grok-cli' ||
        account.connectorType == 'xai-oauth' ||
        account.connectorType == 'trae';
    if (account.connectorType == 'qoder' &&
        account.authType == 'pat' &&
        refreshRemote) {
      final token = await readCredential(account.id);
      if (token == null || !token.startsWith('pt-')) {
        throw const LlmAccountConnectorException();
      }
      final discoveredIds = await _qoderCli.listModels(token: token);
      final discovered = [
        for (final (index, modelId) in discoveredIds.indexed)
          LlmUpstreamModel(
            id: '${account.id}:qoder-cli:$index',
            upstreamModelId: modelId,
            displayName: modelId,
            capabilities: const {'chat': true, 'streaming': true},
            config: const {'catalogSource': 'qodercli'},
          ),
      ];
      return _mergeModelMappings(discovered, account.models);
    }
    if (account.connectorType == 'muse-code' &&
        account.models.isNotEmpty &&
        !refreshRemote) {
      return List.unmodifiable(
        account.models.where(
          (model) => connector.modelCatalog.contains(model.upstreamModelId),
        ),
      );
    }
    if (account.connectorType == 'kilocode' && account.authType == 'none') {
      if (account.models.isNotEmpty && !refreshRemote) {
        return List.unmodifiable(
          account.models.where(
            (model) =>
                kKiloCodeAnonymousFreeModelIds.contains(model.upstreamModelId),
          ),
        );
      }
      final discovered = await _discoverRemoteModels(account);
      return List.unmodifiable(
        discovered.where(
          (model) =>
              kKiloCodeAnonymousFreeModelIds.contains(model.upstreamModelId),
        ),
      );
    }
    if (account.models.isNotEmpty &&
        (!refreshRemote || !hasRemoteCatalog) &&
        !accountEntitlementCatalog) {
      return List.unmodifiable(account.models);
    }
    if (hasRemoteCatalog) {
      if (account.authType == 'oauth' &&
          !LlmOAuthProviderPolicy.forProvider(
            account.connectorType,
          ).supported) {
        throw const LlmAccountConnectorException();
      }
      late final List<LlmUpstreamModel> discovered;
      try {
        discovered = await _discoverRemoteModels(account);
      } catch (_) {
        if (account.connectorType == 'cline' ||
            account.connectorType == 'clinepass') {
          final catalog = account.connectorType == 'cline'
              ? kPinnedClineModels
              : kPinnedClinePassModels;
          return _mergeFallbackModelMappings([
            for (final (index, modelId) in catalog.indexed)
              LlmUpstreamModel(
                id: '${account.id}:cline-fallback:$index',
                upstreamModelId: modelId,
                displayName: modelId,
                capabilities: const {'chat': true, 'streaming': true},
                config: const {
                  'catalogSource': 'provider-fallback',
                  'availability': 'unknown',
                },
              ),
          ], account.models);
        }
        if (!{
          'openference',
          'openference-api',
        }.contains(account.connectorType)) {
          rethrow;
        }
        return _mergeFallbackModelMappings([
          for (var index = 0; index < connector.modelCatalog.length; index++)
            LlmUpstreamModel(
              id: '${account.id}:openference-fallback:$index',
              upstreamModelId: connector.modelCatalog[index],
              displayName: connector.modelCatalog[index],
              capabilities: const {'chat': true, 'streaming': true},
              config: const {
                'catalogSource': 'provider-fallback',
                'availability': 'unknown',
              },
            ),
        ], account.models);
      }
      if (account.connectorType == 'grok-cli' ||
          account.connectorType == 'xai-oauth') {
        final entitledIds =
            discovered.map((model) => model.upstreamModelId).toSet();
        return _mergeModelMappings(
          discovered,
          account.models
              .where((model) => entitledIds.contains(model.upstreamModelId))
              .toList(),
        );
      }
      if (account.connectorType == 'command-code') {
        return _mergeCommandCodeModelMappings(discovered, account.models);
      }
      if (account.connectorType == 'muse-code') {
        final entitledIds =
            discovered.map((model) => model.upstreamModelId).toSet();
        return _mergeModelMappings(
          discovered,
          account.models
              .where((model) => entitledIds.contains(model.upstreamModelId))
              .toList(),
        );
      }
      if (account.connectorType == 'trae') {
        final discoveredIds =
            discovered.map((model) => model.upstreamModelId).toSet();
        return _mergeModelMappings(
          discovered,
          account.models
              .where((model) => discoveredIds.contains(model.upstreamModelId))
              .toList(),
        );
      }
      if (account.connectorType == 'github' ||
          account.connectorType == 'ghe-copilot') {
        final entitledIds =
            discovered.map((model) => model.upstreamModelId).toSet();
        return _mergeModelMappings(
          discovered,
          account.models
              .where((model) => entitledIds.contains(model.upstreamModelId))
              .toList(),
        );
      }
      if (account.connectorType == 'uncloseai') {
        return _mergeUncloseAiModelMappings(discovered, account.models);
      }
      if (account.connectorType == 'openai-compatibility' &&
          account.endpointConfig['providerPresetId'] == 'cheaperinference') {
        return _mergeCheaperInferenceModelMappings(discovered, account.models);
      }
      return _mergeModelMappings(discovered, account.models);
    }
    return List.unmodifiable([
      for (var index = 0; index < connector.modelCatalog.length; index++)
        LlmUpstreamModel(
          id: '${account.id}:catalog:$index',
          upstreamModelId: connector.modelCatalog[index],
          displayName: connector.id == 'uncloseai'
              ? 'Qwen3.8 27B exl3 (Free)'
              : connector.modelCatalog[index],
          capabilities: switch (connector.id) {
            'uncloseai' => const {
                'chat': true,
                'streaming': true,
                'contextLength': _uncloseAiDefaultContextLength,
                'supportedApiProtocols': ['openai.chat_completions'],
              },
            'devin-cli-agentic' => const {'chat': true, 'streaming': true},
            // The Cursor adapter maps Stroom's supported inline image blocks;
            // remote or unsupported image representations fail explicitly.
            'cursor' => const {'chat': true, 'streaming': true, 'vision': true},
            'clova-studio' => {
                'chat': true,
                'streaming': true,
                if (connector.modelCatalog[index] == 'HCX-005') 'vision': true,
                if (connector.modelCatalog[index] == 'HCX-007')
                  'reasoning': true,
                'contextLength': connector.modelCatalog[index] == 'HCX-DASH-002'
                    ? 32000
                    : 128000,
                'maxOutputTokens':
                    connector.modelCatalog[index] == 'HCX-007' ? 32768 : 4096,
                'supportedApiProtocols': [kClovaStudioProtocolId],
              },
            'codebuddy-cn' ||
            'codebuddy-intl' =>
              _staticTencentModelCapabilities(
                connector.id,
                connector.modelCatalog[index],
              ),
            'devin' => {
                // Stroom emits a completed SSE event for Devin's unary RPC so
                // Chat and Task Flow share the standard stream lifecycle.
                'chat': true,
                'streaming': true,
                if (!const {
                  'devin/glm-5-2',
                  'devin/glm-5-3',
                  'devin/deepseek-v4-flash',
                }.contains(connector.modelCatalog[index]))
                  'vision': true,
              },
            _ => const {},
          },
          config: switch (connector.id) {
            'devin-cli-agentic' => const {
                'catalogSource': 'devin_cli_acp_default',
              },
            'cursor' => const {
                'catalogSource': 'cursor_provider_registry',
                'imageInputSupport':
                    'Inline PNG, JPEG, GIF, or WebP data only; maximum 12 images at 1 MiB each. Remote URLs and other image representations are unsupported.',
              },
            _ => const {
                'catalogSource':
                    'pinned_provider_registry@$kLlmConnectorReferenceRevision',
              },
          },
        ),
    ]);
  }

  static List<LlmUpstreamModel> _mergeModelMappings(
    List<LlmUpstreamModel> discovered,
    List<LlmUpstreamModel> configured,
  ) {
    final merged = <String, LlmUpstreamModel>{};
    for (final model in discovered) {
      merged[model.upstreamModelId] = model;
    }
    for (final model in configured) {
      merged[model.upstreamModelId] = model;
    }
    return List.unmodifiable(merged.values);
  }

  static List<LlmUpstreamModel> _mergeCheaperInferenceModelMappings(
    List<LlmUpstreamModel> discovered,
    List<LlmUpstreamModel> configured,
  ) {
    final configuredById = {
      for (final model in configured) model.upstreamModelId: model,
    };
    LlmUpstreamModel mergeModel(
      LlmUpstreamModel model,
      LlmUpstreamModel existing,
    ) {
      final config = {...model.config, ...existing.config};
      if (existing.config['apiProtocolOverrideSource'] ==
          'provider-preset-default') {
        config
          ..remove('apiProtocolOverride')
          ..remove('apiProtocolOverrideSource');
        if (model.config['apiProtocolOverride'] is String) {
          config
            ..['apiProtocolOverride'] = model.config['apiProtocolOverride']
            ..['apiProtocolOverrideSource'] = 'provider-preset-default';
        }
      }
      return LlmUpstreamModel(
        id: existing.id,
        upstreamModelId: model.upstreamModelId,
        displayName: existing.displayName,
        capabilities: existing.capabilities,
        config: config,
      );
    }

    return List.unmodifiable([
      for (final model in discovered)
        if (configuredById[model.upstreamModelId] case final existing?)
          mergeModel(model, existing)
        else
          model,
    ]);
  }

  static List<LlmUpstreamModel> _mergeUncloseAiModelMappings(
    List<LlmUpstreamModel> discovered,
    List<LlmUpstreamModel> configured,
  ) {
    final configuredById = {
      for (final model in configured) model.upstreamModelId: model,
    };
    return List.unmodifiable([
      for (final model in discovered)
        if (configuredById[model.upstreamModelId] case final existing?)
          LlmUpstreamModel(
            id: existing.id,
            upstreamModelId: model.upstreamModelId,
            displayName: existing.displayName,
            capabilities: {
              ...model.capabilities,
              ...existing.capabilities,
              // Discovery describes the current model's limit and takes
              // precedence over the provider default and stale metadata.
              'contextLength': model.capabilities['contextLength'],
              'supportedApiProtocols': ['openai.chat_completions'],
            },
            config: {...model.config, ...existing.config},
          )
        else
          model,
    ]);
  }

  static List<LlmUpstreamModel> _mergeFallbackModelMappings(
    List<LlmUpstreamModel> fallback,
    List<LlmUpstreamModel> configured,
  ) {
    final fallbackIds = fallback.map((model) => model.upstreamModelId).toSet();
    return [
      for (final model in _mergeModelMappings(fallback, configured))
        if (fallbackIds.contains(model.upstreamModelId))
          LlmUpstreamModel(
            id: model.id,
            upstreamModelId: model.upstreamModelId,
            displayName: model.displayName,
            capabilities: model.capabilities,
            config: {
              ...model.config,
              'catalogSource': 'provider-fallback',
              'availability': 'unknown',
            },
          )
        else
          model,
    ];
  }

  static List<LlmUpstreamModel> _mergeCommandCodeModelMappings(
    List<LlmUpstreamModel> discovered,
    List<LlmUpstreamModel> configured,
  ) {
    final configuredByModel = {
      for (final model in configured) model.upstreamModelId: model,
    };
    final merged = <LlmUpstreamModel>[];
    for (final upstream in discovered) {
      final existing = configuredByModel[upstream.upstreamModelId];
      if (existing == null) {
        merged.add(upstream);
        continue;
      }
      merged.add(
        LlmUpstreamModel(
          id: existing.id,
          upstreamModelId: upstream.upstreamModelId,
          displayName: existing.displayName,
          capabilities: upstream.capabilities,
          config: {...upstream.config, ...existing.config},
        ),
      );
    }
    return List.unmodifiable(merged);
  }

  Future<bool> _refreshCopilotCredential(
    LlmAccount account,
    Map<String, dynamic> originalBundle,
    CancelToken? cancelToken,
  ) async {
    final bundle = Map<String, dynamic>.from(originalBundle);
    final accessToken = _firstString(bundle, const [
      'access_token',
      'accessToken',
    ]);
    if (accessToken == null) return false;
    final gheUrl = _firstString(account.endpointConfig, const ['gheUrl']);
    final tokenUri = account.connectorType == 'github'
        ? Uri.https('api.github.com', '/copilot_internal/v2/token')
        : _copilotEnterpriseTokenUri(gheUrl);
    if (tokenUri == null) return false;
    try {
      final response = await _dio.getUri<Object?>(
        tokenUri,
        options: Options(
          responseType: ResponseType.json,
          headers: {
            'Authorization': 'token $accessToken',
            'Accept': 'application/json',
            'X-GitHub-Api-Version': '2026-08-01',
            'User-Agent': 'GithubCopilot/1.0',
            'Editor-Version': 'copilot/1.0.91',
            'Editor-Plugin-Version': 'copilot/1.0.91',
          },
          validateStatus: (status) => status != null,
        ),
        cancelToken: cancelToken,
      );
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        final data = _asJsonMap(response.data);
        final token = _firstString(data, const ['token']);
        if (token == null) throw const LlmAccountConnectorException();
        bundle['copilot_token'] = token;
        if (_firstString(data, const ['expires_at']) != null) {
          bundle['copilot_expires_at'] = _firstString(data, const [
            'expires_at',
          ]);
          bundle['expires_at'] = _earlierExpiry(
            bundle['oauth_expires_at'] ?? bundle['copilot_expires_at'],
            bundle['copilot_expires_at'],
          );
        }
        final endpoints = data?['endpoints'];
        if (account.connectorType == 'ghe-copilot' && endpoints is Map) {
          final api = _secureCopilotEndpoint(endpoints['api']);
          final proxy = _secureCopilotEndpoint(endpoints['proxy']);
          if (api != null) bundle['copilot_api_url'] = api;
          if (proxy != null) bundle['copilot_proxy_url'] = proxy;
        }
        await saveAccount(account, secret: jsonEncode(bundle));
        return true;
      }
      if (response.statusCode != 401 && response.statusCode != 403) {
        throw const LlmAccountConnectorException();
      }
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
    }
    final refreshToken = _firstString(bundle, const [
      'refresh_token',
      'refreshToken',
    ]);
    if (refreshToken == null) return false;
    final clientId =
        _firstString(account.endpointConfig, const ['copilotClientId']) ??
            LlmOAuthTokenClient.githubCopilotClientId;
    final oauthBase = account.connectorType == 'github'
        ? Uri.parse('https://github.com')
        : Uri.tryParse(gheUrl ?? '');
    if (oauthBase == null ||
        oauthBase.scheme != 'https' ||
        oauthBase.host.isEmpty ||
        oauthBase.userInfo.isNotEmpty) {
      return false;
    }
    final refreshUri = oauthBase.replace(
      path:
          '${oauthBase.path.replaceFirst(RegExp(r'/+$'), '')}/login/oauth/access_token',
    );
    try {
      final response = await _dio.postUri<Object?>(
        refreshUri,
        data: {
          'client_id': clientId,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
          headers: const {'Accept': 'application/json'},
        ),
        cancelToken: cancelToken,
      );
      final refreshed = _asJsonMap(response.data);
      final newAccessToken = _firstString(refreshed, const ['access_token']);
      if (newAccessToken == null) return false;
      bundle.addAll(refreshed!);
      bundle['access_token'] = newAccessToken;
      final rotated = _firstString(refreshed, const ['refresh_token']);
      if (rotated != null) bundle['refresh_token'] = rotated;
      final accessExpiry = _durationExpiry(refreshed['expires_in']);
      if (accessExpiry != null) {
        bundle['oauth_expires_at'] = accessExpiry;
        bundle['expires_at'] = accessExpiry;
      }
      final copilotResponse = await _dio.getUri<Object?>(
        tokenUri,
        options: Options(
          responseType: ResponseType.json,
          headers: {
            'Authorization': 'token $newAccessToken',
            'Accept': 'application/json',
            'X-GitHub-Api-Version': '2026-08-01',
            'User-Agent': 'GithubCopilot/1.0',
            'Editor-Version': 'copilot/1.0.91',
            'Editor-Plugin-Version': 'copilot/1.0.91',
          },
        ),
        cancelToken: cancelToken,
      );
      final copilot = _asJsonMap(copilotResponse.data);
      final copilotToken = _firstString(copilot, const ['token']);
      if (copilotToken == null) throw const LlmAccountConnectorException();
      bundle['copilot_token'] = copilotToken;
      final copilotExpiry = _firstString(copilot, const ['expires_at']);
      if (copilotExpiry != null) {
        bundle['copilot_expires_at'] = copilotExpiry;
        bundle['expires_at'] = _earlierExpiry(
          bundle['oauth_expires_at'] ?? bundle['expires_at'],
          copilotExpiry,
        );
      }
      final endpoints = copilot?['endpoints'];
      if (account.connectorType == 'ghe-copilot' && endpoints is Map) {
        final api = _secureCopilotEndpoint(endpoints['api']);
        final proxy = _secureCopilotEndpoint(endpoints['proxy']);
        if (api != null) bundle['copilot_api_url'] = api;
        if (proxy != null) bundle['copilot_proxy_url'] = proxy;
      }
      await saveAccount(account, secret: jsonEncode(bundle));
      return true;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw const LlmAccountConnectorException();
    } catch (_) {
      throw const LlmAccountConnectorException();
    }
  }

  static Uri? _copilotEnterpriseTokenUri(String? enterpriseUrl) {
    final uri = Uri.tryParse(enterpriseUrl?.trim() ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    return uri.replace(
      path:
          '${uri.path.replaceFirst(RegExp(r'/+$'), '')}/api/v3/copilot_internal/v2/token',
    );
  }

  static String? _secureCopilotEndpoint(Object? value) {
    final uri = Uri.tryParse(value is String ? value.trim() : '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    return uri
        .replace(path: uri.path.replaceFirst(RegExp(r'/+$'), ''))
        .toString();
  }

  static String? _earlierExpiry(Object? first, Object? second) {
    final firstTime = first is String ? DateTime.tryParse(first) : null;
    final secondTime = second is String ? DateTime.tryParse(second) : null;
    if (firstTime == null) return secondTime?.toUtc().toIso8601String();
    if (secondTime == null) return firstTime.toUtc().toIso8601String();
    return (firstTime.isBefore(secondTime) ? firstTime : secondTime)
        .toUtc()
        .toIso8601String();
  }

  static String? _durationExpiry(Object? value) {
    final seconds = value is num ? value.toInt() : int.tryParse('$value');
    if (seconds == null || seconds <= 0) return null;
    return DateTime.now()
        .toUtc()
        .add(Duration(seconds: seconds))
        .toIso8601String();
  }

  /// Refreshes an OAuth credential using the provider's pinned refresh flow.
  /// Returns false for connectors that do not advertise token refresh.
  Future<bool> refreshCredential(
    LlmAccount suppliedAccount, {
    CancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
    suppliedAccount = _canonicalAccount(suppliedAccount);
    final account = await getAccount(suppliedAccount.id);
    if (account == null ||
        LlmConnectorRegistry.canonicalId(account.connectorType) !=
            suppliedAccount.connectorType) {
      throw const LlmAccountConnectorException();
    }
    if (account.authType == 'oauth' &&
        !LlmOAuthProviderPolicy.forProvider(account.connectorType).supported) {
      return false;
    }
    final connector = LlmConnectorRegistry.find(account.connectorType);
    if (connector == null) throw const LlmAccountConnectorException();
    if (!connector.canRefreshCredentials) {
      return false;
    }
    final reference = account.credentialRef;
    if (reference == null) throw const LlmAccountConnectorException();
    final rawCredential = await _readSecureValue(reference);
    if (rawCredential == null) throw const LlmAccountConnectorException();
    final bundle = _decodeCredentialBundle(rawCredential);

    if (account.connectorType == 'vertex' &&
        account.authType == 'service_account') {
      return _refreshVertexServiceAccount(account, bundle, cancelToken);
    }
    if (account.connectorType == 'muse-code' && account.authType == 'oauth') {
      return _refreshMetaDca(account, bundle, cancelToken);
    }
    if (account.authType != 'oauth' &&
        !(account.connectorType == 'trae' &&
            account.authType == 'session_token')) {
      return false;
    }
    if (account.connectorType == 'github' ||
        account.connectorType == 'ghe-copilot') {
      return _refreshCopilotCredential(account, bundle, cancelToken);
    }
    if (account.connectorType == 'trae') {
      final providerData = bundle['providerSpecificData'];
      if (providerData is! Map ||
          providerData['authMethod'] != 'oauth_callback') {
        return false;
      }
    }

    final refreshToken = _firstString(bundle, const [
      'refresh_token',
      'refreshToken',
    ]);
    if (refreshToken == null) return false;

    if (account.connectorType == 'amazon-q') {
      return _refreshAmazonQCredential(
        account,
        bundle,
        refreshToken,
        cancelToken,
      );
    }

    final spec = _refreshRequest(account, bundle, refreshToken);
    if (spec == null) return false;
    try {
      final response = account.connectorType == 'cursor'
          ? await _postCursorRefreshWithRetries(spec, cancelToken: cancelToken)
          : await _dio.postUri<Object?>(
              spec.uri,
              data: spec.body,
              options: Options(
                headers: spec.headers,
                contentType: spec.contentType,
                responseType: ResponseType.json,
                followRedirects: account.connectorType != 'amazon-q',
              ),
              cancelToken: cancelToken,
            );
      if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
      final outerTokenResponse = _asJsonMap(response.data);
      if (account.connectorType == 'trae') {
        final responseMetadata = outerTokenResponse?['ResponseMetadata'];
        final responseError =
            responseMetadata is Map ? responseMetadata['Error'] : null;
        final errorCode = responseError is Map ? responseError['Code'] : null;
        if (errorCode != null && errorCode != false && errorCode != '') {
          throw const LlmAccountConnectorException();
        }
      }
      final nestedTokenData = outerTokenResponse?['data'];
      final traeResult = outerTokenResponse?['Result'];
      final tokenResponse = account.connectorType == 'trae'
          ? traeResult is Map
              ? Map<String, dynamic>.from(traeResult)
              : null
          : nestedTokenData is Map
              ? Map<String, dynamic>.from(nestedTokenData)
              : outerTokenResponse;
      final accessToken = _firstString(tokenResponse, [
        'access_token',
        'accessToken',
        if (account.connectorType == 'trae') 'Token',
      ]);
      if (accessToken == null) throw const LlmAccountConnectorException();
      final xaiRefreshScope = account.connectorType == 'grok-cli' ||
              account.connectorType == 'xai-oauth'
          ? _validatedXaiRefreshScope(tokenResponse, account.connectorType)
          : null;
      final freshFields = tokenResponse ?? const <String, dynamic>{};
      final updated = Map<String, dynamic>.from(bundle)
        ..addAll(freshFields)
        ..['access_token'] = accessToken;
      final rotatedRefreshToken = _firstString(tokenResponse, const [
        'refresh_token',
        'refreshToken',
      ]);
      if (rotatedRefreshToken != null) {
        updated['refresh_token'] = rotatedRefreshToken;
      }
      if (account.connectorType == 'trae') {
        final expiryValue = tokenResponse?['TokenExpireAt'];
        final epochMilliseconds = expiryValue is num
            ? expiryValue.toInt()
            : expiryValue is String
                ? int.tryParse(expiryValue)
                : null;
        final expiry = epochMilliseconds != null
            ? DateTime.fromMillisecondsSinceEpoch(
                epochMilliseconds,
                isUtc: true,
              )
            : expiryValue is String
                ? DateTime.tryParse(expiryValue)
                : null;
        if (expiry != null) {
          updated['expires_at'] = expiry.toIso8601String();
        } else {
          updated.remove('expires_at');
          updated.remove('expiresAt');
          updated.remove('expired');
        }
        final returnedRefresh = _firstString(tokenResponse, const [
          'RefreshToken',
          'refresh_token',
          'refreshToken',
        ]);
        if (returnedRefresh != null) {
          updated['refresh_token'] = returnedRefresh;
        }
      }
      if (xaiRefreshScope != null) updated['scope'] = xaiRefreshScope;
      final claudeAccount = tokenResponse?['account'];
      if (account.connectorType == 'claude' && claudeAccount is Map) {
        final accountData = Map<String, dynamic>.from(claudeAccount);
        final accountId = _firstString(accountData, const ['uuid']);
        final email = _firstString(accountData, const ['email_address']);
        if (accountId != null) updated['account_uuid'] = accountId;
        if (email != null) updated['email'] = email;
      }
      final claudeOrganization = tokenResponse?['organization'];
      if (account.connectorType == 'claude' && claudeOrganization is Map) {
        final organizationData = Map<String, dynamic>.from(claudeOrganization);
        final organizationId = _firstString(organizationData, const ['uuid']);
        final organizationName = _firstString(organizationData, const ['name']);
        if (organizationId != null) {
          updated['organization_uuid'] = organizationId;
        }
        if (organizationName != null) {
          updated['organization_name'] = organizationName;
        }
      }
      if (_firstString(updated, const ['refresh_token', 'refreshToken']) ==
          null) {
        updated['refresh_token'] = refreshToken;
      }
      if (account.connectorType == 'cursor') {
        updated['oauth_contract'] = 'cursor-deep-control-v1';
        updated['expires_at'] = _cursorAccessTokenExpiry(accessToken);
      }
      if (account.connectorType == 'cline' ||
          account.connectorType == 'clinepass') {
        final sourceExpiry = _firstString(tokenResponse, const [
          'expiresAt',
          'expires_at',
        ]);
        if (sourceExpiry != null) updated['expires_at'] = sourceExpiry;
        updated['oauth_contract'] = 'cline-workos-v1';
      }
      final expiresIn = tokenResponse?['expires_in'] ??
          tokenResponse?['expiresIn'] ??
          bundle['expires_in'] ??
          bundle['expiresIn'];
      final seconds = expiresIn is num
          ? expiresIn.toInt()
          : expiresIn is String
              ? int.tryParse(expiresIn)
              : null;
      if (seconds != null && seconds > 0) {
        final expiry = DateTime.now().toUtc().add(Duration(seconds: seconds));
        updated['expires_in'] = seconds;
        updated.remove('expiresIn');
        updated['expires_at'] = expiry.toIso8601String();
        updated['expired'] = expiry.toIso8601String();
      }
      await saveAccount(
        account,
        secret: jsonEncode(updated),
        traeCallbackIssued: account.connectorType == 'trae',
      );
      return true;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw const LlmAccountConnectorException();
    } catch (_) {
      throw const LlmAccountConnectorException();
    }
  }

  /// Resolves and persists the account project required by Antigravity's
  /// native generation endpoint. Project identity is safe account metadata;
  /// the OAuth credential remains in secure storage.
  Future<LlmAccount> ensureAntigravityProjectId(
    LlmAccount suppliedAccount, {
    CancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
    final account = await getAccount(suppliedAccount.id);
    if (account == null ||
        account.connectorType != suppliedAccount.connectorType) {
      throw const LlmAccountConnectorException();
    }
    if (account.connectorType != 'antigravity') return account;
    final configuredProject = LlmNativeRequestBuilder._configString(
      account.endpointConfig,
      'projectId',
    );
    if (configuredProject != null) return account;

    final reference = account.credentialRef;
    if (reference == null) throw const LlmAccountConnectorException();
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
        var rawCredential = await _readSecureValue(reference);
        if (rawCredential == null || rawCredential.trim().isEmpty) {
          throw const LlmAccountConnectorException();
        }
        var bundle = _decodeCredentialBundle(rawCredential);
        late final String token;
        try {
          token = LlmNativeRequestBuilder._credentialValue(
            account,
            rawCredential,
          );
        } on LlmAccountConnectorException {
          if (attempt == 0 &&
              await refreshCredential(account, cancelToken: cancelToken)) {
            continue;
          }
          rethrow;
        }
        final expiryValue = bundle['expires_at'] ?? bundle['expired'];
        final expiry = expiryValue is String
            ? DateTime.tryParse(expiryValue)
            : expiryValue is num
                ? DateTime.fromMillisecondsSinceEpoch(
                    expiryValue.toInt() * 1000,
                    isUtc: true,
                  )
                : null;
        final isExpiring = expiry != null &&
            !expiry.isAfter(
              DateTime.now().toUtc().add(const Duration(seconds: 30)),
            );
        if (attempt == 0 && isExpiring) {
          if (!await refreshCredential(account, cancelToken: cancelToken)) {
            throw const LlmAccountConnectorException();
          }
          continue;
        }
        final uri = Uri.parse(
          'https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist',
        );
        final response = await _dio.postUri<Object?>(
          uri,
          data: const {
            'metadata': {'ideType': 'ANTIGRAVITY'},
          },
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': '*/*',
              'User-Agent': kLlmAntigravityRequestUserAgent,
            },
            contentType: Headers.jsonContentType,
            responseType: ResponseType.json,
            validateStatus: (status) => status != null,
          ),
          cancelToken: cancelToken,
        );
        final status = response.statusCode ?? 0;
        if (status == 401 &&
            attempt == 0 &&
            await refreshCredential(account, cancelToken: cancelToken)) {
          continue;
        }
        if (status < 200 || status >= 300) {
          throw const LlmAccountConnectorException();
        }
        final projectId = _antigravityProjectId(_asJsonMap(response.data));
        if (projectId == null) throw const LlmAccountConnectorException();
        if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;

        final endpointConfig = Map<String, dynamic>.from(account.endpointConfig)
          ..['projectId'] = projectId;
        final updated = LlmAccount(
          id: account.id,
          connectorType: account.connectorType,
          authType: account.authType,
          displayName: account.displayName,
          status: account.status,
          credentialRef: account.credentialRef,
          endpointConfig: endpointConfig,
          models: account.models,
          policy: account.policy,
          usageByWindow: account.usageByWindow,
          remainingQuota: account.remainingQuota,
          quotaSignals: account.quotaSignals,
        );
        return saveAccount(updated);
      }
      throw const LlmAccountConnectorException();
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw const LlmAccountConnectorException();
    } catch (_) {
      throw const LlmAccountConnectorException();
    }
  }

  static String? _antigravityProjectId(Map<String, dynamic>? response) {
    final project = response?['cloudaicompanionProject'];
    if (project is String && project.trim().isNotEmpty) return project.trim();
    if (project is Map) {
      final id = project['id'] ?? project['projectId'] ?? project['project_id'];
      if (id is String && id.trim().isNotEmpty) return id.trim();
    }
    final direct = response?['projectId'] ?? response?['project_id'];
    return direct is String && direct.trim().isNotEmpty ? direct.trim() : null;
  }

  Future<bool> _refreshMetaDca(
    LlmAccount account,
    Map<String, dynamic> bundle,
    CancelToken? cancelToken,
  ) async {
    var dcaToken = _firstString(bundle, const ['dca_token', 'dcaToken']);
    final accessToken = _firstString(bundle, const [
      'access_token',
      'accessToken',
    ]);
    if (dcaToken == null && accessToken?.startsWith('dca:') == true) {
      dcaToken = accessToken;
    }
    if (dcaToken == null) return false;

    try {
      final response = await _dio.postUri<Object?>(
        Uri.parse('https://api.meta.ai/muse-code/key'),
        data: {'dca_token': dcaToken},
        options: Options(
          headers: {
            'Authorization': 'Bearer $dcaToken',
            'User-Agent': 'muse-code/1.0.2',
            'Accept': 'application/json',
          },
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
        ),
        cancelToken: cancelToken,
      );
      final minted = _asJsonMap(response.data);
      final apiKey = _firstString(minted, const ['api_key', 'apiKey']);
      if (apiKey == null || minted?['is_subs_active'] != true) {
        throw const LlmAccountConnectorException();
      }
      final email = _firstString(minted, const ['user_email', 'email']);
      final priorEmail = _firstString(bundle, const ['email', 'user_email']);
      if (email == null ||
          priorEmail == null ||
          priorEmail.toLowerCase() != email.toLowerCase()) {
        throw const LlmAccountConnectorException();
      }
      final updated = Map<String, dynamic>.from(bundle)
        ..addAll(minted ?? const <String, dynamic>{})
        ..['api_key'] = apiKey
        ..['access_token'] = apiKey
        ..['dca_token'] = dcaToken;
      updated['email'] = email;
      final name = _firstString(minted, const ['user_full_name', 'name']);
      if (name != null) updated['name'] = name;
      if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
      await saveAccount(account, secret: jsonEncode(updated));
      return true;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw const LlmAccountConnectorException();
    } catch (_) {
      throw const LlmAccountConnectorException();
    }
  }

  Future<Response<Object?>> _postCursorRefreshWithRetries(
    _LlmTokenRefreshRequest spec, {
    CancelToken? cancelToken,
  }) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
      late final Response<Object?> response;
      try {
        response = await _dio.postUri<Object?>(
          spec.uri,
          data: spec.body,
          options: Options(
            headers: spec.headers,
            contentType: spec.contentType,
            responseType: ResponseType.json,
            validateStatus: (status) => status != null,
          ),
          cancelToken: cancelToken,
        );
      } on DioException catch (error) {
        if (CancelToken.isCancel(error)) rethrow;
        if (attempt == 2) throw const LlmAccountConnectorException();
        await _waitBeforeCursorRefreshRetry(attempt, cancelToken);
        continue;
      }

      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) return response;
      if (status == 401 || status == 403) {
        throw const LlmAccountConnectorException();
      }
      final retryable = status == 429 ||
          status == 500 ||
          status == 502 ||
          status == 503 ||
          status == 504;
      if (!retryable || attempt == 2) {
        throw const LlmAccountConnectorException();
      }
      await _waitBeforeCursorRefreshRetry(attempt, cancelToken);
    }
    throw const LlmAccountConnectorException();
  }

  Future<void> _waitBeforeCursorRefreshRetry(
    int attempt,
    CancelToken? cancelToken,
  ) async {
    final delay = Future<void>.delayed(
      Duration(milliseconds: 300 * (1 << attempt)),
    );
    if (cancelToken == null) {
      await delay;
      return;
    }
    await Future.any<void>([
      delay,
      cancelToken.whenCancel.then<void>((_) => throw cancelToken.cancelError!),
    ]);
    if (cancelToken.isCancelled) throw cancelToken.cancelError!;
  }

  Future<bool> _refreshVertexServiceAccount(
    LlmAccount account,
    Map<String, dynamic> bundle,
    CancelToken? cancelToken,
  ) async {
    try {
      final serviceAccount = _serviceAccountCredential(bundle);
      final credentials = ServiceAccountCredentials.fromJson(serviceAccount);
      const scope = 'https://www.googleapis.com/auth/cloud-platform';
      final issuedAt = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final header = _base64UrlJson({'alg': 'RS256', 'typ': 'JWT'});
      final claims = _base64UrlJson({
        'iss': credentials.email,
        'scope': scope,
        'aud': 'https://oauth2.googleapis.com/token',
        'iat': issuedAt,
        'exp': issuedAt + 3600,
      });
      final signingInput = '$header.$claims';
      final signature = base64Url
          .encode(credentials.sign(utf8.encode(signingInput)))
          .replaceAll('=', '');
      final assertion = '$signingInput.$signature';
      final response = await _dio.postUri<Object?>(
        Uri.parse('https://oauth2.googleapis.com/token'),
        data: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          'assertion': assertion,
        },
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          responseType: ResponseType.json,
        ),
        cancelToken: cancelToken,
      );
      final tokenResponse = _asJsonMap(response.data);
      final accessToken = _firstString(tokenResponse, const ['access_token']);
      if (accessToken == null) throw const LlmAccountConnectorException();
      final updated = Map<String, dynamic>.from(bundle)
        ..addAll(tokenResponse ?? const <String, dynamic>{})
        ..['access_token'] = accessToken;
      final expiresIn = _intValue(updated['expires_in']);
      if (expiresIn != null && expiresIn > 0) {
        updated['expires_at'] = DateTime.now()
            .toUtc()
            .add(Duration(seconds: expiresIn))
            .toIso8601String();
      }
      if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
      await saveAccount(account, secret: jsonEncode(updated));
      return true;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw const LlmAccountConnectorException();
    } catch (_) {
      throw const LlmAccountConnectorException();
    }
  }

  static Map<String, dynamic> _serviceAccountCredential(
    Map<String, dynamic> bundle,
  ) {
    final nested = bundle['service_account'];
    if (nested is Map) return Map<String, dynamic>.from(nested);
    return bundle;
  }

  static String _base64UrlJson(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

  static int? _intValue(Object? value) => value is num
      ? value.toInt()
      : value is String
          ? int.tryParse(value)
          : null;

  static Map<String, dynamic> _decodeCredentialBundle(String secret) {
    try {
      final decoded = jsonDecode(secret);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      return {};
    }
  }

  Future<bool> _refreshAmazonQCredential(
    LlmAccount account,
    Map<String, dynamic> bundle,
    String refreshToken,
    CancelToken? cancelToken,
  ) async {
    try {
      final region = AmazonQConnector.oidcRegion(
        bundle['oidcRegion'] ??
            bundle['oidc_region'] ??
            bundle['region'] ??
            bundle['regionId'] ??
            bundle['region_id'] ??
            _amazonQRegion(account, bundle),
      );
      final tokenUri = Uri.https('oidc.$region.amazonaws.com', '/token');
      var clientId = _firstString(bundle, const ['clientId', 'client_id']);
      var clientSecret = _firstString(bundle, const [
        'clientSecret',
        'client_secret',
      ]);

      if ((clientId == null) != (clientSecret == null)) {
        throw const LlmAccountConnectorException();
      }
      Future<void> registerClient() async {
        final registration = await _dio.postUri<Object?>(
          Uri.https('oidc.$region.amazonaws.com', '/client/register'),
          data: const {
            'clientName': 'kiro-oauth-client',
            'clientType': 'public',
            'scopes': [
              'codewhisperer:completions',
              'codewhisperer:analysis',
              'codewhisperer:conversations',
            ],
            'grantTypes': [
              'urn:ietf:params:oauth:grant-type:device_code',
              'refresh_token',
            ],
            'issuerUrl':
                'https://identitycenter.amazonaws.com/ssoins-722374e8c3c8e6c6',
          },
          options: Options(
            contentType: Headers.jsonContentType,
            responseType: ResponseType.json,
            followRedirects: false,
            validateStatus: (status) => status != null,
            headers: const {'Accept': 'application/json'},
          ),
          cancelToken: cancelToken,
        );
        if ((registration.statusCode ?? 0) < 200 ||
            (registration.statusCode ?? 0) >= 300) {
          throw const LlmAccountConnectorException();
        }
        final registered = _asJsonMap(registration.data);
        clientId = _firstString(registered, const ['clientId']);
        clientSecret = _firstString(registered, const ['clientSecret']);
        if (clientId == null || clientSecret == null) {
          throw const LlmAccountConnectorException();
        }
      }

      if (clientId == null) await registerClient();

      Future<Response<Object?>> refreshWithCurrentClient() =>
          _dio.postUri<Object?>(
            tokenUri,
            data: {
              'clientId': clientId,
              'clientSecret': clientSecret,
              'refreshToken': refreshToken,
              'grantType': 'refresh_token',
            },
            options: Options(
              contentType: Headers.jsonContentType,
              responseType: ResponseType.json,
              followRedirects: false,
              validateStatus: (status) => status != null,
              headers: const {'Accept': 'application/json'},
            ),
            cancelToken: cancelToken,
          );

      var response = await refreshWithCurrentClient();
      if ((response.statusCode ?? 0) < 200 ||
          (response.statusCode ?? 0) >= 300) {
        final error = _asJsonMap(response.data);
        final errorType = _firstString(error, const ['__type', 'error']);
        if (const {
          'InvalidGrantException',
          'ExpiredTokenException',
          'invalid_grant',
        }.contains(errorType)) {
          throw const LlmAccountConnectorException();
        }
        await registerClient();
        response = await refreshWithCurrentClient();
        if ((response.statusCode ?? 0) < 200 ||
            (response.statusCode ?? 0) >= 300) {
          throw const LlmAccountConnectorException();
        }
      }
      final tokens = _asJsonMap(response.data);
      final accessToken = _firstString(tokens, const [
        'accessToken',
        'access_token',
      ]);
      if (accessToken == null) throw const LlmAccountConnectorException();

      final updated = Map<String, dynamic>.from(bundle)
        ..addAll(tokens ?? const <String, dynamic>{})
        ..['access_token'] = accessToken
        ..['clientId'] = clientId
        ..['clientSecret'] = clientSecret;
      final rotatedRefreshToken = _firstString(tokens, const [
        'refreshToken',
        'refresh_token',
      ]);
      updated['refresh_token'] = rotatedRefreshToken ?? refreshToken;
      final expiresIn = tokens?['expiresIn'] ?? tokens?['expires_in'];
      final expiresAt = _durationExpiry(expiresIn);
      if (expiresAt != null) updated['expires_at'] = expiresAt;
      await saveAccount(account, secret: jsonEncode(updated));
      return true;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw const LlmAccountConnectorException();
    } catch (_) {
      throw const LlmAccountConnectorException();
    }
  }

  static String? _firstString(Map<String, dynamic>? map, List<String> names) {
    if (map == null) return null;
    for (final name in names) {
      final value = map[name];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static _LlmTokenRefreshRequest? _refreshRequest(
    LlmAccount account,
    Map<String, dynamic> bundle,
    String refreshToken,
  ) {
    const formContentType = 'application/x-www-form-urlencoded';
    switch (account.connectorType) {
      case 'cursor':
        return _LlmTokenRefreshRequest(
          uri: Uri.parse('https://api2.cursor.sh/auth/exchange_user_api_key'),
          body: const <String, Object?>{},
          contentType: Headers.jsonContentType,
          headers: {'Authorization': 'Bearer $refreshToken'},
        );
      case 'trae':
        final clientId =
            _firstString(bundle, const ['client_id', 'clientId']) ??
                'en1oxy7wnw8j9n';
        final providerData = bundle['providerSpecificData'];
        final hostValue = providerData is Map
            ? _firstString(Map<String, dynamic>.from(providerData), const [
                'host',
              ])
            : null;
        final hostUri = hostValue == null
            ? Uri.parse('https://api.trae.ai')
            : Uri.tryParse(
                hostValue.contains('://') ? hostValue : 'https://$hostValue',
              );
        if (hostUri == null ||
            hostUri.scheme != 'https' ||
            hostUri.userInfo.isNotEmpty ||
            !(hostUri.host == 'api.trae.ai' ||
                hostUri.host.endsWith('.trae.ai'))) {
          return null;
        }
        return _LlmTokenRefreshRequest(
          uri: hostUri.replace(
            path: '/cloudide/api/v3/trae/oauth/ExchangeToken',
            query: null,
            fragment: null,
          ),
          body: {
            'ClientID': clientId,
            'RefreshToken': refreshToken,
            'ClientSecret': '-',
            'UserID': '',
          },
          contentType: Headers.jsonContentType,
          headers: const {'Accept': 'application/json'},
        );
      case 'codex':
        final clientId = _firstString(bundle, const ['client_id', 'clientId']);
        if (clientId == null) return null;
        return _LlmTokenRefreshRequest(
          uri: Uri.parse('https://auth.openai.com/api/accounts/oauth/token'),
          body: {
            'client_id': clientId,
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
            'resource': 'https://api.openai.com/v1',
          },
          contentType: formContentType,
        );
      case 'openference':
        return _LlmTokenRefreshRequest(
          uri: Uri.parse('https://openference.com/oauth/token'),
          body: {
            'client_id': 'omniroute',
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
          },
          contentType: formContentType,
        );
      case 'gitlab-duo':
        final clientId = _firstString(bundle, const ['client_id', 'clientId']);
        final configuredBase = account.endpointConfig['baseUrl'];
        final baseUrl = _firstString(bundle, const ['base_url']) ??
            (configuredBase is String && configuredBase.trim().isNotEmpty
                ? configuredBase.trim()
                : 'https://gitlab.com');
        final root = LlmOAuthAuthorizationAttempt.validateGitLabDuoBaseUrl(
          baseUrl,
        );
        final clientSecret = _firstString(bundle, const ['client_secret']);
        if (clientId == null) return null;
        return _LlmTokenRefreshRequest(
          uri: LlmOAuthAuthorizationAttempt.resolveGitLabDuoEndpoint(
            root,
            'oauth/token',
          ),
          body: {
            'client_id': clientId,
            ...?(clientSecret == null ? null : {'client_secret': clientSecret}),
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
          },
          contentType: formContentType,
        );
      case 'cline' || 'clinepass':
        return _LlmTokenRefreshRequest(
          uri: Uri.parse('https://api.cline.bot/api/v1/auth/refresh'),
          body: {
            'refreshToken': refreshToken,
            'grantType': 'refresh_token',
            'clientType': 'extension',
          },
          contentType: Headers.jsonContentType,
          headers: const {'Accept': 'application/json'},
        );
      case 'gemini' || 'aistudio':
        final clientId = _firstString(bundle, const ['client_id', 'clientId']);
        final clientSecret = _firstString(bundle, const [
          'client_secret',
          'clientSecret',
        ]);
        if (clientId == null || clientSecret == null) return null;
        return _LlmTokenRefreshRequest(
          uri: Uri.parse('https://oauth2.googleapis.com/token'),
          body: {
            'client_id': clientId,
            'client_secret': clientSecret,
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
          },
          contentType: formContentType,
        );
      case 'claude':
        return _LlmTokenRefreshRequest(
          uri: Uri.parse('https://platform.claude.com/v1/oauth/token'),
          body: {
            'client_id': _claudeOAuthClientId,
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
            'scope': LlmOAuthAuthorizationAttempt.claudeCodeScope,
          },
          contentType: Headers.jsonContentType,
          headers: const {
            'Accept': 'application/json, text/plain, */*',
            'User-Agent': 'axios/1.15.2',
            'Cache-Control': 'no-cache',
          },
        );
      case 'antigravity':
        // OAuth application credentials stay in the secure account bundle.
        final clientId = _firstString(bundle, const ['client_id', 'clientId']);
        final clientSecret = _firstString(bundle, const [
          'client_secret',
          'clientSecret',
        ]);
        if (clientId == null || clientSecret == null) return null;
        return _LlmTokenRefreshRequest(
          uri: Uri.parse('https://oauth2.googleapis.com/token'),
          body: {
            'client_id': clientId,
            'client_secret': clientSecret,
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
          },
          contentType: formContentType,
        );
      case 'kimi' || 'kimi-ai' || 'kimi.ai':
        final domain = _firstString(bundle, const ['domain']) ??
            (account.connectorType == 'kimi' ? 'kimi.com' : 'kimi.ai');
        final host = domain.toLowerCase().contains('kimi.ai')
            ? 'auth.kimi.ai'
            : 'auth.kimi.com';
        return _LlmTokenRefreshRequest(
          uri: Uri.https(host, '/api/oauth/token'),
          body: {
            'client_id': _kimiOAuthClientId,
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
          },
          contentType: formContentType,
        );
      case 'kimi-coding':
        final deviceId = _firstString(bundle, const ['device_id']);
        if (deviceId == null) return null;
        return _LlmTokenRefreshRequest(
          uri: Uri.parse('https://auth.kimi.com/api/oauth/token'),
          body: {
            'client_id': _kimiOAuthClientId,
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
          },
          contentType: formContentType,
          headers: {
            'X-Msh-Platform': 'CLIProxyAPI',
            'X-Msh-Version': 'stroom',
            'X-Msh-Device-Name': 'Stroom',
            'X-Msh-Device-Model': 'Stroom',
            'X-Msh-Device-Id': deviceId,
          },
        );
      case 'grok-cli' || 'xai-oauth':
        final endpoint = _firstString(bundle, const [
          'token_endpoint',
          'tokenEndpoint',
        ]);
        final uri = endpoint == null ? null : Uri.tryParse(endpoint);
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.userInfo.isNotEmpty ||
            uri.hasQuery ||
            uri.hasFragment ||
            !(uri.host == 'auth.x.ai' || uri.host.endsWith('.auth.x.ai'))) {
          return null;
        }
        return _LlmTokenRefreshRequest(
          uri: uri,
          body: {
            'client_id': _xaiOAuthClientId,
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
          },
          contentType: formContentType,
        );
      case 'codebuddy-cn' || 'codebuddy-intl' || 'workbuddy':
        final host = account.connectorType == 'codebuddy-cn'
            ? 'copilot.tencent.com'
            : account.connectorType == 'codebuddy-intl'
                ? 'www.codebuddy.ai'
                : 'www.workbuddy.ai';
        final headers = <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Refresh-Token': refreshToken,
          'X-Product': 'SaaS',
          'X-Domain': host,
          'User-Agent': account.connectorType == 'workbuddy'
              ? 'WorkBuddy/5.5.6'
              : account.connectorType == 'codebuddy-cn'
                  ? 'CLI/2.108.1 CodeBuddy/2.108.1'
                  : 'IDE/2.108.1 CodeBuddy/2.108.1',
          if (account.connectorType != 'workbuddy') ...{
            'X-Requested-With': 'XMLHttpRequest',
            'X-Auth-Refresh-Source': 'plugin',
          },
        };
        return _LlmTokenRefreshRequest(
          uri: Uri.https(host, '/v2/plugin/auth/token/refresh'),
          body: const <String, dynamic>{},
          contentType: Headers.jsonContentType,
          headers: headers,
        );
      default:
        return null;
    }
  }

  static String _validatedXaiRefreshScope(
    Map<String, dynamic>? tokenResponse,
    String connectorType,
  ) {
    final requiredModeScope = switch (connectorType) {
      'grok-cli' => 'grok-cli:access',
      'xai-oauth' => 'api:access',
      _ => throw const LlmAccountConnectorException(),
    };
    final oppositeModeScope = requiredModeScope == 'grok-cli:access'
        ? 'api:access'
        : 'grok-cli:access';
    if (tokenResponse == null || !tokenResponse.containsKey('scope')) {
      return 'openid profile email offline_access $requiredModeScope';
    }
    final scope = tokenResponse['scope'];
    if (scope is! String || scope.trim().isEmpty) {
      throw const LlmAccountConnectorException();
    }
    final grantedScopes = scope.trim().split(RegExp(r'\s+')).toSet();
    if (!grantedScopes.contains(requiredModeScope) ||
        grantedScopes.contains(oppositeModeScope)) {
      throw const LlmAccountConnectorException();
    }
    return scope.trim();
  }

  Future<List<LlmUpstreamModel>> _discoverCopilotModels(
    LlmAccount account,
  ) async {
    if (account.authType != 'oauth' || account.credentialRef == null) {
      throw const LlmAccountConnectorException();
    }
    var raw = await _readSecureValue(account.credentialRef!);
    var bundle =
        raw == null ? <String, dynamic>{} : _decodeCredentialBundle(raw);
    var token = _firstString(bundle, const ['copilot_token']);
    final expiresAt = DateTime.tryParse(
      _firstString(bundle, const ['copilot_expires_at']) ?? '',
    );
    if (token == null ||
        expiresAt != null &&
            !expiresAt.isAfter(
              DateTime.now().toUtc().add(const Duration(minutes: 1)),
            )) {
      await refreshCredential(account);
      raw = await _readSecureValue(account.credentialRef!);
      bundle = raw == null ? <String, dynamic>{} : _decodeCredentialBundle(raw);
      token = _firstString(bundle, const ['copilot_token']);
      if (token == null) {
        await refreshCredential(account);
        raw = await _readSecureValue(account.credentialRef!);
        bundle =
            raw == null ? <String, dynamic>{} : _decodeCredentialBundle(raw);
        token = _firstString(bundle, const ['copilot_token']);
      }
    }
    if (token == null) throw const LlmAccountConnectorException();
    final base = account.connectorType == 'github'
        ? 'https://api.githubcopilot.com'
        : _firstString(bundle, const ['copilot_api_url']);
    final uri = base == null ? null : Uri.tryParse('$base/models');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const LlmAccountConnectorException();
    }
    LlmNativeRequestBuilder._validateProviderBaseUrl(account, uri);
    final response = await _dio.getUri<Object?>(
      uri,
      options: Options(
        responseType: ResponseType.json,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'X-GitHub-Api-Version': '2026-08-01',
          'User-Agent': 'GithubCopilot/1.0',
          'Editor-Version': 'vscode/1.0.91',
          'Editor-Plugin-Version': 'copilot/1.0.91',
        },
      ),
    );
    final payload = _asJsonMap(response.data);
    final rawModels = payload?['data'] ?? payload?['models'];
    if (rawModels is! Iterable) throw const LlmAccountConnectorException();
    final models = <LlmUpstreamModel>[];
    for (final rawModel in rawModels) {
      if (rawModel is! Map) continue;
      final item = Map<String, dynamic>.from(rawModel);
      final modelId = _firstString(item, const ['id', 'name']);
      if (modelId == null ||
          !LlmConnectorRegistry.isConversationalModelId(modelId)) {
        continue;
      }
      final endpointValues =
          item['supported_endpoints'] ?? item['supportedEndpoints'];
      final endpoints = endpointValues is Iterable
          ? endpointValues.whereType<String>().toSet()
          : <String>{};
      final modelProtocols = <String>{
        if (endpoints.contains('/chat/completions') || endpoints.isEmpty)
          'openai.chat_completions',
        if (endpoints.contains('/responses')) 'openai.responses',
        if (endpoints.contains('/v1/messages')) 'anthropic.messages',
      };
      if (modelProtocols.isEmpty) continue;
      models.add(
        LlmUpstreamModel(
          id: '${account.id}:copilot:$modelId',
          upstreamModelId: modelId,
          displayName: _firstString(item, const ['name', 'id']) ?? modelId,
          capabilities: {
            'chat': true,
            'streaming': true,
            'supportedApiProtocols': modelProtocols,
          },
          config: const {'catalogSource': 'account-entitlement'},
        ),
      );
    }
    return models;
  }

  Future<List<LlmUpstreamModel>> _discoverAiHordeModels(
    LlmAccount account,
  ) async {
    final storedKey = account.credentialRef == null
        ? null
        : await _readSecureValue(account.credentialRef!);
    final apiKey = account.authType == 'api_key' ? storedKey?.trim() : null;
    if (account.authType == 'api_key') {
      if (apiKey == null || apiKey.isEmpty) {
        throw const LlmAccountConnectorException();
      }
      if (!await validateAiHordeApiKey(_dio, apiKey)) {
        throw const LlmAccountConnectorException();
      }
    }

    final response = await _dio.getUri<Object?>(
      Uri.parse(kAiHordeChatModelsUri),
      options: Options(
        responseType: ResponseType.json,
        followRedirects: false,
        validateStatus: (status) => status != null,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${apiKey ?? kAiHordeAnonymousKey}',
        },
      ),
    );
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw const LlmAccountConnectorException();
    }
    final payload = _asJsonMap(response.data);
    final rawModels = payload?['data'];
    if (rawModels is! Iterable) throw const LlmAccountConnectorException();
    final models = <LlmUpstreamModel>[];
    for (final rawModel in rawModels) {
      if (rawModel is! Map) continue;
      final item = Map<String, dynamic>.from(rawModel);
      final modelId = _firstString(item, const ['id']);
      if (modelId == null ||
          !LlmConnectorRegistry.isConversationalModel(modelId, item)) {
        continue;
      }
      final modelType = [
        item['type'],
        item['taskType'],
        item['task_type'],
        item['modelType'],
      ].whereType<String>().join(' ').toLowerCase();
      if (RegExp(
            r'image|diffusion|embedding|rerank|ranking|transcrib|tts',
          ).hasMatch(modelType) ||
          !_aiHordeModelHasOnlyTextModalities(item)) {
        continue;
      }
      models.add(
        LlmUpstreamModel(
          id: '${account.id}:aihorde:$modelId',
          upstreamModelId: modelId,
          displayName:
              _firstString(item, const ['name', 'displayName']) ?? modelId,
          capabilities: const {
            'chat': true,
            'streaming': true,
            'toolCalling': false,
            'supportedApiProtocols': ['openai.chat_completions'],
          },
          config: const {'catalogSource': 'live-chat-catalog'},
        ),
      );
    }
    return models;
  }

  bool _aiHordeModelHasOnlyTextModalities(Map<String, dynamic> model) {
    final architecture = model['architecture'];
    if (architecture is Map) {
      final modality = architecture['modality'];
      if (modality is String && modality.trim().isNotEmpty) {
        final parts = modality.split('->');
        if (parts.length != 2 ||
            parts.any(
              (part) =>
                  part
                      .split(RegExp(r'[+\s,]'))
                      .where((value) => value.trim().isNotEmpty)
                      .isEmpty ||
                  part
                      .split(RegExp(r'[+\s,]'))
                      .where((value) => value.trim().isNotEmpty)
                      .any((value) => value.toLowerCase() != 'text'),
            )) {
          return false;
        }
      }
    }
    for (final source in [model, if (architecture is Map) architecture]) {
      for (final key in ['input_modalities', 'output_modalities']) {
        final modalities = source[key];
        if (modalities == null) continue;
        if (modalities is! Iterable || modalities is String) return false;
        final declared = modalities.whereType<String>().toList();
        if (declared.length != modalities.length ||
            declared.isEmpty ||
            declared.any(
              (modality) => modality.trim().toLowerCase() != 'text',
            )) {
          return false;
        }
      }
    }
    return true;
  }

  Future<List<LlmUpstreamModel>> _discoverRemoteModels(
    LlmAccount account,
  ) async {
    _validateSafeConfig(account.endpointConfig);
    if (account.connectorType == 'aihorde') {
      return _discoverAiHordeModels(account);
    }
    if (account.connectorType == 'gitlab-duo') {
      return [
        for (final modelId in kPinnedGitLabDuoModels)
          LlmUpstreamModel(
            id: '${account.id}:$modelId',
            upstreamModelId: modelId,
            displayName: switch (modelId) {
              'claude-sonnet-4-6' => 'Claude Sonnet 4.6 (GitLab Duo)',
              'claude-haiku-4-5' => 'Claude Haiku 4.5 (GitLab Duo)',
              _ => modelId,
            },
            capabilities: const {
              'chat': true,
              'streaming': true,
              'supportedApiProtocols': ['openai.chat_completions'],
            },
            config: const {'catalogSource': 'pinned-provider-catalog'},
          ),
      ];
    }
    if (account.connectorType == 'vertex' && account.authType == 'oauth') {
      throw const LlmAccountConnectorException();
    }
    final isGemini = account.connectorType == 'gemini' ||
        account.connectorType == 'aistudio' ||
        account.connectorType == 'gemini-interactions';
    if (account.connectorType == 'bedrock') {
      return _discoverBedrockModels(account);
    }
    if (account.connectorType == 'github' ||
        account.connectorType == 'ghe-copilot') {
      return _discoverCopilotModels(account);
    }
    if (account.connectorType == 'zed-hosted') {
      if (account.authType != 'oauth') {
        throw const LlmAccountConnectorException();
      }
      final secret = account.credentialRef == null
          ? null
          : await _readSecureValue(account.credentialRef!);
      if (secret == null || secret.isEmpty) {
        throw const LlmAccountConnectorException();
      }
      final credentials = _decodeCredentialBundle(secret)
        ..['account_id'] = account.id;
      return ZedHostedApiClient(
        dio: _dio,
      ).fetchModels(credentials, forceRefresh: true);
    }
    if (account.connectorType == 'cline' ||
        account.connectorType == 'clinepass') {
      return _discoverClineModels(account);
    }
    if (account.connectorType == 'trae') {
      if (account.authType != 'session_token' ||
          account.endpointConfig['baseUrl'] != null ||
          account.credentialRef == null) {
        throw const LlmAccountConnectorException();
      }
      final rawCredential = await _readSecureValue(account.credentialRef!);
      if (rawCredential == null || rawCredential.trim().isEmpty) {
        throw const LlmAccountConnectorException();
      }
      final credential = TraeSoloCredential.fromPastedValue(rawCredential);
      if (!credential.expiresAt.isAfter(DateTime.now().toUtc())) {
        throw const LlmAccountConnectorException();
      }
      final response = await _dio.getUri<Object?>(
        TraeSoloConnector.modelsUri,
        options: Options(
          responseType: ResponseType.json,
          headers: TraeSoloConnector.headers(credential),
          validateStatus: (status) => status != null,
        ),
      );
      if ((response.statusCode ?? 0) < 200 ||
          (response.statusCode ?? 0) >= 300) {
        throw const LlmAccountConnectorException();
      }
      final models = TraeSoloConnector.parseModels(response.data);
      return [
        for (final model in models)
          LlmUpstreamModel(
            id: '${account.id}:trae:${model['id']}',
            upstreamModelId: model['id'] as String,
            displayName: model['displayName'] as String,
            capabilities: const {'chat': true, 'streaming': true},
            config: const {'catalogSource': 'account-entitlement'},
          ),
      ];
    }
    final fallbackBase = switch (account.connectorType) {
      'uncloseai' => _uncloseAiBaseUrl,
      'openai-api' => 'https://api.openai.com/v1',
      'openference' || 'openference-api' => 'https://api.openference.com/v1',
      'opencode-go' => _openCodeGoBaseUrl,
      'opencode-zen' => _openCodeZenBaseUrl,
      'command-code' => kCommandCodeBaseUrl,
      'claude' => 'https://api.anthropic.com/v1',
      'gemini' ||
      'aistudio' ||
      'gemini-interactions' =>
        'https://generativelanguage.googleapis.com',
      'moonshot' => 'https://api.moonshot.ai/v1',
      'glm' => 'https://open.bigmodel.cn/api/paas/v4',
      'glm-cn' => 'https://open.bigmodel.cn/api/coding/paas/v4',
      'deepseek' => 'https://api.deepseek.com',
      'minimax' => 'https://api.minimax.io/v1',
      'minimax-cn' => 'https://api.minimaxi.com/v1',
      'qwen' => 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      'qwen-cloud' => _qwenCloudBaseUrl(account.endpointConfig),
      'qwen-cloud-token-plan' =>
        'https://token-plan.maas.qwencloudapi.com/compatible-mode/v1',
      'grok-cli' => 'https://cli-chat-proxy.grok.com/v1',
      'xai-oauth' => 'https://api.x.ai/v1',
      'muse-code' => 'https://api.meta.ai/v1',
      'codebuddy-cn' => 'https://copilot.tencent.com/v2',
      'codebuddy-intl' => 'https://www.codebuddy.ai/v2',
      'workbuddy' => 'https://www.workbuddy.ai/v2',
      'kilocode' => 'https://api.kilo.ai/api/openrouter',
      'vertex' => _vertexBaseUrl(account.endpointConfig),
      'ollama' => null,
      'trae' => TraeSoloConnector.defaultBaseUrl,
      _ => null,
    };
    final base = account.connectorType == 'kilocode' ||
            account.connectorType == 'uncloseai'
        ? fallbackBase
        : LlmNativeRequestBuilder._configString(
              account.endpointConfig,
              'baseUrl',
            ) ??
            fallbackBase;
    if (base == null || base.isEmpty) {
      throw const LlmAccountConnectorException();
    }
    final secret = account.credentialRef == null
        ? null
        : await _readSecureValue(account.credentialRef!);
    final configuredModelsUrl = LlmNativeRequestBuilder._configString(
      account.endpointConfig,
      'modelsUrl',
    );
    final configuredModelsUri = configuredModelsUrl == null
        ? null
        : Uri.tryParse(configuredModelsUrl.trim());
    final uri = account.connectorType == 'workbuddy'
        ? Uri.https('www.workbuddy.ai', '/v3/config')
        : account.connectorType == 'ollama'
            ? _ollamaModelListUri(base)
            : account.connectorType == 'vertex'
                ? _vertexModelListUri(account.endpointConfig, base, secret)
                : configuredModelsUrl != null
                    ? configuredModelsUri
                    : _modelListUri(base, isGemini: isGemini);
    if (uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' &&
                LlmNativeRequestBuilder._isLoopbackHost(uri.host)))) {
      throw const LlmAccountConnectorException();
    }
    LlmNativeRequestBuilder._validateProviderBaseUrl(account, uri);
    final headers = <String, String>{'Accept': 'application/json'};
    final usesGeminiOAuth = account.authType == 'oauth' &&
        (account.connectorType == 'gemini' ||
            account.connectorType == 'aistudio');
    final usesXaiOAuth = account.authType == 'oauth' &&
        (account.connectorType == 'grok-cli' ||
            account.connectorType == 'xai-oauth');
    final usesMuseOAuth =
        account.authType == 'oauth' && account.connectorType == 'muse-code';
    final usesTencentOAuth = account.authType == 'oauth' &&
        {
          'codebuddy-cn',
          'codebuddy-intl',
          'workbuddy',
        }.contains(account.connectorType);
    final usesRefreshableOAuth = usesGeminiOAuth ||
        usesXaiOAuth ||
        usesTencentOAuth ||
        (account.authType == 'oauth' &&
            account.connectorType == 'openference') ||
        account.connectorType == 'trae';
    final usesGrokBuildOAuth =
        account.authType == 'oauth' && account.connectorType == 'grok-cli';
    final usesKiloOAuth =
        account.authType == 'oauth' && account.connectorType == 'kilocode';
    final configuredHeaders = account.endpointConfig['headers'];
    if (configuredHeaders is Map) {
      for (final entry in configuredHeaders.entries) {
        if (entry.key is! String || entry.value is! String) {
          throw const LlmAccountConnectorException();
        }
        LlmNativeRequestBuilder._validateRequestHeader(
          entry.key as String,
          entry.value as String,
        );
        headers[entry.key as String] = entry.value as String;
      }
    }
    if (account.connectorType == 'kilocode') {
      headers['X-KILOCODE-EDITORNAME'] = 'Stroom';
    }
    if (account.authType == 'api_key') {
      if (secret == null || secret.isEmpty) {
        throw const LlmAccountConnectorException();
      }
      final key = LlmNativeRequestBuilder._credentialValue(account, secret);
      if (isGemini || account.connectorType == 'vertex') {
        headers['x-goog-api-key'] = key;
      } else if (account.connectorType == 'claude') {
        headers['x-api-key'] = key;
        headers['anthropic-version'] = '2023-06-01';
      } else if (account.connectorType == 'openai-compatibility') {
        LlmNativeRequestBuilder._applyConfiguredApiKeyHeader(
          headers,
          account.endpointConfig,
          key,
        );
      } else {
        headers['Authorization'] = 'Bearer $key';
      }
    } else if (account.connectorType == 'vertex' &&
        account.authType == 'service_account') {
      if (secret == null || secret.isEmpty) {
        throw const LlmAccountConnectorException();
      }
      var credentialBundle = secret;
      if (_vertexServiceAccountTokenNeedsRefresh(secret)) {
        await refreshCredential(account);
        final updatedSecret = account.credentialRef == null
            ? null
            : await _readSecureValue(account.credentialRef!);
        if (updatedSecret == null) {
          throw const LlmAccountConnectorException();
        }
        credentialBundle = updatedSecret;
      }
      final accessToken = LlmNativeRequestBuilder._credentialBundleString(
        credentialBundle,
        const ['access_token', 'accessToken'],
      );
      if (accessToken == null) throw const LlmAccountConnectorException();
      headers['Authorization'] = 'Bearer $accessToken';
    } else if (usesRefreshableOAuth) {
      if (secret == null || secret.isEmpty) {
        throw const LlmAccountConnectorException();
      }
      headers['Authorization'] =
          'Bearer ${LlmNativeRequestBuilder._credentialValue(account, secret)}';
      if (usesTencentOAuth) {
        _addTencentClientHeaders(
          account.connectorType,
          headers,
          discovery: true,
        );
      }
      if (usesGeminiOAuth) {
        headers['x-goog-user-project'] =
            LlmNativeRequestBuilder._requiredGoogleCloudProjectId(
          account.endpointConfig,
        );
      }
    } else if (usesMuseOAuth) {
      if (secret == null || secret.isEmpty) {
        throw const LlmAccountConnectorException();
      }
      headers['Authorization'] =
          'Bearer ${LlmNativeRequestBuilder._credentialValue(account, secret)}';
      headers['User-Agent'] =
          'muse-build/1.3.0 (interactive; macos-aarch64; build ac7280f2aca67769d1455a8847bb502b617d50f6)';
      headers['X-Client-Id'] = 'tbh:tui';
    } else if (usesKiloOAuth) {
      if (secret == null || secret.isEmpty) {
        throw const LlmAccountConnectorException();
      }
      headers['Authorization'] =
          'Bearer ${LlmNativeRequestBuilder._credentialValue(account, secret)}';
      headers['X-KILOCODE-EDITORNAME'] = 'Stroom';
    } else if (account.authType == 'none') {
      // OpenAI-compatible public or local endpoints may omit authentication.
      if (account.connectorType == 'kilocode') {
        headers['Authorization'] = 'Bearer anonymous';
      }
    } else {
      throw const LlmAccountConnectorException();
    }

    var oauthTokenRefreshed = false;
    Future<void> refreshOAuthToken() async {
      if (!usesRefreshableOAuth ||
          oauthTokenRefreshed ||
          !await refreshCredential(account)) {
        throw const LlmAccountConnectorException();
      }
      final refreshedSecret = account.credentialRef == null
          ? null
          : await _readSecureValue(account.credentialRef!);
      if (refreshedSecret == null || refreshedSecret.isEmpty) {
        throw const LlmAccountConnectorException();
      }
      headers['Authorization'] =
          'Bearer ${LlmNativeRequestBuilder._credentialValue(account, refreshedSecret)}';
      oauthTokenRefreshed = true;
    }

    if (usesRefreshableOAuth && secret != null && secret.isNotEmpty) {
      final credentialBundle = _decodeCredentialBundle(secret);
      final expiryValue =
          credentialBundle['expires_at'] ?? credentialBundle['expired'];
      final expiry = expiryValue is String
          ? DateTime.tryParse(expiryValue)
          : expiryValue is num
              ? DateTime.fromMillisecondsSinceEpoch(
                  expiryValue.toInt() * 1000,
                  isUtc: true,
                )
              : null;
      if (expiry != null &&
          !expiry.isAfter(
            DateTime.now().toUtc().add(const Duration(seconds: 30)),
          )) {
        await refreshOAuthToken();
      }
    }
    if (usesGrokBuildOAuth) headers.addAll(_grokBuildClientHeaders);

    try {
      final models = <LlmUpstreamModel>[];
      final providerPreset = account.connectorType == 'openai-compatibility'
          ? findLlmOpenAiProviderPreset(
              account.endpointConfig['providerPresetId'] is String
                  ? account.endpointConfig['providerPresetId'] as String
                  : null,
            )
          : null;
      final seenPageTokens = <String>{};
      String? pageToken;
      var pageCount = 0;
      do {
        if (++pageCount > _maxModelDiscoveryPages) {
          throw const LlmAccountConnectorException();
        }
        final cursorParameter = switch (account.connectorType) {
          'openai-api' => 'after',
          'claude' => 'after_id',
          _ => 'pageToken',
        };
        final pageUri = pageToken == null
            ? uri
            : uri.replace(
                queryParameters: {
                  ...uri.queryParameters,
                  cursorParameter: pageToken,
                },
              );
        Response<Object?> response;
        try {
          response = await _dio.getUri<Object?>(
            pageUri,
            options: Options(
              headers: headers,
              followRedirects: account.connectorType != 'command-code',
            ),
          );
        } on DioException catch (error) {
          if (error.response?.statusCode != 401 ||
              !usesRefreshableOAuth ||
              oauthTokenRefreshed) {
            rethrow;
          }
          await refreshOAuthToken();
          response = await _dio.getUri<Object?>(
            pageUri,
            options: Options(
              headers: headers,
              followRedirects: account.connectorType != 'command-code',
            ),
          );
        }
        final data = _asJsonMap(response.data);
        final innerWorkbuddy =
            account.connectorType == 'workbuddy' && data?['data'] is Map
                ? Map<String, dynamic>.from(data!['data'] as Map)
                : null;
        final rawModels = innerWorkbuddy?['models'] ??
            data?['data'] ??
            data?['models'] ??
            data?['publisherModels'];
        final normalizedWorkbuddyModels = rawModels is Map
            ? rawModels.entries
                .map(
                  (entry) => <String, dynamic>{
                    'id': entry.key,
                    if (entry.value is Map)
                      ...Map<String, dynamic>.from(entry.value as Map),
                  },
                )
                .toList()
            : rawModels;
        if (normalizedWorkbuddyModels is! List) break;
        for (final raw in normalizedWorkbuddyModels) {
          if (raw is! Map) continue;
          final map = Map<String, dynamic>.from(raw);
          final rawId = map['id'] ?? map['name'];
          if (rawId is! String || rawId.trim().isEmpty) continue;
          final modelId = rawId
              .trim()
              .replaceFirst(RegExp(r'^publishers/[^/]+/models/'), '')
              .replaceFirst(RegExp(r'^models/'), '');
          final modelType = map['type'];
          if (account.connectorType == 'openai-compatibility' &&
              account.endpointConfig['providerPresetId'] ==
                  'cheaperinference' &&
              modelType is String &&
              modelType.toLowerCase() == 'image') {
            continue;
          }
          if (account.connectorType == 'kilocode' &&
              account.authType == 'none' &&
              !kKiloCodeAnonymousFreeModelIds.contains(modelId)) {
            continue;
          }
          final commandCodeProtocols = account.connectorType == 'command-code'
              ? _commandCodeProtocolsForModel(map)
              : null;
          if (account.connectorType == 'command-code' &&
              (commandCodeProtocols == null || commandCodeProtocols.isEmpty)) {
            continue;
          }
          if (account.connectorType == 'workbuddy') {
            final tags = map['tags'];
            const mediaOnlyTags = {
              'text-to-image',
              'image-to-image',
              'text-to-video',
              'image-to-video',
            };
            if (tags is List &&
                tags.isNotEmpty &&
                tags.every(
                  (tag) => tag is String && mediaOnlyTags.contains(tag),
                )) {
              continue;
            }
          }
          if (account.connectorType == 'muse-code' &&
              !kPinnedMuseCodeModels.contains(modelId)) {
            continue;
          }
          final methods = map['supportedGenerationMethods'];
          final actions = map['supportedActions'];
          final vertexActions = account.connectorType != 'vertex'
              ? const <String>{}
              : {
                  if (methods is Iterable)
                    for (final method in methods.whereType<String>())
                      method.toLowerCase().replaceAll('_', ''),
                  if (actions is Iterable)
                    for (final action in actions.whereType<String>())
                      action.toLowerCase().replaceAll('_', ''),
                };
          final vertexSupportsGenerateContent = vertexActions.contains(
            'generatecontent',
          );
          final vertexSupportsStreaming = vertexActions.contains(
            'streamgeneratecontent',
          );
          var modelExtensions = account.connectorType == 'command-code'
              ? <String, dynamic>{
                  'supported_endpoints': map['supported_endpoints'],
                  if (map['capabilities'] is Map)
                    'capabilities': map['capabilities'],
                }
              : map;
          var providerCapabilities = map['capabilities'];
          if (account.connectorType == 'ollama') {
            try {
              final detailsUri = uri.replace(
                path: uri.path.replaceFirst(RegExp(r'/tags$'), '/show'),
              );
              final detailsResponse = await _dio.postUri<Object?>(
                detailsUri,
                data: {'name': modelId},
                options: Options(headers: headers),
              );
              final details = _asJsonMap(detailsResponse.data);
              if (details != null) {
                modelExtensions = {...map, 'show': details};
                providerCapabilities = details['capabilities'];
              }
            } catch (_) {
              // Keep the discovered model, but leave unsupported capabilities
              // unknown when this Ollama server cannot describe them.
            }
          }
          final isVertexImagen = account.connectorType == 'vertex' &&
              modelId.toLowerCase().contains('imagen');
          final supportsImagenPredict = isVertexImagen &&
              actions is List &&
              actions.any(
                (action) =>
                    action is String && action.toLowerCase() == 'predict',
              );
          if ((isGemini || account.connectorType == 'vertex') &&
              methods is List &&
              !methods.contains('generateContent') &&
              !methods.contains('streamGenerateContent') &&
              !supportsImagenPredict) {
            continue;
          }
          if (account.connectorType == 'vertex' &&
              !vertexSupportsGenerateContent &&
              !supportsImagenPredict) {
            continue;
          }
          if (const {
                'opencode-go',
                'opencode-zen',
              }.contains(account.connectorType) &&
              !_isOpenCodeStandardGatewayModelId(modelId)) {
            continue;
          }
          if (!_isChatModel(modelId, map) && !supportsImagenPredict) continue;
          final presetModel = providerPreset?.fallbackModels
              .where(
                (model) =>
                    '${providerPreset.modelIdPrefix}${model.id}' == modelId,
              )
              .firstOrNull;
          final savedModel = account.models
              .where((model) => model.upstreamModelId == modelId)
              .firstOrNull;
          final apiProtocolOverride =
              savedModel?.config['apiProtocolOverride'] ??
                  presetModel?.apiProtocolOverride;
          final apiProtocolOverrideSource =
              savedModel?.config['apiProtocolOverride'] != null
                  ? savedModel?.config['apiProtocolOverrideSource']
                  : presetModel?.apiProtocolOverride != null
                      ? 'provider-preset-default'
                      : null;
          models.add(
            LlmUpstreamModel(
              id: '${account.id}:remote:${models.length}',
              upstreamModelId: modelId,
              displayName: (map['displayName'] ?? map['display_name']) is String
                  ? (map['displayName'] ?? map['display_name']) as String
                  : modelId,
              capabilities: {
                if ((account.connectorType == 'openai-api' &&
                        modelId.toLowerCase().startsWith('gpt-realtime')) ||
                    (account.connectorType == 'xai' &&
                        (modelId.toLowerCase() == 'grok-voice' ||
                            modelId.toLowerCase().startsWith('grok-voice-'))))
                  // The source-defined Realtime model families carry audio
                  // support even when their model-list rows omit capabilities.
                  'audio': true,
                if (account.connectorType == 'workbuddy') ...{
                  'chat': true,
                  'streaming': true,
                  if (providerCapabilities is List &&
                      providerCapabilities.contains('tools'))
                    'tools': true,
                  if (providerCapabilities is List &&
                      providerCapabilities.contains('vision'))
                    'vision': true,
                },
                if (commandCodeProtocols != null) ...{
                  'chat': true,
                  'supportedApiProtocols': commandCodeProtocols,
                },
                if (account.connectorType == 'uncloseai') ...{
                  'chat': true,
                  'streaming': true,
                  'contextLength': map['max_model_len'] is num &&
                          (map['max_model_len'] as num) > 0
                      ? (map['max_model_len'] as num).toInt()
                      : _uncloseAiDefaultContextLength,
                  'supportedApiProtocols': ['openai.chat_completions'],
                },
                if (account.connectorType == 'codebuddy-cn' ||
                    account.connectorType == 'codebuddy-intl')
                  ..._staticTencentModelCapabilities(
                    account.connectorType,
                    modelId,
                  ),
                if (const {
                  'glm-cn',
                  'minimax-cn',
                  'qwen-cloud',
                  'qwen-cloud-token-plan',
                }.contains(account.connectorType)) ...{
                  'chat': true,
                  'streaming': true,
                },
                if (const {
                  'opencode-go',
                  'opencode-zen',
                }.contains(account.connectorType)) ...{
                  'chat': true,
                  'streaming': true,
                },
                if (const {
                  'openference',
                  'openference-api',
                }.contains(account.connectorType)) ...{
                  'chat': true,
                  'streaming': true,
                },
                if (account.connectorType == 'muse-code') ...{
                  'chat': true,
                  'streaming': true,
                },
                if (account.connectorType == 'vertex') ...{
                  'chat': vertexSupportsGenerateContent,
                  if (vertexSupportsStreaming) 'streaming': true,
                },
                if (methods is List) ...{
                  'supportedGenerationMethods': List<String>.from(
                    methods.whereType<String>(),
                  ),
                  if (methods.contains('generateContent') ||
                      methods.contains('streamGenerateContent'))
                    'chat': true,
                  if (methods.contains('streamGenerateContent'))
                    'streaming': true,
                },
                if (isGemini &&
                    providerCapabilities == null &&
                    methods is List &&
                    (methods.contains('generateContent') ||
                        methods.contains('streamGenerateContent')))
                  // Gemini's model catalog reports generation methods but
                  // omits a separate function-calling flag. Treat the
                  // generative Gemini model family as tool-capable unless
                  // provider capabilities explicitly say otherwise.
                  'tools': true,
                if (providerCapabilities == null &&
                    _catalogImpliesToolSupport(account.connectorType, modelId))
                  // OpenAI and Anthropic model catalogs omit function/tool
                  // support metadata. Infer only from model families whose
                  // public chat APIs support tool use; explicit metadata wins.
                  'tools': true,
                if (providerCapabilities is List)
                  for (final capability
                      in providerCapabilities.whereType<String>()) ...{
                    if (capability == 'completion') 'chat': true,
                    if (capability == 'completion') 'streaming': true,
                    if (capability == 'tools') 'tools': true,
                    if (capability == 'vision') 'vision': true,
                    if (capability == 'audio') 'audio': true,
                  },
                if (providerCapabilities is Map)
                  for (final entry in providerCapabilities.entries)
                    if (entry.value is bool &&
                        const {
                          'chat',
                          'streaming',
                          'tools',
                          'vision',
                          'audio',
                        }.contains(entry.key))
                      entry.key: entry.value as bool,
              },
              config: {
                'catalogSource': 'upstream_models_endpoint',
                'provider': account.connectorType,
                if (apiProtocolOverride is String)
                  'apiProtocolOverride': apiProtocolOverride,
                if (apiProtocolOverrideSource is String)
                  'apiProtocolOverrideSource': apiProtocolOverrideSource,
                'extensions': {account.connectorType: modelExtensions},
              },
            ),
          );
        }
        if (account.connectorType == 'openai-api' ||
            account.connectorType == 'claude') {
          if (data?['has_more'] == true) {
            final lastId = data?['last_id'];
            if (lastId is! String || lastId.isEmpty) {
              throw const LlmAccountConnectorException();
            }
            pageToken = lastId;
          } else {
            pageToken = null;
          }
        } else {
          final nextPageToken = data?['nextPageToken'];
          pageToken = nextPageToken is String && nextPageToken.isNotEmpty
              ? nextPageToken
              : null;
        }
        if (pageToken != null && !seenPageTokens.add(pageToken)) {
          throw const LlmAccountConnectorException();
        }
      } while (pageToken != null);
      return List.unmodifiable(models);
    } catch (_) {
      throw const LlmAccountConnectorException();
    }
  }

  Future<List<LlmUpstreamModel>> _discoverClineModels(
    LlmAccount account,
  ) async {
    const modelsUri = 'https://api.cline.bot/api/v1/ai/cline/models';
    const recommendedUri =
        'https://api.cline.bot/api/v1/ai/cline/recommended-models';
    final options = Options(
      headers: const {'Accept': 'application/json'},
      receiveTimeout: const Duration(seconds: 5),
    );
    final recommendedResponse = await _dio.getUri<Object?>(
      Uri.parse(recommendedUri),
      options: options,
    );
    final recommended = _asJsonMap(recommendedResponse.data);
    if (recommended == null) throw const LlmAccountConnectorException();

    final candidates = <Map<String, dynamic>>[];
    if (account.connectorType == 'clinepass') {
      final bucket = recommended['clinePass'];
      if (bucket is List) {
        candidates.addAll(
          bucket.whereType<Map>().map(Map<String, dynamic>.from),
        );
      }
    } else {
      for (final bucketName in ['recommended', 'free']) {
        final bucket = recommended[bucketName];
        if (bucket is List) {
          candidates.addAll(
            bucket.whereType<Map>().map(Map<String, dynamic>.from),
          );
        }
      }
      final fullResponse = await _dio.getUri<Object?>(
        Uri.parse(modelsUri),
        options: options,
      );
      final full = _asJsonMap(fullResponse.data);
      final rawFull = fullResponse.data is List
          ? fullResponse.data
          : full?['data'] ?? full?['models'];
      if (rawFull is List) {
        for (final raw in rawFull.whereType<Map>()) {
          final model = Map<String, dynamic>.from(raw);
          final architecture = model['architecture'];
          final modality =
              architecture is Map ? architecture['modality'] : null;
          if (modality is String &&
              modality.toLowerCase().split('->').last.trim() == 'text') {
            candidates.add(model);
          }
        }
      }
    }

    final seen = <String>{};
    final models = <LlmUpstreamModel>[];
    for (final candidate in candidates) {
      final rawId = candidate['id'];
      if (rawId is! String || rawId.trim().isEmpty) continue;
      final modelId = rawId.trim();
      if (account.connectorType == 'clinepass'
          ? !modelId.startsWith('cline-pass/')
          : modelId.startsWith('cline-pass/')) {
        continue;
      }
      if (!seen.add(modelId)) continue;
      final name = candidate['name'];
      models.add(
        LlmUpstreamModel(
          id: '${account.id}:cline:${models.length}',
          upstreamModelId: modelId,
          displayName:
              name is String && name.trim().isNotEmpty ? name.trim() : modelId,
          capabilities: const {'chat': true, 'streaming': true},
          config: const {
            'catalogSource': 'cline-public-catalog',
            'availability': 'account-dependent',
          },
        ),
      );
    }
    if (models.isNotEmpty) return List.unmodifiable(models);

    final fallback = account.connectorType == 'cline'
        ? kPinnedClineModels
        : kPinnedClinePassModels;
    return List.unmodifiable([
      for (final (index, modelId) in fallback.indexed)
        LlmUpstreamModel(
          id: '${account.id}:cline-fallback:$index',
          upstreamModelId: modelId,
          displayName: modelId,
          capabilities: const {'chat': true, 'streaming': true},
          config: const {
            'catalogSource': 'provider-fallback',
            'availability': 'unknown',
          },
        ),
    ]);
  }

  Future<List<LlmUpstreamModel>> _discoverBedrockModels(
    LlmAccount account,
  ) async {
    final region = LlmNativeRequestBuilder._configString(
      account.endpointConfig,
      'region',
    );
    if (region == null || !isValidAwsRegion(region)) {
      throw const LlmAccountConnectorException();
    }
    final secret = account.credentialRef == null
        ? null
        : await _readSecureValue(account.credentialRef!);
    final apiKey = account.authType == 'api_key'
        ? LlmNativeRequestBuilder._credentialValue(account, secret)
        : null;
    final awsCredentials =
        apiKey == null ? await _awsCredentialsFor(account, secret) : null;
    if (apiKey == null && awsCredentials == null) {
      throw const LlmAccountConnectorException();
    }
    final host = awsRegionalEndpointHost('bedrock', region);
    Map<String, String> headersFor(Uri uri) => apiKey != null
        ? {'Accept': 'application/json', 'Authorization': 'Bearer $apiKey'}
        : AwsSigV4.sign(
            method: 'GET',
            uri: uri,
            region: region,
            service: 'bedrock',
            headers: const {'Accept': 'application/json'},
            payload: Uint8List(0),
            credentials: awsCredentials!,
            now: DateTime.now().toUtc(),
          );

    Future<Map<String, dynamic>?> fetchPage(Uri uri) async {
      final response = await _dio.getUri<Object?>(
        uri,
        options: Options(headers: headersFor(uri)),
      );
      return _asJsonMap(response.data);
    }

    final foundationUri = Uri.https(host, '/foundation-models', {
      'byOutputModality': 'TEXT',
    });
    final inferenceProfileUri = Uri.https(host, '/inference-profiles', {
      'maxResults': '100',
      'typeEquals': 'SYSTEM_DEFINED',
    });
    try {
      final models = <LlmUpstreamModel>[];
      final seenModelIds = <String>{};

      Future<void> collectPages({
        required Uri baseUri,
        required String listKey,
        required void Function(Object? item) add,
      }) async {
        final seenPageTokens = <String>{};
        String? pageToken;
        var pageCount = 0;
        do {
          if (++pageCount > _maxModelDiscoveryPages) {
            throw const LlmAccountConnectorException();
          }
          final pageUri = pageToken == null
              ? baseUri
              : baseUri.replace(
                  queryParameters: {
                    ...baseUri.queryParameters,
                    'nextToken': pageToken,
                  },
                );
          final data = await fetchPage(pageUri);
          final entries = data?[listKey];
          if (entries is! List) {
            throw const LlmAccountConnectorException();
          }
          for (final item in entries) {
            add(item);
          }
          final nextPageToken = data?['nextToken'];
          pageToken = nextPageToken is String && nextPageToken.isNotEmpty
              ? nextPageToken
              : null;
          if (pageToken != null && !seenPageTokens.add(pageToken)) {
            throw const LlmAccountConnectorException();
          }
        } while (pageToken != null);
      }

      await collectPages(
        baseUri: foundationUri,
        listKey: 'modelSummaries',
        add: (raw) {
          if (raw is! Map) return;
          final item = Map<String, dynamic>.from(raw);
          final modelId = item['modelId'];
          final input = item['inputModalities'];
          final output = item['outputModalities'];
          if (modelId is! String ||
              modelId.trim().isEmpty ||
              input is! List ||
              output is! List ||
              !input.contains('TEXT') ||
              !output.contains('TEXT') ||
              !_isChatModel(modelId, item) ||
              (item['modelLifecycle'] is Map &&
                  (item['modelLifecycle'] as Map)['status'] != 'ACTIVE') ||
              !seenModelIds.add(modelId.trim())) {
            return;
          }
          models.add(
            LlmUpstreamModel(
              id: '${account.id}:remote:${models.length}',
              upstreamModelId: modelId.trim(),
              displayName: item['modelName'] is String
                  ? item['modelName'] as String
                  : modelId.trim(),
              capabilities: {
                'inputModalities': input.whereType<String>().toList(),
                'outputModalities': output.whereType<String>().toList(),
                'streaming': item['responseStreamingSupported'] == true,
              },
              config: const {'catalogSource': 'bedrock_foundation_models'},
            ),
          );
        },
      );
      final chatModelsById = {
        for (final model in models)
          if (model.config['catalogSource'] == 'bedrock_foundation_models')
            model.upstreamModelId: model,
      };
      try {
        await collectPages(
          baseUri: inferenceProfileUri,
          listKey: 'inferenceProfileSummaries',
          add: (raw) {
            if (raw is! Map) return;
            final item = Map<String, dynamic>.from(raw);
            final profileId = item['inferenceProfileId'];
            final profileModels = item['models'];
            if (profileModels is! List || profileModels.isEmpty) return;
            final backingModels = <LlmUpstreamModel>[];
            for (final profileModel in profileModels) {
              if (profileModel is! Map) return;
              final modelArn = profileModel['modelArn'];
              if (modelArn is! String ||
                  !modelArn.contains(':foundation-model/')) {
                return;
              }
              final modelId = modelArn.substring(modelArn.lastIndexOf('/') + 1);
              final backingModel = chatModelsById[modelId];
              if (backingModel == null) return;
              backingModels.add(backingModel);
            }
            if (profileId is! String ||
                profileId.trim().isEmpty ||
                (item['status'] is String && item['status'] != 'ACTIVE') ||
                (item['type'] is String && item['type'] != 'SYSTEM_DEFINED') ||
                !seenModelIds.add(profileId.trim())) {
              return;
            }
            models.add(
              LlmUpstreamModel(
                id: '${account.id}:remote:${models.length}',
                upstreamModelId: profileId.trim(),
                displayName: item['inferenceProfileName'] is String
                    ? item['inferenceProfileName'] as String
                    : profileId.trim(),
                capabilities: {
                  'chat': true,
                  'streaming': backingModels.every(
                    (model) => model.capabilities['streaming'] == true,
                  ),
                  'source': 'bedrock_inference_profile',
                },
                config: const {'catalogSource': 'bedrock_inference_profiles'},
              ),
            );
          },
        );
      } on DioException catch (error) {
        if (CancelToken.isCancel(error) || error.response?.statusCode == 401) {
          rethrow;
        }
        // Profile listing can be denied independently of model invocation.
        // Keep the account-derived foundation catalog in that case.
      } catch (_) {
        // A non-auth inference-profile failure does not invalidate models
        // already returned by Bedrock's foundation-model catalog.
      }
      return List.unmodifiable(models);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      if (account.authType == 'api_key' && error.response?.statusCode == 403) {
        // The pinned OmniRoute source uses Bearer for control-plane discovery,
        // but AWS's API-key docs do not enumerate model-list actions. If this
        // key is denied listing, keep manual choices for Runtime Converse.
        return List.unmodifiable(account.models);
      }
      throw const LlmAccountConnectorException();
    } catch (_) {
      throw const LlmAccountConnectorException();
    }
  }

  static Future<AwsSigV4Credentials?> _awsCredentialsFor(
    LlmAccount account,
    String? secret,
  ) async {
    if (account.authType == 'aws_credential_chain') {
      try {
        return await AwsCredentialChain.resolve();
      } catch (_) {
        throw const LlmAccountConnectorException();
      }
    }
    if (secret == null) return null;
    try {
      final decoded = jsonDecode(secret);
      if (decoded is! Map) throw const LlmAccountConnectorException();
      return AwsSigV4Credentials.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      throw const LlmAccountConnectorException();
    }
  }

  static bool _vertexServiceAccountTokenNeedsRefresh(String credential) {
    try {
      final decoded = jsonDecode(credential);
      if (decoded is! Map) return true;
      final bundle = Map<String, dynamic>.from(decoded);
      final token = LlmNativeRequestBuilder._credentialBundleString(
        credential,
        const ['access_token', 'accessToken'],
      );
      if (token == null) return true;
      final rawExpiry =
          bundle['expires_at'] ?? bundle['expiresAt'] ?? bundle['expiry_date'];
      DateTime? expiry;
      if (rawExpiry is String) {
        expiry = DateTime.tryParse(rawExpiry);
      } else if (rawExpiry is num && rawExpiry > 0) {
        final milliseconds = rawExpiry > 100000000000
            ? rawExpiry.toInt()
            : rawExpiry.toInt() * 1000;
        expiry = DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
      }
      return expiry == null ||
          !expiry.isAfter(
            DateTime.now().toUtc().add(const Duration(minutes: 1)),
          );
    } catch (_) {
      return true;
    }
  }

  static Uri _vertexModelListUri(
    Map<String, dynamic> config,
    String base,
    String? credential,
  ) {
    final project =
        LlmNativeRequestBuilder._configString(config, 'projectId') ??
            LlmNativeRequestBuilder._credentialBundleString(credential, const [
              'project_id',
              'projectId',
            ]);
    final location =
        LlmNativeRequestBuilder._vertexLocation(config) ?? 'us-central1';
    if (project == null ||
        project.isEmpty ||
        !RegExp(r'^(global|[a-z0-9-]+)$').hasMatch(location)) {
      throw const LlmAccountConnectorException();
    }
    final parent = 'projects/${Uri.encodeComponent(project)}'
        '/locations/${Uri.encodeComponent(location)}/publishers/google';
    return Uri.parse(base).replace(path: '/v1/$parent/models');
  }

  static String _vertexBaseUrl(Map<String, dynamic> config) {
    final location =
        LlmNativeRequestBuilder._vertexLocation(config) ?? 'us-central1';
    if (!RegExp(r'^(global|[a-z0-9-]+)$').hasMatch(location)) {
      throw const LlmAccountConnectorException();
    }
    return location == 'global'
        ? 'https://aiplatform.googleapis.com'
        : 'https://$location-aiplatform.googleapis.com';
  }

  static bool _isChatModel(String modelId, Map<String, dynamic> metadata) =>
      LlmConnectorRegistry.isConversationalModel(modelId, metadata);

  static bool _isOpenCodeStandardGatewayModelId(String modelId) {
    final normalized = modelId.trim().toLowerCase().replaceFirst(
          RegExp(r'^(?:opencode-go|opencode_go|opencode-zen|opencode)/'),
          '',
        );
    return !normalized.startsWith('gemini-') && !normalized.startsWith('jev-');
  }

  static bool _catalogImpliesToolSupport(String connectorType, String modelId) {
    if (connectorType == 'openai-api') {
      if (modelId.toLowerCase().startsWith('gpt-realtime')) return true;
      return RegExp(
        r'^(?:gpt-(?:3\.5-turbo|4\.5|4|4o|4\.1|5)(?:-|$)|o[134](?:-|$))',
        caseSensitive: false,
      ).hasMatch(modelId);
    }
    if (connectorType == 'claude') {
      return RegExp(
        r'^claude-(?:3|4|sonnet|opus|haiku)(?:-|$)',
        caseSensitive: false,
      ).hasMatch(modelId);
    }
    return false;
  }

  Future<String?> _readSecureValue(String reference) async {
    try {
      return await credentialStore.read(reference);
    } catch (_) {
      throw const LlmAccountConnectorException();
    }
  }

  static Map<String, dynamic>? _asJsonMap(Object? data) {
    try {
      final decoded = data is String ? jsonDecode(data) : data;
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static Uri _modelListUri(String base, {required bool isGemini}) {
    final parsed = Uri.tryParse(base.trim());
    if (parsed == null ||
        !parsed.hasScheme ||
        parsed.host.isEmpty ||
        parsed.userInfo.isNotEmpty ||
        (parsed.scheme != 'https' &&
            !(parsed.scheme == 'http' &&
                LlmNativeRequestBuilder._isLoopbackHost(parsed.host)))) {
      throw const LlmAccountConnectorException();
    }
    final path = parsed.path.replaceFirst(RegExp(r'/+$'), '');
    final suffix = isGemini ? '/v1beta/models' : '/models';
    final apiRoot = isGemini
        ? path
        : path.replaceFirst(RegExp(r'/(chat/completions|responses)$'), '');
    final requestPath = path.endsWith('/models')
        ? path
        : isGemini && path.endsWith('/v1beta')
            ? '$path/models'
            : '$apiRoot$suffix';
    return parsed.replace(path: requestPath, query: null, fragment: null);
  }

  static Uri _ollamaModelListUri(String base) {
    final parsed = Uri.tryParse(base.trim());
    if (parsed == null ||
        !parsed.hasScheme ||
        parsed.host.isEmpty ||
        parsed.userInfo.isNotEmpty ||
        (parsed.scheme != 'https' &&
            !(parsed.scheme == 'http' &&
                LlmNativeRequestBuilder._isLoopbackHost(parsed.host)))) {
      throw const LlmAccountConnectorException();
    }
    final basePath = parsed.path.replaceFirst(RegExp(r'/+$'), '');
    return parsed.replace(
      path: basePath.endsWith('/api/tags') ? basePath : '$basePath/api/tags',
      query: null,
      fragment: null,
    );
  }

  /// Adds or updates an account. Pass [secret] to replace its secure value;
  /// omit it to retain the existing value. API/OAuth/service-account secrets
  /// never enter the account's endpoint configuration or preference record.
  Future<LlmAccount> saveAccount(
    LlmAccount account, {
    String? secret,
    bool traeCallbackIssued = false,
  }) async {
    final lease =
        await LlmAccountMigrationService.acquireCredentialTransaction();
    String? reference;
    String? credentialToDelete;
    String? oldCredential;
    var credentialWasChanged = false;
    var credentialValueChanged = false;
    String? oldAccountJson;
    String? oldModelGroupsJson;
    var preferencesWriteAttempted = false;
    var modelGroupsWriteAttempted = false;
    var modelGroupsChanged = false;
    List<Map<String, dynamic>>? updatedModelGroups;
    try {
      account = _canonicalAccount(account);
      if (secret != null && account.connectorType == 'trae') {
        final credential = TraeSoloCredential.fromPastedValue(secret);
        final normalized =
            jsonDecode(credential.toStoredValue()) as Map<String, dynamic>;
        final providerData = Map<String, dynamic>.from(
          normalized['providerSpecificData'] as Map? ?? const {},
        );
        if (traeCallbackIssued && credential.refreshToken != null) {
          providerData['authMethod'] = 'oauth_callback';
        }
        normalized['providerSpecificData'] = providerData;
        secret = jsonEncode(normalized);
      }
      _validateAccount(account);
      if (secret != null) _validateCredential(account, secret);
      final currentRecords = await _readAccounts();
      oldAccountJson = await preferences.getString(
        LlmAccountMigrationService.accountsPreferenceKey,
      );
      final index = currentRecords.indexWhere(
        (record) => record['id'] == account.id,
      );
      final previous = index < 0 ? null : currentRecords[index];
      if (previous != null) {
        oldModelGroupsJson = await preferences.getString(
          LlmAccountMigrationService.modelGroupsPreferenceKey,
        );
        updatedModelGroups = await _readEnvelope(oldModelGroupsJson);
        modelGroupsChanged = _synchronizeGroupModelMappingsForAccount(
          previous: LlmAccount.fromMap(previous),
          updated: account,
          groups: updatedModelGroups,
        );
      }
      if (previous != null &&
          (previous['connectorType'] != account.connectorType ||
              modelGroupsChanged)) {
        final accountsAfterUpdate = <String, LlmAccount>{
          for (final record in currentRecords)
            if (record['id'] is String && record['id'] != account.id)
              record['id'] as String: LlmAccount.fromMap(record),
          account.id: account,
        };
        for (final record in updatedModelGroups ?? const []) {
          final group = LlmModelGroup.fromMap(record);
          if (group.members.any((member) => member.accountId == account.id)) {
            _validateModelGroupMembers(group, accountsAfterUpdate);
          }
        }
      }
      final previousReference = previous?['credentialRef'] as String?;
      if (previous != null &&
          (previous['authType'] != account.authType ||
              previous['connectorType'] != account.connectorType) &&
          _requiresSecret(account.authType) &&
          secret == null) {
        throw const LlmAccountConnectorException();
      }
      if (account.credentialRef != null && previousReference == null) {
        throw const LlmAccountConnectorException();
      }
      if (previousReference != null &&
          account.credentialRef != null &&
          account.credentialRef != previousReference) {
        throw const LlmAccountConnectorException();
      }
      reference = account.credentialRef ??
          previousReference ??
          _newCredentialReference(account.id);
      final otherOwners = currentRecords
          .where(
            (record) =>
                record['id'] != account.id &&
                record['credentialRef'] == reference,
          )
          .toList(growable: false);
      if (otherOwners.isNotEmpty && secret != null) {
        if (previousReference != reference) {
          throw const LlmAccountConnectorException();
        }
        reference = _newUniqueCredentialReference(account.id, currentRecords);
      } else if (otherOwners.isNotEmpty && previousReference != reference) {
        throw const LlmAccountConnectorException();
      }
      if (_requiresSecret(account.authType) &&
          secret == null &&
          account.credentialRef == null &&
          previous?['credentialRef'] == null) {
        throw const LlmAccountConnectorException();
      }
      if (secret != null && !_requiresSecret(account.authType)) {
        throw const LlmAccountConnectorException();
      }
      if (!_requiresSecret(account.authType) && previousReference != null) {
        final stillOwned = currentRecords.any(
          (record) =>
              record['id'] != account.id &&
              record['credentialRef'] == previousReference,
        );
        if (!stillOwned) {
          credentialToDelete = previousReference;
        }
      }

      if (secret != null) {
        if (secret.trim().isEmpty) {
          throw const LlmAccountConnectorException();
        }
        oldCredential = await credentialStore.read(reference);
        credentialValueChanged = oldCredential != secret;
        credentialWasChanged = true;
        await credentialStore.write(reference, secret);
        if (await credentialStore.read(reference) != secret) {
          throw const LlmAccountConnectorException();
        }
      } else if (_requiresSecret(account.authType)) {
        if (await credentialStore.read(reference) == null) {
          throw const LlmAccountConnectorException();
        }
      } else if (credentialToDelete != null) {
        oldCredential = await credentialStore.read(credentialToDelete);
      }

      final savedRecord = <String, dynamic>{...?previous, ...account.toMap()};
      if (previous != null) {
        final endpointConfigChanged =
            jsonEncode(previous['endpointConfig'] ?? const {}) !=
                jsonEncode(account.endpointConfig);
        final connectionIdentityChanged =
            previous['connectorType'] != account.connectorType ||
                previous['authType'] != account.authType ||
                endpointConfigChanged ||
                credentialValueChanged;
        if (connectionIdentityChanged) {
          // Provider quota belongs to the old connection and must not affect
          // routing or the account UI after its connector changes.
          savedRecord['usageByWindow'] = const <String, dynamic>{};
          savedRecord['remainingQuota'] =
              LlmMetricObservation.unknown().toMap();
          savedRecord['quotaSignals'] = const <String, dynamic>{};
        } else {
          // Account settings dialogs can stay open while requests record newer
          // telemetry. Preserve those latest observations for the same
          // connection instead of replaying the dialog snapshot.
          for (final key in const [
            'usageByWindow',
            'remainingQuota',
            'quotaSignals',
          ]) {
            if (previous.containsKey(key)) savedRecord[key] = previous[key];
          }
        }
      }
      if (_requiresSecret(account.authType)) {
        savedRecord['credentialRef'] = reference;
      } else {
        savedRecord.remove('credentialRef');
      }
      if (index < 0) {
        currentRecords.add(savedRecord);
      } else {
        currentRecords[index] = savedRecord;
      }
      final encoded = _encodeEnvelope(currentRecords);
      preferencesWriteAttempted = true;
      if (!await preferences.setString(
        LlmAccountMigrationService.accountsPreferenceKey,
        encoded,
      )) {
        throw const LlmAccountConnectorException();
      }
      if (await preferences.getString(
            LlmAccountMigrationService.accountsPreferenceKey,
          ) !=
          encoded) {
        throw const LlmAccountConnectorException();
      }
      if (modelGroupsChanged) {
        final encodedGroups = _encodeEnvelope(updatedModelGroups!);
        modelGroupsWriteAttempted = true;
        if (!await preferences.setString(
              LlmAccountMigrationService.modelGroupsPreferenceKey,
              encodedGroups,
            ) ||
            await preferences.getString(
                  LlmAccountMigrationService.modelGroupsPreferenceKey,
                ) !=
                encodedGroups) {
          throw const LlmAccountConnectorException();
        }
      }
      if (credentialToDelete != null) {
        credentialWasChanged = true;
        await credentialStore.delete(credentialToDelete);
        if (await credentialStore.read(credentialToDelete) != null) {
          throw const LlmAccountConnectorException();
        }
      }
      return LlmAccount.fromMap(savedRecord);
    } catch (_) {
      if (modelGroupsWriteAttempted) {
        await _restorePreference(
          LlmAccountMigrationService.modelGroupsPreferenceKey,
          oldModelGroupsJson,
        );
      }
      if (preferencesWriteAttempted) {
        await _restorePreference(
          LlmAccountMigrationService.accountsPreferenceKey,
          oldAccountJson,
        );
      }
      if (credentialWasChanged && reference != null) {
        await _restoreCredential(reference, oldCredential);
      }
      throw const LlmAccountConnectorException();
    } finally {
      lease.release();
    }
  }

  /// Stores quota observations reported by a connector request.
  ///
  /// Named time-window signals also update [LlmAccount.usageByWindow] so the
  /// routing policy and account UI can consume the same observation. Unknown
  /// or older values never erase a previously reported observation.
  Future<void> recordQuotaObservation({
    required String accountId,
    required LlmMetricObservation remainingQuota,
    required Map<String, LlmMetricObservation> quotaSignals,
  }) async {
    final validSignals = <String, LlmMetricObservation>{
      for (final entry in quotaSignals.entries)
        if (_isPersistableQuotaMetric(entry.value)) entry.key: entry.value,
    };
    final validRemainingQuota = _isPersistableQuotaMetric(remainingQuota)
        ? remainingQuota
        : const LlmMetricObservation.unknown();
    if (!validRemainingQuota.isKnown && validSignals.isEmpty) return;

    final lease =
        await LlmAccountMigrationService.acquireCredentialTransaction();
    final key = LlmAccountMigrationService.accountsPreferenceKey;
    String? previous;
    var writeAttempted = false;
    try {
      if (accountId.trim().isEmpty) {
        throw const LlmAccountConnectorException();
      }
      previous = await preferences.getString(key);
      final records = await _readEnvelope(previous);
      final index = records.indexWhere((record) => record['id'] == accountId);
      if (index < 0) return;

      final existingRecord = records[index];
      final account = LlmAccount.fromMap(existingRecord);
      final nextRemainingQuota = _preferNewerQuotaMetric(
        account.remainingQuota,
        validRemainingQuota,
      );
      final nextQuotaSignals = Map<String, LlmMetricObservation>.from(
        account.quotaSignals,
      );
      final nextUsageByWindow = Map<LlmUsageWindow, LlmUsageWindowState>.from(
        account.usageByWindow,
      );
      const windowBySignal = {
        'primaryRemainingPercent': LlmUsageWindow.fiveHour,
        'dailyRemainingPercent': LlmUsageWindow.day,
        'secondaryRemainingPercent': LlmUsageWindow.week,
        'weeklyRemainingPercent': LlmUsageWindow.week,
        'monthlyRemainingPercent': LlmUsageWindow.month,
      };
      var changed = jsonEncode(nextRemainingQuota.toMap()) !=
          jsonEncode(account.remainingQuota.toMap());
      for (final entry in validSignals.entries) {
        final current =
            nextQuotaSignals[entry.key] ?? const LlmMetricObservation.unknown();
        final selected = _preferNewerQuotaMetric(current, entry.value);
        if (jsonEncode(selected.toMap()) != jsonEncode(current.toMap())) {
          nextQuotaSignals[entry.key] = selected;
          changed = true;
        }
        final window = windowBySignal[entry.key];
        if (window == null) continue;
        final windowState =
            nextUsageByWindow[window] ?? const LlmUsageWindowState();
        final nextRemaining = _preferNewerQuotaMetric(
          windowState.remaining,
          entry.value,
        );
        if (jsonEncode(nextRemaining.toMap()) ==
            jsonEncode(windowState.remaining.toMap())) {
          continue;
        }
        nextUsageByWindow[window] = LlmUsageWindowState(
          quota: windowState.quota,
          used: windowState.used,
          remaining: nextRemaining,
          resetAt: nextRemaining.resetAt,
          source: nextRemaining.source,
        );
        changed = true;
      }
      if (!changed) return;

      final updated = LlmAccount(
        id: account.id,
        connectorType: account.connectorType,
        authType: account.authType,
        displayName: account.displayName,
        status: account.status,
        credentialRef: account.credentialRef,
        endpointConfig: account.endpointConfig,
        models: account.models,
        policy: account.policy,
        usageByWindow: nextUsageByWindow,
        remainingQuota: nextRemainingQuota,
        quotaSignals: nextQuotaSignals,
      );
      records[index] = {...existingRecord, ...updated.toMap()};
      final encoded = _encodeEnvelope(records);
      writeAttempted = true;
      if (!await preferences.setString(key, encoded) ||
          await preferences.getString(key) != encoded) {
        throw const LlmAccountConnectorException();
      }
    } catch (_) {
      if (writeAttempted) await _restorePreference(key, previous);
      throw const LlmAccountConnectorException();
    } finally {
      lease.release();
    }
  }

  /// Deletes an account, an unshared secure credential and its group members.
  /// Stable model-group IDs are retained even when the removed account was the
  /// last member so callers can decide how to repair the group.
  Future<void> deleteAccount(String accountId) async {
    ZedHostedApiClient.clearAccountTokenCache(accountId);
    final lease =
        await LlmAccountMigrationService.acquireCredentialTransaction();
    final preferenceKeys = [
      LlmAccountMigrationService.accountsPreferenceKey,
      LlmAccountMigrationService.modelGroupsPreferenceKey,
    ];
    final snapshots = <String, String?>{};
    String? credentialReference;
    String? credentialValue;
    var preferenceWriteAttempted = false;
    try {
      if (accountId.trim().isEmpty) {
        throw const LlmAccountConnectorException();
      }
      for (final key in preferenceKeys) {
        snapshots[key] = await preferences.getString(key);
      }
      final accounts = await _readEnvelope(snapshots[preferenceKeys[0]]);
      final groups = await _readEnvelope(snapshots[preferenceKeys[1]]);
      final accountIndex = accounts.indexWhere(
        (item) => item['id'] == accountId,
      );
      if (accountIndex < 0) return;
      final removed = accounts.removeAt(accountIndex);
      credentialReference = removed['credentialRef'] as String?;
      if (credentialReference != null) {
        credentialValue = await credentialStore.read(credentialReference);
      }
      var groupsChanged = false;
      for (final group in groups) {
        final rawMembers = group['members'];
        if (rawMembers is! List) continue;
        final removedMembers = rawMembers
            .whereType<Map>()
            .where((member) => member['accountId'] == accountId)
            .toList(growable: false);
        String? removedStableLocalModelId;
        if (group['id'] is String) {
          final groupId = group['id'] as String;
          final models = removed['models'];
          for (final member in removedMembers) {
            final localModelId = member['localModelId'];
            if (localModelId is! String ||
                groupId != _modelGroupId(accountId, localModelId)) {
              continue;
            }
            removedStableLocalModelId = localModelId;
            if (group['legacyProviderName'] == null &&
                removed['displayName'] is String &&
                (removed['displayName'] as String).isNotEmpty) {
              group['legacyProviderName'] = removed['displayName'];
              groupsChanged = true;
            }
            if (group['legacyModelId'] == null && models is List) {
              final model = models
                  .whereType<Map>()
                  .where((item) => item['id'] == localModelId)
                  .firstOrNull;
              final legacyModelId = model?['upstreamModelId'];
              if (legacyModelId is String && legacyModelId.isNotEmpty) {
                group['legacyModelId'] = legacyModelId;
                groupsChanged = true;
              }
            }
            break;
          }
        }
        final members = rawMembers
            .whereType<Map>()
            .where((member) => member['accountId'] != accountId)
            .toList();
        if (members.length != rawMembers.length) {
          if (removedStableLocalModelId != null &&
              members.isNotEmpty &&
              !members.any(
                (member) => member['localModelId'] == removedStableLocalModelId,
              )) {
            // Keep both identities available: old conversations use the
            // anchor's local ID, while the fallback member may already have
            // saved references to its own local alias.
            members.add({
              ...Map<String, dynamic>.from(members.first),
              'localModelId': removedStableLocalModelId,
            });
          }
          group['members'] = members;
          groupsChanged = true;
        }
      }

      final encodedAccounts = _encodeEnvelope(accounts);
      final encodedGroups = _encodeEnvelope(groups);
      preferenceWriteAttempted = true;
      if (!await preferences.setString(preferenceKeys[0], encodedAccounts) ||
          (groupsChanged &&
              !await preferences.setString(preferenceKeys[1], encodedGroups))) {
        throw const LlmAccountConnectorException();
      }
      if (await preferences.getString(preferenceKeys[0]) != encodedAccounts ||
          (groupsChanged &&
              await preferences.getString(preferenceKeys[1]) !=
                  encodedGroups)) {
        throw const LlmAccountConnectorException();
      }
      final hasRemainingOwner = credentialReference != null &&
          accounts.any(
            (record) => record['credentialRef'] == credentialReference,
          );
      if (credentialReference != null && !hasRemainingOwner) {
        await credentialStore.delete(credentialReference);
        if (await credentialStore.read(credentialReference) != null) {
          throw const LlmAccountConnectorException();
        }
      }
    } catch (_) {
      if (preferenceWriteAttempted) {
        for (final entry in snapshots.entries) {
          await _restorePreference(entry.key, entry.value);
        }
      }
      if (credentialReference != null && credentialValue != null) {
        await _restoreCredential(credentialReference, credentialValue);
      }
      throw const LlmAccountConnectorException();
    } finally {
      lease.release();
    }
  }

  String _modelGroupId(String accountId, String localModelId) {
    final encodedAccountId = Uri.encodeComponent(accountId);
    final encodedLocalModelId = Uri.encodeComponent(localModelId);
    return 'stroom.model-group.${encodedAccountId.length}:$encodedAccountId'
        '${encodedLocalModelId.length}:$encodedLocalModelId';
  }

  Future<List<Map<String, dynamic>>> _readAccounts() async {
    final records = await _readEnvelope(
      await preferences.getString(
        LlmAccountMigrationService.accountsPreferenceKey,
      ),
    );
    for (final record in records) {
      final rawType = record['connectorType'];
      if (rawType is! String) continue;
      final canonicalType = LlmConnectorRegistry.canonicalId(rawType);
      if (canonicalType == rawType) continue;
      record['connectorType'] = canonicalType;
      final rawConfig = record['endpointConfig'];
      final config = rawConfig is Map
          ? Map<String, dynamic>.from(rawConfig)
          : <String, dynamic>{};
      if ((canonicalType == 'claude' ||
              canonicalType == 'openai-compatibility') &&
          config['baseUrl'] == null &&
          config['host'] is String &&
          (config['host'] as String).trim().isNotEmpty) {
        config['baseUrl'] = (config['host'] as String).trim();
      }
      record['endpointConfig'] = config;
    }
    return records;
  }

  Future<List<Map<String, dynamic>>> _readEnvelope(String? encoded) async {
    if (encoded == null || encoded.isEmpty) return [];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map || decoded['items'] is! List) {
        throw const LlmAccountConnectorException();
      }
      final records = <Map<String, dynamic>>[];
      final ids = <String>{};
      for (final item in decoded['items'] as List) {
        if (item is! Map) throw const LlmAccountConnectorException();
        final record = Map<String, dynamic>.from(item);
        final id = record['id'];
        if (id is! String || id.isEmpty || !ids.add(id)) {
          throw const LlmAccountConnectorException();
        }
        records.add(record);
      }
      return records;
    } on LlmAccountConnectorException {
      rethrow;
    } catch (_) {
      throw const LlmAccountConnectorException();
    }
  }

  String _newCredentialReference(String accountId) =>
      'stroom.llm.credential.${Uri.encodeComponent(accountId)}';

  String _newUniqueCredentialReference(
    String accountId,
    List<Map<String, dynamic>> records,
  ) {
    final existing = records
        .map((record) => record['credentialRef'])
        .whereType<String>()
        .toSet();
    String reference;
    do {
      reference =
          '${_newCredentialReference(accountId)}.rotation.${const Uuid().v4()}';
    } while (existing.contains(reference));
    return reference;
  }

  static LlmAccount _canonicalAccount(LlmAccount account) {
    final connectorType = LlmConnectorRegistry.canonicalId(
      account.connectorType,
    );
    if (connectorType == account.connectorType) return account;
    final endpointConfig = Map<String, dynamic>.from(account.endpointConfig);
    if ((connectorType == 'claude' ||
            connectorType == 'openai-compatibility') &&
        endpointConfig['baseUrl'] == null &&
        endpointConfig['host'] is String &&
        (endpointConfig['host'] as String).trim().isNotEmpty) {
      endpointConfig['baseUrl'] = (endpointConfig['host'] as String).trim();
    }
    return LlmAccount(
      id: account.id,
      connectorType: connectorType,
      authType: account.authType,
      displayName: account.displayName,
      status: account.status,
      credentialRef: account.credentialRef,
      endpointConfig: endpointConfig,
      models: account.models,
      policy: account.policy,
      usageByWindow: account.usageByWindow,
      remainingQuota: account.remainingQuota,
      quotaSignals: account.quotaSignals,
    );
  }

  Future<void> _restorePreference(String key, String? oldValue) async {
    try {
      if (oldValue == null) {
        await preferences.remove(key);
      } else {
        await preferences.setString(key, oldValue);
      }
    } catch (_) {
      // Keep the public error generic; the credential remains in secure storage
      // if rollback cannot safely establish the former state.
    }
  }

  Future<void> _restoreCredential(String reference, String? oldValue) async {
    try {
      if (oldValue == null) {
        await credentialStore.delete(reference);
      } else {
        await credentialStore.write(reference, oldValue);
        if (await credentialStore.read(reference) != oldValue) return;
      }
    } catch (_) {
      // Storage exception text may contain provider data; never forward it.
    }
  }

  static String _encodeEnvelope(List<Map<String, dynamic>> items) =>
      jsonEncode({'version': 1, 'items': items});

  static bool _requiresSecret(String authType) =>
      authType == 'api_key' ||
      authType == 'oauth' ||
      authType == 'setup_token' ||
      authType == 'pat' ||
      authType == 'service_account' ||
      authType == 'session_token' ||
      authType == 'aws_credentials';

  static void _validateAccount(LlmAccount account) {
    final connector = LlmConnectorRegistry.find(account.connectorType);
    if (account.id.trim().isEmpty ||
        account.displayName.trim().isEmpty ||
        connector == null ||
        connector.id !=
            LlmConnectorRegistry.canonicalId(account.connectorType) ||
        !connector.authTypes.contains(account.authType)) {
      throw const LlmAccountConnectorException();
    }
    if (account.connectorType == 'vertex' && account.authType == 'oauth') {
      throw const LlmAccountConnectorException();
    }
    if (account.connectorType == 'qoder' && account.authType == 'oauth') {
      try {
        for (final key in const [
          'qoderLoginUrl',
          'qoderExchangeUrl',
          'qoderUserInfoUrl',
        ]) {
          final value = account.endpointConfig[key];
          if (value is! String) throw const FormatException();
          LlmOAuthAuthorizationAttempt.validateQoderOAuthEndpoint(value);
        }
        final clientId = account.endpointConfig['qoderClientId'];
        if (clientId is! String || clientId.trim().isEmpty) {
          throw const FormatException();
        }
      } catch (_) {
        throw const LlmAccountConnectorException();
      }
    }
    if (account.connectorType == 'qoder' &&
        account.authType == 'pat' &&
        account.endpointConfig.containsKey('baseUrl')) {
      throw const LlmAccountConnectorException();
    }
    if (account.connectorType == 'gitlab-duo' && account.authType == 'oauth') {
      final clientId = account.endpointConfig['clientId'];
      final baseUrl = account.endpointConfig['baseUrl'];
      if (clientId is! String || clientId.trim().isEmpty) {
        throw const LlmAccountConnectorException();
      }
      try {
        LlmOAuthAuthorizationAttempt.validateGitLabDuoBaseUrl(
          baseUrl is String ? baseUrl : '',
        );
      } catch (_) {
        throw const LlmAccountConnectorException();
      }
    }
    _validateSafeConfig(account.endpointConfig);
    if (account.connectorType == 'bedrock') {
      final region = account.endpointConfig['region'];
      if (region is! String || !isValidAwsRegion(region)) {
        throw const LlmAccountConnectorException();
      }
    }
    if (account.connectorType == 'vertex') {
      final location = account.endpointConfig['location'] ??
          account.endpointConfig['region'];
      if (location != null &&
          (location is! String ||
              !RegExp(r'^(global|[a-z0-9-]+)$').hasMatch(location))) {
        throw const LlmAccountConnectorException();
      }
    }
    for (final model in account.models) {
      _validateCredentialFreeModelData(model.capabilities);
      _validateCredentialFreeModelData(model.config);
    }
  }

  static void _validateCredential(LlmAccount account, String secret) {
    if (account.connectorType == 'amazon-q' && account.authType == 'oauth') {
      try {
        AmazonQConnector.parseCredentialImport(secret);
      } catch (_) {
        throw const LlmAccountConnectorException();
      }
      return;
    }
    if (account.connectorType == 'qoder' && account.authType == 'pat') {
      if (!secret.trim().startsWith('pt-')) {
        throw const LlmAccountConnectorException();
      }
      return;
    }
    if (account.connectorType == 'bedrock' &&
        account.authType == 'aws_credentials') {
      try {
        final decoded = jsonDecode(secret);
        if (decoded is! Map) throw const FormatException();
        AwsSigV4Credentials.fromJson(Map<String, dynamic>.from(decoded));
      } catch (_) {
        throw const LlmAccountConnectorException();
      }
      return;
    }
    if (account.connectorType != 'vertex' ||
        account.authType != 'service_account') {
      return;
    }
    try {
      final decoded = jsonDecode(secret);
      final serviceAccount = decoded is Map && decoded['service_account'] is Map
          ? decoded['service_account']
          : decoded;
      ServiceAccountCredentials.fromJson(serviceAccount);
    } catch (_) {
      throw const LlmAccountConnectorException();
    }
  }

  static void _validateSafeConfig(Object? value) {
    const forbiddenKeys = {
      'key',
      'apikey',
      'accesskey',
      'accesstoken',
      'refreshtoken',
      'token',
      'secret',
      'password',
      'authorization',
      'credential',
      'privatekey',
      'clientsecret',
      'cookie',
      'sig',
      'signature',
    };
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
        final providerAuthMetadata = const {
          'apikeyheader',
          'apikeyscheme',
        }.contains(normalized);
        if (!providerAuthMetadata &&
            (forbiddenKeys.contains(normalized) ||
                normalized.endsWith('key') ||
                normalized.endsWith('sig') ||
                normalized.contains('apikey') ||
                normalized.contains('accesskey') ||
                normalized.contains('token') ||
                normalized.contains('secret') ||
                normalized.contains('password') ||
                normalized.contains('auth') ||
                normalized.contains('credential') ||
                normalized.contains('authorization') ||
                normalized.contains('privatekey') ||
                normalized.contains('signature') ||
                normalized.contains('cookie'))) {
          throw const LlmAccountConnectorException();
        }
        if (normalized == 'apikeyheader' &&
            (entry.value is! String ||
                !LlmNativeRequestBuilder._isValidHeaderName(
                  entry.value as String,
                ))) {
          throw const LlmAccountConnectorException();
        }
        if (normalized == 'apikeyscheme' &&
            (entry.value is! String ||
                !LlmNativeRequestBuilder._isValidHeaderValue(
                  entry.value as String,
                ))) {
          throw const LlmAccountConnectorException();
        }
        if ((normalized == 'baseurl' || normalized == 'modelsurl') &&
            entry.value is String) {
          final uri = Uri.tryParse((entry.value as String).trim());
          if (uri == null || uri.userInfo.isNotEmpty || uri.hasFragment) {
            throw const LlmAccountConnectorException();
          }
          const sensitiveQueryKeys = {
            'key',
            'apikey',
            'accesskey',
            'accesstoken',
            'refreshtoken',
            'token',
            'secret',
            'password',
            'authorization',
            'credential',
            'sig',
            'signature',
          };
          if (uri.queryParameters.keys.any((key) {
            final normalizedQueryKey = key.toLowerCase().replaceAll(
                  RegExp(r'[^a-z]'),
                  '',
                );
            return sensitiveQueryKeys.contains(normalizedQueryKey) ||
                normalizedQueryKey.contains('apikey') ||
                normalizedQueryKey.contains('accesskey') ||
                normalizedQueryKey.contains('token') ||
                normalizedQueryKey.contains('secret') ||
                normalizedQueryKey.contains('password') ||
                normalizedQueryKey.contains('auth') ||
                normalizedQueryKey.contains('authorization') ||
                normalizedQueryKey.contains('credential') ||
                normalizedQueryKey.contains('privatekey') ||
                normalizedQueryKey.contains('signature') ||
                normalizedQueryKey.endsWith('key') ||
                normalizedQueryKey.endsWith('sig') ||
                normalizedQueryKey.contains('cookie');
          })) {
            throw const LlmAccountConnectorException();
          }
        }
        _validateSafeConfig(entry.value);
      }
    } else if (value is Iterable && value is! String) {
      for (final item in value) {
        _validateSafeConfig(item);
      }
    }
  }

  static void _validateCredentialFreeModelData(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        final normalized = entry.key.toString().toLowerCase().replaceAll(
              RegExp(r'[^a-z]'),
              '',
            );
        if (normalized == 'key' ||
            normalized.endsWith('key') ||
            normalized == 'token' ||
            normalized.startsWith('token') ||
            normalized.endsWith('token') ||
            normalized.endsWith('sig') ||
            normalized.contains('signature') ||
            normalized.contains('apikey') ||
            normalized.contains('accesskey') ||
            normalized.contains('secret') ||
            normalized.contains('password') ||
            normalized.contains('auth') ||
            normalized.contains('authorization') ||
            normalized.contains('credential') ||
            normalized.contains('privatekey') ||
            normalized.contains('cookie')) {
          throw const LlmAccountConnectorException();
        }
        if ({'baseurl', 'endpointurl', 'url'}.contains(normalized) &&
            entry.value is String) {
          _validateSafeConfig({'baseUrl': entry.value});
        }
        _validateCredentialFreeModelData(entry.value);
      }
    } else if (value is Iterable && value is! String) {
      for (final item in value) {
        _validateCredentialFreeModelData(item);
      }
    }
  }
}

/// Prepared native request. Its diagnostic string omits header values and the
/// body because both may contain secrets or private prompt content.
class LlmPreparedNativeRequest {
  final Uri uri;
  final String method;
  final Map<String, String> headers;
  final Object? body;
  final Map<String, Uint8List> requestBlobs;

  LlmPreparedNativeRequest({
    required this.uri,
    required this.method,
    required Map<String, String> headers,
    required this.body,
    Map<String, Uint8List> requestBlobs = const {},
  })  : headers = Map.unmodifiable(headers),
        requestBlobs = Map.unmodifiable(requestBlobs);

  @override
  String toString() {
    final safeUri = uri.replace(
      userInfo: uri.userInfo.isEmpty ? '' : '<redacted>',
      path: uri.path.isEmpty ? '' : '/<redacted>',
      query: uri.hasQuery ? '<redacted>' : null,
      fragment: null,
    );
    return 'LlmPreparedNativeRequest(method: $method, uri: $safeUri, '
        'headerNames: ${headers.keys.toList()}, body: <omitted>)';
  }
}

/// Builds provider-native HTTP request paths and authentication headers from
/// account data. Request bodies are already in that connector's native format;
/// this class does not translate between client protocols.
class LlmNativeRequestBuilder {
  static const _defaultJsonHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  static bool _isValidHeaderName(String value) =>
      RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$").hasMatch(value);

  static bool _isValidHeaderValue(String value) =>
      !RegExp(r'[\x00-\x1F\x7F]').hasMatch(value);

  static void _validateRequestHeader(String name, String value) {
    if (!_isValidHeaderName(name) || !_isValidHeaderValue(value)) {
      throw const LlmAccountConnectorException();
    }
  }

  static void _applyConfiguredApiKeyHeader(
    Map<String, String> headers,
    Map<String, dynamic> endpointConfig,
    String apiKey,
  ) {
    final presetId = endpointConfig['providerPresetId'];
    final preset = findLlmOpenAiProviderPreset(
      presetId is String ? presetId : null,
    );
    final configuredName = endpointConfig['apiKeyHeader'];
    final headerName = configuredName is String
        ? configuredName
        : preset?.authorizationHeader ?? 'Authorization';
    final configuredScheme = endpointConfig['apiKeyScheme'];
    final scheme = configuredScheme is String
        ? configuredScheme
        : preset?.authorizationScheme ?? 'Bearer';
    if (!_isValidHeaderName(headerName) ||
        !_isValidHeaderValue(scheme) ||
        !_isValidHeaderValue(apiKey)) {
      throw const LlmAccountConnectorException();
    }
    final lowerName = headerName.toLowerCase();
    headers.removeWhere((name, _) {
      final lowerExisting = name.toLowerCase();
      return lowerExisting == lowerName ||
          (lowerName != 'authorization' && lowerExisting == 'authorization');
    });
    headers[headerName] = scheme.isEmpty ? apiKey : '$scheme $apiKey';
  }

  static String? credentialBundleString(
    String? credential,
    List<String> keys,
  ) =>
      _credentialBundleString(credential, keys);

  LlmPreparedNativeRequest build({
    required LlmAccount account,
    required String? credential,
    required String modelId,
    required Object? body,
    String? conversationId,
    AwsSigV4Credentials? awsCredentials,
    bool stream = false,
    String? nativeFormat,
    String? zedLlmToken,
  }) {
    final connector = LlmConnectorRegistry.find(account.connectorType);
    if (account.connectorType == 'zed-hosted') {
      final model = account.models
          .where((item) => item.upstreamModelId == modelId)
          .firstOrNull;
      if (connector?.id != 'zed-hosted' ||
          account.authType != 'oauth' ||
          _credentialBundleString(credential, const ['oauth_contract']) !=
              'zed-hosted-native-rsa-v1' ||
          _credentialBundleString(credential, const ['user_id', 'userId']) ==
              null ||
          _credentialBundleString(credential, const [
                'access_token',
                'accessToken',
              ]) ==
              null ||
          _credentialBundleString(credential, const [
                'system_id',
                'systemId',
              ]) ==
              null ||
          model == null ||
          zedLlmToken == null ||
          zedLlmToken.isEmpty) {
        throw const LlmAccountConnectorException();
      }
      final envelope = buildZedHostedCompletionEnvelope(
        model: model,
        body: body,
        nativeFormat: nativeFormat,
        stream: stream,
        conversationId: conversationId,
      );
      return LlmPreparedNativeRequest(
        uri: Uri.parse('https://cloud.zed.dev/completions'),
        method: 'POST',
        headers: {
          'Accept': 'application/x-ndjson, text/event-stream, */*',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $zedLlmToken',
          'User-Agent': 'Stroom/zed-hosted',
          'x-zed-client-supports-status-messages': 'true',
          'x-zed-client-supports-stream-ended-request-completion-status':
              'true',
        },
        body: jsonEncode(envelope),
      );
    }
    if (account.connectorType == 'cursor') {
      final accessToken = _credentialBundleString(credential, const [
        'access_token',
        'accessToken',
      ]);
      final apiKey = account.authType == 'api_key' ? credential?.trim() : null;
      if (!{'oauth', 'api_key'}.contains(account.authType) ||
          nativeFormat != null ||
          !account.models.any((model) => model.upstreamModelId == modelId) ||
          !kPinnedCursorModels.contains(modelId) ||
          (account.authType == 'oauth' && accessToken == null) ||
          (account.authType == 'api_key' && apiKey == null) ||
          body is! Map) {
        throw const LlmAccountConnectorException();
      }
      try {
        final requestBlobs = <String, Uint8List>{};
        final requestBody = CursorConnectFrameDecoder.encodeRequest(
          modelId: modelId,
          conversationId: conversationId?.trim().isNotEmpty == true
              ? conversationId!.trim()
              : const Uuid().v4(),
          body: Map<String, dynamic>.from(body),
          blobStore: requestBlobs,
        );
        return LlmPreparedNativeRequest(
          // The runtime resolves the assigned Agent URL before opening HTTP/2.
          uri: Uri.parse(cursorServerConfigUrl),
          method: 'POST',
          headers: const {'content-type': 'application/connect+proto'},
          body: requestBody,
          requestBlobs: requestBlobs,
        );
      } on CursorConnectRpcException {
        rethrow;
      }
    }
    if (connector == null ||
        connector.id != account.connectorType ||
        !connector.authTypes.contains(account.authType) ||
        (account.connectorType == 'clova-studio' && nativeFormat != 'clova') ||
        (account.connectorType == 'aihorde' &&
            nativeFormat != null &&
            nativeFormat != 'openai.chat_completions') ||
        (account.connectorType == 'uncloseai' && nativeFormat != null) ||
        ((account.connectorType == 'cline' ||
                account.connectorType == 'clinepass') &&
            nativeFormat != null) ||
        (account.connectorType == 'gitlab-duo' &&
            nativeFormat != null &&
            nativeFormat != 'openai.chat_completions') ||
        (account.connectorType == 'gitlab-duo' &&
            !kPinnedGitLabDuoModels.contains(modelId)) ||
        (account.connectorType == 'qoder' && account.authType == 'pat') ||
        (stream &&
            account.connectorType == 'devin' &&
            account.authType != 'oauth') ||
        (account.connectorType == 'vertex' && account.authType == 'oauth') ||
        (stream &&
            _isVertexImagen(
              account,
              modelId,
              config: account.endpointConfig,
              nativeFormat: nativeFormat,
            ))) {
      throw const LlmAccountConnectorException();
    }
    if (account.connectorType == 'devin' &&
        account.authType == 'oauth' &&
        (!kPinnedDevinModels.contains(modelId) ||
            !account.models.any((model) => model.upstreamModelId == modelId) ||
            !_isVerifiedDevinOAuthCredential(credential))) {
      throw const LlmAccountConnectorException();
    }
    if (account.connectorType == 'kimi-coding' &&
        (account.authType != 'oauth' ||
            !kPinnedKimiCodeModels.contains(modelId))) {
      throw const LlmAccountConnectorException();
    }
    if (account.connectorType == 'kilocode' &&
        account.authType == 'none' &&
        !kKiloCodeAnonymousFreeModelIds.contains(modelId)) {
      throw const LlmAccountConnectorException();
    }
    if (account.connectorType == 'kilocode' &&
        nativeFormat != null &&
        nativeFormat != 'openai.chat_completions') {
      throw const LlmAccountConnectorException();
    }
    if (account.connectorType == 'muse-code' &&
        (account.authType != 'oauth' ||
            !kPinnedMuseCodeModels.contains(modelId) ||
            !account.models.any((model) => model.upstreamModelId == modelId))) {
      throw const LlmAccountConnectorException();
    }
    if (const {'opencode-go', 'opencode-zen'}.contains(account.connectorType) &&
        !LlmAccountConnectorService._isOpenCodeStandardGatewayModelId(
          modelId,
        )) {
      throw const LlmAccountConnectorException();
    }
    if (account.connectorType == 'command-code') {
      final model = account.models
          .where((model) => model.upstreamModelId == modelId)
          .firstOrNull;
      final supportedProtocols = model?.capabilities['supportedApiProtocols'];
      final protocol = switch (nativeFormat) {
        'responses' => 'openai.responses',
        'anthropic' => 'anthropic.messages',
        _ => 'openai.chat_completions',
      };
      if (supportedProtocols is! Iterable ||
          !supportedProtocols.whereType<String>().contains(protocol)) {
        throw const LlmAccountConnectorException();
      }
    }
    if ((account.connectorType == 'grok-cli' ||
            account.connectorType == 'xai-oauth') &&
        !account.models.any((model) => model.upstreamModelId == modelId)) {
      throw const LlmAccountConnectorException();
    }
    if ((account.connectorType == 'github' ||
            account.connectorType == 'ghe-copilot') &&
        (account.authType != 'oauth' ||
            !account.models.any((model) => model.upstreamModelId == modelId) ||
            nativeFormat != null &&
                !const {'responses', 'anthropic'}.contains(nativeFormat) ||
            nativeFormat == 'responses' &&
                RegExp(
                  r'claude|gemini',
                  caseSensitive: false,
                ).hasMatch(modelId))) {
      throw const LlmAccountConnectorException();
    }
    if (account.connectorType == 'github' ||
        account.connectorType == 'ghe-copilot') {
      final model = account.models
          .where((item) => item.upstreamModelId == modelId)
          .firstOrNull;
      final declared = model?.capabilities['supportedApiProtocols'];
      if (declared is Iterable) {
        final protocol = _copilotProtocolFor(modelId, nativeFormat);
        if (!declared.whereType<String>().contains(protocol)) {
          throw const LlmAccountConnectorException();
        }
      }
    }
    if (account.connectorType == 'cloudflare-ai' &&
        (account.authType != 'api_key' ||
            !kCloudflareWorkersAiModelIds.contains(modelId) ||
            nativeFormat != null && nativeFormat != 'openai.chat_completions' ||
            _configString(account.endpointConfig, 'cloudflareAccountId') ==
                null)) {
      throw const LlmAccountConnectorException();
    }
    LlmAccountConnectorService._validateSafeConfig(account.endpointConfig);

    final headers = <String, String>{..._defaultJsonHeaders};
    final secret =
        account.connectorType == 'bedrock' && account.authType != 'api_key'
            ? ''
            : _credentialValue(account, credential);
    final config = account.endpointConfig;
    final configuredHeaders = config['headers'];
    if (account.connectorType != 'aihorde' &&
        account.connectorType != 'uncloseai' &&
        configuredHeaders is Map) {
      for (final entry in configuredHeaders.entries) {
        if (entry.key is! String || entry.value is! String) {
          throw const LlmAccountConnectorException();
        }
        _validateRequestHeader(entry.key as String, entry.value as String);
        headers[entry.key as String] = entry.value as String;
      }
    }

    final uri = _buildUri(
      account: account,
      config: config,
      credential: credential,
      modelId: modelId,
      stream: stream,
      nativeFormat: nativeFormat,
    );
    switch (account.connectorType) {
      case 'aihorde':
        final chatKey =
            account.authType == 'none' ? kAiHordeAnonymousKey : secret.trim();
        if (chatKey.isEmpty) {
          throw const LlmAccountConnectorException();
        }
        headers['Authorization'] = 'Bearer $chatKey';
        break;
      case 'cloudflare-ai':
        try {
          headers.addAll(
            CloudflareWorkersAiConnector.buildHeaders(secret, stream: stream),
          );
        } on ArgumentError {
          throw const LlmAccountConnectorException();
        }
        break;
      case 'uncloseai':
        if (account.authType == 'api_key' && secret.trim().isNotEmpty) {
          headers['Authorization'] = 'Bearer ${secret.trim()}';
        }
        break;
      case 'azure-ai' || 'azure-openai':
        if (secret.trim().isEmpty) {
          throw const LlmAccountConnectorException();
        }
        headers.removeWhere((name, _) => name.toLowerCase() == 'authorization');
        headers['api-key'] = secret.trim();
        break;
      case 'gitlab-duo':
        headers['Authorization'] = 'Bearer $secret';
        break;
      case 'kimi-coding':
        final deviceId = _credentialBundleString(credential, const [
          'device_id',
        ]);
        if (deviceId == null) throw const LlmAccountConnectorException();
        headers['Authorization'] = 'Bearer $secret';
        headers['X-Msh-Platform'] = 'CLIProxyAPI';
        headers['X-Msh-Version'] = 'stroom';
        headers['X-Msh-Device-Name'] = 'Stroom';
        headers['X-Msh-Device-Model'] = 'Stroom';
        headers['X-Msh-Device-Id'] = deviceId;
        break;
      case 'github' || 'ghe-copilot':
        final copilotToken = _credentialBundleString(credential, const [
          'copilot_token',
        ]);
        if (copilotToken == null) throw const LlmAccountConnectorException();
        headers['Authorization'] = 'Bearer $copilotToken';
        headers.addAll({
          'Editor-Version': 'copilot/1.0.91',
          'copilot-integration-id': 'copilot-developer-cli',
          'openai-intent': 'conversation-agent',
          'x-interaction-type': 'conversation-user',
          'copilot-harness-id': 'copilot-sdk',
          'X-Initiator': 'user',
          'User-Agent': 'copilot/1.0.91',
          'X-GitHub-Api-Version': '2026-08-01',
        });
        final machineId = _credentialBundleString(credential, const [
          'copilot_machine_id',
        ]);
        if (machineId != null) headers['x-client-machine-id'] = machineId;
        break;
      case 'kilocode':
        headers['Authorization'] =
            'Bearer ${account.authType == 'none' ? 'anonymous' : secret}';
        headers['X-KILOCODE-EDITORNAME'] = 'Stroom';
        break;
      case 'claude':
        if (account.authType == 'api_key') {
          headers['x-api-key'] = secret;
        } else {
          headers['Authorization'] = 'Bearer $secret';
          headers['anthropic-beta'] = 'oauth-2025-04-20,claude-code-20250219';
        }
        headers['anthropic-version'] = '2023-06-01';
        headers['X-App'] = 'cli';
        break;
      case 'qwen-cloud' || 'qwen-cloud-token-plan':
        if (nativeFormat == 'anthropic') {
          headers.remove('Authorization');
          headers['x-api-key'] = secret;
          headers['anthropic-version'] = '2023-06-01';
        } else {
          headers['Authorization'] = 'Bearer $secret';
        }
        break;
      case 'opencode-go' || 'opencode-zen':
        if (nativeFormat == 'anthropic') {
          headers.remove('Authorization');
          headers['x-api-key'] = secret;
        } else {
          headers['Authorization'] = 'Bearer $secret';
        }
        break;
      case 'codex':
        if (account.authType == 'oauth') {
          final accountId = _credentialBundleString(credential, const [
            'account_id',
            'accountId',
          ]);
          if (accountId != null) {
            headers['Chatgpt-Account-Id'] = accountId;
          }
        }
        if (secret.isNotEmpty) headers['Authorization'] = 'Bearer $secret';
        break;
      case 'gemini' || 'aistudio':
        if (account.authType == 'api_key') {
          headers['x-goog-api-key'] = secret;
        } else if (account.authType == 'oauth') {
          headers['Authorization'] = 'Bearer $secret';
          headers['x-goog-user-project'] = _requiredGoogleCloudProjectId(
            config,
          );
        }
        break;
      case 'gemini-interactions':
        headers.putIfAbsent('Api-Revision', () => '2026-05-20');
        if (account.authType == 'api_key') {
          headers['x-goog-api-key'] = secret;
        }
        break;
      case 'vertex':
        if (_usesVertexInteractions(config, nativeFormat)) {
          headers.putIfAbsent('Api-Revision', () => '2026-05-20');
        }
        if (account.authType == 'api_key') {
          headers['x-goog-api-key'] = secret;
        } else if (account.authType == 'service_account') {
          headers['Authorization'] = 'Bearer $secret';
        }
        break;
      case 'meta' || 'muse-code':
        headers['Authorization'] = 'Bearer $secret';
        headers['User-Agent'] =
            'muse-build/1.3.0 (interactive; macos-aarch64; build ac7280f2aca67769d1455a8847bb502b617d50f6)';
        headers['X-Client-Id'] = 'tbh:tui';
        break;
      case 'grok-cli':
        headers.addAll(_grokBuildClientHeaders);
        headers['Authorization'] = 'Bearer $secret';
        break;
      case 'xai-oauth':
        headers['Authorization'] = 'Bearer $secret';
        break;
      case 'cline' || 'clinepass':
        final token =
            account.authType == 'oauth' && !secret.startsWith('workos:')
                ? 'workos:$secret'
                : secret;
        headers['Authorization'] = 'Bearer $token';
        headers.addAll({
          'HTTP-Referer': 'https://cline.bot',
          'X-Title': 'Cline',
          'User-Agent': 'Cline/Stroom',
          'X-IS-MULTIROOT': 'false',
          'X-CLIENT-TYPE': 'stroom',
          'X-CLIENT-VERSION': '0.6',
          'X-PLATFORM': 'Stroom',
          'X-PLATFORM-VERSION': '0.6',
          'X-CORE-VERSION': 'Stroom',
        });
        break;
      case 'codebuddy-cn' || 'codebuddy-intl' || 'workbuddy':
        headers['Authorization'] = 'Bearer $secret';
        _addTencentClientHeaders(
          account.connectorType,
          headers,
          body: body,
          conversationId: conversationId,
        );
        break;
      case 'qoder':
        if (account.authType == 'pat') {
          throw const LlmAccountConnectorException();
        }
        headers['Authorization'] = 'Bearer $secret';
        final runtimePlatform = switch (defaultTargetPlatform) {
          TargetPlatform.android => 'android',
          TargetPlatform.iOS => 'ios',
          TargetPlatform.macOS => 'darwin',
          TargetPlatform.windows => 'win32',
          TargetPlatform.linux => 'linux',
          TargetPlatform.fuchsia => 'fuchsia',
        };
        final runtimeArch = _qoderRuntimeArchitecture();
        final userAgent = 'QwenCode/0.19.3 ($runtimePlatform; $runtimeArch)';
        final stainlessOs = switch (runtimePlatform) {
          'android' => 'Android',
          'ios' => 'iOS',
          'darwin' => 'MacOS',
          'win32' => 'Windows',
          'linux' => 'Linux',
          _ => 'Other:$runtimePlatform',
        };
        final stainlessArch = switch (runtimeArch) {
          'x86_64' || 'x64' => 'x64',
          'aarch64' || 'arm64' => 'arm64',
          'x32' => 'x32',
          'arm' => 'arm',
          '' => 'unknown',
          _ => 'other:$runtimeArch',
        };
        headers.addAll({
          'x-dashscope-authtype': 'qwen-oauth',
          'x-dashscope-cachecontrol': 'enable',
          'user-agent': userAgent,
          'x-dashscope-useragent': userAgent,
          'x-stainless-arch': stainlessArch,
          'x-stainless-lang': 'js',
          'x-stainless-os': stainlessOs,
        });
        break;
      case 'antigravity':
        headers['Authorization'] = 'Bearer $secret';
        headers['User-Agent'] = kLlmAntigravityRequestUserAgent;
        break;
      case 'devin':
        headers['Authorization'] = 'Basic $secret-$secret';
        headers['Connect-Protocol-Version'] = '1';
        headers['Content-Type'] = 'application/connect+proto';
        headers['Accept'] = '*/*';
        break;
      case 'bedrock':
        if (account.authType == 'api_key') {
          headers['Authorization'] = 'Bearer $secret';
        }
        break;
      case 'openai-compatibility':
        if (account.authType == 'api_key') {
          _applyConfiguredApiKeyHeader(headers, config, secret);
        } else if (secret.isNotEmpty) {
          headers['Authorization'] = 'Bearer $secret';
        }
        break;
      case 'amazon-q':
        final accessToken = _credentialBundleString(credential, const [
          'access_token',
          'accessToken',
        ]);
        if (account.authType != 'oauth' || accessToken == null) {
          throw const LlmAccountConnectorException();
        }
        headers['Authorization'] = 'Bearer $accessToken';
        headers['Accept'] = 'application/vnd.amazon.eventstream';
        headers['X-Amz-Target'] =
            'AmazonCodeWhispererStreamingService.GenerateAssistantResponse';
        headers['Amz-Sdk-Request'] = 'attempt=1; max=3';
        headers['Amz-Sdk-Invocation-Id'] = const Uuid().v4();
        headers['x-amzn-bedrock-cache-control'] = 'enable';
        headers['anthropic-beta'] = 'prompt-caching-2024-07-31';
        break;
      default:
        if (secret.isNotEmpty) headers['Authorization'] = 'Bearer $secret';
        break;
    }
    if (nativeFormat == 'anthropic') {
      headers.putIfAbsent('anthropic-version', () => '2023-06-01');
    }
    final upstreamStream = stream ||
        account.connectorType == 'ghe-copilot' ||
        account.connectorType == 'cline' ||
        account.connectorType == 'clinepass';
    if (upstreamStream &&
        (account.connectorType == 'bedrock' ||
            account.connectorType == 'amazon-q')) {
      headers['Accept'] = 'application/vnd.amazon.eventstream';
    } else if (upstreamStream && account.connectorType != 'devin') {
      headers['Accept'] = 'text/event-stream';
    }

    final connectorBody = account.connectorType == 'cloudflare-ai'
        ? CloudflareWorkersAiConnector.normalizeRequestBody(body)
        : body;
    final baseRequestBody = account.connectorType == 'devin' &&
            account.authType == 'oauth'
        ? DevinConnectRpc.encodeChatRequest(
            sessionToken: secret,
            modelId: modelId,
            body: body is Map ? body : const {},
          )
        : account.connectorType == 'grok-cli'
            ? _grokBuildPayload(
                _applyBodyStreamOption(
                  account: account,
                  config: config,
                  body: body,
                  stream: stream,
                  nativeFormat: nativeFormat,
                ),
              )
            : account.connectorType == 'bedrock'
                ? AwsBedrockConverseAdapter.toConverse(body)
                : account.connectorType == 'antigravity'
                    ? _antigravityPayload(account, credential, modelId, body)
                    : _isVertexImagen(
                        account,
                        modelId,
                        config: config,
                        nativeFormat: nativeFormat,
                      )
                        ? _vertexImagenPayload(body)
                        : _applyBodyStreamOption(
                            account: account,
                            config: config,
                            body: account.connectorType == 'aihorde'
                                ? _aiHordeChatBody(connectorBody)
                                : connectorBody,
                            stream: upstreamStream,
                            nativeFormat: nativeFormat,
                          );

    Object? requestBody = baseRequestBody;
    if (account.connectorType == 'kilocode' && account.authType == 'none') {
      if (baseRequestBody is! Map) {
        throw const LlmAccountConnectorException();
      }
      requestBody = Map<String, dynamic>.from(baseRequestBody)
        ..['model'] = modelId;
    }
    if (account.connectorType == 'openai-compatibility' &&
        config['providerPresetId'] == 'cheaperinference' &&
        (nativeFormat == 'responses' || nativeFormat == null)) {
      if (requestBody is! Map) {
        throw const LlmAccountConnectorException();
      }
      final payload = Map<String, dynamic>.from(requestBody);
      if (nativeFormat == 'responses') {
        // CheaperInference's Responses surface is stateless and rejects both
        // a missing store field and store:true.
        payload['store'] = false;
      } else {
        // The Chat Completions surface rejects this Responses-only option.
        payload.remove('store');
      }
      requestBody = payload;
    }

    var requestHeaders = headers;
    if (account.connectorType == 'bedrock' && account.authType != 'api_key') {
      if (awsCredentials == null) {
        throw const LlmAccountConnectorException();
      }
      requestHeaders = AwsSigV4.sign(
        method: 'POST',
        uri: uri,
        region: _configString(config, 'region')!,
        service: 'bedrock',
        headers: headers,
        payload: Uint8List.fromList(utf8.encode(jsonEncode(requestBody))),
        credentials: awsCredentials,
        now: DateTime.now().toUtc(),
      );
    } else if (account.connectorType == 'bedrock' && secret.isEmpty) {
      throw const LlmAccountConnectorException();
    }

    return LlmPreparedNativeRequest(
      uri: uri,
      method: 'POST',
      headers: requestHeaders,
      body: requestBody,
    );
  }

  static Object? _applyBodyStreamOption({
    required LlmAccount account,
    required Map<String, dynamic> config,
    required Object? body,
    required bool stream,
    required String? nativeFormat,
  }) {
    if (account.connectorType == 'gitlab-duo') {
      if (body is! Map || body['messages'] is! Iterable) {
        throw const LlmAccountConnectorException();
      }
      if (body.containsKey('tools') ||
          body.containsKey('tool_choice') ||
          body.containsKey('tool_calls') ||
          body.containsKey('functions') ||
          body.containsKey('parallel_tool_calls') ||
          body.containsKey('function_call')) {
        throw const LlmAccountConnectorException();
      }
      final conversationParts = <String>[];
      for (final rawMessage in body['messages'] as Iterable) {
        if (rawMessage is! Map) {
          throw const LlmAccountConnectorException();
        }
        final role = rawMessage['role']?.toString().toLowerCase();
        if (!const {
          'system',
          'developer',
          'user',
          'assistant',
          'tool',
        }.contains(role)) {
          throw const LlmAccountConnectorException();
        }
        if (role == 'tool' ||
            const {
              'tool_calls',
              'function_call',
              'tools',
              'functions',
              'tool_choice',
              'parallel_tool_calls',
            }.any(rawMessage.containsKey)) {
          throw const LlmAccountConnectorException();
        }
        final rawContent = rawMessage['content'];
        final content = switch (rawContent) {
          String value => value,
          Iterable values => values.map((part) {
              if (part is! Map ||
                  !const {'text', 'input_text'}.contains(part['type']) ||
                  part['text'] is! String) {
                throw const LlmAccountConnectorException();
              }
              return part['text'] as String;
            }).join(),
          null => '',
          _ => throw const LlmAccountConnectorException(),
        };
        if (content.isEmpty) continue;
        final label = switch (role) {
          'system' => 'System instruction',
          'developer' => 'Developer instruction',
          'user' => 'User',
          'assistant' => 'Assistant',
          _ => throw const LlmAccountConnectorException(),
        };
        conversationParts.add('$label: $content');
      }
      final prompt = conversationParts.join('\n');
      if (prompt.isEmpty) throw const LlmAccountConnectorException();
      return {
        'current_file': {
          'file_name': 'snippet.txt',
          'content_above_cursor': prompt,
          'content_below_cursor': '',
        },
        'intent': 'generation',
        'generation_type': 'small_file',
        'stream': false,
        'user_instruction': prompt,
      };
    }
    if ({
      'codebuddy-cn',
      'codebuddy-intl',
      'workbuddy',
    }.contains(account.connectorType)) {
      if (body is! Map) throw const LlmAccountConnectorException();
      final payload = Map<String, dynamic>.from(body)..['stream'] = true;
      if (account.connectorType != 'workbuddy') {
        final effort = payload['reasoning_effort'];
        if (effort == 'none' || effort == 'off') {
          payload.remove('reasoning_effort');
        } else if (effort is String && effort.isNotEmpty) {
          payload['reasoning_summary'] = 'auto';
        }
        if (payload['max_completion_tokens'] != null) {
          payload.putIfAbsent(
            'max_tokens',
            () => payload['max_completion_tokens'],
          );
          payload.remove('max_completion_tokens');
        }
        if (payload['tools'] is List && (payload['tools'] as List).isEmpty) {
          payload.remove('tools');
        }
        if (account.connectorType == 'codebuddy-intl') {
          final messages = payload['messages'];
          if (messages is List &&
              (messages.isEmpty ||
                  messages.first is! Map ||
                  (messages.first as Map)['role'] != 'system')) {
            payload['messages'] = [
              {'role': 'system', 'content': 'You are a helpful assistant.'},
              ...messages,
            ];
          }
        }
      }
      return payload;
    }
    if (!_usesBodyStreamOption(account, config, nativeFormat)) return body;
    if (body is! Map) {
      if (stream) throw const LlmAccountConnectorException();
      return body;
    }
    if (!stream && !body.containsKey('stream')) return body;
    return Map<String, dynamic>.from(body)..['stream'] = stream;
  }

  static Object? _grokBuildPayload(Object? body) {
    if (body is! Map) throw const LlmAccountConnectorException();
    final payload = Map<String, dynamic>.from(body);
    final include = payload['include'] is Iterable
        ? List<Object?>.from(payload['include'] as Iterable)
        : <Object?>[];
    if (!include.contains('reasoning.encrypted_content')) {
      include.add('reasoning.encrypted_content');
    }
    payload['include'] = include;
    return payload;
  }

  static bool _usesBodyStreamOption(
    LlmAccount account,
    Map<String, dynamic> config,
    String? nativeFormat,
  ) =>
      switch (account.connectorType) {
        'codex' ||
        'claude' ||
        'kimi-coding' ||
        'kilocode' ||
        'kimi' ||
        'kimi-ai' ||
        'kimi.ai' ||
        'xai' ||
        'grok-cli' ||
        'xai-oauth' ||
        'meta' ||
        'muse-code' ||
        'codebuddy-cn' ||
        'codebuddy-intl' ||
        'workbuddy' ||
        'github' ||
        'ghe-copilot' ||
        'gemini-interactions' ||
        'openai-compatibility' ||
        'openai-api' ||
        'openference' ||
        'openference-api' ||
        'cline' ||
        'clinepass' ||
        'opencode-go' ||
        'opencode-zen' ||
        'moonshot' ||
        'glm' ||
        'deepseek' ||
        'minimax' ||
        'qwen' ||
        'qoder' =>
          true,
        'vertex' => _usesVertexInteractions(config, nativeFormat),
        _ => false,
      };

  static String _credentialValue(LlmAccount account, String? credential) {
    if (account.authType == 'none') return '';
    if (credential == null || credential.trim().isEmpty) {
      throw const LlmAccountConnectorException();
    }
    Object? decoded;
    var isJson = false;
    try {
      decoded = jsonDecode(credential);
      isJson = true;
    } catch (_) {
      // API keys and session tokens are commonly stored as opaque strings.
    }
    if (isJson && decoded is Map) {
      final candidates = switch (account.authType) {
        'api_key' => const ['api_key', 'apiKey', 'key'],
        'setup_token' => const [
            'setup_token',
            'setupToken',
            'access_token',
            'accessToken',
          ],
        'oauth' => account.connectorType == 'qoder'
            ? const ['api_key', 'apiKey']
            : account.connectorType == 'devin'
                ? const ['session_token']
                : account.connectorType == 'meta' ||
                        account.connectorType == 'muse-code'
                    ? const ['api_key', 'apiKey', 'access_token', 'accessToken']
                    : const ['access_token', 'accessToken'],
        'session_token' => const [
            'session_token',
            'sessionToken',
            'access_token',
            'accessToken',
          ],
        'service_account' => const ['access_token', 'accessToken'],
        _ => const <String>[],
      };
      for (final key in candidates) {
        final value = decoded[key];
        if (value is String && value.trim().isNotEmpty) {
          if ((account.connectorType == 'meta' ||
                  account.connectorType == 'muse-code') &&
              account.authType == 'oauth' &&
              value.startsWith('dca:') &&
              decoded['api_key'] == null) {
            break;
          }
          return value;
        }
      }
      throw const LlmAccountConnectorException();
    }
    if (isJson && (account.authType != 'api_key' || decoded is! num)) {
      throw const LlmAccountConnectorException();
    }
    if (account.authType == 'service_account') {
      throw const LlmAccountConnectorException();
    }
    if ((account.connectorType == 'meta' ||
            account.connectorType == 'muse-code') &&
        account.authType == 'oauth' &&
        credential.trim().startsWith('dca:')) {
      throw const LlmAccountConnectorException();
    }
    if (account.authType == 'pat' &&
        !{'qoder', 'gitlab-duo'}.contains(account.connectorType)) {
      throw const LlmAccountConnectorException();
    }
    if (account.authType != 'api_key' &&
        account.authType != 'oauth' &&
        account.authType != 'pat' &&
        account.authType != 'session_token' &&
        account.authType != 'setup_token') {
      throw const LlmAccountConnectorException();
    }
    return credential;
  }

  static bool _isVerifiedDevinOAuthCredential(String? credential) {
    if (credential == null) return false;
    try {
      final decoded = jsonDecode(credential);
      if (decoded is! Map) return false;
      final planEndValue = decoded['plan_end'];
      final planEnd = planEndValue is String
          ? DateTime.tryParse(planEndValue)?.toUtc()
          : null;
      if (planEndValue != null &&
          (planEnd == null || !planEnd.isAfter(DateTime.now().toUtc()))) {
        return false;
      }
      return decoded['oauth_contract'] == 'devin-pkce-v1' &&
          decoded['auth_kind'] == 'oauth' &&
          decoded['session_token'] is String &&
          (decoded['session_token'] as String).trim().isNotEmpty &&
          decoded['user_id'] is String &&
          (decoded['user_id'] as String).trim().isNotEmpty &&
          decoded['plan'] is String &&
          (decoded['plan'] as String).trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static String? _credentialBundleString(
    String? credential,
    List<String> keys,
  ) {
    if (credential == null) return null;
    try {
      final decoded = jsonDecode(credential);
      if (decoded is! Map) return null;
      final serviceAccount = decoded['service_account'];
      for (final key in keys) {
        final value = decoded[key] ??
            (serviceAccount is Map ? serviceAccount[key] : null);
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    } catch (_) {
      // Opaque credential strings have no ancillary account identity fields.
    }
    return null;
  }

  static Map<String, dynamic> _antigravityPayload(
    LlmAccount account,
    String? credential,
    String modelId,
    Object? body,
  ) {
    if (body is! Map) throw const LlmAccountConnectorException();
    final payload = Map<String, dynamic>.from(body);
    final requestValue = payload['request'];
    final request = requestValue is Map
        ? Map<String, dynamic>.from(requestValue)
        : <String, dynamic>{};
    payload['model'] = modelId;
    payload['userAgent'] = 'antigravity';
    var requestType = payload['requestType'];
    if (requestType is! String || requestType.trim().isEmpty) {
      requestType =
          modelId.toLowerCase().contains('image') ? 'image_gen' : 'agent';
      payload['requestType'] = requestType;
    }
    final projectId = _configString(account.endpointConfig, 'projectId') ??
        _projectIdFromCredential(credential);
    if (projectId == null || projectId.isEmpty) {
      payload.remove('project');
    } else {
      payload['project'] = projectId;
    }
    final isImageModel = modelId.toLowerCase().contains('image');
    if (isImageModel) {
      payload['requestId'] =
          'image_gen/${DateTime.now().millisecondsSinceEpoch}/'
          '${const Uuid().v4()}/12';
    } else if (requestType != 'web_search') {
      payload['requestId'] = 'agent-${const Uuid().v4()}';
      final sessionId = request['sessionId'];
      if (sessionId is! String || sessionId.trim().isEmpty) {
        request['sessionId'] = _antigravitySessionId(request);
      }
    }
    request.remove('safetySettings');
    if (payload['toolConfig'] != null && request['toolConfig'] == null) {
      request['toolConfig'] = payload.remove('toolConfig');
    }
    payload['request'] = request;
    return payload;
  }

  static String _antigravitySessionId(Map<String, dynamic> request) {
    final contents = request['contents'];
    if (contents is List) {
      for (final content in contents) {
        if (content is! Map || content['role'] != 'user') continue;
        final parts = content['parts'];
        if (parts is! List || parts.isEmpty || parts.first is! Map) continue;
        final text = (parts.first as Map)['text'];
        if (text is! String || text.isEmpty) continue;
        final digest = crypto.sha256.convert(utf8.encode(text)).bytes;
        var value = BigInt.zero;
        for (var index = 0; index < 8; index++) {
          value = (value << 8) | BigInt.from(digest[index]);
        }
        value &= BigInt.parse('7fffffffffffffff', radix: 16);
        return '-$value';
      }
    }
    final random = const Uuid().v4().replaceAll('-', '').substring(0, 15);
    return '-${BigInt.parse(random, radix: 16)}';
  }

  static String? _projectIdFromCredential(String? credential) {
    if (credential == null) return null;
    try {
      final decoded = jsonDecode(credential);
      if (decoded is! Map) return null;
      final serviceAccount = decoded['service_account'] is Map
          ? decoded['service_account'] as Map
          : decoded;
      final value = serviceAccount['project_id'] ?? serviceAccount['projectId'];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    } catch (_) {
      return null;
    }
  }

  static Uri _buildUri({
    required LlmAccount account,
    required Map<String, dynamic> config,
    required String? credential,
    required String modelId,
    required bool stream,
    required String? nativeFormat,
  }) {
    if (account.connectorType == 'clova-studio') {
      if (account.authType != 'api_key' || nativeFormat != 'clova') {
        throw const LlmAccountConnectorException();
      }
      try {
        return ClovaStudioProtocol.requestUri(modelId);
      } on ArgumentError {
        throw const LlmAccountConnectorException();
      }
    }
    String baseUrl;
    String path;
    String? query;
    String? amazonQRegion;
    final preserveLegacyOcrEndpoint =
        account.connectorType == 'openai-compatibility' &&
            config['legacyOcrFullEndpoint'] == true &&
            nativeFormat == null;
    if (account.connectorType == 'cloudflare-ai') {
      final accountId = _configString(config, 'cloudflareAccountId');
      if (accountId == null) throw const LlmAccountConnectorException();
      try {
        return CloudflareWorkersAiConnector.buildChatCompletionsUri(accountId);
      } on ArgumentError {
        throw const LlmAccountConnectorException();
      }
    }
    if (account.connectorType == 'azure-ai' ||
        account.connectorType == 'azure-openai') {
      final deploymentId = _configString(config, 'azureDeploymentId');
      final apiVersion = _configString(config, 'apiVersion') ??
          AzureOpenAiEndpoint.defaultApiVersion;
      if (deploymentId == null || deploymentId != modelId) {
        throw const LlmAccountConnectorException();
      }
      try {
        return AzureOpenAiEndpoint.chatCompletionsUri(
          resourceUrl: _baseUrl(config, ''),
          deploymentId: deploymentId,
          apiVersion: apiVersion,
        );
      } on FormatException {
        throw const LlmAccountConnectorException();
      }
    }
    switch (account.connectorType) {
      case 'amazon-q':
        amazonQRegion = _amazonQRegion(account, {
          'region': _credentialBundleString(credential, const [
            'region',
            'regionId',
            'region_id',
          ]),
        });
        final target = AmazonQConnector.chatUri(amazonQRegion);
        baseUrl = target.origin;
        path = target.path;
      case 'aihorde':
        baseUrl = 'https://oai.aihorde.net/v1';
        path = '/chat/completions';
      case 'uncloseai':
        baseUrl = _uncloseAiBaseUrl;
        path = '/chat/completions';
      case 'gitlab-duo':
        baseUrl = _baseUrl(config, 'https://gitlab.com');
        path = '/api/v4/code_suggestions/completions';
      case 'codex':
        baseUrl = _baseUrl(config, 'https://api.openai.com/v1');
        path = '/responses';
      case 'claude':
        baseUrl = _baseUrl(config, 'https://api.anthropic.com');
        path = nativeFormat == 'count_tokens'
            ? '/v1/messages/count_tokens'
            : '/v1/messages';
        if (account.authType == 'oauth' || account.authType == 'setup_token') {
          query = 'beta=true';
        }
      case 'antigravity':
        baseUrl = _baseUrl(config, 'https://cloudcode-pa.googleapis.com');
        path = stream
            ? '/v1internal:streamGenerateContent'
            : '/v1internal:generateContent';
        if (stream) query = 'alt=sse';
      case 'kimi-coding' || 'kimi' || 'kimi-ai' || 'kimi.ai':
        baseUrl = _baseUrl(
          config,
          account.connectorType == 'kimi-coding' ||
                  account.connectorType == 'kimi'
              ? 'https://api.kimi.com/coding'
              : 'https://api.kimi.ai/coding',
        );
        path = switch (nativeFormat) {
          'responses' => '/v1/responses',
          'anthropic' => '/v1/messages',
          _ => '/v1/chat/completions',
        };
      case 'xai':
        baseUrl = _baseUrl(config, 'https://api.x.ai/v1');
        path = '/responses';
      case 'grok-cli':
        baseUrl = _baseUrl(config, 'https://cli-chat-proxy.grok.com/v1');
        path = '/responses';
      case 'xai-oauth':
        baseUrl = _baseUrl(config, 'https://api.x.ai/v1');
        path = '/responses';
      case 'cline' || 'clinepass':
        baseUrl = 'https://api.cline.bot/api/v1';
        path = '/chat/completions';
      case 'codebuddy-cn' || 'codebuddy-intl':
        baseUrl = _baseUrl(
          config,
          account.connectorType == 'codebuddy-cn'
              ? 'https://copilot.tencent.com/v2'
              : 'https://www.codebuddy.ai/v2',
        );
        path = '/chat/completions';
      case 'workbuddy':
        baseUrl = _baseUrl(config, 'https://www.workbuddy.ai/v2');
        path = '/chat/completions';
      case 'github' || 'ghe-copilot':
        final enterpriseApi = _credentialBundleString(credential, const [
          'copilot_api_url',
        ]);
        baseUrl = _baseUrl(
          config,
          account.connectorType == 'github'
              ? 'https://api.githubcopilot.com'
              : enterpriseApi ?? '',
        );
        if (baseUrl.isEmpty) throw const LlmAccountConnectorException();
        path = switch (_copilotProtocolFor(modelId, nativeFormat)) {
          'anthropic.messages' => '/v1/messages',
          'openai.responses' => '/responses',
          _ => '/chat/completions',
        };
      case 'qoder':
        baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1';
        path = '/chat/completions';
      case 'kilocode':
        baseUrl = 'https://api.kilo.ai/api/openrouter';
        path = '/chat/completions';
      case 'devin':
        baseUrl = _baseUrl(config, 'https://server.codeium.com');
        path = '/exa.api_server_pb.ApiServerService/GetChatMessage';
      case 'meta' || 'muse-code':
        baseUrl = _baseUrl(
          config,
          _metaBaseUrl(credential) ?? 'https://api.meta.ai/v1',
        );
        path = '/responses';
      case 'gemini' || 'aistudio':
        baseUrl = _baseUrl(config, 'https://generativelanguage.googleapis.com');
        path = '/v1beta/models/${Uri.encodeComponent(modelId)}:'
            '${stream ? 'streamGenerateContent' : 'generateContent'}';
        if (stream) query = 'alt=sse';
      case 'openai-api':
        baseUrl = _baseUrl(config, 'https://api.openai.com/v1');
        path = nativeFormat == 'responses' ? '/responses' : '/chat/completions';
      case 'openference' || 'openference-api':
        baseUrl = _baseUrl(config, 'https://api.openference.com/v1');
        path = nativeFormat == 'responses' ? '/responses' : '/chat/completions';
      case 'opencode-go' || 'opencode-zen':
        final isGo = account.connectorType == 'opencode-go';
        final isAnthropic = nativeFormat == 'anthropic';
        final defaultBase = switch ((isGo, isAnthropic)) {
          (true, true) => _openCodeGoAnthropicBaseUrl,
          (true, false) => _openCodeGoBaseUrl,
          (false, true) => _openCodeZenAnthropicBaseUrl,
          (false, false) => _openCodeZenBaseUrl,
        };
        baseUrl = _baseUrl(config, defaultBase);
        if (isAnthropic) {
          final endpointPath = Uri.tryParse(baseUrl)?.path ?? '';
          if (endpointPath.replaceFirst(RegExp(r'/+$'), '').endsWith('/v1')) {
            baseUrl = baseUrl.replaceFirst(RegExp(r'/v1/?$'), '');
          }
          path = '/v1/messages';
        } else {
          path =
              nativeFormat == 'responses' ? '/responses' : '/chat/completions';
        }
      case 'command-code':
        baseUrl = _baseUrl(config, kCommandCodeBaseUrl);
        path = switch (nativeFormat) {
          'responses' => '/responses',
          'anthropic' => '/messages',
          _ => '/chat/completions',
        };
      case 'moonshot':
        baseUrl = _baseUrl(config, 'https://api.moonshot.ai/v1');
        path = '/chat/completions';
      case 'glm':
        baseUrl = _baseUrl(config, 'https://open.bigmodel.cn/api/paas/v4');
        path = '/chat/completions';
      case 'glm-cn':
        baseUrl = _baseUrl(
          config,
          'https://open.bigmodel.cn/api/coding/paas/v4',
        );
        path = '/chat/completions';
      case 'deepseek':
        baseUrl = _baseUrl(config, 'https://api.deepseek.com');
        path = '/chat/completions';
      case 'minimax' || 'minimax-cn':
        baseUrl = _baseUrl(
          config,
          account.connectorType == 'minimax-cn'
              ? 'https://api.minimaxi.com/v1'
              : 'https://api.minimax.io/v1',
        );
        path = '/chat/completions';
      case 'qwen':
        baseUrl = _baseUrl(
          config,
          'https://dashscope.aliyuncs.com/compatible-mode/v1',
        );
        path = '/chat/completions';
      case 'qwen-cloud' || 'qwen-cloud-token-plan':
        baseUrl = _qwenCloudProtocolBaseUrl(
          account.connectorType,
          config,
          nativeFormat,
        );
        path = switch (nativeFormat) {
          'anthropic' => '/v1/messages',
          'responses' => '/responses',
          _ => '/chat/completions',
        };
      case 'bedrock':
        final region = _configString(config, 'region');
        if (region == null || !isValidAwsRegion(region)) {
          throw const LlmAccountConnectorException();
        }
        baseUrl =
            'https://${awsRegionalEndpointHost('bedrock-runtime', region)}';
        path = '/model/${Uri.encodeComponent(modelId)}/'
            '${stream ? 'converse-stream' : 'converse'}';
      case 'gemini-interactions':
        baseUrl = _baseUrl(config, 'https://generativelanguage.googleapis.com');
        path = '/v1beta/interactions';
        if (stream) query = 'alt=sse';
      case 'ollama':
        baseUrl = _baseUrl(config, '');
        path = '/api/chat';
      case 'vertex':
        if (_usesVertexInteractions(config, nativeFormat)) {
          final projectId = _configString(config, 'projectId') ??
              _projectIdFromCredential(credential);
          baseUrl = _baseUrl(config, 'https://aiplatform.googleapis.com');
          path = projectId == null || projectId.isEmpty
              ? '/v1beta1/interactions'
              : '/v1beta1/projects/${Uri.encodeComponent(projectId)}'
                  '/locations/global/interactions';
          if (stream) query = 'alt=sse';
          break;
        }
        final location = _vertexLocation(config) ?? 'us-central1';
        if (!RegExp(r'^[a-z0-9-]+$').hasMatch(location)) {
          throw const LlmAccountConnectorException();
        }
        baseUrl = _baseUrl(
          config,
          location == 'global'
              ? 'https://aiplatform.googleapis.com'
              : 'https://$location-aiplatform.googleapis.com',
        );
        final projectId = _configString(config, 'projectId') ??
            _projectIdFromCredential(credential);
        final model = Uri.encodeComponent(modelId);
        final action = _isVertexImagen(
          account,
          modelId,
          config: config,
          nativeFormat: nativeFormat,
        )
            ? 'predict'
            : stream
                ? 'streamGenerateContent'
                : 'generateContent';
        if (projectId == null || projectId.isEmpty) {
          path = '/v1/publishers/google/models/$model:$action';
        } else {
          path = '/v1/projects/${Uri.encodeComponent(projectId)}'
              '/locations/${Uri.encodeComponent(location)}'
              '/publishers/google/models/$model:$action';
        }
        if (stream) query = 'alt=sse';
      case 'openai-compatibility':
        baseUrl = _baseUrl(config, '');
        final baseUri = Uri.tryParse(baseUrl);
        if (baseUri == null ||
            !baseUri.hasScheme ||
            baseUri.host.isEmpty ||
            (baseUri.scheme != 'https' && baseUri.scheme != 'http') ||
            baseUri.userInfo.isNotEmpty) {
          throw const LlmAccountConnectorException();
        }
        final endpointPath = baseUri.path.replaceFirst(RegExp(r'/+$'), '');
        final desiredPath = switch (nativeFormat) {
          'responses' => '/responses',
          'anthropic' => '/messages',
          _ => '/chat/completions',
        };
        if (preserveLegacyOcrEndpoint) {
          path = '';
        } else {
          const endpointSuffixes = [
            '/chat/completions',
            '/responses',
            '/messages',
          ];
          final currentSuffix =
              endpointSuffixes.where(endpointPath.endsWith).firstOrNull;
          if (currentSuffix == desiredPath) {
            path = '';
          } else {
            if (currentSuffix != null) {
              final endpointRoot = endpointPath.substring(
                0,
                endpointPath.length - currentSuffix.length,
              );
              baseUrl = baseUri.replace(path: endpointRoot).toString();
            }
            path = desiredPath;
          }
        }
      default:
        throw const LlmAccountConnectorException();
    }
    final usesProtocolSpecificQwenBase =
        account.connectorType == 'qwen-cloud' ||
            account.connectorType == 'qwen-cloud-token-plan';
    final base = account.connectorType == 'amazon-q' ||
            account.connectorType == 'aihorde' ||
            account.connectorType == 'uncloseai' ||
            account.connectorType == 'openai-compatibility' ||
            account.connectorType == 'cline' ||
            account.connectorType == 'clinepass' ||
            usesProtocolSpecificQwenBase
        ? baseUrl
        : _baseUrl(config, baseUrl);
    final parsed = Uri.tryParse(base);
    if (parsed == null ||
        !parsed.hasScheme ||
        parsed.host.isEmpty ||
        parsed.userInfo.isNotEmpty ||
        !_isBaseSchemeAllowed(account, parsed)) {
      throw const LlmAccountConnectorException();
    }
    _validateProviderBaseUrl(account, parsed, amazonQRegion: amazonQRegion);
    if (preserveLegacyOcrEndpoint) return parsed.replace(fragment: null);
    final basePath = account.connectorType == 'openai-compatibility'
        ? parsed.path.replaceFirst(RegExp(r'/+$'), '')
        : parsed.path;
    final joinedPath = _joinPath(basePath, path);
    final queryParameters = <String, dynamic>{
      ...parsed.queryParametersAll,
      if (query != null) ...Uri.splitQueryString(query),
    };
    if (queryParameters.isEmpty) {
      return parsed.replace(path: joinedPath, fragment: null);
    }
    return parsed.replace(
      path: joinedPath,
      queryParameters: queryParameters,
      fragment: null,
    );
  }

  static bool _isBaseSchemeAllowed(LlmAccount account, Uri base) {
    if (account.connectorType == 'openai-compatibility') {
      return base.scheme == 'https' ||
          (base.scheme == 'http' && _isLoopbackHost(base.host));
    }
    return base.scheme == 'https' ||
        (base.scheme == 'http' && _isLoopbackHost(base.host));
  }

  static bool _isLoopbackHost(String host) {
    final normalized =
        host.toLowerCase().replaceAll('[', '').replaceAll(']', '');
    if (normalized == 'localhost' || normalized == '::1') return true;
    final octets = normalized.split('.');
    if (octets.length != 4 || octets.first != '127') return false;
    return octets.every((octet) {
      final value = int.tryParse(octet);
      return value != null && value >= 0 && value <= 255;
    });
  }

  static bool _validGheCopilotHost(String host, Map<String, dynamic> config) {
    final gheText = _configString(config, 'gheUrl');
    final gheHost = gheText == null ? null : Uri.tryParse(gheText)?.host;
    final hostParts = host.split('.');
    final gheParts = (gheHost ?? '').split('.');
    final sharesRegisteredDomain = hostParts.length >= 2 &&
        gheParts.length >= 2 &&
        hostParts.skip(1).join('.') == gheParts.skip(1).join('.');
    return host.endsWith('.githubcopilot.com') ||
        host == 'githubcopilot.com' ||
        gheHost != null &&
            (host == gheHost ||
                host.endsWith('.$gheHost') ||
                sharesRegisteredDomain);
  }

  static bool _usesVertexInteractions(
    Map<String, dynamic> config,
    String? nativeFormat,
  ) {
    if (nativeFormat != 'interactions') return false;
    final value = config['interactions'];
    if (value is bool) return value;
    if (value is String) {
      return value.trim().toLowerCase() == 'true' || value.trim() == '1';
    }
    return false;
  }

  static bool _isVertexImagen(
    LlmAccount account,
    String modelId, {
    required Map<String, dynamic> config,
    required String? nativeFormat,
  }) =>
      account.connectorType == 'vertex' &&
      !_usesVertexInteractions(config, nativeFormat) &&
      modelId.toLowerCase().contains('imagen');

  static Map<String, dynamic> _vertexImagenPayload(Object? body) {
    if (body is! Map) throw const LlmAccountConnectorException();

    String? prompt;
    final contents = body['contents'];
    if (contents is List && contents.isNotEmpty && contents.first is Map) {
      final parts = (contents.first as Map)['parts'];
      if (parts is List && parts.isNotEmpty && parts.first is Map) {
        final text = (parts.first as Map)['text'];
        if (text is String && text.isNotEmpty) prompt = text;
      }
    }
    if (prompt == null) {
      final messages = body['messages'];
      if (messages is List) {
        for (final message in messages) {
          if (message is Map && message['content'] is String) {
            final content = message['content'] as String;
            if (content.isNotEmpty) {
              prompt = content;
              break;
            }
          }
        }
      }
    }
    if (prompt == null && body['prompt'] is String) {
      prompt = body['prompt'] as String;
    }
    if (prompt == null || prompt.isEmpty) {
      throw const LlmAccountConnectorException();
    }

    final parameters = <String, dynamic>{'sampleCount': 1};
    if (body.containsKey('aspectRatio')) {
      parameters['aspectRatio'] = body['aspectRatio'].toString();
    }
    if (body.containsKey('sampleCount')) {
      final value = body['sampleCount'];
      parameters['sampleCount'] =
          value is num ? value.toInt() : int.tryParse(value.toString()) ?? 0;
    }
    final instance = <String, dynamic>{'prompt': prompt};
    if (body.containsKey('negativePrompt')) {
      instance['negativePrompt'] = body['negativePrompt'].toString();
    }
    return {
      'instances': [instance],
      'parameters': parameters,
    };
  }

  static void _validateProviderBaseUrl(
    LlmAccount account,
    Uri base, {
    String? amazonQRegion,
  }) {
    if (account.connectorType == 'openai-compatibility' ||
        account.connectorType == 'gitlab-duo') {
      return;
    }
    final host = base.host.toLowerCase();
    final hasCustomBaseUrl =
        _configString(account.endpointConfig, 'baseUrl') != null;
    if (hasCustomBaseUrl &&
        {'opencode-go', 'opencode-zen'}.contains(account.connectorType) &&
        base.scheme != 'https') {
      throw const LlmAccountConnectorException();
    }
    final supportsCustomApiKeyEndpoint = account.authType == 'api_key' &&
        {
          'codex',
          'claude',
          'opencode-go',
          'opencode-zen',
          'vertex',
        }.contains(account.connectorType);
    if (account.connectorType == 'ollama' && hasCustomBaseUrl) return;
    if (hasCustomBaseUrl && supportsCustomApiKeyEndpoint) return;
    final location = _vertexLocation(account.endpointConfig) ?? 'us-central1';
    final bedrockRegion = _configString(account.endpointConfig, 'region');
    final bedrockHost = bedrockRegion == null
        ? null
        : awsRegionalEndpointHost('bedrock-runtime', bedrockRegion);
    final allowed = switch (account.connectorType) {
      'codex' => {'chatgpt.com', 'api.openai.com'}.contains(host),
      'claude' => host == 'api.anthropic.com',
      'antigravity' => host == 'cloudcode-pa.googleapis.com',
      'kimi' || 'kimi-coding' => host == 'api.kimi.com',
      'kimi-ai' || 'kimi.ai' => host == 'api.kimi.ai',
      'xai' || 'xai-oauth' => host == 'api.x.ai',
      'codebuddy-cn' => host == 'copilot.tencent.com',
      'codebuddy-intl' => host == 'www.codebuddy.ai',
      'workbuddy' => host == 'www.workbuddy.ai',
      'github' => host == 'api.githubcopilot.com',
      'ghe-copilot' => _validGheCopilotHost(host, account.endpointConfig),
      'qoder' => host == 'dashscope.aliyuncs.com',
      'kilocode' => host == 'api.kilo.ai',
      'cline' || 'clinepass' => host == 'api.cline.bot',
      'grok-cli' => host == 'cli-chat-proxy.grok.com',
      'devin' => host == 'server.codeium.com',
      'meta' || 'muse-code' => host == 'api.meta.ai',
      'gemini' ||
      'gemini-interactions' ||
      'aistudio' =>
        host == 'generativelanguage.googleapis.com',
      'openai-api' => host == 'api.openai.com',
      'openference' || 'openference-api' => host == 'api.openference.com',
      'opencode-go' || 'opencode-zen' => host == 'opencode.ai',
      'command-code' => host == 'api.commandcode.ai',
      'aihorde' => host == 'oai.aihorde.net',
      'uncloseai' => host == 'hermes.ai.unturf.com',
      'azure-ai' ||
      'azure-openai' =>
        AzureOpenAiEndpoint.isAzureResourceHost(host),
      'moonshot' => {'api.moonshot.ai', 'api.moonshot.cn'}.contains(host),
      'glm' => host == 'open.bigmodel.cn',
      'deepseek' => host == 'api.deepseek.com',
      'minimax' => {'api.minimax.io', 'api.minimaxi.com'}.contains(host),
      'minimax-cn' => host == 'api.minimaxi.com',
      'qwen' => host == 'dashscope.aliyuncs.com',
      'qwen-cloud' => _qwenCloudRegions
          .map((region) => '$region.maas.qwencloudapi.com')
          .contains(host),
      'qwen-cloud-token-plan' => host == 'token-plan.maas.qwencloudapi.com',
      'glm-cn' => host == 'open.bigmodel.cn',
      'bedrock' => host == bedrockHost,
      'amazon-q' => AmazonQConnector.isSupportedRegion(
            amazonQRegion ??
                _configString(account.endpointConfig, 'region') ??
                '',
          ) &&
          host ==
              'q.${amazonQRegion ?? _configString(account.endpointConfig, 'region')}.amazonaws.com',
      'vertex' => host == 'aiplatform.googleapis.com' ||
          host == '$location-aiplatform.googleapis.com',
      _ => false,
    };
    if (!allowed) throw const LlmAccountConnectorException();
  }

  static Object? _aiHordeChatBody(Object? body) {
    if (body is! Map) {
      throw const LlmAccountConnectorException();
    }
    final request = Map<String, dynamic>.from(body);
    request.remove('tools');
    request.remove('tool_choice');
    request.remove('parallel_tool_calls');
    final messages = request['messages'];
    if (messages is! List) {
      throw const LlmAccountConnectorException();
    }
    final normalized = <Map<String, dynamic>>[];
    for (final rawMessage in messages) {
      if (rawMessage is! Map) {
        throw const LlmAccountConnectorException();
      }
      final message = Map<String, dynamic>.from(rawMessage);
      final role = message['role'];
      if (!const {'system', 'developer', 'user', 'assistant'}.contains(role) ||
          message['tool_calls'] != null ||
          message['function_call'] != null ||
          message['tool_call_id'] != null) {
        throw const LlmAccountConnectorException();
      }
      final content = message['content'];
      if (content is List) {
        final text = StringBuffer();
        for (final part in content) {
          if (part is! Map ||
              part['type'] != 'text' ||
              part['text'] is! String) {
            throw const LlmAccountConnectorException();
          }
          text.write(part['text'] as String);
        }
        message['content'] = text.toString();
      } else if (content != null && content is! String) {
        throw const LlmAccountConnectorException();
      }
      normalized.add(message);
    }
    request['messages'] = normalized;
    return request;
  }

  static String? _metaBaseUrl(String? credential) {
    if (credential == null) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(credential);
    } catch (_) {
      return null;
    }
    final value = decoded is Map ? decoded['base_url'] : null;
    if (value is! String || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'api.meta.ai' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery) {
      throw const LlmAccountConnectorException();
    }
    final path = uri.path.isEmpty || uri.path == '/' ? '/v1' : uri.path;
    return uri.replace(path: path).toString().replaceFirst(RegExp(r'/+$'), '');
  }

  static String _baseUrl(Map<String, dynamic> config, String fallback) =>
      _configString(config, 'baseUrl') ?? fallback;

  static String _copilotProtocolFor(String modelId, String? nativeFormat) {
    switch (nativeFormat) {
      case 'responses':
        return 'openai.responses';
      case 'anthropic':
        return 'anthropic.messages';
    }
    final normalized = modelId.toLowerCase();
    if (normalized.contains('claude')) return 'anthropic.messages';
    if (normalized.contains('codex')) return 'openai.responses';
    return 'openai.chat_completions';
  }

  static String? _vertexLocation(Map<String, dynamic> config) =>
      _configString(config, 'location') ?? _configString(config, 'region');

  static String? _configString(Map<String, dynamic> config, String key) {
    final value = config[key];
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static String _requiredGoogleCloudProjectId(Map<String, dynamic> config) {
    final projectId = _configString(config, 'googleCloudProjectId');
    if (projectId == null ||
        !RegExp(r'^[a-z][a-z0-9-]{4,28}[a-z0-9]$').hasMatch(projectId)) {
      throw const LlmAccountConnectorException();
    }
    return projectId;
  }

  static String _joinPath(String base, String suffix) {
    if (suffix.isEmpty) return base.isEmpty ? '/' : base;
    if (base.isEmpty || base == '/') return suffix;
    return '${base.replaceFirst(RegExp(r'/+$'), '')}$suffix';
  }
}

/// Safe, content-free failure type for account storage and connector setup.
class LlmAccountConnectorException implements Exception {
  const LlmAccountConnectorException();

  @override
  String toString() => 'LLM connector operation could not be completed.';
}

String _cursorAccessTokenExpiry(String token) {
  try {
    final parts = token.split('.');
    if (parts.length == 3) {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = payload is Map ? payload['exp'] : null;
      if (exp is num) {
        return DateTime.fromMillisecondsSinceEpoch(
          (exp * 1000).round(),
          isUtc: true,
        ).subtract(const Duration(minutes: 5)).toIso8601String();
      }
    }
  } catch (_) {
    // Cursor may return an opaque token; use its one-hour fallback.
  }
  return DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String();
}

class _LlmTokenRefreshRequest {
  final Uri uri;
  final Map<String, dynamic> body;
  final String contentType;
  final Map<String, String> headers;

  const _LlmTokenRefreshRequest({
    required this.uri,
    required this.body,
    required this.contentType,
    this.headers = const {},
  });
}

/// Makes response usage observations without assuming an account balance.
LlmConnectorObservation parseLlmConnectorObservation(
  String connectorType,
  Object? responseBody, {
  DateTime? observedAt,
}) {
  final observed = observedAt ?? DateTime.now().toUtc();
  if (connectorType == 'devin' &&
      (responseBody is Uint8List || responseBody is List<int>)) {
    return _parseDevinConnectUsage(
      responseBody is Uint8List
          ? responseBody
          : Uint8List.fromList(responseBody as List<int>),
      observed,
    );
  }
  if (responseBody is! Map) return LlmConnectorObservation();
  Map? usage;
  if (responseBody['usage'] is Map) {
    usage = responseBody['usage'] as Map;
  } else if (responseBody['usageMetadata'] is Map) {
    usage = responseBody['usageMetadata'] as Map;
  } else if (responseBody['response'] is Map &&
      (responseBody['response'] as Map)['usage'] is Map) {
    usage = (responseBody['response'] as Map)['usage'] as Map;
  } else if (responseBody['message'] is Map &&
      (responseBody['message'] as Map)['usage'] is Map) {
    usage = (responseBody['message'] as Map)['usage'] as Map;
  }
  final input = _firstNumber(usage, const [
    'input_tokens',
    'prompt_tokens',
    'promptTokenCount',
  ]);
  final output = _firstNumber(usage, const [
    'output_tokens',
    'completion_tokens',
    'candidatesTokenCount',
  ]);
  final total = _firstNumber(usage, const ['totalTokenCount', 'total_tokens']);
  final hasUsage = input != null || output != null || total != null;
  final requestUsage = !hasUsage
      ? const LlmMetricObservation.unknown()
      : LlmMetricObservation.reported(
          total ?? (input ?? 0) + (output ?? 0),
          unit: 'tokens',
          source: connectorType,
          observedAt: observed,
        );
  final quotaSignals = connectorType == 'codex'
      ? _parseCodexQuotaSignals(responseBody, observed)
      : const <String, LlmMetricObservation>{};
  return LlmConnectorObservation(
    requestUsage: requestUsage,
    remainingQuota: const LlmMetricObservation.unknown(),
    quotaSignals: quotaSignals,
  );
}

LlmConnectorObservation parseLlmConnectorHeaderObservation(
  String connectorType,
  Map<String, List<String>> headers, {
  DateTime? observedAt,
}) {
  if (connectorType != 'codex') return LlmConnectorObservation();
  final normalized = <String, String>{};
  for (final entry in headers.entries) {
    if (entry.value.isNotEmpty) {
      normalized[entry.key.toLowerCase()] = entry.value.first;
    }
  }
  final observed = observedAt ?? DateTime.now().toUtc();
  final signals = <String, LlmMetricObservation>{};
  for (final (headerName, signalName) in const [
    ('x-codex-primary-used-percent', 'primaryRemainingPercent'),
    ('x-codex-secondary-used-percent', 'secondaryRemainingPercent'),
    ('x-codex-code-review-used-percent', 'codeReviewRemainingPercent'),
  ]) {
    final used = num.tryParse(normalized[headerName] ?? '');
    if (used == null || used < 0 || used > 100) continue;
    signals[signalName] = LlmMetricObservation.reported(
      100 - used,
      unit: 'percent',
      source: 'codex.$signalName',
      observedAt: observed,
    );
  }
  return LlmConnectorObservation(quotaSignals: signals);
}

LlmConnectorObservation mergeLlmConnectorObservations(
  LlmConnectorObservation first,
  LlmConnectorObservation second,
) =>
    LlmConnectorObservation(
      requestUsage: second.requestUsage.isKnown
          ? second.requestUsage
          : first.requestUsage,
      remainingQuota: second.remainingQuota.isKnown
          ? second.remainingQuota
          : first.remainingQuota,
      quotaSignals: {...first.quotaSignals, ...second.quotaSignals},
    );

class LlmConnectorSseObservationAccumulator {
  final String connectorType;
  final DateTime? observedAt;
  num? _claudeInputTokens;
  num? _claudeOutputTokens;

  LlmConnectorSseObservationAccumulator(this.connectorType, {this.observedAt});

  LlmConnectorObservation observe(Map frame) {
    final frameObservation = parseLlmConnectorObservation(
      connectorType,
      frame,
      observedAt: observedAt,
    );
    if (connectorType != 'claude') return frameObservation;

    final eventType = frame['type'];
    final Map? usage = switch (eventType) {
      'message_start' when frame['message'] is Map =>
        (frame['message'] as Map)['usage'] is Map
            ? (frame['message'] as Map)['usage'] as Map
            : null,
      'message_delta' when frame['usage'] is Map => frame['usage'] as Map,
      _ => null,
    };
    if (usage == null) return frameObservation;

    final inputTokens = _firstNumber(usage, const [
      'input_tokens',
      'prompt_tokens',
    ]);
    final outputTokens = _firstNumber(usage, const [
      'output_tokens',
      'completion_tokens',
    ]);
    if (inputTokens != null) _claudeInputTokens = inputTokens;
    if (outputTokens != null) _claudeOutputTokens = outputTokens;
    if (_claudeInputTokens == null && _claudeOutputTokens == null) {
      return frameObservation;
    }
    return LlmConnectorObservation(
      requestUsage: LlmMetricObservation.reported(
        (_claudeInputTokens ?? 0) + (_claudeOutputTokens ?? 0),
        unit: 'tokens',
        source: connectorType,
        observedAt: observedAt ?? DateTime.now().toUtc(),
      ),
      remainingQuota: frameObservation.remainingQuota,
      quotaSignals: frameObservation.quotaSignals,
    );
  }
}

LlmConnectorObservation parseLlmConnectorSseObservation(
  String connectorType,
  List<int> bytes, {
  DateTime? observedAt,
}) {
  final text = utf8.decode(bytes, allowMalformed: true);
  final dataLines = <String>[];
  var observation = LlmConnectorObservation();
  var dataLinesLength = 0;
  var discardingOversizedFrame = false;
  final accumulator = LlmConnectorSseObservationAccumulator(
    connectorType,
    observedAt: observedAt,
  );
  const maxSseFrameCharacters = 1048576;

  void clearFrame() {
    dataLines.clear();
    dataLinesLength = 0;
  }

  void addDataLine(String data) {
    if (discardingOversizedFrame) return;
    if (dataLinesLength + data.length + 1 > maxSseFrameCharacters) {
      clearFrame();
      discardingOversizedFrame = true;
      return;
    }
    dataLines.add(data);
    dataLinesLength += data.length + 1;
  }

  void observeFrame() {
    if (discardingOversizedFrame) {
      clearFrame();
      discardingOversizedFrame = false;
      return;
    }
    if (dataLines.isEmpty) return;
    final data = dataLines.join('\n').trim();
    clearFrame();
    if (data.isEmpty || data == '[DONE]') return;
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        observation = mergeLlmConnectorObservations(
          observation,
          accumulator.observe(decoded),
        );
      }
    } catch (_) {
      // Non-JSON event data is not an observation.
    }
  }

  var lineStart = 0;
  while (lineStart < text.length) {
    final newline = text.indexOf('\n', lineStart);
    final lineEnd = newline < 0 ? text.length : newline;
    final lineLength = lineEnd - lineStart;
    if (lineLength > maxSseFrameCharacters) {
      clearFrame();
      discardingOversizedFrame = true;
    } else {
      var line = text.substring(lineStart, lineEnd);
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
      if (line.isEmpty) {
        observeFrame();
      } else if (line.startsWith('data:')) {
        var data = line.substring(5);
        if (data.startsWith(' ')) data = data.substring(1);
        addDataLine(data);
      }
    }
    if (newline < 0) break;
    lineStart = newline + 1;
  }
  observeFrame();
  return observation;
}

LlmConnectorObservation _parseDevinConnectUsage(
  Uint8List response,
  DateTime observedAt,
) {
  var offset = 0;
  num? promptTokens;
  num? completionTokens;
  num? cachedTokens;
  var foundFrame = false;

  while (offset + 5 <= response.length) {
    final flag = response[offset];
    final length = (response[offset + 1] << 24) |
        (response[offset + 2] << 16) |
        (response[offset + 3] << 8) |
        response[offset + 4];
    offset += 5;
    final end = offset + length;
    if ((flag != 0 && flag != 2) || length < 0 || end > response.length) {
      return LlmConnectorObservation();
    }
    foundFrame = true;
    if (flag == 0) {
      final parsed = _parseDevinFrameUsage(response.sublist(offset, end));
      promptTokens = parsed.promptTokens ?? promptTokens;
      completionTokens = parsed.completionTokens ?? completionTokens;
      cachedTokens = parsed.cachedTokens ?? cachedTokens;
    }
    offset = end;
  }
  if (!foundFrame || offset != response.length) {
    return LlmConnectorObservation();
  }
  final prompt = (promptTokens ?? 0) + (cachedTokens ?? 0);
  final total = prompt + (completionTokens ?? 0);
  if (total == 0 && promptTokens == null && completionTokens == null) {
    return LlmConnectorObservation();
  }
  return LlmConnectorObservation(
    requestUsage: LlmMetricObservation.reported(
      total,
      unit: 'tokens',
      source: 'devin',
      observedAt: observedAt,
    ),
  );
}

({num? promptTokens, num? completionTokens, num? cachedTokens})
    _parseDevinFrameUsage(Uint8List payload) {
  var offset = 0;
  num? promptTokens;
  num? completionTokens;
  num? cachedTokens;
  while (offset < payload.length) {
    final tag = _readProtoVarint(payload, offset);
    if (tag == null || tag.value == 0) break;
    offset = tag.nextOffset;
    final fieldNumber = tag.value >> 3;
    final wireType = tag.value & 7;
    if (wireType == 2) {
      final size = _readProtoVarint(payload, offset);
      if (size == null || size.value < 0) break;
      offset = size.nextOffset;
      final end = offset + size.value;
      if (end > payload.length) break;
      if (fieldNumber == 7) {
        final usage = _parseDevinUsage(payload.sublist(offset, end));
        promptTokens = usage.promptTokens ?? promptTokens;
        completionTokens = usage.completionTokens ?? completionTokens;
        cachedTokens = usage.cachedTokens ?? cachedTokens;
      } else if (fieldNumber == 28) {
        final dimensions = _parseDevinDimensionGroup(
          payload.sublist(offset, end),
        );
        promptTokens = dimensions.promptTokens ?? promptTokens;
        completionTokens = dimensions.completionTokens ?? completionTokens;
        cachedTokens = dimensions.cachedTokens ?? cachedTokens;
      }
      offset = end;
      continue;
    }
    final next = _skipProtoValue(payload, offset, wireType);
    if (next == null) break;
    offset = next;
  }
  return (
    promptTokens: promptTokens,
    completionTokens: completionTokens,
    cachedTokens: cachedTokens,
  );
}

({num? promptTokens, num? completionTokens, num? cachedTokens})
    _parseDevinUsage(Uint8List payload) {
  var offset = 0;
  num? promptTokens;
  num? completionTokens;
  num? cachedTokens;
  while (offset < payload.length) {
    final tag = _readProtoVarint(payload, offset);
    if (tag == null || tag.value == 0) break;
    offset = tag.nextOffset;
    final fieldNumber = tag.value >> 3;
    final wireType = tag.value & 7;
    if (wireType == 0) {
      final value = _readProtoVarint(payload, offset);
      if (value == null) break;
      offset = value.nextOffset;
      switch (fieldNumber) {
        case 2:
          promptTokens = value.value;
        case 3:
          completionTokens = value.value;
        case 5:
          cachedTokens = value.value;
      }
      continue;
    }
    final next = _skipProtoValue(payload, offset, wireType);
    if (next == null) break;
    offset = next;
  }
  return (
    promptTokens: promptTokens,
    completionTokens: completionTokens,
    cachedTokens: cachedTokens,
  );
}

({num? promptTokens, num? completionTokens, num? cachedTokens})
    _parseDevinDimensionGroup(Uint8List payload) {
  var offset = 0;
  String? title;
  final metrics = <String, num>{};
  while (offset < payload.length) {
    final tag = _readProtoVarint(payload, offset);
    if (tag == null || tag.value == 0) break;
    offset = tag.nextOffset;
    final fieldNumber = tag.value >> 3;
    final wireType = tag.value & 7;
    if (wireType != 2) {
      final next = _skipProtoValue(payload, offset, wireType);
      if (next == null) break;
      offset = next;
      continue;
    }
    final size = _readProtoVarint(payload, offset);
    if (size == null || size.value < 0) break;
    offset = size.nextOffset;
    final end = offset + size.value;
    if (end > payload.length) break;
    final value = payload.sublist(offset, end);
    offset = end;
    if (fieldNumber == 1) {
      title = utf8.decode(value, allowMalformed: true);
    } else if (fieldNumber == 2) {
      final metric = _parseDevinMetric(value);
      if (metric.$1 != null && metric.$2 != null) {
        metrics[metric.$1!] = metric.$2!;
      }
    }
  }
  if (title != 'Token Usage') {
    return (promptTokens: null, completionTokens: null, cachedTokens: null);
  }
  return (
    promptTokens: metrics['input_tokens'],
    completionTokens: metrics['output_tokens'],
    cachedTokens: metrics['cached_input_tokens'],
  );
}

(String?, num?) _parseDevinMetric(Uint8List payload) {
  var offset = 0;
  String? key;
  num? value;
  while (offset < payload.length) {
    final tag = _readProtoVarint(payload, offset);
    if (tag == null || tag.value == 0) break;
    offset = tag.nextOffset;
    final fieldNumber = tag.value >> 3;
    final wireType = tag.value & 7;
    if (wireType != 2) {
      final next = _skipProtoValue(payload, offset, wireType);
      if (next == null) break;
      offset = next;
      continue;
    }
    final size = _readProtoVarint(payload, offset);
    if (size == null || size.value < 0) break;
    offset = size.nextOffset;
    final end = offset + size.value;
    if (end > payload.length) break;
    final nested = payload.sublist(offset, end);
    offset = end;
    if (fieldNumber == 5) {
      key = utf8.decode(nested, allowMalformed: true);
    } else if (fieldNumber == 4) {
      var nestedOffset = 0;
      while (nestedOffset < nested.length) {
        final nestedTag = _readProtoVarint(nested, nestedOffset);
        if (nestedTag == null || nestedTag.value == 0) break;
        nestedOffset = nestedTag.nextOffset;
        final nestedField = nestedTag.value >> 3;
        final nestedWire = nestedTag.value & 7;
        if (nestedWire == 5 &&
            nestedField == 2 &&
            nestedOffset + 4 <= nested.length) {
          value = ByteData.sublistView(
            nested,
            nestedOffset,
            nestedOffset + 4,
          ).getFloat32(0, Endian.little);
        }
        final next = _skipProtoValue(nested, nestedOffset, nestedWire);
        if (next == null) break;
        nestedOffset = next;
      }
    }
  }
  return (key, value);
}

({int value, int nextOffset})? _readProtoVarint(Uint8List bytes, int offset) {
  var value = 0;
  var shift = 0;
  while (offset < bytes.length && shift < 64) {
    final byte = bytes[offset++];
    value |= (byte & 0x7f) << shift;
    if (byte & 0x80 == 0) return (value: value, nextOffset: offset);
    shift += 7;
  }
  return null;
}

int? _skipProtoValue(Uint8List bytes, int offset, int wireType) {
  switch (wireType) {
    case 0:
      return _readProtoVarint(bytes, offset)?.nextOffset;
    case 1:
      return offset + 8 <= bytes.length ? offset + 8 : null;
    case 2:
      final size = _readProtoVarint(bytes, offset);
      if (size == null) return null;
      final end = size.nextOffset + size.value;
      return end <= bytes.length ? end : null;
    case 5:
      return offset + 4 <= bytes.length ? offset + 4 : null;
    default:
      return null;
  }
}

Map<String, LlmMetricObservation> _parseCodexQuotaSignals(
  Map responseBody,
  DateTime observedAt,
) {
  if (responseBody['type'] != 'codex.rate_limits') {
    return const <String, LlmMetricObservation>{};
  }
  final rawLimits = responseBody['rate_limits'];
  if (rawLimits is! Map) return const <String, LlmMetricObservation>{};
  final signals = <String, LlmMetricObservation>{};
  for (final window in const ['primary', 'secondary', 'code_review']) {
    final rawWindow = rawLimits[window];
    if (rawWindow is! Map) continue;
    final used = _firstNumber(rawWindow, const ['used_percent', 'usedPercent']);
    if (used == null || used < 0 || used > 100) continue;
    final key =
        '${window == 'code_review' ? 'codeReview' : window}RemainingPercent';
    signals[key] = LlmMetricObservation.reported(
      100 - used,
      unit: 'percent',
      source: 'codex.$window',
      observedAt: observedAt,
    );
  }
  return signals;
}

num? _firstNumber(Map? values, List<String> names) {
  if (values == null) return null;
  for (final name in names) {
    final value = values[name];
    if (value is num) return value;
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

bool _isPersistableQuotaMetric(LlmMetricObservation metric) =>
    metric.isKnown &&
    metric.value != null &&
    metric.value!.isFinite &&
    metric.value! >= 0;

LlmMetricObservation _preferNewerQuotaMetric(
  LlmMetricObservation current,
  LlmMetricObservation incoming,
) {
  if (!_isPersistableQuotaMetric(incoming)) return current;
  if (!_isPersistableQuotaMetric(current)) return incoming;
  final currentAt = current.observedAt;
  final incomingAt = incoming.observedAt;
  if (currentAt != null &&
      (incomingAt == null || incomingAt.isBefore(currentAt))) {
    return current;
  }
  return incoming;
}
