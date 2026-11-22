import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/ai_gateway/ai_gateway_realtime_session.dart';

Uint8List _pcm16Wav({required int sampleRate, required List<int> samples}) {
  final bytes = Uint8List(44 + samples.length * 2);
  final data = ByteData.sublistView(bytes);
  void writeAscii(int offset, String value) {
    bytes.setRange(offset, offset + value.length, value.codeUnits);
  }

  writeAscii(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  writeAscii(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var index = 0; index < samples.length; index++) {
    data.setInt16(44 + index * 2, samples[index], Endian.little);
  }
  return bytes;
}

void main() {
  group('AI Gateway realtime session protocol', () {
    test('admits only the source-backed Realtime account/model pairs', () {
      expect(
        AiGatewayRealtimeProtocol.providerForModel(
          'openai-api',
          'gpt-realtime-2.1',
        ),
        'openai',
      );
      expect(
        AiGatewayRealtimeProtocol.providerForModel('xai', 'grok-voice-agent'),
        'xai',
      );
      expect(
        AiGatewayRealtimeProtocol.providerForModel(
          'xai-oauth',
          'grok-voice-agent',
        ),
        isNull,
      );
      expect(
        AiGatewayRealtimeProtocol.providerForModel('openai-api', 'gpt-4.1'),
        isNull,
      );
      expect(
        AiGatewayRealtimeProtocol.providerForModel('xai', 'grok-4'),
        isNull,
      );
    });

    test('builds a text turn while rejecting unsupported message shapes', () {
      expect(
        AiGatewayRealtimeProtocol.buildConversationEvents([
          {'role': 'user', 'content': 'hello'},
        ]),
        [
          {
            'type': 'session.update',
            'session': {
              'audio': {
                'input': {
                  'format': {'type': 'audio/pcm', 'rate': 24000},
                },
                'output': {
                  'format': {'type': 'audio/pcm', 'rate': 24000},
                  'voice': 'marin',
                },
              },
            },
          },
          {
            'type': 'conversation.item.create',
            'item': {
              'type': 'message',
              'role': 'user',
              'content': [
                {'type': 'input_text', 'text': 'hello'},
              ],
            },
          },
          {
            'type': 'response.create',
            'response': {
              'output_modalities': ['audio'],
            },
          },
        ],
      );
      expect(
        AiGatewayRealtimeProtocol.buildConversationEvents([
          {
            'role': 'user',
            'content': [
              {
                'type': 'input_audio',
                'input_audio': {'data': 'AQID', 'format': 'pcm16'},
              },
            ],
          },
        ]),
        [
          {
            'type': 'session.update',
            'session': {
              'audio': {
                'input': {
                  'format': {'type': 'audio/pcm', 'rate': 24000},
                },
                'output': {
                  'format': {'type': 'audio/pcm', 'rate': 24000},
                  'voice': 'marin',
                },
              },
            },
          },
          {'type': 'input_audio_buffer.append', 'audio': 'AQID'},
          {'type': 'input_audio_buffer.commit'},
          {
            'type': 'response.create',
            'response': {
              'output_modalities': ['audio'],
            },
          },
        ],
      );
      expect(
        AiGatewayRealtimeProtocol.buildConversationEvents([
          {'role': 'user', 'content': 'hello'},
        ], providerId: 'xai')
            .last,
        {'type': 'response.create'},
      );
      final mixedContentEvents =
          AiGatewayRealtimeProtocol.buildConversationEvents([
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': 'before audio'},
            {
              'type': 'input_audio',
              'input_audio': {'data': 'AQID', 'format': 'pcm16'},
            },
            {'type': 'text', 'text': 'after audio'},
          ],
        },
      ]);
      expect(
        mixedContentEvents.map((event) {
          if (event['type'] == 'conversation.item.create') {
            final item = event['item'] as Map;
            return ((item['content'] as List).single as Map)['text'];
          }
          return event['type'];
        }),
        [
          'session.update',
          'before audio',
          'input_audio_buffer.append',
          'input_audio_buffer.commit',
          'after audio',
          'response.create',
        ],
      );
      final continuedConversation =
          AiGatewayRealtimeProtocol.buildConversationEvents([
        {
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': 'spoken answer'},
            {
              'type': 'input_audio',
              'input_audio': {'data': 'UklGRg==', 'format': 'wav'},
            },
          ],
        },
        {'role': 'user', 'content': 'next question'},
      ]);
      expect(
        continuedConversation.where(
          (event) => event['type'] == 'input_audio_buffer.append',
        ),
        isEmpty,
      );
      expect(
        continuedConversation
            .where((event) => event['type'] == 'conversation.item.create')
            .map(
              (event) => (((event['item'] as Map)['content'] as List).single
                  as Map)['text'],
            ),
        ['spoken answer', 'next question'],
      );
      final wavInput = _pcm16Wav(sampleRate: 16000, samples: [1000, 2000]);
      final convertedWavInput =
          AiGatewayRealtimeProtocol.buildConversationEvents([
        {
          'role': 'user',
          'content': [
            {
              'type': 'input_audio',
              'input_audio': {
                'data': base64Encode(wavInput),
                'format': 'wav',
              },
            },
          ],
        },
      ]);
      final convertedPcm = base64Decode(
        convertedWavInput.singleWhere(
          (event) => event['type'] == 'input_audio_buffer.append',
        )['audio'] as String,
      );
      expect(convertedPcm.length, 6);
      expect(String.fromCharCodes(convertedPcm.take(4)), isNot('RIFF'));
      expect(
        () => AiGatewayRealtimeProtocol.buildConversationEvents([
          {
            'role': 'user',
            'content': [
              {
                'type': 'input_audio',
                'input_audio': {'data': 'AQID', 'format': 'mp3'},
              },
            ],
          },
        ]),
        throwsA(
          isA<UnsupportedError>().having(
            (error) => error.toString(),
            'message',
            contains('convert compressed audio'),
          ),
        ),
      );

      expect(
        () => AiGatewayRealtimeProtocol.buildConversationEvents([
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {'url': 'https://example.test/image.png'},
              },
            ],
          },
        ]),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => AiGatewayRealtimeProtocol.buildConversationEvents([
          {
            'role': 'user',
            'content': [
              {'type': 'input_video', 'video': 'data'},
            ],
          },
        ]),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        AiGatewayRealtimeProtocol.buildConversationEvents(
          [
            {
              'role': 'assistant',
              'content': 'checking',
              'tool_calls': [
                {
                  'id': 'call-1',
                  'type': 'function',
                  'function': {'name': 'lookup', 'arguments': '{"q":"x"}'},
                },
              ],
            },
            {'role': 'tool', 'tool_call_id': 'call-1', 'content': 'result'},
            {'role': 'user', 'content': 'what did you find?'},
          ],
          tools: [
            {
              'type': 'function',
              'function': {
                'name': 'lookup',
                'description': 'Look up a value',
                'parameters': {'type': 'object'},
              },
            },
          ],
        ),
        [
          {
            'type': 'session.update',
            'session': {
              'audio': {
                'input': {
                  'format': {'type': 'audio/pcm', 'rate': 24000},
                },
                'output': {
                  'format': {'type': 'audio/pcm', 'rate': 24000},
                  'voice': 'marin',
                },
              },
            },
          },
          {
            'type': 'session.update',
            'session': {
              'tools': [
                {
                  'type': 'function',
                  'name': 'lookup',
                  'description': 'Look up a value',
                  'parameters': {'type': 'object'},
                },
              ],
              'tool_choice': 'auto',
            },
          },
          {
            'type': 'conversation.item.create',
            'item': {
              'type': 'message',
              'role': 'assistant',
              'content': [
                {'type': 'text', 'text': 'checking'},
              ],
            },
          },
          {
            'type': 'conversation.item.create',
            'item': {
              'type': 'function_call',
              'call_id': 'call-1',
              'name': 'lookup',
              'arguments': '{"q":"x"}',
            },
          },
          {
            'type': 'conversation.item.create',
            'item': {
              'type': 'function_call_output',
              'call_id': 'call-1',
              'output': 'result',
            },
          },
          {
            'type': 'conversation.item.create',
            'item': {
              'type': 'message',
              'role': 'user',
              'content': [
                {'type': 'input_text', 'text': 'what did you find?'},
              ],
            },
          },
          {
            'type': 'response.create',
            'response': {
              'output_modalities': ['audio'],
            },
          },
        ],
      );
    });

    test('requires API-key auth and keeps provider endpoints separate', () {
      expect(
        () => AiGatewayRealtimeProtocol.prepareConnection(
          providerId: 'xai',
          authType: 'oauth',
          apiKey: 'oauth-token',
          modelId: 'grok-voice',
        ),
        throwsArgumentError,
      );

      final openAi = AiGatewayRealtimeProtocol.prepareConnection(
        providerId: 'openai-api',
        authType: 'api_key',
        apiKey: 'openai-key',
        modelId: 'gpt-realtime',
      );
      final xai = AiGatewayRealtimeProtocol.prepareConnection(
        providerId: 'xai',
        authType: 'api_key',
        apiKey: 'xai-key',
        modelId: 'grok-voice',
      );

      expect(
        openAi.uri.toString(),
        'wss://api.openai.com/v1/realtime?model=gpt-realtime',
      );
      expect(xai.uri.toString(), 'wss://api.x.ai/v1/realtime?model=grok-voice');
      expect(
        AiGatewayXaiVoiceRealtimeAdapter.prepareConnection(
          authType: 'api_key',
          apiKey: 'xai-key',
          modelId: 'grok-voice',
        ).headers['Authorization'],
        'Bearer xai-key',
      );
      expect(
        () => AiGatewayXaiVoiceRealtimeAdapter.prepareConnection(
          authType: 'oauth',
          apiKey: 'oauth-access-token',
          modelId: 'grok-voice',
        ),
        throwsArgumentError,
      );
      expect(openAi.headers['Authorization'], 'Bearer openai-key');
      expect(xai.headers['Authorization'], 'Bearer xai-key');
    });

    test('bounds and cancels a stalled websocket handshake', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requestReceived = Completer<void>();
      final secondRequestReceived = Completer<void>();
      var requestCount = 0;
      final subscription = server.listen((request) {
        requestCount++;
        if (!requestReceived.isCompleted) requestReceived.complete();
        if (requestCount == 2 && !secondRequestReceived.isCompleted) {
          secondRequestReceived.complete();
        }
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
      });
      final options = AiGatewayRealtimeConnectionOptions(
        providerId: 'openai',
        uri: Uri.parse(
          'ws://${server.address.address}:${server.port}/v1/realtime?model=gpt-realtime',
        ),
        headers: const {},
      );

      await expectLater(
        AiGatewayRealtimeProtocol.connect(
          options,
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(isA<TimeoutException>()),
      );
      await requestReceived.future;

      final cancellation = CancelToken();
      final pending = AiGatewayRealtimeProtocol.connect(
        options,
        cancelToken: cancellation,
        timeout: const Duration(seconds: 5),
      );
      await secondRequestReceived.future;
      cancellation.cancel('test cancellation');
      await expectLater(
        pending,
        throwsA(isA<AiGatewayRealtimeConnectionCancelled>()),
      );
    });

    test(
      'preserves the HTTP status from a rejected websocket handshake',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final subscription = server.listen((request) async {
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.close();
        });
        addTearDown(() async {
          await subscription.cancel();
          await server.close(force: true);
        });

        final options = AiGatewayRealtimeConnectionOptions(
          providerId: 'openai',
          uri: Uri.parse(
            'ws://${server.address.address}:${server.port}/realtime',
          ),
          headers: const {},
        );
        await expectLater(
          AiGatewayRealtimeProtocol.connect(options),
          throwsA(
            isA<AiGatewayRealtimeHandshakeFailure>().having(
              (error) => error.statusCode,
              'statusCode',
              HttpStatus.unauthorized,
            ),
          ),
        );
      },
    );

    test('maps realtime text, audio, lifecycle, cancellation, and errors', () {
      final text = AiGatewayRealtimeProtocol.mapEvent('openai', {
        'type': 'response.output_text.delta',
        'delta': 'hello',
      });
      final audio = AiGatewayRealtimeProtocol.mapEvent('xai', {
        'type': 'response.audio.delta',
        'delta': 'AQID',
      });
      final lifecycle = AiGatewayRealtimeProtocol.mapEvent('openai', {
        'type': 'session.created',
        'session': {'id': 'sess-1'},
      });
      final error = AiGatewayRealtimeProtocol.mapEvent('xai', {
        'type': 'error',
        'error': {'code': 'bad_request'},
      });
      final failedResponse = AiGatewayRealtimeProtocol.mapEvent('openai', {
        'type': 'response.failed',
        'response': {
          'error': {'code': 'server_error'},
        },
      });
      final transcript = AiGatewayRealtimeProtocol.mapEvent('openai', {
        'type': 'conversation.item.input_audio_transcription.completed',
        'transcript': 'recognized speech',
      });
      final transcriptionDelta = AiGatewayRealtimeProtocol.mapEvent('openai', {
        'type': 'conversation.item.input_audio_transcription.delta',
        'delta': 'recognized ',
      });
      final inputTranscript = AiGatewayRealtimeProtocol.mapEvent('openai', {
        'type': 'conversation.item.input_audio_transcription.completed',
        'transcript': 'recognized speech',
      });
      final generatedText = AiGatewayRealtimeProtocol.mapEvent('openai', {
        'type': 'response.output_text.done',
        'text': 'final answer',
      });
      final generatedTranscript = AiGatewayRealtimeProtocol.mapEvent('xai', {
        'type': 'response.output_audio_transcript.done',
        'transcript': 'spoken answer',
      });
      final functionCall = AiGatewayRealtimeProtocol.mapEvent('openai', {
        'type': 'response.function_call_arguments.done',
        'event_id': 'evt-1',
        'item_id': 'item-1',
        'call_id': 'call-1',
        'name': 'lookup',
        'arguments': '{"q":"x"}',
      });

      expect(text.kind, AiGatewayRealtimeEventKind.textDelta);
      expect(text.text, 'hello');
      expect(audio.kind, AiGatewayRealtimeEventKind.audioDelta);
      expect(audio.audioBase64, 'AQID');
      expect(lifecycle.kind, AiGatewayRealtimeEventKind.lifecycle);
      expect(error.kind, AiGatewayRealtimeEventKind.error);
      expect(failedResponse.kind, AiGatewayRealtimeEventKind.error);
      expect((failedResponse.raw['response'] as Map)['error'], {
        'code': 'server_error',
      });
      expect(transcript.kind, AiGatewayRealtimeEventKind.inputTranscript);
      expect(transcript.text, 'recognized speech');
      expect(
        transcriptionDelta.kind,
        AiGatewayRealtimeEventKind.inputTranscript,
      );
      expect(inputTranscript.kind, AiGatewayRealtimeEventKind.inputTranscript);
      expect(generatedText.kind, AiGatewayRealtimeEventKind.textComplete);
      expect(generatedText.text, 'final answer');
      expect(generatedTranscript.kind, AiGatewayRealtimeEventKind.textComplete);
      expect(generatedTranscript.text, 'spoken answer');
      expect(functionCall.kind, AiGatewayRealtimeEventKind.toolCall);
      expect(functionCall.raw['event_id'], 'evt-1');
      expect(functionCall.raw['item_id'], 'item-1');
      expect(error.raw['error'], {'code': 'bad_request'});
    });
  });
}
