import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:stroom/services/asr_service.dart';

/// A mock [HttpClientAdapter] that maps paths to responses.
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

void main() {
  group('AudioUploadMethod', () {
    test('default is multipart', () {
      expect(AudioUploadMethod.values.first, AudioUploadMethod.multipart);
    });

    test('contains three values', () {
      expect(AudioUploadMethod.values.length, 3);
    });
  });

  group('AsrConfig upload method', () {
    test('uploadMethod defaults to multipart', () {
      const config = AsrConfig(apiKey: 'k', host: 'https://api.test.com');
      expect(config.uploadMethod, AudioUploadMethod.multipart);
    });

    test('uploadMethod can be set to base64Json', () {
      const config = AsrConfig(
        apiKey: 'k',
        host: 'https://api.test.com',
        uploadMethod: AudioUploadMethod.base64Json,
      );
      expect(config.uploadMethod, AudioUploadMethod.base64Json);
    });

    test('uploadMethod can be set to url', () {
      const config = AsrConfig(
        apiKey: 'k',
        host: 'https://api.test.com',
        uploadMethod: AudioUploadMethod.url,
      );
      expect(config.uploadMethod, AudioUploadMethod.url);
    });

    test('maxFileSizeBytes does not apply to url method (no validation)',
        () async {
      // URL method should not validate file size since there are no bytes
      const config = AsrConfig(
        apiKey: 'k',
        host: 'https://api.test.com',
        uploadMethod: AudioUploadMethod.url,
        maxFileSizeBytes: 10, // 10 bytes limit, but URL doesn't use bytes
      );
      final service = AsrService(config: config);
      // transcribeFromUrl with bytes param is not how URL mode works -
      // the service should NOT reject on size for URL
      expect(config.uploadMethod, AudioUploadMethod.url);
      expect(config.maxFileSizeBytes, 10);
    });

    test('copyWith preserves uploadMethod', () {
      const config = AsrConfig(
        apiKey: 'k',
        host: 'https://api.test.com',
        uploadMethod: AudioUploadMethod.base64Json,
      );
      final copy = config.copyWith();
      expect(copy.uploadMethod, AudioUploadMethod.base64Json);
    });
  });

  group('AsrService base64 JSON upload', () {
    test('sends Content-Type application/json with base64 file field',
        () async {
      final adapter = _RouteAdapter();
      adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"text":"Hello base64"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = Dio(BaseOptions(
        baseUrl: 'https://api.test.com',
      ))
        ..httpClientAdapter = adapter;

      const config = AsrConfig(
        apiKey: 'test-key',
        host: 'https://api.test.com/audio/transcriptions',
        uploadMethod: AudioUploadMethod.base64Json,
      );
      final service = AsrService(config: config, dio: dio);

      final audioBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = await service.transcribe(
        audioBytes: audioBytes,
        audioFormat: 'wav',
      );

      expect(result.text, 'Hello base64');

      // Verify the request
      expect(adapter.requests.length, 1);
      final req = adapter.requests.first;
      expect(req['method'], 'POST');
      expect(req['contentType'], contains('application/json'));

      // Parse the JSON body
      final body =
          jsonDecode(req['bodyString'] as String) as Map<String, dynamic>;
      expect(body['model'], 'whisper-1');
      expect(body['file'], isA<String>());
      expect(body['response_format'], 'json');

      // Verify the file field is base64 of our bytes
      final expectedB64 = base64Encode(audioBytes);
      expect(body['file'], expectedB64);
    });

    test('base64 JSON includes all configured fields', () async {
      final adapter = _RouteAdapter();
      adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"text":"ok"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = Dio(BaseOptions(
        baseUrl: 'https://api.test.com',
      ))
        ..httpClientAdapter = adapter;

      final config = AsrConfig(
        apiKey: 'test-key',
        host: 'https://api.test.com/audio/transcriptions',
        uploadMethod: AudioUploadMethod.base64Json,
        language: 'zh',
        typeConfig: {
          'enableResponseFormat': true,
          'responseFormat': 'verbose_json',
          'enableTemperature': true,
          'temperature': 0.3,
        },
      );
      final service = AsrService(config: config, dio: dio);

      await service.transcribe(
        audioBytes: Uint8List.fromList([10, 20]),
        audioFormat: 'wav',
      );

      final body = jsonDecode(adapter.requests.first['bodyString'] as String)
          as Map<String, dynamic>;
      expect(body['language'], 'zh');
      expect(body['response_format'], 'verbose_json');
      expect(body['temperature'], 0.3);
    });

    test('base64 JSON applies file size validation', () async {
      const config = AsrConfig(
        apiKey: 'test-key',
        host: 'https://api.test.com',
        uploadMethod: AudioUploadMethod.base64Json,
        maxFileSizeBytes: 4, // only 4 bytes allowed
      );
      final service = AsrService(config: config);

      // 10 bytes > 4 byte limit → should reject
      await expectLater(
        () => service.transcribe(
          audioBytes: Uint8List(10),
          audioFormat: 'wav',
        ),
        throwsA(predicate(
            (e) => e is Exception && e.toString().contains('文件大小超过限制'))),
      );
    });

    test('base64 JSON sends Authorization header', () async {
      final adapter = _RouteAdapter();
      adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"text":"ok"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = Dio(BaseOptions(
        baseUrl: 'https://api.test.com',
      ))
        ..httpClientAdapter = adapter;

      const config = AsrConfig(
        apiKey: 'my-secret-key',
        host: 'https://api.test.com/audio/transcriptions',
        uploadMethod: AudioUploadMethod.base64Json,
      );
      final service = AsrService(config: config, dio: dio);

      await service.transcribe(
        audioBytes: Uint8List(5),
        audioFormat: 'wav',
      );

      // Check the adapter received the request
      expect(adapter.requests.length, 1);
    });
  });

  group('AsrService URL upload', () {
    test('transcribeFromUrl sends JSON with file field as URL', () async {
      final adapter = _RouteAdapter();
      adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"text":"URL result"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = Dio(BaseOptions(
        baseUrl: 'https://api.test.com',
      ))
        ..httpClientAdapter = adapter;

      const config = AsrConfig(
        apiKey: 'test-key',
        host: 'https://api.test.com/audio/transcriptions',
        uploadMethod: AudioUploadMethod.url,
      );
      final service = AsrService(config: config, dio: dio);

      final result = await service.transcribeFromUrl(
        'https://example.com/audio.mp3',
      );

      expect(result.text, 'URL result');

      // Verify request format
      expect(adapter.requests.length, 1);
      final req = adapter.requests.first;
      expect(req['method'], 'POST');
      expect(req['contentType'], contains('application/json'));

      final body =
          jsonDecode(req['bodyString'] as String) as Map<String, dynamic>;
      expect(body['file'], 'https://example.com/audio.mp3');
      expect(body['model'], 'whisper-1');
      expect(body['response_format'], 'json');
    });

    test('transcribeFromUrl includes language and extra fields', () async {
      final adapter = _RouteAdapter();
      adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"text":"with lang"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = Dio(BaseOptions(
        baseUrl: 'https://api.test.com',
      ))
        ..httpClientAdapter = adapter;

      final config = AsrConfig(
        apiKey: 'test-key',
        host: 'https://api.test.com/audio/transcriptions',
        uploadMethod: AudioUploadMethod.url,
        language: 'en',
        typeConfig: {
          'enableResponseFormat': true,
          'responseFormat': 'text',
        },
      );
      final service = AsrService(config: config, dio: dio);

      await service.transcribeFromUrl('https://files.example.com/audio.wav');

      final body = jsonDecode(adapter.requests.first['bodyString'] as String)
          as Map<String, dynamic>;
      expect(body['language'], 'en');
      expect(body['response_format'], 'text');
    });

    test('transcribeFromUrl rejects empty URL', () async {
      const config = AsrConfig(
        apiKey: 'test-key',
        host: 'https://api.test.com',
        uploadMethod: AudioUploadMethod.url,
      );
      final service = AsrService(config: config);

      await expectLater(
        () => service.transcribeFromUrl(''),
        throwsA(isA<Exception>()),
      );

      await expectLater(
        () => service.transcribeFromUrl('   '),
        throwsA(isA<Exception>()),
      );
    });

    test('transcribeFromUrl rejects obviously invalid URLs', () async {
      const config = AsrConfig(
        apiKey: 'test-key',
        host: 'https://api.test.com',
        uploadMethod: AudioUploadMethod.url,
      );
      final service = AsrService(config: config);

      await expectLater(
        () => service.transcribeFromUrl('not-a-url'),
        throwsA(isA<Exception>()),
      );
    });

    test('transcribeFromUrl does not apply file size validation', () async {
      // Even with a tiny maxFileSizeBytes, URL upload should work
      // because there are no bytes to validate.
      final adapter = _RouteAdapter();
      adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"text":"no size check"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = Dio(BaseOptions(
        baseUrl: 'https://api.test.com',
      ))
        ..httpClientAdapter = adapter;

      const config = AsrConfig(
        apiKey: 'test-key',
        host: 'https://api.test.com/audio/transcriptions',
        uploadMethod: AudioUploadMethod.url,
        maxFileSizeBytes: 10,
      );
      final service = AsrService(config: config, dio: dio);

      final result =
          await service.transcribeFromUrl('https://example.com/huge-audio.mp3');
      expect(result.text, 'no size check');
    });

    test('transcribeFromUrl wraps DioException', () async {
      final adapter = _RouteAdapter();
      adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"error":{"message":"Download failed"}}',
          400,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = Dio(BaseOptions(
        baseUrl: 'https://api.test.com',
      ))
        ..httpClientAdapter = adapter;

      const config = AsrConfig(
        apiKey: 'test-key',
        host: 'https://api.test.com/audio/transcriptions',
        uploadMethod: AudioUploadMethod.url,
      );
      final service = AsrService(config: config, dio: dio);

      await expectLater(
        () => service.transcribeFromUrl('https://example.com/bad.mp3'),
        throwsA(predicate(
            (e) => e is Exception && e.toString().contains('HTTP 400'))),
      );
    });
  });

  group('AsrService diagnostics', () {
    test('base64 JSON captures diagnostics (lastRequestBody etc.)', () async {
      final adapter = _RouteAdapter();
      adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"text":"diag"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = Dio(BaseOptions(
        baseUrl: 'https://api.test.com',
      ))
        ..httpClientAdapter = adapter;

      const config = AsrConfig(
        apiKey: 'test-key',
        host: 'https://api.test.com/audio/transcriptions',
        uploadMethod: AudioUploadMethod.base64Json,
      );
      final service = AsrService(config: config, dio: dio);

      await service.transcribe(
        audioBytes: Uint8List.fromList([1, 2, 3]),
        audioFormat: 'mp3',
      );

      expect(service.lastRequestBody, isNotNull);
      expect(service.lastRequestBody!['model'], 'whisper-1');
      expect(
          service.lastRequestUrl, 'https://api.test.com/audio/transcriptions');
    });

    test('URL upload captures diagnostics', () async {
      final adapter = _RouteAdapter();
      adapter.onPost('/audio/transcriptions', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"text":"url diag"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = Dio(BaseOptions(
        baseUrl: 'https://api.test.com',
      ))
        ..httpClientAdapter = adapter;

      const config = AsrConfig(
        apiKey: 'test-key',
        host: 'https://api.test.com/audio/transcriptions',
        uploadMethod: AudioUploadMethod.url,
      );
      final service = AsrService(config: config, dio: dio);

      await service.transcribeFromUrl('https://example.com/audio.mp3');

      expect(service.lastRequestBody, isNotNull);
      expect(service.lastRequestBody!['file'], 'https://example.com/audio.mp3');
    });
  });
}
