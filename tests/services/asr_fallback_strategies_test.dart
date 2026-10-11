import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:stroom/services/asr_service.dart';

/// A mock [HttpClientAdapter] that maps paths to responses and records every
/// request (method, content type, body bytes/string).
class _RouteAdapter implements HttpClientAdapter {
  final Map<String, ResponseBody Function(RequestOptions, List<int>?)> _routes =
      {};
  final List<Map<String, dynamic>> _requests = [];

  void onPost(
      String path, ResponseBody Function(RequestOptions, List<int>?) handler) {
    _routes[path] = handler;
  }

  List<Map<String, dynamic>> get requests => _requests;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    List<int> bodyBytes = [];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bodyBytes.addAll(chunk);
      }
    }

    String path = options.path;
    if (path.startsWith('http')) {
      path = Uri.parse(path).path;
    }

    _requests.add({
      'method': options.method,
      'path': path,
      'contentType': options.contentType,
      'bodyBytes': Uint8List.fromList(bodyBytes),
      'bodyString': utf8.decode(bodyBytes, allowMalformed: true),
    });

    final handler = _routes[path];
    if (handler != null) {
      return handler(options, bodyBytes);
    }

    return ResponseBody.fromString(
      '{"error":{"message":"Not found"}}',
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Find the first index of [needle] in [haystack], or -1.
int _indexOfSequence(List<int> haystack, List<int> needle) {
  if (needle.isEmpty || needle.length > haystack.length) return -1;
  for (int i = 0; i <= haystack.length - needle.length; i++) {
    var match = true;
    for (int j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) return i;
  }
  return -1;
}

/// Build a minimal 16-bit PCM WAV file (mono by default).
Uint8List _buildWav({
  int seconds = 1,
  int sampleRate = 8000,
  int channels = 1,
  int amplitude = 8000,
}) {
  final dataBytes = sampleRate * seconds * 2 * channels;
  final total = 44 + dataBytes;
  final bytes = Uint8List(total);
  final bd = ByteData.view(bytes.buffer);

  void w4(int off, String s) {
    for (int i = 0; i < 4; i++) {
      bytes[off + i] = s.codeUnitAt(i);
    }
  }

  w4(0, 'RIFF');
  bd.setUint32(4, total - 8, Endian.little);
  w4(8, 'WAVE');
  w4(12, 'fmt ');
  bd.setUint32(16, 16, Endian.little);
  bd.setUint16(20, 1, Endian.little); // PCM
  bd.setUint16(22, channels, Endian.little);
  bd.setUint32(24, sampleRate, Endian.little);
  bd.setUint32(28, sampleRate * 2 * channels, Endian.little);
  bd.setUint16(32, 2 * channels, Endian.little);
  bd.setUint16(34, 16, Endian.little);
  w4(36, 'data');
  bd.setUint32(40, dataBytes, Endian.little);

  // Non-silent sine wave so silence-based processing is deterministic.
  for (int i = 0; i < sampleRate * seconds; i++) {
    final v = (sin(i * 0.05) * amplitude).round();
    bd.setInt16(44 + i * 2 * channels, v, Endian.little);
    if (channels == 2) {
      bd.setInt16(44 + i * 2 * channels + 2, v, Endian.little);
    }
  }
  return bytes;
}

Uint8List _buildNoisyWav({required int seconds, int sampleRate = 1}) {
  final wav = _buildWav(seconds: seconds, sampleRate: sampleRate);
  final data = ByteData.view(wav.buffer);
  var state = 0x12345678;
  for (var i = 0; i < seconds * sampleRate; i++) {
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    data.setInt16(44 + i * 2, (state & 0xffff) - 32768, Endian.little);
  }
  return wav;
}

int _wavPcmDataSize(Uint8List wav) {
  expect(_indexOfSequence(wav, 'RIFF'.codeUnits), 0);
  expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
  return ByteData.sublistView(wav).getUint32(40, Endian.little);
}

int _multipartWavPcmDataSize(Uint8List body) {
  final riffIndex = _indexOfSequence(body, 'RIFF'.codeUnits);
  expect(riffIndex, isNonNegative, reason: 'request must include its WAV part');
  final wav = ByteData.sublistView(body, riffIndex, riffIndex + 44);
  return wav.getUint32(40, Endian.little);
}

void _expectChunkCoverage(AsrResult result, int requestCount, double duration) {
  final chunks = result.chunks;
  expect(chunks, isNotNull);
  expect(chunks, hasLength(requestCount));
  final expectedChunks = chunks!;
  expect(expectedChunks.first.startSeconds, 0);
  for (var i = 1; i < expectedChunks.length; i++) {
    expect(expectedChunks[i].startSeconds, expectedChunks[i - 1].endSeconds);
  }
  expect(expectedChunks.last.endSeconds, closeTo(duration, 1e-9));
}

Uint8List _appendJunkChunk(Uint8List wav, int payloadBytes) {
  final paddedPayloadBytes = payloadBytes + payloadBytes % 2;
  final result = Uint8List(wav.length + 8 + paddedPayloadBytes);
  result.setRange(0, wav.length, wav);
  result.setRange(wav.length, wav.length + 4, 'JUNK'.codeUnits);
  final data = ByteData.view(result.buffer);
  data.setUint32(wav.length + 4, payloadBytes, Endian.little);
  data.setUint32(4, result.length - 8, Endian.little);
  return result;
}

void main() {
  const host = 'https://api.test.com/audio/transcriptions';

  Dio testDio(_RouteAdapter adapter) =>
      Dio(BaseOptions(baseUrl: 'https://api.test.com'))
        ..httpClientAdapter = adapter;

  ResponseBody ok(String text) => ResponseBody.fromString(
        '{"text":"$text"}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );

  ResponseBody err500() => ResponseBody.fromString(
        '{"error":{"message":"boom"}}',
        500,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );

  group('ASR fallback strategies', () {
    test('fallbackMethod=none rejects over-limit files without any request',
        () async {
      final adapter = _RouteAdapter();
      final service = AsrService(
        config: const AsrConfig(
          apiKey: 'k',
          host: host,
          maxFileSizeBytes: 1024,
          fallbackMethod: 'none',
        ),
        dio: testDio(adapter),
      );

      await expectLater(
        () => service.transcribe(
          audioBytes: _buildWav(seconds: 1), // 16000 bytes > 1024
          audioFormat: 'wav',
        ),
        throwsA(predicate(
            (e) => e is Exception && e.toString().contains('文件大小超过限制'))),
      );
      expect(adapter.requests, isEmpty);
    });

    test('fallback threshold uses original size before resample preprocessing',
        () async {
      final adapter = _RouteAdapter();
      adapter.onPost(
        '/audio/transcriptions',
        (options, bodyBytes) => ok('sent'),
      );
      final service = AsrService(
        config: const AsrConfig(
          apiKey: 'k',
          host: host,
          uploadMethod: AudioUploadMethod.multipart,
          maxFileSizeBytes: 100 * 1024,
          preprocessing: 'resampleMono',
          fallbackMethod: 'none',
        ),
        dio: testDio(adapter),
      );
      final sourceBytes = _buildWav(
        seconds: 2,
        sampleRate: 48000,
        channels: 2,
      );

      Object? thrown;
      try {
        await service.transcribe(audioBytes: sourceBytes, audioFormat: 'wav');
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isA<Exception>());
      final errorMessage = thrown.toString();
      expect(
        errorMessage,
        contains('超限项: 原始音频 ${sourceBytes.length} 字节 > 102400 字节'),
      );
      expect(errorMessage, isNot(matches(RegExp(r'请求体 \d+ 字节 > 102400 字节'))));
      expect(sourceBytes.length, greaterThan(100 * 1024));
      expect(adapter.requests, isEmpty);
    });

    test('one-frame fallback ignores oversized ancillary WAV metadata',
        () async {
      final adapter = _RouteAdapter();
      adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
        return ok('one frame sent');
      });
      final service = AsrService(
        config: const AsrConfig(
          apiKey: 'k',
          host: host,
          uploadMethod: AudioUploadMethod.multipart,
          maxFileSizeBytes: 512,
          chunking: 'fixedSize',
          fallbackMethod: 'generic',
        ),
        dio: testDio(adapter),
      );
      final sourceBytes = _appendJunkChunk(
        _buildWav(seconds: 1, sampleRate: 1),
        1024,
      );

      final result = await service.transcribe(
        audioBytes: sourceBytes,
        audioFormat: 'wav',
      );

      expect(result.text, 'one frame sent');
      expect(sourceBytes.length, greaterThan(512));
      expect(adapter.requests, hasLength(1));
      expect(
        (adapter.requests.single['bodyBytes'] as Uint8List).length,
        lessThanOrEqualTo(512),
      );
    });

    test(
      'specific base64 fallback respects the complete request body budget',
      () async {
        final audioBytes = _buildWav(seconds: 1);
        final expectedBase64BodyBytes = utf8
            .encode(
              jsonEncode({
                'model': 'whisper-1',
                'response_format': 'json',
                'file': base64Encode(audioBytes),
              }),
            )
            .length;
        final adapter = _RouteAdapter();
        adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
          return ok('base64 fallback works');
        });
        final service = AsrService(
          config: const AsrConfig(
            apiKey: 'k',
            host: host,
            uploadMethod: AudioUploadMethod.multipart,
            maxFileSizeBytes: 1024,
            fallbackMethod: 'specific',
          ),
          dio: testDio(adapter),
        );

        await expectLater(
          () => service.transcribe(audioBytes: audioBytes, audioFormat: 'wav'),
          throwsA(
            predicate(
              (e) =>
                  e is Exception &&
                  e.toString().contains('请求体 $expectedBase64BodyBytes 字节') &&
                  e.toString().contains('Base64 与 JSON'),
            ),
          ),
        );

        // Base64 expansion exceeds the same transport budget; no fallback
        // request may exceed the configured cap.
        expect(adapter.requests, isEmpty);
      },
    );

    test(
        'fallbackMethod=specific with base64Json primary has no specific '
        'fallback and rejects', () async {
      final adapter = _RouteAdapter();
      final service = AsrService(
        config: const AsrConfig(
          apiKey: 'k',
          host: host,
          uploadMethod: AudioUploadMethod.base64Json,
          maxFileSizeBytes: 1024,
          fallbackMethod: 'specific',
        ),
        dio: testDio(adapter),
      );

      await expectLater(
        () => service.transcribe(
          audioBytes: _buildWav(seconds: 1),
          audioFormat: 'wav',
        ),
        throwsA(predicate(
            (e) => e is Exception && e.toString().contains('文件大小超过限制'))),
      );
      // No request: multipart does not help an over-limit file.
      expect(adapter.requests, isEmpty);
    });

    test('fallbackMethod=generic compresses over-limit WAV to FLAC and uploads',
        () async {
      final adapter = _RouteAdapter();
      adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
        return ok('flac ok');
      });
      final service = AsrService(
        config: const AsrConfig(
          apiKey: 'k',
          host: host,
          uploadMethod: AudioUploadMethod.multipart,
          maxFileSizeBytes: 64 * 1024,
          compression: 'flac',
          fallbackMethod: 'generic',
        ),
        dio: testDio(adapter),
      );

      // 10s @ 8kHz mono 16-bit = 160KB > 64KB limit.
      final result = await service.transcribe(
        audioBytes: _buildWav(seconds: 10),
        audioFormat: 'wav',
      );

      expect(result.text, 'flac ok');
      expect(adapter.requests.length, 1);
      final bodyStr = adapter.requests.first['bodyString'] as String;
      // The compressed file is sent as audio.flac.
      expect(bodyStr, contains('audio.flac'));
    });

    test('fallbackMethod=generic wraps ADPCM in a WAV container', () async {
      final adapter = _RouteAdapter();
      adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
        return ok('adpcm ok');
      });
      final service = AsrService(
        config: const AsrConfig(
          apiKey: 'k',
          host: host,
          uploadMethod: AudioUploadMethod.multipart,
          maxFileSizeBytes: 64 * 1024,
          compression: 'adpcm',
          fallbackMethod: 'generic',
        ),
        dio: testDio(adapter),
      );

      final result = await service.transcribe(
        audioBytes: _buildWav(seconds: 10),
        audioFormat: 'wav',
      );

      expect(result.text, 'adpcm ok');
      expect(adapter.requests.length, 1);
      final bodyStr = adapter.requests.first['bodyString'] as String;
      // Raw ADPCM nibbles must NOT be uploaded — the file is a WAV container.
      expect(bodyStr, contains('audio.wav'));
      expect(bodyStr, isNot(contains('audio/adpcm')));
      // The uploaded payload is a real WAV with WAVE_FORMAT_IMA_ADPCM (0x11).
      final bodyBytes = adapter.requests.first['bodyBytes'] as Uint8List;
      final riffIdx = _indexOfSequence(bodyBytes, 'RIFF'.codeUnits);
      expect(riffIdx, isNonNegative, reason: 'payload must contain RIFF magic');
      expect(bodyBytes[riffIdx + 20], 0x11,
          reason: 'payload must be WAVE_FORMAT_IMA_ADPCM (0x11)');
    });

    test(
        'fallbackMethod=generic chunking splits over-limit WAV into '
        'multiple uploads and concatenates results', () async {
      final adapter = _RouteAdapter();
      var call = 0;
      adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
        call++;
        return ok('chunk $call');
      });
      final service = AsrService(
        config: const AsrConfig(
          apiKey: 'k',
          host: host,
          uploadMethod: AudioUploadMethod.multipart,
          maxFileSizeBytes: 64 * 1024,
          chunking: 'fixedSize',
          fallbackMethod: 'generic',
        ),
        dio: testDio(adapter),
      );

      // The request body includes multipart fields and boundaries, so the
      // measured transport budget can require more than three PCM chunks.
      final sourceAudio = _buildWav(seconds: 10);
      final result = await service.transcribe(
        audioBytes: sourceAudio,
        audioFormat: 'wav',
      );

      expect(adapter.requests.length, greaterThan(1));
      expect(
        result.text,
        List.generate(
          adapter.requests.length,
          (index) => 'chunk ${index + 1}',
        ).join(' '),
      );
      for (final req in adapter.requests) {
        expect(req['contentType'], contains('multipart/form-data'));
        expect(
          (req['bodyBytes'] as Uint8List).length,
          lessThanOrEqualTo(64 * 1024),
        );
      }
      final uploadedPcmBytes = adapter.requests.fold<int>(
        0,
        (sum, request) =>
            sum + _multipartWavPcmDataSize(request['bodyBytes'] as Uint8List),
      );
      expect(uploadedPcmBytes, _wavPcmDataSize(sourceAudio));
      _expectChunkCoverage(result, adapter.requests.length, 10);
    });

    test('chunked transcription throws when every chunk fails', () async {
      final adapter = _RouteAdapter();
      adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
        return err500();
      });
      final service = AsrService(
        config: const AsrConfig(
          apiKey: 'k',
          host: host,
          uploadMethod: AudioUploadMethod.multipart,
          maxFileSizeBytes: 64 * 1024,
          chunking: 'fixedSize',
          fallbackMethod: 'generic',
        ),
        dio: testDio(adapter),
      );

      await expectLater(
        () => service.transcribe(
          audioBytes: _buildWav(seconds: 10),
          audioFormat: 'wav',
        ),
        throwsA(predicate(
            (e) => e is Exception && e.toString().contains('切块转写全部失败'))),
      );
    });

    test(
      'fallbackMethod=all falls back to generic when specific fails',
      () async {
        final adapter = _RouteAdapter();
        adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
          return ok('generic saved it');
        });
        final service = AsrService(
          config: const AsrConfig(
            apiKey: 'k',
            host: host,
            uploadMethod: AudioUploadMethod.multipart,
            maxFileSizeBytes: 64 * 1024,
            compression: 'flac',
            fallbackMethod: 'all',
          ),
          dio: testDio(adapter),
        );

        final sourceAudio = _buildWav(seconds: 10);
        final result = await service.transcribe(
          audioBytes: sourceAudio,
          audioFormat: 'wav',
        );

        expect(result.text, 'generic saved it');
        // The oversized base64 attempt is rejected locally, then the generic
        // FLAC fallback fits in one multipart request.
        expect(adapter.requests.length, 1);
        expect(
          adapter.requests.single['contentType'],
          contains('multipart/form-data'),
        );
        expect(
          adapter.requests.single['bodyString'] as String,
          contains('audio.flac'),
        );
        expect(
          (adapter.requests.single['bodyBytes'] as Uint8List).length,
          lessThanOrEqualTo(64 * 1024),
        );
      },
    );

    test(
      'fallbackMethod=all reaches generic after a Base64 provider failure',
      () async {
        final audioBytes = _buildNoisyWav(seconds: 1, sampleRate: 120);
        final base64BodyBytes = utf8
            .encode(
              jsonEncode({
                'model': 'whisper-1',
                'response_format': 'json',
                'file': base64Encode(audioBytes),
              }),
            )
            .length;
        final measurementAdapter = _RouteAdapter();
        measurementAdapter.onPost('/audio/transcriptions', (options, body) {
          return ok('measure compressed body');
        });
        final measurementService = AsrService(
          config: const AsrConfig(
            apiKey: 'k',
            host: host,
            uploadMethod: AudioUploadMethod.multipart,
            maxFileSizeBytes: 64 * 1024,
            compression: 'flac',
            fallbackMethod: 'none',
          ),
          dio: testDio(measurementAdapter),
        );
        await measurementService.transcribe(
          audioBytes: audioBytes,
          audioFormat: 'wav',
        );
        final fullCompressedBodyBytes =
            (measurementAdapter.requests.single['bodyBytes'] as Uint8List)
                .length;
        expect(
          fullCompressedBodyBytes,
          greaterThan(base64BodyBytes),
          reason: 'the compressed whole-file request must trigger fallback',
        );

        final adapter = _RouteAdapter();
        var requestNumber = 0;
        adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
          requestNumber++;
          return requestNumber == 1
              ? err500()
              : ok('generic chunk $requestNumber');
        });
        final service = AsrService(
          config: AsrConfig(
            apiKey: 'k',
            host: host,
            uploadMethod: AudioUploadMethod.multipart,
            maxFileSizeBytes: base64BodyBytes,
            compression: 'flac',
            chunking: 'fixedSize',
            fallbackMethod: 'all',
          ),
          dio: testDio(adapter),
        );

        final result = await service.transcribe(
          audioBytes: audioBytes,
          audioFormat: 'wav',
        );

        expect(adapter.requests, hasLength(10));
        final specificRequest = adapter.requests.first;
        expect(specificRequest['contentType'], contains('application/json'));
        expect(
          (specificRequest['bodyBytes'] as Uint8List).length,
          base64BodyBytes,
        );
        final specificBody = jsonDecode(specificRequest['bodyString'] as String)
            as Map<String, dynamic>;
        expect(base64Decode(specificBody['file'] as String), audioBytes);

        final genericRequests = adapter.requests.skip(1).toList();
        expect(genericRequests, hasLength(9));
        for (final request in genericRequests) {
          expect(request['contentType'], contains('multipart/form-data'));
          final requestBytes = request['bodyBytes'] as Uint8List;
          expect(requestBytes.length, lessThanOrEqualTo(base64BodyBytes));
          expect(
              _indexOfSequence(requestBytes, 'fLaC'.codeUnits), isNonNegative);
        }
        expect(
          result.text,
          List.generate(
            9,
            (index) => 'generic chunk ${index + 2}',
          ).join(' '),
        );
        _expectChunkCoverage(result, 9, 1);
      },
    );

    test(
      'fallbackMethod=all retains a Base64 provider failure when generic cannot fit',
      () async {
        final audioBytes = Uint8List.fromList([1, 2, 3]);
        final measurementAdapter = _RouteAdapter();
        measurementAdapter.onPost('/audio/transcriptions', (
          options,
          bodyBytes,
        ) {
          return ok('measure multipart body');
        });
        final measurementService = AsrService(
          config: const AsrConfig(
            apiKey: 'k',
            host: host,
            uploadMethod: AudioUploadMethod.multipart,
            maxFileSizeBytes: 1024,
            fallbackMethod: 'none',
          ),
          dio: testDio(measurementAdapter),
        );
        await measurementService.transcribe(
          audioBytes: audioBytes,
          audioFormat: 'mp3',
        );
        final multipartBodyBytes =
            (measurementAdapter.requests.single['bodyBytes'] as Uint8List)
                .length;
        final limit = multipartBodyBytes - 1;
        final base64BodyBytes = utf8
            .encode(
              jsonEncode({
                'model': 'whisper-1',
                'response_format': 'json',
                'file': base64Encode(audioBytes),
              }),
            )
            .length;
        expect(audioBytes.length, lessThan(limit));
        expect(base64BodyBytes, lessThanOrEqualTo(limit));

        final adapter = _RouteAdapter();
        adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
          return err500();
        });
        final service = AsrService(
          config: AsrConfig(
            apiKey: 'k',
            host: host,
            uploadMethod: AudioUploadMethod.multipart,
            maxFileSizeBytes: limit,
            fallbackMethod: 'all',
          ),
          dio: testDio(adapter),
        );

        Object? thrown;
        try {
          await service.transcribe(audioBytes: audioBytes, audioFormat: 'mp3');
        } catch (e) {
          thrown = e;
        }

        expect(thrown, isA<Exception>());
        expect(thrown.toString(), contains('500'));
        expect(thrown.toString(), contains('非 WAV 音频不能安全切分'));
        expect(adapter.requests, hasLength(1));
        expect(
          adapter.requests.single['contentType'],
          contains('application/json'),
        );
        expect(
          (adapter.requests.single['bodyBytes'] as Uint8List).length,
          lessThanOrEqualTo(limit),
        );
      },
    );

    test(
      'fallbackMethod=all retains Base64 failure when no PCM frame fits',
      () async {
        final audioBytes = _buildWav(seconds: 1, sampleRate: 10);
        final expectedBase64BodyBytes = utf8
            .encode(
              jsonEncode({
                'model': 'whisper-1',
                'response_format': 'json',
                'file': base64Encode(audioBytes),
              }),
            )
            .length;
        final measurementAdapter = _RouteAdapter();
        measurementAdapter.onPost('/audio/transcriptions', (
          options,
          bodyBytes,
        ) {
          return ok('measure multipart body');
        });
        final measurementService = AsrService(
          config: const AsrConfig(
            apiKey: 'k',
            host: host,
            uploadMethod: AudioUploadMethod.multipart,
            maxFileSizeBytes: 1024,
            fallbackMethod: 'none',
          ),
          dio: testDio(measurementAdapter),
        );
        await measurementService.transcribe(
          audioBytes: audioBytes,
          audioFormat: 'wav',
        );
        final multipartBodyBytes =
            (measurementAdapter.requests.single['bodyBytes'] as Uint8List)
                .length;
        expect(audioBytes.length, lessThan(expectedBase64BodyBytes));
        expect(multipartBodyBytes, greaterThan(expectedBase64BodyBytes));

        final adapter = _RouteAdapter();
        adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
          return err500();
        });
        final service = AsrService(
          config: AsrConfig(
            apiKey: 'k',
            host: host,
            uploadMethod: AudioUploadMethod.multipart,
            maxFileSizeBytes: expectedBase64BodyBytes,
            compression: 'adpcm',
            chunking: 'fixedSize',
            fallbackMethod: 'all',
          ),
          dio: testDio(adapter),
        );

        Object? thrown;
        try {
          await service.transcribe(audioBytes: audioBytes, audioFormat: 'wav');
        } catch (e) {
          thrown = e;
        }

        expect(thrown, isA<Exception>());
        expect(thrown.toString(), contains('500'));
        expect(thrown.toString(), contains('单个 PCM 帧'));
        expect(adapter.requests, hasLength(1));
        expect(
          adapter.requests.single['contentType'],
          contains('application/json'),
        );
      },
    );

    test(
      'fallbackMethod=all reports when the primary Base64 method has no specific fallback',
      () async {
        final audioBytes = _buildWav(seconds: 1, sampleRate: 1);
        final base64BodyBytes = utf8
            .encode(
              jsonEncode({
                'model': 'whisper-1',
                'response_format': 'json',
                'file': base64Encode(audioBytes),
              }),
            )
            .length;
        final adapter = _RouteAdapter();
        final service = AsrService(
          config: AsrConfig(
            apiKey: 'k',
            host: host,
            uploadMethod: AudioUploadMethod.base64Json,
            maxFileSizeBytes: base64BodyBytes - 1,
            chunking: 'fixedSize',
            fallbackMethod: 'all',
          ),
          dio: testDio(adapter),
        );

        Object? thrown;
        try {
          await service.transcribe(audioBytes: audioBytes, audioFormat: 'wav');
        } catch (e) {
          thrown = e;
        }

        expect(thrown, isA<Exception>());
        expect(thrown.toString(), contains('没有可用的特定兜底'));
        expect(thrown.toString(), contains('通用兜底未能'));
        expect(thrown.toString(), contains('单个 PCM 帧'));
        expect(thrown.toString(), isNot(contains('特定与通用兜底均')));
        expect(adapter.requests, isEmpty);
      },
    );

    test(
      'fallbackMethod=all preserves a generic provider error after compression',
      () async {
        final audioBytes = _buildWav(seconds: 1, sampleRate: 400);
        final adapter = _RouteAdapter();
        adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
          return err500();
        });
        final service = AsrService(
          config: AsrConfig(
            apiKey: 'k',
            host: host,
            uploadMethod: AudioUploadMethod.base64Json,
            maxFileSizeBytes: 700,
            compression: 'adpcm',
            chunking: 'none',
            fallbackMethod: 'all',
          ),
          dio: testDio(adapter),
        );

        Object? thrown;
        try {
          await service.transcribe(audioBytes: audioBytes, audioFormat: 'wav');
        } catch (e) {
          thrown = e;
        }

        expect(thrown, isA<Exception>());
        expect(thrown.toString(), contains('HTTP 500'));
        expect(thrown.toString(), isNot(contains('文件大小超过限制')));
        expect(adapter.requests, hasLength(1));
        expect(
          adapter.requests.single['contentType'],
          contains('application/json'),
        );
        expect(
          (adapter.requests.single['bodyBytes'] as Uint8List).length,
          lessThanOrEqualTo(700),
        );
      },
    );

    test(
      'fallbackMethod=all preserves partial chunk results when a chunk fails',
      () async {
        final adapter = _RouteAdapter();
        adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
          return adapter.requests.length == 1 ? ok('first chunk') : err500();
        });
        final service = AsrService(
          config: const AsrConfig(
            apiKey: 'k',
            host: host,
            uploadMethod: AudioUploadMethod.base64Json,
            maxFileSizeBytes: 800,
            chunking: 'fixedSize',
            fallbackMethod: 'all',
          ),
          dio: testDio(adapter),
        );

        AsrChunkedTranscriptionException? thrown;
        try {
          await service.transcribe(
            audioBytes: _buildWav(seconds: 1, sampleRate: 500),
            audioFormat: 'wav',
          );
        } catch (e) {
          if (e is AsrChunkedTranscriptionException) thrown = e;
        }

        expect(thrown, isNotNull);
        expect(thrown!.isPartial, isTrue);
        expect(thrown.partialText, 'first chunk');
        expect(adapter.requests, hasLength(2));
        for (final request in adapter.requests) {
          expect(
            (request['bodyBytes'] as Uint8List).length,
            lessThanOrEqualTo(800),
          );
        }
      },
    );

    test(
      'fixed-duration chunk cap stops a low-rate WAV during chunk creation',
      () async {
        final adapter = _RouteAdapter();
        final service = AsrService(
          config: const AsrConfig(
            apiKey: 'k',
            host: host,
            uploadMethod: AudioUploadMethod.multipart,
            maxFileSizeBytes: 512,
            chunking: 'fixedDuration',
            fallbackMethod: 'generic',
          ),
          dio: testDio(adapter),
        );
        final audioBytes = _buildWav(seconds: 600001, sampleRate: 1);

        await expectLater(
          () => service.transcribe(audioBytes: audioBytes, audioFormat: 'wav'),
          throwsA(
            predicate((e) => e is Exception && e.toString().contains('10000')),
          ),
        );

        expect(adapter.requests, isEmpty);
      },
    );

    test(
      'base64 upload chunking keeps each base64 payload within the limit',
      () async {
        final adapter = _RouteAdapter();
        var call = 0;
        adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
          call++;
          return ok('b64 chunk $call');
        });
        const limit = 64 * 1024;
        final service = AsrService(
          config: const AsrConfig(
            apiKey: 'k',
            host: host,
            uploadMethod: AudioUploadMethod.base64Json,
            maxFileSizeBytes: limit,
            chunking: 'fixedSize',
            fallbackMethod: 'generic',
          ),
          dio: testDio(adapter),
        );

        final sourceAudio = _buildWav(seconds: 10);
        final result = await service.transcribe(
          audioBytes: sourceAudio,
          audioFormat: 'wav',
        );

        // The complete JSON body, including Base64 and request fields, stays
        // within the configured transport budget.
        expect(adapter.requests.length, greaterThan(1));
        expect(
          result.text,
          List.generate(
            adapter.requests.length,
            (index) => 'b64 chunk ${index + 1}',
          ).join(' '),
        );
        for (final req in adapter.requests) {
          final body =
              jsonDecode(req['bodyString'] as String) as Map<String, dynamic>;
          final file = body['file'] as String;
          // The base64 STRING length == payload bytes — must stay within the
          // provider's file size limit.
          expect(
            file.length,
            lessThanOrEqualTo(limit),
            reason: 'base64 payload must stay within the file limit',
          );
          expect(
            (req['bodyBytes'] as Uint8List).length,
            lessThanOrEqualTo(limit),
            reason: 'complete JSON body must stay within the configured budget',
          );
        }
        final uploadedPcmBytes = adapter.requests.fold<int>(
          0,
          (sum, request) {
            final body = jsonDecode(request['bodyString'] as String)
                as Map<String, dynamic>;
            final chunk = Uint8List.fromList(
              base64Decode(body['file'] as String),
            );
            return sum + _wavPcmDataSize(chunk);
          },
        );
        expect(uploadedPcmBytes, _wavPcmDataSize(sourceAudio));
        _expectChunkCoverage(result, adapter.requests.length, 10);
      },
    );

    const expectedChunkCounts = {
      'flac/silence': 4,
      'flac/fixedDuration': 4,
      'flac/fixedSize': 21,
      'adpcm/silence': 8,
      'adpcm/fixedDuration': 8,
      'adpcm/fixedSize': 21,
    };
    for (final codec in ['flac', 'adpcm']) {
      for (final method in ['silence', 'fixedDuration', 'fixedSize']) {
        test(
          '$codec compression chunks source PCM with $method under budget',
          () async {
            final adapter = _RouteAdapter();
            var call = 0;
            adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
              call++;
              return ok('$codec $method $call');
            });
            const limit = 8 * 1024;
            final service = AsrService(
              config: AsrConfig(
                apiKey: 'k',
                host: host,
                uploadMethod: AudioUploadMethod.multipart,
                maxFileSizeBytes: limit,
                compression: codec,
                chunking: method,
                fallbackMethod: 'generic',
              ),
              dio: testDio(adapter),
            );

            final result = await service.transcribe(
              audioBytes: _buildWav(seconds: 10),
              audioFormat: 'wav',
            );

            final expectedChunkCount = expectedChunkCounts['$codec/$method']!;
            expect(adapter.requests, hasLength(expectedChunkCount));
            expect(
              result.text,
              List.generate(
                expectedChunkCount,
                (index) => '$codec $method ${index + 1}',
              ).join(' '),
            );
            _expectChunkCoverage(result, expectedChunkCount, 10);
            for (final request in adapter.requests) {
              final requestBytes = request['bodyBytes'] as Uint8List;
              expect(
                requestBytes.length,
                lessThanOrEqualTo(limit),
                reason: 'complete multipart body must fit the configured cap',
              );
              if (codec == 'flac') {
                expect(
                  _indexOfSequence(requestBytes, 'fLaC'.codeUnits),
                  isNonNegative,
                );
              } else {
                final riffIndex =
                    _indexOfSequence(requestBytes, 'RIFF'.codeUnits);
                expect(riffIndex, isNonNegative);
                expect(requestBytes[riffIndex + 20], 0x11);
              }
            }
          },
        );
      }
    }

    test(
      'base64 JSON budget includes fields and expansion at -1, exact, +1',
      () async {
        final bytes = Uint8List.fromList([1, 2, 3]);
        final expectedBody = jsonEncode({
          'model': 'whisper-1',
          'response_format': 'json',
          'file': base64Encode(bytes),
        });
        final bodySize = utf8.encode(expectedBody).length;

        for (final delta in [-1, 0, 1]) {
          final adapter = _RouteAdapter();
          adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
            return ok('base64 threshold $delta');
          });
          final limit = bodySize + delta;
          final service = AsrService(
            config: AsrConfig(
              apiKey: 'k',
              host: host,
              uploadMethod: AudioUploadMethod.base64Json,
              maxFileSizeBytes: limit,
              fallbackMethod: 'none',
            ),
            dio: testDio(adapter),
          );

          if (delta == -1) {
            await expectLater(
              () => service.transcribe(audioBytes: bytes, audioFormat: 'mp3'),
              throwsA(
                predicate(
                  (e) => e is Exception && e.toString().contains('请求体'),
                ),
              ),
            );
            expect(adapter.requests, isEmpty);
          } else {
            await service.transcribe(audioBytes: bytes, audioFormat: 'mp3');
            expect(adapter.requests, hasLength(1));
            expect(
              (adapter.requests.single['bodyBytes'] as Uint8List).length,
              lessThanOrEqualTo(limit),
            );
          }
        }
      },
    );

    test(
      'multipart budget includes the serialized envelope at -1, exact, +1',
      () async {
        final bytes = Uint8List.fromList([1, 2, 3]);

        Future<int> sendAndGetBodySize(
          Uint8List audioBytes,
          String audioFormat,
          int limit,
        ) async {
          final adapter = _RouteAdapter();
          adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
            return ok('multipart threshold');
          });
          final service = AsrService(
            config: AsrConfig(
              apiKey: 'k',
              host: host,
              uploadMethod: AudioUploadMethod.multipart,
              maxFileSizeBytes: limit,
              fallbackMethod: 'none',
            ),
            dio: testDio(adapter),
          );
          await service.transcribe(
            audioBytes: audioBytes,
            audioFormat: audioFormat,
          );
          return (adapter.requests.single['bodyBytes'] as Uint8List).length;
        }

        final bodySize = await sendAndGetBodySize(bytes, 'mp3', 1024);
        for (final delta in [-1, 0, 1]) {
          final adapter = _RouteAdapter();
          adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
            return ok('multipart threshold $delta');
          });
          final limit = bodySize + delta;
          final service = AsrService(
            config: AsrConfig(
              apiKey: 'k',
              host: host,
              uploadMethod: AudioUploadMethod.multipart,
              maxFileSizeBytes: limit,
              fallbackMethod: 'none',
            ),
            dio: testDio(adapter),
          );

          if (delta == -1) {
            await expectLater(
              () => service.transcribe(audioBytes: bytes, audioFormat: 'mp3'),
              throwsA(
                predicate(
                  (e) => e is Exception && e.toString().contains('请求体'),
                ),
              ),
            );
            expect(adapter.requests, isEmpty);
          } else {
            await service.transcribe(audioBytes: bytes, audioFormat: 'mp3');
            expect(adapter.requests, hasLength(1));
            expect(
              (adapter.requests.single['bodyBytes'] as Uint8List).length,
              lessThanOrEqualTo(limit),
            );
          }
        }

        // The raw WAV fits the configured cap, but the complete multipart
        // body is one byte over. Generic fallback must use the selected PCM
        // chunking mode before any request is sent.
        final wav = _buildWav(seconds: 1);
        final fullRequestBytes = await sendAndGetBodySize(
          wav,
          'wav',
          wav.length + 1024,
        );
        final limit = fullRequestBytes - 1;
        expect(wav.length, lessThan(limit));
        final adapter = _RouteAdapter();
        var call = 0;
        adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
          call++;
          return ok('body fallback $call');
        });
        final service = AsrService(
          config: AsrConfig(
            apiKey: 'k',
            host: host,
            uploadMethod: AudioUploadMethod.multipart,
            maxFileSizeBytes: limit,
            chunking: 'fixedSize',
            fallbackMethod: 'generic',
          ),
          dio: testDio(adapter),
        );

        final result = await service.transcribe(
          audioBytes: wav,
          audioFormat: 'wav',
        );

        expect(adapter.requests, hasLength(2));
        expect(result.text, 'body fallback 1 body fallback 2');
        for (final request in adapter.requests) {
          expect(
            (request['bodyBytes'] as Uint8List).length,
            lessThanOrEqualTo(limit),
          );
        }
      },
    );

    test(
      'no encoded PCM frame can fit: returns a controlled error before send',
      () async {
        final adapter = _RouteAdapter();
        final service = AsrService(
          config: const AsrConfig(
            apiKey: 'k',
            host: host,
            maxFileSizeBytes: 64,
            compression: 'adpcm',
            chunking: 'fixedSize',
            fallbackMethod: 'generic',
          ),
          dio: testDio(adapter),
        );

        await expectLater(
          () => service.transcribe(
            audioBytes: _buildWav(seconds: 1),
            audioFormat: 'wav',
          ),
          throwsA(
            predicate(
              (e) => e is Exception && e.toString().contains('单个 PCM 帧'),
            ),
          ),
        );
        expect(adapter.requests, isEmpty);
      },
    );

    test(
        'non-WAV over-limit files with chunking get a friendly rejection, '
        'not a raw parser error', () async {
      final adapter = _RouteAdapter();
      adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
        return ok('should not be reached');
      });
      final service = AsrService(
        config: const AsrConfig(
          apiKey: 'k',
          host: host,
          uploadMethod: AudioUploadMethod.multipart,
          maxFileSizeBytes: 1024,
          compression: 'flac',
          chunking: 'fixedSize',
          fallbackMethod: 'generic',
        ),
        dio: testDio(adapter),
      );

      // Chunking only supports WAV — an over-limit MP3 must be rejected with
      // the friendly message instead of leaking a FormatException.
      await expectLater(
        () => service.transcribe(
          audioBytes: Uint8List.fromList(
            List.generate(5000, (i) => i % 256),
          ), // fake mp3 bytes
          audioFormat: 'mp3',
        ),
        throwsA(
          predicate(
            (e) =>
                e is Exception &&
                e.toString().contains('仅支持 PCM WAV') &&
                e.toString().contains('处理后音频 5000 字节') &&
                !e.toString().contains('处理后 PCM'),
          ),
        ),
      );
      expect(adapter.requests, isEmpty);
    });

    test(
        'truncated WAV with chunking gets the friendly rejection, not a '
        'RangeError', () async {
      final adapter = _RouteAdapter();
      adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
        return ok('should not be reached');
      });
      final service = AsrService(
        config: const AsrConfig(
          apiKey: 'k',
          host: host,
          uploadMethod: AudioUploadMethod.multipart,
          maxFileSizeBytes: 1024,
          chunking: 'fixedSize',
          fallbackMethod: 'generic',
        ),
        dio: testDio(adapter),
      );

      // Header claims 160000 data bytes but only ~1000 are present and the
      // file is over the limit — the truncated WAV must yield the friendly
      // rejection, not a raw RangeError.
      final truncated = _buildWav(seconds: 1); // 16044 bytes total
      final wav = Uint8List(44 + 1000);
      wav.setRange(
          0,
          44 + 1000 < truncated.length ? 44 + 1000 : truncated.length,
          truncated);
      final bd = ByteData.view(wav.buffer);
      bd.setUint32(4, wav.length - 8, Endian.little);
      bd.setUint32(40, 160000, Endian.little); // claim more data than exists

      await expectLater(
        () => service.transcribe(
          audioBytes: wav,
          audioFormat: 'wav',
        ),
        throwsA(predicate(
            (e) => e is Exception && e.toString().contains('文件大小超过限制'))),
      );
      expect(adapter.requests, isEmpty);
    });

    test('URL mode rejects transcribe() with a guidance exception', () async {
      final adapter = _RouteAdapter();
      final service = AsrService(
        config: const AsrConfig(
          apiKey: 'k',
          host: host,
          uploadMethod: AudioUploadMethod.url,
        ),
        dio: testDio(adapter),
      );

      await expectLater(
        () => service.transcribe(
          audioBytes: _buildWav(seconds: 1),
          audioFormat: 'wav',
        ),
        throwsA(predicate((e) =>
            e is Exception && e.toString().contains('transcribeFromUrl'))),
      );
      expect(adapter.requests, isEmpty);
    });
  });
}
