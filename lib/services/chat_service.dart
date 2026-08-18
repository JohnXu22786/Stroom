import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

import '../models/assistant.dart' show AssistantSettings, CustomParameter;
import '../models/ai_stream_event.dart';
import '../models/chat_event.dart';
import '../models/chat_message.dart';
import '../models/mcp.dart' show McpServerConfig;
import '../models/tool_call.dart';
import '../providers/chat_api_provider.dart';
import '../providers/provider_config.dart';
import 'chat_protocol.dart';
import 'context_manager.dart'
    show
        kInterruptedToolResultPlaceholder,
        kToolOutputMaxChars,
        kToolOutputTruncatedSuffix,
        truncateUtf8;
import 'chat_service_shared.dart' show setNestedParam;
import 'mcp_client.dart';
import 'app_log_service.dart';

part 'chat_service_tools.dart';
part 'chat_service_streaming.dart';
part 'chat_service_send.dart';
part 'chat_service_params.dart';

// ====================================================================
// ChatService — AI 聊天服务抽象层
// ====================================================================
//
// Two usage modes:
//
// 1. Instance mode (preferred, for real API calls):
//    final service = ChatService(provider: ..., modelConfig: ...);
//    service.sendStream(text, history: history);
//
// 2. Static mode (mock, for development/testing):
//    ChatService.sendStream(text);
// ====================================================================

/// 每次请求的 usage 计量事件回调（per-request、事件驱动）。
///
/// 由上层（ChatStreamManager）注入：每次请求的完整 usage 数据返回时
/// 立即调用，把该请求的计量/花费累加到对应对话——对话级累计按
/// "每次完整请求数据返回立即累加"进行，绝不从头重算。
///
/// [recordInput] 为 false 时只应累计 cost，不应写入 input/output tokens
/// （内部任务请求如压缩/标题：其输入不代表"当前上下文大小"）。
typedef UsageEventCallback = void Function(Map<String, dynamic> usage,
    {required bool recordInput});

class ChatService {
  // ── Instance fields (used when constructed with a provider) ─────
  final BaseChatProvider? _provider;
  final ModelConfig? _modelConfig;

  /// 工具结果存储上限（对齐 opencode tool-output-store MAX_BYTES = 50KB）。
  /// 50KB 内**完整保留**（UI 可展开查看、历史重建可发送），
  /// 发送给模型时另有渲染截断（上限由助手设置决定，
  /// 默认 [kToolOutputMaxChars] 字符）。
  static const int maxToolResultBytes = 50 * 1024;

  /// 工具循环上限常量：
  /// 单条用户消息内模型 API 请求（步骤）的最大次数，范围 1-100，默认 20。
  /// 每次 API 响应内的多个并行工具调用属于同一"步骤"，只计 1 次；
  /// 计数按用户消息重置，不跨对话累计。
  static const int kMaxToolRoundsDefault = 20;
  static const int kMaxToolRoundsMin = 1;
  static const int kMaxToolRoundsMax = 100;

  /// 工具结果渲染截断上限（字符数）的可接受范围：
  /// 低于 [kToolOutputMaxCharsMin] 或高于 [kToolOutputMaxCharsMax]
  /// 的配置值（含持久化损坏数据）回退默认 [kToolOutputMaxChars]。
  /// 上限取 100K 字符：超过存储上限（50KB 字节）的截断值没有意义，
  /// 但也不至于在 UI 输入 100 万时把请求体直接撑爆。
  static const int kToolOutputMaxCharsMin = 100;
  static const int kToolOutputMaxCharsMax = 100000;

  /// 计算生效的工具结果渲染截断上限（**字符数**，非 token/字节）：
  ///
  /// - 无助手（settings 为 null）：使用默认上限 [kToolOutputMaxChars]
  ///   （保持"始终有兜底截断"的旧行为）；
  /// - 开关关闭（[AssistantSettings.enableMaxToolOutputChars] = false）：
  ///   返回 0 = **不截断**，完整发送存储的工具结果（存储仍有 50KB 上限）；
  /// - 开关开启：使用配置值，仅接受 [kToolOutputMaxCharsMin,
  ///   kToolOutputMaxCharsMax] 范围内的值，越界/损坏回退默认值。
  static int getEffectiveToolOutputMaxChars(AssistantSettings? settings) {
    if (settings == null) return kToolOutputMaxChars;
    if (!settings.enableMaxToolOutputChars) return 0;
    final v = settings.maxToolOutputChars;
    if (v < kToolOutputMaxCharsMin || v > kToolOutputMaxCharsMax) {
      return kToolOutputMaxChars;
    }
    return v;
  }

  /// 工具循环绝对安全上限（仅兜底防失控，用户不可见）：
  /// 开关关闭（不限次数）时，循环在模型不再调用工具、出错或用户取消
  /// 时自然结束；若模型失控连续返回工具调用，该上限保证最多消耗
  /// [kMaxToolRoundsHardLimit] 次 API 请求，避免无限计费。
  /// 真实任务远达不到此值（1 轮 = 1 次 API 请求）。
  static const int kMaxToolRoundsHardLimit = 1000;

  /// 计算生效的工具循环上限：
  ///
  /// - 未配置（settings 为 null，如无助手会话）：保持默认上限 20，
  ///   不做静默放宽——只有用户在设置页显式关闭开关才进入不限模式；
  /// - 开关关闭：返回 null = 不限制（与设置页开关关闭时的
  ///   "无限制"文案一致），循环仅由模型停止调用工具、出错或用户取消
  ///   而终止（另有 [kMaxToolRoundsHardLimit] 兜底防失控）；
  /// - 开关开启：使用用户配置值，但仅接受 [kMaxToolRoundsMin,
  ///   kMaxToolRoundsMax] 范围内的值，越界/损坏（含持久化旧数据）回退默认值。
  static int? getEffectiveMaxToolRounds(AssistantSettings? settings) {
    if (settings == null) {
      return kMaxToolRoundsDefault;
    }
    if (!settings.enableMaxToolCalls) {
      return null;
    }
    final v = settings.maxToolCalls;
    if (v < kMaxToolRoundsMin || v > kMaxToolRoundsMax) {
      return kMaxToolRoundsDefault;
    }
    return v;
  }

  /// 中断工具结果的占位文本（用户取消时对未完成工具补发）。
  /// 与协议层历史重建的占位符统一。
  static const String kToolInterruptedPlaceholder =
      kInterruptedToolResultPlaceholder;

  /// Provider-level params to merge with model params.
  /// Provider params serve as defaults; model params override on collision.
  final ProviderConfigItem? _providerConfig;

  /// 协议层：负责中立历史 → API 格式消息的构建与工具链重建。
  /// 由端点类型决定（openai / anthropic），ChatService 本身格式无关。
  final ChatProtocol _protocol;
  bool _isCancelledByUser = false;
  CancelToken? _cancelToken;

  /// 内部任务（标题/压缩）进行中的 CancelToken 列表。
  /// 独立于 [_cancelToken]（主请求）；多个内部任务可能并发
  /// （fire-and-forget 标题与下一次发送的压缩），用列表避免单槽覆盖，
  /// [cancel] 时一并中止全部。
  final List<CancelToken> _internalTaskTokens = [];
  StreamSubscription<AIStreamEvent>? _streamSubscription;
  StreamController<String>? _controller;

  /// The stream controller for [sendStreamWithTools], stored so that
  /// [cancel()] can close it. This ensures the caller's `await for` loop
  /// (in ChatPage) receives a done event and can clean up the streaming
  /// placeholder message — otherwise the spinner animation never disappears.
  StreamController<ChatEvent>? _chatEventController;

  /// 当前工具轮次的等待 completer（sendStreamWithTools 内部）。
  ///
  /// [cancel()] 会同步取消订阅与 cancelToken；真实 provider（Dio 驱动的
  /// async* 流）在订阅取消后 onDone/onError **不会**送达，`await
  /// completer.future` 将永久挂起。cancel 时必须完成它，循环才能走到
  /// `if (_isCancelledByUser) break` 正常退出（否则每次"停止"都泄漏
  /// 一个持 MB 级闭包的挂起微任务）。
  Completer<void>? _roundCompleter;
  String _reasoningBuffer = '';

  /// Accumulated visible content from the current streaming round,
  /// preserved for tool call chain reconstruction per DeepSeek spec.
  String _contentBuffer = '';

  /// Tracks how much of [_reasoningBuffer] was accumulated in previous rounds,
  /// so we can extract only the current round's reasoning for the assistant message.
  int _lastReasoningLength = 0;

  /// Anthropic extended thinking 签名（当前轮）。
  /// 由 provider 在流结束时产出，用于下一轮链重建时续接 thinking 块。
  String _thinkingSignature = '';
  Map<String, dynamic>? _lastRequestBody;

  /// 每次请求的 usage 计量事件回调（per-request 隔离、事件驱动）。
  ///
  /// 由上层（ChatStreamManager）按对话绑定：provider 在每次请求的
  /// 流末尾/错误轮产出 usage 事件时立即回调，上层据此把该请求的
  /// cost/tokens **立即**累加到对话——对话级累计按"每次完整请求
  /// 数据返回"增量进行，而非整次发送攒到流结束一次性提交（后者在
  /// service 被复用/异常清理时会把旧请求的 usage 重复提交双计）。
  /// provider 实例被多对话共享，直接读 provider.lastUsage 会被并发
  /// 对话覆盖——事件驱动即为此设计。
  UsageEventCallback? onUsageEvent;

  Map<String, dynamic>? _lastResponseData;
  Map<String, String>? _lastRequestHeaders;
  Map<String, List<String>>? _lastResponseHeaders;
  String? _lastRequestUrl;
  int? _lastResponseStatusCode;

  /// Construct an instance backed by a real provider and model config.
  /// Optionally accepts [providerConfig] for provider-level params to merge.
  ///
  /// [endpointType] 为有效端点类型（模型覆盖 > 供应商 > 'openai'），
  /// 由 ChatAdapter 解析后传入；也可直接注入 [protocol] 覆盖。
  ChatService({
    required BaseChatProvider provider,
    required ModelConfig modelConfig,
    ProviderConfigItem? providerConfig,
    String endpointType = 'openai',
    ChatProtocol? protocol,
  })  : _provider = provider,
        _modelConfig = modelConfig,
        _providerConfig = providerConfig,
        _protocol = protocol ?? createChatProtocol(endpointType);

  /// The protocol used by this service instance (for test use only).
  @visibleForTesting
  ChatProtocol get protocol => _protocol;

  /// Whether there's an active streaming session (instance or static).
  bool get isStreamActive => _controller != null && !_controller!.isClosed;

  /// The model config used by this service instance.
  ModelConfig? get modelConfig => _modelConfig;

  /// 该服务所用供应商配置的显示名（供上下文管理按模型定位使用）。
  /// 供应商配置缺失时返回 null。
  String? get modelProviderName => _providerConfig?.providerName;

  /// The provider used by this service instance (for test use only).
  @visibleForTesting
  BaseChatProvider? get provider => _provider;

  /// The provider config used by this service instance (for test use only).
  @visibleForTesting
  ProviderConfigItem? get providerConfig => _providerConfig;

  Map<String, dynamic>? get lastRequestBody =>
      _lastRequestBody ?? _provider?.lastRequestBody;
  Map<String, dynamic>? get lastResponseData =>
      _lastResponseData ?? _provider?.lastResponseData;
  Map<String, String>? get lastRequestHeaders =>
      _lastRequestHeaders ?? _provider?.lastRequestHeaders;
  String? get lastRequestUrl => _lastRequestUrl ?? _provider?.lastRequestUrl;
  int? get lastResponseStatusCode =>
      _lastResponseStatusCode ?? _provider?.lastResponseStatusCode;
  Map<String, List<String>>? get lastResponseHeaders =>
      _lastResponseHeaders ?? _provider?.lastResponseHeaders;

  /// 发送一次性系统提示词请求（标题生成 / 上下文压缩等内部任务用）。
  ///
  /// 不走对话助手的 system prompt / 工具参数 / 推理参数：
  /// 使用 [systemPrompt] 作为 system 内容，[history] 作为消息历史。
  /// [contextSummary] 可选注入压缩摘要。
  ///
  /// 内部任务请求需要轻量（maxTokens 通常较小、无工具），
  /// 与主对话请求相互独立。使用**局部** CancelToken（不触碰
  /// [_cancelToken] 字段，避免与并发的主请求流互相干扰），
  /// 同时注册到 [_internalTaskToken] 供 [cancel] 中止。
  ///
  /// [accumulateUsage]：为 true 时把本次请求的 usage 转发到
  /// [onUsageEvent]（由 manager 立即累加到对话）；为 false 时不转发。
  ///
  /// [recordInputTokens]：压缩请求的输入 ≈ 压缩前头部大小，写入
  /// lastInputTokens 会污染"当前上下文大小"（下次触发判断膨胀、
  /// 状态行显示虚高）——压缩请求只累计 cost（recordInputTokens: false），
  /// 输入/输出计量由主请求提供。
  Future<String> sendPrompt({
    required String systemPrompt,
    required List<ChatMessage> history,
    int? maxTokens,
    String? contextSummary,
    bool accumulateUsage = true,
    bool recordInputTokens = true,
  }) async {
    final req = await _protocol.buildRequest(
      history: history,
      assistantPrompt: systemPrompt,
      contextSummary: contextSummary,
      toolOutputMaxChars: getEffectiveToolOutputMaxChars(_assistantSettings),
    );
    final token = CancelToken();
    _internalTaskTokens.add(token);
    final chunks = <String>[];
    try {
      await for (final event in _provider!.chatStream(
        req.messages,
        model: _modelConfig!.modelId,
        maxTokens: maxTokens,
        system: req.system,
        cancelToken: token,
      )) {
        if (event.isReasoning || event.isToolCallEvent) continue;
        // usage 计量事件（provider 流末尾产出，per-request 隔离）
        if (event.usage != null && accumulateUsage) {
          onUsageEvent?.call(event.usage!, recordInput: recordInputTokens);
        }
        if (event.text.isNotEmpty) chunks.add(event.text);
      }
    } catch (e) {
      debugPrint('ChatService sendPrompt stream error: $e');
      rethrow;
    } finally {
      _internalTaskTokens.remove(token);
    }
    return chunks.join('').trim();
  }

  // ── Tool execution ────────────────────────────────────────────────

  static final Map<String, Map<String, dynamic>> _toolRegistries = {};

  /// Returns the list of all registered built-in tool definitions.
  static List<ToolDefinition> getRegisteredToolDefinitions() {
    return _toolRegistries.values
        .map((entry) => entry['definition'] as ToolDefinition)
        .toList(growable: false);
  }

  /// MCP 客户端管理器（可选，用于执行 MCP 工具）
  static McpClientManager? _mcpClientManager;

  /// 设置 MCP 客户端管理器
  static void setMcpClientManager(McpClientManager manager) {
    _mcpClientManager = manager;
  }

  /// 获取当前 MCP 客户端管理器
  static McpClientManager? get mcpClientManager => _mcpClientManager;

  /// Register a tool handler for a given tool definition.
  /// The handler receives parsed arguments and returns a result string.
  /// The handler can be sync (`String`) or async (`Future<String>`).
  static void registerTool(
    ToolDefinition def,
    dynamic Function(Map<String, dynamic>) handler,
  ) {
    _toolRegistries[def.name] = {'definition': def, 'handler': handler};
  }

  // ── Extra params helpers ─────────────────────────────────────────

  /// Optional assistant-level custom parameters to merge into the API call.
  List<CustomParameter>? _assistantCustomParams;

  /// Set assistant-level custom parameters that will be merged into the API
  /// request body alongside model-level custom params.
  void setAssistantCustomParams(List<CustomParameter>? params) {
    _assistantCustomParams = params;
  }

  /// Optional assistant system prompt to prepend to API messages.
  String? _assistantPrompt;

  /// The assistant system prompt currently applied (used by tests).
  String? get assistantPrompt => _assistantPrompt;

  /// Set the assistant's system prompt that will be prepended as a
  /// system-role message in the API request.
  void setAssistantPrompt(String? prompt) {
    _assistantPrompt = prompt;
  }

  /// 上下文压缩产生的锚定摘要（对话被压缩过时为非空）。
  String? _contextSummary;

  /// 设置对话的上下文压缩摘要，以 system 级内容注入请求。
  void setContextSummary(String? summary) {
    _contextSummary = summary;
  }

  /// Optional assistant-level settings to override model params.
  /// When an assistant setting's enableXxx flag is true, its value overrides
  /// the corresponding model parameter. When false, the model parameter is used.
  AssistantSettings? _assistantSettings;

  /// Set assistant-level settings that will override model parameters when
  /// their corresponding enable flags are set to true.
  void setAssistantSettings(AssistantSettings? settings) {
    _assistantSettings = settings;
  }

  /// Filter out the `_OmittedSentinel` values (params that failed to coerce).
  /// Sentinel-mapped entries must be removed so they don't get re-serialized
  /// into the JSON request body.
  ///
  /// Recursive: dotted param names (`provider.only`) may bury a sentinel at
  /// any depth. A nested map whose entries were ALL omitted is dropped too;
  /// a legitimately empty map (a JSON param whose value is `{}`) is kept.
  static Map<String, dynamic> _stripOmitted(Map<String, dynamic> params) {
    final result = <String, dynamic>{};
    for (final entry in params.entries) {
      if (entry.value is _OmittedSentinel) continue;
      if (entry.value is Map<String, dynamic>) {
        final sub = entry.value as Map<String, dynamic>;
        final stripped = _stripOmitted(sub);
        // 嵌套值全部被剔除（原 map 非空 → 由哨兵剔净）：整体丢弃，
        // 避免向 API 发送残缺的空对象。
        if (stripped.isEmpty && sub.isNotEmpty) continue;
        result[entry.key] = stripped;
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  // ----------------------------------------------------------------
  // Test-only entry points. The real coercion path is exercised by
  // sendStream() in integration tests; these wrappers let unit tests
  // verify the coercion / stripping policy without standing up a full
  // ChatService with a real provider.
  // ----------------------------------------------------------------

  /// @visibleForTesting
  static dynamic coerceCustomParamForTest({
    required String paramName,
    required String type,
    required String defaultValue,
  }) =>
      _coerceCustomParam(paramName, type, defaultValue);

  /// @visibleForTesting
  static Map<String, dynamic> stripOmittedForTest(
          Map<String, dynamic> params) =>
      _stripOmitted(params);

  /// @visibleForTesting — type marker for the omitted sentinel (for `isA`).
  static Type get omittedSentinelTypeForTest => _OmittedSentinel;

  /// @visibleForTesting — singleton instance for inserting into test maps.
  static Object get omittedSentinelInstanceForTest => _kOmittedSentinelInstance;

  /// Parse a JSON string into a dynamic value.
  ///
  /// Throws [FormatException] when parsing fails. The previous behavior of
  /// returning the raw string on failure meant a malformed JSON defaultValue
  /// would be re-serialized as a quoted string in the API request body
  /// (e.g. `{"response_format": "{\\"type\\": \\"json_object\\"}"}` instead of
  /// the intended `{"response_format": {"type": "json_object"}}`). That
  /// silently sent the wrong shape to the upstream API. Throwing lets callers
  /// skip the offending parameter and surface a clear error.
  ///
  /// Empty strings are treated as a no-op (returns null) so optional JSON
  /// parameters that have been left blank don't break the request.
  @visibleForTesting
  static dynamic parseJsonValue(String value) {
    if (value.trim().isEmpty) return null;
    try {
      return jsonDecode(value);
    } catch (e) {
      throw FormatException(
        'Failed to parse JSON value: $value. '
        'Check the custom param defaultValue for valid JSON syntax '
        '(keys and strings must use double quotes).',
        value,
      );
    }
  }

  /// Parse a JSON custom parameter value that may already be a parsed object
  /// or a JSON string. If it's a String, tries to parse it as JSON.
  /// If it's already a Map/List, returns it as-is.
  @visibleForTesting
  static dynamic parseJsonParam(dynamic value) {
    if (value is String) {
      return parseJsonValue(value);
    }
    // Already a parsed Map/List/bool/num — return as-is
    return value;
  }

  /// Parse a reasoning parameter value according to its [type].
  /// Supports: 'string', 'number', 'boolean', 'json'.
  /// Throws [FormatException] for invalid JSON values. Callers that loop
  /// over many params (e.g. _buildExtraParams) should use the safer
  /// [_setReasoningParam] wrapper instead, which catches the exception,
  /// logs it, and drops the param from the request body.
  static dynamic parseReasoningValue(String value, String type) {
    return switch (type) {
      'number' => double.tryParse(value) ?? 0.0,
      'boolean' => value.toLowerCase() == 'true',
      'json' => parseJsonValue(value),
      'string' || _ => value,
    };
  }

  /// Apply a reasoning [rp]'s selected value to the [result] map under its
  /// paramName, swallowing any [FormatException] from invalid JSON so that
  /// one bad param can't abort the whole request build.
  @visibleForTesting
  static void setReasoningParamForTest(
    Map<String, dynamic> result,
    ReasoningParam rp,
    String value, {
    String source = 'model',
  }) {
    _setReasoningParam(result, rp, value, source: source);
  }

  static void _setReasoningParam(
    Map<String, dynamic> result,
    ReasoningParam rp,
    String value, {
    String source = 'model',
  }) {
    try {
      setNestedParam(
        result,
        rp.paramName,
        parseReasoningValue(value, rp.type),
      );
    } on FormatException catch (e) {
      debugPrint(
        '[ChatService] Skipping $source reasoning param "${rp.paramName}" '
        'because its value is not valid JSON: ${e.message}',
      );
    }
  }

  /// Coerce a model-level / provider-level [CustomParam] defaultValue into
  /// the runtime type expected by the API. JSON failures throw, are logged,
  /// and the parameter is omitted (NOT sent as a raw string).
  static dynamic _coerceCustomParam(
    String paramName,
    String type,
    String defaultValue, {
    String source = 'model',
  }) {
    switch (type) {
      case 'number':
        return double.tryParse(defaultValue) ?? 0.0;
      case 'boolean':
        return defaultValue.toLowerCase() == 'true';
      case 'json':
        try {
          return parseJsonValue(defaultValue);
        } on FormatException catch (e) {
          debugPrint(
            '[ChatService] Skipping $source custom param "$paramName" '
            'because its defaultValue is not valid JSON: ${e.message}',
          );
          return const _OmittedSentinel();
        }
      case 'string':
      default:
        return defaultValue;
    }
  }

  /// Coerce an assistant-level [CustomParameter] into the runtime type.
  /// Assistant-level params already store parsed values for type 'json',
  /// so this only falls back to string→JSON parsing when given a String.
  static dynamic _coerceAssistantCustomParam(CustomParameter cp) {
    switch (cp.type) {
      case 'number':
        return (cp.value is num)
            ? (cp.value as num).toDouble()
            : (double.tryParse(cp.value.toString()) ?? 0.0);
      case 'boolean':
        return cp.value is bool
            ? cp.value
            : (cp.value.toString().toLowerCase() == 'true');
      case 'json':
        if (cp.value is String) {
          try {
            return parseJsonValue(cp.value as String);
          } on FormatException catch (e) {
            debugPrint(
              '[ChatService] Skipping assistant custom param "${cp.name}" '
              'because its value is not valid JSON: ${e.message}',
            );
            return const _OmittedSentinel();
          }
        }
        return cp.value; // already parsed
      case 'string':
      default:
        return cp.value?.toString() ?? '';
    }
  }
}
