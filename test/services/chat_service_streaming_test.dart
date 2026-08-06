// Merged from: chat_service_reasoning_test.dart,
// chat_service_reasoning_parse_test.dart,
// chat_service_parse_value_test.dart,
// chat_service_builtin_tools_test.dart,
// chat_service_attachment_content_test.dart,
// chat_service_audio_video_attachment_test.dart,
// chat_service_base64_cache_test.dart
//
// No naming conflicts between sources for this file.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:stroom/models/ai_stream_event.dart';
import 'package:stroom/models/chat_event.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/providers/chat_api_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/chat_service.dart';
import 'package:stroom/services/chat_service_shared.dart';
import 'package:stroom/models/tool_call.dart';
part 'chat_service_streaming_test_p1.dart';
part 'chat_service_streaming_test_p2.dart';
part 'chat_service_streaming_test_p3.dart';
part 'chat_service_streaming_test_p4.dart';

/// Creates a mock provider that captures the request body for inspection.
/// (Originally from chat_service_reasoning_test.dart)
class CapturingChatProvider extends BaseChatProvider {
  Map<String, dynamic>? capturedBody;
  bool throwError = false;

  @override
  String get name => 'CapturingProvider';

  @override
  List<String> get supportedModelIds => ['test-model'];

  @override
  Map<String, dynamic> get defaultParams => {
        'model': 'test-model',
        'max_tokens': 4096,
        'temperature': 0.7,
      };

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
    throw UnimplementedError();
  }

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
    if (throwError) {
      throw Exception('Simulated error');
    }
    capturedBody = {
      'model': model,
      'messages': messages,
      'max_tokens': maxTokens,
      'temperature': temperature,
      'reasoning': reasoning,
      'reasoningEffort': reasoningEffort,
      'tools': tools,
      'extraParams': extraParams,
    };
    // Yield a minimal event so the stream doesn't hang
    yield AIStreamEvent('');
  }
}

/// Mock provider that captures the messages sent to the API.
/// (Originally from chat_service_attachment_content_test.dart)
class _MessageCaptureProvider extends BaseChatProvider {
  /// Captures the messages from the last chatStream call.
  List<Map<String, dynamic>>? lastMessages;

  /// Completer to signal that the provider has received a chatStream call.
  final _streamCompleter = Completer<void>();

  @override
  String get name => 'MessageCapture';

  @override
  List<String> get supportedModelIds => [];

  @override
  Map<String, dynamic> get defaultParams => {
        'model': 'test',
        'max_tokens': 4096,
        'temperature': 0.7,
      };

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
    throw UnimplementedError();
  }

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
    lastMessages = messages;
    if (!_streamCompleter.isCompleted) {
      _streamCompleter.complete();
    }
    yield AIStreamEvent('');
  }

  Future<void> waitForCall({Duration timeout = const Duration(seconds: 5)}) =>
      _streamCompleter.future.timeout(
        timeout,
        onTimeout: () => fail('chatStream was never called within $timeout'),
      );
}

/// A provider whose chatStream never ends on its own (no events, no done).
/// Only ends when cancelToken fires — at which point it calls
/// controller.close(). This simulates a slow/streaming API call.
class _StallingChatProvider extends BaseChatProvider {
  StreamController<AIStreamEvent>? _controller;

  @override
  String get name => 'StallingProvider';

  @override
  List<String> get supportedModelIds => ['test-model'];

  @override
  Map<String, dynamic> get defaultParams => {
        'model': 'test-model',
        'max_tokens': 4096,
        'temperature': 0.7,
      };

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
    throw UnimplementedError();
  }

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
    _controller = StreamController<AIStreamEvent>();
    cancelToken?.whenCancel.then((_) {
      if (!_controller!.isClosed) _controller!.close();
    });
    await for (final event in _controller!.stream) {
      yield event;
    }
  }

  Future<void> closeController() async {
    if (_controller != null && !_controller!.isClosed) {
      _controller!.close();
    }
  }
}

/// Top-level helper that mirrors the production `imageExtension` helper but
/// stays private to this test file. The merged file imports the public
/// `imageExtension` from `chat_service_shared.dart`, so this private function
/// is renamed to avoid confusion. (Originally from chat_service_base64_cache_test.dart)
String _privateImageExtension(String mimeType) {
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

void main() {
  chatServiceStreamingGroup1();
  chatServiceStreamingGroup2();
  chatServiceStreamingGroup3();
  chatServiceStreamingGroup4();
}
