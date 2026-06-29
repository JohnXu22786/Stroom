import 'package:dio/dio.dart';

// ============================================================================
// Shared Dio mock helpers for tests
// ============================================================================
// Usage:
//   import '../mock_helpers.dart';
//   final dio = mockDioSuccess({'key': 'value'});
// ============================================================================

/// An interceptor that resolves all requests with a 200 response.
class SuccessInterceptor extends Interceptor {
  final dynamic data;
  final int statusCode;

  SuccessInterceptor(this.data, {this.statusCode = 200});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.resolve(Response(
      requestOptions: options,
      statusCode: statusCode,
      data: data,
    ));
  }
}

/// An interceptor that rejects all requests with a [DioException].
class ThrowingInterceptor extends Interceptor {
  final DioException exception;

  ThrowingInterceptor(this.exception);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.reject(exception);
  }
}

/// Create a mock Dio that returns a successful 200 response with [data].
Dio mockDioSuccess(dynamic data) {
  return Dio()..interceptors.add(SuccessInterceptor(data));
}

/// Create a mock Dio that returns the given [body] at [statusCode].
Dio mockDioStatus(String body, int statusCode) {
  return Dio()..interceptors.add(SuccessInterceptor(body, statusCode: statusCode));
}

/// Create a mock Dio that returns a successful response after [delay].
Dio mockDioWithDelay(dynamic data, Duration delay) {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      await Future.delayed(delay);
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: data,
      ));
    },
  ));
  return dio;
}

/// Create a mock Dio that throws a [DioException] with the given HTTP status.
Dio mockDioHttpError({
  int statusCode = 400,
  dynamic data,
  String? message,
  String path = 'http://example.com/chat/completions',
}) {
  final response = Response(
    requestOptions: RequestOptions(path: path),
    statusCode: statusCode,
    data: data,
  );
  final exception = DioException(
    type: DioExceptionType.badResponse,
    requestOptions: RequestOptions(path: path),
    response: response,
    message: message ?? 'Bad response',
  );
  return Dio()..interceptors.add(ThrowingInterceptor(exception));
}

/// Create a mock Dio that throws a connection timeout error.
Dio mockDioConnectionError({String path = 'http://example.com/chat/completions'}) {
  final exception = DioException(
    type: DioExceptionType.connectionTimeout,
    requestOptions: RequestOptions(path: path),
    message: 'The request connection timed out',
  );
  return Dio()..interceptors.add(ThrowingInterceptor(exception));
}
