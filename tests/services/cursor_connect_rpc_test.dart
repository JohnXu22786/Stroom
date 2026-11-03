import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:stroom/services/cursor_connect_rpc.dart';
import 'package:stroom/services/cursor_http2_transport.dart';

void main() {
  test(
    'Cursor Connect transport uses the pinned CLI client version header',
    () {
      expect(cursorAgentClientVersion, 'cli-2026.07.08-0c04a8a');
    },
  );

  test('Cursor HTTP/2 request guard rejects cancellation before send', () {
    final cancelToken = CancelToken()..cancel();

    expect(
      () => ensureCursorRequestNotCancelled(cancelToken),
      throwsA(
        isA<CursorConnectRpcException>().having(
          (error) => error.code,
          'code',
          'request_cancelled',
        ),
      ),
    );
    expect(() => ensureCursorRequestNotCancelled(null), returnsNormally);
  });

  test(
    'Cursor connect cancellation wins before TLS completes and disposes late socket',
    () async {
      final connection = Completer<int>();
      final cancelToken = CancelToken();
      var disposedLateConnection = false;
      final result = awaitCursorConnection<int>(
        connection: connection.future,
        cancelToken: cancelToken,
        disposeLateConnection: (_) => disposedLateConnection = true,
      );
      cancelToken.cancel();

      await expectLater(
        result,
        throwsA(
          isA<CursorConnectRpcException>().having(
            (error) => error.code,
            'code',
            'request_cancelled',
          ),
        ),
      );
      connection.complete(1);
      await Future<void>.delayed(Duration.zero);
      expect(disposedLateConnection, isTrue);
    },
  );

  test(
    'Cursor connect timeout disposes a socket that completes late',
    () async {
      final connection = Completer<int>();
      var disposedLateConnection = false;
      final result = awaitCursorConnection<int>(
        connection: connection.future,
        cancelToken: null,
        disposeLateConnection: (_) => disposedLateConnection = true,
        timeout: const Duration(milliseconds: 1),
      );

      await expectLater(
        result,
        throwsA(
          isA<CursorConnectRpcException>().having(
            (error) => error.code,
            'code',
            'transport_error',
          ),
        ),
      );
      connection.complete(1);
      await Future<void>.delayed(Duration.zero);
      expect(disposedLateConnection, isTrue);
    },
  );

  test(
    'Cursor request includes conversation state, source model, and session id',
    () {
      final request = CursorConnectFrameDecoder.encodeRequest(
        modelId: 'claude-sonnet-5-high',
        conversationId: 'conversation-1',
        body: const {
          'messages': [
            {'role': 'user', 'content': 'question'},
          ],
        },
      );

      expect(request.first, 0);
      expect(request, containsSubsequence(utf8.encode('claude-sonnet-5')));
      expect(request, containsSubsequence(utf8.encode('effort')));
      expect(request, containsSubsequence(utf8.encode('high')));
      expect(request, containsSubsequence(utf8.encode('conversation-1')));
      expect(request, containsSubsequence(utf8.encode('question')));
    },
  );

  test('Cursor server config selects and validates its assigned agent URL', () {
    final serverConfig = _message(27, [
      _bytes(1, utf8.encode('https://api5.cursor.sh/')),
      _bytes(2, utf8.encode('https://agent.api5.cursor.sh/')),
    ]);

    expect(
      CursorConnectFrameDecoder.decodeAgentRunEndpoint(serverConfig).toString(),
      'https://api5.cursor.sh/agent.v1.AgentService/Run',
    );
    expect(
      CursorConnectFrameDecoder.decodeAgentRunEndpoint(
        serverConfig,
        ghostMode: false,
      ).toString(),
      'https://agent.api5.cursor.sh/agent.v1.AgentService/Run',
    );

    final unsafeConfig = _message(27, [
      _bytes(1, utf8.encode('https://example.test/')),
      _bytes(2, utf8.encode('https://agent.api5.cursor.sh/')),
    ]);
    expect(
      () => CursorConnectFrameDecoder.decodeAgentRunEndpoint(unsafeConfig),
      throwsA(
        isA<CursorConnectRpcException>().having(
          (error) => error.code,
          'code',
          'invalid_agent_endpoint',
        ),
      ),
    );
  });

  test('Cursor model variants resolve to runtime model ids and parameters', () {
    Uint8List request(String model) => CursorConnectFrameDecoder.encodeRequest(
          modelId: model,
          conversationId: 'conversation-model',
          body: const {
            'messages': [
              {'role': 'user', 'content': 'hello'},
            ],
          },
        );

    final claude = request('claude-sonnet-5-high');
    expect(claude, containsSubsequence(utf8.encode('claude-sonnet-5')));
    expect(claude, containsSubsequence(utf8.encode('effort')));
    expect(claude, containsSubsequence(utf8.encode('high')));
    expect(
      claude,
      isNot(containsSubsequence(utf8.encode('claude-sonnet-5-high'))),
    );

    final auto = request('auto-cost');
    expect(auto, containsSubsequence(utf8.encode('default')));
    expect(auto, containsSubsequence(utf8.encode('optimization')));
    expect(auto, containsSubsequence(utf8.encode('cost')));

    final composer = request('composer-2.5-fast');
    expect(composer, containsSubsequence(utf8.encode('composer-2.5')));
    expect(composer, containsSubsequence(utf8.encode('fast')));
    expect(
      composer,
      isNot(containsSubsequence(utf8.encode('composer-2.5-fast'))),
    );

    final grok = request('cursor-grok-4.7-xhigh-fast-500k');
    expect(grok, containsSubsequence(utf8.encode('grok-4.7')));
    expect(grok, containsSubsequence(utf8.encode('context')));
    expect(grok, containsSubsequence(utf8.encode('500k')));
    expect(grok, containsSubsequence(utf8.encode('xhigh')));

    final fastGpt = request('gpt-5.6-sol-max-fast-1m');
    final standardGpt = request('gpt-5.6-sol-max-1m');
    expect(fastGpt, containsSubsequence(utf8.encode('fast')));
    expect(fastGpt, containsSubsequence(utf8.encode('true')));
    expect(standardGpt, containsSubsequence(utf8.encode('false')));
  });

  test(
    'Cursor joins text content blocks with the source newline separator',
    () {
      final request = CursorConnectFrameDecoder.encodeRequest(
        modelId: 'claude-sonnet-5-high',
        conversationId: 'conversation-text-parts',
        body: const {
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': 'first block'},
                {'type': 'text', 'text': 'second block'},
              ],
            },
          ],
        },
      );

      expect(
        request,
        containsSubsequence(utf8.encode('first block\nsecond block')),
      );
    },
  );

  test(
    'Cursor flattens system and history turns using the runtime chat layout',
    () {
      final request = CursorConnectFrameDecoder.encodeRequest(
        modelId: 'claude-sonnet-5-high',
        conversationId: 'conversation-history',
        body: const {
          'messages': [
            {'role': 'system', 'content': 'Be concise.'},
            {'role': 'user', 'content': 'First question'},
            {'role': 'assistant', 'content': 'First answer'},
            {'role': 'user', 'content': 'Follow up'},
          ],
        },
      );

      expect(request, containsSubsequence(utf8.encode('Be concise.')));
      expect(request, containsSubsequence(utf8.encode('User: First question')));
      expect(
        request,
        containsSubsequence(utf8.encode('Assistant: First answer')),
      );
      expect(request, containsSubsequence(utf8.encode('User: Follow up')));
    },
  );

  test('Cursor stores system prompts by digest and answers KV blob reads', () {
    final blobs = <String, Uint8List>{};
    final request = CursorConnectFrameDecoder.encodeRequest(
      modelId: 'claude-sonnet-5-high',
      conversationId: 'conversation-system',
      blobStore: blobs,
      body: const {
        'messages': [
          {'role': 'system', 'content': 'first instruction'},
          {'role': 'system', 'content': 'second instruction'},
          {'role': 'user', 'content': 'question'},
        ],
      },
    );
    final rootPromptBytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'role': 'system',
          'content': 'first instruction\n\nsecond instruction',
        }),
      ),
    );
    final digest = Uint8List.fromList(sha256.convert(rootPromptBytes).bytes);
    final digestHex =
        digest.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    expect(blobs[digestHex], rootPromptBytes);
    expect(request, containsSubsequence(digest));
    expect(request, containsSubsequence(utf8.encode('first instruction')));
    expect(request, containsSubsequence(utf8.encode('second instruction')));

    final metadata = Uint8List.fromList(utf8.encode('request-cursor'));
    final getBlobRequest = _frame(
      _message(4, [
        _varint(1, 27),
        _message(2, [_bytes(1, digest)]),
        _bytes(4, metadata),
      ]),
    );
    final delta = CursorConnectFrameDecoder().add(getBlobRequest).single;
    expect(delta.keyValueGet, isTrue);
    expect(delta.keyValueBlobId, digest);
    expect(delta.requestMetadata, metadata);
    final ack = CursorConnectFrameDecoder.encodeKeyValueAck(
      id: delta.keyValueId!,
      set: false,
      blobData: blobs[digestHex],
      requestMetadata: delta.requestMetadata,
    );
    expect(ack, containsSubsequence(rootPromptBytes));
    expect(ack, containsSubsequence(metadata));
  });

  test(
    'Cursor rejects partial tool activity before a Composer KV checkpoint',
    () {
      final payload = Uint8List.fromList([
        ..._message(1, [
          _message(1, [_bytes(1, utf8.encode('narration'))]),
          _bytes(7, const []),
        ]),
        ..._message(4, [
          _varint(1, 9),
          _message(2, [
            _bytes(1, [1, 2, 3]),
          ]),
        ]),
      ]);

      final deltas = CursorConnectFrameDecoder.decodeAgentServerMessage(
        payload,
      );

      expect(deltas.first.text, 'narration');
      expect(deltas[1].unsupportedAction, 'tools');
      expect(deltas.last.keyValueGet, isTrue);
    },
  );

  test(
    'Cursor request encodes inline Stroom image blocks as selected images',
    () {
      final imageBytes = Uint8List.fromList([
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
      ]);
      final dataUrl = 'data:image/png;base64,${base64Encode(imageBytes)}';
      final blobs = <String, Uint8List>{};
      final request = CursorConnectFrameDecoder.encodeRequest(
        modelId: 'claude-sonnet-5-high',
        conversationId: 'conversation-image',
        blobStore: blobs,
        body: {
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': 'What is in this picture?'},
                {
                  'type': 'image_url',
                  'image_url': {'url': dataUrl},
                },
              ],
            },
          ],
        },
      );

      expect(request, containsSubsequence(imageBytes));
      expect(request, containsSubsequence(utf8.encode('image/png')));
      expect(request, containsSubsequence(utf8.encode('attachment-')));
      final digestHex = sha256
          .convert(imageBytes)
          .bytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      expect(blobs[digestHex], imageBytes);
    },
  );

  test('Cursor attaches only images from the latest user turn', () {
    final oldImage = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 0x01]);
    final currentImage = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 0x02]);
    String dataUrl(Uint8List bytes) =>
        'data:image/png;base64,${base64Encode(bytes)}';
    final blobs = <String, Uint8List>{};
    final request = CursorConnectFrameDecoder.encodeRequest(
      modelId: 'claude-sonnet-5-high',
      conversationId: 'conversation-image-history',
      blobStore: blobs,
      body: {
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'Earlier image'},
              {
                'type': 'image_url',
                'image_url': {'url': dataUrl(oldImage)},
              },
            ],
          },
          {'role': 'assistant', 'content': 'Earlier description'},
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'What is in this image?'},
              {
                'type': 'image_url',
                'image_url': {'url': dataUrl(currentImage)},
              },
            ],
          },
        ],
      },
    );

    expect(request, containsSubsequence(currentImage));
    expect(request, isNot(containsSubsequence(oldImage)));
    final currentDigest = sha256
        .convert(currentImage)
        .bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final oldDigest = sha256
        .convert(oldImage)
        .bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    expect(blobs[currentDigest], currentImage);
    expect(blobs.containsKey(oldDigest), isFalse);
  });

  test(
    'Cursor rejects unmapped tools and non-inline image sources explicitly',
    () {
      expect(
        () => CursorConnectFrameDecoder.encodeRequest(
          modelId: 'claude-sonnet-5-high',
          conversationId: 'conversation-tools',
          body: const {
            'messages': [
              {'role': 'user', 'content': 'hello'},
            ],
            'tools': [
              {
                'type': 'function',
                'function': {'name': 'run'},
              },
            ],
          },
        ),
        throwsA(
          isA<CursorConnectRpcException>().having(
            (error) => error.code,
            'code',
            'unsupported_tools',
          ),
        ),
      );
      expect(
        () => CursorConnectFrameDecoder.encodeRequest(
          modelId: 'claude-sonnet-5-high',
          conversationId: 'conversation-remote-image',
          body: const {
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'https://example.test/image.png'},
                  },
                ],
              },
            ],
          },
        ),
        throwsA(
          isA<CursorConnectRpcException>().having(
            (error) => error.code,
            'code',
            'unsupported_images',
          ),
        ),
      );

      expect(
        () => CursorConnectFrameDecoder.encodeRequest(
          modelId: 'claude-sonnet-5-high',
          conversationId: 'conversation-mixed-media',
          body: const {
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': 'transcribe this'},
                  {
                    'type': 'input_audio',
                    'input_audio': {'format': 'wav', 'data': 'YWJj'},
                  },
                ],
              },
            ],
          },
        ),
        throwsA(
          isA<CursorConnectRpcException>().having(
            (error) => error.code,
            'code',
            'unsupported_content',
          ),
        ),
      );
    },
  );

  test('Cursor accepts supplied tools when tool_choice disables them', () {
    final request = CursorConnectFrameDecoder.encodeRequest(
      modelId: 'claude-sonnet-5-high',
      conversationId: 'conversation-tools-disabled',
      body: const {
        'messages': [
          {'role': 'user', 'content': 'Answer without tools.'},
        ],
        'tools': [
          {
            'type': 'function',
            'function': {
              'name': 'lookup',
              'parameters': {'type': 'object'},
            },
          },
        ],
        'tool_choice': 'none',
      },
    );

    expect(request, containsSubsequence(utf8.encode('Answer without tools.')));
  });

  test('Cursor rejects malformed messages and unsupported content values', () {
    for (final message in [
      'not a message map',
      {'content': 'missing role'},
      {'role': 'developer', 'content': 'unsupported role'},
    ]) {
      expect(
        () => CursorConnectFrameDecoder.encodeRequest(
          modelId: 'claude-sonnet-5-high',
          conversationId: 'conversation-invalid-message',
          body: {
            'messages': [message],
          },
        ),
        throwsA(
          isA<CursorConnectRpcException>().having(
            (error) => error.code,
            'code',
            'invalid_request',
          ),
        ),
      );
    }

    expect(
      () => CursorConnectFrameDecoder.encodeRequest(
        modelId: 'claude-sonnet-5-high',
        conversationId: 'conversation-invalid-content',
        body: const {
          'messages': [
            {'role': 'user', 'content': 7},
          ],
        },
      ),
      throwsA(
        isA<CursorConnectRpcException>().having(
          (error) => error.code,
          'code',
          'unsupported_content',
        ),
      ),
    );
  });

  test(
    'Cursor frame decoder handles split frames and preserves visible reasoning and usage',
    () {
      final text = _message(1, [_bytes(1, utf8.encode('answer'))]);
      final reasoning = _message(4, [
        _bytes(1, utf8.encode('brief rationale')),
      ]);
      final usage = _message(14, [_varint(1, 12), _varint(2, 4)]);
      final payload = _message(1, [text, reasoning, usage]);
      final frame = _frame(payload);
      final decoder = CursorConnectFrameDecoder();

      expect(decoder.add(frame.sublist(0, 3)), isEmpty);
      final deltas = decoder.add(frame.sublist(3));
      expect(deltas.map((delta) => delta.text).whereType<String>(), ['answer']);
      expect(deltas.map((delta) => delta.reasoning).whereType<String>(), [
        'brief rationale',
      ]);
      expect(deltas.last.turnEnded, isTrue);
      expect(deltas.last.usage, {
        'prompt_tokens': 12,
        'completion_tokens': 4,
        'total_tokens': 16,
      });
    },
  );

  test(
    'Cursor decodes compressed Connect frames and nested error trailers',
    () {
      final text = _message(1, [_bytes(1, utf8.encode('compressed answer'))]);
      final update = _message(1, [text]);
      final compressedMessage = GZipEncoder().encode(update);
      final messageDeltas = CursorConnectFrameDecoder().add(
        _frame(compressedMessage, flags: 1),
      );
      expect(messageDeltas.map((delta) => delta.text).whereType<String>(), [
        'compressed answer',
      ]);

      final trailer = GZipEncoder().encode(
        utf8.encode(
          jsonEncode({
            'error': {'code': 'unauthenticated', 'message': 'token expired'},
          }),
        ),
      );
      expect(
        () => CursorConnectFrameDecoder().add(_frame(trailer, flags: 3)),
        throwsA(
          isA<CursorConnectRpcException>().having(
            (error) => error.code,
            'code',
            'upstream_unauthenticated',
          ),
        ),
      );
    },
  );

  test('Cursor answers blocking MCP state with an empty ready server', () {
    final request = _frame(
      _message(2, [
        _varint(1, 9),
        _bytes(15, utf8.encode('exec-state')),
        _message(36, [_bytes(1, const [])]),
      ]),
    );
    final delta = CursorConnectFrameDecoder().add(request).single;
    expect(delta.mcpStateId, 9);
    expect(delta.execId, 'exec-state');
    expect(delta.mcpServerIdentifier, 'stroom');

    final response = CursorConnectFrameDecoder.encodeMcpStateAck(
      id: delta.mcpStateId!,
      execId: delta.execId!,
      serverIdentifier: delta.mcpServerIdentifier!,
    );
    expect(response, containsSubsequence(utf8.encode('stroom')));
    expect(response, containsSubsequence(utf8.encode('ready')));
    expect(response, containsSubsequence(utf8.encode('exec-state')));
  });

  test('Composer KV checkpoint after MCP state does not end the turn', () {
    final state = CursorComposerTerminalState();
    state.noteContent();
    expect(state.shouldEndOnKvCheckpoint, isTrue);

    state.noteInternalToolActivity();
    expect(state.shouldEndOnKvCheckpoint, isFalse);

    state.noteContent();
    expect(state.shouldEndOnKvCheckpoint, isTrue);
  });

  test('Cursor response stream enforces a bounded lifetime', () async {
    final source = StreamController<int>();
    var terminated = false;
    final guarded = cursorAgentResponseWithDeadline(
      source.stream,
      timeout: const Duration(milliseconds: 1),
      onTimeout: () => terminated = true,
    );

    await expectLater(
      guarded,
      emitsError(
        isA<CursorConnectRpcException>().having(
          (error) => error.code,
          'code',
          'response_timeout',
        ),
      ),
    );
    expect(terminated, isTrue);
    await source.close();
  });

  test(
    'Cursor non-success HTTP status terminates the transport immediately',
    () {
      var terminated = false;

      terminateCursorTransportForStatus(503, () => terminated = true);

      expect(terminated, isTrue);
      terminated = false;
      terminateCursorTransportForStatus(200, () => terminated = true);
      expect(terminated, isFalse);
    },
  );

  test(
    'canceling a Cursor response stream cancels its transport source',
    () async {
      var sourceCancelled = false;
      final source = StreamController<int>(
        onCancel: () => sourceCancelled = true,
      );
      final guarded = cursorAgentResponseWithDeadline(
        source.stream,
        timeout: const Duration(seconds: 30),
        onTimeout: () {},
      );
      final subscription = guarded.listen((_) {});

      await subscription.cancel();

      expect(sourceCancelled, isTrue);
      await source.close();
    },
  );

  test(
    'Cursor frame decoder rejects an incomplete frame at stream completion',
    () {
      final decoder = CursorConnectFrameDecoder();
      decoder.add(Uint8List.fromList([0, 0, 0, 0, 3, 0x0a]));
      expect(
        decoder.finish,
        throwsA(
          isA<CursorConnectRpcException>().having(
            (error) => error.code,
            'code',
            'truncated_frame',
          ),
        ),
      );
      CursorConnectFrameDecoder().finish();
    },
  );

  test(
    'Cursor Composer thinking keeps the private prefix hidden and yields only final content',
    () {
      expect(
        CursorConnectFrameDecoder.visibleComposerReply(
          'private analysis</think><|final|>visible answer<|/final|>',
        ),
        'visible answer',
      );
      expect(
        CursorConnectFrameDecoder.visibleComposerReply(
          'private analysis</think>   <|final|>  visible answer<|/final|>',
        ),
        'visible answer',
      );
      expect(
        CursorConnectFrameDecoder.visibleComposerReply('private analysis'),
        isEmpty,
      );
      expect(
        CursorConnectFrameDecoder.visibleComposerReply(
          'private analysis</think><|fin',
        ),
        isEmpty,
      );

      final decoder = CursorComposerReplyDecoder();
      expect(
        decoder.add('private analysis</think><|final|>visible'),
        'visible',
      );
      expect(decoder.add(' answer'), ' answer');
      expect(decoder.finish(), isEmpty);

      final spacedDecoder = CursorComposerReplyDecoder();
      expect(
        spacedDecoder.add('private analysis</think><|final|>Hello '),
        'Hello ',
      );
      expect(spacedDecoder.add('world'), 'world');
      expect(spacedDecoder.finish(), isEmpty);
    },
  );

  test('Cursor Composer inline tool markers are rejected before completion',
      () {
    final toolDecoder = CursorComposerReplyDecoder();
    expect(
      toolDecoder.add(
        'private analysis</think>Visible preamble<|tool_calls_',
      ),
      'Visible preamble',
    );
    expect(
      () => toolDecoder.add('begin|>tool payload'),
      throwsA(
        isA<CursorConnectRpcException>().having(
          (error) => error.code,
          'code',
          'unsupported_tools',
        ),
      ),
    );
  });

  test('Cursor stream capability failures use a structured SSE error', () {
    final chunk = CursorConnectFrameDecoder.encodeSseErrorChunk(
      'unsupported_capability',
    );
    final frame = utf8.decode(chunk).trim();
    final data = jsonDecode(frame.substring('data: '.length)) as Map;

    expect((data['error'] as Map)['code'], 'unsupported_capability');
  });
}

Matcher containsSubsequence(List<int> expected) =>
    predicate<List<int>>((actual) {
      for (var start = 0; start + expected.length <= actual.length; start++) {
        var matches = true;
        for (var index = 0; index < expected.length; index++) {
          if (actual[start + index] != expected[index]) {
            matches = false;
            break;
          }
        }
        if (matches) return true;
      }
      return false;
    }, 'contains byte subsequence $expected');

Uint8List _frame(List<int> payload, {int flags = 0}) => Uint8List.fromList([
      flags,
      (payload.length >> 24) & 0xff,
      (payload.length >> 16) & 0xff,
      (payload.length >> 8) & 0xff,
      payload.length & 0xff,
      ...payload,
    ]);

Uint8List _message(int number, List<Uint8List> parts) =>
    _bytes(number, parts.expand((part) => part).toList());

Uint8List _bytes(int number, List<int> data) => Uint8List.fromList([
      ..._rawVarint((number << 3) | 2),
      ..._rawVarint(data.length),
      ...data,
    ]);

Uint8List _varint(int number, int value) =>
    Uint8List.fromList([..._rawVarint(number << 3), ..._rawVarint(value)]);

List<int> _rawVarint(int value) {
  final bytes = <int>[];
  while (value >= 0x80) {
    bytes.add((value & 0x7f) | 0x80);
    value >>= 7;
  }
  bytes.add(value);
  return bytes;
}
