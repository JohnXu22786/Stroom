import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import '../models/assistant.dart' show AssistantSettings, CustomParameter;
import '../models/chat_event.dart';
import '../models/chat_message.dart';
import '../models/mcp.dart';
import '../models/tool_call.dart';
import '../models/tts_models.dart' show CustomParam;
import '../providers/provider_config.dart';
import 'chat_service.dart';
import 'http_tool_service.dart';
import 'todo_tool_service.dart';
import 'web_search_service.dart';
import '../providers/chat_api_provider.dart';
import 'mcp_client.dart';

/// Internal pairing of an McpServerConfig with its vendor description.
///
/// Used by [ChatAdapter.initializeMcpServers] to carry the description
/// from the provider config's typeConfig alongside the server config,
/// so that placeholder tool definitions can be created for vendors
/// whose servers are unreachable.
class _McpConfigEntry {
  final McpServerConfig config;
  final String description;

  const _McpConfigEntry({
    required this.config,
    required this.description,
  });
}

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

  /// The [ChatService] instance most recently created or explicitly set.
  /// Returns null when no service has been configured yet. For per-conversation
  /// access use [_getOrCreateService] or [_activeServices].
  ChatService? get currentChatService => _activeServices.values.firstOrNull;

  /// MCP 客户端管理器
  final McpClientManager _mcpClientManager = McpClientManager();

  /// 缓存的 MCP 工具列表
  List<ToolDefinition> _mcpToolDefinitions = [];

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

  /// Gets the model-level custom parameters (模型页自定义参数)
  /// from the current model config.
  /// These are distinct from reasoning/inference parameters.
  List<CustomParam> get customParams {
    return _cachedModelConfig?.customParams ?? [];
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

  /// 初始化内置工具（HTTP 工具），与 MCP SSE 服务器初始化独立。
  ///
  /// 此方法确保 HTTP 工具（如 brave_web_search、bocha_web_search 等）
  /// 始终被注册，不受 MCP 服务器连接状态影响。
  /// 即使 MCP 条目不存在或为空，也会尝试注册已缓存的工具。
  void initializeBuiltinTools(ProviderEntriesState entriesState) {
    final mcpEntry =
        entriesState.entries.where((e) => e.type == 'mcp').firstOrNull;

    String? braveApiKey, bochaApiKey, queritApiKey, searxngUrl, searxngApiKey;

    if (mcpEntry != null && mcpEntry.configs.isNotEmpty) {
      for (final config in mcpEntry.configs) {
        final typeConfig =
            config.models.isNotEmpty ? config.models[0].typeConfig : null;

        // Collect API keys from HTTP tool configs
        final isHttpTool = typeConfig?['isHttpTool'] as bool? ?? false;
        if (isHttpTool) {
          debugPrint(
              'BuiltinTools: collecting API key for "${config.providerName}"');
          _collectHttpToolApiKey(
            config.providerName,
            typeConfig,
            (key) => braveApiKey ??= key,
            (key) => bochaApiKey ??= key,
            (key) => queritApiKey ??= key,
            (url) => searxngUrl ??= url,
            (key) => searxngApiKey ??= key,
          );
        }
      }
    }

    // Always update API keys and register HTTP tools, even if no configs
    // were found. This ensures previously registered tools remain available
    // and new API keys take effect.
    HttpToolService.updateApiKeys(
      braveApiKey: braveApiKey,
      bochaApiKey: bochaApiKey,
      queritApiKey: queritApiKey,
      searxngUrl: searxngUrl,
      searxngApiKey: searxngApiKey,
    );

    // Register HTTP tool handlers in ChatService (idempotent)
    _registerHttpTools();

    // Set McpClientManager on ChatService for tool routing
    ChatService.setMcpClientManager(_mcpClientManager);
  }

  /// 初始化 MCP 客户端（SSE / stdio）并发现工具。
  ///
  /// 仅处理非 HTTP 工具的 MCP 服务器配置。HTTP 工具由 [initializeBuiltinTools] 独立处理。
  /// MCP 服务器连接失败不会影响已注册的内置工具。
  ///
  /// 对内置供应商（isVendor=true）的 MCP 服务器，即使连接失败也会创建占位工具定义，
  /// 确保所有 MCP 供应商的工具都在工具列表中可见，不会区分"纯 Dart HTTP 工具"和
  /// "SSE MCP 工具"。
  Future<void> initializeMcpServers(ProviderEntriesState entriesState) async {
    final mcpEntry =
        entriesState.entries.where((e) => e.type == 'mcp').firstOrNull;
    if (mcpEntry == null || mcpEntry.configs.isEmpty) return;

    // Build MCP server configs (skip HTTP tools — handled by initializeBuiltinTools)
    // and capture vendor descriptions for placeholder tool creation.
    final mcpConfigs = <_McpConfigEntry>[];

    for (final config in mcpEntry.configs) {
      final typeConfig =
          config.models.isNotEmpty ? config.models[0].typeConfig : null;

      // Skip HTTP tools (pure Dart, not MCP)
      final isHttpTool = typeConfig?['isHttpTool'] as bool? ?? false;
      if (isHttpTool) continue;

      final serverConfig = McpServerConfig.fromProviderConfig(
        providerName: config.providerName,
        typeConfig: typeConfig,
      );
      if (serverConfig != null) {
        final description = typeConfig?['description'] as String? ?? '';
        mcpConfigs.add(_McpConfigEntry(
          config: serverConfig,
          description: description,
        ));
      }
    }

    // Create clients and discover tools from MCP servers
    final allTools = <ToolDefinition>[];

    // First pass: add placeholder tool definitions for vendor MCP providers
    // so they always appear in the tool list even if servers are unreachable.
    // This ensures no distinction between "pure Dart" HTTP tools and SSE MCP tools.
    for (final entry in mcpConfigs) {
      if (entry.config.isVendor && entry.description.isNotEmpty) {
        allTools.add(ToolDefinition(
          name: '${entry.config.name.toLowerCase().replaceAll(' ', '_')}_mcp',
          description: entry.description,
          parameters: const {
            'type': 'object',
            'properties': {},
            'required': <String>[],
          },
        ));
      }
    }

    // Second pass: connect to MCP servers and discover actual tools.
    // When a server connects successfully, replace its placeholder with
    // the actual tool definitions returned by the server.
    // Only remove the placeholder when actual tools are discovered;
    // otherwise keep the placeholder so the provider remains visible.
    for (final entry in mcpConfigs) {
      try {
        final client = McpClient(config: entry.config);
        _mcpClientManager.addClient(entry.config.name, client);

        // Try to connect and list tools
        final tools = await client.listTools();
        final toolDefs = tools.map((t) => t.toToolDefinition()).toList();

        if (toolDefs.isNotEmpty) {
          // Actual tools were discovered — remove the placeholder
          // and use the server-provided definitions instead.
          if (entry.config.isVendor && entry.description.isNotEmpty) {
            allTools.removeWhere(
              (t) =>
                  t.name ==
                  '${entry.config.name.toLowerCase().replaceAll(' ', '_')}_mcp',
            );
          }
          allTools.addAll(toolDefs);
        }

        debugPrint(
          'MCP[${entry.config.name}]: discovered ${toolDefs.length} tools',
        );
      } catch (e) {
        debugPrint('MCP[${entry.config.name}]: init error: $e');
      }
    }
    _mcpToolDefinitions = allTools;
  }

  /// Collect API key from an HTTP tool config entry
  void _collectHttpToolApiKey(
    String name,
    Map<String, dynamic>? typeConfig,
    void Function(String) setBrave,
    void Function(String) setBocha,
    void Function(String) setQuerit,
    void Function(String) setSearxngUrl,
    void Function(String) setSearxngKey,
  ) {
    if (typeConfig == null) return;

    // Try apiKey field first, then headers, then env
    String? extractKey() {
      final apiKey = typeConfig['apiKey'] as String?;
      if (apiKey != null && apiKey.isNotEmpty) return apiKey;
      final headersRaw = typeConfig['headers'];
      if (headersRaw is Map) {
        for (final val in headersRaw.values) {
          final s = val.toString().trim();
          if (s.isNotEmpty && s.length > 3) {
            if (s.startsWith('Bearer ')) return s.substring(7).trim();
            return s;
          }
        }
      }
      final envRaw = typeConfig['env'];
      if (envRaw is Map) {
        for (final val in envRaw.values) {
          final s = val.toString();
          if (s.isNotEmpty) return s;
        }
      }
      return null;
    }

    switch (name) {
      case 'Brave Search':
        setBrave(extractKey() ?? '');
      case 'Bocha':
        setBocha(extractKey() ?? '');
      case 'Querit':
        setQuerit(extractKey() ?? '');
      case 'Searxng':
        final url = typeConfig['url'] as String? ?? 'http://localhost:8080';
        setSearxngUrl(url);
        setSearxngKey(extractKey() ?? '');
    }
  }

  /// Register HTTP tool handlers in ChatService (idempotent — uses static flag)
  static bool _httpToolsRegistered = false;
  void _registerHttpTools() {
    if (_httpToolsRegistered) return;
    _httpToolsRegistered = true;

    for (final def in HttpToolService.toolDefinitions) {
      // Async handler that delegates to the HTTP tool service
      Future<String> handler(Map<String, dynamic> args) async {
        switch (def.name) {
          case 'brave_web_search':
            return await HttpToolService.handleBraveSearch(args);
          case 'bocha_web_search':
            return await HttpToolService.handleBochaSearch(args);
          case 'querit_search':
            return await HttpToolService.handleQueritSearch(args);
          case 'searxng_search':
            return await HttpToolService.handleSearxngSearch(args);
          default:
            return '错误: 未知的 HTTP 工具 "${def.name}"';
        }
      }

      ChatService.registerTool(def, handler);
    }
    debugPrint(
        'Registered ${HttpToolService.toolDefinitions.length} HTTP tools');

    // Register Todo tools (todowrite / todoread)
    for (final def in TodoToolService.toolDefinitions) {
      Future<String> handler(Map<String, dynamic> args) async {
        switch (def.name) {
          case 'todowrite':
            return await TodoToolService.handleTodoWrite(args);
          case 'todoread':
            return await TodoToolService.handleTodoRead(args);
          default:
            return '错误: 未知的 Todo 工具 "${def.name}"';
        }
      }

      ChatService.registerTool(def, handler);
    }
    debugPrint(
        'Registered ${TodoToolService.toolDefinitions.length} Todo tools');

    // Register Web Search tool (web_search - Google/Bing/Baidu)
    for (final def in WebSearchService.toolDefinitions) {
      Future<String> handler(Map<String, dynamic> args) async {
        switch (def.name) {
          case 'web_search':
            return await WebSearchService.handleWebSearch(args);
          default:
            return '错误: 未知的搜索工具 "${def.name}"';
        }
      }

      ChatService.registerTool(def, handler);
    }
    debugPrint(
        'Registered ${WebSearchService.toolDefinitions.length} Web Search tools');
  }

  /// 释放 MCP 资源
  void disposeMcp() {
    _mcpClientManager.disposeAll();
    _mcpToolDefinitions = [];
  }

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
      currentConfigIndex = -1;
      currentModelIndex = -1;
      return;
    }
    debugPrint(
      'ChatAdapter.configure: host=${config.host} model=${modelConfig.modelId}',
    );
    final provider = createChatProviderFromConfig(
      providerName: config.providerName,
      baseUrl: config.host,
      apiKey: config.key,
    );
    _cachedProvider = provider;
    _cachedModelConfig = modelConfig;
    _cachedProviderConfig = config;
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
      currentConfigIndex = -1;
      currentModelIndex = -1;
      return;
    }
    if (modelIndex < 0 || modelIndex >= config.models.length) {
      debugPrint('ChatAdapter.selectModel: invalid modelIndex=$modelIndex');
      _cachedProvider = null;
      _cachedModelConfig = null;
      _cachedProviderConfig = null;
      currentConfigIndex = -1;
      currentModelIndex = -1;
      return;
    }
    final modelConfig = config.models[modelIndex];
    debugPrint(
      'ChatAdapter.selectModel: using config[$configIndex] host=${config.host} model=${modelConfig.modelId}',
    );
    final provider = createChatProviderFromConfig(
      providerName: config.providerName,
      baseUrl: config.host,
      apiKey: config.key,
    );
    _cachedProvider = provider;
    _cachedModelConfig = modelConfig;
    _cachedProviderConfig = config;
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
    _cachedProvider = service.provider;
    _cachedModelConfig = service.modelConfig;
    _cachedProviderConfig = service.providerConfig;
    currentConfigIndex = 0;
    currentModelIndex = 0;
  }

  /// 释放所有资源
  void dispose() {
    cancelAllServices();
    _cachedProvider = null;
    _cachedModelConfig = null;
    _cachedProviderConfig = null;
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
