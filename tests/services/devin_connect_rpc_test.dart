import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/devin_connect_rpc.dart';

void main() {
  test(
    'frames Devin Connect-RPC requests with model and conversation turns',
    () {
      final request = DevinConnectRpc.encodeChatRequest(
        sessionToken: r'devin-session-token$test',
        modelId: 'devin/swe-2',
        body: const {
          'messages': [
            {'role': 'system', 'content': 'Be concise'},
            {'role': 'user', 'content': 'Hello Devin'},
          ],
        },
      );

      expect(request.first, 0);
      final size =
          request[1] << 24 | request[2] << 16 | request[3] << 8 | request[4];
      expect(size, request.length - 5);
      expect(utf8.decode(request, allowMalformed: true), contains('chisel'));
      expect(
        utf8.decode(request, allowMalformed: true),
        contains('Hello Devin'),
      );
      expect(utf8.decode(request, allowMalformed: true), contains('swe-2'));
    },
  );

  test('decodes unary Devin Connect response into Chat completion shape', () {
    final text = _field(3, utf8.encode('Hello from Devin'));
    final usage = [..._varintField(2, 11), ..._varintField(3, 7)];
    final payload = [...text, ..._field(7, usage)];
    final framed = [..._frame(0, payload), ..._frame(2, utf8.encode('{}'))];

    final response = DevinConnectRpc.decodeChatResponse(framed);

    expect(response['object'], 'chat.completion');
    expect(((response['choices'] as List).single as Map)['message'], {
      'role': 'assistant',
      'content': 'Hello from Devin',
    });
    expect(response['usage'], {
      'prompt_tokens': 11,
      'completion_tokens': 7,
      'total_tokens': 18,
    });
  });

  test('returns Devin tool calls in the Chat completion contract', () {
    final tool = [
      ..._field(1, utf8.encode('call-1')),
      ..._field(2, utf8.encode('lookup')),
      ..._field(3, utf8.encode('{"q":"weather"}')),
    ];
    final payload = _field(6, tool);
    final response = DevinConnectRpc.decodeChatResponse([
      ..._frame(0, payload),
      ..._frame(2, utf8.encode('{}')),
    ]);

    final choice = (response['choices'] as List).single as Map;
    final message = choice['message'] as Map;
    expect(choice['finish_reason'], 'tool_calls');
    expect(message['tool_calls'], [
      {
        'id': 'call-1',
        'type': 'function',
        'function': {'name': 'lookup', 'arguments': '{"q":"weather"}'},
      },
    ]);
  });

  test('rejects a Connect-RPC error in the terminal trailer', () {
    final message = _field(3, utf8.encode('should not be accepted'));
    final errorTrailer = utf8.encode(
      '{"error":{"code":"unauthenticated","message":"expired"}}',
    );
    final response = [
      ..._frame(0, message),
      ..._frame(2, errorTrailer),
    ];

    expect(
      () => DevinConnectRpc.decodeChatResponse(response),
      throwsFormatException,
    );
  });

  test('requires the Connect end-stream trailer to terminate the response', () {
    final message = _field(3, utf8.encode('reply'));
    final response = [
      ..._frame(0, message),
      ..._frame(2, utf8.encode('{}')),
      ..._frame(0, message),
    ];

    expect(
      () => DevinConnectRpc.decodeChatResponse(response),
      throwsFormatException,
    );
  });

  test('rejects a response that has no Connect end-stream trailer', () {
    final message = _field(3, utf8.encode('reply'));

    expect(
      () => DevinConnectRpc.decodeChatResponse(_frame(0, message)),
      throwsFormatException,
    );
  });

  test(
    'rejects unsupported media blocks instead of silently dropping them',
    () {
      expect(
        () => DevinConnectRpc.encodeChatRequest(
          sessionToken: 'test-token',
          modelId: 'devin/swe-2',
          body: const {
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': 'input_audio', 'data': '...'},
                ],
              },
            ],
          },
        ),
        throwsFormatException,
      );
    },
  );
}

List<int> _field(int field, List<int> value) => [
      ..._rawVarint(field << 3 | 2),
      ..._rawVarint(value.length),
      ...value,
    ];

List<int> _frame(int flag, List<int> payload) => [
      flag,
      payload.length >> 24 & 255,
      payload.length >> 16 & 255,
      payload.length >> 8 & 255,
      payload.length & 255,
      ...payload,
    ];

List<int> _varintField(int field, int value) => [
      ..._rawVarint(field << 3),
      ..._rawVarint(value),
    ];

List<int> _rawVarint(int value) {
  final bytes = <int>[];
  while (value >= 128) {
    bytes.add(value & 127 | 128);
    value >>= 7;
  }
  bytes.add(value);
  return bytes;
}
