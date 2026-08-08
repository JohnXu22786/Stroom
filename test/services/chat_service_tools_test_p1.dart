part of 'chat_service_tools_test.dart';

void chatServiceToolsGroup1() {
  // ====================================================================
  // 懒连接 MCP：进入对话页面不发起任何连接，工具被调用时才按需
  // 连接服务器并列出真实工具。
  // ====================================================================

  group('ChatService - lazy MCP execution', () {
    test(
        'MCP servers stay unconnected after init; the placeholder tool '
        'connects on demand when called', () async {
      final adapter = ChatAdapter();
      addTearDown(adapter.dispose);

      final state = ProviderEntriesState(
        entries: [
          ProviderEntry(
            id: 'test_mcp',
            type: 'mcp',
            name: 'MCP供应商',
            configs: [
              ProviderConfigItem(
                providerName: 'Exa',
                host: 'https://mcp.example.com/mcp',
                key: '',
                models: [
                  ModelConfig(
                    name: 'Exa',
                    modelId: 'sse',
                    typeConfig: {
                      'transport': 'sse',
                      'url': 'https://mcp.example.com/mcp',
                      'isVendor': true,
                      'description': 'Exa MCP search tool',
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      adapter.initializeBuiltinTools(state);
      await adapter.initializeMcpServers(state);

      // 懒连接：初始化后客户端未连接（页面进入不发任何网络请求）。
      final manager = ChatService.mcpClientManager!;
      final client = manager.clients['Exa']!;
      expect(client.isConnected, isFalse,
          reason: 'page init must not connect MCP servers — connections '
              'happen only when a tool is called');

      // 模型调用占位工具 → 按需连接（测试环境连接失败）→ 引导错误信息，
      // 而不是 "Unknown tool"。
      final mockProvider = _MockToolCallProvider([
        const [
          {
            'id': 'call_exa_001',
            'type': 'function',
            'function': {'name': 'exa_mcp', 'arguments': '{}'},
          },
        ],
      ]);
      final service = ChatService(
        provider: mockProvider,
        modelConfig: _createMockModelConfig(),
      );
      addTearDown(service.dispose);

      final events = <ChatEvent>[];
      await service
          .sendStreamWithTools(
            '搜索一下',
            history: [
              ChatMessage(role: 'user', content: '搜索一下'),
            ],
            tools: adapter.getAllToolDefinitions(),
          )
          .listen(
            (event) => events.add(event),
            onError: (e) => fail('Unexpected error: $e'),
          )
          .asFuture();

      final toolComplete = events.whereType<ToolCallCompleteEvent>().first;
      expect(toolComplete.result, contains('连接失败'),
          reason: 'calling the placeholder tool must attempt an on-demand '
              'connection (which fails in the test env) and report the '
              'server state instead of "Unknown tool"');
      expect(client.isDisposed, isFalse,
          reason: 'a failed on-demand connect must not dispose the client');
    });
  });

  // ====================================================================
  // From chat_service_mcp_test.dart
  // ====================================================================

  group('ChatService - MCP tool integration', () {
    test('ToolDefinition from MCP has correct structure', () {
      final mcpTool = ToolDefinition(
        name: 'mcp_fetch',
        description: 'Fetch a URL',
        parameters: {
          'type': 'object',
          'properties': {
            'url': {
              'type': 'string',
              'description': 'The URL to fetch',
            },
          },
          'required': ['url'],
        },
      );

      final json = mcpTool.toJson();
      expect(json['type'], equals('function'));
      expect(json['function']['name'], equals('mcp_fetch'));
      expect(json['function']['description'], equals('Fetch a URL'));

      final params = json['function']['parameters'] as Map<String, dynamic>;
      expect(params['type'], equals('object'));
      expect((params['properties'] as Map<String, dynamic>).containsKey('url'),
          isTrue);
    });

    test('multiple MCP tools can be included in tool list', () {
      final mcpTools = [
        ToolDefinition(
          name: 'mcp_tool_1',
          description: 'Tool 1',
          parameters: {'type': 'object'},
        ),
        ToolDefinition(
          name: 'mcp_tool_2',
          description: 'Tool 2',
          parameters: {'type': 'object'},
        ),
        ToolDefinition(
          name: 'mcp_tool_3',
          description: 'Tool 3',
          parameters: {'type': 'object'},
        ),
      ];

      // Convert to JSON
      final jsonList = mcpTools.map((t) => t.toJson()).toList();
      expect(jsonList.length, equals(3));
      expect(jsonList[0]['function']['name'], equals('mcp_tool_1'));
      expect(jsonList[2]['function']['name'], equals('mcp_tool_3'));
    });

    test('ToolDefinition from MCP with no description', () {
      // MCP tools might have empty descriptions
      final mcpTool = ToolDefinition(
        name: 'bare_tool',
        description: '',
        parameters: {'type': 'object'},
      );

      final json = mcpTool.toJson();
      expect(json['function']['name'], equals('bare_tool'));
      expect(json['function']['description'], isEmpty);
    });
  });
}
