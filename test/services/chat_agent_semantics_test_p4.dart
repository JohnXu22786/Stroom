part of 'chat_agent_semantics_test.dart';

void chatAgentSemanticsGroup4() {
  group('实际 usage 计量与花费', () {
    test('请求完成后更新 lastInputTokens/lastOutputTokens 与 API 返回的 cost', () async {
      final container = _makeContainer(
        conversations: [Conversation(id: 'conv-usage', title: '')],
      );
      final manager = container.read(chatStreamManagerProvider);
      // cost 纯粹来自 API 返回（如 OpenRouter usage.total_cost），不自己统计
      final provider = _RecordingProvider([
        [AIStreamEvent('回答')],
      ])
        ..usage = {
          'inputTokens': 1200,
          'outputTokens': 300,
          'cost': 0.00036,
        };
      manager.adapter.forceService(_makeService(provider));

      await manager.startStreaming(
        text: 'hi',
        convId: 'conv-usage',
        history: [ChatMessage(role: 'user', content: 'hi')],
      );

      // 主请求 + fire-and-forget 自动标题请求（每次请求完整数据回来立即累加）
      await _waitFor(() => provider.captures.length >= 2);
      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-usage')
          .first;
      expect(conv.lastInputTokens, 1200);
      expect(conv.lastOutputTokens, 300);
      // 主请求 0.00036 + 标题请求 0.00036（标题请求只累计 cost，不写 tokens）
      expect(conv.totalCost, closeTo(0.00072, 1e-9));
      container.dispose();
    });

    test('多次请求 cost 累加（含 fire-and-forget 标题请求）', () async {
      final container = _makeContainer(
        conversations: [Conversation(id: 'conv-usage4', title: '')],
      );
      final manager = container.read(chatStreamManagerProvider);
      final provider = _RecordingProvider([
        [AIStreamEvent('回答1')],
        [AIStreamEvent('回答2')],
      ])
        ..usage = {
          'inputTokens': 100,
          'outputTokens': 50,
          'cost': 0.0001,
        };
      manager.adapter.forceService(_makeService(provider));

      await manager.startStreaming(
        text: 'hi',
        convId: 'conv-usage4',
        history: [ChatMessage(role: 'user', content: 'hi')],
      );
      await manager.startStreaming(
        text: '再问',
        convId: 'conv-usage4',
        history: [
          ChatMessage(role: 'user', content: 'hi'),
          ChatMessage(role: 'assistant', content: '回答1'),
          ChatMessage(role: 'user', content: '再问'),
        ],
      );

      // 2 次主请求 + 2 次标题请求都计入累计（每次请求完整数据回来立即累加）
      await _waitFor(() => provider.captures.length >= 4);
      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-usage4')
          .first;
      expect(conv.totalCost, closeTo(0.0004, 1e-9));
      // 标题请求不污染 lastInputTokens（只累计主请求的 100）
      expect(conv.lastInputTokens, 100);
      container.dispose();
    });

    test('API 未返回 cost 时花费为 0，但计量仍更新', () async {
      final container = _makeContainer(
        conversations: [Conversation(id: 'conv-usage2', title: '')],
      );
      final manager = container.read(chatStreamManagerProvider);
      final provider = _RecordingProvider([
        [AIStreamEvent('回答')],
      ])
        ..usage = {'inputTokens': 500, 'outputTokens': 100};
      manager.adapter.forceService(_makeService(provider));

      await manager.startStreaming(
        text: 'hi',
        convId: 'conv-usage2',
        history: [ChatMessage(role: 'user', content: 'hi')],
      );

      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-usage2')
          .first;
      expect(conv.lastInputTokens, 500);
      expect(conv.totalCost, 0);
      container.dispose();
    });

    test('无 usage 返回时计量不更新（保持 null）', () async {
      final container = _makeContainer(
        conversations: [Conversation(id: 'conv-usage3', title: '')],
      );
      final manager = container.read(chatStreamManagerProvider);
      final provider = _RecordingProvider([
        [AIStreamEvent('回答')],
      ]);
      manager.adapter.forceService(_makeService(provider));

      await manager.startStreaming(
        text: 'hi',
        convId: 'conv-usage3',
        history: [ChatMessage(role: 'user', content: 'hi')],
      );

      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-usage3')
          .first;
      expect(conv.lastInputTokens, isNull);
      container.dispose();
    });
  });

  group('压缩触发线规则', () {
    test('默认触发线 = 模型 context，基准用实际 lastInputTokens', () async {
      final container = _makeContainer(
        conversations: [
          Conversation(id: 'conv-trigger', title: '', lastInputTokens: 6000),
        ],
      );
      final manager = container.read(chatStreamManagerProvider);
      // context 5000：实际 6000 ≥ 5000 → 触发压缩（摘要）+ 主请求
      final provider = _RecordingProvider([
        [AIStreamEvent('## Objective\n- 摘要')],
        [AIStreamEvent('回答')],
      ]);
      manager.adapter.forceService(ChatService(
        provider: provider,
        modelConfig: _createModelConfig(context: 5000),
      ));

      await manager.startStreaming(
        text: 'q3',
        convId: 'conv-trigger',
        history: [
          ChatMessage(role: 'assistant', content: 'old ' * 200),
          ChatMessage(role: 'user', content: 'q1'),
          ChatMessage(role: 'user', content: 'q2'),
        ],
      );

      // 压缩请求发生（摘要持久化）
      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-trigger')
          .first;
      expect(conv.contextSummary, contains('Objective'));
      container.dispose();
    });

    test('实际计量未达触发线时不压缩', () async {
      final container = _makeContainer(
        conversations: [
          Conversation(id: 'conv-below', title: '', lastInputTokens: 1000),
        ],
      );
      final manager = container.read(chatStreamManagerProvider);
      final provider = _RecordingProvider([
        [AIStreamEvent('回答')],
      ]);
      manager.adapter.forceService(ChatService(
        provider: provider,
        modelConfig: _createModelConfig(context: 5000),
      ));

      await manager.startStreaming(
        text: 'hi',
        convId: 'conv-below',
        history: [ChatMessage(role: 'user', content: 'hi')],
      );

      await _waitFor(() => provider.captures.length >= 2);
      expect(provider.captures, hasLength(2)); // 主请求 + 标题
      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-below')
          .first;
      expect(conv.contextSummary, isNull);
      container.dispose();
    });

    test('未达自定义触发值时按自定义阈值判断（30000 < 40000 不压缩）', () async {
      final container = _makeContainer(
        conversations: [
          Conversation(id: 'conv-custom', title: '', lastInputTokens: 30000),
        ],
        ctxSettings: const ContextManagementSettings(
          customCompactionThresholdEnabled: true,
          compactionThreshold: 40000,
        ),
      );
      final manager = container.read(chatStreamManagerProvider);
      final provider = _RecordingProvider([
        [AIStreamEvent('## Objective\n- 摘要')],
        [AIStreamEvent('回答')],
      ]);
      manager.adapter.forceService(ChatService(
        provider: provider,
        modelConfig: _createModelConfig(context: 100000),
      ));

      await manager.startStreaming(
        text: 'q3',
        convId: 'conv-custom',
        history: [
          ChatMessage(role: 'assistant', content: 'old ' * 200),
          ChatMessage(role: 'user', content: 'q1'),
          ChatMessage(role: 'user', content: 'q2'),
        ],
      );

      // 实际 30000 < 模型 context 100000，但 ≥ 自定义 40000？不——
      // 30000 < 40000 → 不压缩。用 50000 才触发。
      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-custom')
          .first;
      expect(conv.contextSummary, isNull, reason: '30000 < 自定义 40000，不压缩');
      container.dispose();
    });

    test('自定义触发值 ≥ 实际计量时触发压缩', () async {
      final container = _makeContainer(
        conversations: [
          Conversation(id: 'conv-custom2', title: '', lastInputTokens: 45000),
        ],
        ctxSettings: const ContextManagementSettings(
          customCompactionThresholdEnabled: true,
          compactionThreshold: 40000,
        ),
      );
      final manager = container.read(chatStreamManagerProvider);
      final provider = _RecordingProvider([
        [AIStreamEvent('## Objective\n- 摘要')],
        [AIStreamEvent('回答')],
      ]);
      manager.adapter.forceService(ChatService(
        provider: provider,
        modelConfig: _createModelConfig(context: 100000),
      ));

      await manager.startStreaming(
        text: 'q3',
        convId: 'conv-custom2',
        history: [
          ChatMessage(role: 'assistant', content: 'old ' * 200),
          ChatMessage(role: 'user', content: 'q1'),
          ChatMessage(role: 'user', content: 'q2'),
        ],
      );

      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-custom2')
          .first;
      expect(conv.contextSummary, contains('Objective'),
          reason: '45000 ≥ 自定义 40000 → 压缩（尽管 < 模型 context）');
      container.dispose();
    });
  });
}
