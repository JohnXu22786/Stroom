import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// Decodes the AWS EventStream frames returned by Bedrock ConverseStream and
/// emits incremental OpenAI Chat Completions SSE frames for ChatAdapter.
abstract final class AwsBedrockEventStreamAdapter {
  static Stream<List<int>> toOpenAiSse(Stream<List<int>> source) async* {
    final pending = <int>[];
    final toolIndices = <int, int>{};
    var nextToolIndex = 0;
    var finishReason = 'stop';
    var receivedMessageStop = false;
    await for (final chunk in source) {
      pending.addAll(chunk);
      while (pending.length >= 12) {
        final data = Uint8List.fromList(pending);
        final view = ByteData.sublistView(data);
        final totalLength = view.getUint32(0, Endian.big);
        final headersLength = view.getUint32(4, Endian.big);
        if (totalLength < 16 || headersLength > totalLength - 16) {
          throw const FormatException('Invalid Bedrock EventStream frame.');
        }
        if (pending.length < totalLength) break;
        final frame = Uint8List.fromList(pending.take(totalLength).toList());
        pending.removeRange(0, totalLength);
        _validateFrame(frame, headersLength);
        final headers = _readHeaders(frame, headersLength);
        final eventType = headers[':event-type'];
        final payloadBytes = frame.sublist(12 + headersLength, totalLength - 4);
        final decoded = jsonDecode(utf8.decode(payloadBytes));
        if (decoded is! Map) {
          throw const FormatException('Invalid Bedrock event payload.');
        }
        final payload = Map<String, dynamic>.from(decoded);
        final event = eventType is String
            ? eventType
            : payload.isEmpty
                ? null
                : payload.keys.first;
        if (event == null) {
          throw const FormatException('Bedrock event has no type.');
        }
        if (event.toLowerCase().contains('exception')) {
          throw const FormatException(
            'Bedrock stream returned an error event.',
          );
        }
        final eventValue = payload[event];
        final valueSource = eventValue is Map ? eventValue : payload;
        final value = Map<String, dynamic>.from(valueSource);
        if (event == 'contentBlockStart') {
          final index = _int(value['contentBlockIndex']);
          final start = value['start'];
          final toolUse = start is Map ? start['toolUse'] : null;
          if (index == null || toolUse is! Map) continue;
          final id = toolUse['toolUseId'];
          final name = toolUse['name'];
          if (id is! String || name is! String) {
            throw const FormatException('Bedrock tool event is invalid.');
          }
          final toolIndex = nextToolIndex++;
          toolIndices[index] = toolIndex;
          yield _frame({
            'id': 'bedrock-stream',
            'object': 'chat.completion.chunk',
            'choices': [
              {
                'index': 0,
                'delta': {
                  'tool_calls': [
                    {
                      'index': toolIndex,
                      'id': id,
                      'type': 'function',
                      'function': {'name': name, 'arguments': ''},
                    },
                  ],
                },
                'finish_reason': null,
              },
            ],
          });
        } else if (event == 'contentBlockDelta') {
          final index = _int(value['contentBlockIndex']);
          final delta = value['delta'];
          if (delta is! Map) continue;
          if (delta['text'] is String) {
            yield _frame({
              'id': 'bedrock-stream',
              'object': 'chat.completion.chunk',
              'choices': [
                {
                  'index': 0,
                  'delta': {'content': delta['text']},
                  'finish_reason': null,
                },
              ],
            });
          }
          final toolUse = delta['toolUse'];
          if (toolUse is Map && toolUse['input'] is String && index != null) {
            final toolIndex = toolIndices[index];
            if (toolIndex == null) {
              throw const FormatException(
                'Bedrock tool delta has no start event.',
              );
            }
            yield _frame({
              'id': 'bedrock-stream',
              'object': 'chat.completion.chunk',
              'choices': [
                {
                  'index': 0,
                  'delta': {
                    'tool_calls': [
                      {
                        'index': toolIndex,
                        'function': {'arguments': toolUse['input']},
                      },
                    ],
                  },
                  'finish_reason': null,
                },
              ],
            });
          }
        } else if (event == 'messageStop') {
          receivedMessageStop = true;
          finishReason = _finishReason(value['stopReason']);
          yield _frame({
            'id': 'bedrock-stream',
            'object': 'chat.completion.chunk',
            'choices': [
              {'index': 0, 'delta': const {}, 'finish_reason': finishReason},
            ],
          });
        } else if (event == 'metadata') {
          final usage = value['usage'];
          if (usage is Map) {
            yield _frame({
              'id': 'bedrock-stream',
              'object': 'chat.completion.chunk',
              'choices': const [],
              'usage': {
                if (usage['inputTokens'] is num)
                  'prompt_tokens': (usage['inputTokens'] as num).toInt(),
                if (usage['outputTokens'] is num)
                  'completion_tokens': (usage['outputTokens'] as num).toInt(),
              },
            });
          }
        }
      }
    }
    if (pending.isNotEmpty || !receivedMessageStop) {
      throw const FormatException('Bedrock stream ended before messageStop.');
    }
    yield utf8.encode('data: [DONE]\n\n');
  }

  static List<int> _frame(Map<String, dynamic> value) =>
      utf8.encode('data: ${jsonEncode(value)}\n\n');

  static int? _int(Object? value) => value is num ? value.toInt() : null;

  static String _finishReason(Object? value) => switch (value) {
        'tool_use' => 'tool_calls',
        'max_tokens' => 'length',
        _ => 'stop',
      };

  static void _validateFrame(Uint8List frame, int headersLength) {
    final view = ByteData.sublistView(frame);
    final preludeCrc = view.getUint32(8, Endian.big);
    final calculatedPreludeCrc = _crc32(frame.sublist(0, 8));
    final messageCrc = view.getUint32(frame.length - 4, Endian.big);
    final calculatedMessageCrc = _crc32(frame.sublist(0, frame.length - 4));
    if (preludeCrc != calculatedPreludeCrc ||
        messageCrc != calculatedMessageCrc ||
        headersLength > frame.length - 16) {
      throw const FormatException('Bedrock EventStream CRC validation failed.');
    }
  }

  static Map<String, Object?> _readHeaders(Uint8List frame, int headersLength) {
    final result = <String, Object?>{};
    var offset = 12;
    final end = offset + headersLength;
    while (offset < end) {
      final nameLength = frame[offset++];
      if (offset + nameLength + 1 > end) {
        throw const FormatException('Invalid Bedrock EventStream header.');
      }
      final name = utf8.decode(frame.sublist(offset, offset + nameLength));
      offset += nameLength;
      final type = frame[offset++];
      final (value, nextOffset) = switch (type) {
        0 => (true as Object, offset),
        1 => (false as Object, offset),
        2 => _readInt(frame, offset, 1, end),
        3 => _readInt(frame, offset, 2, end),
        4 => _readInt(frame, offset, 4, end),
        5 || 8 => _readInt(frame, offset, 8, end),
        6 || 7 => _readVariable(frame, offset, end, type == 7),
        9 => _readUuid(frame, offset, end),
        _ => throw const FormatException(
            'Unknown Bedrock EventStream header type.',
          ),
      };
      offset = nextOffset;
      result[name] = value;
    }
    if (offset != end) {
      throw const FormatException('Invalid Bedrock EventStream header length.');
    }
    return result;
  }

  static (Object?, int) _readInt(
    Uint8List bytes,
    int offset,
    int length,
    int end,
  ) {
    if (offset + length > end) {
      throw const FormatException('Truncated Bedrock EventStream header.');
    }
    final view = ByteData.sublistView(bytes);
    final value = switch (length) {
      1 => bytes[offset],
      2 => view.getInt16(offset, Endian.big),
      4 => view.getInt32(offset, Endian.big),
      _ => view.getInt64(offset, Endian.big),
    };
    return (value, offset + length);
  }

  static (Object, int) _readVariable(
    Uint8List bytes,
    int offset,
    int end,
    bool isString,
  ) {
    if (offset + 2 > end) {
      throw const FormatException('Truncated Bedrock EventStream header.');
    }
    final length = ByteData.sublistView(bytes).getUint16(offset, Endian.big);
    offset += 2;
    if (offset + length > end) {
      throw const FormatException(
        'Truncated Bedrock EventStream header value.',
      );
    }
    final value = bytes.sublist(offset, offset + length);
    return (isString ? utf8.decode(value) : value, offset + length);
  }

  static (String, int) _readUuid(Uint8List bytes, int offset, int end) {
    if (offset + 16 > end) {
      throw const FormatException('Truncated Bedrock EventStream UUID.');
    }
    final value = bytes
        .sublist(offset, offset + 16)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return (value, offset + 16);
  }

  static int _crc32(List<int> bytes) {
    var crc = 0xffffffff;
    for (final byte in bytes) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
      }
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }
}
