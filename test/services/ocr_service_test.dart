import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/ocr_service.dart';
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

/// Create a mock Dio that throws a [DioException].
Dio _mockDioWithError({int statusCode = 400, dynamic data}) {
  final response = Response(
    requestOptions: RequestOptions(path: 'http://example.com/chat/completions'),
    statusCode: statusCode,
    data: data,
  );
  final exception = DioException(
    type: DioExceptionType.badResponse,
    requestOptions: RequestOptions(path: 'http://example.com/chat/completions'),
    response: response,
    message: 'Bad response',
  );
  return Dio()..interceptors.add(_ThrowingInterceptor(exception));
}

class _ThrowingInterceptor extends Interceptor {
  final DioException _exception;
  _ThrowingInterceptor(this._exception);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.reject(_exception);
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

      test('normalizedHost preserves full endpoint path (no stripping of /chat/completions)', () {
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

      test('Dio has sendTimeout configured', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        final service = OcrService(config: config);
        expect(service.sendTimeout, isNotNull);
        expect(service.sendTimeout!.inSeconds, equals(60));
      });

      test('Dio has connectTimeout configured', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        final service = OcrService(config: config);
        expect(service.connectTimeout, isNotNull);
        expect(service.connectTimeout!.inSeconds, equals(30));
      });

      test('Dio has receiveTimeout configured', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        final service = OcrService(config: config);
        expect(service.receiveTimeout, isNotNull);
        expect(service.receiveTimeout!.inSeconds, equals(120));
      });

      test('recognize throws on empty host', () async {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'test-key',
          host: '',
        );
        final service = OcrService(config: config);
        expect(
          () => service.recognize(imageBytes: Uint8List(0), imageFormat: 'jpeg'),
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
      test('recognize extracts text from standard response with String content', () async {
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

      test('recognize extracts text when content is a List of text blocks', () async {
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

      test('recognize extracts text when content is a List with single text block', () async {
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
