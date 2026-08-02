part of 'chat_service.dart';

extension ChatServiceStreamingExt on ChatService {
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
            } else if (event.usage != null) {
              // usage 计量事件（provider 流末尾产出）
              _accumulateFromMap(event.usage!, recordInput: true);
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
    // 注意：不重置 _accumulatedUsage —— 一次"用户发送"内的内部任务
    // （压缩请求先于主请求执行）与主请求多轮共用同一个累计器；
    // service 生命周期 = 一次发送（manager 每次流结束 cancelService），
    // 重置在这里会清掉压缩请求已累计的 usage。

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
        // 持久化损坏/旧数据可能给出非正数 maxToolCalls：totalRounds <= 0
        // 会让 while 恒假——不发任何请求、空流无错误、消息不落库，
        // 用户完全无反馈。非正数按未配置处理（回退安全上限）。
        final effectiveMaxRounds =
            (maxRounds != null && maxRounds >= 1) ? maxRounds : null;
        // 对齐 opencode steps 语义：maxRounds 轮内工具可用；
        // 若模型在最后一轮仍请求工具（超限），追加一轮"收尾轮"
        // （tools 禁用 + 文本收尾提示词），让模型总结而不是硬跑。
        // 未配置 maxRounds 时（无限模式）仍有安全上限护栏
        // （kMaxToolRoundsFallback），防止模型无限 ping-pong 工具。
        final totalRounds =
            effectiveMaxRounds == null ? null : effectiveMaxRounds + 1;
        final maxLoopRounds =
            effectiveMaxRounds ?? ChatService.kMaxToolRoundsFallback;

        while (!_isCancelledByUser &&
            (totalRounds == null || loopProtection < totalRounds)) {
          loopProtection++;
          if (loopProtection % 50 == 0) {
            AppLogService.info('ChatService', '工具调用循环: 第 $loopProtection 轮');
          }
          // 无限模式的安全护栏：达到上限后停止（等价于 maxRounds 模式
          // 的收尾轮语义），避免成本失控。第 40 轮正常执行，第 41 轮
          // 发出前停止（> 而非 >=，避免少执行一轮）。
          if (totalRounds == null && loopProtection > maxLoopRounds) {
            await AppLogService.warning(
                'ChatService', '工具调用循环达到安全上限 $maxLoopRounds 轮, 停止');
            break;
          }

          _streamSubscription?.cancel();
          _cancelToken?.cancel();
          _cancelToken = CancelToken();

          final completer = Completer<void>();
          // 登记当前轮 completer：cancel() 时完成它使循环退出
          // （真实 provider 取消订阅后 onDone/onError 不送达）。
          _roundCompleter = completer;
          final toolCallRefs = <Map<String, dynamic>>[];
          // 本轮流错误标记：onError 后立即停止轮处理，不再执行
          // 本轮的剩余工具或发起下一轮请求（错误已上抛给 manager，
          // 继续执行工具只会产生用户看不到的副作用）。
          Object? roundStreamError;
          // ── Max-steps 语义（opencode MAX_STEPS_PROMPT）──
          // 收尾轮：tools 定义保留（Anthropic 要求历史含 tool_use/
          // tool_result 块时必须定义 tools，否则 400）+ tool_choice none
          // 显式禁止调用 + 前置文本收尾提示，要求模型总结已做/未做/下一步。
          final isLastStep =
              effectiveMaxRounds != null && loopProtection > effectiveMaxRounds;
          final roundExtraParams = <String, dynamic>{...extraParams};
          if (isLastStep) {
            roundExtraParams.addAll(_protocol.toolChoiceNoneJson());
          }
          var roundMessages = messages;
          if (isLastStep) {
            // 收尾提示以 user 角色注入（对齐 opencode MAX_STEPS_PROMPT）：
            // assistant 角色注入的"要求"部分模型可能不当作指令执行。
            roundMessages = [
              ...messages,
              {'role': 'user', 'content': ChatService.maxStepsPrompt},
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
            tools: toolDefs.isEmpty ? null : toolDefs,
            system: req.system,
            extraParams: roundExtraParams,
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
              // usage 计量事件（provider 流末尾产出，per-request 隔离）
              if (event.usage != null) {
                _accumulateFromMap(event.usage!, recordInput: true);
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
              // Capture the provider's final response snapshot on the
              // success path too. The provider instance is shared across
              // concurrent conversations (per-conversation services), so
              // without this snapshot the shared slot may later be
              // overwritten by another conversation's chunk — mixing up
              // the raw diagnostics shown for THIS request.
              _lastResponseData = _provider?.lastResponseData;
              if (!completer.isCompleted) completer.complete();
            },
            onError: (Object error) {
              _streamSubscription = null;
              roundStreamError = error;
              debugPrint('ChatService stream error: $error');
              _lastResponseData = _provider?.lastResponseData;
              if (!controller.isClosed) {
                controller.addError(error);
              }
              if (!completer.isCompleted) completer.complete();
            },
          );

          await completer.future;
          _roundCompleter = null;
          if (_isCancelledByUser) break;
          // 本轮流错误：工具结果已不可信，终止整个循环
          // （manager 已通过 addError 收到错误并走错误路径）。
          if (roundStreamError != null) break;

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
            // 存储级截断：50KB 上限（opencode MAX_BYTES，按 **UTF-8 字节**
            // 计——CJK 等多字节内容按字符计会实际超限约 3 倍）。
            // 不强行截断小结果——完整结果保留给 UI 与历史重建。
            if (utf8.encode(result).length > ChatService.maxToolResultBytes) {
              result =
                  '${truncateUtf8(result, ChatService.maxToolResultBytes)}$kToolOutputTruncatedSuffix';
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

  /// Cancel the current stream
  void cancel() {
    _isCancelledByUser = true;
    _cancelToken?.cancel();
    _cancelToken = null;
    // 中止所有进行中的内部任务（压缩/标题请求）
    for (final t in _internalTaskTokens) {
      t.cancel();
    }
    _internalTaskTokens.clear();
    _streamSubscription?.cancel();
    _streamSubscription = null;
    // 完成当前工具轮次的等待：真实 provider 在订阅取消后不会送达
    // onDone/onError，不完成则 sendStreamWithTools 的工具循环永久挂起
    // （详见 _roundCompleter 字段注释）。带 isCompleted 守卫与
    // onDone/onError 风格一致。
    final roundCompleter = _roundCompleter;
    _roundCompleter = null;
    if (roundCompleter != null && !roundCompleter.isCompleted) {
      roundCompleter.complete();
    }
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

  /// Dispose permanently (no more streams possible after this)
  void dispose() {
    cancel();
  }
}
