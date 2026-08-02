part of 'chat_agent_semantics_test.dart';

void chatAgentSemanticsGroup2() {
  group('上下文压缩（compaction）', () {
    test('压缩期间取消：主请求不发起，结果标记 cancelled', () async {
      final container = _makeContainer(
        conversations: [Conversation(id: 'conv-cc', title: '')],
      );
      final manager = container.read(chatStreamManagerProvider);
      // 第一次调用（压缩请求）延迟 300ms，给取消留出窗口
      final provider = _DelayedFirstProvider([
        [AIStreamEvent('## Objective\n- 摘要')],
        [AIStreamEvent('回答')],
      ], delay: const Duration(milliseconds: 300));
      manager.adapter.forceService(ChatService(
        provider: provider,
        modelConfig: _createModelConfig(context: 5000),
      ));

      final big = 'x' * 7000;
      final resultFuture = manager.startStreaming(
        text: 'q3',
        convId: 'conv-cc',
        history: [
          ChatMessage(role: 'assistant', content: 'old a1 $big'),
          ChatMessage(role: 'user', content: 'old q1 $big'),
          ChatMessage(role: 'assistant', content: 'old a2 $big'),
          ChatMessage(role: 'user', content: 'q2'),
        ],
      );

      // 压缩请求进行中取消
      await Future<void>.delayed(const Duration(milliseconds: 50));
      manager.cancel('conv-cc');
      final result = await resultFuture;

      expect(result.cancelled, isTrue);
      // 压缩请求被取消（未产出）、主请求未发起：无任何完成的调用
      expect(provider.captures, isEmpty);
      container.dispose();
    });

    test('压缩请求只累计 cost，不写入 lastInputTokens（防膨胀）', () async {
      final container = _makeContainer(
        conversations: [Conversation(id: 'conv-cc2', title: '')],
      );
      final manager = container.read(chatStreamManagerProvider);
      // 压缩请求 usage：input 5000（≈头部大小）+ cost 0.001；
      // 主请求 usage：input 200 + cost 0.0002
      final provider = _UsageQueueProvider([
        [AIStreamEvent('## Objective\n- 摘要')],
        [AIStreamEvent('回答')],
      ]);
      provider.usageQueue = [
        {'inputTokens': 5000, 'outputTokens': 100, 'cost': 0.001},
        {'inputTokens': 200, 'outputTokens': 50, 'cost': 0.0002},
      ];
      manager.adapter.forceService(ChatService(
        provider: provider,
        modelConfig: _createModelConfig(context: 5000),
      ));

      final big = 'x' * 7000;
      await manager.startStreaming(
        text: 'q3',
        convId: 'conv-cc2',
        history: [
          ChatMessage(role: 'assistant', content: 'old a1 $big'),
          ChatMessage(role: 'user', content: 'old q1 $big'),
          ChatMessage(role: 'assistant', content: 'old a2 $big'),
          ChatMessage(role: 'user', content: 'q2'),
        ],
      );

      await _waitFor(() => provider.captures.length >= 3); // + 标题
      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-cc2')
          .first;
      // 压缩的 input（5000）不写入：lastInputTokens 仅主请求的 200
      expect(conv.lastInputTokens, 200);
      // cost 全计入：压缩 0.001 + 主请求 0.0002 = 0.0012
      expect(conv.totalCost, closeTo(0.0012, 1e-9));
      container.dispose();
    });

    test('压缩请求失败时静默容错，主请求照发', () async {
      final container = _makeContainer(
        conversations: [Conversation(id: 'conv-fail', title: '')],
      );
      final manager = container.read(chatStreamManagerProvider);

      // 第 1 次调用（压缩）抛异常；第 2 次（主请求）正常
      final provider = _ThrowingFirstCallProvider([
        [AIStreamEvent('回答')],
      ]);
      manager.adapter.forceService(ChatService(
        provider: provider,
        modelConfig: _createModelConfig(context: 5000),
      ));

      final big = 'x' * 7000;
      final result = await manager.startStreaming(
        text: 'q3',
        convId: 'conv-fail',
        history: [
          ChatMessage(role: 'assistant', content: 'old a1 $big'),
          ChatMessage(role: 'user', content: 'old q1 $big'),
          ChatMessage(role: 'assistant', content: 'old a2 $big'),
          ChatMessage(role: 'user', content: 'q2'),
          ChatMessage(role: 'assistant', content: 'a3'),
          ChatMessage(role: 'user', content: 'q3'),
        ],
      );

      // 压缩失败不阻断：主请求照发，摘要未持久化
      expect(result.fullReply, '回答');
      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-fail')
          .first;
      expect(conv.contextSummary, isNull);
      container.dispose();
    });

    test('超限时压缩头部、持久化摘要、主请求使用尾部', () async {
      final container = _makeContainer(
        conversations: [Conversation(id: 'conv-c', title: '')],
      );
      final manager = container.read(chatStreamManagerProvider);

      // 第 1 次调用 = 压缩请求（摘要）；第 2 次 = 主请求（回答）
      final provider = _RecordingProvider([
        [AIStreamEvent('## Objective\n- 旧对话摘要')],
        [AIStreamEvent('最终回答')],
      ]);
      // context 5000：触发线 = 模型 context（无自定义值）；
      // 历史 3 条大消息 ≈ 5250 tokens > 5000 → 触发
      manager.adapter.forceService(ChatService(
        provider: provider,
        modelConfig: _createModelConfig(context: 5000),
      ));

      final convId = 'conv-c';

      // 6 条消息：tail 从倒数第 2 个 user 消息开始
      final big = 'x' * 7000;
      final history = [
        ChatMessage(role: 'assistant', content: 'old a1 $big'),
        ChatMessage(role: 'user', content: 'old q1 $big'),
        ChatMessage(role: 'assistant', content: 'old a2 $big'),
        ChatMessage(role: 'user', content: 'q2'),
        ChatMessage(role: 'assistant', content: 'a3'),
        ChatMessage(role: 'user', content: 'q3'),
      ];

      final result = await manager.startStreaming(
        text: 'q3',
        convId: convId,
        history: history,
      );

      // 压缩请求已执行（摘要持久化）
      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == convId)
          .first;
      expect(conv.contextSummary, contains('Objective'));
      expect(conv.contextSummary, contains('旧对话摘要'));

      // 压缩请求使用内置压缩助手 prompt（OpenAI 协议：system 消息在前）
      final sysMsgs = (provider.captures[0]['messages'] as List)
          .cast<Map>()
          .where((m) => m['role'] == 'system')
          .toList();
      expect(sysMsgs, isNotEmpty);
      expect(sysMsgs.first['content'], contains('锚定上下文摘要助手'));

      // 主请求发送 = 摘要(system) + 尾部（对齐 opencode filterCompacted）：
      // 存储完整保留头部，发给 API 的只是"摘要 + tail"子集
      final requestMsgs =
          (provider.captures[1]['messages'] as List).cast<Map>().toList();
      // system（助手 prompt 无，仅摘要）+ tail [user q2, assistant a3, user q3]
      final requestRoles = requestMsgs.map((m) => m['role']).toList();
      expect(requestRoles, ['system', 'user', 'assistant', 'user']);
      expect(requestMsgs[1]['content'], 'q2');

      // result.history（持久化）= **完整**历史 + 新 assistant 回答
      // （存储完整保留头部消息，opencode 语义）
      final fullRoles = result.history.map((m) => m.role).toList();
      expect(fullRoles, [
        'assistant', // old a1（头部保留）
        'user', // old q1
        'assistant', // old a2
        'user', // q2
        'assistant', // a3
        'user', // q3
        'assistant', // 最终回答
      ]);
      expect(result.history[6].content, '最终回答');

      final mainSys = requestMsgs.where((m) => m['role'] == 'system').toList();
      expect(mainSys.any((m) => (m['content'] as String).contains('旧对话摘要')),
          isTrue,
          reason: '主请求注入压缩摘要到 system 消息');

      container.dispose();
    });

    test('估算未超限时不压缩', () async {
      final container = _makeContainer(
        conversations: [Conversation(id: 'conv-ok', title: '')],
      );
      final manager = container.read(chatStreamManagerProvider);

      // 大 context（不超限）→ 只发生 1 次请求（主请求）
      final provider = _RecordingProvider([
        [AIStreamEvent('回答')],
      ]);
      manager.adapter.forceService(ChatService(
        provider: provider,
        modelConfig: _createModelConfig(context: 1000000),
      ));

      final result = await manager.startStreaming(
        text: 'hi',
        convId: 'conv-ok',
        history: [
          ChatMessage(role: 'user', content: 'hi'),
          ChatMessage(role: 'assistant', content: 'a'),
        ],
      );

      // 未压缩：仅主请求 + 标题请求（titleAutoGenerated 触发，异步执行）
      await _waitFor(() => provider.captures.length >= 2);
      expect(provider.captures, hasLength(2));
      // 首次请求（无压缩）发**完整**历史（对齐 opencode：无已完成
      // 压缩时 filterCompacted 返回全部消息）
      final requestRoles = (provider.captures[0]['messages'] as List)
          .cast<Map>()
          .map((m) => m['role'])
          .toList();
      expect(requestRoles, ['user', 'assistant']);
      expect(result.fullReply, '回答');
      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-ok')
          .first;
      expect(conv.contextSummary, isNull);
      container.dispose();
    });

    test('压缩后不再重复压缩（触发基于发送量，非存储总量）', () async {
      final container = _makeContainer(
        conversations: [Conversation(id: 'conv-once', title: '')],
      );
      final manager = container.read(chatStreamManagerProvider);
      // 第 1 次调用 = 压缩请求（摘要）；后续 = 主请求
      final provider = _RecordingProvider([
        [AIStreamEvent('## Objective\n- 摘要')],
        [AIStreamEvent('回答1')],
        [AIStreamEvent('回答2')],
      ]);
      manager.adapter.forceService(ChatService(
        provider: provider,
        modelConfig: _createModelConfig(context: 5000),
      ));

      final big = 'x' * 7000;
      final history = [
        ChatMessage(role: 'assistant', content: 'old a1 $big'),
        ChatMessage(role: 'user', content: 'old q1 $big'),
        ChatMessage(role: 'assistant', content: 'old a2 $big'),
        ChatMessage(role: 'user', content: 'q2'),
        ChatMessage(role: 'assistant', content: 'a3'),
        ChatMessage(role: 'user', content: 'q3'),
      ];

      // 第一次发送：触发压缩（存储完整、发送 = 摘要 + tail）
      await manager.startStreaming(
        text: 'q3',
        convId: 'conv-once',
        history: List.from(history),
      );
      // 第二次发送：发送量 = 摘要 + 快照起的 tail（小）→ 不再压缩
      await manager.startStreaming(
        text: '再问',
        convId: 'conv-once',
        history: [
          ...history,
          ChatMessage(role: 'assistant', content: '回答1'),
          ChatMessage(role: 'user', content: '再问'),
        ],
      );

      await _waitFor(() => provider.captures.length >= 4); // 主请求 + 标题
      // 压缩助手 prompt 只应出现 1 次（首次发送）：
      // 第二次发送基于发送量（摘要 + 快照 tail）不再触发压缩
      final compactionCalls = provider.captures
          .where((c) => ((c['messages'] as List).first as Map)['content']
              .toString()
              .contains('锚定上下文摘要助手'))
          .length;
      expect(compactionCalls, 1, reason: '压缩只发生一次——第二次发送不重复压缩');
      // 主请求（含摘要 system）至少 2 次
      final mainSysCalls = provider.captures
          .where((c) => ((c['messages'] as List).first as Map)['content']
              .toString()
              .contains('Objective'))
          .length;
      expect(mainSysCalls, greaterThanOrEqualTo(2));
      container.dispose();
    });
  });
}
