import 'dart:async';
import 'dart:convert';

const String kOneMinAiProtocolId = 'oneminai.chat';
const String kOneMinAiChatUrl = 'https://api.1min.ai/api/chat-with-ai';
const String kOneMinAiFallbackModelId = 'gpt-4o-mini';

/// Request and response conversion for 1min.AI's source-backed chat endpoint.
///
/// This is a provider-native API, despite the OpenAI-shaped Gateway input.
/// The upstream accepts one text prompt, not a messages array.
abstract final class OneMinAiProtocol {
  static Uri requestUri({required bool stream}) => Uri.parse(kOneMinAiChatUrl)
      .replace(queryParameters: stream ? const {'isStreaming': 'true'} : null);

  static Map<String, String> buildHeaders(String apiKey) => {
        'Content-Type': 'application/json',
        'API-KEY': apiKey,
      };

  static Map<String, dynamic> buildRequest(
    String modelId,
    Map<String, dynamic> body,
  ) {
    if (modelId.trim().isEmpty) {
      throw const FormatException('1min.AI requires a model ID.');
    }
    final unsupportedKeys = const {
      'tools',
      'tool_choice',
      'functions',
      'function_call',
      'response_format',
      'reasoning_effort',
      'max_tokens',
      'max_completion_tokens',
      'temperature',
      'top_p',
      'stop',
      'seed',
    };
    if (unsupportedKeys.any((key) => body[key] != null)) {
      throw UnsupportedError(
        '1min.AI chat supports text prompts without tools or generation options.',
      );
    }
    final rawMessages = body['messages'];
    if (rawMessages is! List || rawMessages.isEmpty) {
      throw const FormatException('1min.AI requires chat messages.');
    }
    final messages = <Map<String, dynamic>>[];
    for (final raw in rawMessages) {
      if (raw is! Map) {
        throw UnsupportedError('1min.AI messages must be objects.');
      }
      final message = Map<String, dynamic>.from(raw);
      if (message['tool_calls'] != null || message['function_call'] != null) {
        throw UnsupportedError('1min.AI does not support tool calls.');
      }
      final role = message['role'];
      if (role is! String ||
          !const {'system', 'developer', 'user', 'assistant'}.contains(role)) {
        throw UnsupportedError('1min.AI supports text chat roles only.');
      }
      messages.add({'role': role, 'content': _textContent(message['content'])});
    }

    final topLevelSystem = body['system'];
    if (topLevelSystem != null) {
      if (topLevelSystem is! String) {
        throw UnsupportedError('1min.AI system prompts must be text.');
      }
      if (topLevelSystem.isNotEmpty &&
          !messages.any(
            (message) =>
                message['role'] == 'system' &&
                message['content'] == topLevelSystem,
          )) {
        messages.insert(0, {'role': 'system', 'content': topLevelSystem});
      }
    }

    return {
      'type': 'UNIFY_CHAT_WITH_AI',
      'model': modelId,
      'promptObject': {'prompt': buildPrompt(messages)},
    };
  }

  static String buildPrompt(List<Map<String, dynamic>> messages) {
    if (messages.length == 1 && messages.single['role'] == 'user') {
      return _textContent(messages.single['content']);
    }
    const labels = {
      'system': 'System',
      'developer': 'System',
      'user': 'User',
      'assistant': 'Assistant',
    };
    return messages.map((message) {
      final role = message['role'] as String;
      return '${labels[role] ?? role}: ${_textContent(message['content'])}';
    }).join('\n\n');
  }

  static String parseCompletion(Object? value) {
    if (value is! Map) {
      throw const FormatException('1min.AI returned an invalid completion.');
    }
    final aiRecord = value['aiRecord'];
    final detail = aiRecord is Map ? aiRecord['aiRecordDetail'] : null;
    final result = detail is Map ? detail['resultObject'] : null;
    if (result is String) return result;
    if (result is List) {
      return result.whereType<String>().join();
    }
    throw const FormatException('1min.AI returned an invalid completion.');
  }

  static Map<String, dynamic> toChatCompletion(
    Object? value, {
    required String modelId,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return {
      'id': 'oneminai-$now',
      'object': 'chat.completion',
      'created': now,
      'model': modelId,
      'choices': [
        {
          'index': 0,
          'message': {'role': 'assistant', 'content': parseCompletion(value)},
          'finish_reason': 'stop',
        },
      ],
    };
  }

  static Stream<List<int>> translateSse(
    Stream<List<int>> source, {
    required String modelId,
  }) {
    final parser = OneMinAiSseAccumulator();
    final encoder = utf8.encoder;
    var roleSent = false;
    var finished = false;
    final id = 'chatcmpl-oneminai-${DateTime.now().millisecondsSinceEpoch}';
    final created = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    late final StreamController<List<int>> output;
    StreamSubscription<String>? upstream;

    String frame(Map<String, dynamic> payload) =>
        'data: ${jsonEncode(payload)}\n\n';
    void add(String value) => output.add(encoder.convert(value));

    void finish() {
      if (finished) return;
      finished = true;
      add(frame({
        'id': id,
        'object': 'chat.completion.chunk',
        'created': created,
        'model': modelId,
        'choices': [
          {'index': 0, 'delta': {}, 'finish_reason': 'stop'},
        ],
      }));
      add('data: [DONE]\n\n');
      output.close();
      unawaited(upstream?.cancel());
    }

    void process(Iterable<OneMinAiStreamEvent> events) {
      for (final event in events) {
        if (event.errorMessage != null) {
          finished = true;
          output.addError(const OneMinAiUpstreamException());
          output.close();
          unawaited(upstream?.cancel());
          return;
        }
        if (event.textDelta != null && event.textDelta!.isNotEmpty) {
          if (!roleSent) {
            roleSent = true;
            add(frame({
              'id': id,
              'object': 'chat.completion.chunk',
              'created': created,
              'model': modelId,
              'choices': [
                {
                  'index': 0,
                  'delta': {'role': 'assistant'},
                  'finish_reason': null,
                },
              ],
            }));
          }
          add(frame({
            'id': id,
            'object': 'chat.completion.chunk',
            'created': created,
            'model': modelId,
            'choices': [
              {
                'index': 0,
                'delta': {'content': event.textDelta},
                'finish_reason': null,
              },
            ],
          }));
        }
        if (event.done) {
          finish();
          return;
        }
      }
    }

    output = StreamController<List<int>>(
      onListen: () {
        upstream = source.cast<List<int>>().transform(utf8.decoder).listen(
          (chunk) => process(parser.addChunk(chunk)),
          onError: (Object error, StackTrace stack) {
            if (finished) return;
            finished = true;
            output.addError(error, stack);
            output.close();
          },
          onDone: () {
            if (finished) return;
            process(parser.close());
            if (!finished) finish();
          },
          cancelOnError: true,
        );
      },
      onCancel: () async {
        finished = true;
        await upstream?.cancel();
      },
    );
    return output.stream;
  }

  static String _textContent(Object? value) {
    if (value is String) return value;
    if (value is! List) {
      throw UnsupportedError('1min.AI supports text message content only.');
    }
    final parts = <String>[];
    for (final raw in value) {
      if (raw is! Map || raw['type'] != 'text' || raw['text'] is! String) {
        throw UnsupportedError('1min.AI supports text message content only.');
      }
      parts.add(raw['text'] as String);
    }
    return parts.join('\n');
  }
}

class OneMinAiUpstreamException implements Exception {
  const OneMinAiUpstreamException();

  @override
  String toString() => '1min.AI request failed.';
}

class OneMinAiStreamEvent {
  final String? textDelta;
  final bool done;
  final String? errorMessage;

  const OneMinAiStreamEvent({
    this.textDelta,
    this.done = false,
    this.errorMessage,
  });
}

/// Incremental parser for 1min.AI's named, event-framed SSE response.
class OneMinAiSseAccumulator {
  String _buffer = '';
  bool _done = false;
  bool _pendingCarriageReturn = false;

  bool get done => _done;

  List<OneMinAiStreamEvent> addChunk(String chunk) {
    if (_done) return const [];
    _buffer += _normalizeLineEndings(chunk);
    return _drainFrames();
  }

  String _normalizeLineEndings(String chunk, {bool flush = false}) {
    final normalized = StringBuffer();
    var index = 0;
    if (_pendingCarriageReturn) {
      normalized.write('\n');
      if (chunk.startsWith('\n')) index = 1;
      _pendingCarriageReturn = false;
    }
    while (index < chunk.length) {
      final character = chunk[index];
      if (character == '\r') {
        if (index + 1 == chunk.length) {
          _pendingCarriageReturn = true;
        } else {
          if (chunk[index + 1] == '\n') index++;
          normalized.write('\n');
        }
      } else {
        normalized.write(character);
      }
      index++;
    }
    if (flush && _pendingCarriageReturn) {
      normalized.write('\n');
      _pendingCarriageReturn = false;
    }
    return normalized.toString();
  }

  List<OneMinAiStreamEvent> _drainFrames() {
    final events = <OneMinAiStreamEvent>[];
    var separator = _buffer.indexOf('\n\n');
    while (separator >= 0 && !_done) {
      final frame = _buffer.substring(0, separator);
      _buffer = _buffer.substring(separator + 2);
      final event = _parseFrame(frame);
      if (event != null) events.add(event);
      separator = _buffer.indexOf('\n\n');
    }
    return events;
  }

  /// Flushes a final event when a server closes without a trailing blank line.
  List<OneMinAiStreamEvent> close() {
    if (_done) return const [];
    _buffer += _normalizeLineEndings('', flush: true);
    final events = _drainFrames();
    if (_done) return events;
    final tail = _buffer;
    _buffer = '';
    if (tail.trim().isEmpty) return events;
    final event = _parseFrame(tail);
    if (event != null) events.add(event);
    return events;
  }

  OneMinAiStreamEvent? _parseFrame(String frame) {
    var type = 'message';
    final data = <String>[];
    for (final line in frame.split('\n')) {
      if (line.startsWith('event:')) {
        type = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        data.add(line.substring(5).trimLeft());
      }
    }
    final payload = data.join('\n');
    if (type == 'done') {
      _done = true;
      return const OneMinAiStreamEvent(done: true);
    }
    if (type == 'error') {
      _done = true;
      return const OneMinAiStreamEvent(errorMessage: '1min.AI request failed.');
    }
    if (type != 'content') return null; // `result` duplicates content events.
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map && decoded['content'] is String) {
        return OneMinAiStreamEvent(textDelta: decoded['content'] as String);
      }
    } on FormatException {
      // Ignore incomplete or malformed content data rather than emit partial text.
    }
    return null;
  }
}
