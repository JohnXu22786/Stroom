import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:stroom/services/asr_service.dart';

/// A mock [HttpClientAdapter] that captures the request options (including
/// Content-Type) after Dio's transformer processes FormData, and returns a
/// success response.
class _CapturingAdapter implements HttpClientAdapter {
  String? capturedContentType;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    capturedContentType = options.contentType;
    // Drain the request stream so the adapter completes cleanly
    await requestStream?.drain<void>();
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

      test('FormData request has correct Content-Type with boundary', () async {
        final adapter = _CapturingAdapter();
        final mockDio = Dio()..httpClientAdapter = adapter;

        const config = AsrConfig(
          apiKey: 'test-key',
          host: 'https://api.test.com',
        );
        final service = AsrService(config: config, dio: mockDio);

        final result = await service.transcribe(
          audioBytes: Uint8List.fromList([1, 2, 3]),
          audioFormat: 'wav',
        );

        // After Dio's transformer processes the FormData, the Content-Type
        // should include the boundary parameter.
        final capturedContentType = adapter.capturedContentType;

        expect(capturedContentType, isNotNull);
        expect(
          capturedContentType!.startsWith('multipart/form-data'),
          isTrue,
          reason: 'Content-Type must start with multipart/form-data',
        );
        expect(
          capturedContentType.contains('boundary='),
          isTrue,
          reason:
              'Content-Type must include boundary parameter. Got: $capturedContentType',
        );

        // Extract boundary value and verify it is not empty.
        // According to RFC 2046, the boundary value can contain characters
        // such as hyphens. For example, OpenAI's Python SDK sends
        // boundaries like `----WebKitFormBoundary7MA4YWxkTrZu0gW`.
        // Dio generates boundaries like `--dio-boundary-XXXXXXXXXX`
        // which is a valid format accepted by OpenAI-compatible APIs.
        final boundaryMatch =
            RegExp(r'boundary=([^\s;]+)').firstMatch(capturedContentType);
        expect(boundaryMatch, isNotNull);
        final boundaryValue = boundaryMatch!.group(1)!;
        expect(
          boundaryValue.isNotEmpty,
          isTrue,
          reason: 'Boundary value must not be empty. Got: $boundaryValue',
        );

        // Verify the transcription still works after the fix
        expect(result.text, equals('Hello world'));
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

    group('audioFormatMimeType', () {
      test('returns correct MIME type for common audio formats', () {
        expect(audioFormatMimeType('mp3').mimeType, 'audio/mpeg');
        expect(audioFormatMimeType('MP3').mimeType, 'audio/mpeg');
        expect(audioFormatMimeType('wav').mimeType, 'audio/wav');
        expect(audioFormatMimeType('ogg').mimeType, 'audio/ogg');
        expect(audioFormatMimeType('opus').mimeType, 'audio/ogg');
        expect(audioFormatMimeType('flac').mimeType, 'audio/flac');
        expect(audioFormatMimeType('m4a').mimeType, 'audio/mp4');
        expect(audioFormatMimeType('mp4').mimeType, 'audio/mp4');
        expect(audioFormatMimeType('webm').mimeType, 'audio/webm');
        expect(audioFormatMimeType('mpga').mimeType, 'audio/mpeg');
        expect(audioFormatMimeType('wma').mimeType, 'audio/x-ms-wma');
      });

      test('falls back to application/octet-stream for unknown formats', () {
        expect(audioFormatMimeType('xyz').mimeType, 'application/octet-stream');
        expect(audioFormatMimeType('').mimeType, 'application/octet-stream');
      });
    });
  });
}
