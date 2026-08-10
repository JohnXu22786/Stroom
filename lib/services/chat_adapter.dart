import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

import '../models/assistant.dart'
    show Assistant, AssistantSettings, CustomParameter;
import '../models/chat_event.dart';
import '../models/chat_message.dart';
import '../models/mcp.dart';
import '../models/tool_call.dart';
import '../providers/chat_api_provider.dart';
import '../providers/provider_config.dart';
import 'chat_protocol.dart';
import 'chat_service.dart';
import 'http_tool_service.dart';
import 'mcp_client.dart';
import 'todo_tool_service.dart';
import 'web_search_service.dart';

part 'chat_adapter_mcp.dart';
part 'chat_adapter_http_tools.dart';

/// 表示一个可选的模型项
class AvailableModel {
  /// 显示名："[model.name ?? model.modelId] | [providerName]"
  final String displayName;

  /// 指向 llmEntry.configs[configIndex]
  final int configIndex;

  /// 指向 configs[configIndex].models[modelIndex]
  final int modelIndex;

  const AvailableModel({
    required this.displayName,
    required this.configIndex,
    required this.modelIndex,
  });
}

/// 桥接层：将我们的供应商/模型配置系统适配到 flutter_chat_ui 的流式调用
class ChatAdapter {
  /// Per-conversation ChatService instances, keyed by conversation ID.
  /// Each conversation gets its own independent HTTP connection, enabling
  /// multiple conversations to stream concurrently without interference.
  final Map<String, ChatService> _activeServices = {};

  /// Cached parts of the last [configure] / [selectModel] call, used as
  /// a template to create new per-conversation services on demand.
  BaseChatProvider? _cachedProvider;
  ModelConfig? _cachedModelConfig;
  ProviderConfigItem? _cachedProviderConfig;

  /// 有效端点类型（模型覆盖 > 供应商 > 'openai'），
  /// 由 [configure] / [selectModel] 解析并缓存，用于创建协议与服务。
  String _cachedEndpointType = 'openai';

  /// 当前有效端点类型（'openai' | 'anthropic'）。
  String get endpointType => _cachedEndpointType;

  /// 当前缓存的模型配置（供上下文管理估算用）。
  ModelConfig? get modelConfig => _cachedModelConfig;

  /// 当前缓存的对话助手 system prompt（供上下文管理注入用）。
  String? get assistantPrompt => _cachedAssistantPrompt;

  /// The first active [ChatService] instance, or null if none are running.
  /// **Warning**: nondeterministic when multiple conversations are streaming
  /// concurrently. Use [getOrCreateService] with an explicit convId for
  /// per-conversation access.
  ChatService? get currentChatService => _activeServices.values.firstOrNull;

  /// MCP 客户端管理器
  final McpClientManager _mcpClientManager = McpClientManager();

  /// 缓存的 MCP 工具列表（占位工具定义）
  List<ToolDefinition> _mcpToolDefinitions = [];

  /// 上一份已处理的 MCP 供应商条目实例。
  ///
  /// 用于跳过重复初始化：页面重复进入、或其它供应商（TTS/OCR 等）配置
  /// 变更时，entries state 会重建但 MCP 条目实例不变（ProviderEntriesNotifier
  /// 的 update 只替换被更新的条目），此时占位符与客户端都无需重建。
  /// MCP 条目本身被编辑时实例变化，触发重建。
  ProviderEntry? _lastMcpEntry;

  /// 当前选中的配置索引（指向 llmEntry.configs）
  int currentConfigIndex = -1;

  /// 当前选中的模型索引（指向 configs[currentConfigIndex].models）
  int currentModelIndex = -1;

  bool get isConfigured => _cachedProvider != null;

  /// Whether the current model has reasoning parameters configured.
  /// A model with only an empty toggle (all fields empty) has no reasoning
  /// params configured, so the chat page should not show the reasoning toggle.
  /// Provider-level reasoning params count too: a provider-declared toggle
  /// or effort param is enough to enable the chat reasoning UI.
  bool get hasReasoningParams {
    final config = _cachedModelConfig;
    if (config == null) return false;
    final merged = reasoningParams;
    if (merged.isEmpty) return false;
    // At least one param must be actually configured (not all-empty toggle)
    return merged.any((rp) {
      if (rp.isReasoningToggle) {
        return rp.isFilledToggle;
      }
      return rp.paramName.trim().isNotEmpty;
    });
  }

  /// Gets the reasoning parameters for the current model, merged with the
  /// provider-level reasoning params (model params override provider params
  /// with the same name, mirroring the request-building merge in
  /// ChatService._buildExtraParams). The chat UI consumes this merged view
  /// so provider-declared params (e.g. the effort param name) work even
  /// when the model itself doesn't define them.
  ///
  /// 力度参数遮蔽：模型有自己的力度参数（含旧数据回退识别）时，
  /// 供应商的力度参数被模型版本遮蔽——从合并视图中移除，避免
  /// 不可见的陈旧参数（陈旧值会注入请求且 UI 无法清除）。
  ///
  /// Provider-origin params are returned as copies: the chat panel toggles
  /// `param.enabled` in place on these objects, and writing through to the
  /// shared provider config would corrupt every model of the provider (and
  /// the next provider-settings save). Model params keep the pre-existing
  /// live-reference behavior (per-model cached config, replaced on model
  /// switch).
  List<ReasoningParam> get reasoningParams {
    final config = _cachedModelConfig;
    if (config == null) return const [];
    final providerParams = _cachedProviderConfig?.reasoningParams ?? [];
    // 力度参数模型优先（对模型列表独立解析：旧数据回退不被供应商的
    // 现代参数干扰）
    final modelEffort = findEffortParam(config.reasoningParams);
    var merged = mergeReasoningParams(providerParams, config.reasoningParams);
    if (modelEffort != null) {
      merged =
          merged.where((p) => !p.isEffortParam || p == modelEffort).toList();
    }
    final providerNames = providerParams
        .map((p) => p.paramName.trim())
        .where((n) => n.isNotEmpty)
        .toSet();
    final modelNames = config.reasoningParams
        .map((p) => p.paramName.trim())
        .where((n) => n.isNotEmpty)
        .toSet();
    return merged.map((p) {
      final name = p.paramName.trim();
      final isProviderOrigin = name.isNotEmpty &&
          providerNames.contains(name) &&
          !modelNames.contains(name);
      return isProviderOrigin ? p.copy() : p;
    }).toList();
  }

  /// 获取当前 MCP 工具定义列表
  List<ToolDefinition> get mcpToolDefinitions =>
      List.unmodifiable(_mcpToolDefinitions);

  // ── Per-conversation service management ───────────────────────────────

  /// Creates (or returns an existing) [ChatService] for the given
  /// conversation. Each conversation gets an independent HTTP connection,
  /// enabling concurrent streaming across multiple conversations.
  /// Returns null if the adapter hasn't been configured yet.
  ///
  /// When [assistant] is provided (with [entriesState]), the service is
  /// built from the assistant's bound model (its `modelId`) and carries
  /// the assistant's prompt/settings — the global cached model selection
  /// is NOT touched, so a task-flow chat block and the chat page can run
  /// concurrently with different models/assistants. The assistant model
  /// resolution does NOT depend on the global cache: it works even in a
  /// fresh session where the chat page was never opened. If the
  /// assistant's model cannot be resolved, it falls back to the global
  /// config (still applying the assistant's prompt/settings).
  ChatService? getOrCreateService(
    String convId, {
    Assistant? assistant,
    ProviderEntriesState? entriesState,
  }) {
    if (assistant != null && entriesState != null) {
      final resolved = _resolveAssistantModel(
        assistant.modelId,
        entriesState,
      );
      if (resolved != null) {
        final (config, modelConfig) = resolved;
        final endpointType = effectiveEndpointType(
          modelConfig.endpointType,
          config.endpointType,
        );
        final provider = createChatProviderFromConfig(
          providerName: config.providerName,
          baseUrl: config.host,
          apiKey: config.key,
          endpointType: endpointType,
        );
        return _activeServices.putIfAbsent(convId, () {
          return _buildService(
            provider,
            modelConfig,
            config,
            endpointType,
            assistant: assistant,
          );
        });
      }
    }

    // Fallback: the global cached model (requires the adapter to have
    // been configured — e.g. the chat page opened this session).
    if (_cachedProvider == null || _cachedModelConfig == null) return null;
    return _activeServices.putIfAbsent(convId, () {
      final svc = _buildService(
        _cachedProvider!,
        _cachedModelConfig!,
        _cachedProviderConfig,
        _cachedEndpointType,
        assistant: assistant,
      );
      return svc;
    });
  }

  ChatService _buildService(
    BaseChatProvider provider,
    ModelConfig modelConfig,
    ProviderConfigItem? providerConfig,
    String endpointType, {
    Assistant? assistant,
  }) {
    final svc = ChatService(
      provider: provider,
      modelConfig: modelConfig,
      providerConfig: providerConfig,
      endpointType: endpointType,
    );
    // Apply the assistant prompt/settings (explicit assistant wins over
    // the global cached assistant template).
    final prompt = assistant?.prompt ?? _cachedAssistantPrompt;
    final settings = assistant?.settings ?? _cachedAssistantSettings;
    final customParams =
        assistant?.settings.customParameters ?? _cachedAssistantCustomParams;
    if (prompt != null) {
      svc.setAssistantPrompt(prompt);
    }
    if (settings != null) {
      svc.setAssistantSettings(settings);
    }
    if (customParams != null) {
      svc.setAssistantCustomParams(customParams);
    }
    return svc;
  }

  /// Resolves an assistant's bound model (its `modelId`) to its
  /// (config, model) pair within the LLM provider entries.
  (ProviderConfigItem, ModelConfig)? _resolveAssistantModel(
    String? modelId,
    ProviderEntriesState entriesState,
  ) {
    if (modelId == null || modelId.isEmpty) return null;
    final llmEntry =
        entriesState.entries.where((e) => e.type == 'llm').firstOrNull;
    if (llmEntry == null) return null;
    for (final config in llmEntry.configs) {
      if (config.host.isEmpty || config.key.isEmpty) continue;
      for (final model in config.models) {
        if (model.modelId == modelId) {
          return (config, model);
        }
      }
    }
    return null;
  }

  /// 创建一次性 [ChatService]（不缓存、不进入 _activeServices）。
  ///
  /// 供 fire-and-forget 内部任务（如标题生成）使用：若通过
  /// [getOrCreateService] 创建会被 putIfAbsent 缓存，下次流的
  /// cancelService 不会移除它，导致模型切换被旧配置 service 吞掉
  /// （"UI 显示模型 B、请求走模型 A"）。用后即弃，随 GC 回收。
  /// 返回 null 表示 adapter 未配置。
  ChatService? createTransientService() {
    if (_cachedProvider == null || _cachedModelConfig == null) return null;
    final svc = ChatService(
      provider: _cachedProvider!,
      modelConfig: _cachedModelConfig!,
      providerConfig: _cachedProviderConfig,
      endpointType: _cachedEndpointType,
    );
    if (_cachedAssistantPrompt != null) {
      svc.setAssistantPrompt(_cachedAssistantPrompt);
    }
    if (_cachedAssistantSettings != null) {
      svc.setAssistantSettings(_cachedAssistantSettings);
    }
    if (_cachedAssistantCustomParams != null) {
      svc.setAssistantCustomParams(_cachedAssistantCustomParams);
    }
    return svc;
  }

  /// Cancels and disposes the [ChatService] for [convId].
  void cancelService(String convId) {
    final svc = _activeServices.remove(convId);
    svc?.cancel();
    svc?.dispose();
  }

  /// Cancels and disposes ALL per-conversation services.
  void cancelAllServices() {
    for (final svc in _activeServices.values) {
      svc.cancel();
      svc.dispose();
    }
    _activeServices.clear();
  }

  // Cached assistant config applied to newly created services.
  String? _cachedAssistantPrompt;
  AssistantSettings? _cachedAssistantSettings;
  List<CustomParameter>? _cachedAssistantCustomParams;

  /// Register HTTP tool handlers in ChatService (idempotent — uses static flag)
  static bool _httpToolsRegistered = false;

  /// 从 ProviderEntriesState 解析出所有可选的模型列表
  List<AvailableModel> availableModels(ProviderEntriesState entriesState) {
    final llmEntry =
        entriesState.entries.where((e) => e.type == 'llm').firstOrNull;
    if (llmEntry == null || llmEntry.configs.isEmpty) return const [];

    final result = <AvailableModel>[];
    for (var ci = 0; ci < llmEntry.configs.length; ci++) {
      final config = llmEntry.configs[ci];
      for (var mi = 0; mi < config.models.length; mi++) {
        final model = config.models[mi];
        final displayName =
            '${model.name.isNotEmpty ? model.name : model.modelId} | ${config.providerName}';
        result.add(
          AvailableModel(
            displayName: displayName,
            configIndex: ci,
            modelIndex: mi,
          ),
        );
      }
    }
    return result;
  }

  /// 从 ProviderEntriesState 读取 LLM 配置并初始化 ChatService
  void configure(ProviderEntriesState entriesState) {
    final llmEntry =
        entriesState.entries.where((e) => e.type == 'llm').firstOrNull;
    if (llmEntry == null || llmEntry.configs.isEmpty) {
      debugPrint('ChatAdapter.configure: no LLM entry or configs');
      _cachedProvider = null;
      _cachedModelConfig = null;
      _cachedProviderConfig = null;
      _cachedEndpointType = 'openai';
      currentConfigIndex = -1;
      currentModelIndex = -1;
      return;
    }
    final config = llmEntry.configs.first;
    if (config.host.isEmpty || config.key.isEmpty) {
      debugPrint('ChatAdapter.configure: first config host or key empty');
      _cachedProvider = null;
      _cachedModelConfig = null;
      _cachedProviderConfig = null;
      _cachedEndpointType = 'openai';
      currentConfigIndex = -1;
      currentModelIndex = -1;
      return;
    }
    final modelConfig = config.models.isNotEmpty ? config.models.first : null;
    if (modelConfig == null) {
      debugPrint('ChatAdapter.configure: no models in first config');
      _cachedProvider = null;
      _cachedModelConfig = null;
      _cachedProviderConfig = null;
      _cachedEndpointType = 'openai';
      currentConfigIndex = -1;
      currentModelIndex = -1;
      return;
    }
    final endpointType =
        effectiveEndpointType(modelConfig.endpointType, config.endpointType);
    debugPrint(
      'ChatAdapter.configure: host=${config.host} model=${modelConfig.modelId} '
      'endpoint=$endpointType',
    );
    final provider = createChatProviderFromConfig(
      providerName: config.providerName,
      baseUrl: config.host,
      apiKey: config.key,
      endpointType: endpointType,
    );
    _cachedProvider = provider;
    _cachedModelConfig = modelConfig;
    _cachedProviderConfig = config;
    _cachedEndpointType = endpointType;
    currentConfigIndex = 0;
    currentModelIndex = 0;
  }

  /// 根据 configIndex / modelIndex 更新模板配置
  /// Existing per-conversation services keep their old config until the
  /// conversation's stream completes; new streams pick up the updated model.
  void selectModel(
    ProviderEntriesState entriesState,
    int configIndex,
    int modelIndex,
  ) {
    final llmEntry =
        entriesState.entries.where((e) => e.type == 'llm').firstOrNull;
    if (llmEntry == null ||
        configIndex < 0 ||
        configIndex >= llmEntry.configs.length) {
      debugPrint('ChatAdapter.selectModel: invalid configIndex=$configIndex');
      _cachedProvider = null;
      _cachedModelConfig = null;
      _cachedProviderConfig = null;
      _cachedEndpointType = 'openai';
      currentConfigIndex = -1;
      currentModelIndex = -1;
      return;
    }
    final config = llmEntry.configs[configIndex];
    if (config.host.isEmpty || config.key.isEmpty) {
      debugPrint(
        'ChatAdapter.selectModel: config[$configIndex] host or key empty',
      );
      _cachedProvider = null;
      _cachedModelConfig = null;
      _cachedProviderConfig = null;
      _cachedEndpointType = 'openai';
      currentConfigIndex = -1;
      currentModelIndex = -1;
      return;
    }
    if (modelIndex < 0 || modelIndex >= config.models.length) {
      debugPrint('ChatAdapter.selectModel: invalid modelIndex=$modelIndex');
      _cachedProvider = null;
      _cachedModelConfig = null;
      _cachedProviderConfig = null;
      _cachedEndpointType = 'openai';
      currentConfigIndex = -1;
      currentModelIndex = -1;
      return;
    }
    final modelConfig = config.models[modelIndex];
    final endpointType =
        effectiveEndpointType(modelConfig.endpointType, config.endpointType);
    debugPrint(
      'ChatAdapter.selectModel: using config[$configIndex] '
      'host=${config.host} model=${modelConfig.modelId} endpoint=$endpointType',
    );
    final provider = createChatProviderFromConfig(
      providerName: config.providerName,
      baseUrl: config.host,
      apiKey: config.key,
      endpointType: endpointType,
    );
    _cachedProvider = provider;
    _cachedModelConfig = modelConfig;
    _cachedProviderConfig = config;
    _cachedEndpointType = endpointType;
    currentConfigIndex = configIndex;
    currentModelIndex = modelIndex;
  }

  /// 取消所有活跃流的 HTTP 请求
  void cancel() {
    for (final svc in _activeServices.values) {
      svc.cancel();
    }
  }

  /// Injects a [ChatService] instance for testing.
  /// Stores it as the template for future per-conversation services.
  @visibleForTesting
  void forceService(ChatService service) {
    // Extract config from the service for use as template.
    // ignore: invalid_use_of_visible_for_testing_member
    _cachedProvider = service.provider;
    _cachedModelConfig = service.modelConfig;
    // ignore: invalid_use_of_visible_for_testing_member
    _cachedProviderConfig = service.providerConfig;
    // 传播注入服务的端点类型，保证派生 service 的协议一致
    // ignore: invalid_use_of_visible_for_testing_member
    _cachedEndpointType = service.protocol.name;
    currentConfigIndex = 0;
    currentModelIndex = 0;
  }

  /// 释放所有资源
  void dispose() {
    cancelAllServices();
    _cachedProvider = null;
    _cachedModelConfig = null;
    _cachedProviderConfig = null;
    _cachedEndpointType = 'openai';
    currentConfigIndex = -1;
    currentModelIndex = -1;
    disposeMcp();
  }

  /// 获取所有可用工具定义（内置 + MCP）
  List<ToolDefinition> getAllToolDefinitions() {
    // Built-in tools are registered statically via ChatService.registerTool()
    // MCP tools are discovered dynamically
    return [
      ...ChatService.getRegisteredToolDefinitions(),
      ..._mcpToolDefinitions,
    ];
  }

  /// Pass assistant-level custom parameters to the underlying ChatService.
  /// These will be merged into the API request body alongside model-level params.
  void setAssistantCustomParams(List<CustomParameter>? params) {
    _cachedAssistantCustomParams = params;
    for (final svc in _activeServices.values) {
      svc.setAssistantCustomParams(params);
    }
  }

  /// Pass the assistant's system prompt to the underlying ChatService.
  /// This prompt will be prepended as a system-role message in API requests.
  void setAssistantPrompt(String? prompt) {
    _cachedAssistantPrompt = prompt;
    for (final svc in _activeServices.values) {
      svc.setAssistantPrompt(prompt);
    }
  }

  /// Pass assistant-level settings to the underlying ChatService.
  /// When an assistant setting's enable flag is true, it overrides the
  /// corresponding model parameter. When false, the model parameter is used.
  void setAssistantSettings(AssistantSettings? settings) {
    _cachedAssistantSettings = settings;
    for (final svc in _activeServices.values) {
      svc.setAssistantSettings(settings);
    }
  }

  Stream<String> sendStream(
    String text, {
    required List<ChatMessage> history,
    bool reasoning = false,
    String reasoningEffort = 'medium',
    Map<String, String> reasoningParamValues = const {},
    String convId = '',
  }) {
    final svc =
        convId.isNotEmpty ? getOrCreateService(convId) : currentChatService;
    if (svc == null) {
      return Stream.error('请先配置聊天供应商');
    }
    return svc.sendStream(
      text,
      history: history,
      reasoning: reasoning,
      reasoningEffort: reasoningEffort,
      reasoningParamValues: reasoningParamValues,
    );
  }

  /// Send a message with tool call support.
  /// Returns a stream of [ChatEvent] (text chunks and tool call events).
  /// [convId] routes the request to the correct per-conversation service.
  Stream<ChatEvent> sendStreamWithTools(
    String text, {
    required List<ChatMessage> history,
    bool reasoning = false,
    String reasoningEffort = 'medium',
    Map<String, String> reasoningParamValues = const {},
    List<ToolDefinition> tools = const [],
    String convId = '',
    Assistant? assistant,
    ProviderEntriesState? entriesState,
  }) {
    final svc = convId.isNotEmpty
        ? getOrCreateService(convId,
            assistant: assistant, entriesState: entriesState)
        : currentChatService;
    if (svc == null) {
      return Stream.error('请先配置聊天供应商');
    }
    return svc.sendStreamWithTools(
      text,
      history: history,
      reasoning: reasoning,
      reasoningEffort: reasoningEffort,
      reasoningParamValues: reasoningParamValues,
      tools: tools,
    );
  }

  String get reasoningContent => currentChatService?.reasoningContent ?? '';

  Map<String, dynamic>? get lastRequestBody =>
      currentChatService?.lastRequestBody;
  Map<String, dynamic>? get lastResponseData =>
      currentChatService?.lastResponseData;
  Map<String, String>? get lastRequestHeaders =>
      currentChatService?.lastRequestHeaders;
  String? get lastRequestUrl => currentChatService?.lastRequestUrl;
  int? get lastResponseStatusCode => currentChatService?.lastResponseStatusCode;
  Map<String, List<String>>? get lastResponseHeaders =>
      currentChatService?.lastResponseHeaders;
}

/// Resolve the set of tool names to enable for the current conversation.
///
/// Behavior:
/// - If [hasExplicitSavedPrefs] is true (the user has touched the toggles
///   for this conversation), the [savedEnabledNames] set is returned as-is.
///   This is the case for both "user selected some tools" and
///   "user toggled every tool off" — both must survive serialization.
/// - If [hasExplicitSavedPrefs] is false (the conversation has no saved
///   preferences — the default for new conversations), all available tool
///   names are returned so that built-in HTTP tools and built-in remote
///   SSE MCP providers (Exa, Tavily, Jina, Firecrawl, Zhipu) are
///   immediately visible in the conversation page's tool list. Users can
///   still opt-out specific tools via the "可用工具" panel; the opt-out set
///   will be persisted on the next save (with hasExplicitEnabledMcpTools
///   flipped to true).
///
/// This is a pure function to keep the policy testable and easy to reason
/// about. The actual side-effect of writing to [enabledToolNamesProvider]
/// stays in the chat page.
Set<String> resolveEnabledToolNames({
  required List<ToolDefinition> allTools,
  required Set<String> savedEnabledNames,
  required bool hasExplicitSavedPrefs,
}) {
  if (hasExplicitSavedPrefs) {
    return Set<String>.from(savedEnabledNames);
  }
  return allTools.map((t) => t.name).toSet();
}

/// Resolves which model the chat page should restore for the active
/// conversation, when the conversation has a per-conversation record
/// ([Conversation.lastUsedModelName] — set by an assistant default at
/// creation or by the user's own switch inside that conversation).
///
/// Returns the model display name when it still exists among
/// [availableModels]; returns null when the conversation has no record or
/// the recorded model was removed from the provider configs — in both
/// cases the global saved model index applies (the fallback).
///
/// Pure so the priority policy is unit-testable; the side effects (adapter
/// select + per-model settings restore) live in the chat page.
String? perConversationModelToRestore({
  required String? lastUsedModelName,
  required List<AvailableModel> availableModels,
}) {
  final name = lastUsedModelName;
  if (name == null || name.isEmpty) return null;
  if (!availableModels.any((m) => m.displayName == name)) return null;
  return name;
}
