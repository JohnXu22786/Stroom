/// Source-backed request and stream translation for Naver CLOVA Studio v3.
///
/// CLOVA's v3 chat endpoint has its own camelCase wire format and named SSE
/// frames. This adapter intentionally supports text conversation and HCX-005
/// images only; unsupported message shapes fail rather than disappearing.
library;

import 'dart:convert';
import 'dart:io';

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
  static Future<Map<String, dynamic>> buildRequest(
    String modelId,
    Map<String, dynamic> body, {
    Future<List<InternetAddress>> Function(String host)? lookupHost,
  }) async {
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
    final resolveHost = lookupHost ?? InternetAddress.lookup;
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
      final content = await _contentParts(
        message['content'],
        imagesSupported: imagesSupported,
        lookupHost: resolveHost,
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

  static Future<List<Map<String, dynamic>>> _contentParts(
    Object? content, {
    required bool imagesSupported,
    required Future<List<InternetAddress>> Function(String host) lookupHost,
    required void Function() onImage,
  }) async {
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
      if (url.startsWith('data:')) {
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
      } else {
        final uri = Uri.tryParse(url);
        if (uri == null || !await _isPublicHttpsUri(uri, lookupHost)) {
          throw UnsupportedError('CLOVA only accepts public HTTPS image URLs.');
        }
        parts.add({
          'type': 'image_url',
          'imageUrl': {'url': url},
        });
      }
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

  static Future<bool> _isPublicHttpsUri(
    Uri uri,
    Future<List<InternetAddress>> Function(String host) lookupHost,
  ) async {
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443)) {
      return false;
    }
    final host = uri.host.toLowerCase();
    final address = InternetAddress.tryParse(host);
    if (address != null) return _isPublicIpAddress(address);
    if (RegExp(r'^[0-9.]+$').hasMatch(host) ||
        !host.contains('.') ||
        host.endsWith('.') ||
        const {
          'localhost',
          'local',
          'internal',
          'test',
          'invalid',
          'example',
        }.any((suffix) => host == suffix || host.endsWith('.$suffix'))) {
      return false;
    }
    try {
      final addresses = await lookupHost(host);
      return addresses.isNotEmpty && addresses.every(_isPublicIpAddress);
    } on SocketException {
      return false;
    }
  }

  static bool _isPublicIpAddress(InternetAddress address) {
    final bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      final a = bytes[0];
      final b = bytes[1];
      final c = bytes[2];
      return !(a == 0 ||
          a == 10 ||
          a == 127 ||
          (a == 100 && b >= 64 && b <= 127) ||
          (a == 169 && b == 254) ||
          (a == 172 && b >= 16 && b <= 31) ||
          (a == 192 && (b == 168 || b == 0 && (c == 0 || c == 2))) ||
          (a == 192 && b == 88 && c == 99) ||
          (a == 198 && (b == 18 || b == 19 || b == 51 && c == 100)) ||
          (a == 203 && b == 0 && c == 113) ||
          a >= 224);
    }
    final isIpv4Mapped =
        bytes.take(10).every((byte) => byte == 0) &&
        bytes[10] == 255 &&
        bytes[11] == 255;
    if (isIpv4Mapped) {
      return _isPublicIpAddress(
        InternetAddress.fromRawAddress(bytes.sublist(12)),
      );
    }
    final isIpv4Compatible = bytes.take(12).every((byte) => byte == 0);
    final isGlobalUnicast = (bytes[0] & 0xe0) == 0x20;
    final isIetfProtocolAssignment =
        bytes[0] == 0x20 && bytes[1] == 0x01 && (bytes[2] & 0xfe) == 0;
    final isSixToFour = bytes[0] == 0x20 && bytes[1] == 0x02;
    final isDocumentation =
        bytes[0] == 0x3f && bytes[1] == 0xff && (bytes[2] & 0xf0) == 0;
    return isGlobalUnicast &&
        !(isIpv4Compatible ||
            isIetfProtocolAssignment ||
            isSixToFour ||
            isDocumentation ||
            bytes.take(15).every((byte) => byte == 0) && bytes[15] == 1 ||
            (bytes[0] & 0xfe) == 0xfc ||
            (bytes[0] == 0xfe && (bytes[1] & 0xc0) >= 0x80) ||
            (bytes[0] == 0x20 &&
                bytes[1] == 0x01 &&
                bytes[2] == 0x0d &&
                bytes[3] == 0xb8) ||
            bytes[0] == 0xff);
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
    final usage = result['usage'];
    final normalizedUsage = usage is Map
        ? <String, dynamic>{
            if (usage['promptTokens'] is num)
              'input_tokens': usage['promptTokens'],
            if (usage['completionTokens'] is num)
              'output_tokens': usage['completionTokens'],
            if (usage['totalTokens'] is num)
              'total_tokens': usage['totalTokens'],
          }
        : null;
    final finish = result['finishReason'];
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
