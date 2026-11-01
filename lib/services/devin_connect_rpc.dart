import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// The pinned Devin executor accepts Connect envelopes around protobuf
/// GetChatMessageRequest messages. This codec intentionally supports the
/// conversational text/tool/image subset Stroom can represent.
class DevinConnectRpc {
  static Uint8List encodeChatRequest({
    required String sessionToken,
    required String modelId,
    required Map body,
  }) {
    final messages = body['messages'];
    if (messages is! Iterable) throw const FormatException('messages');
    final sessionId = _uuidLikeValue(
      body['conversation_id'] is String
          ? body['conversation_id'] as String
          : null,
    );
    String system = '';
    final prompts = <List<int>>[];
    for (final value in messages) {
      if (value is! Map) throw const FormatException('message');
      final role = value['role']?.toString() ?? 'user';
      final content = value['content'];
      if (role == 'system' || role == 'developer') {
        final parsedSystem = _parseContent(content);
        if (parsedSystem.images.isNotEmpty) {
          throw const FormatException(
            'Devin system prompt images are unsupported',
          );
        }
        system = '${system.isEmpty ? '' : '\n'}${parsedSystem.text}';
        continue;
      }
      final parsedContent = _parseContent(content);
      final prompt = <int>[];
      _bytes(prompt, 1, _utf8(_uuidLikeValue()));
      _varint(
        prompt,
        2,
        role == 'assistant'
            ? 2
            : role == 'tool'
                ? 4
                : 1,
      );
      _bytes(prompt, 3, _utf8(parsedContent.text));
      if (role != 'user' && parsedContent.images.isNotEmpty) {
        throw const FormatException(
          'images are supported for Devin user turns only',
        );
      }
      for (final image in parsedContent.images) {
        final encodedImage = <int>[];
        _bytes(encodedImage, 1, _utf8(image.$1));
        _bytes(encodedImage, 2, _utf8(image.$2));
        _bytes(prompt, 10, encodedImage);
      }
      final toolCalls = value['tool_calls'];
      if (toolCalls is Iterable) {
        for (final call in toolCalls) {
          if (call is! Map) continue;
          final fn = call['function'];
          if (fn is! Map) continue;
          final encoded = <int>[];
          final id = call['id']?.toString() ?? '';
          if (id.isNotEmpty) _bytes(encoded, 1, _utf8(id));
          _bytes(encoded, 2, _utf8(fn['name']?.toString() ?? ''));
          final args = fn['arguments'];
          _bytes(
            encoded,
            3,
            _utf8(args is String ? args : jsonEncode(args ?? {})),
          );
          _bytes(prompt, 6, encoded);
        }
      }
      final toolCallId = value['tool_call_id'];
      if (toolCallId is String && toolCallId.isNotEmpty) {
        _bytes(prompt, 7, _utf8(toolCallId));
      }
      prompts.add(prompt);
    }

    final metadata = <int>[];
    _bytes(metadata, 1, _utf8('chisel'));
    _bytes(metadata, 2, _utf8('3000.10.21'));
    _bytes(metadata, 3, _utf8(sessionToken));
    _bytes(metadata, 4, _utf8('en'));
    _bytes(metadata, 5, _utf8(_platformName));
    _bytes(metadata, 7, _utf8('3000.10.21'));
    _bytes(metadata, 12, _utf8('chisel'));
    final longFingerprint = List.generate(
      12,
      (index) => sha256.convert(_utf8('stroom-devin-device-$index')).toString(),
    ).join().substring(0, 732);
    _bytes(metadata, 31, _utf8(longFingerprint));

    final request = <int>[];
    _bytes(request, 1, metadata);
    if (system.isNotEmpty) _bytes(request, 2, _utf8(system));
    for (final prompt in prompts) {
      _bytes(request, 3, prompt);
    }
    _varint(request, 7, 5);
    final config = <int>[];
    _varint(config, 1, 1);
    final maxTokens =
        body['max_tokens'] ?? body['max_completion_tokens'] ?? 4096;
    _varint(
      config,
      2,
      maxTokens is num ? maxTokens.toInt().clamp(1, 128000).toInt() : 4096,
    );
    _varint(config, 3, 400);
    _fixed64(
      config,
      5,
      _doubleBits((body['temperature'] as num?)?.toDouble() ?? 1.0),
    );
    _varint(config, 7, 40);
    _fixed64(config, 8, _doubleBits(0.95));
    _bytes(request, 8, config);
    final tools = body['tools'];
    if (tools is Iterable) {
      for (final tool in tools) {
        if (tool is! Map) continue;
        final fn = tool['function'];
        if (fn is! Map) continue;
        final encoded = <int>[];
        _bytes(encoded, 1, _utf8(fn['name']?.toString() ?? ''));
        final desc = fn['description'];
        if (desc is String && desc.isNotEmpty) _bytes(encoded, 2, _utf8(desc));
        _bytes(encoded, 3, _utf8(jsonEncode(fn['parameters'] ?? const {})));
        _bytes(request, 10, encoded);
      }
    }
    final sessionMetadata = <int>[];
    _bytes(sessionMetadata, 1, _utf8(sessionId));
    _varint(sessionMetadata, 3, 4);
    final lastMessage = messages.isEmpty ? null : messages.last;
    if (lastMessage is Map && lastMessage['role'] == 'user') {
      _varint(sessionMetadata, 4, 14);
    }
    _bytes(request, 15, sessionMetadata);
    _bytes(request, 16, _utf8(sessionId));
    _varint(request, 20, 1);
    final upstreamModelId = modelId.toLowerCase().startsWith('devin/')
        ? modelId.substring(6)
        : modelId;
    final upstreamModel = _defaultModelUid(upstreamModelId);
    _bytes(request, 21, _utf8(upstreamModel));
    final framed = <int>[0];
    final length = request.length;
    framed.addAll([
      length >> 24 & 255,
      length >> 16 & 255,
      length >> 8 & 255,
      length & 255,
    ]);
    framed.addAll(request);
    return Uint8List.fromList(framed);
  }

  static Map<String, dynamic> decodeChatResponse(List<int> response) {
    var offset = 0;
    final text = StringBuffer();
    final toolCalls = <Map<String, dynamic>>[];
    int? promptTokens;
    int? completionTokens;
    var found = false;
    var trailerSeen = false;
    while (offset + 5 <= response.length) {
      if (trailerSeen) {
        throw const FormatException('Connect frame after trailer');
      }
      final flag = response[offset];
      final length = response[offset + 1] << 24 |
          response[offset + 2] << 16 |
          response[offset + 3] << 8 |
          response[offset + 4];
      offset += 5;
      if ((flag != 0 && flag != 2) ||
          length < 0 ||
          offset + length > response.length) {
        throw const FormatException('Connect frame');
      }
      found = true;
      if (flag == 2) {
        _validateTrailer(response.sublist(offset, offset + length));
        trailerSeen = true;
      } else {
        final payload = response.sublist(offset, offset + length);
        var pos = 0;
        while (pos < payload.length) {
          final tag = _readVarint(payload, pos);
          pos = tag.next;
          final field = tag.value >> 3;
          final wire = tag.value & 7;
          if (wire == 2) {
            final size = _readVarint(payload, pos);
            pos = size.next;
            final end = pos + size.value;
            if (end > payload.length) {
              throw const FormatException('protobuf length');
            }
            final bytes = payload.sublist(pos, end);
            if (field == 3) {
              text.write(utf8.decode(bytes, allowMalformed: true));
            }
            if (field == 6) {
              final toolCall = _parseToolCall(bytes);
              final existingIndex = toolCalls.indexWhere(
                (existing) => existing['id'] == toolCall['id'],
              );
              if (existingIndex < 0) {
                toolCalls.add(toolCall);
              } else {
                final existing = toolCalls[existingIndex];
                final existingFunction = existing['function'] as Map;
                final nextFunction = toolCall['function'] as Map;
                existingFunction['name'] = nextFunction['name'];
                existingFunction['arguments'] =
                    '${existingFunction['arguments']}${nextFunction['arguments']}';
              }
            }
            if (field == 7) {
              final usage = _parseUsage(bytes);
              promptTokens = usage.$1 ?? promptTokens;
              completionTokens = usage.$2 ?? completionTokens;
            }
            pos = end;
          } else if (wire == 0) {
            pos = _readVarint(payload, pos).next;
          } else if (wire == 1) {
            pos += 8;
          } else if (wire == 5) {
            pos += 4;
          } else {
            throw const FormatException('protobuf wire type');
          }
        }
      }
      offset += length;
    }
    if (!found ||
        !trailerSeen ||
        offset != response.length ||
        (text.length == 0 && toolCalls.isEmpty)) {
      throw const FormatException('empty Devin response');
    }
    return {
      'id': 'devin-${DateTime.now().millisecondsSinceEpoch}',
      'object': 'chat.completion',
      'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'model': 'devin',
      'choices': [
        {
          'index': 0,
          'message': {
            'role': 'assistant',
            'content': text.toString(),
            if (toolCalls.isNotEmpty) 'tool_calls': toolCalls,
          },
          'finish_reason': toolCalls.isEmpty ? 'stop' : 'tool_calls',
        },
      ],
      if (promptTokens != null || completionTokens != null)
        'usage': {
          'prompt_tokens': promptTokens ?? 0,
          'completion_tokens': completionTokens ?? 0,
          'total_tokens': (promptTokens ?? 0) + (completionTokens ?? 0),
        },
    };
  }

  static void _validateTrailer(List<int> payload) {
    final data = utf8.decode(payload, allowMalformed: false).trim();
    if (data.isEmpty) return;
    final decoded = jsonDecode(data);
    if (decoded is! Map) throw const FormatException('Connect trailer');
    final error = decoded['error'];
    if (error == null) return;
    if (error is! Map) throw const FormatException('Devin Connect-RPC error');
    final code = error['code'];
    final message = error['message'];
    if (code is String && code.isNotEmpty ||
        message is String && message.isNotEmpty) {
      throw const FormatException('Devin Connect-RPC error');
    }
  }

  static String _defaultModelUid(String modelId) =>
      switch (modelId.toLowerCase()) {
        'swe-2' => 'swe-2-high',
        'claude-fable-5-1' => 'claude-fable-5-1-medium',
        'gpt-6-astra' => 'gpt-6-astra-medium',
        'glm-5-2' || 'deepseek-v4-1-flash' => modelId.toLowerCase(),
        'glm-5-3' ||
        'glm-5-3-flash' ||
        'gemini-3-8-flash' ||
        'grok-4-6' ||
        'deepseek-v4-flash' =>
          '${modelId.toLowerCase()}-high',
        'gpt-5-6-sol' => 'gpt-5-6-sol-low',
        final value => value,
      };

  static _DevinContent _parseContent(Object? content) {
    if (content is String) return _DevinContent(content, const []);
    if (content is! Iterable) return const _DevinContent('', []);
    final result = StringBuffer();
    final images = <(String, String)>[];
    for (final part in content) {
      if (part is! Map) {
        throw const FormatException('unsupported Devin content part');
      }
      if (part['type'] == 'text' && part['text'] is String) {
        result.write(part['text']);
      } else if (part['type'] == 'image_url') {
        final imageUrl = part['image_url'];
        final url = imageUrl is Map ? imageUrl['url'] : imageUrl;
        if (url is! String || !url.startsWith('data:')) {
          throw const FormatException('Devin requires materialized image data');
        }
        final comma = url.indexOf(',');
        if (comma < 0 || !url.substring(0, comma).endsWith(';base64')) {
          throw const FormatException('unsupported Devin image encoding');
        }
        final mime = RegExp(
          r'^data:([^;]+);base64$',
        ).firstMatch(url.substring(0, comma))?.group(1);
        if (mime == null || !mime.startsWith('image/')) {
          throw const FormatException('unsupported Devin image type');
        }
        images.add((
          base64.encode(base64.decode(url.substring(comma + 1))),
          mime,
        ));
      } else {
        throw const FormatException('unsupported Devin content part');
      }
    }
    return _DevinContent(result.toString(), images);
  }

  static (int?, int?) _parseUsage(List<int> bytes) {
    int? input;
    int? output;
    var pos = 0;
    while (pos < bytes.length) {
      final tag = _readVarint(bytes, pos);
      pos = tag.next;
      final field = tag.value >> 3;
      final wire = tag.value & 7;
      if (wire == 0) {
        final value = _readVarint(bytes, pos);
        pos = value.next;
        if (field == 2) {
          input = value.value;
        }
        if (field == 3) {
          output = value.value;
        }
      } else if (wire == 2) {
        final size = _readVarint(bytes, pos);
        pos = size.next + size.value;
      } else if (wire == 1) {
        pos += 8;
      } else if (wire == 5) {
        pos += 4;
      } else {
        throw const FormatException('usage wire type');
      }
    }
    return (input, output);
  }

  static Map<String, dynamic> _parseToolCall(List<int> bytes) {
    String id = '';
    String name = '';
    final arguments = StringBuffer();
    var offset = 0;
    while (offset < bytes.length) {
      final tag = _readVarint(bytes, offset);
      offset = tag.next;
      if (tag.value & 7 != 2) {
        throw const FormatException('tool call wire type');
      }
      final size = _readVarint(bytes, offset);
      offset = size.next;
      final end = offset + size.value;
      if (end > bytes.length) throw const FormatException('tool call length');
      final value = utf8.decode(
        bytes.sublist(offset, end),
        allowMalformed: true,
      );
      switch (tag.value >> 3) {
        case 1:
          id = value;
        case 2:
          name = value;
        case 3:
          arguments.write(value);
      }
      offset = end;
    }
    return {
      'id': id,
      'type': 'function',
      'function': {'name': name, 'arguments': arguments.toString()},
    };
  }

  static void _bytes(List<int> out, int field, List<int> value) {
    _rawVarint(out, field << 3 | 2);
    _rawVarint(out, value.length);
    out.addAll(value);
  }

  static void _varint(List<int> out, int field, int value) {
    _rawVarint(out, field << 3);
    _rawVarint(out, value);
  }

  static void _fixed64(List<int> out, int field, int value) {
    _rawVarint(out, field << 3 | 1);
    for (var i = 0; i < 8; i++) {
      out.add(value >> (i * 8) & 255);
    }
  }

  static int _doubleBits(double value) {
    final data = ByteData(8)..setFloat64(0, value, Endian.little);
    return data.getUint64(0, Endian.little);
  }

  static Uint8List _utf8(String value) =>
      Uint8List.fromList(utf8.encode(value));
  static String get _platformName => switch (defaultTargetPlatform) {
        TargetPlatform.android => 'android',
        TargetPlatform.iOS => 'ios',
        TargetPlatform.macOS => 'darwin',
        TargetPlatform.windows => 'windows',
        TargetPlatform.linux => 'linux',
        TargetPlatform.fuchsia => 'fuchsia',
      };

  static ({int value, int next}) _readVarint(List<int> bytes, int offset) {
    var result = 0;
    var shift = 0;
    while (offset < bytes.length && shift < 64) {
      final byte = bytes[offset++];
      result |= (byte & 127) << shift;
      if (byte < 128) return (value: result, next: offset);
      shift += 7;
    }
    throw const FormatException('invalid protobuf varint');
  }

  static void _rawVarint(List<int> out, int value) {
    while (value >= 128) {
      out.add(value & 127 | 128);
      value >>= 7;
    }
    out.add(value);
  }

  static String _uuidLikeValue([String? seed]) {
    final bytes = seed == null
        ? List<int>.generate(16, (_) => Random.secure().nextInt(256))
        : List<int>.from(sha256.convert(_utf8(seed)).bytes.take(16));
    bytes[6] = bytes[6] & 0x0f | (seed == null ? 0x40 : 0x50);
    bytes[8] = bytes[8] & 0x3f | 0x80;
    return '${_hex(bytes, 0, 4)}-${_hex(bytes, 4, 2)}-${_hex(bytes, 6, 2)}-${_hex(bytes, 8, 2)}-${_hex(bytes, 10, 6)}';
  }

  static String _hex(List<int> bytes, int start, int count) => bytes
      .skip(start)
      .take(count)
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
}

class _DevinContent {
  final String text;
  final List<(String, String)> images;

  const _DevinContent(this.text, this.images);
}
