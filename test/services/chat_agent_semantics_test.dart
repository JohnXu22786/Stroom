import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/chat_event.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/pages/chat/chat_types.dart'
    show formatCost, formatTokenCount;
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/chat_manager_provider.dart';
import 'package:stroom/providers/context_management_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/system_assistant_provider.dart';
import 'package:stroom/services/chat_adapter.dart';
import 'package:stroom/services/chat_protocol.dart';
import 'package:stroom/services/chat_service.dart';
import 'package:stroom/services/chat_stream_manager.dart';
import 'package:stroom/services/context_manager.dart'
    show kCompactedToolResultPlaceholder;

// ============================================================================
// Agent 语义测试：max-steps / 中断标记 / 上下文压缩 / 自动标题
// ============================================================================

/// 第一次 chatStream 调用抛异常（模拟压缩请求失败），后续正常。
class _ThrowingFirstCallProvider extends BaseChatProvider {
  final List<List<AIStreamEvent>> rounds;
  int callCount = 0;

  _ThrowingFirstCallProvider(this.rounds);

  @override
  String get name => 'ThrowingProvider';

  @override
  List<String> get supportedModelIds => ['test-model'];

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
    if (index == 0) {
      throw Exception('Simulated compaction failure');
    }
    final round = rounds[index - 1];
    for (final e in round) {
      yield e;
    }
  }

  @override
  Future<String> chat(
    List<Map<String, dynamic>> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    bool reasoning = false,
    String reasoningEffort = 'medium',
    CancelToken? cancelToken,
    Map<String, dynamic>? extraParams,
    String? system,
  }) async {
    return 'Mock response';
  }

  @override
  Map<String, dynamic> get defaultParams => {
        'model': 'test-model',
        'max_tokens': 4096,
        'temperature': 0.7,
      };
}

/// 记录每次 chatStream 调用的 (tools, extraParams, system, 最后一条消息)。
class _RecordingProvider extends BaseChatProvider {
  final List<List<AIStreamEvent>> rounds;
  int callCount = 0;

  /// 每次调用的捕获快照。
  final List<Map<String, dynamic>> captures = [];

  /// 模拟 API 返回的 usage（标准化 {inputTokens, outputTokens}）。
  Map<String, dynamic>? usage;

  _RecordingProvider(this.rounds);

  @override
  String get name => 'RecordingProvider';

  @override
  List<String> get supportedModelIds => ['test-model'];

  @override
  Map<String, dynamic>? get lastUsage => usage;

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
    captures.add({
      'messages': List<Map<String, dynamic>>.from(messages),
      'tools': tools == null ? null : List<Map<String, dynamic>>.from(tools),
      'extraParams': Map<String, dynamic>.from(extraParams ?? {}),
      'system': system,
    });
    if (index < rounds.length) {
      for (final e in rounds[index]) {
        yield e;
      }
    } else {
      yield AIStreamEvent('默认回答');
    }
  }

  @override
  Future<String> chat(
    List<Map<String, dynamic>> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    bool reasoning = false,
    String reasoningEffort = 'medium',
    CancelToken? cancelToken,
    Map<String, dynamic>? extraParams,
    String? system,
  }) async {
    return 'Mock response';
  }

  @override
  Map<String, dynamic> get defaultParams => {
        'model': 'test-model',
        'max_tokens': 4096,
        'temperature': 0.7,
      };
}

ModelConfig _createModelConfig({int context = 4096}) {
  return ModelConfig(
    name: 'Test Model',
    modelId: 'test-model',
    typeConfig: {'context': context, 'maxTokens': 2048},
  );
}

ChatService _makeService(BaseChatProvider provider,
    {String endpointType = 'openai'}) {
  return ChatService(
    provider: provider,
    modelConfig: _createModelConfig(),
    endpointType: endpointType,
  );
}

/// 创建带预置对话的 ProviderContainer。
/// override conversationsProvider 绕过异步 _load（避免与 createConversation
/// 竞争）；同时 override 系统助手/上下文管理 provider 避免异步 _load 与
/// dispose 的竞态。
ProviderContainer _makeContainer({
  List<Conversation>? conversations,
  ContextManagementSettings? ctxSettings,
}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderContainer(
    overrides: [
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        notifier.state = conversations ?? [];
        return notifier;
      }),
      assistantProvider.overrideWith((ref) {
        final notifier = AssistantsNotifier();
        notifier.state = [];
        return notifier;
      }),
      systemAssistantSettingsProvider.overrideWith((ref) {
        final notifier = SystemAssistantSettingsNotifier();
        notifier.state = const SystemAssistantSettings();
        return notifier;
      }),
      if (ctxSettings != null)
        contextManagementSettingsProvider.overrideWith((ref) {
          final notifier = ContextManagementSettingsNotifier();
          notifier.state = ctxSettings;
          return notifier;
        }),
    ],
  );
}

/// 轮询等待 [condition] 为真（标题生成等 fire-and-forget 任务）。
Future<void> _waitFor(bool Function() condition, {int timeoutMs = 2000}) async {
  final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) break;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
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

      // 收尾轮：tools 禁用 + MAX_STEPS_PROMPT 前置（不注入 tool_choice，
      // 避免 tools 缺失时严格端点拒绝该字段）
      expect(provider.captures[2]['tools'], isNull);
      expect(
        (provider.captures[2]['extraParams'] as Map).containsKey('tool_choice'),
        isFalse,
      );
      final lastMsg = (provider.captures[2]['messages'] as List).last as Map;
      expect(lastMsg['role'], 'assistant');
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
      // 第 2 轮：收尾（禁用工具）
      expect(provider.captures[1]['tools'], isNull);
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
  });

  group('上下文压缩（compaction）', () {
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

      // 主请求 history = tail（头部被摘要替换），且注入摘要
      // tail = [user q2, assistant a3, user q3] + 新 assistant 回答
      final tailRoles = result.history.map((m) => m.role).toList();
      expect(tailRoles, ['user', 'assistant', 'user', 'assistant']);
      expect(result.history[0].content, 'q2');
      expect(result.history[3].content, '最终回答');
      final mainSys = (provider.captures[1]['messages'] as List)
          .cast<Map>()
          .where((m) => m['role'] == 'system')
          .toList();
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
      expect(result.fullReply, '回答');
      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-ok')
          .first;
      expect(conv.contextSummary, isNull);
      container.dispose();
    });
  });

  group('自动标题', () {
    test('流完成后用标题助手生成 AI 标题', () async {
      final container = _makeContainer(
        conversations: [Conversation(id: 'conv-title', title: '')],
      );
      final manager = container.read(chatStreamManagerProvider);

      // 调用顺序：主请求 → 标题生成（单条用户消息无旧历史可压缩，
      // head 为空 → 压缩不触发）
      final provider = _RecordingProvider([
        [AIStreamEvent('回答')],
        [AIStreamEvent('「AI 生成的标题」')],
      ]);
      manager.adapter.forceService(_makeService(provider));

      await manager.startStreaming(
        text: '帮我优化代码',
        convId: 'conv-title',
        history: [ChatMessage(role: 'user', content: '帮我优化代码')],
      );

      // 标题生成是 fire-and-forget（不阻塞结果返回），等待其完成
      await _waitFor(() => provider.captures.length >= 2);
      expect(provider.captures, hasLength(2));
      // 标题请求使用内置标题助手 prompt（OpenAI：system 消息）
      final titleSys = (provider.captures[1]['messages'] as List)
          .cast<Map>()
          .where((m) => m['role'] == 'system')
          .toList();
      expect(titleSys, isNotEmpty);
      expect(titleSys.first['content'], contains('标题生成器'));
      // 标题已更新（去引号）
      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-title')
          .first;
      expect(conv.title, 'AI 生成的标题');
      expect(conv.titleAutoGenerated, isFalse,
          reason: 'renameConversation 清除自动标记');
      container.dispose();
    });

    test('用户手动改过标题时不覆盖', () async {
      final container = _makeContainer(
        conversations: [
          Conversation(id: 'conv-manual', title: '我的手动标题'),
        ],
      );
      final manager = container.read(chatStreamManagerProvider);
      final provider = _RecordingProvider([
        [AIStreamEvent('回答')],
      ]);
      manager.adapter.forceService(ChatService(
        provider: provider,
        modelConfig: _createModelConfig(context: 1000000),
      ));

      await manager.startStreaming(
        text: 'hi',
        convId: 'conv-manual',
        history: [ChatMessage(role: 'user', content: 'hi')],
      );

      // 标题请求未发生（仅主请求）
      expect(provider.captures, hasLength(1));
      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-manual')
          .first;
      expect(conv.title, '我的手动标题');
      container.dispose();
    });
  });

  group('工具结果截断', () {
    test('超过 2000 字符的工具结果保留前缀并标记截断', () async {
      final provider = _RecordingProvider([
        [
          AIStreamEvent('', toolCalls: [
            {
              'id': 'call_big',
              'type': 'function',
              'function': {
                'name': 'big_tool',
                'arguments': '{}',
              },
            },
          ]),
        ],
        [AIStreamEvent('done')],
      ]);
      final service = _makeService(provider);
      ChatService.registerTool(
        const ToolDefinition(
          name: 'big_tool',
          description: 'big',
          parameters: {'type': 'object'},
        ),
        (args) => 'x' * 5000,
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

      final complete = events.whereType<ToolCallCompleteEvent>().single;
      expect(complete.result.length, lessThan(5000));
      expect(complete.result, startsWith('x' * 2000));
      expect(complete.result, contains('[已截断]'));

      // 链中 tool 消息也使用截断结果
      final toolMsg = (provider.captures[1]['messages'] as List)
          .cast<Map>()
          .where((m) => m['role'] == 'tool')
          .single;
      expect(toolMsg['content'], complete.result);
    });
  });

  group('sendPrompt（内部任务请求）', () {
    test('跳过推理与工具事件，只收集文本', () async {
      final provider = _RecordingProvider([
        [
          AIStreamEvent('思考中', isReasoning: true),
          AIStreamEvent('', toolCalls: [
            {'id': 'x', 'name': 't', 'input': {}},
          ]),
          AIStreamEvent('最终标题'),
        ],
      ]);
      final service = _makeService(provider);
      final result = await service.sendPrompt(
        systemPrompt: '你是标题生成器',
        history: [ChatMessage(role: 'user', content: '帮我优化')],
        maxTokens: 200,
      );
      expect(result, '最终标题');
      // 请求体：system 消息在前，无工具
      final msgs = (provider.captures[0]['messages'] as List).cast<Map>();
      expect(msgs.first['role'], 'system');
      expect(msgs.first['content'], '你是标题生成器');
      expect(provider.captures[0]['tools'], isNull);
    });
  });

  group('OpenAI 协议 system 合并', () {
    test('assistantPrompt 与 contextSummary 合并为单条 system 消息', () async {
      final provider = _RecordingProvider([
        [AIStreamEvent('ok')],
      ]);
      final service = _makeService(provider);
      service.setAssistantPrompt('你是助手');
      service.setContextSummary('旧对话摘要内容');
      await service
          .sendStream(
            'hi',
            history: [ChatMessage(role: 'user', content: 'hi')],
          )
          .listen((_) {})
          .asFuture();

      final msgs = (provider.captures[0]['messages'] as List).cast<Map>();
      final sysMsgs = msgs.where((m) => m['role'] == 'system').toList();
      expect(sysMsgs, hasLength(1), reason: '严格端点拒绝多条 system 消息');
      final content = sysMsgs.single['content'] as String;
      expect(content, contains('你是助手'));
      expect(content, contains('旧对话摘要内容'));
    });
  });

  group('titleAutoGenerated 序列化', () {
    test('toMap/fromMap 往返', () {
      final conv = Conversation(
        title: '自动标题',
        titleAutoGenerated: true,
      );
      final restored = Conversation.fromMap(conv.toMap());
      expect(restored.titleAutoGenerated, isTrue);
    });

    test('旧数据缺省 false（不覆盖手动标题语义）', () {
      final restored = Conversation.fromMap({
        'id': 'c1',
        'title': 't',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': <dynamic>[],
      });
      expect(restored.titleAutoGenerated, isFalse);
    });
  });

  group('协议层换端点（ChatService 级）', () {
    test('anthropic 端点：请求走 Anthropic 协议（system 顶层 + 链格式）', () async {
      final provider = _RecordingProvider([
        [
          AIStreamEvent('', toolCalls: [
            {
              'id': 'toolu_1',
              'name': 'loop_tool',
              'input': {'i': 1}
            },
          ]),
        ],
        [AIStreamEvent('done')],
      ]);
      final service = _makeService(provider, endpointType: 'anthropic');
      expect(service.protocol, isA<AnthropicProtocol>());
      ChatService.registerTool(
        const ToolDefinition(
          name: 'loop_tool',
          description: 'loop',
          parameters: {'type': 'object'},
        ),
        (args) => 'ok',
      );

      await service
          .sendStreamWithTools(
            'go',
            history: [
              ChatMessage(role: 'user', content: 'go'),
              ChatMessage(role: 'assistant', content: '前一轮'),
            ],
            tools: ChatService.getRegisteredToolDefinitions(),
          )
          .listen((_) {})
          .asFuture();

      // 第 1 轮请求：system 走顶层字段（非 system 消息），
      // messages 只含 user/assistant
      final messages1 = (provider.captures[0]['messages'] as List).cast<Map>();
      expect(
          messages1.map((m) => m['role']), containsAll(['user', 'assistant']));
      expect(
        messages1.any((m) => m['role'] == 'system'),
        isFalse,
        reason: 'Anthropic 协议 system 不入 messages',
      );
      // 工具定义是 anthropic 形状（name/input_schema，无 function 包装）
      final tools = (provider.captures[0]['tools'] as List).cast<Map>();
      expect(tools.first.containsKey('function'), isFalse);
      expect(tools.first['name'], 'loop_tool');
      expect(tools.first['input_schema'], isNotNull);

      // 第 2 轮请求：链重建为 assistant(tool_use) + user(tool_result)
      final messages2 = (provider.captures[1]['messages'] as List).cast<Map>();
      final assistantMsg =
          messages2.where((m) => m['role'] == 'assistant').last;
      final contentBlocks = (assistantMsg['content'] as List).cast<Map>();
      expect(contentBlocks.any((b) => b['type'] == 'tool_use'), isTrue);
      final toolUse = contentBlocks.firstWhere((b) => b['type'] == 'tool_use');
      expect(toolUse['id'], 'toolu_1');
      expect(toolUse['name'], 'loop_tool');
      // tool_result 配对
      final userMsg = messages2.last;
      final userBlocks = (userMsg['content'] as List).cast<Map>();
      expect(userBlocks.single['type'], 'tool_result');
      expect(userBlocks.single['tool_use_id'], 'toolu_1');
      expect(userBlocks.single['content'], 'ok');
    });
  });
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

      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-usage')
          .first;
      expect(conv.lastInputTokens, 1200);
      expect(conv.lastOutputTokens, 300);
      expect(conv.totalCost, closeTo(0.00036, 1e-9));
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

      // 2 次主请求 + 1 次标题请求（fire-and-forget），全部计入
      await _waitFor(() => provider.captures.length >= 3);
      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-usage4')
          .first;
      expect(conv.totalCost, closeTo(0.0003, 1e-9));
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

    test('自定义更小触发值生效（小于模型 context 时提前压缩）', () async {
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
      expect(toolCall.compactedAt, isNotNull);
      expect(toolCall.result, kCompactedToolResultPlaceholder);
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

      // 3 次请求（2 工具轮 + 1 收尾/文本轮）usage 全部累计
      await _waitFor(() => provider.captures.length >= 4); // + 标题
      final conv = container
          .read(conversationsProvider)
          .where((c) => c.id == 'conv-multi')
          .first;
      expect(conv.lastInputTokens, 300); // 3 × 100
      expect(conv.totalCost, closeTo(0.0003, 1e-9)); // 3 × 0.0001
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
