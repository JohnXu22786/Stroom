part of 'chat_agent_semantics_test.dart';

void chatAgentSemanticsGroup5() {
  group('prune 开关', () {
    test('关闭时工具结果不压缩', () async {
      final container = _makeContainer(
        conversations: [Conversation(id: 'conv-noprune', title: '')],
        ctxSettings: const ContextManagementSettings(pruneEnabled: false),
      );
      final manager = container.read(chatStreamManagerProvider);
      final provider = _RecordingProvider([
        [AIStreamEvent('回答')],
      ]);
      manager.adapter.forceService(ChatService(
        provider: provider,
        modelConfig: _createModelConfig(context: 1000000),
      ));

      final bigResult = 'x' * 200000;
      final history = [
        ChatMessage(role: 'assistant', content: 'a', toolCalls: [
          ToolCallData(
            id: 't1',
            name: 'big_tool',
            arguments: const {},
            status: ToolCallStatus.completed,
            result: bigResult,
          ),
        ]),
        ChatMessage(role: 'user', content: 'q1'),
        ChatMessage(role: 'user', content: 'q2'),
      ];
      await manager.startStreaming(
        text: 'q2',
        convId: 'conv-noprune',
        history: history,
      );

      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-noprune')
          .first;
      final toolCall = conv.messages.first.toolCalls!.single;
      await _waitFor(() => provider.captures.length >= 2);
      expect(toolCall.compactedAt, isNull, reason: 'prune 关闭时工具结果保持完整');
      expect(toolCall.result, bigResult);
      container.dispose();
    });

    test('开启（默认）时超阈值工具结果被压缩', () async {
      final container = _makeContainer(
        conversations: [Conversation(id: 'conv-prune-on', title: '')],
      );
      final manager = container.read(chatStreamManagerProvider);
      final provider = _RecordingProvider([
        [AIStreamEvent('回答')],
      ]);
      manager.adapter.forceService(ChatService(
        provider: provider,
        modelConfig: _createModelConfig(context: 1000000),
      ));

      final history = [
        ChatMessage(role: 'assistant', content: 'a', toolCalls: [
          ToolCallData(
            id: 't1',
            name: 'big_tool',
            arguments: const {},
            status: ToolCallStatus.completed,
            result: 'x' * 200000,
          ),
        ]),
        ChatMessage(role: 'user', content: 'q1'),
        ChatMessage(role: 'user', content: 'q2'),
      ];
      await manager.startStreaming(
        text: 'q2',
        convId: 'conv-prune-on',
        history: history,
      );

      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-prune-on')
          .first;
      final toolCall = conv.messages.first.toolCalls!.single;
      await _waitFor(() => provider.captures.length >= 2);
      // 标记 compacted——数据保留（软删除，渲染时占位）
      expect(toolCall.compactedAt, isNotNull);
      expect(toolCall.result, 'x' * 200000);
      container.dispose();
    });
  });

  group('上下文显示格式化', () {
    test('formatTokenCount 千/百万缩写', () {
      expect(formatTokenCount(0), '0');
      expect(formatTokenCount(999), '999');
      expect(formatTokenCount(1200), '1.2K');
      expect(formatTokenCount(12300), '12.3K');
      expect(formatTokenCount(123000), '123K');
      expect(formatTokenCount(1200000), '1.20M');
      expect(formatTokenCount(12000000), '12.0M');
    });

    test('formatCost 小数位', () {
      expect(formatCost(0), '0.00');
      expect(formatCost(0.00036), '0.0004');
      expect(formatCost(0.0123), '0.01');
      expect(formatCost(1.234), '1.23');
    });

    test('formatCost 极小额不显示成 0.0000（累计可见）', () {
      // 1e-5 量级的真实计费：4 位小数会舍成 0.0000，让人误以为没计费；
      // 显示必须让非零累计可见（后台 totalCost 仍保持完整精度）。
      expect(formatCost(0.0000369), '0.0000369');
      expect(formatCost(0.00005), '0.00005');
      expect(formatCost(0.0000001), '0.0000001');
      // < 5e-9 用科学计数法兜底，保证"已累计"可见
      expect(formatCost(0.000000001), '1.0e-9');
    });
  });

  group('normalizeUsage（OpenAI 兼容）', () {
    test('OpenAI 标准字段 prompt_tokens/completion_tokens', () {
      final usage = OpenAICompatibleChatProvider.normalizeUsage({
        'prompt_tokens': 10,
        'completion_tokens': 5,
        'total_tokens': 15,
      });
      expect(usage, {'inputTokens': 10, 'outputTokens': 5});
    });

    test('OpenRouter 风格 input_tokens/output_tokens + total_cost', () {
      final usage = OpenAICompatibleChatProvider.normalizeUsage({
        'input_tokens': 100,
        'output_tokens': 50,
        'total_cost': 0.00012,
      });
      expect(usage!['inputTokens'], 100);
      expect(usage['outputTokens'], 50);
      expect(usage['cost'], closeTo(0.00012, 1e-9));
    });

    test('usage.cost 兼容 + 非 Map 返回 null', () {
      expect(OpenAICompatibleChatProvider.normalizeUsage(null), isNull);
      expect(OpenAICompatibleChatProvider.normalizeUsage('x'), isNull);
      final usage = OpenAICompatibleChatProvider.normalizeUsage(
          {'cost': 0.5, 'prompt_tokens': 1});
      expect(usage!['cost'], 0.5);
    });

    test('空 usage 返回 null', () {
      expect(OpenAICompatibleChatProvider.normalizeUsage({}), isNull);
    });

    test('字符串数值（网关把 total_cost/prompt_tokens 返回为字符串）也记录', () {
      // 部分网关/兼容端点把数值以字符串返回：只认 num 会把这些
      // "API 已返回的计费"静默丢弃，导致累计缺失。
      final usage = OpenAICompatibleChatProvider.normalizeUsage({
        'prompt_tokens': '123',
        'completion_tokens': '45',
        'total_cost': '0.0000123',
      });
      expect(usage!['inputTokens'], 123);
      expect(usage['outputTokens'], 45);
      expect(usage['cost'], closeTo(0.0000123, 1e-12));
    });

    test('非数值字符串 cost 不写入（不把垃圾值当计费）', () {
      final usage = OpenAICompatibleChatProvider.normalizeUsage({
        'prompt_tokens': 10,
        'completion_tokens': 5,
        'total_cost': 'n/a',
      });
      expect(usage, {'inputTokens': 10, 'outputTokens': 5});
    });

    test('非有限字符串（NaN/Infinity）不写入（避免污染 totalCost）', () {
      for (final bad in ['Infinity', '-Infinity', 'NaN']) {
        final usage = OpenAICompatibleChatProvider.normalizeUsage({
          'prompt_tokens': 10,
          'completion_tokens': 5,
          'total_cost': bad,
        });
        expect(usage, {'inputTokens': 10, 'outputTokens': 5},
            reason: '$bad 不是有效计费，必须丢弃');
      }
    });
  });

  group('mergeAnthropicUsage（Anthropic usage 计量合并）', () {
    test('message_start：输入含缓存 token，cost 接受字符串数值', () {
      final local = <String, dynamic>{};
      AnthropicChatProvider.mergeAnthropicUsage(local, {
        'input_tokens': 100,
        'cache_read_input_tokens': 20,
        'cache_creation_input_tokens': '5',
      });
      expect(local['inputTokens'], 125);
    });

    test('message_delta：输出 token + 重复上报 cost 取较大值避免双计', () {
      final local = <String, dynamic>{};
      AnthropicChatProvider.mergeAnthropicUsage(local, {'input_tokens': 100});
      AnthropicChatProvider.mergeAnthropicUsage(local, {
        'output_tokens': 30,
        'total_cost': '0.0000456',
      });
      expect(local['outputTokens'], 30);
      expect(local['cost'], closeTo(0.0000456, 1e-12));
      // 两端点重复上报较小 cost 不覆盖已记录值
      AnthropicChatProvider.mergeAnthropicUsage(local, {
        'output_tokens': 31,
        'total_cost': 0.00001,
      });
      expect(local['cost'], closeTo(0.0000456, 1e-12));
      expect(local['outputTokens'], 31);
    });

    test('空 usage（无任何可用计量）不写入', () {
      final local = <String, dynamic>{};
      AnthropicChatProvider.mergeAnthropicUsage(local, {});
      expect(local, isEmpty);
    });
  });

  group('Conversation usage 序列化', () {
    test('lastInputTokens/lastOutputTokens/totalCost 往返', () {
      final conv = Conversation(
        id: 'c-usage',
        title: 't',
        lastInputTokens: 1234,
        lastOutputTokens: 56,
        totalCost: 0.00456,
      );
      final restored = Conversation.fromMap(conv.toMap());
      expect(restored.lastInputTokens, 1234);
      expect(restored.lastOutputTokens, 56);
      expect(restored.totalCost, closeTo(0.00456, 1e-9));
    });

    test('旧数据缺省（totalCost 0、tokens null）', () {
      final restored = Conversation.fromMap({
        'id': 'c1',
        'title': 't',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': <dynamic>[],
      });
      expect(restored.lastInputTokens, isNull);
      expect(restored.totalCost, 0);
    });
  });

  group('上下文管理设置持久化', () {
    test('SharedPreferences 往返 + 默认值', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      // 默认：prune 开、自定义阈值关
      final settings = container.read(contextManagementSettingsProvider);
      // 等异步 _load 完成（避免其覆盖后续修改——产品代码已有
      // _userModified 保护，但测试先等加载完成更稳）
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(settings.pruneEnabled, isTrue);
      expect(settings.customCompactionThresholdEnabled, isFalse);
      expect(settings.compactionThreshold, isNull);

      // 修改并持久化（await 确保写入完成后再读回）
      final notifier =
          container.read(contextManagementSettingsProvider.notifier);
      await notifier.setPruneEnabled(false);
      await notifier.setCustomCompactionThresholdEnabled(true);
      await notifier.setCompactionThreshold(48000);

      // prefs 直接验证写入
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('context_prune_enabled'), isFalse);

      // 新容器读回：先 read 触发工厂（_load 异步开始），
      // 等加载完成后第二次 read 才拿到持久化值
      final container2 = ProviderContainer();
      container2.read(contextManagementSettingsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final reloaded = container2.read(contextManagementSettingsProvider);
      expect(reloaded.pruneEnabled, isFalse);
      expect(reloaded.customCompactionThresholdEnabled, isTrue);
      expect(reloaded.compactionThreshold, 48000);
      container.dispose();
      container2.dispose();
    });

    test('effectiveCompactionThreshold：自定义优先，否则模型 context', () {
      const settings = ContextManagementSettings(
        customCompactionThresholdEnabled: true,
        compactionThreshold: 48000,
      );
      expect(settings.effectiveCompactionThreshold(100000), 48000);

      const defaultSettings = ContextManagementSettings();
      expect(defaultSettings.effectiveCompactionThreshold(100000), 100000);
      expect(defaultSettings.effectiveCompactionThreshold(null), isNull);
    });
  });
}
