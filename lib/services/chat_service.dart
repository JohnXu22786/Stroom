import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

import '../models/assistant.dart' show AssistantSettings, CustomParameter;
import '../models/ai_stream_event.dart';
import '../models/chat_event.dart';
import '../models/chat_message.dart';
import '../models/tool_call.dart';
import '../providers/chat_api_provider.dart';
import '../providers/provider_config.dart';
import 'chat_protocol.dart';
import 'chat_service_shared.dart' show setNestedParam;
import 'mcp_client.dart';
import 'app_log_service.dart';

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

/// Sentinel value used to mark a custom param that should be omitted from
/// the request body (e.g. because its JSON value failed to parse). Distinct
/// from null, which is a legitimate value to send for some params.
class _OmittedSentinel {
  const _OmittedSentinel();
}

/// Single shared instance of the sentinel (used by tests for type matching).
const _OmittedSentinel _kOmittedSentinelInstance = _OmittedSentinel();

class ChatService {
  // ── Instance fields (used when constructed with a provider) ─────
  final BaseChatProvider? _provider;
  final ModelConfig? _modelConfig;

  /// 工具结果最大保留字符数（对齐 opencode TOOL_OUTPUT_MAX_CHARS）。
  /// 超长结果在入库/进链前截断，防止 SharedPreferences 膨胀与上下文占用。
  static const int maxToolResultChars = 2000;

  /// 中断工具结果的占位文本（用户取消时对未完成工具补发）。
  static const String kToolInterruptedPlaceholder = '[工具执行被中断]';

  /// 达到工具调用上限时，追加到请求的提示消息（opencode MAX_STEPS_PROMPT
  /// 改编）：要求模型禁用工具、仅文本总结。
  static const String maxStepsPrompt = '''
已达到本任务的工具调用上限。工具已禁用，请仅用文本回应。

要求：
1. 不要再调用任何工具
2. 总结到目前为止已完成的工作
3. 列出尚未完成的任务
4. 给出下一步建议''';

  /// Provider-level params to merge with model params.
  /// Provider params serve as defaults; model params override on collision.
  final ProviderConfigItem? _providerConfig;

  /// 协议层：负责中立历史 → API 格式消息的构建与工具链重建。
  /// 由端点类型决定（openai / anthropic），ChatService 本身格式无关。
  final ChatProtocol _protocol;
  bool _isCancelledByUser = false;
  CancelToken? _cancelToken;
  StreamSubscription<AIStreamEvent>? _streamSubscription;
  StreamController<String>? _controller;

  /// The stream controller for [sendStreamWithTools], stored so that
  /// [cancel()] can close it. This ensures the caller's `await for` loop
  /// (in ChatPage) receives a done event and can clean up the streaming
  /// placeholder message — otherwise the spinner animation never disappears.
  StreamController<ChatEvent>? _chatEventController;
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

  /// 最近一次请求的实际 token 计量（来自 API usage，标准化为
  /// {inputTokens, outputTokens}）。用于上下文显示与花费计算。
  Map<String, dynamic>? get lastUsage => _provider?.lastUsage;

  /// Returns the effective temperature considering assistant overrides.
  /// Returns null when no temperature toggle is enabled (model or assistant).
  double? get _effectiveTemperature {
    // Assistant override takes priority when enabled
    if (_assistantSettings != null && _assistantSettings!.enableTemperature) {
      return _assistantSettings!.temperature;
    }
    // Model-level toggle check
    final typeConfig = _modelConfig?.typeConfig;
    final enableTemperature =
        typeConfig?['enableTemperature'] as bool? ?? false;
    if (enableTemperature && typeConfig?.containsKey('temperature') == true) {
      return (typeConfig!['temperature'] as num).toDouble();
    }
    // Neither toggle is on — return null so it's NOT sent in the request
    return null;
  }

  /// Returns the effective maxTokens considering assistant overrides.
  /// Returns null when no max_tokens toggle is enabled (model or assistant).
  int? get _effectiveMaxTokens {
    // Assistant override takes priority when enabled
    if (_assistantSettings != null && _assistantSettings!.enableMaxTokens) {
      return _assistantSettings!.maxTokens;
    }
    // Model-level toggle check
    final typeConfig = _modelConfig?.typeConfig;
    final enableMaxTokens = typeConfig?['enableMaxTokens'] as bool? ?? false;
    if (enableMaxTokens) {
      final value = (typeConfig!['maxTokens'] as num?)?.toInt() ??
          (typeConfig['context'] as num?)?.toInt();
      if (value != null) return value;
    }
    // Neither toggle is on — return null so it's NOT sent in the request
    return null;
  }

  // ── Instance methods ────────────────────────────────────────────

  /// Stream a message — converts [history] (which already contains the latest
  /// user message with attachments) into API‑format messages and streams the
  /// reply.
  ///
  /// [history] must already include the latest user message (added by the
  /// caller before calling this method). Attachments are converted to the
  /// OpenAI multimodal content‑array format (base64 inline images).
  ///
  /// [reasoningParamValues] is a map of paramName -> selectedOptionValue
  /// used when [reasoning] is true. If a param has no selection, it is skipped.
  Stream<String> sendStream(
    String userMessage, {
    required List<ChatMessage> history,
    bool reasoning = false,
    String reasoningEffort = 'medium',
    Map<String, String> reasoningParamValues = const {},
  }) {
    AppLogService.info(
        'ChatService', 'sendStream 开始: ${userMessage.length} 字符');
    cancel();
    _isCancelledByUser = false;
    _reasoningBuffer = '';

    _controller = StreamController<String>(
      onCancel: () {
        debugPrint('ChatService: stream cancelled');
        _cancelToken?.cancel();
        _cancelToken = null;
        _streamSubscription?.cancel();
        _streamSubscription = null;
        _cleanUp();
      },
    );

    final extraParams = _buildExtraParams(
      reasoning: reasoning,
      reasoningEffort: reasoningEffort,
      reasoningParamValues: reasoningParamValues,
    );

    Future.microtask(() async {
      try {
        if (_isCancelledByUser) return;
        final req = await _protocol.buildRequest(
          history: history,
          assistantPrompt: _assistantPrompt,
          contextSummary: _contextSummary,
        );
        final apiMessages = req.messages;
        _lastRequestBody = {
          'model': _modelConfig?.modelId,
          'messages': apiMessages,
          if (_effectiveMaxTokens != null) 'max_tokens': _effectiveMaxTokens,
          if (_effectiveTemperature != null)
            'temperature': _effectiveTemperature,
          ...extraParams,
        };
        _cancelToken = CancelToken();
        _streamSubscription = _provider!
            .chatStream(
          apiMessages,
          model: _modelConfig!.modelId,
          reasoning: reasoning,
          reasoningEffort: reasoningEffort,
          maxTokens: _effectiveMaxTokens, // null when toggle is OFF
          temperature: _effectiveTemperature, // null when toggle is OFF
          system: req.system,
          extraParams: extraParams,
          cancelToken: _cancelToken,
        )
            .listen(
          (event) {
            if (event.isReasoning) {
              _reasoningBuffer += event.text;
            } else if (!_controller!.isClosed) {
              _controller!.add(event.text);
            }
          },
          onDone: () {
            _streamSubscription = null;
            if (_controller != null && !_controller!.isClosed) {
              _controller!.close();
            }
            _lastResponseData = _provider?.lastResponseData;
            _cleanUp();
          },
          onError: (Object error) {
            _streamSubscription = null;
            debugPrint('ChatService stream error: $error');
            _lastResponseData = _provider?.lastResponseData;
            if (_controller != null && !_controller!.isClosed) {
              _controller!.addError(error);
              _controller!.close();
            }
            _cleanUp();
          },
        );
      } catch (e) {
        _lastResponseData = _provider?.lastResponseData;
        if (!_controller!.isClosed) {
          _controller!.addError(e);
          _controller!.close();
        }
      }
    });

    return _controller!.stream;
  }

  /// Stream a message WITH tool call support.
  /// Returns both text chunks and tool call events.
  /// Handles the function-calling loop internally.
  ///
  /// [reasoningParamValues] is a map of paramName -> selectedOptionValue
  /// used when [reasoning] is true. If a param has no selection, it is skipped.
  Stream<ChatEvent> sendStreamWithTools(
    String userMessage, {
    required List<ChatMessage> history,
    bool reasoning = false,
    String reasoningEffort = 'medium',
    Map<String, String> reasoningParamValues = const {},
    List<ToolDefinition> tools = const [],
  }) {
    AppLogService.info(
        'ChatService', 'sendStreamWithTools 开始: ${userMessage.length} 字符');
    _isCancelledByUser = false;
    _reasoningBuffer = '';
    _contentBuffer = '';
    _lastReasoningLength = 0;
    _thinkingSignature = '';

    final controller = StreamController<ChatEvent>(
      onCancel: () {
        _cancelToken?.cancel();
        _cancelToken = null;
        _streamSubscription?.cancel();
        _streamSubscription = null;
        _chatEventController = null;
      },
    );
    _chatEventController = controller;

    final extraParams = _buildExtraParams(
      reasoning: reasoning,
      reasoningEffort: reasoningEffort,
      reasoningParamValues: reasoningParamValues,
    );
    final toolDefs = _protocol.toolDefsToJson(tools);

    Future.microtask(() async {
      try {
        if (_isCancelledByUser) return;
        final req = await _protocol.buildRequest(
          history: history,
          assistantPrompt: _assistantPrompt,
          contextSummary: _contextSummary,
        );
        var messages = req.messages;
        _lastRequestBody = {
          'model': _modelConfig?.modelId,
          'messages': messages,
          if (_effectiveMaxTokens != null) 'max_tokens': _effectiveMaxTokens,
          if (_effectiveTemperature != null)
            'temperature': _effectiveTemperature,
          if (toolDefs.isNotEmpty) 'tools': toolDefs,
          ...extraParams,
        };
        int loopProtection = 0;
        final maxRounds = _assistantSettings?.enableMaxToolCalls == true
            ? _assistantSettings!.maxToolCalls
            : null;
        // 对齐 opencode steps 语义：maxRounds 轮内工具可用；
        // 若模型在最后一轮仍请求工具（超限），追加一轮"收尾轮"
        // （tools 禁用 + 文本收尾提示词），让模型总结而不是硬跑。
        final totalRounds = maxRounds == null ? null : maxRounds + 1;

        while (!_isCancelledByUser &&
            (totalRounds == null || loopProtection < totalRounds)) {
          loopProtection++;
          if (maxRounds != null && loopProtection % 50 == 0) {
            AppLogService.info('ChatService', '工具调用循环: 第 $loopProtection 轮');
          }

          _streamSubscription?.cancel();
          _cancelToken?.cancel();
          _cancelToken = CancelToken();

          final completer = Completer<void>();
          final toolCallRefs = <Map<String, dynamic>>[];

          // ── Max-steps 语义（opencode MAX_STEPS_PROMPT）──
          // 收尾轮：不传工具定义（模型无法调用工具）+ 前置文本收尾提示，
          // 要求模型总结已做/未做/下一步。不注入 tool_choice：
          // tools 缺失时部分严格端点会拒绝 tool_choice 字段。
          final isLastStep = maxRounds != null && loopProtection > maxRounds;
          var roundMessages = messages;
          if (isLastStep) {
            roundMessages = [
              ...messages,
              {'role': 'assistant', 'content': maxStepsPrompt},
            ];
          }

          _streamSubscription = _provider!
              .chatStream(
            roundMessages,
            model: _modelConfig!.modelId,
            reasoning: reasoning,
            reasoningEffort: reasoningEffort,
            maxTokens: _effectiveMaxTokens, // null when toggle is OFF
            temperature: _effectiveTemperature, // null when toggle is OFF
            tools: isLastStep || toolDefs.isEmpty ? null : toolDefs,
            system: req.system,
            extraParams: extraParams,
            cancelToken: _cancelToken,
          )
              .listen(
            (event) {
              if (_isCancelledByUser) return;
              // Anthropic extended thinking 签名（协议续接用，静默透传）
              if (event.thinkingSignature != null &&
                  event.thinkingSignature!.isNotEmpty) {
                _thinkingSignature = event.thinkingSignature!;
              }
              if (event.isReasoning) {
                _reasoningBuffer += event.text;
                // Emit reasoning text as ReasoningEvent so the UI
                // can stream it in real-time to the reasoning panel.
                controller.add(ReasoningEvent(event.text));
              } else if (event.isToolCallEvent) {
                toolCallRefs.addAll(event.toolCalls!);
              } else if (event.text.isNotEmpty) {
                // Accumulate visible content for tool call chain
                // preservation per DeepSeek spec.
                _contentBuffer += event.text;
                controller.add(TextEvent(event.text));
              }
            },
            onDone: () {
              _streamSubscription = null;
              if (!completer.isCompleted) completer.complete();
            },
            onError: (Object error) {
              _streamSubscription = null;
              debugPrint('ChatService stream error: $error');
              _lastResponseData = _provider?.lastResponseData;
              if (!controller.isClosed) {
                controller.addError(error);
              }
              if (!completer.isCompleted) completer.complete();
            },
          );

          await completer.future;
          if (_isCancelledByUser) break;

          // No tool calls → done
          if (toolCallRefs.isEmpty) break;

          // Emit ReasoningSectionEndEvent before starting the next round.
          // This allows the UI to split multi-step reasoning chains into
          // separate panels.
          controller.add(const ReasoningSectionEndEvent());

          // Capture the current round's reasoning content (what was added
          // since the last round). Per the DeepSeek Tool Calls guide,
          // messages.append(message) preserves the complete assistant message
          // (including reasoning_content) when sending subsequent requests
          // in the same tool call chain.
          final roundReasoning = _reasoningBuffer.substring(
            _lastReasoningLength,
          );

          // Collect all tool calls and results first, then build the chain
          // messages via the protocol (format-specific). The neutral
          // representation keeps the loop independent of the API format.
          final neutralCalls = <NeutralToolCall>[];
          final results = <ToolCallResult>[];

          for (final tc in toolCallRefs) {
            if (_isCancelledByUser) break;
            final neutral = normalizeToolCall(tc);
            final name = neutral.name;
            final rawArgs = neutral.argumentsJson;

            Map<String, dynamic> parsedArgs = {};
            try {
              parsedArgs = Map<String, dynamic>.from(jsonDecode(rawArgs));
            } catch (e) {
              AppLogService.warning(
                  'ChatService', '解析工具调用参数失败: $name, 参数: $rawArgs: $e');
            }

            final toolCallData = ToolCallData(
              id: neutral.id,
              name: name,
              arguments: parsedArgs,
              status: ToolCallStatus.running,
            );

            controller.add(ToolCallStartEvent(toolCallData));

            // Execute tool
            String result;
            try {
              result = await _executeTool(name, parsedArgs);
            } catch (e) {
              result = 'Error: $e';
            }
            // 工具结果截断：超长结果保留前缀（入库/进链/持久化前）
            if (result.length > maxToolResultChars) {
              result = '${result.substring(0, maxToolResultChars)}\n... [已截断]';
            }
            // 执行期间被取消：跳过 complete 事件（controller 已关闭，
            // 且避免把"恰在取消时完成"的工具误标为正常结果）
            if (_isCancelledByUser) break;

            controller.add(ToolCallCompleteEvent(neutral.id, result));

            neutralCalls.add(neutral);
            results.add(ToolCallResult(toolCallId: neutral.id, result: result));
          }

          // 注意：用户取消时（cancel() 已关闭 controller）无法再补发事件；
          // 中断工具标记由 ChatStreamManager 在 post-stream 阶段完成
          // （把 running/pending 工具标为 kToolInterruptedPlaceholder）。

          if (!_isCancelledByUser) {
            // Build the assistant chain message + tool results via the
            // protocol: OpenAI 为单条 assistant(tool_calls) + N 条 tool 消息；
            // Anthropic 为 assistant(thinking/text/tool_use 块) + 单条
            // user(tool_result 块)。历史保持中立，格式切换安全。
            messages.addAll(_protocol.buildAssistantChainMessage(
              content: _contentBuffer,
              toolCalls: neutralCalls,
              roundReasoning: roundReasoning,
              thinkingSignature: _thinkingSignature,
            ));
            messages.addAll(_protocol.buildToolResultMessages(results));

            // Reset per-round buffers for the next iteration
            _contentBuffer = '';
            _lastReasoningLength = _reasoningBuffer.length;
            _thinkingSignature = '';
          }
        }
      } catch (e) {
        _lastResponseData = _provider?.lastResponseData;
        if (!controller.isClosed) {
          controller.addError(e);
        }
      } finally {
        if (!controller.isClosed) {
          await controller.close();
        }
        _cleanUp();
      }
    });

    return controller.stream;
  }

  String get reasoningContent => _reasoningBuffer;

  /// Non-streaming version - collects stream into a single string.
  Future<String> send(
    String userMessage, {
    required List<ChatMessage> history,
    bool reasoning = false,
    String reasoningEffort = 'medium',
  }) async {
    final chunks = <String>[];
    await for (final chunk in sendStream(
      userMessage,
      history: history,
      reasoning: reasoning,
      reasoningEffort: reasoningEffort,
    )) {
      chunks.add(chunk);
    }
    return chunks.join('');
  }

  /// 发送一次性系统提示词请求（标题生成 / 上下文压缩等内部任务用）。
  ///
  /// 不走对话助手的 system prompt / 工具参数 / 推理参数：
  /// 使用 [systemPrompt] 作为 system 内容，[history] 作为消息历史。
  /// [contextSummary] 可选注入压缩摘要。
  ///
  /// 内部任务请求需要轻量（maxTokens 通常较小、无工具），
  /// 与主对话请求相互独立。
  Future<String> sendPrompt({
    required String systemPrompt,
    required List<ChatMessage> history,
    int? maxTokens,
    String? contextSummary,
  }) async {
    final req = await _protocol.buildRequest(
      history: history,
      assistantPrompt: systemPrompt,
      contextSummary: contextSummary,
    );
    _cancelToken = CancelToken();
    final chunks = <String>[];
    try {
      await for (final event in _provider!.chatStream(
        req.messages,
        model: _modelConfig!.modelId,
        maxTokens: maxTokens,
        system: req.system,
        cancelToken: _cancelToken,
      )) {
        if (event.isReasoning || event.isToolCallEvent) continue;
        if (event.text.isNotEmpty) chunks.add(event.text);
      }
    } finally {
      _cancelToken = null;
    }
    return chunks.join('').trim();
  }

  /// Cancel the current stream
  void cancel() {
    _isCancelledByUser = true;
    _cancelToken?.cancel();
    _cancelToken = null;
    _streamSubscription?.cancel();
    _streamSubscription = null;
    if (_controller != null && !_controller!.isClosed) {
      _controller!.close();
    }
    if (_chatEventController != null && !_chatEventController!.isClosed) {
      _chatEventController!.close();
    }
    _chatEventController = null;
    _cleanUp();
  }

  void _cleanUp() {
    if (_controller?.isClosed ?? true) {
      _controller = null;
    }
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

  Future<String> _executeTool(String name, Map<String, dynamic> args) async {
    // First check locally registered tools
    final entry = _toolRegistries[name];
    if (entry != null) {
      final handler =
          entry['handler'] as dynamic Function(Map<String, dynamic>);
      final result = handler(args);
      // Handle both sync and async handlers
      if (result is Future<String>) {
        return await result;
      }
      return result as String;
    }

    // Then check MCP clients
    if (_mcpClientManager != null) {
      for (final entry in _mcpClientManager!.clients.entries) {
        final client = entry.value;
        if (client.isConnected == false &&
            client.isDisposed == false &&
            !client.hasConnectedBefore) {
          await client.connect();
        }
        if (client.isConnected) {
          // Check if this MCP server has the tool
          final cachedTools = client.cachedTools;
          final hasTool = cachedTools.any((t) => t.name == name);
          if (hasTool) {
            return client.callTool(name, args);
          }
        }
      }
    }

    return 'Error: Unknown tool "$name"';
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

  /// Build extraParams map from typeConfig and customParams for the API call.
  /// Merges provider-level and model-level standard LLM params + [ProviderParam]s
  /// with assistant-level [CustomParameter]s.
  /// Rule: ALL enabled params from provider AND model are used.
  ///       If duplicate names, model's value wins.
  /// Assistant-level params take final precedence.
  /// When [reasoning] is true, also includes user-configured reasoning params
  /// from both provider and model configs (sent only when reasoning is enabled).
  ///
  /// Custom params with invalid JSON values are omitted from the result (and
  /// NOT sent as quoted strings). The omission is logged so the user can
  /// find the offending config in the model settings page.
  Map<String, dynamic> _buildExtraParams({
    bool reasoning = false,
    String reasoningEffort = 'medium',
    Map<String, String> reasoningParamValues = const {},
  }) {
    final result = <String, dynamic>{};

    // 1. Provider-level params first (defaults)
    if (_providerConfig != null) {
      final pc = _providerConfig!.typeConfig;
      // Top P
      if (pc.containsKey('topP')) {
        result['top_p'] = (pc['topP'] as num).toDouble();
      }
      // Frequency penalty
      if (pc.containsKey('frequencyPenalty')) {
        result['frequency_penalty'] =
            (pc['frequencyPenalty'] as num).toDouble();
      }
      // Presence penalty
      if (pc.containsKey('presencePenalty')) {
        result['presence_penalty'] = (pc['presencePenalty'] as num).toDouble();
      }
      // Seed
      if (pc.containsKey('seed')) {
        result['seed'] = (pc['seed'] as num).toInt();
      }

      // Provider-level custom params
      for (final cp in _providerConfig!.customParams) {
        result[cp.paramName] = _coerceCustomParam(
            cp.paramName, cp.type, cp.defaultValue,
            source: 'provider');
      }

      // Provider-level reasoning params (when reasoning enabled)
      if (reasoning) {
        ReasoningParam? toggleParam;
        final extraParams = <ReasoningParam>[];
        for (final rp in _providerConfig!.reasoningParams) {
          if (rp.isReasoningToggle) {
            toggleParam = rp;
          } else {
            extraParams.add(rp);
          }
        }

        // Reasoning toggle
        if (toggleParam != null && toggleParam.isFilledToggle) {
          final toggleValue = reasoning
              ? (toggleParam.onValue ?? 'true')
              : (toggleParam.offValue ?? 'false');
          _setReasoningParam(
            result,
            toggleParam,
            toggleValue,
            source: 'provider',
          );
        }

        // Additional reasoning params (inference intensity etc.)
        for (final rp in extraParams) {
          if (!rp.enabled) continue;
          if (rp.paramName.trim().isEmpty) continue;
          // If options are empty, send the param name itself as the value
          // (provider allows name-only inference intensity)
          if (rp.options.isEmpty) {
            setNestedParam(
              result,
              rp.paramName,
              rp.paramName,
            );
          } else {
            final selectedValue = reasoningParamValues[rp.paramName];
            if (selectedValue != null && selectedValue.isNotEmpty) {
              _setReasoningParam(
                result,
                rp,
                selectedValue,
                source: 'provider',
              );
            }
          }
        }
      }
    }

    // 2. Model-level params (override provider params on name collision)
    final tc = _modelConfig!.typeConfig;
    // Top P
    if (tc.containsKey('topP')) {
      result['top_p'] = (tc['topP'] as num).toDouble();
    }
    // Frequency penalty
    if (tc.containsKey('frequencyPenalty')) {
      result['frequency_penalty'] = (tc['frequencyPenalty'] as num).toDouble();
    }
    // Presence penalty
    if (tc.containsKey('presencePenalty')) {
      result['presence_penalty'] = (tc['presencePenalty'] as num).toDouble();
    }
    // Seed
    if (tc.containsKey('seed')) {
      result['seed'] = (tc['seed'] as num).toInt();
    }

    // Model-level custom params
    for (final cp in _modelConfig!.customParams) {
      result[cp.paramName] = _coerceCustomParam(
          cp.paramName, cp.type, cp.defaultValue,
          source: 'model');
    }

    // Assistant-level custom params (override model-level on name collision)
    if (_assistantCustomParams != null) {
      for (final cp in _assistantCustomParams!) {
        result[cp.name] = _coerceAssistantCustomParam(cp);
      }
    }

    // Assistant-level settings override model params when enableXxx is true
    if (_assistantSettings != null) {
      final as = _assistantSettings!;
      if (as.enableTopP) {
        result['top_p'] = as.topP;
      }
      if (as.enableFrequencyPenalty) {
        result['frequency_penalty'] = as.frequencyPenalty;
      }
      if (as.enablePresencePenalty) {
        result['presence_penalty'] = as.presencePenalty;
      }
      if (as.enableSeed && as.seed != null) {
        result['seed'] = as.seed;
      }
    }

    // Reasoning params:
    // - The reasoning toggle param (isReasoningToggle=true) controls the
    //   overall reasoning on/off: when reasoning=true send onValue,
    //   when reasoning=false send offValue.
    //   If the toggle fields are all empty, skip it entirely (no toggle configured).
    // - Additional reasoning params (isReasoningToggle=false) are only sent
    //   when reasoning is ON and the param's own enabled flag is set.
    //   They send the selected value from reasoningParamValues.
    // Find the reasoning toggle (first one marked as toggle)
    ReasoningParam? toggleParam;
    final extraParams = <ReasoningParam>[];
    for (final rp in _modelConfig!.reasoningParams) {
      if (rp.isReasoningToggle) {
        toggleParam = rp;
      } else {
        extraParams.add(rp);
      }
    }

    // Only send reasoning toggle if it exists AND is filled (has a paramName)
    if (toggleParam != null && toggleParam.isFilledToggle) {
      final toggleValue = reasoning
          ? (toggleParam.onValue ?? 'true')
          : (toggleParam.offValue ?? 'false');
      _setReasoningParam(
        result,
        toggleParam,
        toggleValue,
        source: 'model',
      );
    }

    // Additional reasoning params: only sent when global toggle is ON
    if (reasoning) {
      for (final rp in extraParams) {
        if (!rp.enabled) continue;
        final selectedValue = reasoningParamValues[rp.paramName];
        if (selectedValue != null && selectedValue.isNotEmpty) {
          _setReasoningParam(
            result,
            rp,
            selectedValue,
            source: 'model',
          );
        }
      }
    }

    return _stripOmitted(result);
  }

  /// Filter out the `_OmittedSentinel` values (params that failed to coerce).
  /// Sentinel-mapped entries must be removed so they don't get re-serialized
  /// into the JSON request body.
  static Map<String, dynamic> _stripOmitted(Map<String, dynamic> params) {
    return {
      for (final entry in params.entries)
        if (entry.value is! _OmittedSentinel) entry.key: entry.value,
    };
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

  /// Dispose permanently (no more streams possible after this)
  void dispose() {
    cancel();
  }
}
