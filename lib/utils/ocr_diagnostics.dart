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
  static final _credentialAssignment = RegExp(
    r'''(?:api[\s_-]*key|private[_-]?key|client[_-]?secret|secret[_-]?key|(?:^|[^a-z0-9])key|token|access[_-]?token|refresh[_-]?token|authorization|bearer|password|secret)["']?\s*[:=]''',
    caseSensitive: false,
  );
  static final _credentialValue = RegExp(
    r'(?:Bearer\s+\S+|sk-(?:proj-|ant-api\d{2}-|or-v1-)?[a-z0-9]{8,}|gsk_[a-z0-9]{8,}|gh[pousr]_[a-z0-9]{8,}|AIza[a-z0-9_-]{20,})',
    caseSensitive: false,
  );

  static Map<String, dynamic>? sanitizeRequest(
    Map<String, dynamic>? source, {
    Iterable<String> excludedValues = const [],
    bool includeRequestId = true,
  }) {
    if (source == null) return null;
    final safeRequestId = includeRequestId
        ? _safeRequestId(
              source['requestId'],
              excludedValues: excludedValues,
            ) ??
            _safeRequestId(
              requestIdFromHeaders(source['headers']),
              excludedValues: excludedValues,
            )
        : null;
    final result = <String, dynamic>{
      if (_safeHost(
            source['host'] ?? source['url'],
            excludedValues: excludedValues,
          )
          case final host?)
        'host': host,
      if (_safeMethod(source['method']) case final method?) 'method': method,
      if (_smallInt(source['imageCount']) case final count?)
        'imageCount': count,
      if (_smallInt(source['imageBytes']) case final bytes?)
        'imageBytes': bytes,
      if (safeRequestId != null) 'requestId': safeRequestId,
      if (_smallInt(source['durationMs']) case final duration?)
        'durationMs': duration,
    };
    return _bounded(result);
  }

  static Map<String, dynamic>? sanitizeResponse(
    Map<String, dynamic>? source, {
    Iterable<String> excludedValues = const [],
    bool includeRequestId = true,
    bool includeFinishReason = true,
  }) {
    if (source == null) return null;
    final data = source['data'];
    final safeRequestId = includeRequestId
        ? _safeRequestId(
              source['requestId'],
              excludedValues: excludedValues,
            ) ??
            _safeRequestId(
              requestIdFromHeaders(source['headers']),
              excludedValues: excludedValues,
            ) ??
            _safeRequestId(
              requestIdFromData(data),
              excludedValues: excludedValues,
            )
        : null;
    final safeFinishReason = includeFinishReason
        ? _safeReason(
                source['finishReason'] ?? source['finish_reason'],
                excludedValues: excludedValues,
              ) ??
              _finishReasonFromData(data, excludedValues: excludedValues)
        : null;
    final result = <String, dynamic>{
      if (_smallInt(source['statusCode']) ?? _smallInt(source['status'])
          case final status?)
        'statusCode': status,
      if (safeFinishReason != null) 'finishReason': safeFinishReason,
      if (safeRequestId != null) 'requestId': safeRequestId,
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
    Iterable<String> excludedValues = const [],
  }) => sanitizeRequest(
    {
      'url': url,
      'method': 'POST',
      'imageCount': imageCount,
      'imageBytes': imageBytes,
      'durationMs': durationMs,
      'requestId': requestId,
    },
    excludedValues: excludedValues,
  )!;

  static Map<String, dynamic> response({
    required int? statusCode,
    required String? finishReason,
    required int? durationMs,
    required String? requestId,
    required String? errorType,
    Map<String, dynamic>? data,
    Iterable<String> excludedValues = const [],
  }) => sanitizeResponse(
    {
      'statusCode': statusCode,
      'finishReason': finishReason,
      'durationMs': durationMs,
      'requestId': requestId,
      'errorType': errorType,
      'data': data,
    },
    excludedValues: excludedValues,
  )!;

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

  /// Drop legacy OCR exception text that could contain a provider response
  /// body, credentials, or image data while keeping safe task messages bounded.
  static String? sanitizeStoredTaskError(
    String? value, {
    Iterable<String> excludedValues = const [],
  }) {
    if (value == null || value.isEmpty) return value;
    final safeDioType = RegExp(
      r'^OCR 请求失败（([a-zA-Z]+)）$',
    ).firstMatch(value)?.group(1);
    if (DioExceptionType.values.any((type) => type.name == safeDioType)) {
      return value;
    }
    final containsProviderBody = RegExp(
      r'(?:DioException|Exception:\s*请求失败|请求失败\s*[（(]|data:image/|base64,)',
      caseSensitive: false,
    ).hasMatch(value);
    final containsCredentialValue = containsCredential(
      value,
      excludedValues: excludedValues,
    );
    if (value.length <= _maxTextLength &&
        !containsProviderBody &&
        !containsCredentialValue) {
      return value;
    }

    final details = <String>[
      if (RegExp(r'\bHTTP\s+([1-5]\d{2})\b', caseSensitive: false)
              .firstMatch(value)
          case final status?)
        'HTTP ${status.group(1)}',
      if (_safeReason(
            RegExp(
              r'finish[_ ]reason\s*=\s*([a-zA-Z0-9_-]{1,48})',
              caseSensitive: false,
            ).firstMatch(value)?.group(1),
          )
          case final finishReason?)
        'finish_reason=$finishReason',
    ];
    return details.isEmpty
        ? 'OCR 错误详情已隐藏'
        : 'OCR 错误详情已隐藏（${details.join('，')}）';
  }

  /// Whether text contains a credential-shaped value or a supplied secret.
  static bool containsCredential(
    String value, {
    Iterable<String> excludedValues = const [],
  }) {
    final compacted = value.replaceAll(RegExp(r'\s+'), '');
    final excluded = excludedValues.where((value) => value.isNotEmpty).toList();
    final compactedExcluded = excluded
        .map((value) => value.replaceAll(RegExp(r'\s+'), ''))
        .where((value) => value.isNotEmpty);
    return _credentialAssignment.hasMatch(value) ||
        _credentialValue.hasMatch(value) ||
        _credentialAssignment.hasMatch(compacted) ||
        _credentialValue.hasMatch(compacted) ||
        _containsExcludedValue(value, excluded) ||
        _containsExcludedValue(compacted, compactedExcluded);
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

  static String? _safeHost(
    dynamic value, {
    Iterable<String> excludedValues = const [],
  }) {
    if (value is! String || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    final host = uri?.host.isNotEmpty == true
        ? uri!.host
        : RegExp(r'^[A-Za-z0-9.-]+(?::[0-9]{1,5})?$').hasMatch(value)
        ? value
        : null;
    if (host == null) return null;
    if (_credentialValue.hasMatch(host) ||
        _containsExcludedValue(host, excludedValues)) {
      return null;
    }
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

  static String? _safeRequestId(
    dynamic value, {
    Iterable<String> excludedValues = const [],
  }) {
    if (value is! String) return null;
    final cleaned = value.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    if (cleaned.isEmpty || cleaned.length > _maxTextLength) return null;
    if (RegExp(r'data:image/', caseSensitive: false).hasMatch(cleaned) ||
        containsCredential(cleaned, excludedValues: excludedValues)) {
      return null;
    }
    return cleaned;
  }

  static String? _safeReason(
    dynamic value, {
    Iterable<String> excludedValues = const [],
  }) {
    if (value is! String || value.length > 48) return null;
    final reason = value.trim();
    return reason.isNotEmpty &&
            RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(reason) &&
            !containsCredential(reason, excludedValues: excludedValues)
        ? reason
        : null;
  }

  static bool _containsExcludedValue(
    String value,
    Iterable<String> excludedValues,
  ) {
    final normalized = value.toLowerCase();
    return excludedValues.any(
      (secret) =>
          secret.isNotEmpty && normalized.contains(secret.toLowerCase()),
    );
  }

  static String? _safeErrorType(dynamic value) {
    if (value is! String || value.length > 48) return null;
    final type = value.trim();
    return type.isNotEmpty && RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(type)
        ? type
        : null;
  }

  static String? _finishReasonFromData(
    dynamic data, {
    Iterable<String> excludedValues = const [],
  }) {
    if (data is! Map || data['choices'] is! List) return null;
    final choices = data['choices'] as List;
    if (choices.isEmpty || choices.first is! Map) return null;
    return _safeReason(
      (choices.first as Map)['finish_reason'],
      excludedValues: excludedValues,
    );
  }
}
