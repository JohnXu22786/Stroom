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
      test('normalizedHost preserves trailing slash', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.openai.com/v1/',
        );
        expect(config.normalizedHost.endsWith('/'), isTrue);
        expect(config.normalizedHost, equals('https://api.openai.com/v1/'));
      });

      test('normalizedHost returns host as-is when no trailing slash', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.openai.com/v1',
        );
        expect(config.normalizedHost, equals('https://api.openai.com/v1'));
      });

      test('normalizedHost preserves full endpoint path and trailing slash',
          () {
        // The service uses normalizedHost as the request URL directly. Users
        // enter the full endpoint URL, which must be preserved verbatim.
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'key',
          host: 'https://api.openai.com/v1/chat/completions/',
        );
        expect(config.normalizedHost,
            equals('https://api.openai.com/v1/chat/completions/'));
        expect(config.normalizedHost.endsWith('/chat/completions/'), isTrue);
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

    group('OcrService', () {
      test('Dio has upload timeout base', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        final service = OcrService(config: config);
        expect(service.sendTimeout, const Duration(minutes: 1));
      });

      test('Dio has connection timeout', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        final service = OcrService(config: config);
        expect(service.connectTimeout, const Duration(seconds: 30));
      });

      test('Dio has long response fallback', () {
        const config = OcrConfig(
          model: 'gpt-4o',
          apiKey: 'test-key',
          host: 'https://api.openai.com/v1',
        );
        final service = OcrService(config: config);
        expect(service.receiveTimeout, const Duration(minutes: 60));
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

      test('recognize rejects refusal results', () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {
                'refusal': 'I cannot process this image.',
                'content': 'This text must not be accepted.',
              },
            },
          ],
        });
        final service = OcrService(config: _testOcrConfig, dio: dio);

        expect(
          () => service.recognize(imageBytes: Uint8List.fromList([1, 2, 3])),
          throwsA(isA<Exception>()),
        );
      });

      test('recognize rejects non-text content blocks', () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {
                'content': [
                  {'type': 'text', 'text': 'text that must not be accepted'},
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'data:image/png'}
                  },
                ],
              },
            },
          ],
        });
        final service = OcrService(config: _testOcrConfig, dio: dio);

        expect(
          () => service.recognize(imageBytes: Uint8List.fromList([1, 2, 3])),
          throwsA(isA<Exception>()),
        );
      });

      test('recognize retains text and marks a length-truncated result',
          () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'finish_reason': 'length',
              'message': {'content': 'partial OCR text'},
            },
          ],
        });
        final service = OcrService(config: _testOcrConfig, dio: dio);

        final result = await service.recognize(
          imageBytes: Uint8List.fromList([1, 2, 3]),
        );

        expect(result.text, 'partial OCR text');
        expect(result.isComplete, isFalse);
        expect(result.finishReason, 'length');
      });

      test('custom params cannot replace protected request fields', () async {
        for (final protectedName in ['model', 'messages']) {
          var sent = false;
          final dio = Dio()
            ..interceptors.add(_InterceptorWithCallback(
              callback: (options, handler) {
                sent = true;
                handler.resolve(Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'choices': [
                      {
                        'message': {'content': 'ok'},
                      },
                    ],
                  },
                ));
              },
            ));
          final service = OcrService(
            config: OcrConfig(
              model: 'expected-model',
              apiKey: 'key',
              host: 'https://api.test.com/v1/chat/completions',
              customParams: [
                CustomParam(
                  paramName: protectedName,
                  defaultValue: 'custom-value',
                ),
              ],
            ),
            dio: dio,
          );

          await expectLater(
            service.recognize(imageBytes: Uint8List.fromList([1])),
            throwsArgumentError,
          );
          expect(sent, isFalse);
        }
      });

      test('custom stream=true is rejected before sending', () async {
        var sent = false;
        final dio = Dio()
          ..interceptors.add(_InterceptorWithCallback(
            callback: (options, handler) {
              sent = true;
              handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'choices': [
                    {
                      'message': {'content': 'ok'}
                    }
                  ]
                },
              ));
            },
          ));
        final service = OcrService(
          config: OcrConfig(
            model: 'gpt-4o',
            apiKey: 'key',
            host: 'https://api.test.com',
            customParams: [
              CustomParam(
                paramName: 'stream',
                defaultValue: 'true',
                type: 'boolean',
              ),
            ],
          ),
          dio: dio,
        );

        await expectLater(
          service.recognize(imageBytes: Uint8List.fromList([1])),
          throwsArgumentError,
        );
        expect(sent, isFalse);
      });

      test('empty boolean stream parameter defaults true and is rejected',
          () async {
        var sent = false;
        final dio = Dio()
          ..interceptors.add(_InterceptorWithCallback(
            callback: (options, handler) {
              sent = true;
              handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'choices': [
                    {
                      'message': {'content': 'unexpected'}
                    }
                  ]
                },
              ));
            },
          ));
        final service = OcrService(
          config: OcrConfig(
            model: 'gpt-4o',
            apiKey: 'key',
            host: 'https://api.test.com',
            customParams: [
              CustomParam(paramName: 'stream', type: 'boolean'),
            ],
          ),
          dio: dio,
        );

        await expectLater(
          service.recognize(imageBytes: Uint8List.fromList([1, 2, 3])),
          throwsArgumentError,
        );
        expect(sent, isFalse);
      });

      test('invalid custom parameter values are rejected before sending',
          () async {
        var sent = false;
        final dio = Dio()
          ..interceptors.add(_InterceptorWithCallback(
            callback: (options, handler) {
              sent = true;
              handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'choices': [
                    {
                      'message': {'content': 'ok'}
                    }
                  ]
                },
              ));
            },
          ));
        final service = OcrService(
          config: OcrConfig(
            model: 'gpt-4o',
            apiKey: 'key',
            host: 'https://api.test.com',
            customParams: [
              CustomParam(
                paramName: 'top_k',
                defaultValue: 'many',
                type: 'number',
              ),
            ],
          ),
          dio: dio,
        );

        await expectLater(
          service.recognize(imageBytes: Uint8List.fromList([1])),
          throwsFormatException,
        );
        expect(sent, isFalse);
      });

      test('invalid boolean and JSON custom parameter values are rejected',
          () async {
        for (final param in [
          CustomParam(
            paramName: 'enabled',
            defaultValue: 'sometimes',
            type: 'boolean',
          ),
          CustomParam(
            paramName: 'response_format',
            defaultValue: '{invalid json',
            type: 'json',
          ),
        ]) {
          final service = OcrService(
            config: OcrConfig(
              model: 'gpt-4o',
              apiKey: 'key',
              host: 'https://api.test.com',
              customParams: [param],
            ),
            dio: _mockDioWithSuccess({
              'choices': [
                {
                  'message': {'content': 'unexpected'},
                },
              ],
            }),
          );

          await expectLater(
            service.recognize(imageBytes: Uint8List.fromList([1])),
            throwsFormatException,
          );
        }
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

      test('single image with userInstruction sends instruction after image',
          () async {
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
          model: 'qwen-vl-ocr',
          apiKey: 'key',
          host: 'https://api.test.com',
          typeConfig: {
            'userInstruction': '提取发票号码和金额，以 JSON 输出',
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
        // Official qwen-vl-ocr / DeepSeek-OCR examples put the image first,
        // the instruction text after it.
        expect(userContent.length, equals(2));
        expect(userContent[0]['type'], equals('image_url'));
        expect(
            userContent[1],
            equals({
              'type': 'text',
              'text': '提取发票号码和金额，以 JSON 输出',
            }));
      });

      test(
          'batch with userInstruction sends instruction after all images '
          'without per-image labels', () async {
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
          model: 'qwen-vl-ocr',
          apiKey: 'key',
          host: 'https://api.test.com',
          typeConfig: {
            'userInstruction': '提取每张图片中的全部文字',
            'maxTokens': 4096,
          },
        );
        final service = OcrService(config: config, dio: dio);
        await service.recognizeBatch(
          imageBytesList: [
            (Uint8List.fromList([1, 2, 3]), 'jpeg'),
            (Uint8List.fromList([4, 5, 6]), 'jpeg'),
          ],
        );
        final messages = capturedBody?['messages'] as List?;
        final userContent = messages?.lastWhere(
          (m) => m['role'] == 'user',
        )['content'] as List;
        // Consecutive images (no "图片 N：" labels), instruction text last.
        expect(userContent.length, equals(3));
        expect(userContent[0]['type'], equals('image_url'));
        expect(userContent[1]['type'], equals('image_url'));
        expect(
            userContent[2],
            equals({
              'type': 'text',
              'text': '提取每张图片中的全部文字',
            }));
        final textParts =
            userContent.where((c) => c['type'] == 'text').toList();
        expect(textParts.length, equals(1));
      });

      test('single image without instruction has only the image', () async {
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
          model: 'qwen-vl-ocr',
          apiKey: 'key',
          host: 'https://api.test.com',
          typeConfig: {'maxTokens': 4096},
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
        expect(userContent.length, equals(1));
        expect(userContent[0]['type'], equals('image_url'));
      });

      test('batch without instruction has only images (no labels)', () async {
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
          model: 'qwen-vl-ocr',
          apiKey: 'key',
          host: 'https://api.test.com',
          typeConfig: {'maxTokens': 4096},
        );
        final service = OcrService(config: config, dio: dio);
        await service.recognizeBatch(
          imageBytesList: [
            (Uint8List.fromList([1, 2, 3]), 'jpeg'),
            (Uint8List.fromList([4, 5, 6]), 'jpeg'),
          ],
        );
        final messages = capturedBody?['messages'] as List?;
        final userContent = messages?.lastWhere(
          (m) => m['role'] == 'user',
        )['content'] as List;
        expect(userContent.length, equals(2));
        expect(userContent.every((c) => c['type'] == 'image_url'), isTrue);
      });

      test('whitespace-only instruction is treated as absent', () async {
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
          model: 'qwen-vl-ocr',
          apiKey: 'key',
          host: 'https://api.test.com',
          typeConfig: {
            'userInstruction': '   \n\n  ',
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
        expect(userContent.length, equals(1));
        expect(userContent[0]['type'], equals('image_url'));
      });

      test('multi-line instruction is sent as a single text part', () async {
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
          model: 'qwen-vl-ocr',
          apiKey: 'key',
          host: 'https://api.test.com',
          typeConfig: {
            'userInstruction': '第一行\n第二行',
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
        expect(userContent.length, equals(2));
        expect(userContent[1], equals({'type': 'text', 'text': '第一行\n第二行'}));
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

      test('custom params use the first option when default value is empty',
          () async {
        final dio = _mockDioWithSuccess({
          'choices': [
            {
              'message': {'content': 'test'},
            },
          ],
        });
        final service = OcrService(
          config: OcrConfig(
            model: 'gpt-4o',
            apiKey: 'key',
            host: 'https://api.test.com',
            customParams: [
              CustomParam(
                paramName: 'top_k',
                defaultValue: '',
                type: 'number',
                options: ['50', '100'],
              ),
            ],
          ),
          dio: dio,
        );

        await service.recognize(imageBytes: Uint8List.fromList([1, 2, 3]));

        expect(service.lastRequestBody?['top_k'], equals(50));
      });

      test('string custom params preserve selected value whitespace', () async {
        final service = OcrService(
          config: OcrConfig(
            model: 'gpt-4o',
            apiKey: 'key',
            host: 'https://api.test.com',
            customParams: [
              CustomParam(
                paramName: 'user_tag',
                defaultValue: 'fallback',
                type: 'string',
                options: ['  exact text  '],
              ),
            ],
          ),
          dio: _mockDioWithSuccess({
            'choices': [
              {
                'message': {'content': 'test'},
              },
            ],
          }),
        );

        await service.recognize(imageBytes: Uint8List.fromList([1, 2, 3]));

        expect(service.lastRequestBody?['user_tag'], equals('  exact text  '));
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

      test('boolean custom params default to true when value is empty',
          () async {
        final service = OcrService(
          config: OcrConfig(
            model: 'gpt-4o',
            apiKey: 'key',
            host: 'https://api.test.com',
            customParams: [
              CustomParam(paramName: 'enabled', type: 'boolean'),
            ],
          ),
          dio: _mockDioWithSuccess({
            'choices': [
              {
                'message': {'content': 'test'},
              },
            ],
          }),
        );

        await service.recognize(imageBytes: Uint8List.fromList([1, 2, 3]));

        expect(service.lastRequestBody?['enabled'], isTrue);
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
