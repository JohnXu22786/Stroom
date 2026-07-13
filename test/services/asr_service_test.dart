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

      test('request sends base64 audio via JSON body', () async {
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

        // Content-Type should be application/json
        final capturedContentType = adapter.capturedContentType;
        expect(capturedContentType, isNotNull);
        expect(
          capturedContentType!.startsWith('application/json'),
          isTrue,
          reason:
              'Content-Type must be application/json. Got: $capturedContentType',
        );

        // Request body should contain base64-encoded audio
        final bodyBytes = adapter.capturedBodyBytes;
        expect(bodyBytes, isNotNull);
        final bodyStr = utf8.decode(bodyBytes!);
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;

        expect(body['model'], 'whisper-1');
        expect(body['response_format'], 'json');

        final inputAudio = body['input_audio'] as Map<String, dynamic>;
        expect(inputAudio['format'], 'wav');
        expect(inputAudio['data'], base64Encode(audioBytes));

        // Verify the transcription still works
        expect(result.text, equals('Hello world'));

        // Verify diagnostics (lastRequestBody) show truncated base64
        expect(service.lastRequestBody, isNotNull);
        final diagAudio = service.lastRequestBody!['input_audio'] as Map;
        expect(
          (diagAudio['data'] as String).contains('${audioBytes.length} bytes'),
          true,
        );
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

    group('input_audio format in diagnostics', () {
      test('audio data appears in lastRequestBody', () async {
        const config = AsrConfig(
          apiKey: 'test-key',
          host: 'https://api.test.com',
        );
        final service = AsrService(config: config);

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

        final inputAudio = testService.lastRequestBody!['input_audio'] as Map;
        expect(inputAudio['format'], 'mp3');
        // The data should be truncated in diagnostics but still contain
        // the first few characters of the base64 string
        expect(
          (inputAudio['data'] as String).contains('${audioBytes.length} bytes'),
          true,
        );
      });
    });
  });
}
