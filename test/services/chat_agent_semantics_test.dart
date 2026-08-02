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
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/system_assistant_provider.dart';
import 'package:stroom/services/chat_protocol.dart';
import 'package:stroom/services/chat_service.dart';
import 'package:stroom/services/chat_stream_manager.dart';

// ============================================================================
// Agent 语义测试：max-steps / 中断标记 / 上下文压缩 / 自动标题
// ============================================================================
part 'chat_agent_semantics_test_p1.dart';
part 'chat_agent_semantics_test_p2.dart';
part 'chat_agent_semantics_test_p3.dart';
part 'chat_agent_semantics_test_p4.dart';
part 'chat_agent_semantics_test_p5.dart';
part 'chat_agent_semantics_test_p6.dart';
part 'chat_agent_semantics_test_p7.dart';

/// 按调用顺序提供 usage 的 provider（第 N 次 chatStream 用 usageQueue[N]）。
class _UsageQueueProvider extends _RecordingProvider {
  List<Map<String, dynamic>>? usageQueue;
  int _usageIndex = 0;

  _UsageQueueProvider(super.rounds);

  @override
  Map<String, dynamic>? nextUsage() {
    final queue = usageQueue;
    if (queue == null || _usageIndex >= queue.length) return usage;
    final v = queue[_usageIndex];
    _usageIndex++;
    return v;
  }
}

/// 第一次 chatStream 调用延迟 [delay] 后再产出（模拟慢压缩请求），
/// 后续调用正常。记录调用次数与 captures。
class _DelayedFirstProvider extends _RecordingProvider {
  final Duration delay;

  _DelayedFirstProvider(super.rounds, {required this.delay});

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
    final index = callCount;
    if (index == 0) {
      await Future<void>.delayed(delay);
      if (cancelToken?.isCancelled ?? false) {
        throw DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.cancel,
        );
      }
    }
    yield* super.chatStream(messages,
        model: model,
        maxTokens: maxTokens,
        temperature: temperature,
        reasoning: reasoning,
        reasoningEffort: reasoningEffort,
        tools: tools,
        extraParams: extraParams,
        cancelToken: cancelToken,
        system: system);
  }
}

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
    // 模拟 provider 在流末尾产出 usage 计量事件（事件驱动）
    final u = nextUsage();
    if (u != null) {
      yield AIStreamEvent('', usage: u);
    }
  }

  /// 返回本次调用的 usage 计量（子类可覆盖为按序队列）。
  Map<String, dynamic>? nextUsage() => usage;

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
  chatAgentSemanticsGroup1();
  chatAgentSemanticsGroup2();
  chatAgentSemanticsGroup3();
  chatAgentSemanticsGroup4();
  chatAgentSemanticsGroup5();
  chatAgentSemanticsGroup6();
  chatAgentSemanticsGroup7();
}
