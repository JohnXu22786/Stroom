part of 'chat_agent_semantics_test.dart';

void chatAgentSemanticsGroup1() {
  group('工具循环上限', () {
    // 工具循环上限定义（AI SDK stepCountIs 语义）：
    // maxToolCalls = 单条用户消息内模型 API 请求（步骤）的最大次数。
    // 每次 API 响应内的多个并行工具调用属于同一"步骤"，只计 1 次；
    // 计数按用户消息重置，不跨对话累计；达到上限即停止，无额外请求。

    List<AIStreamEvent> toolRound(int i) => [
          AIStreamEvent('', toolCalls: [
            {
              'id': 'call_$i',
              'type': 'function',
              'function': {
                'name': 'loop_tool',
                'arguments': '{"i": $i}',
              },
            },
          ]),
        ];

    setUp(() {
      ChatService.registerTool(
        const ToolDefinition(
          name: 'loop_tool',
          description: 'loop',
          parameters: {'type': 'object'},
        ),
        (args) => 'ok',
      );
    });

    test('maxToolCalls=2：最多 2 次 API 请求，达限即停（无收尾轮）', () async {
      // provider 准备了 3 轮（第 3 轮是文本），但上限 2 → 只发 2 次请求
      final provider = _RecordingProvider([
        toolRound(1),
        toolRound(2),
        [AIStreamEvent('本应第 3 次的回答')],
      ]);
      final service = _makeService(provider);
      service.setAssistantSettings(
        AssistantSettings(maxToolCalls: 2, enableMaxToolCalls: true),
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

      // 恰好 2 次 API 请求（不是 2+1 收尾轮）
      expect(provider.captures, hasLength(2));
      // 两轮都正常带工具，无 tool_choice 禁用
      for (final capture in provider.captures) {
        expect(capture['tools'], isNotNull);
        expect(
          (capture['extraParams'] as Map).containsKey('tool_choice'),
          isFalse,
          reason: '上限内所有轮次工具保持可用（无收尾轮）',
        );
      }
      // 最后一轮请求消息末尾不是注入的"收尾提示"（user 角色）——
      // 旧收尾轮会在最后一轮请求前向 messages 追加提示消息。
      // （第 1 轮 messages 末尾是用户自己的消息，不适用此断言）
      final lastCaptureMessages = provider.captures.last['messages'] as List;
      expect(lastCaptureMessages.last['role'] == 'user', isFalse,
          reason: '无收尾提示注入');
      // 第 2 轮的工具调用仍执行（对齐 AI SDK：最后一轮的工具执行后停止）
      expect(events.whereType<ToolCallStartEvent>().length, 2);
      expect(events.whereType<ToolCallCompleteEvent>().length, 2);
    });

    test('maxToolCalls=1：恰好 1 次 API 请求', () async {
      final provider = _RecordingProvider([
        toolRound(1),
        [AIStreamEvent('本应第 2 次的回答')],
      ]);
      final service = _makeService(provider);
      service.setAssistantSettings(
        AssistantSettings(maxToolCalls: 1, enableMaxToolCalls: true),
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

      expect(provider.captures, hasLength(1));
      expect(provider.captures[0]['tools'], isNotNull);
      expect(
        (provider.captures[0]['extraParams'] as Map).containsKey('tool_choice'),
        isFalse,
      );
      expect(events.whereType<ToolCallStartEvent>().length, 1);
    });

    test('开关关闭时使用默认上限 20（非无限）', () async {
      // 关闭开关 + 用户值 30 → 生效上限为默认 20（关闭开关不等于无限，
      // 仍按默认上限执行）
      final provider = _RecordingProvider(
        List.generate(25, (i) => toolRound(i + 1)),
      );
      final service = _makeService(provider);
      service.setAssistantSettings(
        AssistantSettings(maxToolCalls: 30, enableMaxToolCalls: false),
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

      expect(provider.captures, hasLength(20));
      expect(events.whereType<ToolCallStartEvent>().length, 20);
    });

    test('默认配置（enable=true, maxToolCalls=20）→ 恰好 20 次请求', () async {
      // 钉住用户实际拿到的默认组合（AssistantSettings 默认构造）下
      // 的生效上限：20 次请求。若默认 maxToolCalls 被改动（如 30），
      // 或默认 enable 语义被改动导致生效值变化，此测试会失败。
      final provider = _RecordingProvider(
        List.generate(25, (i) => toolRound(i + 1)),
      );
      final service = _makeService(provider);
      service.setAssistantSettings(AssistantSettings());

      final events = <ChatEvent>[];
      await service
          .sendStreamWithTools(
            'go',
            history: [ChatMessage(role: 'user', content: 'go')],
            tools: ChatService.getRegisteredToolDefinitions(),
          )
          .listen(events.add, onError: (e) => fail('error: $e'))
          .asFuture();

      expect(provider.captures, hasLength(20));
      expect(events.whereType<ToolCallStartEvent>().length, 20);
    });

    test('损坏/越界值回退默认上限 20（0 与 150）', () async {
      for (final invalid in [0, 150]) {
        final provider = _RecordingProvider(
          List.generate(25, (i) => toolRound(i + 1)),
        );
        final service = _makeService(provider);
        service.setAssistantSettings(
          AssistantSettings(maxToolCalls: invalid, enableMaxToolCalls: true),
        );

        await service
            .sendStreamWithTools(
              'go',
              history: [ChatMessage(role: 'user', content: 'go')],
              tools: ChatService.getRegisteredToolDefinitions(),
            )
            .listen((_) {}, onError: (e) => fail('error: $e'))
            .asFuture();

        expect(
          provider.captures,
          hasLength(20),
          reason: 'maxToolCalls=$invalid 应回退默认上限 20，'
              '且不发空流/不无限循环',
        );
      }
    });

    test('getEffectiveMaxToolRounds 值域校验', () {
      // 未配置 / 关闭：默认 20
      expect(ChatService.getEffectiveMaxToolRounds(null), 20);
      expect(
        ChatService.getEffectiveMaxToolRounds(
          AssistantSettings(maxToolCalls: 50, enableMaxToolCalls: false),
        ),
        20,
      );
      // 开启 + 合法值：1..100 原样使用
      expect(
        ChatService.getEffectiveMaxToolRounds(
          AssistantSettings(maxToolCalls: 1, enableMaxToolCalls: true),
        ),
        1,
      );
      expect(
        ChatService.getEffectiveMaxToolRounds(
          AssistantSettings(maxToolCalls: 100, enableMaxToolCalls: true),
        ),
        100,
      );
      // 开启 + 越界/损坏值：回退默认 20
      for (final invalid in [0, -5, 101, 999]) {
        expect(
          ChatService.getEffectiveMaxToolRounds(
            AssistantSettings(maxToolCalls: invalid, enableMaxToolCalls: true),
          ),
          20,
          reason: 'maxToolCalls=$invalid 应回退默认 20',
        );
      }
    });

    test('getEffectiveToolOutputMaxChars 值域校验（字符数）', () {
      // 无助手（null settings）：默认上限 5000 字符（保持始终截断的兜底）。
      expect(ChatService.getEffectiveToolOutputMaxChars(null), 5000);
      // 关闭截断开关：0 = 不截断（完整发送存储结果）。
      expect(
        ChatService.getEffectiveToolOutputMaxChars(
          AssistantSettings(
            maxToolOutputChars: 3000,
            enableMaxToolOutputChars: false,
          ),
        ),
        0,
        reason: '关闭截断必须返回 0（协议层语义：不截断）',
      );
      // 开启 + 合法值：原样使用（最小 100，最大 100000）。
      expect(
        ChatService.getEffectiveToolOutputMaxChars(
          AssistantSettings(maxToolOutputChars: 100, enableMaxToolOutputChars: true),
        ),
        100,
      );
      expect(
        ChatService.getEffectiveToolOutputMaxChars(
          AssistantSettings(
            maxToolOutputChars: 5000,
            enableMaxToolOutputChars: true,
          ),
        ),
        5000,
      );
      expect(
        ChatService.getEffectiveToolOutputMaxChars(
          AssistantSettings(
            maxToolOutputChars: 100000,
            enableMaxToolOutputChars: true,
          ),
        ),
        100000,
      );
      // 开启 + 越界/损坏值：回退默认 5000。
      for (final invalid in [0, -1, 99, 100001, 999999999]) {
        expect(
          ChatService.getEffectiveToolOutputMaxChars(
            AssistantSettings(
              maxToolOutputChars: invalid,
              enableMaxToolOutputChars: true,
            ),
          ),
          5000,
          reason: 'maxToolOutputChars=$invalid 应回退默认 5000',
        );
      }
    });

    test('未设置助手参数：1 次请求，无 tool_choice 注入', () async {
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
          .listen((_) {}, onError: (e) => fail('error: $e'))
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
