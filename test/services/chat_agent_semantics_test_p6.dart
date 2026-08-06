part of 'chat_agent_semantics_test.dart';

void chatAgentSemanticsGroup6() {
  group('模型无 context 配置时不压缩', () {
    test('threshold null → 不触发压缩（无 modelContext）', () async {
      final container = _makeContainer(
        conversations: [Conversation(id: 'conv-nocontext', title: '')],
      );
      final manager = container.read(chatStreamManagerProvider);
      final provider = _RecordingProvider([
        [AIStreamEvent('回答')],
      ]);
      // modelConfig 无 context（typeConfig 空）
      manager.adapter.forceService(ChatService(
        provider: provider,
        modelConfig: ModelConfig(name: 'm', modelId: 'test-model'),
      ));

      await manager.startStreaming(
        text: 'hi',
        convId: 'conv-nocontext',
        history: [
          ChatMessage(role: 'assistant', content: 'x' * 10000),
          ChatMessage(role: 'user', content: 'q1'),
          ChatMessage(role: 'user', content: 'q2'),
        ],
      );

      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-nocontext')
          .first;
      expect(conv.contextSummary, isNull);
      container.dispose();
    });
  });

  group('工具循环多轮 usage 累计', () {
    test('工具循环每轮 usage 都计入累计（不止最后一轮）', () async {
      final container = _makeContainer(
        conversations: [Conversation(id: 'conv-multi', title: '')],
      );
      final manager = container.read(chatStreamManagerProvider);
      // 两轮工具 + 一轮文本
      final provider = _RecordingProvider([
        [
          AIStreamEvent('', toolCalls: [
            {
              'id': 'call_1',
              'type': 'function',
              'function': {
                'name': 'loop_tool',
                'arguments': '{"i": 1}',
              },
            },
          ]),
        ],
        [
          AIStreamEvent('', toolCalls: [
            {
              'id': 'call_2',
              'type': 'function',
              'function': {
                'name': 'loop_tool',
                'arguments': '{"i": 2}',
              },
            },
          ]),
        ],
        [AIStreamEvent('完成')],
      ])
        ..usage = {'inputTokens': 100, 'outputTokens': 10, 'cost': 0.0001};
      manager.adapter.forceService(ChatService(
        provider: provider,
        modelConfig: _createModelConfig(context: 1000000),
      ));
      ChatService.registerTool(
        const ToolDefinition(
          name: 'loop_tool',
          description: 'loop',
          parameters: {'type': 'object'},
        ),
        (args) => 'ok',
      );

      await manager.startStreaming(
        text: 'go',
        convId: 'conv-multi',
        history: [ChatMessage(role: 'user', content: 'go')],
        tools: ChatService.getRegisteredToolDefinitions(),
      );

      // 3 次主请求（2 工具轮 + 1 收尾/文本轮）+ 标题请求：
      // - cost 每轮累加（对话级累计，4 × 0.0001）
      // - lastInputTokens = 最近一次请求的输入（工具循环中每轮请求的
      //   输入已包含前一轮内容，累计求和会高估上下文；文档语义即
      //   "最近一次请求的实际输入 token 数"）
      await _waitFor(() => provider.captures.length >= 4); // 3 主轮 + 标题
      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-multi')
          .first;
      expect(conv.lastInputTokens, 100); // 最近一轮的输入（标题请求不写 tokens）
      expect(conv.totalCost, closeTo(0.0004, 1e-9)); // 4 × 0.0001（含标题）
      container.dispose();
    });
  });

  group('usage 未返回时保留旧计量', () {
    test('后续请求无 usage 不清空 lastInputTokens', () async {
      final container = _makeContainer(
        conversations: [
          Conversation(id: 'conv-stale', title: '', lastInputTokens: 500),
        ],
      );
      final manager = container.read(chatStreamManagerProvider);
      final provider = _RecordingProvider([
        [AIStreamEvent('回答')],
      ]); // 无 usage
      manager.adapter.forceService(_makeService(provider));

      await manager.startStreaming(
        text: 'hi',
        convId: 'conv-stale',
        history: [ChatMessage(role: 'user', content: 'hi')],
      );

      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-stale')
          .first;
      expect(conv.lastInputTokens, 500);
      container.dispose();
    });
  });
}
