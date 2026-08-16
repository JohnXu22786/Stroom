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
          toolOutputMaxChars:
              ChatService.getEffectiveToolOutputMaxChars(_assistantSettings),
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
              // usage 计量事件（provider 流末尾产出，per-request 隔离）
              // 立即转发给上层累加到对话（每次完整请求数据返回即累加）
              onUsageEvent?.call(event.usage!, recordInput: true);
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
        final toolOutputMaxChars =
            ChatService.getEffectiveToolOutputMaxChars(_assistantSettings);
        final req = await _protocol.buildRequest(
          history: history,
          assistantPrompt: _assistantPrompt,
          contextSummary: _contextSummary,
          toolOutputMaxChars: toolOutputMaxChars,
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
        // ── 工具循环上限 ──
        // maxToolCalls = 单条用户消息内模型 API 请求（步骤）的最大次数。
        // 每次 API 响应内的多个并行工具调用属于同一"步骤"，只计 1 次；
        // 计数按用户消息重置（sendStreamWithTools 每次调用独立计数），
        // 不跨对话累计。
        // 开关关闭（设置页文案"无限制"）→ 不设上限：循环随模型停止
        // 调用工具、出错或用户取消自然结束；仅由 kMaxToolRoundsHardLimit
        // 兜底防止模型失控连续调用工具时无限消耗 API（正常任务远达不到）。
        // 持久化损坏/旧数据可能给出非正数或越界 maxToolCalls，
        // getEffectiveMaxToolRounds 统一回退默认值（此前 <= 0 会让
        // while 恒假——不发任何请求、空流无错误、消息不落库，用户
        // 完全无反馈）。
        final effectiveMaxRounds =
            ChatService.getEffectiveMaxToolRounds(_assistantSettings);
        final maxRounds =
            effectiveMaxRounds ?? ChatService.kMaxToolRoundsHardLimit;

        // 无限模式（开关关闭）下区分"硬上限强制停止"与正常终止：
        // 每轮开始时置 false，仅当整轮完整执行（含工具执行与消息追加）
        // 后才置 true——循环从 while 条件检查处退出时若该标记为 true，
        // 说明是达到上限被强制停止，而非模型停用工具/出错/取消。
        var lastRoundHadToolCalls = false;
        while (!_isCancelledByUser && loopProtection < maxRounds) {
          loopProtection++;
          lastRoundHadToolCalls = false;

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
          // 上限内的每一轮工具都保持可用（与 AI SDK stepCountIs 语义一致：
          // 所有 step 均携带 tools，达限即停，无额外"收尾轮"）。
          _streamSubscription = _provider!
              .chatStream(
            messages,
            model: _modelConfig!.modelId,
            reasoning: reasoning,
            reasoningEffort: reasoningEffort,
            maxTokens: _effectiveMaxTokens, // null when toggle is OFF
            temperature: _effectiveTemperature, // null when toggle is OFF
            tools: toolDefs.isEmpty ? null : toolDefs,
            system: req.system,
            extraParams: extraParams,
            cancelToken: _cancelToken,
          )
              .listen(
            (event) {
              // usage 计量是 API 计费事实（per-request 隔离），必须
              // 先于取消守卫处理：用户停止后仍要把已计量请求的
              // cost/tokens 累加到对话（错误轮/流末尾的 usage 事件）。
              if (event.usage != null) {
                // usage 计量事件（provider 流末尾产出，per-request 隔离）
                // 立即转发给上层累加到对话（每次完整请求数据返回即累加）
                onUsageEvent?.call(event.usage!, recordInput: true);
              }
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
          // controller.isClosed covers the cancel→resend race here too:
          // the resend resets _isCancelledByUser, so a cancelled round
          // resuming on the closed controller would otherwise throw a
          // silently-swallowed StateError on the next controller.add.
          if (_isCancelledByUser || controller.isClosed) break;
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

          // ── 并行工具执行 ──
          // 同一轮内的多个工具（模型一次触发多个工具调用）同时运行，
          // 而非依次执行。先同步发出全部 ToolCallStartEvent（所有工具
          // 立即显示 running），再 Future.wait 并发执行，最后按**声明
          // 顺序**补发 ToolCallCompleteEvent——tool_result 与 tool_use
          // 块保持同序（协议层按 id 配对，声明序保证结果列表稳定可读）。
          // 注意：并行后取消只能丢弃结果，不能取消已启动的工具——
          // 已启动的工具副作用（文件写入/外部调用）会执行完毕。
          final pendingResults = <Future<String>>[];

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
            neutralCalls.add(neutral);
            pendingResults.add(_runTool(name, parsedArgs));
          }

          // 执行期间被取消：跳过 complete 事件（controller 已关闭，
          // 且避免把"恰在取消时完成"的工具误标为正常结果）。
          // controller.isClosed 额外覆盖"取消后立即重发"竞态：重发会
          // 重置 _isCancelledByUser，旧轮若只看该标志会往已关闭的
          // controller 补发事件（StateError）并污染新轮的消息缓冲。
          if (!_isCancelledByUser && !controller.isClosed) {
            final executed = await Future.wait(pendingResults);
            for (var i = 0; i < neutralCalls.length; i++) {
              if (_isCancelledByUser || controller.isClosed) break;
              controller
                  .add(ToolCallCompleteEvent(neutralCalls[i].id, executed[i]));
              results.add(ToolCallResult(
                  toolCallId: neutralCalls[i].id, result: executed[i]));
            }
          }

          // 注意：用户取消时（cancel() 已关闭 controller）无法再补发事件；
          // 中断工具标记由 ChatStreamManager 在 post-stream 阶段完成
          // （把 running/pending 工具标为 kToolInterruptedPlaceholder）。
          //
          // 取消/关闭后必须**终止本轮**而不是跳过继续循环：cancel() 后
          // 立即重发会重置 _isCancelledByUser 并新建 controller，旧轮若
          // 继续进入下一轮 while，会 cancel 掉新请求的
          // _streamSubscription/_cancelToken（新请求被中止/永久挂起）、
          // 覆盖 _roundCompleter、并发出一个幽灵请求（产生计费）。
          if (_isCancelledByUser || controller.isClosed) break;

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
          messages.addAll(_protocol.buildToolResultMessages(results,
              toolOutputMaxChars: toolOutputMaxChars));

          // Reset per-round buffers for the next iteration
          _contentBuffer = '';
          _lastReasoningLength = _reasoningBuffer.length;
          _thinkingSignature = '';
          // 本轮完整执行且未提前退出（工具已执行、消息已追加）。
          lastRoundHadToolCalls = true;
        }
        // 无限模式下由硬上限强制退出（非取消/非错误/非模型停用工具）：
        // 记录 warning，便于在日志中区分"模型失控"与正常终止。
        // 开关开启时达限即停是用户配置的预期行为，不在此列。
        if (!_isCancelledByUser &&
            effectiveMaxRounds == null &&
            loopProtection >= maxRounds &&
            lastRoundHadToolCalls) {
          AppLogService.warning(
            'ChatService',
            '工具循环达到硬上限 $maxRounds 次 API 请求（开关关闭/无限模式），'
            '模型可能失控持续调用工具，已强制停止。',
          );
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

  /// Executes a single tool for the parallel tool-call batch.
  ///
  /// Wraps [_executeTool] with the per-tool error fallback ('Error: …') and
  /// the storage-level truncation (50KB UTF-8 bytes, opencode MAX_BYTES —
  /// CJK multi-byte content counted per character would exceed the limit
  /// ~3x). Small results are kept intact for the UI and history rebuild.
  ///
  /// Never throws: the returned future always completes with a result
  /// string, so [Future.wait] on the batch can't fail as a whole and one
  /// failing tool doesn't abort its siblings.
  Future<String> _runTool(String name, Map<String, dynamic> args) async {
    String result;
    try {
      result = await _executeTool(name, args);
    } catch (e) {
      result = 'Error: $e';
    }
    if (utf8.encode(result).length > ChatService.maxToolResultBytes) {
      result =
          '${truncateUtf8(result, ChatService.maxToolResultBytes)}$kToolOutputTruncatedSuffix';
    }
    return result;
  }

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
