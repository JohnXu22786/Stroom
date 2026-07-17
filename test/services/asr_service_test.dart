import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:stroom/services/asr_service.dart';

/// A mock [HttpClientAdapter] that captures the request data for inspection
/// and returns a success response.
class _CapturingAdapter implements HttpClientAdapter {
  String? capturedContentType;
  List<int>? capturedBodyBytes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    capturedContentType = options.contentType;
    // Capture the request body bytes
    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      capturedBodyBytes = bytes;
    }
    return ResponseBody.fromString(
      '{"text":"Hello world"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Check that [bodyBytes] contains a multipart field with the given [name]
/// whose value starts with [valuePrefix].
bool _multipartFieldContains(
    List<int> bodyBytes, String name, String valuePrefix) {
  // Use allowMalformed=true because the body also contains binary audio data
  // which is not valid UTF-8. Dio serializes text fields before file fields,
  // so the field headers/values we search for are in the early text portion.
  final bodyStr = utf8.decode(bodyBytes, allowMalformed: true);
  // Each form-data field looks like:
  // --boundary\r\n
  // Content-Disposition: form-data; name="<name>"\r\n
  // \r\n
  // <value>
  final pattern = 'name="$name"';
  final nameIdx = bodyStr.indexOf(pattern);
  if (nameIdx == -1) return false;
  // Find the double \r\n after the header
  final headerEnd = bodyStr.indexOf('\r\n\r\n', nameIdx);
  if (headerEnd == -1) return false;
  final valueStart = headerEnd + 4;
  final valueEnd = bodyStr.indexOf('\r\n', valueStart);
  if (valueEnd == -1) return false;
  final value = bodyStr.substring(valueStart, valueEnd);
  return value.startsWith(valuePrefix);
}

/// Check that [needle] bytes appear sequentially in [haystack].
bool _bodyContains(List<int> haystack, List<int> needle) {
  if (needle.length > haystack.length) return false;
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}

/// Check that the multipart body contains a file part with the given [mimeType]
/// in its content-type header.
bool _multipartFileHasMimeType(List<int> bodyBytes, String mimeType) {
  final bodyStr = utf8.decode(bodyBytes, allowMalformed: true);
  // The file part looks like:
  // content-disposition: form-data; name="file"; filename="..."\r\n
  // content-type: <mimeType>\r\n
  final filePartPattern = 'name="file"';
  final fileIdx = bodyStr.indexOf(filePartPattern);
  if (fileIdx == -1) return false;
  // Find the content-type header after the file part
  final ctIdx = bodyStr.indexOf('content-type: ', fileIdx);
  if (ctIdx == -1) return false;
  final ctEnd = bodyStr.indexOf('\r\n', ctIdx);
  if (ctEnd == -1) return false;
  final ctValue = bodyStr.substring(ctIdx, ctEnd);
  return ctValue.contains(mimeType);
}

void main() {
  group('AsrService', () {
    group('AsrConfig', () {
      test('can be created with all fields', () {
        const config = AsrConfig(
          model: 'whisper-1',
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
          language: 'zh',
        );
        expect(config.model, equals('whisper-1'));
        expect(config.apiKey, equals('test-key'));
        expect(config.host, equals('https://api.openai.com/v1'));
        expect(config.language, equals('zh'));
      });

      test('default model is whisper-1', () {
        const config = AsrConfig(
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        expect(config.model, equals('whisper-1'));
      });

      test('language is null by default', () {
        const config = AsrConfig(
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        expect(config.language, isNull);
      });

      test('copies correctly', () {
        const config = AsrConfig(
          model: 'whisper-1',
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
          language: 'en',
        );
        final copy = config.copyWith(model: 'whisper-2');
        expect(copy.model, equals('whisper-2'));
        expect(copy.apiKey, equals('test-key'));
        expect(copy.host, equals('https://api.openai.com/v1'));
        expect(copy.language, equals('en'));
      });

      test('copyWith can update language', () {
        const config = AsrConfig(
          apiKey: 'key',
          host: 'https://api.test.com',
        );
        final copy = config.copyWith(language: 'zh');
        expect(copy.language, equals('zh'));
      });

      test('normalizedHost strips trailing slash', () {
        const config = AsrConfig(
          apiKey: 'key',
          host: 'https://api.openai.com/v1/',
        );
        expect(config.normalizedHost.endsWith('/'), isFalse);
        expect(config.normalizedHost, equals('https://api.openai.com/v1'));
      });

      test('normalizedHost returns host as-is when no trailing slash', () {
        const config = AsrConfig(
          apiKey: 'key',
          host: 'https://api.openai.com/v1',
        );
        expect(config.normalizedHost, equals('https://api.openai.com/v1'));
      });

      test('transcribeUrl returns normalizedHost directly (no auto-append)',
          () {
        const config = AsrConfig(
          apiKey: 'key',
          host: 'https://api.openai.com/v1',
        );
        expect(config.transcribeUrl, equals('https://api.openai.com/v1'));
      });

      test('transcribeUrl handles trailing slash in host', () {
        const config = AsrConfig(
          apiKey: 'key',
          host: 'https://api.openai.com/v1/',
        );
        expect(config.transcribeUrl, equals('https://api.openai.com/v1'));
      });
    });

    group('AsrResult', () {
      test('can be created with all fields', () {
        final result = AsrResult(
          text: 'Hello world',
          processingTimeMs: 2000,
        );
        expect(result.text, equals('Hello world'));
        expect(result.processingTimeMs, equals(2000));
      });

      test('default values', () {
        final result = AsrResult(text: 'Hello');
        expect(result.processingTimeMs, isZero);
      });
    });

    group('AsrService', () {
      test('can be created with config', () {
        const config = AsrConfig(
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        final service = AsrService(config: config);
        expect(service, isNotNull);
        expect(service.config.model, equals('whisper-1'));
      });

      test('Dio has no sendTimeout (no timeout)', () {
        const config = AsrConfig(
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        final service = AsrService(config: config);
        expect(service.sendTimeout, isNull);
      });

      test('Dio has no connectTimeout (no timeout)', () {
        const config = AsrConfig(
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        final service = AsrService(config: config);
        expect(service.connectTimeout, isNull);
      });

      test('Dio has no receiveTimeout (no timeout)', () {
        const config = AsrConfig(
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        final service = AsrService(config: config);
        expect(service.receiveTimeout, isNull);
      });

      test('throws on empty host', () async {
        const config = AsrConfig(
          apiKey: 'test-key',
          host: '',
        );
        final service = AsrService(config: config);
        expect(
          () => service.transcribe(
            audioBytes: Uint8List(0),
            audioFormat: 'wav',
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('throws on empty audio bytes', () async {
        const config = AsrConfig(
          apiKey: 'test-key',
          host: 'https://api.test.com',
        );
        final service = AsrService(config: config);
        expect(
          () => service.transcribe(
            audioBytes: Uint8List(0),
            audioFormat: 'wav',
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('request sends multipart/form-data with file and fields', () async {
        final adapter = _CapturingAdapter();
        final mockDio = Dio()..httpClientAdapter = adapter;

        const config = AsrConfig(
          apiKey: 'test-key',
          host: 'https://api.test.com',
        );
        final service = AsrService(config: config, dio: mockDio);

        final audioBytes = Uint8List.fromList([1, 2, 3]);
        final result = await service.transcribe(
          audioBytes: audioBytes,
          audioFormat: 'wav',
        );

        // Content-Type should be multipart/form-data (with boundary)
        final capturedContentType = adapter.capturedContentType;
        expect(capturedContentType, isNotNull);
        expect(
          capturedContentType!.startsWith('multipart/form-data'),
          isTrue,
          reason:
              'Content-Type must be multipart/form-data. Got: $capturedContentType',
        );

        // Content-Type should include a boundary parameter
        expect(
          capturedContentType.contains('boundary='),
          isTrue,
          reason:
              'Content-Type must include boundary parameter. Got: $capturedContentType',
        );

        // Request body should contain multipart-formatted data
        final bodyBytes = adapter.capturedBodyBytes;
        expect(bodyBytes, isNotNull);

        // Verify audio file bytes (binary) are in the body
        expect(
          _bodyContains(bodyBytes!, audioBytes),
          isTrue,
          reason: 'Audio file bytes should be present in multipart body, '
              'not just a text placeholder',
        );

        // Verify file part has proper MIME type for WAV
        expect(
          _multipartFileHasMimeType(bodyBytes, 'audio/wav'),
          isTrue,
          reason:
              'File part in multipart body should have content-type: audio/wav',
        );

        // Verify model field
        expect(
          _multipartFieldContains(bodyBytes, 'model', 'whisper-1'),
          isTrue,
          reason: 'Multipart body should contain model=whisper-1',
        );

        // Verify response_format field
        expect(
          _multipartFieldContains(bodyBytes, 'response_format', 'json'),
          isTrue,
          reason: 'Multipart body should contain response_format=json',
        );

        // Verify file name in Content-Disposition
        // Use allowMalformed because the body contains binary WAV data
        // (ensureValidAudioFormat converts PCM→WAV before sending).
        final bodyStr = utf8.decode(bodyBytes, allowMalformed: true);
        expect(
          bodyStr.contains('filename="audio.wav"'),
          isTrue,
          reason: 'Multipart body should contain filename="audio.wav"',
        );

        // Verify the transcription still works
        expect(result.text, equals('Hello world'));

        // Verify diagnostics (lastRequestBody) show file metadata
        // Note: byte count may differ from original after ensureValidAudioFormat
        // converts PCM→WAV, so we only check filename and MIME type.
        expect(service.lastRequestBody, isNotNull);
        expect(
          (service.lastRequestBody!['file'] as String).contains('audio.wav'),
          true,
          reason: 'Diagnostics should contain audio.wav',
        );
        expect(
          (service.lastRequestBody!['file'] as String).contains('audio/wav'),
          true,
          reason: 'Diagnostics should contain audio/wav MIME type',
        );
      });

      test('request sends correct MIME type for mp3 format', () async {
        final adapter = _CapturingAdapter();
        final mockDio = Dio()..httpClientAdapter = adapter;

        const config = AsrConfig(
          apiKey: 'test-key',
          host: 'https://api.test.com',
        );
        final service = AsrService(config: config, dio: mockDio);

        await service.transcribe(
          audioBytes: Uint8List.fromList([10, 20, 30]),
          audioFormat: 'mp3',
        );

        final bodyBytes = adapter.capturedBodyBytes;
        expect(bodyBytes, isNotNull);

        // Verify file part has proper MIME type for MP3
        expect(
          _multipartFileHasMimeType(bodyBytes!, 'audio/mpeg'),
          isTrue,
          reason:
              'File part in multipart body should have content-type: audio/mpeg for mp3',
        );
      });

      test('request sends correct MIME type for m4a format', () async {
        final adapter = _CapturingAdapter();
        final mockDio = Dio()..httpClientAdapter = adapter;

        const config = AsrConfig(
          apiKey: 'test-key',
          host: 'https://api.test.com',
        );
        final service = AsrService(config: config, dio: mockDio);

        await service.transcribe(
          audioBytes: Uint8List.fromList([10, 20, 30]),
          audioFormat: 'm4a',
        );

        final bodyBytes = adapter.capturedBodyBytes;
        expect(bodyBytes, isNotNull);

        // Verify file part has proper MIME type for M4A
        expect(
          _multipartFileHasMimeType(bodyBytes!, 'audio/mp4'),
          isTrue,
          reason:
              'File part in multipart body should have content-type: audio/mp4 for m4a',
        );
      });

      test('request includes language in multipart when set', () async {
        final adapter = _CapturingAdapter();
        final mockDio = Dio()..httpClientAdapter = adapter;

        const config = AsrConfig(
          apiKey: 'test-key',
          host: 'https://api.test.com',
          language: 'zh',
        );
        final service = AsrService(config: config, dio: mockDio);

        await service.transcribe(
          audioBytes: Uint8List.fromList([1, 2, 3]),
          audioFormat: 'wav',
        );

        final bodyBytes = adapter.capturedBodyBytes;
        expect(bodyBytes, isNotNull);

        // Verify language field is present
        expect(
          _multipartFieldContains(bodyBytes!, 'language', 'zh'),
          isTrue,
          reason: 'Multipart body should contain language=zh when configured',
        );

        // Verify diagnostics also include language
        expect(service.lastRequestBody, isNotNull);
        expect(service.lastRequestBody!['language'], 'zh');
      });
    });

    group('createAsrServiceFromConfig', () {
      test('creates service from config fields', () {
        final service = createAsrServiceFromConfig(
          host: 'https://api.test.com',
          apiKey: 'key',
          model: 'whisper-1',
        );
        expect(service, isNotNull);
        expect(service.config.model, equals('whisper-1'));
        expect(service.config.apiKey, equals('key'));
        expect(service.config.host, equals('https://api.test.com'));
      });

      test('creates service with language', () {
        final service = createAsrServiceFromConfig(
          host: 'https://api.test.com',
          apiKey: 'key',
          model: 'whisper-1',
          language: 'zh',
        );
        expect(service.config.language, equals('zh'));
      });
    });

    group('form-data diagnostics', () {
      test('lastRequestBody shows file metadata and fields', () async {
        const config = AsrConfig(
          apiKey: 'test-key',
          host: 'https://api.test.com',
        );

        // Call transcribe with a mock adapter to prevent real network call
        final adapter = _CapturingAdapter();
        final mockDio = Dio()..httpClientAdapter = adapter;
        final testService = AsrService(config: config, dio: mockDio);

        final audioBytes = Uint8List.fromList([10, 20, 30, 40]);
        await testService.transcribe(
          audioBytes: audioBytes,
          audioFormat: 'mp3',
        );

        expect(testService.lastRequestBody, isNotNull);
        expect(testService.lastRequestBody!['model'], 'whisper-1');
        expect(testService.lastRequestBody!['response_format'], 'json');
        expect(
          (testService.lastRequestBody!['file'] as String)
              .contains('audio.mp3'),
          true,
          reason: 'Diagnostics should contain audio.mp3',
        );
        expect(
          (testService.lastRequestBody!['file'] as String)
              .contains('audio/mpeg'),
          true,
          reason: 'Diagnostics should contain audio/mpeg MIME type',
        );
      });
    });
  });
}
