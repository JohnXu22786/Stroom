/// Source-backed request and stream translation for Naver CLOVA Studio v3.
///
/// CLOVA's v3 chat endpoint has its own camelCase wire format and named SSE
/// frames. This adapter intentionally supports text conversation and HCX-005
/// images only; unsupported message shapes fail rather than disappearing.
library;

import 'dart:convert';

const String kClovaStudioProtocolId = 'clova.studio.chat';
const String kClovaStudioBaseUrl =
    'https://clovastudio.stream.ntruss.com/v3/chat-completions';

const List<String> kClovaStudioModelIds = [
  'HCX-007',
  'HCX-005',
  'HCX-DASH-002',
];

class ClovaStudioProtocol {
  static String encodeModelPathSegment(String modelId) =>
      Uri.encodeComponent(modelId);

  static Uri requestUri(
    String modelId, {
    String baseUrl = kClovaStudioBaseUrl,
  }) {
    if (!kClovaStudioModelIds.contains(modelId)) {
      throw ArgumentError.value(modelId, 'modelId');
    }
    final base = Uri.tryParse(baseUrl);
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw ArgumentError.value(baseUrl, 'baseUrl');
    }
    final root = base.toString().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$root/${encodeModelPathSegment(modelId)}');
  }

  /// Converts the application's Chat Completions-shaped neutral request into
  /// CLOVA v3's native camelCase request body.
  static Map<String, dynamic> buildRequest(
    String modelId,
    Map<String, dynamic> body,
  ) {
    if (!kClovaStudioModelIds.contains(modelId)) {
      throw ArgumentError.value(modelId, 'modelId');
    }
    if (body['tools'] is List && (body['tools'] as List).isNotEmpty ||
        body['tool_choice'] != null) {
      throw UnsupportedError('CLOVA tool requests are not supported here.');
    }
    final rawMessages = body['messages'];
    if (rawMessages is! List || rawMessages.isEmpty) {
      throw ArgumentError.value(rawMessages, 'messages');
    }
    final system = body['system'];
    final hasSystemMessage =
        system is String &&
        rawMessages.whereType<Map>().any((message) {
          if (message['role'] != 'system') return false;
          final content = message['content'];
          if (content is String) return content == system;
          return content is List &&
              content
                      .whereType<Map>()
                      .map((part) => part['text'])
                      .whereType<String>()
                      .join('\n') ==
                  system;
        });
    final sourceMessages = <Object?>[
      if (system is String && system.isNotEmpty && !hasSystemMessage)
        {'role': 'system', 'content': system},
      ...rawMessages,
    ];
    final imagesSupported = modelId == 'HCX-005';
    var imageCount = 0;
    final messages = <Map<String, dynamic>>[];
    for (final raw in sourceMessages) {
      if (raw is! Map) {
        throw UnsupportedError('CLOVA messages must be objects.');
      }
      final message = Map<String, dynamic>.from(raw);
      final role = message['role'];
      if (role is! String ||
          !const {'system', 'user', 'assistant'}.contains(role) ||
          message['tool_calls'] != null ||
          message['function_call'] != null) {
        throw UnsupportedError(
          'CLOVA message role or tool shape is unsupported.',
        );
      }
      final content = _contentParts(
        message['content'],
        imagesSupported: imagesSupported,
        onImage: () => imageCount++,
      );
      if (imageCount > 5 ||
          content.where((part) => part['type'] == 'image_url').length > 1) {
        throw UnsupportedError(
          'CLOVA accepts at most five images, one per turn.',
        );
      }
      messages.add({'role': role, 'content': content});
    }

    final request = <String, dynamic>{'messages': messages, 'stream': true};
    final reasoning = modelId == 'HCX-007';
    if (reasoning) {
      request['thinking'] = {
        'effort': _thinkingEffort(body['reasoning_effort']) ?? 'low',
      };
    }
    final maxTokens = body['max_completion_tokens'] ?? body['max_tokens'];
    if (maxTokens is num && maxTokens.isFinite) {
      final cap = modelId == 'HCX-007' ? 32768 : 4096;
      request[modelId == 'HCX-007' ? 'maxCompletionTokens' : 'maxTokens'] =
          maxTokens.toInt().clamp(1, cap);
    }
    final temperature = body['temperature'];
    if (temperature is num && temperature.isFinite) {
      request['temperature'] = temperature.clamp(0, 1);
    }
    final topP = body['top_p'];
    if (topP is num && topP.isFinite && topP > 0) {
      request['topP'] = topP.clamp(0, 1);
    }
    final stop = body['stop'];
    if (modelId != 'HCX-007' || !reasoning) {
      if (stop is String && stop.isNotEmpty) {
        request['stop'] = [stop];
      } else if (stop is List && stop.isNotEmpty) {
        request['stop'] = stop.whereType<String>().toList();
      }
    }
    return request;
  }

  static List<Map<String, dynamic>> _contentParts(
    Object? content, {
    required bool imagesSupported,
    required void Function() onImage,
  }) {
    if (content is String) {
      return [
        {'type': 'text', 'text': content},
      ];
    }
    if (content is! List) {
      throw UnsupportedError(
        'CLOVA message content must be text or typed parts.',
      );
    }
    final parts = <Map<String, dynamic>>[];
    for (final rawPart in content) {
      if (rawPart is! Map) {
        throw UnsupportedError('CLOVA content parts must be objects.');
      }
      final part = Map<String, dynamic>.from(rawPart);
      if (part['type'] == 'text' && part['text'] is String) {
        parts.add({'type': 'text', 'text': part['text']});
        continue;
      }
      if (part['type'] != 'image_url' || !imagesSupported) {
        throw UnsupportedError('CLOVA content part is unsupported.');
      }
      final image = part['image_url'];
      final url = image is Map ? image['url'] : null;
      if (url is! String || url.isEmpty) {
        throw UnsupportedError('CLOVA image URL is invalid.');
      }
      onImage();
      if (!url.startsWith('data:')) {
        throw UnsupportedError(
          'CLOVA image URLs must be inline base64 data URIs; remote image URLs are not supported.',
        );
      }
      if (!RegExp(
        r'^data:image/[a-z0-9.+-]+;base64,[A-Za-z0-9+/]*={0,2}$',
        caseSensitive: false,
      ).hasMatch(url)) {
        throw UnsupportedError('CLOVA image data URI is invalid.');
      }
      parts.add({
        'type': 'image_url',
        'dataUri': {'data': url},
      });
    }
    return parts.isEmpty
        ? [
            {'type': 'text', 'text': ''},
          ]
        : parts;
  }

  static String? _thinkingEffort(Object? raw) {
    if (raw is! String) return null;
    final value = raw.toLowerCase();
    if (value == 'minimal') return 'low';
    return const {'none', 'low', 'medium', 'high'}.contains(value)
        ? value
        : null;
  }
}

class ClovaStudioStreamEvent {
  final String? textDelta;
  final String? reasoningDelta;
  final Map<String, dynamic>? usage;
  final String? finishReason;
  final bool done;

  const ClovaStudioStreamEvent({
    this.textDelta,
    this.reasoningDelta,
    this.usage,
    this.finishReason,
    this.done = false,
  });
}

class ClovaStudioUpstreamException implements Exception {
  final String code;
  final String message;

  const ClovaStudioUpstreamException(this.code, this.message);

  @override
  String toString() => 'CLOVA Studio error $code: $message';
}

/// Accumulates named v3 SSE frames. The terminal result repeats the complete
/// answer, so it is emitted only when no token frame carried text.
class ClovaStudioSseAccumulator {
  String _text = '';
  String _reasoning = '';
  bool _done = false;

  String get text => _text;
  String get reasoning => _reasoning;

  ClovaStudioStreamEvent addFrame(String frame) {
    if (_done) return const ClovaStudioStreamEvent();
    String eventType = '';
    final dataLines = <String>[];
    for (final line in const LineSplitter().convert(frame)) {
      if (line.startsWith('event:')) eventType = line.substring(6).trim();
      if (line.startsWith('data:')) dataLines.add(line.substring(5).trim());
    }
    if (dataLines.isEmpty) return const ClovaStudioStreamEvent();
    final decoded = jsonDecode(dataLines.join('\n'));
    if (decoded is! Map) {
      throw const FormatException('Invalid CLOVA Studio SSE data.');
    }
    final data = Map<String, dynamic>.from(decoded);
    final status = data['status'];
    if (status is Map &&
        status['code'] != null &&
        status['code'].toString() != '20000') {
      throw ClovaStudioUpstreamException(
        status['code'].toString(),
        status['message'] is String
            ? status['message'] as String
            : 'Request failed',
      );
    }
    if (eventType == 'error' || data['error'] is Map) {
      final error = data['error'] is Map ? data['error'] as Map : data;
      final code = error['code'] ?? (status is Map ? status['code'] : null);
      final message =
          error['message'] ?? (status is Map ? status['message'] : null);
      throw ClovaStudioUpstreamException(
        code?.toString() ?? 'unknown',
        message is String ? message : 'Request failed',
      );
    }
    if (eventType == 'token') {
      final message = data['message'] is Map ? data['message'] as Map : data;
      final thinking = message['thinkingContent'] ?? data['thinkingContent'];
      final content = message['content'] ?? data['content'];
      final reasoningDelta = thinking is String ? thinking : null;
      final textDelta = content is String ? content : null;
      if (reasoningDelta != null) _reasoning += reasoningDelta;
      if (textDelta != null) _text += textDelta;
      return ClovaStudioStreamEvent(
        textDelta: textDelta,
        reasoningDelta: reasoningDelta,
      );
    }
    if (eventType != 'result' && eventType != 'stop') {
      return const ClovaStudioStreamEvent();
    }
    final result = data['result'] is Map ? data['result'] as Map : data;
    final message = result['message'] is Map
        ? result['message'] as Map
        : const {};
    final snapshot = message['content'] ?? result['content'];
    final terminalText = _text.isEmpty && snapshot is String ? snapshot : null;
    if (terminalText != null) _text = terminalText;
    final snapshotReasoning =
        message['thinkingContent'] ?? result['thinkingContent'];
    final terminalReasoning = _reasoning.isEmpty && snapshotReasoning is String
        ? snapshotReasoning
        : null;
    if (terminalReasoning != null) _reasoning = terminalReasoning;
    final usage = result['usage'] is Map ? result['usage'] as Map : const {};
    final inputTokens = usage['promptTokens'] ?? result['inputLength'];
    final outputTokens = usage['completionTokens'] ?? result['outputLength'];
    final totalTokens =
        usage['totalTokens'] ??
        (inputTokens is num && outputTokens is num
            ? inputTokens + outputTokens
            : null);
    final normalizedUsage = inputTokens is num || outputTokens is num
        ? <String, dynamic>{
            if (inputTokens is num) 'input_tokens': inputTokens,
            if (outputTokens is num) 'output_tokens': outputTokens,
            if (totalTokens is num) 'total_tokens': totalTokens,
          }
        : null;
    final finish = result['stopReason'] ?? result['finishReason'];
    _done = true;
    return ClovaStudioStreamEvent(
      textDelta: terminalText,
      reasoningDelta: terminalReasoning,
      usage: normalizedUsage,
      finishReason: finish is String ? finish : 'stop',
      done: true,
    );
  }
}
