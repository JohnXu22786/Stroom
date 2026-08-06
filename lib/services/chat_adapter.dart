import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

import '../models/assistant.dart' show AssistantSettings, CustomParameter;
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

  /// 缓存的 MCP 工具列表
  List<ToolDefinition> _mcpToolDefinitions = [];

  /// 正在进行的 MCP 工具发现 future。
  ///
  /// 防并发重发现：页面 _initialize 与 provider-change listener 可能同时
  /// 调用 initializeMcpServers（同一配置）。没有此守卫会并发执行两次
  /// 发现，第二次的 addClient 会 dispose 第一次的 in-flight client，
  /// 导致工具静默丢失。发现完成后置空，允许后续重发现。
  Future<void>? _mcpInitFuture;

  /// 当前选中的配置索引（指向 llmEntry.configs）
  int currentConfigIndex = -1;

  /// 当前选中的模型索引（指向 configs[currentConfigIndex].models）
  int currentModelIndex = -1;

  bool get isConfigured => _cachedProvider != null;

  /// Whether the current model has reasoning parameters configured.
  /// A model with only an empty toggle (all fields empty) has no reasoning
  /// params configured, so the chat page should not show the reasoning toggle.
  bool get hasReasoningParams {
    final config = _cachedModelConfig;
    if (config == null || config.reasoningParams.isEmpty) return false;
    // At least one param must be actually configured (not all-empty toggle)
    return config.reasoningParams.any((rp) {
      if (rp.isReasoningToggle) {
        return rp.isFilledToggle;
      }
      return rp.paramName.trim().isNotEmpty;
    });
  }

  /// Gets the reasoning parameters from the current model config.
  List<ReasoningParam> get reasoningParams {
    return _cachedModelConfig?.reasoningParams ?? [];
  }

  /// 获取当前 MCP 工具定义列表
  List<ToolDefinition> get mcpToolDefinitions =>
      List.unmodifiable(_mcpToolDefinitions);

  // ── Per-conversation service management ───────────────────────────────

  /// Creates (or returns an existing) [ChatService] for the given
  /// conversation. Each conversation gets an independent HTTP connection,
  /// enabling concurrent streaming across multiple conversations.
  /// Returns null if the adapter hasn't been configured yet.
  ChatService? getOrCreateService(String convId) {
    if (_cachedProvider == null || _cachedModelConfig == null) return null;
    return _activeServices.putIfAbsent(convId, () {
      final svc = ChatService(
        provider: _cachedProvider!,
        modelConfig: _cachedModelConfig!,
        providerConfig: _cachedProviderConfig,
        endpointType: _cachedEndpointType,
      );
      // Apply any assistant settings that were set on the "template"
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
    });
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

  /// Hash of the last entries state used for MCP initialization.
  /// Prevents redundant re-discovery across page mounts, but allows
  /// re-initialization when the provider config actually changes.
  int? _lastMcpEntriesHash;

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
    _lastMcpEntriesHash = null;
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
  }) {
    final svc =
        convId.isNotEmpty ? getOrCreateService(convId) : currentChatService;
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
