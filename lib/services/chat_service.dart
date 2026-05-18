import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../models/chat_message.dart';
import '../providers/chat_api_provider.dart';
import '../providers/provider_config.dart';
import 'attachment_storage.dart';

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
  CancelToken? _cancelToken;
  StreamSubscription<String>? _streamSubscription;
  StreamController<String>? _controller;

  /// Construct an instance backed by a real provider and model config.
  ChatService({
    required BaseChatProvider provider,
    required ModelConfig modelConfig,
  })  : _provider = provider,
        _modelConfig = modelConfig;

  /// Whether there's an active streaming session (instance or static).
  bool get isStreamActive => _controller != null && !_controller!.isClosed;

  // ── Instance methods ────────────────────────────────────────────

  /// Stream a message — converts [history] (which already contains the latest
  /// user message with attachments) into API‑format messages and streams the
  /// reply.
  ///
  /// [history] must already include the latest user message (added by the
  /// caller before calling this method). Attachments are converted to the
  /// OpenAI multimodal content‑array format (base64 inline images).
  Stream<String> sendStream(String userMessage,
      {required List<ChatMessage> history}) {
    cancel();

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
    _cancelToken = CancelToken();

    // Pre‑process messages in a microtask so the stream is returned
    // immediately (caller can listen right away).
    Future.microtask(() async {
      try {
        final apiMessages = await _prepareApiMessages(history);
        _streamSubscription = _provider!
            .chatStream(
          apiMessages,
          model: _modelConfig!.modelId,
          maxTokens: (_modelConfig!.typeConfig['maxTokens'] as num?)
                  ?.toInt() ??
              4096,
          temperature: (_modelConfig!.typeConfig['temperature'] as num?)
                  ?.toDouble() ??
              0.7,
          extraParams: extraParams,
          cancelToken: _cancelToken,
        )
            .listen(
          (chunk) {
            if (!_controller!.isClosed) _controller!.add(chunk);
          },
          onDone: () {
            _streamSubscription = null;
            if (!_controller!.isClosed) _controller!.close();
            _cleanUp();
          },
          onError: (Object error) {
            _streamSubscription = null;
            debugPrint('ChatService stream error: $error');
            if (!_controller!.isClosed) {
              _controller!.addError(error);
              _controller!.close();
            }
            _cleanUp();
          },
        );
      } catch (e) {
        if (!_controller!.isClosed) {
          _controller!.addError(e);
          _controller!.close();
        }
      }
    });

    return _controller!.stream;
  }

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
              final b64 = base64Encode(bytes);
              final ext = _imageExtension(att.mimeType);
              parts.add({
                'type': 'image_url',
                'image_url': {'url': 'data:image/$ext;base64,$b64'},
              });
            }
          } else {
            // Non‑image files: include as text description
            parts.add({
              'type': 'text',
              'text': '[Attached file: ${att.fileName}]',
            });
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
      {required List<ChatMessage> history}) async {
    final chunks = <String>[];
    await for (final chunk in sendStream(userMessage, history: history)) {
      chunks.add(chunk);
    }
    return chunks.join('');
  }

  /// Cancel the current stream
  void cancel() {
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

  // ── Extra params helpers ─────────────────────────────────────────

  /// Build extraParams map from customParams for the API call.
  Map<String, dynamic> _buildExtraParams() {
    final params = _modelConfig!.customParams;
    if (params.isEmpty) return {};

    return {
      for (final cp in params)
        cp.paramName: switch (cp.type) {
          'number' => double.tryParse(cp.defaultValue) ?? 0.0,
          'boolean' => cp.defaultValue.toLowerCase() == 'true',
          'string' || _ => cp.defaultValue,
        },
    };
  }

  /// Dispose permanently (no more streams possible after this)
  void dispose() {
    cancel();
  }
}
