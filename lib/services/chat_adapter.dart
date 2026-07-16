import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/assistant.dart' show AssistantSettings, CustomParameter;
import '../models/chat_event.dart';
import '../models/chat_message.dart';
import '../models/mcp.dart';
import '../models/tool_call.dart';
import '../providers/provider_config.dart';
import 'chat_service.dart';
import 'http_tool_service.dart';
import '../providers/chat_api_provider.dart';
import 'mcp_client.dart';

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
  ChatService? _chatService;

  /// MCP 客户端管理器
  final McpClientManager _mcpClientManager = McpClientManager();

  /// 缓存的 MCP 工具列表
  List<ToolDefinition> _mcpToolDefinitions = [];

  /// 当前选中的配置索引（指向 llmEntry.configs）
  int currentConfigIndex = -1;

  /// 当前选中的模型索引（指向 configs[currentConfigIndex].models）
  int currentModelIndex = -1;

  bool get isConfigured => _chatService != null;

  /// Whether the current model has reasoning parameters configured.
  /// A model with only an empty toggle (all fields empty) has no reasoning
  /// params configured, so the chat page should not show the reasoning toggle.
  bool get hasReasoningParams {
    final config = _chatService?.modelConfig;
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
    return _chatService?.modelConfig?.reasoningParams ?? [];
  }

  /// 获取当前 MCP 工具定义列表
  List<ToolDefinition> get mcpToolDefinitions =>
      List.unmodifiable(_mcpToolDefinitions);

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
  Future<void> initializeMcpServers(ProviderEntriesState entriesState) async {
    final mcpEntry =
        entriesState.entries.where((e) => e.type == 'mcp').firstOrNull;
    if (mcpEntry == null || mcpEntry.configs.isEmpty) return;

    // Build MCP server configs (skip HTTP tools — handled by initializeBuiltinTools)
    final mcpConfigs = <McpServerConfig>[];

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
        mcpConfigs.add(serverConfig);
      }
    }

    // Create clients and discover tools from MCP servers
    final allTools = <ToolDefinition>[];
    for (final mcpConfig in mcpConfigs) {
      try {
        final client = McpClient(config: mcpConfig);
        _mcpClientManager.addClient(mcpConfig.name, client);

        // Try to connect and list tools
        final tools = await client.listTools();
        final toolDefs = tools.map((t) => t.toToolDefinition()).toList();
        allTools.addAll(toolDefs);

        debugPrint(
          'MCP[${mcpConfig.name}]: discovered ${toolDefs.length} tools',
        );
      } catch (e) {
        debugPrint('MCP[${mcpConfig.name}]: init error: $e');
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
      _chatService = null;
      currentConfigIndex = -1;
      currentModelIndex = -1;
      return;
    }
    final config = llmEntry.configs.first;
    if (config.host.isEmpty || config.key.isEmpty) {
      debugPrint('ChatAdapter.configure: first config host or key empty');
      _chatService = null;
      currentConfigIndex = -1;
      currentModelIndex = -1;
      return;
    }
    final modelConfig = config.models.isNotEmpty ? config.models.first : null;
    if (modelConfig == null) {
      debugPrint('ChatAdapter.configure: no models in first config');
      _chatService = null;
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
    _chatService = ChatService(
      provider: provider,
      modelConfig: modelConfig,
      providerConfig: config, // Pass provider-level params for merging
    );
    currentConfigIndex = 0;
    currentModelIndex = 0;
  }

  /// 根据 configIndex / modelIndex 重新创建 ChatService
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
      _chatService = null;
      currentConfigIndex = -1;
      currentModelIndex = -1;
      return;
    }
    final config = llmEntry.configs[configIndex];
    if (config.host.isEmpty || config.key.isEmpty) {
      debugPrint(
        'ChatAdapter.selectModel: config[$configIndex] host or key empty',
      );
      _chatService = null;
      currentConfigIndex = -1;
      currentModelIndex = -1;
      return;
    }
    if (modelIndex < 0 || modelIndex >= config.models.length) {
      debugPrint('ChatAdapter.selectModel: invalid modelIndex=$modelIndex');
      _chatService = null;
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
    _chatService = ChatService(
      provider: provider,
      modelConfig: modelConfig,
      providerConfig: config,
    );
    currentConfigIndex = configIndex;
    currentModelIndex = modelIndex;
  }

  /// 取消当前流
  void cancel() {
    _chatService?.cancel();
  }

  /// 释放资源
  void dispose() {
    cancel();
    _chatService?.dispose();
    _chatService = null;
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
    _chatService?.setAssistantCustomParams(params);
  }

  /// Pass the assistant's system prompt to the underlying ChatService.
  /// This prompt will be prepended as a system-role message in API requests.
  void setAssistantPrompt(String? prompt) {
    _chatService?.setAssistantPrompt(prompt);
  }

  /// Pass assistant-level settings to the underlying ChatService.
  /// When an assistant setting's enable flag is true, it overrides the
  /// corresponding model parameter. When false, the model parameter is used.
  void setAssistantSettings(AssistantSettings? settings) {
    _chatService?.setAssistantSettings(settings);
  }

  Stream<String> sendStream(
    String text, {
    required List<ChatMessage> history,
    bool reasoning = false,
    String reasoningEffort = 'medium',
    Map<String, String> reasoningParamValues = const {},
  }) {
    if (_chatService == null) {
      return Stream.error('请先配置聊天供应商');
    }
    return _chatService!.sendStream(
      text,
      history: history,
      reasoning: reasoning,
      reasoningEffort: reasoningEffort,
      reasoningParamValues: reasoningParamValues,
    );
  }

  /// Send a message with tool call support.
  /// Returns a stream of [ChatEvent] (text chunks and tool call events).
  Stream<ChatEvent> sendStreamWithTools(
    String text, {
    required List<ChatMessage> history,
    bool reasoning = false,
    String reasoningEffort = 'medium',
    Map<String, String> reasoningParamValues = const {},
    List<ToolDefinition> tools = const [],
  }) {
    if (_chatService == null) {
      return Stream.error('请先配置聊天供应商');
    }
    return _chatService!.sendStreamWithTools(
      text,
      history: history,
      reasoning: reasoning,
      reasoningEffort: reasoningEffort,
      reasoningParamValues: reasoningParamValues,
      tools: tools,
    );
  }

  String get reasoningContent => _chatService?.reasoningContent ?? '';

  Map<String, dynamic>? get lastRequestBody => _chatService?.lastRequestBody;
  Map<String, dynamic>? get lastResponseData => _chatService?.lastResponseData;
  Map<String, String>? get lastRequestHeaders =>
      _chatService?.lastRequestHeaders;
  String? get lastRequestUrl => _chatService?.lastRequestUrl;
  int? get lastResponseStatusCode => _chatService?.lastResponseStatusCode;
  Map<String, List<String>>? get lastResponseHeaders =>
      _chatService?.lastResponseHeaders;
}
