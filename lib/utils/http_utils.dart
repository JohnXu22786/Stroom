import 'package:dio/dio.dart';

// ============================================================================
// Shared DioException Utility
// ============================================================================

/// Wraps a [DioException] into a user-friendly [Exception], extracting HTTP
/// status code and response body detail.
///
/// This is the single source of truth for DioException handling across all
/// service types (chat, OCR, ASR, and any future HTTP-based services).
///
/// Message format:
/// - With HTTP status: `Exception('请求失败 (HTTP $statusCode): $detail')`
/// - Without HTTP status (connection error): `Exception('请求失败: $detail')`
Never throwWrappedDioException(DioException e) {
  final statusCode = e.response?.statusCode ?? 0;
  String detail;
  final body = e.response?.data;
  if (body is Map) {
    detail =
        body['error'] is Map ? '${body['error']['message'] ?? body}' : '$body';
  } else if (body is String) {
    detail = body;
  } else {
    detail = '$e';
  }
  if (statusCode > 0) {
    throw Exception('请求失败 (HTTP $statusCode): $detail');
  }
  throw Exception('请求失败: $detail');
}
