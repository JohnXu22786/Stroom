import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show MissingPluginException;

/// Retry helper with exponential backoff and configurable retryable-error
/// detection.
class RetryHelper {
  RetryHelper._();

  /// Retry a [fn] up to [maxRetries] times with exponential backoff.
  ///
  /// [retryableCheck] – returns `true` if [error] is retryable.
  ///   Defaults to [isRetryableError].
  /// Non-retryable errors are thrown immediately without further retries.
  static Future<T> retry<T>({
    required Future<T> Function() fn,
    int maxRetries = 3,
    Duration baseDelay = const Duration(seconds: 1),
    bool Function(Object error)? retryableCheck,
  }) async {
    retryableCheck ??= isRetryableError;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await fn();
      } catch (error) {
        if (attempt == maxRetries || !retryableCheck(error)) {
          rethrow;
        }
        // Exponential backoff: baseDelay * 2^attempt
        await Future.delayed(baseDelay * (1 << attempt));
      }
    }

    // Unreachable – satisfies the return type.
    throw StateError('Unreachable');
  }

  /// Returns `true` for commonly retryable errors:
  ///
  /// Retryable           | Non-retryable
  /// --------------------|--------------------------
  /// [SocketException]   | [ArgumentError]
  /// [HttpException] 5xx | [FormatException]
  /// [HttpException] 429 | [HttpException] 4xx
  /// [DioException] conn | [DioException] badResponse 4xx (non-429)
  ///   timeout / 5xx/429 | [DioException] cancel / badCertificate / unknown
  /// [MissingPluginException] |
  /// [TimeoutException]  |
  static bool isRetryableError(Object error) {
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;
    if (error is MissingPluginException) return true;

    if (error is DioException) {
      // Timeout & connection-level errors are usually transient
      if (error.type == DioExceptionType.connectionTimeout) return true;
      if (error.type == DioExceptionType.sendTimeout) return true;
      if (error.type == DioExceptionType.receiveTimeout) return true;
      if (error.type == DioExceptionType.connectionError) return true;
      // 5xx and 429 are retryable
      if (error.type == DioExceptionType.badResponse) {
        final code = error.response?.statusCode ?? 0;
        if (code >= 500 && code <= 599) return true;
        if (code == 429) return true;
      }
      return false;
    }

    if (error is ArgumentError) return false;
    if (error is FormatException) return false;

    if (error is HttpException) {
      return _isHttpStatusRetryable(error.message);
    }

    // Unknown error type – don't retry by default.
    return false;
  }

  /// Checks whether an HTTP status code extracted from the exception message
  /// indicates a retryable condition (5xx or 429).
  static bool _isHttpStatusRetryable(String message) {
    final match = RegExp(r'status[Cc]ode[:\s]*(\d{3})').firstMatch(message);
    if (match == null) return false;

    final code = int.parse(match.group(1)!);
    if (code >= 500 && code <= 599) return true;
    if (code == 429) return true;
    return false;
  }
}
