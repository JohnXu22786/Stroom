part of 'chat_adapter.dart';

/// 内置 HTTP 工具初始化逻辑（brave_web_search 等）。
extension ChatAdapterHttpToolsExt on ChatAdapter {
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

    // 占位符（'Bearer ' 前缀等）视为未设置，避免默认工具自动填入假 Key
    String? extractKey() {
      final key = McpServerConfig.extractApiKeyFromTypeConfig(typeConfig);
      return key.isNotEmpty ? key : null;
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
  void _registerHttpTools() {
    if (ChatAdapter._httpToolsRegistered) return;
    ChatAdapter._httpToolsRegistered = true;

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

    // Register Todo tool (todowrite — 读写一体)
    for (final def in TodoToolService.toolDefinitions) {
      Future<String> handler(Map<String, dynamic> args) async {
        switch (def.name) {
          case 'todowrite':
            return await TodoToolService.handleTodo(args);
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
}
