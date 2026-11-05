import 'package:dio/dio.dart';

/// Converts a failed browser XHR into the equivalent Dio transport error.
///
/// Keeping the conversion independent of `dart:html` lets the error
/// classification and Retry-After metadata be covered by platform-neutral
/// tests while the web client supplies the XHR response fields.
DioException createSseClientWebFailure({
  required String url,
  required int? statusCode,
  required String? statusText,
  required String? responseBody,
  Map<String, List<String>> responseHeaders = const {},
}) {
  final requestOptions = RequestOptions(path: url);
  if (statusCode != null && statusCode >= 400) {
    return DioException(
      requestOptions: requestOptions,
      response: Response(
        requestOptions: requestOptions,
        data: responseBody,
        statusCode: statusCode,
        statusMessage: statusText,
        headers: Headers.fromMap(responseHeaders),
      ),
      type: DioExceptionType.badResponse,
    );
  }
  return DioException(
    requestOptions: requestOptions,
    message: statusCode != null && statusCode != 0
        ? '网络请求失败 (HTTP $statusCode${(statusText ?? '').isNotEmpty ? ': $statusText' : ''})'
        : '网络请求失败: 无法连接到服务器',
    type: DioExceptionType.connectionError,
  );
}
