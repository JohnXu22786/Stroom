import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/ocr_service.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:dio/dio.dart';
import 'dart:typed_data';

// ============================================================================
// Helpers
// ============================================================================

/// Create a mock Dio that returns a successful response with the given data.
Dio _mockDioWithSuccess(dynamic data) {
  return Dio()..interceptors.add(_SuccessInterceptor(data));
}

/// An interceptor that always returns a successful response with the given data.
class _SuccessInterceptor extends Interceptor {
  final dynamic _data;
  _SuccessInterceptor(this._data);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.resolve(Response(
      requestOptions: options,
      statusCode: 200,
      data: _data,
    ));
  }
}

/// An interceptor that invokes a callback on request and resolves with
/// a default success response.
class _InterceptorWithCallback extends Interceptor {
  final void Function(RequestOptions options, RequestInterceptorHandler handler)
      _callback;

  _InterceptorWithCallback(
      {required void Function(
        RequestOptions options,
        RequestInterceptorHandler handler,
      ) callback})
      : _callback = callback;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _callback(options, handler);
  }
}

const _testOcrConfig = OcrConfig(
  model: 'gpt-4o',
  apiKey: 'test-key',
  host: 'https://api.test.com/v1',
);

void main() {
  group('OcrService', () {
    group('OcrConfig', () {
      test('can be created', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        expect(config.model, equals('gpt-4o'));
        expect(config.apiKey, equals('test-key'));
        expect(config.host, equals('https://api.openai.com/v1'));
      });

      test('copies correctly', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        final copy = config.copyWith(model: 'gpt-4o-mini');
        expect(copy.model, equals('gpt-4o-mini'));
        expect(copy.apiKey, equals('test-key'));
        expect(copy.host, equals('https://api.openai.com/v1'));
      });

      test('normalizedHost strips trailing slash', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.openai.com/v1/',
        );
        expect(config.normalizedHost.endsWith('/'), isFalse);
        expect(config.normalizedHost, equals('https://api.openai.com/v1'));
      });

      test('normalizedHost returns host as-is when no trailing slash', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.openai.com/v1',
        );
        expect(config.normalizedHost, equals('https://api.openai.com/v1'));
      });

      test(
          'normalizedHost preserves full endpoint path (no stripping of /chat/completions)',
          () {
        // The service uses normalizedHost as the request URL directly.
        // Users enter the full endpoint URL (e.g. .../chat/completions),
        // and normalizedHost preserves it without stripping or appending.
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.openai.com/v1/chat/completions',
        );
        expect(config.normalizedHost,
            equals('https://api.openai.com/v1/chat/completions'));
        expect(config.normalizedHost.endsWith('/chat/completions'), isTrue);
      });

      test('effectiveSystemPrompt uses default when null', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.test.com',
        );
        expect(config.effectiveSystemPrompt, contains('提取图片'));
      });

      test('effectiveSystemPrompt uses custom when provided', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.test.com',
          systemPrompt: 'Custom prompt',
        );
        expect(config.effectiveSystemPrompt, equals('Custom prompt'));
      });
    });

    group('OcrResult', () {
      test('can be created with all fields', () {
        final result = OcrResult(
          text: 'Extracted text',
          processingTimeMs: 1500,
          imageCount: 3,
        );
        expect(result.text, equals('Extracted text'));
        expect(result.processingTimeMs, equals(1500));
        expect(result.imageCount, equals(3));
      });

      test('default values', () {
        final result = OcrResult(text: 'Hello');
        expect(result.processingTimeMs, isZero);
        expect(result.imageCount, equals(1));
      });
    });

    group('OcrService', () {
      test('can be created with config', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        final service = OcrService(config: config);
        expect(service, isNotNull);
      });

      test('Dio has no sendTimeout (no timeout)', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        final service = OcrService(config: config);
        expect(service.sendTimeout, isNull);
      });

      test('Dio has no connectTimeout (no timeout)', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        final service = OcrService(config: config);
        expect(service.connectTimeout, isNull);
      });

      test('Dio has no receiveTimeout (no timeout)', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        final service = OcrService(config: config);
        expect(service.receiveTimeout, isNull);
      });

      test('recognize throws on empty host', () async {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'test-key',
          host: '',
        );
        final service = OcrService(config: config);
        expect(
          () =>
              service.recognize(imageBytes: Uint8List(0), imageFormat: 'jpeg'),
          throwsA(isA<Exception>()),
        );
      });

      test('recognizeBatch throws on empty list', () async {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'test-key',
          host: 'https://api.test.com',
        );
        final service = OcrService(config: config);
        expect(
          () => service.recognizeBatch(imageBytesList: []),
          throwsArgumentError,
        );
      });
    });

    group('createOcrServiceFromConfig', () {
      test('creates service from config fields', () {
        final service = createOcrServiceFromConfig(
          host: 'https://api.test.com',
          apiKey: 'key',
          model: 'gpt-4o',
        );
        expect(service, isNotNull);
        expect(service.config.model, equals('gpt-4o'));
        expect(service.config.apiKey, equals('key'));
        expect(service.config.host, equals('https://api.test.com'));
      });
    });

    group('OcrService response parsing', () {
      test('recognize extracts text from standard response with String content',
          () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {
                'content': '这是图片中的文字内容',
              },
            },
          ],
        });
        final service = OcrService(config: _testOcrConfig, dio: dio);

        final result = await service.recognize(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          imageFormat: 'jpeg',
        );

        expect(result.text, equals('这是图片中的文字内容'));
        // Use greaterThanOrEqualTo(0) because on fast CI runners the mock
        // response may complete in <1ms, making processingTimeMs 0.
        expect(result.processingTimeMs, greaterThanOrEqualTo(0));
        expect(result.imageCount, equals(1));
      });

      test('recognize extracts text when content is a List of text blocks',
          () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {
                'content': [
                  {'type': 'text', 'text': '第一行文字'},
                  {'type': 'text', 'text': '第二行文字'},
                ],
              },
            },
          ],
        });
        final service = OcrService(config: _testOcrConfig, dio: dio);

        final result = await service.recognize(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          imageFormat: 'jpeg',
        );

        expect(result.text, contains('第一行文字'));
        expect(result.text, contains('第二行文字'));
      });

      test(
          'recognize extracts text when content is a List with single text block',
          () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {
                'content': [
                  {'type': 'text', 'text': '这是识别出的文字'},
                ],
              },
            },
          ],
        });
        final service = OcrService(config: _testOcrConfig, dio: dio);

        final result = await service.recognize(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          imageFormat: 'jpeg',
        );

        expect(result.text, equals('这是识别出的文字'));
      });

      test('recognize throws on garbled JSON-bracket content', () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {
                'content': '}}]}}]}}]}}]}}]}}]}}]}}]}}]}',
              },
            },
          ],
        });
        final service = OcrService(config: _testOcrConfig, dio: dio);

        expect(
          () => service.recognize(
            imageBytes: Uint8List.fromList([1, 2, 3]),
            imageFormat: 'jpeg',
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('recognize throws on empty content', () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {
                'content': '',
              },
            },
          ],
        });
        final service = OcrService(config: _testOcrConfig, dio: dio);

        expect(
          () => service.recognize(
            imageBytes: Uint8List.fromList([1, 2, 3]),
            imageFormat: 'jpeg',
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('recognize throws on missing choices', () async {
        final dio = _mockDioWithSuccess({});
        final service = OcrService(config: _testOcrConfig, dio: dio);

        expect(
          () => service.recognize(
            imageBytes: Uint8List.fromList([1, 2, 3]),
            imageFormat: 'jpeg',
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('recognizeBatch extracts text from standard response', () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {
                'content': '批量识别的文字结果',
              },
            },
          ],
        });
        final service = OcrService(config: _testOcrConfig, dio: dio);

        final result = await service.recognizeBatch(
          imageBytesList: [
            (Uint8List.fromList([1, 2, 3]), 'jpeg'),
            (Uint8List.fromList([4, 5, 6]), 'png'),
          ],
        );

        expect(result.text, equals('批量识别的文字结果'));
        expect(result.imageCount, equals(2));
      });

      test('recognizeBatch extracts text when content is a List', () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {
                'content': [
                  {'type': 'text', 'text': '批量结果第一部分'},
                  {'type': 'text', 'text': '批量结果第二部分'},
                ],
              },
            },
          ],
        });
        final service = OcrService(config: _testOcrConfig, dio: dio);

        final result = await service.recognizeBatch(
          imageBytesList: [
            (Uint8List.fromList([1, 2, 3]), 'jpeg'),
          ],
        );

        expect(result.text, contains('批量结果第一部分'));
        expect(result.text, contains('批量结果第二部分'));
      });

      test('recognizeBatch throws on garbled content', () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {
                'content': '}}]}}]}}]',
              },
            },
          ],
        });
        final service = OcrService(config: _testOcrConfig, dio: dio);

        expect(
          () => service.recognizeBatch(
            imageBytesList: [
              (Uint8List.fromList([1, 2, 3]), 'jpeg'),
            ],
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('request body includes max_tokens from typeConfig', () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {'content': 'test'},
            },
          ],
        });
        final config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.test.com',
          typeConfig: {'maxTokens': 2048, 'enableMaxTokens': true},
        );
        final service = OcrService(config: config, dio: dio);
        await service.recognize(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          imageFormat: 'jpeg',
        );
        expect(service.lastRequestBody?['max_tokens'], equals(2048));
      });

      test('request body includes max_tokens when enableMaxTokens is true',
          () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {'content': 'test'},
            },
          ],
        });
        final config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.test.com',
          typeConfig: {'enableMaxTokens': true, 'maxTokens': 4096},
        );
        final service = OcrService(config: config, dio: dio);
        await service.recognize(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          imageFormat: 'jpeg',
        );
        expect(service.lastRequestBody?['max_tokens'], equals(4096));
      });

      test('request body includes temperature from typeConfig when enabled',
          () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {'content': 'test'},
            },
          ],
        });
        final config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.test.com',
          typeConfig: {
            'enableTemperature': true,
            'temperature': 0.5,
            'maxTokens': 4096,
          },
        );
        final service = OcrService(config: config, dio: dio);
        await service.recognize(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          imageFormat: 'jpeg',
        );
        expect(service.lastRequestBody?['temperature'], equals(0.5));
      });

      test('request body omits temperature when not enabled', () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {'content': 'test'},
            },
          ],
        });
        final config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.test.com',
          typeConfig: {
            'enableTemperature': false,
            'temperature': 0.5,
            'maxTokens': 4096,
          },
        );
        final service = OcrService(config: config, dio: dio);
        await service.recognize(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          imageFormat: 'jpeg',
        );
        expect(service.lastRequestBody?['temperature'], isNull);
      });

      test('request body includes top_p from typeConfig when enabled',
          () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {'content': 'test'},
            },
          ],
        });
        final config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.test.com',
          typeConfig: {
            'enableTopP': true,
            'topP': 0.9,
            'maxTokens': 4096,
          },
        );
        final service = OcrService(config: config, dio: dio);
        await service.recognize(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          imageFormat: 'jpeg',
        );
        expect(service.lastRequestBody?['top_p'], equals(0.9));
      });

      test('request body includes seed from typeConfig when enabled', () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {'content': 'test'},
            },
          ],
        });
        final config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.test.com',
          typeConfig: {
            'enableSeed': true,
            'seed': 42,
            'maxTokens': 4096,
          },
        );
        final service = OcrService(config: config, dio: dio);
        await service.recognize(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          imageFormat: 'jpeg',
        );
        expect(service.lastRequestBody?['seed'], equals(42));
      });

      test('request body includes custom params', () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {'content': 'test'},
            },
          ],
        });
        final config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.test.com',
          typeConfig: {'maxTokens': 4096},
          customParams: [
            CustomParam(paramName: 'response_format', defaultValue: 'json'),
          ],
        );
        final service = OcrService(config: config, dio: dio);
        await service.recognize(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          imageFormat: 'jpeg',
        );
        expect(service.lastRequestBody?['response_format'], equals('json'));
      });

      test('custom param supports number type parsing', () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {'content': 'test'},
            },
          ],
        });
        final config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.test.com',
          typeConfig: {'maxTokens': 4096},
          customParams: [
            CustomParam(
              paramName: 'top_k',
              defaultValue: '50',
              type: 'number',
            ),
          ],
        );
        final service = OcrService(config: config, dio: dio);
        await service.recognize(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          imageFormat: 'jpeg',
        );
        // Should be parsed as number
        expect(service.lastRequestBody?['top_k'], equals(50));
        expect(service.lastRequestBody?['top_k'], isA<num>());
      });

      test('custom param supports boolean type parsing', () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {'content': 'test'},
            },
          ],
        });
        final config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.test.com',
          typeConfig: {'maxTokens': 4096},
          customParams: [
            CustomParam(
              paramName: 'stream',
              defaultValue: 'false',
              type: 'boolean',
            ),
          ],
        );
        final service = OcrService(config: config, dio: dio);
        await service.recognize(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          imageFormat: 'jpeg',
        );
        expect(service.lastRequestBody?['stream'], equals(false));
        expect(service.lastRequestBody?['stream'], isA<bool>());
      });

      test('custom param supports json type parsing', () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {'content': 'test'},
            },
          ],
        });
        final config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.test.com',
          typeConfig: {'maxTokens': 4096},
          customParams: [
            CustomParam(
              paramName: 'response_format',
              defaultValue: '{"type": "json_object"}',
              type: 'json',
            ),
          ],
        );
        final service = OcrService(config: config, dio: dio);
        await service.recognize(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          imageFormat: 'jpeg',
        );
        expect(service.lastRequestBody?['response_format'], isA<Map>());
        expect(
          (service.lastRequestBody?['response_format'] as Map)['type'],
          equals('json_object'),
        );
      });

      test('max_tokens omitted when enableMaxTokens is false', () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {'content': 'test'},
            },
          ],
        });
        final config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.test.com',
          typeConfig: {
            'enableMaxTokens': false,
            'maxTokens': 2048,
          },
        );
        final service = OcrService(config: config, dio: dio);
        await service.recognize(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          imageFormat: 'jpeg',
        );
        expect(service.lastRequestBody?['max_tokens'], isNull);
      });

      test('top_p omitted when not enabled', () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {'content': 'test'},
            },
          ],
        });
        final config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.test.com',
          typeConfig: {
            'enableTopP': false,
            'topP': 0.9,
            'maxTokens': 4096,
          },
        );
        final service = OcrService(config: config, dio: dio);
        await service.recognize(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          imageFormat: 'jpeg',
        );
        expect(service.lastRequestBody?['top_p'], isNull);
      });

      test('seed omitted when not enabled', () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {'content': 'test'},
            },
          ],
        });
        final config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.test.com',
          typeConfig: {
            'enableSeed': false,
            'seed': 42,
            'maxTokens': 4096,
          },
        );
        final service = OcrService(config: config, dio: dio);
        await service.recognize(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          imageFormat: 'jpeg',
        );
        expect(service.lastRequestBody?['seed'], isNull);
      });

      test('detail defaults to omitted when enableDetail is false', () async {
        Map<String, dynamic>? capturedBody;
        final dio = Dio()
          ..interceptors.add(_InterceptorWithCallback(
            callback: (options, handler) {
              capturedBody = options.data as Map<String, dynamic>;
              handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'choices': [
                    {
                      'message': {'content': 'test'},
                    },
                  ],
                },
              ));
            },
          ));
        final config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.test.com',
          typeConfig: {
            'enableDetail': false,
            'detail': 'high',
            'maxTokens': 4096,
          },
        );
        final service = OcrService(config: config, dio: dio);
        await service.recognize(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          imageFormat: 'jpeg',
        );
        final messages = capturedBody?['messages'] as List?;
        final userContent = messages?.lastWhere(
          (m) => m['role'] == 'user',
        )['content'] as List;
        final imageUrl = userContent.firstWhere(
          (c) => c['type'] == 'image_url',
        )['image_url'] as Map;
        // When toggle is off, detail should NOT be in the image_url
        expect(imageUrl.containsKey('detail'), isFalse);
      });

      test('image content includes detail from typeConfig', () async {
        // We need a custom interceptor to capture the request body
        Map<String, dynamic>? capturedBody;
        final dio = Dio()
          ..interceptors.add(_InterceptorWithCallback(
            callback: (options, handler) {
              capturedBody = options.data as Map<String, dynamic>;
              handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'choices': [
                    {
                      'message': {'content': 'test'},
                    },
                  ],
                },
              ));
            },
          ));
        final config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.test.com',
          typeConfig: {
            'enableDetail': true,
            'detail': 'low',
            'maxTokens': 4096,
          },
        );
        final service = OcrService(config: config, dio: dio);
        await service.recognize(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          imageFormat: 'jpeg',
        );
        final messages = capturedBody?['messages'] as List?;
        final userContent = messages?.lastWhere(
          (m) => m['role'] == 'user',
        )['content'] as List;
        final imageUrl = userContent.firstWhere(
          (c) => c['type'] == 'image_url',
        )['image_url'] as Map;
        expect(imageUrl['detail'], equals('low'));
      });

      test('diagnostics are captured on successful response', () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {
                'content': 'test text',
              },
            },
          ],
        });
        final service = OcrService(config: _testOcrConfig, dio: dio);

        await service.recognize(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          imageFormat: 'jpeg',
        );

        expect(service.lastRequestBody, isNotNull);
        expect(service.lastRequestUrl, isNotNull);
        expect(service.lastRequestHeaders, isNotNull);
        expect(service.lastResponseData, isNotNull);
        expect(service.lastResponseStatusCode, equals(200));
      });
    });
  });
}
