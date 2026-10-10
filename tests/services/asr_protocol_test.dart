import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/asr_service.dart';

class _ProtocolAdapter implements HttpClientAdapter {
  _ProtocolAdapter({
    required this.responseBody,
    this.responseBodies = const [],
    this.statusCode = 200,
    this.responseContentType = Headers.jsonContentType,
  });

  final String responseBody;
  final List<String> responseBodies;
  final int statusCode;
  final String responseContentType;

  Uint8List? requestBody;
  final requestBodies = <Uint8List>[];
  int _responseIndex = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    requestBody = Uint8List.fromList(bytes);
    requestBodies.add(requestBody!);

    final body = responseBodies.isEmpty
        ? responseBody
        : responseBodies[_responseIndex++];
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [responseContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<({AsrResult result, AsrService service, _ProtocolAdapter adapter})>
    _transcribe({
  required String responseBody,
  String responseContentType = Headers.jsonContentType,
  String responseFormat = 'json',
  int statusCode = 200,
  AudioUploadMethod uploadMethod = AudioUploadMethod.multipart,
  List<String> responseBodies = const [],
  Uint8List? audioBytes,
  int maxFileSizeBytes = AsrConfig.defaultMaxAudioFileSizeBytes,
  String chunking = 'none',
  String fallbackMethod = 'none',
  Map<String, dynamic> extraTypeConfig = const {},
  List<CustomParam> customParams = const [],
}) async {
  final adapter = _ProtocolAdapter(
    responseBody: responseBody,
    responseBodies: responseBodies,
    statusCode: statusCode,
    responseContentType: responseContentType,
  );
  final dio = Dio()..httpClientAdapter = adapter;
  final config = AsrConfig(
    apiKey: 'test-key',
    host: 'https://api.test.com/audio/transcriptions',
    model: 'whisper-1',
    uploadMethod: uploadMethod,
    maxFileSizeBytes: maxFileSizeBytes,
    chunking: chunking,
    fallbackMethod: fallbackMethod,
    typeConfig: {
      'enableResponseFormat': true,
      'responseFormat': responseFormat,
      ...extraTypeConfig,
    },
    customParams: customParams,
  );
  final service = AsrService(config: config, dio: dio);
  final result = await service.transcribe(
    audioBytes: audioBytes ?? Uint8List.fromList([1, 2, 3]),
    audioFormat: 'wav',
  );
  return (result: result, service: service, adapter: adapter);
}

bool _multipartHasField(List<int> bytes, String name, String value) {
  return _multipartField(bytes, name) == value;
}

String? _multipartField(List<int> bytes, String name) {
  final body = utf8.decode(bytes, allowMalformed: true);
  final marker = 'name="$name"';
  var index = 0;
  while (index < body.length) {
    final fieldIndex = body.indexOf(marker, index);
    if (fieldIndex < 0) return null;
    final headerEnd = body.indexOf('\r\n\r\n', fieldIndex);
    if (headerEnd < 0) return null;
    final valueStart = headerEnd + 4;
    final valueEnd = body.indexOf('\r\n', valueStart);
    if (valueEnd < 0) return null;
    final value = body.substring(valueStart, valueEnd);
    if (value.isNotEmpty) return value;
    index = valueEnd + 2;
  }
  return null;
}

Uint8List _testWav(int dataSize) {
  final bytes = Uint8List(44 + dataSize);
  final data = ByteData.sublistView(bytes);
  bytes.setRange(0, 4, ascii.encode('RIFF'));
  data.setUint32(4, 36 + dataSize, Endian.little);
  bytes.setRange(8, 12, ascii.encode('WAVE'));
  bytes.setRange(12, 16, ascii.encode('fmt '));
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 8000, Endian.little);
  data.setUint32(28, 16000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  bytes.setRange(36, 40, ascii.encode('data'));
  data.setUint32(40, dataSize, Endian.little);
  return bytes;
}

void main() {
  group('ASR response protocol', () {
    test('extracts text from a JSON response', () async {
      final call = await _transcribe(responseBody: '{"text":"Hello world"}');

      expect(call.result.text, 'Hello world');
      expect(call.result.outputFormat, 'txt');
      expect(call.result.subtitle, isNull);
    });

    test('accepts a plain text response body', () async {
      final call = await _transcribe(
        responseBody: 'Recognized words',
        responseContentType: 'text/plain; charset=utf-8',
        responseFormat: 'text',
      );

      expect(call.result.text, 'Recognized words');
      expect(call.result.outputFormat, 'txt');
    });

    test('keeps SRT cues while exposing plain transcript text', () async {
      const srt = '1\n'
          '00:00:00,000 --> 00:00:01,200\n'
          'Hello\n\n'
          '2\n'
          '00:00:01,200 --> 00:00:02,400\n'
          'world';
      final call = await _transcribe(
        responseBody: srt,
        responseContentType: 'text/plain; charset=utf-8',
        responseFormat: 'srt',
      );

      expect(call.result.text, 'Hello world');
      expect(call.result.subtitle, srt);
      expect(call.result.outputFormat, 'srt');
      expect(call.result.segments, hasLength(2));
      expect(call.result.segments!.first.startSeconds, 0);
      expect(call.result.segments!.first.endSeconds, 1.2);
      expect(call.service.lastResponseData!['raw'], srt);
    });

    test('keeps VTT cues while exposing plain transcript text', () async {
      const vtt = 'WEBVTT\n\n'
          '00:00:00.000 --> 00:00:01.500 align:start\n'
          'Welcome to Stroom.';
      final call = await _transcribe(
        responseBody: vtt,
        responseContentType: 'text/vtt; charset=utf-8',
        responseFormat: 'vtt',
      );

      expect(call.result.text, 'Welcome to Stroom.');
      expect(call.result.subtitle, vtt);
      expect(call.result.outputFormat, 'vtt');
      expect(call.result.segments, hasLength(1));
      expect(call.result.segments!.single.startSeconds, 0);
      expect(call.result.segments!.single.endSeconds, 1.5);
    });

    test(
      'rebases SRT and VTT cue timestamps when transcribed in chunks',
      () async {
        for (final format in ['srt', 'vtt']) {
          String cue(String text) {
            final timeSeparator = format == 'srt' ? ',' : '.';
            final prefix = format == 'srt' ? '1\n' : '';
            return '$prefix'
                '00:00:00${timeSeparator}000 --> '
                '00:00:00${timeSeparator}001\n'
                '$text';
          }

          final call = await _transcribe(
            responseBody: cue('first'),
            responseBodies: [cue('first'), cue('second'), cue('third')],
            responseContentType: format == 'srt'
                ? 'text/plain; charset=utf-8'
                : 'text/vtt; charset=utf-8',
            responseFormat: format,
            audioBytes: _testWav(140),
            maxFileSizeBytes: 100,
            chunking: 'fixedSize',
            fallbackMethod: 'generic',
          );

          expect(call.result.text, 'first second third');
          expect(call.result.outputFormat, format);
          expect(call.result.segments, hasLength(3));
          expect(
            call.result.segments![1].startSeconds,
            closeTo(0.0035, 0.0001),
          );
          final subtitle = call.result.subtitle!;
          final firstCue = format == 'srt'
              ? '00:00:00,000 --> 00:00:00,001'
              : '00:00:00.000 --> 00:00:00.001';
          final secondCue = format == 'srt'
              ? '00:00:00,004 --> 00:00:00,005'
              : '00:00:00.004 --> 00:00:00.005';
          final thirdCue = format == 'srt'
              ? '00:00:00,007 --> 00:00:00,008'
              : '00:00:00.007 --> 00:00:00.008';
          expect(subtitle, contains(firstCue));
          expect(subtitle, contains(secondCue));
          expect(subtitle, contains(thirdCue));
          expect(
            subtitle.indexOf('first'),
            lessThan(subtitle.indexOf('second')),
          );
          expect(
            subtitle.indexOf('second'),
            lessThan(subtitle.indexOf('third')),
          );
          if (format == 'vtt') expect(subtitle, startsWith('WEBVTT'));
        }
      },
    );

    test('rebases JSON segment and word timestamps for each chunk', () async {
      final response = jsonEncode({
        'text': 'turn',
        'segments': [
          {'start': 0, 'end': 0.001, 'text': 'turn'},
        ],
        'words': [
          {'start': 0, 'end': 0.001, 'word': 'turn'},
        ],
      });
      final call = await _transcribe(
        responseBody: response,
        responseBodies: [response, response, response],
        responseFormat: 'verbose_json',
        audioBytes: _testWav(140),
        maxFileSizeBytes: 100,
        chunking: 'fixedSize',
        fallbackMethod: 'generic',
      );

      expect(call.result.segments, hasLength(3));
      expect(call.result.words, hasLength(3));
      expect(call.result.segments![1].startSeconds, closeTo(0.0035, 0.0001));
      expect(call.result.words![2].endSeconds, closeTo(0.008, 0.0001));
    });

    test(
      'chunk failure throws structured partial results and prompt context',
      () async {
        final adapter = _ProtocolAdapter(
          responseBody: '',
          responseBodies: [
            '{"text":"first chunk"}',
            '{"error":{"message":"middle failed"}}',
            '{"text":"last chunk"}',
          ],
        );
        final dio = Dio()..httpClientAdapter = adapter;
        final service = AsrService(
          config: AsrConfig(
            apiKey: 'test-key',
            host: 'https://api.test.com/audio/transcriptions',
            maxFileSizeBytes: 100,
            chunking: 'fixedSize',
            fallbackMethod: 'generic',
            typeConfig: {
              'enableResponseFormat': true,
              'responseFormat': 'json',
              'enablePrompt': true,
              'prompt': 'domain vocabulary',
            },
          ),
          dio: dio,
        );

        await expectLater(
          service.transcribe(audioBytes: _testWav(140), audioFormat: 'wav'),
          throwsA(
            isA<AsrChunkedTranscriptionException>()
                .having((e) => e.chunks, 'chunks', hasLength(3))
                .having((e) => e.isPartial, 'isPartial', isTrue)
                .having(
                  (e) => e.partialText,
                  'partialText',
                  'first chunk last chunk',
                )
                .having((e) => e.chunks[1].index, 'failed index', 1)
                .having(
                  (e) => e.chunks[1].status,
                  'failed status',
                  AsrChunkStatus.failed,
                )
                .having(
                  (e) => e.chunks[2].startSeconds,
                  'third chunk start',
                  closeTo(0.007, 0.0001),
                )
                .having(
                  (e) => e.chunks[2].endSeconds,
                  'third chunk end',
                  closeTo(0.00875, 0.0001),
                ),
          ),
        );

        final bodies = adapter.requestBodies
            .map((bytes) => utf8.decode(bytes, allowMalformed: true))
            .toList();
        expect(bodies[0], contains('domain vocabulary'));
        expect(bodies[1], contains('domain vocabulary'));
        expect(bodies[1], contains('first chunk'));
        expect(bodies[2], contains('domain vocabulary'));
        expect(bodies[2], isNot(contains('first chunk')));
        expect(bodies[2], isNot(contains('last chunk')));
      },
    );

    test('valid empty text response succeeds for every chunk', () async {
      final call = await _transcribe(
        responseBody: '{"text":""}',
        responseBodies: ['{"text":""}', '{"text":""}', '{"text":""}'],
        audioBytes: _testWav(140),
        maxFileSizeBytes: 100,
        chunking: 'fixedSize',
        fallbackMethod: 'generic',
      );

      expect(call.result.text, isEmpty);
      expect(call.result.chunks, hasLength(3));
      expect(
        call.result.chunks!.every((c) => c.status == AsrChunkStatus.succeeded),
        isTrue,
      );
    });

    test(
      'empty subtitle chunks succeed while malformed subtitles fail',
      () async {
        for (final format in ['srt', 'vtt']) {
          final empty = await _transcribe(
            responseBody: format == 'srt'
                ? ''
                : '\uFEFFWEBVTT\nKind: captions\nLanguage: en\n'
                    'X-TIMESTAMP-MAP=LOCAL:00:00:00.000,MPEGTS:0\n\n',
            responseBodies: List.filled(
              3,
              format == 'srt'
                  ? ''
                  : '\uFEFFWEBVTT\nKind: captions\nLanguage: en\n'
                      'X-TIMESTAMP-MAP=LOCAL:00:00:00.000,MPEGTS:0\n\n',
            ),
            responseContentType: format == 'srt'
                ? 'text/plain; charset=utf-8'
                : 'text/vtt; charset=utf-8',
            responseFormat: format,
            audioBytes: _testWav(140),
            maxFileSizeBytes: 100,
            chunking: 'fixedSize',
            fallbackMethod: 'generic',
          );
          expect(empty.result.text, isEmpty);
          expect(
            empty.result.chunks!.every(
              (c) => c.status == AsrChunkStatus.succeeded,
            ),
            isTrue,
          );
          expect(empty.result.subtitle, format == 'srt' ? isEmpty : 'WEBVTT');
          expect(empty.result.outputFormat, format);
        }

        final malformed = _transcribe(
          responseBody: 'not a subtitle',
          responseBodies: [
            'not a subtitle',
            'not a subtitle',
            'not a subtitle',
          ],
          responseContentType: 'text/plain; charset=utf-8',
          responseFormat: 'srt',
          audioBytes: _testWav(140),
          maxFileSizeBytes: 100,
          chunking: 'fixedSize',
          fallbackMethod: 'generic',
        );
        await expectLater(
          malformed,
          throwsA(
            isA<AsrChunkedTranscriptionException>()
                .having((e) => e.isPartial, 'isPartial', isFalse)
                .having((e) => e.partialText, 'partialText', isEmpty)
                .having(
                  (e) =>
                      e.chunks.every((c) => c.status == AsrChunkStatus.failed),
                  'all chunks failed',
                  isTrue,
                ),
          ),
        );

        final malformedVtt = _transcribe(
          responseBody: 'WEBVTT\nnot metadata or a cue',
          responseBodies: List.filled(3, 'WEBVTT\nnot metadata or a cue'),
          responseContentType: 'text/vtt; charset=utf-8',
          responseFormat: 'vtt',
          audioBytes: _testWav(140),
          maxFileSizeBytes: 100,
          chunking: 'fixedSize',
          fallbackMethod: 'generic',
        );
        await expectLater(
          malformedVtt,
          throwsA(
            isA<AsrChunkedTranscriptionException>().having(
              (e) => e.chunks.every((c) => c.status == AsrChunkStatus.failed),
              'all VTT chunks failed',
              isTrue,
            ),
          ),
        );
      },
    );

    test(
      'successful chunk concatenation retains repeated boundary words',
      () async {
        final call = await _transcribe(
          responseBody: '{"text":"again"}',
          responseBodies: [
            '{"text":"again"}',
            '{"text":"again"}',
            '{"text":"done"}',
          ],
          audioBytes: _testWav(140),
          maxFileSizeBytes: 100,
          chunking: 'fixedSize',
          fallbackMethod: 'generic',
        );

        expect(call.result.text, 'again again done');
        expect(call.result.chunks!.map((c) => c.index), [0, 1, 2]);
        expect(
          call.result.chunks!.map((c) => c.status),
          everyElement(AsrChunkStatus.succeeded),
        );
      },
    );

    test(
      'chunk prompt keeps supplementary Unicode characters intact',
      () async {
        final prefix = List.filled(99, 'a').join();
        final suffix = List.filled(99, 'b').join();
        final previousText = '$prefix😀$suffix';
        final adapter = _ProtocolAdapter(
          responseBody: '',
          responseBodies: [
            jsonEncode({'text': previousText}),
            jsonEncode({'text': 'next'}),
            jsonEncode({'text': 'last'}),
          ],
        );
        final dio = Dio()..httpClientAdapter = adapter;
        final service = AsrService(
          config: AsrConfig(
            apiKey: 'test-key',
            host: 'https://api.test.com/audio/transcriptions',
            maxFileSizeBytes: 100,
            chunking: 'fixedSize',
            fallbackMethod: 'generic',
            typeConfig: {
              'enableResponseFormat': true,
              'responseFormat': 'json',
            },
          ),
          dio: dio,
        );

        await service.transcribe(audioBytes: _testWav(140), audioFormat: 'wav');

        final prompt = _multipartField(adapter.requestBodies[1], 'prompt');
        expect(prompt, contains('😀'));
        expect(prompt, isNot(contains('�')));
        expect(prompt, contains(suffix));
        expect(prompt, isNot(contains(prefix)));
      },
    );

    test('extracts text and timing segments from verbose JSON', () async {
      final call = await _transcribe(
        responseBody: jsonEncode({
          'text': 'Turn left.',
          'segments': [
            {'start': 0.25, 'end': 1.75, 'text': 'Turn left.'},
          ],
        }),
        responseFormat: 'verbose_json',
      );

      expect(call.result.text, 'Turn left.');
      expect(call.result.outputFormat, 'txt');
      expect(call.result.segments, hasLength(1));
      expect(call.result.segments!.single.startSeconds, 0.25);
      expect(call.result.segments!.single.endSeconds, 1.75);
      expect(call.result.segments!.single.text, 'Turn left.');
    });

    test('preserves each requested verbose JSON timing granularity', () async {
      final call = await _transcribe(
        responseBody: jsonEncode({
          'text': 'Hello there.',
          'segments': [
            {'start': 0, 'end': 0.5, 'text': 'Hello there.'},
          ],
          'words': [
            {'start': 0, 'end': 0.2, 'word': 'Hello'},
            {'start': 0.2, 'end': 0.5, 'word': 'there.'},
          ],
        }),
        responseFormat: 'verbose_json',
        extraTypeConfig: {
          'enableTimestampGranularities': true,
          'timestampGranularities': ['segment', 'word'],
        },
      );

      expect(call.result.text, 'Hello there.');
      expect(call.result.segments, hasLength(1));
      expect(call.result.segments!.single.text, 'Hello there.');
      expect(call.result.words, hasLength(2));
      expect(call.result.words!.map((segment) => segment.text), [
        'Hello',
        'there.',
      ]);
      expect(call.result.words!.first.startSeconds, 0);
      expect(call.result.words!.last.endSeconds, 0.5);
    });

    test('rejects malformed JSON, API errors, and empty results', () async {
      await expectLater(
        _transcribe(responseBody: '{bad json'),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        _transcribe(
          responseBody: '{"error":{"message":"unsupported format"}}',
          statusCode: 400,
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        _transcribe(responseBody: '{"text":"  "}'),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'preserves JSON custom parameter types and protects file fields',
      () async {
        final call = await _transcribe(
          responseBody: '{"text":"ok"}',
          uploadMethod: AudioUploadMethod.base64Json,
          customParams: [
            CustomParam(
              paramName: 'metadata',
              type: 'json',
              defaultValue: '{"enabled":true,"labels":["a",2]}',
            ),
            CustomParam(
              paramName: 'attempts',
              type: 'number',
              defaultValue: '3',
            ),
            CustomParam(
              paramName: 'enabled',
              type: 'boolean',
              defaultValue: 'true',
            ),
            CustomParam(paramName: 'file', defaultValue: 'wrong-file'),
            CustomParam(paramName: 'model', defaultValue: 'wrong-model'),
            CustomParam(paramName: 'response_format', defaultValue: 'srt'),
          ],
        );

        final body = jsonDecode(utf8.decode(call.adapter.requestBody!))
            as Map<String, dynamic>;
        expect(body['metadata'], {
          'enabled': true,
          'labels': ['a', 2],
        });
        expect(body['attempts'], 3);
        expect(body['enabled'], true);
        expect(body['file'], base64Encode([1, 2, 3]));
        expect(body['model'], 'whisper-1');
        expect(body['response_format'], 'json');
      },
    );

    test(
      'serializes timestamp granularities as an array only for verbose JSON',
      () async {
        final verbose = await _transcribe(
          responseBody: '{"text":"ok"}',
          responseFormat: 'verbose_json',
          extraTypeConfig: {
            'enableTimestampGranularities': true,
            'timestampGranularities': 'word',
          },
        );
        final verboseBody = utf8.decode(verbose.adapter.requestBody!);
        expect(
          _multipartHasField(
            verbose.adapter.requestBody!,
            'timestamp_granularities[]',
            'word',
          ),
          isTrue,
        );
        expect(
          verboseBody,
          isNot(contains('name="timestamp_granularities"\r\n')),
        );
        expect(verbose.service.lastRequestBody!['timestamp_granularities'], [
          'word',
        ]);

        final jsonVerbose = await _transcribe(
          responseBody: '{"text":"ok"}',
          responseFormat: 'verbose_json',
          uploadMethod: AudioUploadMethod.base64Json,
          extraTypeConfig: {
            'enableTimestampGranularities': true,
            'timestampGranularities': 'word',
          },
        );
        final jsonBody =
            jsonDecode(utf8.decode(jsonVerbose.adapter.requestBody!))
                as Map<String, dynamic>;
        expect(jsonBody['timestamp_granularities'], ['word']);

        final standard = await _transcribe(
          responseBody: '{"text":"ok"}',
          responseFormat: 'json',
          extraTypeConfig: {
            'enableTimestampGranularities': true,
            'timestampGranularities': 'word',
          },
        );
        expect(
          utf8.decode(standard.adapter.requestBody!),
          isNot(contains('timestamp_granularities')),
        );
      },
    );

    test(
      'custom file params cannot replace the multipart audio part',
      () async {
        final call = await _transcribe(
          responseBody: '{"text":"ok"}',
          customParams: [
            CustomParam(paramName: 'file', defaultValue: 'wrong-file'),
            CustomParam(paramName: 'model', defaultValue: 'wrong-model'),
          ],
        );

        final body = call.adapter.requestBody!;
        final bodyText = utf8.decode(body, allowMalformed: true);
        expect(RegExp('name="file"').allMatches(bodyText), hasLength(1));
        expect(bodyText, contains('filename="audio.wav"'));
        expect(body, containsAllInOrder([1, 2, 3]));
        expect(_multipartHasField(body, 'model', 'whisper-1'), isTrue);
        expect(_multipartHasField(body, 'model', 'wrong-model'), isFalse);
      },
    );

    test(
      'multipart JSON custom parameters are encoded as one JSON value',
      () async {
        final call = await _transcribe(
          responseBody: '{"text":"ok"}',
          customParams: [
            CustomParam(
              paramName: 'metadata',
              type: 'json',
              defaultValue: '{"enabled":true,"labels":["a",2]}',
            ),
          ],
        );

        expect(
          _multipartHasField(
            call.adapter.requestBody!,
            'metadata',
            '{"enabled":true,"labels":["a",2]}',
          ),
          isTrue,
        );
      },
    );

    test(
      'JSON custom params do not encode configured multipart fields',
      () async {
        final call = await _transcribe(
          responseBody: '{"text":"ok"}',
          extraTypeConfig: {
            'enablePrompt': true,
            'prompt': 'configured prompt',
          },
          customParams: [
            CustomParam(
              paramName: 'prompt',
              type: 'json',
              defaultValue: '{"replacement":true}',
            ),
            CustomParam(
              paramName: 'model',
              type: 'json',
              defaultValue: '"wrong-model"',
            ),
            CustomParam(
              paramName: 'response_format',
              type: 'json',
              defaultValue: '"srt"',
            ),
          ],
        );

        expect(
          _multipartHasField(
            call.adapter.requestBody!,
            'prompt',
            'configured prompt',
          ),
          isTrue,
        );
        expect(
          _multipartHasField(call.adapter.requestBody!, 'model', 'whisper-1'),
          isTrue,
        );
        expect(
          _multipartHasField(
            call.adapter.requestBody!,
            'response_format',
            'json',
          ),
          isTrue,
        );
      },
    );

    test(
      'chunk prompts preserve JSON custom prompt values without encoding',
      () async {
        final call = await _transcribe(
          responseBody: '{"text":"first chunk"}',
          responseBodies: ['{"text":"first chunk"}', '{"text":"second chunk"}'],
          audioBytes: _testWav(100),
          maxFileSizeBytes: 100,
          chunking: 'fixedSize',
          fallbackMethod: 'generic',
          customParams: [
            CustomParam(
              paramName: 'prompt',
              type: 'json',
              defaultValue: '"custom prompt"',
            ),
          ],
        );

        expect(
          _multipartHasField(
            call.adapter.requestBody!,
            'prompt',
            'custom prompt\nfirst chunk',
          ),
          isTrue,
        );
        expect(
          _multipartHasField(
            call.adapter.requestBody!,
            'prompt',
            '"first chunk"',
          ),
          isFalse,
        );
      },
    );

    test(
      'chunk prompt carryover accepts structured JSON custom prompts',
      () async {
        final call = await _transcribe(
          responseBody: '{"text":"first chunk"}',
          responseBodies: ['{"text":"first chunk"}', '{"text":"second chunk"}'],
          audioBytes: _testWav(100),
          maxFileSizeBytes: 100,
          chunking: 'fixedSize',
          fallbackMethod: 'generic',
          customParams: [
            CustomParam(
              paramName: 'prompt',
              type: 'json',
              defaultValue: '{"vocabulary":["Stroom"]}',
            ),
          ],
        );

        expect(call.result.text, 'first chunk second chunk');
        expect(
          _multipartField(call.adapter.requestBodies[1], 'prompt'),
          '{"vocabulary":["Stroom"]}\nfirst chunk',
        );
      },
    );

    test(
      'failed chunk does not lose structured prompt encoding metadata',
      () async {
        final adapter = _ProtocolAdapter(
          responseBody: '',
          responseBodies: [
            '{"text":"first chunk"}',
            '{"error":{"message":"middle failed"}}',
            '{"text":"last chunk"}',
          ],
        );
        final service = AsrService(
          config: AsrConfig(
            apiKey: 'test-key',
            host: 'https://api.test.com/audio/transcriptions',
            maxFileSizeBytes: 100,
            chunking: 'fixedSize',
            fallbackMethod: 'generic',
            customParams: [
              CustomParam(
                paramName: 'prompt',
                type: 'json',
                defaultValue: '{"vocabulary":["Stroom"]}',
              ),
            ],
          ),
          dio: Dio()..httpClientAdapter = adapter,
        );

        await expectLater(
          service.transcribe(audioBytes: _testWav(140), audioFormat: 'wav'),
          throwsA(
            isA<AsrChunkedTranscriptionException>().having(
              (error) => error.chunks[1].status,
              'middle chunk status',
              AsrChunkStatus.failed,
            ),
          ),
        );
        expect(adapter.requestBodies, hasLength(3));
        expect(
          _multipartField(adapter.requestBodies[2], 'prompt'),
          '{"vocabulary":["Stroom"]}',
        );
      },
    );
  });
}
