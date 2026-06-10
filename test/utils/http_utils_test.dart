import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import 'package:stroom/utils/http_utils.dart';

// ============================================================================
// Helpers
// ============================================================================

DioException _makeDioException({
  required int statusCode,
  dynamic data,
  DioExceptionType type = DioExceptionType.badResponse,
  String? message,
}) {
  final response = data != null
      ? Response(
          requestOptions: RequestOptions(path: 'http://example.com/api'),
          statusCode: statusCode,
          data: data,
        )
      : null;
  return DioException(
    type: type,
    requestOptions: RequestOptions(path: 'http://example.com/api'),
    response: response,
    message: message ?? 'Bad response',
  );
}

void main() {
  group('throwWrappedDioException', () {
    test('wraps HTTP 400 with JSON error.message', () {
      final e = _makeDioException(
        statusCode: 400,
        data: {'error': {'message': 'Invalid request'}},
      );

      expect(
        () => throwWrappedDioException(e),
        throwsA(isA<Exception>()),
      );

      // Verify the message content by catching the exception
      Object? caught;
      try {
        throwWrappedDioException(e);
      } catch (ex) {
        caught = ex;
      }
      expect(caught, isNot(isA<DioException>()));
      expect(caught.toString(), contains('HTTP 400'));
      expect(caught.toString(), contains('Invalid request'));
    });

    test('wraps HTTP 500 with plain text body', () {
      final e = _makeDioException(
        statusCode: 500,
        data: 'Internal Server Error',
      );

      Object? caught;
      try {
        throwWrappedDioException(e);
      } catch (ex) {
        caught = ex;
      }
      expect(caught, isNot(isA<DioException>()));
      expect(caught.toString(), contains('HTTP 500'));
      expect(caught.toString(), contains('Internal Server Error'));
    });

    test('wraps connection error (no response) without HTTP prefix', () {
      final e = _makeDioException(
        statusCode: 0,
        data: null, // no response
        type: DioExceptionType.connectionTimeout,
        message: 'Connection timed out',
      );

      Object? caught;
      try {
        throwWrappedDioException(e);
      } catch (ex) {
        caught = ex;
      }
      expect(caught, isNot(isA<DioException>()));
      expect(caught.toString(), contains('请求失败'));
      expect(caught.toString(), isNot(contains('(HTTP')));
    });

    test('wraps with Map body but no error key', () {
      final e = _makeDioException(
        statusCode: 422,
        data: {'detail': 'Image too large'},
      );

      Object? caught;
      try {
        throwWrappedDioException(e);
      } catch (ex) {
        caught = ex;
      }
      expect(caught, isNot(isA<DioException>()));
      expect(caught.toString(), contains('HTTP 422'));
      expect(caught.toString(), contains('Image too large'));
    });

    test('wraps with null body falls back to DioException string', () {
      // A response with null data: DioException with response but null body
      final response = Response(
        requestOptions: RequestOptions(path: 'http://example.com/api'),
        statusCode: 503,
        data: null,
      );
      final e = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: 'http://example.com/api'),
        response: response,
        message: 'Service Unavailable',
      );

      Object? caught;
      try {
        throwWrappedDioException(e);
      } catch (ex) {
        caught = ex;
      }
      expect(caught, isNot(isA<DioException>()));
      expect(caught.toString(), contains('HTTP 503'));
      expect(caught.toString(), contains('DioException'));
    });

    test('wraps with error as non-Map', () {
      final e = _makeDioException(
        statusCode: 401,
        data: {'error': 'Unauthorized'},
      );

      Object? caught;
      try {
        throwWrappedDioException(e);
      } catch (ex) {
        caught = ex;
      }
      expect(caught, isNot(isA<DioException>()));
      expect(caught.toString(), contains('HTTP 401'));
      expect(caught.toString(), contains('Unauthorized'));
    });

    test('wraps with error Map missing message key', () {
      final e = _makeDioException(
        statusCode: 400,
        data: {'error': {'code': 12345}},
      );

      Object? caught;
      try {
        throwWrappedDioException(e);
      } catch (ex) {
        caught = ex;
      }
      expect(caught, isNot(isA<DioException>()));
      expect(caught.toString(), contains('HTTP 400'));
      // Falls back to full body since message is null
      expect(caught.toString(), contains('code'));
      expect(caught.toString(), contains('12345'));
    });
  });

  group('chat_page formatChatErrorMessage compatibility', () {
    // Simulates the chat page's formatChatErrorMessage logic
    String formatChatErrorMessage(Object error) {
      final errorStr = error.toString();
      if (errorStr.contains('HTTP ')) {
        return '错误: $errorStr';
      }
      if (errorStr.contains('timeout') || errorStr.contains('超时')) {
        return '错误: 连接超时，服务器无响应\n$errorStr';
      }
      if (errorStr.contains('SocketException') ||
          errorStr.contains('Connection refused')) {
        return '错误: 网络连接失败，请检查网络连接\n$errorStr';
      }
      return '错误: $errorStr';
    }

    test('HTTP 400 from throwWrappedDioException is recognized by formatChatErrorMessage', () {
      final e = _makeDioException(
        statusCode: 400,
        data: {'error': {'message': 'Bad request'}},
      );

      Object? caught;
      try {
        throwWrappedDioException(e);
      } catch (ex) {
        caught = ex;
      }

      final msg = formatChatErrorMessage(caught!);
      expect(msg, contains('HTTP 400'));
      expect(msg, contains('Bad request'));
      expect(msg, startsWith('错误:'));
    });

    test('connection error from throwWrappedDioException shows in fallback', () {
      final e = _makeDioException(
        statusCode: 0,
        data: null,
        type: DioExceptionType.connectionTimeout,
      );

      Object? caught;
      try {
        throwWrappedDioException(e);
      } catch (ex) {
        caught = ex;
      }

      final msg = formatChatErrorMessage(caught!);
      expect(msg, contains('DioException'));
    });
  });
}
