import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import '../models/chat_event.dart';
import '../models/chat_message.dart';
import '../models/tool_call.dart';
import '../pages/chat/chat_types.dart';
import '../providers/chat_stream_provider.dart';
import '../providers/conversation_provider.dart';
import 'app_log_service.dart';
import 'chat_adapter.dart';

// ============================================================================
// ChatStreamManager — 对话流式请求管理器
// ============================================================================
//
// 职责：
// - 持有 [ChatAdapter] 实例，管理其生命周期
// - 独立于页面 Widget 运行流式请求循环
// - 通过 Riverpod providers 向页面暴露流式状态
// - 在流式过程中定期持久化部分结果，防止应用中断丢失
// - 在流式完成后自动持久化完整消息
// - 支持取消和销毁
// - 每条对话独立跟踪流式状态
//
// 与 ChatPage 的关系：
// - ChatStreamManager 是 app 级单例，不依赖任何页面 Widget
// - ChatPage 通过 chatStreamManagerProvider 获取管理器引用
// - ChatPage 将发送请求、取消等操作委托给管理器
// - ChatPage 通过 watch providers 获取实时流式状态
// ============================================================================

class ChatStreamManager {
  final Ref? _ref;
  final ChatAdapter _adapter = ChatAdapter();

  // ── 流式状态 ──
  bool _isStreaming = false;
  bool _cancelledByUser = false;
  String? _streamingMsgId;
  String? _streamingConvId;
  String _fullReply = '';
  String _reasoningBuffer = '';
  List<String> _reasoningSections = [];
  List<ToolCallData> _toolCalls = [];
  List<ChatMessage> _history = [];
  bool _hasReceivedFirstToken = false;

  /// Accumulator for tool calls across streaming rounds (used for history).
  final List<ToolCallData> _accumulatedToolCalls = [];

  // ── 节流控制 ──
  DateTime _lastTextUpdate = DateTime.now();
  DateTime _lastReasoningUpdate = DateTime.now();
  static const Duration _textThrottle = Duration(milliseconds: 200); // 5次/秒
  static const Duration _reasoningThrottle = Duration(milliseconds: 200);

  // ── 定期持久化 ──
  Timer? _persistTimer;
  static const Duration _persistInterval = Duration(seconds: 5);

  ChatStreamManager([this._ref]);

  // ── 公开 getter ──

  ChatAdapter get adapter => _adapter;

  bool get isStreaming => _isStreaming;

  /// 当前正在流式的对话 ID，用于页面判断是否属于本对话
  String? get streamingConvId => _streamingConvId;

  String? get streamingMsgId => _streamingMsgId;

  String get fullReply => _fullReply;

  String get reasoningBuffer => _reasoningBuffer;

  List<String> get reasoningSections => List.unmodifiable(_reasoningSections);

  List<ToolCallData> get toolCalls => List.unmodifiable(_toolCalls);

  List<ChatMessage> get history => List.unmodifiable(_history);

  bool get hasReceivedFirstToken => _hasReceivedFirstToken;

  // ── Provider 更新辅助 ──

  void _setProvider<T>(StateProvider<T> provider, T value) {
    if (_ref == null) return;
    _ref!.read(provider.notifier).state = value;
  }

  // ── 公共 API ──

  /// 启动流式请求，独立于页面 Widget 在后台运行。
  ///
  /// [text] 用户消息文本
  /// [convId] 当前对话 ID
  /// [history] 当前对话的消息历史（不包含新创建的消息）
  /// [tools] 启用的工具列表
  /// [reasoning] 是否启用推理
  ///
  /// 返回 Future，在流式完成后完成。调用方可以 await 但不需要。
  Future<void> startStreaming({
    required String text,
    required String convId,
    required List<ChatMessage> history,
    List<ToolDefinition> tools = const [],
    bool reasoning = false,
    String reasoningEffort = 'medium',
    Map<String, String> reasoningParamValues = const {},
  }) async {
    if (_isStreaming) {
      debugPrint('[ChatStreamManager] 已有流式请求进行中，忽略');
      return;
    }

    _isStreaming = true;
    _cancelledByUser = false;
    _streamingConvId = convId;
    _history = List.from(history);
    _fullReply = '';
    _reasoningBuffer = '';
    _reasoningSections = [];
    _toolCalls = [];
    _accumulatedToolCalls.clear();
    _hasReceivedFirstToken = false;
    _lastTextUpdate = DateTime.now();
    _lastReasoningUpdate = DateTime.now();

    final aiMsgId = 'a${DateTime.now().millisecondsSinceEpoch}';
    _streamingMsgId = aiMsgId;

    // 更新 providers (同步执行，页面立即可见)
    _setProvider(isStreamingProvider, true);
    _setProvider(streamingMsgIdProvider, aiMsgId);
    _setProvider(streamingFullReplyProvider, '');
    _setProvider(streamingHasFirstTokenProvider, false);
    _setProvider(streamingReasoningProvider, '');
    _setProvider(streamingReasoningSectionsProvider, []);
    _setProvider(streamingToolCallsProvider, []);

    // 启动定期持久化定时器（每5秒保存一次部分结果）
    _persistTimer = Timer.periodic(_persistInterval, (_) {
      _doPeriodicPersist();
    });

    await AppLogService.info('ChatStreamManager', '开始流式请求, convId=$convId');

    Object? streamError;
    Map<String, dynamic>? rawRequestCapture;
    Map<String, dynamic>? rawResponseCapture;

    try {
      final stream = _adapter.sendStreamWithTools(
        text,
        history: _history,
        reasoning: reasoning,
        reasoningEffort: reasoningEffort,
        reasoningParamValues: reasoningParamValues,
        tools: tools,
      );

      await for (final event in stream) {
        if (_cancelledByUser) break;

        switch (event) {
          case TextEvent e:
            if (!_hasReceivedFirstToken) {
              _hasReceivedFirstToken = true;
              _setProvider(streamingHasFirstTokenProvider, true);
            }
            _fullReply += e.text;
            // 节流：最长200ms更新一次 provider
            final now = DateTime.now();
            if (now.difference(_lastTextUpdate) >= _textThrottle) {
              _lastTextUpdate = now;
              _setProvider(streamingFullReplyProvider, _fullReply);
            }

          case ReasoningEvent e:
            _reasoningBuffer += e.text;
            final sections = List<String>.from(_reasoningSections);
            if (sections.isNotEmpty) {
              sections[sections.length - 1] = _reasoningBuffer;
            } else {
              sections.add(_reasoningBuffer);
            }
            _reasoningSections = sections;
            // 节流
            final now = DateTime.now();
            if (now.difference(_lastReasoningUpdate) >= _reasoningThrottle) {
              _lastReasoningUpdate = now;
              _setProvider(streamingReasoningProvider, _reasoningBuffer);
              _setProvider(streamingReasoningSectionsProvider, sections);
            }

          case ReasoningSectionEndEvent():
            final sections = List<String>.from(_reasoningSections);
            sections.add('');
            _reasoningSections = sections;
            _setProvider(streamingReasoningSectionsProvider, sections);

          case ToolCallStartEvent e:
            final toolCallData = ToolCallData(
              id: e.toolCall.id,
              name: e.toolCall.name,
              arguments: Map<String, dynamic>.from(e.toolCall.arguments),
              status: ToolCallStatus.running,
            );
            _toolCalls.add(toolCallData);
            _accumulatedToolCalls.add(toolCallData);
            _setProvider(streamingToolCallsProvider,
                List<ToolCallData>.from(_toolCalls));

          case ToolCallCompleteEvent e:
            for (var i = 0; i < _toolCalls.length; i++) {
              if (_toolCalls[i].id == e.toolCallId) {
                _toolCalls[i] = _toolCalls[i].copyWith(
                  status: ToolCallStatus.completed,
                  result: e.result,
                );
                break;
              }
            }
            for (var i = 0; i < _accumulatedToolCalls.length; i++) {
              if (_accumulatedToolCalls[i].id == e.toolCallId) {
                _accumulatedToolCalls[i] = _accumulatedToolCalls[i].copyWith(
                  status: ToolCallStatus.completed,
                  result: e.result,
                );
                break;
              }
            }
            _setProvider(streamingToolCallsProvider,
                List<ToolCallData>.from(_toolCalls));
        }
      }
    } catch (e, s) {
      streamError = e;
      if (!_cancelledByUser) {
        debugPrint('[ChatStreamManager] 流式请求异常: $e\n$s');
        await AppLogService.error('ChatStreamManager', '流式请求异常', e, s);
        _fullReply = '错误: ${e.toString()}';
        _setProvider(streamingFullReplyProvider, _fullReply);
        _toolCalls.clear();
        _setProvider(streamingToolCallsProvider, []);
      }
    } finally {
      // 停止定期持久化
      _persistTimer?.cancel();
      _persistTimer = null;

      // 最后一次节流刷新：确保最后的文本到达 UI
      _setProvider(streamingFullReplyProvider, _fullReply);

      // 捕获请求/响应原始数据
      try {
        final reqBody = _adapter.lastRequestBody;
        final headers = _adapter.lastRequestHeaders;
        final url = _adapter.lastRequestUrl;
        if (reqBody != null || headers != null || url != null) {
          rawRequestCapture = {};
          if (url != null) rawRequestCapture['url'] = url;
          if (headers != null) rawRequestCapture['headers'] = headers;
          if (reqBody != null) rawRequestCapture['body'] = reqBody;
        }
        final respData = _adapter.lastResponseData;
        final statusCode = _adapter.lastResponseStatusCode;
        final respHeaders = _adapter.lastResponseHeaders;
        if (respData != null || statusCode != null || respHeaders != null) {
          rawResponseCapture = {};
          if (statusCode != null) {
            rawResponseCapture['statusCode'] = statusCode;
          }
          if (respHeaders != null) {
            rawResponseCapture['headers'] = respHeaders;
          }
          if (respData != null) rawResponseCapture['data'] = respData;
        } else if (streamError is Exception) {
          rawResponseCapture = {'error': streamError.toString()};
        }
      } catch (_) {}

      // 捕获推理内容
      final finalReasoning = _adapter.reasoningContent;
      if (finalReasoning.isNotEmpty) {
        _reasoningBuffer = finalReasoning;
        final sections = List<String>.from(_reasoningSections);
        if (sections.isNotEmpty) {
          sections[sections.length - 1] = finalReasoning;
        } else {
          sections.add(finalReasoning);
        }
        _reasoningSections = sections;
        _setProvider(streamingReasoningProvider, finalReasoning);
        _setProvider(streamingReasoningSectionsProvider, sections);
      }
    }

    // ── 流式完成后处理 ──
    try {
      if (_fullReply.isNotEmpty) {
        final isError = _fullReply.startsWith('错误:');
        final msg = ChatMessage(
          role: 'assistant',
          content: _fullReply,
          id: _streamingMsgId ?? '',
          isError: isError,
          reasoningContent:
              _reasoningBuffer.isNotEmpty ? _reasoningBuffer : null,
          rawRequest: rawRequestCapture,
          rawResponse: rawResponseCapture,
          toolCalls:
              _accumulatedToolCalls.isNotEmpty ? _accumulatedToolCalls : null,
          reasoningSections:
              _reasoningSections.isNotEmpty ? _reasoningSections : null,
        );
        _history.add(msg);
      }
    } catch (e, s) {
      debugPrint('[ChatStreamManager] 后处理错误: $e\n$s');
    } finally {
      _isStreaming = false;
      _streamingMsgId = null;
      _setProvider(isStreamingProvider, false);
      _setProvider(streamingFullReplyProvider, '');
      _setProvider(streamingHasFirstTokenProvider, false);
      _setProvider(streamingToolCallsProvider, []);
    }

    // 持久化完整消息
    if (_streamingConvId != null && _history.isNotEmpty) {
      await _saveMessages(convId: _streamingConvId!);
    }
  }

  /// 取消当前流式请求。
  ///
  /// 只属于当前对话的取消才生效，防止误取消其他对话的流。
  void cancel([String? convId]) {
    if (!_isStreaming) return;
    // 如果指定了 convId 且不匹配，说明取消的是其他对话，忽略
    if (convId != null && convId != _streamingConvId) return;
    _cancelledByUser = true;
    _adapter.cancel();
  }

  /// 释放资源。
  void dispose() {
    _persistTimer?.cancel();
    _persistTimer = null;
    cancel();
    _adapter.dispose();
  }

  // ── 私有方法 ──

  /// 定期持久化部分结果。在流式进行中每5秒保存一次，
  /// 防止应用突然终止导致已接收的数据丢失。
  void _doPeriodicPersist() {
    if (!_isStreaming || _streamingConvId == null) return;
    if (_fullReply.isEmpty && _reasoningBuffer.isEmpty) return;
    if (_ref == null) return;
    try {
      // 构建包含当前部分结果的消息历史
      // 注意：_history 可能还没有包含当前流式的消息
      final partialHistory = List<ChatMessage>.from(_history);
      if (_fullReply.isNotEmpty) {
        final exists = partialHistory.any((m) => m.id == _streamingMsgId);
        if (!exists) {
          partialHistory.add(ChatMessage(
            role: 'assistant',
            content: _fullReply,
            id: _streamingMsgId ?? '',
            reasoningContent:
                _reasoningBuffer.isNotEmpty ? _reasoningBuffer : null,
            toolCalls: _accumulatedToolCalls.isNotEmpty
                ? List<ToolCallData>.from(_accumulatedToolCalls)
                : null,
            reasoningSections:
                _reasoningSections.isNotEmpty ? _reasoningSections : null,
          ));
        }
      }
      _ref!
          .read(conversationsProvider.notifier)
          .updateMessages(_streamingConvId!, partialHistory);
    } catch (e) {
      debugPrint('[ChatStreamManager] 定期持久化失败: $e');
    }
  }

  Future<void> _saveMessages({required String convId}) async {
    try {
      await _ref
          ?.read(conversationsProvider.notifier)
          .updateMessages(convId, List<ChatMessage>.from(_history));
    } catch (e, s) {
      debugPrint('[ChatStreamManager] 保存消息失败: $e\n$s');
      await AppLogService.error('ChatStreamManager', '保存消息失败', e, s);
    }
  }
}
