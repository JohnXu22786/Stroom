import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'dart:typed_data';

import 'package:stroom/services/ocr_service.dart';
import 'package:stroom/services/asr_service.dart';

// ============================================================================
// Helpers
// ============================================================================

/// Create a mock Dio that throws a [DioException] when any request is made.
Dio _mockDioWithHttpError({
  required int statusCode,
  dynamic data,
  String? message,
}) {
  final response = Response(
    requestOptions: RequestOptions(path: 'http://example.com/chat/completions'),
    statusCode: statusCode,
    data: data,
  );
  final exception = DioException(
    type: DioExceptionType.badResponse,
    requestOptions: RequestOptions(path: 'http://example.com/chat/completions'),
    response: response,
    message: message ?? 'Bad response',
  );
  return Dio()..interceptors.add(_ThrowingInterceptor(exception));
}

/// Create a mock Dio that throws a connection error [DioException].
Dio _mockDioWithConnectionError() {
  final exception = DioException(
    type: DioExceptionType.connectionTimeout,
    requestOptions: RequestOptions(path: 'http://example.com/chat/completions'),
    message: 'The request connection timed out',
  );
  return Dio()..interceptors.add(_ThrowingInterceptor(exception));
}

/// An interceptor that always rejects the request with the given [DioException].
class _ThrowingInterceptor extends Interceptor {
  final DioException _exception;
  _ThrowingInterceptor(this._exception);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.reject(_exception);
  }
}

// ============================================================================
// Common test configs
// ============================================================================

const _ocrConfig = OcrConfig(
  model: 'gpt-4o',
  apiKey: 'test-key',
  host: 'https://api.test.com/v1',
);

const _asrConfig = AsrConfig(
  model: 'whisper-1',
  apiKey: 'test-key',
  host: 'https://api.test.com/v1',
);

void main() {
  group('OcrService DioException handling', () {
    test(
        'DioException with HTTP 400 and JSON error body is wrapped as friendly Exception',
        () async {
      final dio = _mockDioWithHttpError(
        statusCode: 400,
        data: {
          'error': {'message': 'Invalid image format'}
        },
      );
      final service = OcrService(config: _ocrConfig, dio: dio);

      Object? caught;
      try {
        await service.recognize(imageBytes: Uint8List.fromList([1, 2, 3]));
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<Exception>());
      expect(caught, isNot(isA<DioException>()));
      expect(caught.toString(), contains('HTTP 400'));
      expect(caught.toString(), contains('Invalid image format'));
    });

    test('DioException with HTTP 500 and plain text body is wrapped', () async {
      final dio = _mockDioWithHttpError(
        statusCode: 500,
        data: 'Internal Server Error',
      );
      final service = OcrService(config: _ocrConfig, dio: dio);

      Object? caught;
      try {
        await service.recognize(imageBytes: Uint8List.fromList([1, 2, 3]));
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<Exception>());
      expect(caught, isNot(isA<DioException>()));
      expect(caught.toString(), contains('HTTP 500'));
      expect(caught.toString(), contains('Internal Server Error'));
    });

    test('DioException with no response (connection error) is wrapped',
        () async {
      final dio = _mockDioWithConnectionError();
      final service = OcrService(config: _ocrConfig, dio: dio);

      Object? caught;
      try {
        await service.recognize(imageBytes: Uint8List.fromList([1, 2, 3]));
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<Exception>());
      expect(caught, isNot(isA<DioException>()));
      // Connection errors don't have an HTTP status code — no "(HTTP" in message
      expect(caught.toString(), contains('请求失败'));
      expect(caught.toString(), isNot(contains('(HTTP')));
    });

    test('DioException on recognizeBatch is also wrapped', () async {
      final dio = _mockDioWithHttpError(
        statusCode: 429,
        data: {
          'error': {'message': 'Rate limit exceeded'}
        },
      );
      final service = OcrService(config: _ocrConfig, dio: dio);

      Object? caught;
      try {
        await service.recognizeBatch(
          imageBytesList: [
            (Uint8List.fromList([1, 2, 3]), 'jpeg'),
          ],
        );
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<Exception>());
      expect(caught, isNot(isA<DioException>()));
      expect(caught.toString(), contains('HTTP 429'));
      expect(caught.toString(), contains('Rate limit exceeded'));
    });

    test('DioException with Map body (no error key) extracts full body',
        () async {
      final dio = _mockDioWithHttpError(
        statusCode: 422,
        data: {'detail': 'Image too large'},
      );
      final service = OcrService(config: _ocrConfig, dio: dio);

      Object? caught;
      try {
        await service.recognize(imageBytes: Uint8List.fromList([1, 2, 3]));
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<Exception>());
      expect(caught, isNot(isA<DioException>()));
      expect(caught.toString(), contains('HTTP 422'));
      expect(caught.toString(), contains('Image too large'));
    });

    test('DioException with null body falls back to exception string',
        () async {
      final dio = _mockDioWithHttpError(
        statusCode: 503,
        data: null,
      );
      final service = OcrService(config: _ocrConfig, dio: dio);

      Object? caught;
      try {
        await service.recognize(imageBytes: Uint8List.fromList([1, 2, 3]));
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<Exception>());
      expect(caught, isNot(isA<DioException>()));
      expect(caught.toString(), contains('HTTP 503'));
      expect(caught.toString(), contains('DioException'));
    });

    test('DioException with error as non-Map extracts full body', () async {
      final dio = _mockDioWithHttpError(
        statusCode: 401,
        data: {'error': 'Unauthorized'},
      );
      final service = OcrService(config: _ocrConfig, dio: dio);

      Object? caught;
      try {
        await service.recognize(imageBytes: Uint8List.fromList([1, 2, 3]));
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<Exception>());
      expect(caught, isNot(isA<DioException>()));
      expect(caught.toString(), contains('HTTP 401'));
      expect(caught.toString(), contains('Unauthorized'));
    });

    test('captures diagnostic fields on HTTP error', () async {
      final dio = _mockDioWithHttpError(
        statusCode: 400,
        data: {
          'error': {'message': 'Bad request'}
        },
      );
      final service = OcrService(config: _ocrConfig, dio: dio);

      try {
        await service.recognize(imageBytes: Uint8List.fromList([1, 2, 3]));
      } catch (_) {}

      expect(service.lastRequestBody, isNotNull);
      expect(service.lastRequestUrl, isNotNull);
      expect(service.lastRequestHeaders, isNotNull);
      expect(service.lastResponseStatusCode, equals(400));
      expect(service.lastResponseData, isNotNull);
      expect(service.lastResponseHeaders, isNotNull);
    });

    test('captures diagnostic fields on connection error', () async {
      final dio = _mockDioWithConnectionError();
      final service = OcrService(config: _ocrConfig, dio: dio);

      try {
        await service.recognize(imageBytes: Uint8List.fromList([1, 2, 3]));
      } catch (_) {}

      expect(service.lastRequestBody, isNotNull);
      expect(service.lastRequestUrl, isNotNull);
      expect(service.lastRequestHeaders, isNotNull);
      // No response for connection errors
      expect(service.lastResponseStatusCode, isNull);
      expect(service.lastResponseData, isNull);
    });
  });

  group('AsrService DioException handling', () {
    test(
        'DioException with HTTP 400 and JSON error body is wrapped as friendly Exception',
        () async {
      final dio = _mockDioWithHttpError(
        statusCode: 400,
        data: {
          'error': {'message': 'Invalid audio format'}
        },
      );
      final service = AsrService(config: _asrConfig, dio: dio);

      Object? caught;
      try {
        await service.transcribe(
          audioBytes: Uint8List.fromList([1, 2, 3]),
          audioFormat: 'wav',
        );
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<Exception>());
      expect(caught, isNot(isA<DioException>()));
      expect(caught.toString(), contains('HTTP 400'));
      expect(caught.toString(), contains('Invalid audio format'));
    });

    test('DioException with HTTP 500 and plain text body is wrapped', () async {
      final dio = _mockDioWithHttpError(
        statusCode: 500,
        data: 'Internal Server Error',
      );
      final service = AsrService(config: _asrConfig, dio: dio);

      Object? caught;
      try {
        await service.transcribe(
          audioBytes: Uint8List.fromList([1, 2, 3]),
          audioFormat: 'wav',
        );
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<Exception>());
      expect(caught, isNot(isA<DioException>()));
      expect(caught.toString(), contains('HTTP 500'));
      expect(caught.toString(), contains('Internal Server Error'));
    });

    test('DioException with no response (connection error) is wrapped',
        () async {
      final dio = _mockDioWithConnectionError();
      final service = AsrService(config: _asrConfig, dio: dio);

      Object? caught;
      try {
        await service.transcribe(
          audioBytes: Uint8List.fromList([1, 2, 3]),
          audioFormat: 'wav',
        );
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<Exception>());
      expect(caught, isNot(isA<DioException>()));
      // Connection errors don't have an HTTP status code — no "(HTTP" in message
      expect(caught.toString(), contains('请求失败'));
      expect(caught.toString(), isNot(contains('(HTTP')));
    });

    test('DioException with Map body (no error key) extracts full body',
        () async {
      final dio = _mockDioWithHttpError(
        statusCode: 413,
        data: {'detail': 'Audio file too large'},
      );
      final service = AsrService(config: _asrConfig, dio: dio);

      Object? caught;
      try {
        await service.transcribe(
          audioBytes: Uint8List.fromList([1, 2, 3]),
          audioFormat: 'wav',
        );
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<Exception>());
      expect(caught, isNot(isA<DioException>()));
      expect(caught.toString(), contains('HTTP 413'));
      expect(caught.toString(), contains('Audio file too large'));
    });

    test('DioException with null body falls back to exception string',
        () async {
      final dio = _mockDioWithHttpError(
        statusCode: 504,
        data: null,
      );
      final service = AsrService(config: _asrConfig, dio: dio);

      Object? caught;
      try {
        await service.transcribe(
          audioBytes: Uint8List.fromList([1, 2, 3]),
          audioFormat: 'wav',
        );
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<Exception>());
      expect(caught, isNot(isA<DioException>()));
      expect(caught.toString(), contains('HTTP 504'));
      expect(caught.toString(), contains('DioException'));
    });

    test('DioException with error as non-Map extracts full body', () async {
      final dio = _mockDioWithHttpError(
        statusCode: 403,
        data: {'error': 'Forbidden'},
      );
      final service = AsrService(config: _asrConfig, dio: dio);

      Object? caught;
      try {
        await service.transcribe(
          audioBytes: Uint8List.fromList([1, 2, 3]),
          audioFormat: 'wav',
        );
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<Exception>());
      expect(caught, isNot(isA<DioException>()));
      expect(caught.toString(), contains('HTTP 403'));
      expect(caught.toString(), contains('Forbidden'));
    });

    test('captures diagnostic fields on HTTP error', () async {
      final dio = _mockDioWithHttpError(
        statusCode: 400,
        data: {
          'error': {'message': 'Bad request'}
        },
      );
      final service = AsrService(config: _asrConfig, dio: dio);

      try {
        await service.transcribe(
          audioBytes: Uint8List.fromList([1, 2, 3]),
          audioFormat: 'wav',
        );
      } catch (_) {}

      expect(service.lastRequestBody, isNotNull);
      expect(service.lastRequestUrl, isNotNull);
      expect(service.lastRequestHeaders, isNotNull);
      expect(service.lastResponseStatusCode, equals(400));
      expect(service.lastResponseData, isNotNull);
      expect(service.lastResponseHeaders, isNotNull);
    });

    test('captures diagnostic fields on connection error', () async {
      final dio = _mockDioWithConnectionError();
      final service = AsrService(config: _asrConfig, dio: dio);

      try {
        await service.transcribe(
          audioBytes: Uint8List.fromList([1, 2, 3]),
          audioFormat: 'wav',
        );
      } catch (_) {}

      expect(service.lastRequestBody, isNotNull);
      expect(service.lastRequestUrl, isNotNull);
      expect(service.lastRequestHeaders, isNotNull);
      // No response for connection errors
      expect(service.lastResponseStatusCode, isNull);
      expect(service.lastResponseData, isNull);
    });
  });
}
