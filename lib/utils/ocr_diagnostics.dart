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
  static const _knownFinishReasons = {
    'stop',
    'length',
    'content_filter',
    'function_call',
    'tool_calls',
  };
  static const _knownSafeStoredTaskErrorSummaries = {
    'OCR 图片格式无法识别',
    'OCR 任务因格式问题未完成',
    'API 返回格式异常（非 JSON 对象）',
    'API 返回了空的 choices 列表',
    'API 返回中的 choice 格式异常',
    'API 返回中的 finish_reason 格式异常',
    'API 返回中缺少 message 字段',
    'OCR 处理失败（_Exception）',
    'OCR 处理失败（ArgumentError）',
    'OCR 处理失败（RangeError）',
    'OCR 处理失败（StateError）',
    'OCR 处理失败（TypeError）',
    'OCR 处理失败（TimeoutException）',
    'OCR 处理失败（UnsupportedError）',
    'OCR 返回格式无效',
    'OCR 结果保存失败',
    'OCR 部分页面未完成',
    'OCR 返回了格式异常的 content block',
    'OCR 返回了不支持的非文本 content block',
    'OCR 返回了格式异常的 text block',
    'OCR 返回了未知格式的内容',
    'OCR 未识别到文字内容',
    'OCR 未识别到文字内容（content 列表为空）',
    'OCR 返回了异常内容（仅包含 JSON 括号），请检查 API 返回格式或更换模型',
  };
  static const _storedTaskErrorWrappers = [
    'OCR识别失败: ',
    'OCR结果保存失败: ',
    'OCR结果不完整: ',
    'Exception: ',
  ];
  static final _credentialAssignment = RegExp(
    r'''(?:api[\s_-]*key|private[_-]?key|client[_-]?secret|secret[_-]?key|(?:^|[^a-z0-9])key|token|access[_-]?token|refresh[_-]?token|authorization|bearer|password|secret)["']?\s*[:=]''',
    caseSensitive: false,
  );
  static final _credentialValue = RegExp(
    r'(?:Bearer\s+\S+|sk-(?:proj-|ant-api\d{2}-|or-v1-)?[a-z0-9]{8,}|gsk_[a-z0-9]{8,}|gh[pousr]_[a-z0-9]{8,}|AIza[a-z0-9_-]{20,})',
    caseSensitive: false,
  );
  static final _credentialQueryParameter = RegExp(
    r'(?:(?:api|access|private|secret|subscription|client)[_-]?key|(?:^|[-_.])key(?:$|[-_.])|(?:^|[-_.])(?:access|refresh|id)?[_-]?token(?:$|[-_.])|(?:^|[-_.])auth(?:orization)?(?:$|[-_.])|(?:^|[-_.])(?:client[_-]?)?secret(?:$|[-_.])|(?:^|[-_.])(?:pass(?:word|phrase)?|passwd|credentials?|cookie|signature|sig|jwt)(?:$|[-_.]))',
    caseSensitive: false,
  );

  static List<String> credentialValuesFromUrl(dynamic rawUrl) {
    if (rawUrl is! String || rawUrl.isEmpty) return const [];
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return const [];

    final values = <String>{};
    void addValue(String rawValue) {
      final value = rawValue.trim();
      if (value.isEmpty || value.length > 512) return;
      values.add(value);
      final token = RegExp(
        r'^(?:Bearer|Basic)\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(value)?.group(1)?.trim();
      if (token != null && token.isNotEmpty && token.length <= 512) {
        values.add(token);
      }
    }

    if (uri.userInfo.isNotEmpty) {
      for (final component in uri.userInfo.split(':')) {
        try {
          addValue(Uri.decodeComponent(component));
        } on FormatException {
          addValue(component);
        }
      }
    }
    try {
      for (final entry in uri.queryParametersAll.entries) {
        if (!_credentialQueryParameter.hasMatch(entry.key)) continue;
        for (final value in entry.value) {
          addValue(value);
        }
      }
    } on FormatException {
      // Keep any values recovered from userinfo when a malformed query cannot
      // be decoded safely.
    }
    return values.toList(growable: false);
  }

  static List<String> credentialValuesFromRequest(
    Map<String, dynamic>? rawRequest,
  ) {
    if (rawRequest == null) return const [];
    return <String>{
      ...credentialValuesFromHeaders(rawRequest['headers']),
      ...credentialValuesFromUrl(rawRequest['url']),
      ...credentialValuesFromUrl(rawRequest['host']),
    }.toList(growable: false);
  }

  static List<String> credentialValuesFromHeaders(dynamic rawHeaders) {
    if (rawHeaders is! Map) return const [];
    final credentialHeader = RegExp(
      r'(?:authorization|auth.?token|(?:^|[-_.])token|api.?key|access.?token|refresh.?token|(?:private|secret).?key|client.?secret|password|cookie)',
      caseSensitive: false,
    );
    final values = <String>{};
    for (final entry in rawHeaders.entries) {
      if (entry.key is! String ||
          !credentialHeader.hasMatch(entry.key as String)) {
        continue;
      }
      final rawValues =
          entry.value is List ? entry.value as List : [entry.value];
      for (final rawValue in rawValues) {
        if (rawValue is! String) continue;
        final value = rawValue.trim();
        if (value.isEmpty) continue;
        values.add(value);
        final token = RegExp(
          r'^(?:Bearer|Basic)\s+(.+)$',
          caseSensitive: false,
        ).firstMatch(value)?.group(1)?.trim();
        if (token != null && token.isNotEmpty) values.add(token);
      }
    }
    return values.toList(growable: false);
  }

  static Map<String, dynamic>? sanitizeRequest(
    Map<String, dynamic>? source, {
    Iterable<String> excludedValues = const [],
    bool includeRequestId = true,
  }) {
    if (source == null) return null;
    final safeExcludedValues = <String>{
      ...excludedValues,
      ...credentialValuesFromRequest(source),
    }.toList();
    final safeRequestId = includeRequestId
        ? _safeRequestId(
              source['requestId'],
              excludedValues: safeExcludedValues,
            ) ??
            _safeRequestId(
              requestIdFromHeaders(
                source['headers'],
                excludedValues: safeExcludedValues,
              ),
              excludedValues: safeExcludedValues,
            )
        : null;
    final result = <String, dynamic>{
      if (_safeHost(
        source['host'] ?? source['url'],
        excludedValues: safeExcludedValues,
      )
          case final host?)
        'host': host,
      if (_safeMethod(source['method'], excludedValues: safeExcludedValues)
          case final method?)
        'method': method,
      if (_smallInt(source['imageCount'], excludedValues: safeExcludedValues)
          case final count?)
        'imageCount': count,
      if (_smallInt(source['imageBytes'], excludedValues: safeExcludedValues)
          case final bytes?)
        'imageBytes': bytes,
      if (safeRequestId != null) 'requestId': safeRequestId,
      if (_smallInt(source['durationMs'], excludedValues: safeExcludedValues)
          case final duration?)
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
        ? _safeRequestId(source['requestId'], excludedValues: excludedValues) ??
            _safeRequestId(
              requestIdFromHeaders(
                source['headers'],
                excludedValues: excludedValues,
              ),
              excludedValues: excludedValues,
            ) ??
            _safeRequestId(
              requestIdFromData(data, excludedValues: excludedValues),
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
      if (_smallInt(source['statusCode'], excludedValues: excludedValues) ??
              _smallInt(source['status'], excludedValues: excludedValues)
          case final status?)
        'statusCode': status,
      if (safeFinishReason != null) 'finishReason': safeFinishReason,
      if (safeRequestId != null) 'requestId': safeRequestId,
      if (_smallInt(source['durationMs'], excludedValues: excludedValues)
          case final duration?)
        'durationMs': duration,
      if (_safeErrorType(source['errorType'], excludedValues: excludedValues)
          case final errorType?)
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
  }) =>
      sanitizeRequest({
        'url': url,
        'method': 'POST',
        'imageCount': imageCount,
        'imageBytes': imageBytes,
        'durationMs': durationMs,
        'requestId': requestId,
      }, excludedValues: excludedValues)!;

  static Map<String, dynamic> response({
    required int? statusCode,
    required String? finishReason,
    required int? durationMs,
    required String? requestId,
    required String? errorType,
    Map<String, dynamic>? data,
    Iterable<String> excludedValues = const [],
  }) =>
      sanitizeResponse({
        'statusCode': statusCode,
        'finishReason': finishReason,
        'durationMs': durationMs,
        'requestId': requestId,
        'errorType': errorType,
        'data': data,
      }, excludedValues: excludedValues)!;

  static String? requestIdFromHeaders(
    dynamic rawHeaders, {
    Iterable<String> excludedValues = const [],
  }) {
    if (rawHeaders is! Map) return null;
    for (final entry in rawHeaders.entries) {
      if (entry.key is! String ||
          !_requestIdHeaders.contains((entry.key as String).toLowerCase())) {
        continue;
      }
      final values = entry.value is List ? entry.value as List : [entry.value];
      for (final value in values) {
        final safe = _safeRequestId(value, excludedValues: excludedValues);
        if (safe != null) return safe;
      }
    }
    return null;
  }

  static String? requestIdFromData(
    dynamic data, {
    Iterable<String> excludedValues = const [],
  }) {
    if (data is! Map) return null;
    for (final field in ['request_id', 'requestId', 'id']) {
      final safe = _safeRequestId(data[field], excludedValues: excludedValues);
      if (safe != null) return safe;
    }
    return null;
  }

  /// Avoid storing provider-controlled exception text that can echo secrets.
  static String safeTaskError(
    Object error, {
    Iterable<String> excludedValues = const [],
  }) {
    late final String message;
    if (error is DioException) {
      message = 'OCR 请求失败（${error.type.name}）';
    } else if (error is FormatException) {
      message = 'OCR 返回格式无效';
    } else if (error is FileSystemException) {
      message = 'OCR 结果保存失败';
    } else {
      final type = error.runtimeType.toString();
      message =
          'OCR 处理失败（${type.substring(0, type.length.clamp(0, 64).toInt())}）';
    }
    if (containsCredential(message, excludedValues: excludedValues)) {
      return _hiddenTaskError(excludedValues: excludedValues);
    }
    return message;
  }

  static String _hiddenTaskError({
    Iterable<String> excludedValues = const [],
    Iterable<String> details = const [],
  }) {
    final exclusions = excludedValues.toList(growable: false);
    final detailsText = details.join('，');
    const fallbacks = ['OCR 错误详情已隐藏', '错误详情已隐藏', '请求失败', '请重试'];
    for (final fallback in fallbacks) {
      final candidate =
          detailsText.isEmpty ? fallback : '$fallback（$detailsText）';
      if (!containsCredential(candidate, excludedValues: exclusions)) {
        return candidate;
      }
    }
    if (detailsText.isNotEmpty &&
        !containsCredential(detailsText, excludedValues: exclusions)) {
      return detailsText;
    }
    return '';
  }

  /// Keep known OCR diagnostic summaries while hiding unclassified legacy
  /// error text that could contain provider response data.
  static String? sanitizeStoredTaskError(
    String? value, {
    Iterable<String> excludedValues = const [],
  }) {
    if (value == null || value.isEmpty) return value;
    final credentialValues = excludedValues.toList(growable: false);
    if (value.length <= _maxTextLength) {
      var safeDioCandidate = value;
      while (true) {
        String? wrapper;
        for (final prefix in _storedTaskErrorWrappers) {
          if (safeDioCandidate.startsWith(prefix)) {
            wrapper = prefix;
            break;
          }
        }
        if (wrapper == null) break;
        safeDioCandidate = safeDioCandidate.substring(wrapper.length);
      }
      final safeDioType = RegExp(
        r'^OCR 请求失败（([a-zA-Z]+)）$',
      ).firstMatch(safeDioCandidate)?.group(1);
      if (DioExceptionType.values.any((type) => type.name == safeDioType) &&
          !containsCredential(value, excludedValues: credentialValues)) {
        return value;
      }
    }
    final containsProviderBody = RegExp(
          r'(?:DioException|(?:Exception:\s*)?(?:请求失败|OCR\s*请求被模型拒绝)|请求失败\s*[（(]|data:image/|base64,)',
          caseSensitive: false,
        ).hasMatch(value) ||
        _isShortEncodedImageBody(value);
    final containsCredentialValue = containsCredential(
      value,
      excludedValues: credentialValues,
    );
    if (value.length <= _maxTextLength &&
        !containsProviderBody &&
        !containsCredentialValue &&
        _isKnownSafeStoredTaskErrorSummary(
          value,
          excludedValues: credentialValues,
        )) {
      return value;
    }

    final statusCode = RegExp(
      r'\bHTTP\s+([1-5]\d{2})\b',
      caseSensitive: false,
    ).firstMatch(value)?.group(1);
    final details = <String>[
      if (statusCode != null &&
          !containsCredential(statusCode, excludedValues: credentialValues))
        'HTTP $statusCode',
      if (_safeReason(
        RegExp(
          r'finish[_ ]reason\s*=\s*([a-zA-Z0-9_-]{1,48})',
          caseSensitive: false,
        ).firstMatch(value)?.group(1),
        excludedValues: credentialValues,
      )
          case final finishReason?)
        'finish_reason=$finishReason',
    ];
    return _hiddenTaskError(excludedValues: credentialValues, details: details);
  }

  static bool _isKnownSafeStoredTaskErrorSummary(
    String value, {
    Iterable<String> excludedValues = const [],
  }) {
    if (containsCredential(value, excludedValues: excludedValues)) return false;

    var candidate = value;
    while (candidate.isNotEmpty) {
      if (_knownSafeStoredTaskErrorSummaries.contains(candidate) ||
          RegExp(
            r'^HTTP\s+[1-5]\d{2}$',
            caseSensitive: false,
          ).hasMatch(candidate) ||
          RegExp(
            r'^OCR 请求的 JSON 大小为 \d+ 字节，超过 \d+ 字节上限$',
          ).hasMatch(candidate) ||
          RegExp(
            r'^部分图片 OCR 未完成：第 \d+ 张图片(?:识别失败|结果不完整)(?:；第 \d+ 张图片(?:识别失败|结果不完整))*$',
          ).hasMatch(candidate)) {
        return true;
      }

      final incompleteResult = RegExp(
        r'^OCR 返回了不完整结果（finish_reason=([A-Za-z0-9_-]{1,48})）$',
      ).firstMatch(candidate);
      final finishReason = incompleteResult?.group(1);
      if (finishReason == 'unknown' ||
          (finishReason != null &&
              _safeReason(finishReason, excludedValues: excludedValues) ==
                  finishReason)) {
        return true;
      }

      if (_isSafeHiddenTaskErrorSummary(
        candidate,
        excludedValues: excludedValues,
      )) {
        return true;
      }

      String? wrapper;
      for (final prefix in _storedTaskErrorWrappers) {
        if (candidate.startsWith(prefix)) {
          wrapper = prefix;
          break;
        }
      }
      if (wrapper == null) return false;
      candidate = candidate.substring(wrapper.length);
    }
    return false;
  }

  static bool _isSafeHiddenTaskErrorSummary(
    String value, {
    Iterable<String> excludedValues = const [],
  }) {
    const prefixes = ['OCR 错误详情已隐藏', '错误详情已隐藏', '请求失败', '请重试'];
    for (final prefix in prefixes) {
      if (value == prefix) return true;
      if (!value.startsWith('$prefix（') || !value.endsWith('）')) continue;

      final details = value.substring(prefix.length + 1, value.length - 1);
      final parts = details.split('，');
      if (parts.isEmpty || parts.length > 2) return false;
      return parts.every((part) {
        if (RegExp(
          r'^HTTP\s+[1-5]\d{2}$',
          caseSensitive: false,
        ).hasMatch(part)) {
          return true;
        }
        final finishReason = RegExp(
          r'^finish_reason=([A-Za-z0-9_-]{1,48})$',
        ).firstMatch(part)?.group(1);
        return finishReason != null &&
            _safeReason(finishReason, excludedValues: excludedValues) ==
                finishReason;
      });
    }
    return false;
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

  /// Recognize short, bare base64 image bodies in legacy task errors without
  /// treating arbitrary base64-looking user text as an image payload.
  static bool _isShortEncodedImageBody(String value) {
    if (value.length > _maxTextLength) return false;
    final compacted = value.replaceAll(RegExp(r'\s+'), '');
    final candidates = RegExp(r'[A-Za-z0-9+/=]{8,}').allMatches(compacted);
    return candidates.any((match) => _matchesEncodedImageBody(match.group(0)!));
  }

  static bool _matchesEncodedImageBody(String value) {
    if (!RegExp(r'^[A-Za-z0-9+/]+={0,2}$').hasMatch(value)) return false;
    final unpadded = value.replaceFirst(RegExp(r'=+$'), '');
    if (unpadded.length % 4 == 1 ||
        (value.contains('=') && value.length % 4 != 0)) {
      return false;
    }
    final padded = unpadded.padRight(
      unpadded.length + ((4 - unpadded.length % 4) % 4),
      '=',
    );
    try {
      final bytes = base64Decode(padded);
      if (base64Encode(bytes).replaceFirst(RegExp(r'=+$'), '') != unpadded) {
        return false;
      }
      bool matches(List<int> signature, {int offset = 0}) =>
          bytes.length >= offset + signature.length &&
          List.generate(
            signature.length,
            (index) => index,
          ).every((index) => bytes[offset + index] == signature[index]);

      return matches([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]) ||
          matches([0xff, 0xd8, 0xff]) ||
          matches([0x47, 0x49, 0x46, 0x38, 0x37, 0x61]) ||
          matches([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]) ||
          (matches([0x52, 0x49, 0x46, 0x46]) &&
              matches([0x57, 0x45, 0x42, 0x50], offset: 8)) ||
          matches([0x42, 0x4d]) ||
          matches([0x49, 0x49, 0x2a, 0x00]) ||
          matches([0x4d, 0x4d, 0x00, 0x2a]) ||
          matches([0x00, 0x00, 0x01, 0x00]) ||
          (matches([0x66, 0x74, 0x79, 0x70], offset: 4) &&
              [
                [0x68, 0x65, 0x69, 0x63],
                [0x68, 0x65, 0x69, 0x78],
                [0x68, 0x65, 0x76, 0x63],
                [0x68, 0x65, 0x76, 0x78],
                [0x6d, 0x69, 0x66, 0x31],
                [0x6d, 0x73, 0x66, 0x31],
                [0x61, 0x76, 0x69, 0x66],
                [0x61, 0x76, 0x69, 0x73],
              ].any((brand) => matches(brand, offset: 8)));
    } on FormatException {
      return false;
    }
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

  static String? _safeMethod(
    dynamic value, {
    Iterable<String> excludedValues = const [],
  }) {
    if (value is! String) return null;
    final method = value.toUpperCase();
    return const {'GET', 'POST', 'PUT', 'PATCH', 'DELETE'}.contains(method) &&
            !containsCredential(method, excludedValues: excludedValues)
        ? method
        : null;
  }

  static int? _smallInt(
    dynamic value, {
    Iterable<String> excludedValues = const [],
  }) =>
      value is int &&
              value >= 0 &&
              !containsCredential(value.toString(),
                  excludedValues: excludedValues)
          ? value.clamp(0, 1 << 50).toInt()
          : null;

  static String? _safeRequestId(
    dynamic value, {
    Iterable<String> excludedValues = const [],
  }) {
    if (value is! String) return null;
    final cleaned = value.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.:/-]{0,159}$').hasMatch(cleaned)) {
      return null;
    }
    if (RegExp(r'data:image/', caseSensitive: false).hasMatch(cleaned) ||
        _isShortEncodedImageBody(cleaned) ||
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
    return _knownFinishReasons.contains(reason) &&
            !containsCredential(reason, excludedValues: excludedValues)
        ? reason
        : null;
  }

  static bool _containsExcludedValue(
    String value,
    Iterable<String> excludedValues,
  ) {
    final normalized = value.toLowerCase();
    return excludedValues.any((secret) {
      if (secret.isEmpty) return false;
      final normalizedSecret = secret.toLowerCase();
      if (normalized.contains(normalizedSecret)) return true;

      // Legacy OCR snapshots store API keys as `prefix...suffix` or
      // `prefix...` in the Authorization header. A different diagnostic field
      // can still contain the full key, so exclude the visible masked part.
      // Keys up to four characters use a one-character `a***` mask. Match
      // only a complete possible key token to avoid dropping longer safe IDs.
      final tinyMask = RegExp(r'^(.{1,3})\*{3}$').firstMatch(normalizedSecret);
      if (tinyMask != null) {
        final prefix = tinyMask.group(1)!;
        final maxSuffixLength = 4 - prefix.length;
        final possibleShortKey = RegExp(
          '(?:^|[^a-z0-9])${RegExp.escape(prefix)}\\S{0,$maxSuffixLength}(?:\$|[^a-z0-9])',
        );
        if (possibleShortKey.hasMatch(normalized)) return true;
      }
      // Keys up to 16 characters use the legacy `first4****` form instead.
      final shortMask = RegExp(r'^(.{4})\*{4}$').firstMatch(normalizedSecret);
      if (shortMask != null) {
        final prefix = shortMask.group(1)!;
        if (RegExp('${RegExp.escape(prefix)}\\S{1,12}').hasMatch(normalized)) {
          return true;
        }
      }
      final maskIndex = normalizedSecret.indexOf('...');
      if (maskIndex < 8) return false;
      final prefix = normalizedSecret.substring(0, maskIndex);
      final suffix = normalizedSecret.substring(maskIndex + 3);
      final prefixIndex = normalized.indexOf(prefix);
      if (prefixIndex < 0) return false;
      if (suffix.isEmpty) {
        return RegExp(
          '${RegExp.escape(prefix)}\\S{1,128}',
        ).hasMatch(normalized.substring(prefixIndex));
      }
      if (suffix.length < 4) return false;
      return normalized.indexOf(suffix, prefixIndex + prefix.length) >
          prefixIndex + prefix.length;
    });
  }

  static String? _safeErrorType(
    dynamic value, {
    Iterable<String> excludedValues = const [],
  }) {
    if (value is! String || value.length > 48) return null;
    final type = value.trim();
    return type.isNotEmpty &&
            RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(type) &&
            !_isShortEncodedImageBody(type) &&
            !containsCredential(type, excludedValues: excludedValues)
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
