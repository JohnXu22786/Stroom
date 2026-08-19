part of 'chat_agent_semantics_test.dart';

void chatAgentSemanticsGroup7() {
  group('取消/重发（Stop→re-Send）与错误轮计费', () {
    test('取消后立即重发同一对话：结果来自新流，旧流 finalize 不覆盖新流数据', () async {
      final container = _makeContainer(
        conversations: [Conversation(id: 'conv-rs', title: '')],
      );
      final manager = container.read(chatStreamManagerProvider);

      // 第一个流：阻塞直到放行（模拟流进行中）
      final blockA = Completer<void>();
      final providerA = _RecordingProvider([
        [AIStreamEvent('first partial')],
      ]);
      manager.adapter.forceService(_makeService(providerA));

      final future1 = manager.startStreaming(
        text: 'first',
        convId: 'conv-rs',
        history: [ChatMessage(role: 'user', content: 'first')],
      );
      expect(manager.isStreamingFor('conv-rs'), true);

      // 用户点停止（cancel 只标记取消，条目在 finalize 时才移除）
      manager.cancel('conv-rs');
      expect(manager.isStreamingFor('conv-rs'), true);

      // 立即重发同一对话（Stop→re-Send 核心路径）
      final providerB = _RecordingProvider([
        [AIStreamEvent('second response')],
      ]);
      manager.adapter.forceService(_makeService(providerB));
      final future2 = manager.startStreaming(
        text: 'second',
        convId: 'conv-rs',
        history: [
          ChatMessage(role: 'user', content: 'first'),
          ChatMessage(role: 'user', content: 'second'),
        ],
      );

      // 放行旧流，让它的 finalize 与新流并存
      blockA.complete();
      final result1 = await future1;
      final result2 = await future2;

      // 旧流结果标记为取消；新流返回新回复
      expect(result1.cancelled, true);
      expect(result2.fullReply, 'second response');
      expect(result2.cancelled, false);

      // 最终持久化的对话：含两条用户消息 + 新流回复
      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-rs')
          .first;
      final userTexts =
          conv.messages.where((m) => m.role == 'user').map((m) => m.content);
      expect(userTexts, containsAll(['first', 'second']));
      final lastMsg = conv.messages.last;
      expect(lastMsg.role, 'assistant');
      expect(lastMsg.content, 'second response');

      container.dispose();
    });

    test('流错误轮：usage 先于错误到达时 cost 仍累计、token 仍写入', () async {
      final container = _makeContainer(
        conversations: [Conversation(id: 'conv-err', title: '')],
      );
      final manager = container.read(chatStreamManagerProvider);

      // provider 先产出 usage 计量事件，再抛错（错误轮计费场景）
      final provider = _ErrorAfterUsageProvider([
        [AIStreamEvent('partial text')],
      ])
        ..usage = {
          'inputTokens': 800,
          'outputTokens': 200,
          'cost': 0.00123,
        };
      manager.adapter.forceService(_makeService(provider));

      final result = await manager.startStreaming(
        text: 'hi',
        convId: 'conv-err',
        history: [ChatMessage(role: 'user', content: 'hi')],
      );

      // 错误被标记（错误轮），但计费已发生
      expect(result.fullReply.startsWith('错误:'), isTrue);
      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-err')
          .first;
      expect(conv.totalCost, closeTo(0.00123, 1e-9));
      expect(conv.lastInputTokens, 800);
      expect(conv.lastOutputTokens, 200);

      container.dispose();
    });
  });
}

/// 先产出事件与 usage 计量，再抛错的 provider（错误轮计费场景）。
class _ErrorAfterUsageProvider extends _RecordingProvider {
  _ErrorAfterUsageProvider(super.rounds);

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
    // 先产出 usage 计量事件（错误轮也计费）
    final u = nextUsage();
    if (u != null) {
      yield AIStreamEvent('', usage: u);
    }
    // 再抛错
    throw Exception('Simulated stream failure after usage');
  }
}
