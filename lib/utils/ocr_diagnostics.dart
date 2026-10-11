import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

/// Creates small OCR diagnostic maps suitable for task persistence and display.
class OcrDiagnosticSnapshot {
  OcrDiagnosticSnapshot._();

  static const maxSerializedBytes = 2048;
  static const _maxTextLength = 160;
  static const _requestIdHeaders = {
    'x-request-id',
    'request-id',
    'openai-request-id',
    'x-goog-request-id',
    'x-ms-request-id',
  };

  static Map<String, dynamic>? sanitizeRequest(Map<String, dynamic>? source) {
    if (source == null) return null;
    final result = <String, dynamic>{
      if (_safeHost(source['host'] ?? source['url']) case final host?)
        'host': host,
      if (_safeMethod(source['method']) case final method?) 'method': method,
      if (_smallInt(source['imageCount']) case final count?)
        'imageCount': count,
      if (_smallInt(source['imageBytes']) case final bytes?)
        'imageBytes': bytes,
      if (_safeRequestId(source['requestId']) ??
              requestIdFromHeaders(source['headers'])
          case final requestId?)
        'requestId': requestId,
      if (_smallInt(source['durationMs']) case final duration?)
        'durationMs': duration,
    };
    return _bounded(result);
  }

  static Map<String, dynamic>? sanitizeResponse(Map<String, dynamic>? source) {
    if (source == null) return null;
    final data = source['data'];
    final result = <String, dynamic>{
      if (_smallInt(source['statusCode']) ?? _smallInt(source['status'])
          case final status?)
        'statusCode': status,
      if (_safeReason(source['finishReason'] ?? source['finish_reason']) ??
              _finishReasonFromData(data)
          case final reason?)
        'finishReason': reason,
      if (_safeRequestId(source['requestId']) ??
              requestIdFromHeaders(source['headers']) ??
              requestIdFromData(data)
          case final requestId?)
        'requestId': requestId,
      if (_smallInt(source['durationMs']) case final duration?)
        'durationMs': duration,
      if (_safeErrorType(source['errorType']) case final errorType?)
        'errorType': errorType,
    };
    return _bounded(result);
  }

  static Map<String, dynamic> request({
    required String? url,
    required int imageCount,
    required int imageBytes,
    required int? durationMs,
    required String? requestId,
  }) => sanitizeRequest({
    'url': url,
    'method': 'POST',
    'imageCount': imageCount,
    'imageBytes': imageBytes,
    'durationMs': durationMs,
    'requestId': requestId,
  })!;

  static Map<String, dynamic> response({
    required int? statusCode,
    required String? finishReason,
    required int? durationMs,
    required String? requestId,
    required String? errorType,
  }) => sanitizeResponse({
    'statusCode': statusCode,
    'finishReason': finishReason,
    'durationMs': durationMs,
    'requestId': requestId,
    'errorType': errorType,
  })!;

  static String? requestIdFromHeaders(dynamic rawHeaders) {
    if (rawHeaders is! Map) return null;
    for (final entry in rawHeaders.entries) {
      if (entry.key is! String ||
          !_requestIdHeaders.contains((entry.key as String).toLowerCase())) {
        continue;
      }
      final value = entry.value is List
          ? (entry.value as List).firstOrNull
          : entry.value;
      final safe = _safeRequestId(value);
      if (safe != null) return safe;
    }
    return null;
  }

  static String? requestIdFromData(dynamic data) {
    if (data is! Map) return null;
    return _safeRequestId(
      data['request_id'] ?? data['requestId'] ?? data['id'],
    );
  }

  /// Avoid storing provider-controlled exception text that can echo secrets.
  static String safeTaskError(Object error) {
    if (error is DioException) {
      return 'OCR 请求失败（${error.type.name}）';
    }
    if (error is FormatException) return 'OCR 返回格式无效';
    if (error is FileSystemException) return 'OCR 结果保存失败';
    final type = error.runtimeType.toString();
    return 'OCR 处理失败（${type.substring(0, type.length.clamp(0, 64).toInt())}）';
  }

  static Map<String, dynamic> _bounded(Map<String, dynamic> value) {
    if (utf8.encode(jsonEncode(value)).length <= maxSerializedBytes) {
      return value;
    }
    // All persisted fields are allowlisted and capped; this is a final guard
    // against future additions accidentally making diagnostics unbounded.
    return {
      if (value['statusCode'] is int) 'statusCode': value['statusCode'],
      if (value['requestId'] is String)
        'requestId': (value['requestId'] as String).substring(
          0,
          (value['requestId'] as String).length.clamp(0, 64).toInt(),
        ),
      if (value['durationMs'] is int) 'durationMs': value['durationMs'],
    };
  }

  static String? _safeHost(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    final host = uri?.host.isNotEmpty == true
        ? uri!.host
        : RegExp(r'^[A-Za-z0-9.-]+(?::[0-9]{1,5})?$').hasMatch(value)
        ? value
        : null;
    if (host == null) return null;
    return host.length <= _maxTextLength
        ? host
        : host.substring(0, _maxTextLength);
  }

  static String? _safeMethod(dynamic value) {
    if (value is! String) return null;
    final method = value.toUpperCase();
    return const {'GET', 'POST', 'PUT', 'PATCH', 'DELETE'}.contains(method)
        ? method
        : null;
  }

  static int? _smallInt(dynamic value) =>
      value is int && value >= 0 ? value.clamp(0, 1 << 50).toInt() : null;

  static String? _safeRequestId(dynamic value) {
    if (value is! String) return null;
    final cleaned = value.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    if (cleaned.isEmpty || cleaned.length > _maxTextLength) return null;
    if (RegExp(
      r'^(?:bearer\s|sk-[a-z0-9]|gh[pousr]_)',
      caseSensitive: false,
    ).hasMatch(cleaned)) {
      return null;
    }
    return cleaned;
  }

  static String? _safeReason(dynamic value) {
    if (value is! String || value.length > 48) return null;
    final reason = value.trim();
    return reason.isNotEmpty && RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(reason)
        ? reason
        : null;
  }

  static String? _safeErrorType(dynamic value) {
    if (value is! String || value.length > 48) return null;
    final type = value.trim();
    return type.isNotEmpty && RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(type)
        ? type
        : null;
  }

  static String? _finishReasonFromData(dynamic data) {
    if (data is! Map || data['choices'] is! List) return null;
    final choices = data['choices'] as List;
    if (choices.isEmpty || choices.first is! Map) return null;
    return _safeReason((choices.first as Map)['finish_reason']);
  }
}
