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

void main() {
  const host = 'https://api.test.com/audio/transcriptions';

  Dio testDio(_RouteAdapter adapter) => Dio(BaseOptions(baseUrl: 'https://api.test.com'))
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

    test('fallbackMethod=specific sends over-limit file via base64 JSON',
        () async {
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

      final result = await service.transcribe(
        audioBytes: _buildWav(seconds: 1),
        audioFormat: 'wav',
      );

      expect(result.text, 'base64 fallback works');
      expect(adapter.requests.length, 1);
      expect(adapter.requests.first['contentType'], contains('application/json'));
      final body = jsonDecode(adapter.requests.first['bodyString'] as String)
          as Map<String, dynamic>;
      expect(body['file'], isA<String>());
      // base64 of the over-limit wav bytes
      expect(
        base64Decode(body['file'] as String),
        _buildWav(seconds: 1),
      );
    });

    test('fallbackMethod=specific with base64Json primary has no specific '
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

    test('fallbackMethod=generic chunking splits over-limit WAV into '
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

      // 10s @ 8kHz mono 16-bit = 160KB -> 3 chunks at 64KB.
      final result = await service.transcribe(
        audioBytes: _buildWav(seconds: 10),
        audioFormat: 'wav',
      );

      expect(adapter.requests.length, 3);
      expect(result.text, 'chunk 1 chunk 2 chunk 3');
      for (final req in adapter.requests) {
        expect(req['contentType'], contains('multipart/form-data'));
      }
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
        throwsA(predicate((e) =>
            e is Exception && e.toString().contains('切块转写全部失败'))),
      );
    });

    test('fallbackMethod=all falls back to generic when specific fails',
        () async {
      final adapter = _RouteAdapter();
      var call = 0;
      adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
        call++;
        if (call == 1) return err500(); // specific base64 attempt fails
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

      final result = await service.transcribe(
        audioBytes: _buildWav(seconds: 10),
        audioFormat: 'wav',
      );

      expect(result.text, 'generic saved it');
      expect(adapter.requests.length, 2);
      // 1st attempt: base64 JSON; 2nd: multipart with compressed FLAC.
      expect(adapter.requests[0]['contentType'], contains('application/json'));
      expect(adapter.requests[1]['contentType'], contains('multipart/form-data'));
      expect(
        adapter.requests[1]['bodyString'] as String,
        contains('audio.flac'),
      );
    });

    test('base64 upload chunking keeps each base64 payload within the limit',
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

      final result = await service.transcribe(
        audioBytes: _buildWav(seconds: 10),
        audioFormat: 'wav',
      );

      // 160KB / (0.75 * 64KB) chunks -> 4 base64 payloads.
      expect(adapter.requests.length, 4);
      expect(result.text, 'b64 chunk 1 b64 chunk 2 b64 chunk 3 b64 chunk 4');
      for (final req in adapter.requests) {
        final body = jsonDecode(req['bodyString'] as String)
            as Map<String, dynamic>;
        final file = body['file'] as String;
        // The base64 STRING length == payload bytes — must stay within the
        // provider's file size limit.
        expect(file.length, lessThanOrEqualTo(limit),
            reason: 'base64 payload must stay within the file limit');
      }
    });

    test('ADPCM + chunking never splits compressed data — falls back to a '
        'friendly rejection instead of crashing', () async {
      final adapter = _RouteAdapter();
      adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
        return ok('should not be reached');
      });
      final service = AsrService(
        config: const AsrConfig(
          apiKey: 'k',
          host: host,
          uploadMethod: AudioUploadMethod.multipart,
          maxFileSizeBytes: 8 * 1024,
          compression: 'adpcm',
          chunking: 'fixedSize',
          fallbackMethod: 'generic',
        ),
        dio: testDio(adapter),
      );

      // 10s WAV (160KB) is far above the 8KB limit even after ~4x ADPCM
      // compression (≈40KB). Chunking must NOT be attempted on compressed
      // data — the user gets the friendly rejection, not a FormatException.
      await expectLater(
        () => service.transcribe(
          audioBytes: _buildWav(seconds: 10),
          audioFormat: 'wav',
        ),
        throwsA(predicate((e) =>
            e is Exception && e.toString().contains('文件大小超过限制'))),
      );
      expect(adapter.requests, isEmpty);
    });

    test('non-WAV over-limit files with chunking get a friendly rejection, '
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
              List.generate(5000, (i) => i % 256)), // fake mp3 bytes
          audioFormat: 'mp3',
        ),
        throwsA(predicate((e) =>
            e is Exception && e.toString().contains('文件大小超过限制'))),
      );
      expect(adapter.requests, isEmpty);
    });

    test('truncated WAV with chunking gets the friendly rejection, not a '
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
      wav.setRange(0, 44 + 1000 < truncated.length ? 44 + 1000 : truncated.length,
          truncated);
      final bd = ByteData.view(wav.buffer);
      bd.setUint32(4, wav.length - 8, Endian.little);
      bd.setUint32(40, 160000, Endian.little); // claim more data than exists

      await expectLater(
        () => service.transcribe(
          audioBytes: wav,
          audioFormat: 'wav',
        ),
        throwsA(predicate((e) =>
            e is Exception && e.toString().contains('文件大小超过限制'))),
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
