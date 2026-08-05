part of 'chat_agent_semantics_test.dart';

/// 用户场景：重发消息（重试/重新生成/编辑后重发）时计费必须是对话级累计。
///
/// 标准：每次请求的完整 usage 数据返回时立即累加（per-request 事件驱动），
/// 而不是整次发送攒到流结束后一次性提交，更不是从消息内容从头重算。
/// 因此重发/重试/编辑只会在累计值上继续增加，绝不重置、不双计。
void chatAgentSemanticsGroup8() {
  group('重发消息（retry/edit/re-send）计费累计', () {
    // 预置非空标题：禁用自动标题请求，让 usage 队列按请求序确定性消费，
    // 聚焦"重发"本身的累计语义（自动标题计费另测）。
    Conversation convWithTitle(String id) =>
        Conversation(id: id, title: '已有标题');

    test('重试回复：删除旧回复后重新生成，cost 继续累加不重置', () async {
      final container =
          _makeContainer(conversations: [convWithTitle('conv-retry')]);
      final manager = container.read(chatStreamManagerProvider);
      // 第一次请求 cost 0.0001；重试请求 cost 0.0002（不同 cost 便于区分）
      final provider = _UsageQueueProvider([
        [AIStreamEvent('回答1')],
        [AIStreamEvent('回答2')],
      ]);
      provider.usageQueue = [
        {'inputTokens': 100, 'outputTokens': 10, 'cost': 0.0001},
        {'inputTokens': 200, 'outputTokens': 20, 'cost': 0.0002},
      ];
      manager.adapter.forceService(_makeService(provider));

      // 第一次发送
      await manager.startStreaming(
        text: 'hi',
        convId: 'conv-retry',
        history: [ChatMessage(role: 'user', content: 'hi')],
      );

      // 用户点击"重试"：删除 assistant 回复，用相同用户消息重新生成
      // （对齐 chat_page_editing._retryAssistantMessage 的语义）
      await manager.startStreaming(
        text: 'hi',
        convId: 'conv-retry',
        history: [ChatMessage(role: 'user', content: 'hi')],
      );

      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-retry')
          .first;
      // 累计：0.0001 + 0.0002 —— 重发不重置、不丢失、不双计
      expect(conv.totalCost, closeTo(0.0003, 1e-9),
          reason: '重试重新生成应继续累加 cost（0.0001 + 0.0002）');
      expect(conv.lastInputTokens, 200, reason: '最近一次完整请求的计量');
      container.dispose();
    });

    test('编辑用户消息后重发：cost 继续累加', () async {
      final container =
          _makeContainer(conversations: [convWithTitle('conv-edit')]);
      final manager = container.read(chatStreamManagerProvider);
      final provider = _UsageQueueProvider([
        [AIStreamEvent('回答1')],
        [AIStreamEvent('回答2')],
      ]);
      provider.usageQueue = [
        {'inputTokens': 100, 'outputTokens': 10, 'cost': 0.0005},
        {'inputTokens': 300, 'outputTokens': 30, 'cost': 0.0007},
      ];
      manager.adapter.forceService(_makeService(provider));

      // 第一次发送（历史含原用户消息）
      await manager.startStreaming(
        text: '旧问题',
        convId: 'conv-edit',
        history: [ChatMessage(role: 'user', content: '旧问题')],
      );

      // 编辑：删除用户消息及其后所有消息，改为新文本重发
      await manager.startStreaming(
        text: '新问题',
        convId: 'conv-edit',
        history: [ChatMessage(role: 'user', content: '新问题')],
      );

      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-edit')
          .first;
      expect(conv.totalCost, closeTo(0.0012, 1e-9),
          reason: '编辑重发应继续累加 cost（0.0005 + 0.0007）');
      container.dispose();
    });

    test('相同文本重复发送（重发消息）：cost 每次累加，不清零', () async {
      final container =
          _makeContainer(conversations: [convWithTitle('conv-dup')]);
      final manager = container.read(chatStreamManagerProvider);
      final provider = _UsageQueueProvider([
        [AIStreamEvent('回答1')],
        [AIStreamEvent('回答2')],
        [AIStreamEvent('回答3')],
      ]);
      provider.usageQueue = [
        {'inputTokens': 100, 'outputTokens': 10, 'cost': 0.0001},
        {'inputTokens': 100, 'outputTokens': 10, 'cost': 0.0001},
        {'inputTokens': 100, 'outputTokens': 10, 'cost': 0.0001},
      ];
      manager.adapter.forceService(_makeService(provider));

      for (var i = 0; i < 3; i++) {
        await manager.startStreaming(
          text: 'hi',
          convId: 'conv-dup',
          history: [
            for (var j = 0; j <= i; j++) ...[
              ChatMessage(role: 'user', content: 'hi'),
              if (j < i) ChatMessage(role: 'assistant', content: '回答$j'),
            ],
          ],
        );
      }

      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-dup')
          .first;
      // 3 次请求全部计入：每次完整数据回来立即累加，绝不从头算
      expect(conv.totalCost, closeTo(0.0003, 1e-9),
          reason: '连续 3 次发送（含相同文本）应累计 3 份 cost，不得清零或双计');
      container.dispose();
    });

    test('多步工具调用：每轮 cost 独立计费（不是只计最后一轮）', () async {
      final container =
          _makeContainer(conversations: [convWithTitle('conv-multi2')]);
      final manager = container.read(chatStreamManagerProvider);
      // 2 轮工具 + 1 轮文本收尾，每轮 cost 不同：每步都必须是独立计费
      final provider = _UsageQueueProvider([
        [
          AIStreamEvent('', toolCalls: [
            {
              'id': 'm1',
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
              'id': 'm2',
              'type': 'function',
              'function': {
                'name': 'loop_tool',
                'arguments': '{"i": 2}',
              },
            },
          ]),
        ],
        [AIStreamEvent('完成')],
      ]);
      provider.usageQueue = [
        {'inputTokens': 100, 'outputTokens': 10, 'cost': 0.0001},
        {'inputTokens': 200, 'outputTokens': 20, 'cost': 0.0002},
        {'inputTokens': 300, 'outputTokens': 30, 'cost': 0.0003},
      ];
      manager.adapter.forceService(_makeService(provider));
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
        convId: 'conv-multi2',
        history: [ChatMessage(role: 'user', content: 'go')],
        tools: ChatService.getRegisteredToolDefinitions(),
      );

      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-multi2')
          .first;
      // 多步调用的每一步都是独立 API 请求、独立计费：0.0001 + 0.0002
      // + 0.0003 = 0.0006。若只计最后一轮，会得到 0.0003。
      expect(conv.totalCost, closeTo(0.0006, 1e-9),
          reason: '多步工具调用每轮 cost 都必须累计（0.0001+0.0002+0.0003）');
      // lastInputTokens = 最近一轮（第 3 轮）的输入（"最近一次请求"语义）
      expect(conv.lastInputTokens, 300);
      expect(conv.lastOutputTokens, 30);
      container.dispose();
    });

    test('Stop→re-Send 且两流都有 usage：旧流 cost + 新流 cost 各自计一次', () async {
      final container =
          _makeContainer(conversations: [convWithTitle('conv-rs2')]);
      final manager = container.read(chatStreamManagerProvider);

      // 旧流：先产出 usage（模拟停止前已计费），再阻塞等待放行
      final releaseA = Completer<void>();
      final providerA = _BlockAfterUsageProvider([
        [AIStreamEvent('first partial')],
      ], release: releaseA)
        ..usage = {
          'inputTokens': 500,
          'outputTokens': 50,
          'cost': 0.0005,
        };
      manager.adapter.forceService(_makeService(providerA));
      final future1 = manager.startStreaming(
        text: 'first',
        convId: 'conv-rs2',
        history: [ChatMessage(role: 'user', content: 'first')],
      );

      // 等旧流 usage 计量事件已产出（无论提交路径如何，都先取消）
      await _waitFor(() => providerA.usageEmitted);
      manager.cancel('conv-rs2');

      // 新流：cost 0.0003
      final providerB = _RecordingProvider([
        [AIStreamEvent('second response')],
      ])
        ..usage = {
          'inputTokens': 100,
          'outputTokens': 10,
          'cost': 0.0003,
        };
      manager.adapter.forceService(_makeService(providerB));
      final future2 = manager.startStreaming(
        text: 'second',
        convId: 'conv-rs2',
        history: [
          ChatMessage(role: 'user', content: 'first'),
          ChatMessage(role: 'user', content: 'second'),
        ],
      );

      releaseA.complete();
      await future1;
      await future2;

      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-rs2')
          .first;
      // 两次真实请求都被 API 计费：都该进入累计（0.0005 + 0.0003），
      // 旧流 cost 不得因取消而丢失，也不得双计
      expect(conv.totalCost, closeTo(0.0008, 1e-9),
          reason: 'Stop→re-Send 两流 usage 各自计一次，累计 0.0005 + 0.0003');
      container.dispose();
    });

    test('取消的流中已完成轮次：usage 立即提交（tokens 不被整流抑制）', () async {
      final container =
          _makeContainer(conversations: [convWithTitle('conv-cancel')]);
      final manager = container.read(chatStreamManagerProvider);

      // 第一轮已完整产出 usage，随后流被用户取消：
      // 该轮的 input/output/cost 是已发生事实，应立即累计
      final releaseA = Completer<void>();
      final provider = _BlockAfterUsageProvider([
        [AIStreamEvent('partial')],
      ], release: releaseA)
        ..usage = {
          'inputTokens': 150,
          'outputTokens': 30,
          'cost': 0.0004,
        };
      manager.adapter.forceService(_makeService(provider));

      final future1 = manager.startStreaming(
        text: 'hi',
        convId: 'conv-cancel',
        history: [ChatMessage(role: 'user', content: 'hi')],
      );

      await _waitFor(() => provider.usageEmitted);
      manager.cancel('conv-cancel');
      releaseA.complete();
      final result = await future1;

      expect(result.cancelled, isTrue);
      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-cancel')
          .first;
      // usage 事件在取消前已返回：cost 与计量都是事实，立即累计
      expect(conv.totalCost, closeTo(0.0004, 1e-9),
          reason: '取消前已完成的请求 cost 必须保留');
      expect(conv.lastInputTokens, 150, reason: '已完成轮次的计量不被整流取消抑制');
      expect(conv.lastOutputTokens, 30);
      container.dispose();
    });

    test('发送完成后旧 service 被释放：下次发送从零累计（无残留双计）', () async {
      final container =
          _makeContainer(conversations: [convWithTitle('conv-fresh')]);
      final manager = container.read(chatStreamManagerProvider);
      final provider = _UsageQueueProvider([
        [AIStreamEvent('回答1')],
        [AIStreamEvent('回答2')],
      ]);
      provider.usageQueue = [
        {'inputTokens': 100, 'outputTokens': 10, 'cost': 0.0001},
        {'inputTokens': 100, 'outputTokens': 10, 'cost': 0.0001},
      ];
      manager.adapter.forceService(_makeService(provider));

      await manager.startStreaming(
        text: 'hi',
        convId: 'conv-fresh',
        history: [ChatMessage(role: 'user', content: 'hi')],
      );
      await manager.startStreaming(
        text: '再问',
        convId: 'conv-fresh',
        history: [
          ChatMessage(role: 'user', content: 'hi'),
          ChatMessage(role: 'assistant', content: '回答1'),
          ChatMessage(role: 'user', content: '再问'),
        ],
      );

      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-fresh')
          .first;
      // 若 service 残留复用：第二次会累加 0.0001+0.0001=0.0002 → 总 0.0003；
      // 正确行为是每次发送独立累计 → 0.0002
      expect(conv.totalCost, closeTo(0.0002, 1e-9),
          reason: '每次发送独立累计，service 不残留双计');
      container.dispose();
    });
  });
}

/// 产出 usage 计量事件后阻塞，直到 [release] 完成（模拟"已计费但流未结束"）。
class _BlockAfterUsageProvider extends _RecordingProvider {
  final Completer<void> release;
  bool usageEmitted = false;

  _BlockAfterUsageProvider(super.rounds, {required this.release});

  @override
  Stream<AIStreamEvent> chatStream(
    List<Map<String, dynamic>> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    bool reasoning = false,
    String reasoningEffort = 'medium',
    List<Map<String, dynamic>>? tools,
    Map<String, dynamic>? extraParams,
    CancelToken? cancelToken,
    String? system,
  }) async* {
    final index = callCount++;
    if (index < rounds.length) {
      for (final e in rounds[index]) {
        yield e;
      }
    }
    final u = nextUsage();
    if (u != null) {
      usageEmitted = true;
      yield AIStreamEvent('', usage: u);
    }
    await release.future;
  }
}
