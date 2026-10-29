import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/aws_bedrock_event_stream.dart';

void main() {
  test(
    'converts ConverseStream text and usage events into OpenAI SSE deltas',
    () async {
      final events = [
        _event('messageStart', {
          'messageStart': {'role': 'assistant'},
        }),
        _event('contentBlockDelta', {
          'contentBlockIndex': 0,
          'delta': {'text': 'Hello'},
        }),
        _event('contentBlockDelta', {
          'contentBlockIndex': 0,
          'delta': {'text': ' world'},
        }),
        _event('messageStop', {
          'messageStop': {'stopReason': 'end_turn'},
        }),
        _event('metadata', {
          'metadata': {
            'usage': {'inputTokens': 3, 'outputTokens': 2},
          },
        }),
      ];

      final chunks = await AwsBedrockEventStreamAdapter.toOpenAiSse(
        Stream<List<int>>.fromIterable([
          events.expand((event) => event).take(17).toList(),
          events.expand((event) => event).skip(17).toList(),
        ]),
      ).toList();
      final text = utf8.decode(chunks.expand((chunk) => chunk).toList());
      final frames = _dataFrames(text);

      expect(
        frames
            .map((frame) => frame['choices'])
            .where((choices) => choices is List && choices.isNotEmpty),
        hasLength(3),
      );
      expect(text, contains('"content":"Hello"'));
      expect(text, contains('"content":" world"'));
      expect(text, contains('"finish_reason":"stop"'));
      expect(text, contains('"prompt_tokens":3'));
      expect(text, contains('data: [DONE]'));
    },
  );

  test('rejects corrupt AWS EventStream CRCs', () async {
    final frame = _event('messageStop', {
      'messageStop': {'stopReason': 'end_turn'},
    });
    frame[frame.length - 1] ^= 0xff;

    await expectLater(
      AwsBedrockEventStreamAdapter.toOpenAiSse(Stream.value(frame)).toList(),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'converts tool input events to incremental function-call deltas',
    () async {
      final stream = Stream<List<int>>.fromIterable([
        _event('contentBlockStart', {
          'contentBlockIndex': 1,
          'start': {
            'toolUse': {'toolUseId': 'call-1', 'name': 'lookup'},
          },
        }),
        _event('contentBlockDelta', {
          'contentBlockIndex': 1,
          'delta': {
            'toolUse': {'input': '{"query":'},
          },
        }),
        _event('contentBlockDelta', {
          'contentBlockIndex': 1,
          'delta': {
            'toolUse': {'input': '"weather"}'},
          },
        }),
        _event('messageStop', {
          'messageStop': {'stopReason': 'tool_use'},
        }),
      ]);

      final chunks = await AwsBedrockEventStreamAdapter.toOpenAiSse(
        stream,
      ).toList();
      final text = utf8.decode(chunks.expand((chunk) => chunk).toList());

      expect(text, contains('"id":"call-1"'));
      expect(text, contains('"name":"lookup"'));
      expect(text, contains(r'{\"query\":'));
      expect(text, contains('"finish_reason":"tool_calls"'));
    },
  );
}

List<Map<String, dynamic>> _dataFrames(String source) => [
      for (final block in source.split('\n\n'))
        if (block.startsWith('data: {'))
          Map<String, dynamic>.from(jsonDecode(block.substring(6)) as Map),
    ];

Uint8List _event(String eventType, Map<String, dynamic> payload) {
  final name = utf8.encode(':event-type');
  final value = utf8.encode(eventType);
  final header = <int>[
    name.length,
    ...name,
    7,
    value.length >> 8,
    value.length & 0xff,
    ...value,
  ];
  final body = utf8.encode(
    jsonEncode(payload.containsKey(eventType) ? payload[eventType] : payload),
  );
  final totalLength = 12 + header.length + body.length + 4;
  final prelude = ByteData(12)
    ..setUint32(0, totalLength, Endian.big)
    ..setUint32(4, header.length, Endian.big)
    ..setUint32(
      8,
      _crc32(
        Uint8List.sublistView(
          ByteData(8)
            ..setUint32(0, totalLength, Endian.big)
            ..setUint32(4, header.length, Endian.big),
        ),
      ),
      Endian.big,
    );
  final frameWithoutCrc = Uint8List.fromList([
    ...prelude.buffer.asUint8List(),
    ...header,
    ...body,
  ]);
  final trailer = ByteData(4)
    ..setUint32(0, _crc32(frameWithoutCrc), Endian.big);
  return Uint8List.fromList([
    ...frameWithoutCrc,
    ...trailer.buffer.asUint8List(),
  ]);
}

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}
