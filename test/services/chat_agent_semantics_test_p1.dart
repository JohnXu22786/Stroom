part of 'chat_agent_semantics_test.dart';

void chatAgentSemanticsGroup1() {
  group('max-steps 提示词', () {
    test('maxRounds 轮工具后追加收尾轮（工具禁用 + 提示消息）', () async {
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
        [AIStreamEvent('总结完成')],
      ]);
      final service = _makeService(provider);
      service.setAssistantSettings(
        AssistantSettings(maxToolCalls: 2, enableMaxToolCalls: true),
      );
      ChatService.registerTool(
        const ToolDefinition(
          name: 'loop_tool',
          description: 'loop',
          parameters: {'type': 'object'},
        ),
        (args) => 'ok',
      );

      final events = <ChatEvent>[];
      await service
          .sendStreamWithTools(
            'go',
            history: [ChatMessage(role: 'user', content: 'go')],
            tools: ChatService.getRegisteredToolDefinitions(),
          )
          .listen(events.add, onError: (e) => fail('error: $e'))
          .asFuture();

      // 三次请求：工具轮 ×2 + 收尾轮 ×1
      expect(provider.captures, hasLength(3));

      // 工具轮：正常带工具，无收尾提示
      expect(provider.captures[0]['tools'], isNotNull);
      expect(provider.captures[1]['tools'], isNotNull);

      // 收尾轮：tools 定义保留（Anthropic 要求历史含 tool_use/tool_result
      // 块时必须定义 tools）+ tool_choice: none 显式禁用 + MAX_STEPS_PROMPT 前置
      expect(provider.captures[2]['tools'], isNotNull);
      expect(
        (provider.captures[2]['extraParams'] as Map)['tool_choice'],
        'none',
      );
      final lastMsg = (provider.captures[2]['messages'] as List).last as Map;
      // 收尾提示以 user 角色注入（对齐 opencode MAX_STEPS_PROMPT）：
      // assistant 角色注入的"要求"部分模型可能不当作指令执行
      expect(lastMsg['role'], 'user');
      expect(lastMsg['content'], ChatService.maxStepsPrompt);

      // 2 轮工具调用 + 收尾文本；无旧的终止 hack 文本
      expect(events.whereType<ToolCallStartEvent>().length, 2);
      expect(
        events
            .whereType<TextEvent>()
            .where((e) => e.text.contains('已达到工具调用上限')),
        isEmpty,
        reason: 'max-steps 提示词取代了旧的终止 hack 文本',
      );
    });

    test('maxToolCalls=1 仍允许 1 轮工具调用（收尾轮不吞工具轮）', () async {
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
        [AIStreamEvent('收尾总结')],
      ]);
      final service = _makeService(provider);
      service.setAssistantSettings(
        AssistantSettings(maxToolCalls: 1, enableMaxToolCalls: true),
      );
      ChatService.registerTool(
        const ToolDefinition(
          name: 'loop_tool',
          description: 'loop',
          parameters: {'type': 'object'},
        ),
        (args) => 'ok',
      );

      final events = <ChatEvent>[];
      await service
          .sendStreamWithTools(
            'go',
            history: [ChatMessage(role: 'user', content: 'go')],
            tools: ChatService.getRegisteredToolDefinitions(),
          )
          .listen(events.add, onError: (e) => fail('error: $e'))
          .asFuture();

      expect(provider.captures, hasLength(2));
      // 第 1 轮：工具可用
      expect(provider.captures[0]['tools'], isNotNull);
      // 第 2 轮：收尾（tools 保留 + tool_choice none 禁用）
      expect(provider.captures[1]['tools'], isNotNull);
      expect(
        (provider.captures[1]['extraParams'] as Map)['tool_choice'],
        'none',
      );
      expect(events.whereType<ToolCallStartEvent>().length, 1);
    });

    test('未配置 maxToolCalls 时不受影响（无收尾轮）', () async {
      final provider = _RecordingProvider([
        [AIStreamEvent('final')],
      ]);
      final service = _makeService(provider);
      await service
          .sendStreamWithTools(
            'go',
            history: [ChatMessage(role: 'user', content: 'go')],
            tools: const [],
          )
          .listen((_) {})
          .asFuture();
      expect(provider.captures, hasLength(1));
      expect(
        (provider.captures[0]['extraParams'] as Map).containsKey('tool_choice'),
        isFalse,
      );
    });
  });

  group('中断工具标记（manager 层）', () {
    test('取消后 running 工具被标记为中断占位并持久化', () async {
      SharedPreferences.setMockInitialValues({});
      final manager = ChatStreamManager();
      final provider = _RecordingProvider([
        [
          AIStreamEvent('', toolCalls: [
            {
              'id': 'call_slow',
              'type': 'function',
              'function': {
                'name': 'slow_tool',
                'arguments': '{}',
              },
            },
          ]),
        ],
        [AIStreamEvent('answer')],
      ]);
      manager.adapter.forceService(_makeService(provider));
      ChatService.registerTool(
        const ToolDefinition(
          name: 'slow_tool',
          description: 'slow',
          parameters: {'type': 'object'},
        ),
        (args) async {
          await Future.delayed(const Duration(milliseconds: 200));
          return 'slow result';
        },
      );

      final resultFuture = manager.startStreaming(
        text: 'go',
        convId: 'conv-cancel',
        history: [ChatMessage(role: 'user', content: 'go')],
        tools: ChatService.getRegisteredToolDefinitions(),
      );

      // 等工具开始执行后取消
      await Future.delayed(const Duration(milliseconds: 50));
      manager.cancel('conv-cancel');
      final result = await resultFuture;

      expect(result.cancelled, isTrue);
      final toolCalls = result.toolCalls;
      expect(toolCalls, isNotEmpty);
      expect(toolCalls[0].status, ToolCallStatus.completed);
      expect(toolCalls[0].result, ChatService.kToolInterruptedPlaceholder);
      manager.dispose();
    });

    test('纯工具轮取消：中断标记持久化到对话消息（非仅 result）', () async {
      final container = _makeContainer(
        conversations: [Conversation(id: 'conv-pt', title: '')],
      );
      final manager = container.read(chatStreamManagerProvider);
      final provider = _RecordingProvider([
        [
          AIStreamEvent('', toolCalls: [
            {
              'id': 'call_slow',
              'type': 'function',
              'function': {
                'name': 'slow_tool',
                'arguments': '{}',
              },
            },
          ]),
        ],
        [AIStreamEvent('answer')],
      ]);
      manager.adapter.forceService(_makeService(provider));
      ChatService.registerTool(
        const ToolDefinition(
          name: 'slow_tool',
          description: 'slow',
          parameters: {'type': 'object'},
        ),
        (args) async {
          await Future.delayed(const Duration(milliseconds: 200));
          return 'slow result';
        },
      );

      final resultFuture = manager.startStreaming(
        text: 'go',
        convId: 'conv-pt',
        history: [ChatMessage(role: 'user', content: 'go')],
        tools: ChatService.getRegisteredToolDefinitions(),
      );

      await Future.delayed(const Duration(milliseconds: 50));
      manager.cancel('conv-pt');
      final result = await resultFuture;
      expect(result.cancelled, isTrue);

      // 持久化的 assistant 消息（纯工具轮，无文本）含中断标记
      await _waitFor(() =>
          container.read(conversationsProvider).first.messages.length >= 2);
      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-pt')
          .first;
      final assistantMsg = conv.messages.last;
      expect(assistantMsg.role, 'assistant');
      expect(assistantMsg.toolCalls, isNotNull);
      expect(assistantMsg.toolCalls!.single.status, ToolCallStatus.completed);
      expect(
        assistantMsg.toolCalls!.single.result,
        ChatService.kToolInterruptedPlaceholder,
      );
      container.dispose();
    });
  });
}
