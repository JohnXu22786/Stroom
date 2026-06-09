import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../models/assistant.dart' show CustomParameter;
import '../models/ai_stream_event.dart';
import '../models/chat_event.dart';
import '../models/chat_message.dart';
import '../models/tool_call.dart';
import '../providers/chat_api_provider.dart';
import '../providers/provider_config.dart';
import 'attachment_storage.dart';
import 'mcp_client.dart';

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

class ChatService {
  // ── Instance fields (used when constructed with a provider) ─────
  final BaseChatProvider? _provider;
  final ModelConfig? _modelConfig;
  bool _isCancelledByUser = false;
  CancelToken? _cancelToken;
  StreamSubscription<AIStreamEvent>? _streamSubscription;
  StreamController<String>? _controller;
  String _reasoningBuffer = '';
  Map<String, dynamic>? _lastRequestBody;
  Map<String, dynamic>? _lastResponseData;
  Map<String, String>? _lastRequestHeaders;
  Map<String, List<String>>? _lastResponseHeaders;
  String? _lastRequestUrl;
  int? _lastResponseStatusCode;

  /// Construct an instance backed by a real provider and model config.
  ChatService({
    required BaseChatProvider provider,
    required ModelConfig modelConfig,
  })  : _provider = provider,
        _modelConfig = modelConfig;

  /// Whether there's an active streaming session (instance or static).
  bool get isStreamActive => _controller != null && !_controller!.isClosed;

  Map<String, dynamic>? get lastRequestBody =>
      _lastRequestBody ?? _provider?.lastRequestBody;
  Map<String, dynamic>? get lastResponseData =>
      _lastResponseData ?? _provider?.lastResponseData;
  Map<String, String>? get lastRequestHeaders =>
      _lastRequestHeaders ?? _provider?.lastRequestHeaders;
  String? get lastRequestUrl =>
      _lastRequestUrl ?? _provider?.lastRequestUrl;
  int? get lastResponseStatusCode =>
      _lastResponseStatusCode ?? _provider?.lastResponseStatusCode;
  Map<String, List<String>>? get lastResponseHeaders =>
      _lastResponseHeaders ?? _provider?.lastResponseHeaders;

  // ── Instance methods ────────────────────────────────────────────

  /// Stream a message — converts [history] (which already contains the latest
  /// user message with attachments) into API‑format messages and streams the
  /// reply.
  ///
  /// [history] must already include the latest user message (added by the
  /// caller before calling this method). Attachments are converted to the
  /// OpenAI multimodal content‑array format (base64 inline images).
  Stream<String> sendStream(String userMessage,
      {required List<ChatMessage> history, bool reasoning = false}) {
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

    final extraParams = _buildExtraParams();

    Future.microtask(() async {
      try {
        if (_isCancelledByUser) return;
        final apiMessages = await _prepareApiMessages(history);
        _lastRequestBody = {
          'messages': apiMessages,
          'model': _modelConfig?.modelId,
          'max_tokens': (_modelConfig!.typeConfig['context'] as num?)?.toInt() ??
              (_modelConfig!.typeConfig['maxTokens'] as num?)?.toInt() ?? 4096,
          'temperature': (_modelConfig!.typeConfig['temperature'] as num?)?.toDouble() ?? 0.7,
        };
        _cancelToken = CancelToken();
        _streamSubscription = _provider!
            .chatStream(
          apiMessages,
          model: _modelConfig!.modelId,
          reasoning: reasoning,
          maxTokens: (_modelConfig!.typeConfig['context'] as num?)
                  ?.toInt()
              ?? (_modelConfig!.typeConfig['maxTokens'] as num?)?.toInt()
              ?? 4096,
          temperature: (_modelConfig!.typeConfig['temperature'] as num?)
                  ?.toDouble() ??
              0.7,
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
  Stream<ChatEvent> sendStreamWithTools(
    String userMessage, {
    required List<ChatMessage> history,
    bool reasoning = false,
    List<ToolDefinition> tools = const [],
  }) {
    _isCancelledByUser = false;
    _reasoningBuffer = '';

    final controller = StreamController<ChatEvent>(
      onCancel: () {
        _cancelToken?.cancel();
        _cancelToken = null;
        _streamSubscription?.cancel();
        _streamSubscription = null;
      },
    );

    final extraParams = _buildExtraParams();
    final toolDefs = tools.map((t) => t.toJson()).toList();

    Future.microtask(() async {
      try {
        if (_isCancelledByUser) return;
        var messages = await _prepareApiMessages(history);
        _lastRequestBody = {
          'messages': messages,
          'model': _modelConfig?.modelId,
          'max_tokens': (_modelConfig!.typeConfig['context'] as num?)?.toInt() ??
              (_modelConfig!.typeConfig['maxTokens'] as num?)?.toInt() ?? 4096,
          'temperature': (_modelConfig!.typeConfig['temperature'] as num?)?.toDouble() ?? 0.7,
          'tools': toolDefs.isNotEmpty ? toolDefs : null,
        };
        int loopProtection = 0;

        while (!_isCancelledByUser && loopProtection < 10) {
          loopProtection++;
          _cancelToken = CancelToken();

          final completer = Completer<void>();
          final toolCallRefs = <Map<String, dynamic>>[];

          _streamSubscription = _provider!
              .chatStream(
            messages,
            model: _modelConfig!.modelId,
            reasoning: reasoning,
            maxTokens:
                (_modelConfig!.typeConfig['context'] as num?)?.toInt() ??
                    (_modelConfig!.typeConfig['maxTokens'] as num?)?.toInt() ??
                    4096,
            temperature:
                (_modelConfig!.typeConfig['temperature'] as num?)?.toDouble() ??
                    0.7,
            tools: toolDefs.isNotEmpty ? toolDefs : null,
            extraParams: extraParams,
            cancelToken: _cancelToken,
          ).listen(
            (event) {
              if (_isCancelledByUser) return;
              if (event.isReasoning) {
                _reasoningBuffer += event.text;
              } else if (event.isToolCallEvent) {
                toolCallRefs.addAll(event.toolCalls!);
              } else if (event.text.isNotEmpty) {
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

          // Process tool calls
          for (final tc in toolCallRefs) {
            if (_isCancelledByUser) break;
            final fn = tc['function'] as Map<String, dynamic>? ?? {};
            final name = fn['name'] as String? ?? 'unknown';
            final rawArgs = fn['arguments'] as String? ?? '{}';
            final toolCallId = tc['id'] as String? ?? '';

            Map<String, dynamic> parsedArgs = {};
            try {
              parsedArgs =
                  Map<String, dynamic>.from(jsonDecode(rawArgs));
            } catch (_) {}

            final toolCallData = ToolCallData(
              id: toolCallId,
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

            controller.add(
                ToolCallCompleteEvent(toolCallId, result));

            // Add tool call + result to messages for the next API turn
            messages.add({
              'role': 'assistant',
              'content': null,
              'tool_calls': [
                {
                  'id': toolCallId,
                  'type': 'function',
                  'function': {'name': name, 'arguments': rawArgs},
                }
              ],
            });
            messages.add({
              'role': 'tool',
              'tool_call_id': toolCallId,
              'content': result,
            });
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

  /// Convert [ChatMessage] list to API‑format message maps.
  ///
  /// Messages with image attachments are converted to the OpenAI multimodal
  /// content‑array format. Non‑image attachments are currently skipped.
  Future<List<Map<String, dynamic>>> _prepareApiMessages(
      List<ChatMessage> history) async {
    final result = <Map<String, dynamic>>[];
    for (final msg in history) {
      if (msg.attachments.isEmpty) {
        result.add({'role': msg.role, 'content': msg.content});
      } else {
        final parts = <Map<String, dynamic>>[];
        if (msg.content.isNotEmpty) {
          parts.add({'type': 'text', 'text': msg.content});
        }
        for (final att in msg.attachments) {
          if (att.fileType == 'image') {
            final bytes = await AttachmentStorage.readFile(att.storagePath);
            if (bytes != null && bytes.isNotEmpty) {
              if (bytes.length > 10 * 1024 * 1024) {
                parts.add({'type': 'text', 'text': '[图片过大已跳过: ${att.fileName}]'});
                continue;
              }
              final b64 = base64Encode(bytes);
              final ext = _imageExtension(att.mimeType);
              parts.add({
                'type': 'image_url',
                'image_url': {'url': 'data:image/$ext;base64,$b64'},
              });
            }
          } else {
            // Try to read text content for text-based files
            final textExts = ['txt', 'md', 'json', 'csv', 'log', 'yaml', 'xml', 'ini', 'cfg', 'py', 'js', 'ts', 'dart', 'java', 'cpp', 'h', 'rs', 'go', 'rb', 'php'];
            final ext = att.fileName.split('.').last.toLowerCase();
            if (textExts.contains(ext)) {
              try {
                final bytes = await AttachmentStorage.readFile(att.storagePath);
                if (bytes == null) throw Exception('file not readable');
                final textContent = utf8.decode(bytes);
                final truncated = textContent.length > 4000 ? textContent.substring(0, 4000) + '\n... [truncated]' : textContent;
                parts.add({'type': 'text', 'text': '以下为文件 ${att.fileName} 的内容:\n$truncated'});
              } catch (_) {
                parts.add({'type': 'text', 'text': '[${att.fileName} - 无法读取文件内容]'});
              }
            } else {
              parts.add({
                'type': 'text',
                'text': '[Attached file: ${att.fileName}]',
              });
            }
          }
        }
        result.add({'role': msg.role, 'content': parts});
      }
    }
    return result;
  }

  /// Map MIME type to file extension for data URI.
  static String _imageExtension(String mimeType) {
    switch (mimeType) {
      case 'image/png':
        return 'png';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      case 'image/bmp':
        return 'bmp';
      default:
        return 'jpeg';
    }
  }

  /// Non-streaming version - collects stream into a single string.
  Future<String> send(String userMessage,
      {required List<ChatMessage> history, bool reasoning = false}) async {
    final chunks = <String>[];
    await for (final chunk in sendStream(userMessage, history: history, reasoning: reasoning)) {
      chunks.add(chunk);
    }
    return chunks.join('');
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
    _cleanUp();
  }

  void _cleanUp() {
    if (_controller?.isClosed ?? true) {
      _controller = null;
    }
  }

  // ── Tool execution ────────────────────────────────────────────────

  static final Map<String, Map<String, dynamic>> _toolRegistries = {};

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
  static void registerTool(
    ToolDefinition def,
    String Function(Map<String, dynamic>) handler,
  ) {
    _toolRegistries[def.name] = {
      'definition': def,
      'handler': handler,
    };
  }

  Future<String> _executeTool(String name, Map<String, dynamic> args) async {
    // First check locally registered tools
    final entry = _toolRegistries[name];
    if (entry != null) {
      final handler = entry['handler'] as String Function(Map<String, dynamic>);
      return handler(args);
    }

    // Then check MCP clients
    if (_mcpClientManager != null) {
      for (final entry in _mcpClientManager!.clients.entries) {
        final client = entry.value;
        if (client.isConnected == false && client.isDisposed == false) {
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

  /// Build extraParams map from customParams for the API call.
  /// Merges model-level [ProviderParam]s with assistant-level [CustomParameter]s.
  /// Assistant-level params take precedence when names collide.
  Map<String, dynamic> _buildExtraParams() {
    final result = <String, dynamic>{};

    // Model-level custom params
    final modelParams = _modelConfig!.customParams;
    for (final cp in modelParams) {
      result[cp.paramName] = switch (cp.type) {
        'number' => double.tryParse(cp.defaultValue) ?? 0.0,
        'boolean' => cp.defaultValue.toLowerCase() == 'true',
        'string' || _ => cp.defaultValue,
      };
    }

    // Assistant-level custom params (override model-level on name collision)
    if (_assistantCustomParams != null) {
      for (final cp in _assistantCustomParams!) {
        result[cp.name] = switch (cp.type) {
          'number' => (cp.value is num)
              ? (cp.value as num).toDouble()
              : (double.tryParse(cp.value.toString()) ?? 0.0),
          'boolean' => (cp.value is bool) ? cp.value : (cp.value.toString().toLowerCase() == 'true'),
          'json' => cp.value,
          'string' || _ => cp.value?.toString() ?? '',
        };
      }
    }

    return result;
  }

  /// Dispose permanently (no more streams possible after this)
  void dispose() {
    cancel();
  }
}
