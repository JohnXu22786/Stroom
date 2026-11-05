import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';

const String kAutoContinuationMessage = 'Continue if not finished.';

/// Retry policy for streaming HTTP 429 rate limits.
///
/// Four retries follow the initial request. The backoff starts at 500 ms,
/// doubles for each retry, and is capped at five seconds. Jitter spreads
/// concurrent clients across the upper half of each interval.
class RateLimitRetryPolicy {
  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final bool jitter;

  const RateLimitRetryPolicy({
    this.maxRetries = 4,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 5),
    this.jitter = true,
  });

  Duration delayForRetry(int retryNumber, {double? randomValue}) {
    final multiplier = math.pow(2, retryNumber - 1).toInt();
    final rawMs = initialDelay.inMilliseconds * multiplier;
    final cappedMs = math.min(rawMs, maxDelay.inMilliseconds).toInt();
    if (!jitter) return Duration(milliseconds: cappedMs);
    final fraction = (randomValue ?? math.Random().nextDouble()).clamp(0.5, 1.0);
    return Duration(milliseconds: (cappedMs * fraction).round());
  }
}

/// Retries a failed stream only when its HTTP response is 429 and no event
/// has been emitted. This avoids replaying partial output or duplicating work.
Stream<T> retryRateLimitedStream<T>(
  Stream<T> Function() createStream, {
  RateLimitRetryPolicy policy = const RateLimitRetryPolicy(),
  Future<void> Function(Duration duration)? delay,
}) async* {
  var retries = 0;
  while (true) {
    var emittedEvent = false;
    try {
      await for (final event in createStream()) {
        emittedEvent = true;
        yield event;
      }
      return;
    } catch (error) {
      if (emittedEvent || retries >= policy.maxRetries || !_isRateLimit(error)) {
        rethrow;
      }
      retries++;
      final wait = _retryAfter(error) ?? policy.delayForRetry(retries);
      await (delay?.call(wait) ?? Future<void>.delayed(wait));
    }
  }
}

bool _isRateLimit(Object error) =>
    error is DioException && error.response?.statusCode == 429;

Duration? _retryAfter(Object error) {
  if (error is! DioException) return null;
  final value = error.response?.headers.value('retry-after');
  if (value == null) return null;
  final seconds = double.tryParse(value.trim());
  if (seconds != null && seconds >= 0 && seconds.isFinite) {
    return Duration(milliseconds: (seconds * 1000).round());
  }
  final date = _parseRetryAfterDate(value);
  if (date == null) return null;
  final remaining = date.difference(DateTime.now());
  if (remaining.isNegative) return Duration.zero;
  return remaining;
}

DateTime? _parseRetryAfterDate(String value) {
  final normalized = value.trim();
  final httpDate = RegExp(
    r'^(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun), (\d{2}) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (httpDate != null) {
    return _validatedUtcDate(
      monthName: httpDate.group(2)!,
      day: int.parse(httpDate.group(1)!),
      year: int.parse(httpDate.group(3)!),
      hour: int.parse(httpDate.group(4)!),
      minute: int.parse(httpDate.group(5)!),
      second: int.parse(httpDate.group(6)!),
    );
  }

  final obsoleteDate = RegExp(
    r'^(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday), (\d{2})-(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)-(\d{2}) (\d{2}):(\d{2}):(\d{2}) GMT$',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (obsoleteDate != null) {
    final shortYear = int.parse(obsoleteDate.group(3)!);
    var year = 2000 + shortYear;
    if (year > DateTime.now().year + 50) year -= 100;
    return _validatedUtcDate(
      monthName: obsoleteDate.group(2)!,
      day: int.parse(obsoleteDate.group(1)!),
      year: year,
      hour: int.parse(obsoleteDate.group(4)!),
      minute: int.parse(obsoleteDate.group(5)!),
      second: int.parse(obsoleteDate.group(6)!),
    );
  }

  final asctimeDate = RegExp(
    r'^(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) {1,2}(\d{1,2}) (\d{2}):(\d{2}):(\d{2}) (\d{4})$',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (asctimeDate != null) {
    return _validatedUtcDate(
      monthName: asctimeDate.group(1)!,
      day: int.parse(asctimeDate.group(2)!),
      year: int.parse(asctimeDate.group(6)!),
      hour: int.parse(asctimeDate.group(3)!),
      minute: int.parse(asctimeDate.group(4)!),
      second: int.parse(asctimeDate.group(5)!),
    );
  }
  return DateTime.tryParse(normalized);
}

DateTime? _validatedUtcDate({
  required String monthName,
  required int day,
  required int year,
  required int hour,
  required int minute,
  required int second,
}) {
  const months = [
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ];
  final month = months.indexOf(monthName.toLowerCase()) + 1;
  if (month == 0) return null;
  final parsed = DateTime.utc(year, month, day, hour, minute, second);
  if (parsed.year != year ||
      parsed.month != month ||
      parsed.day != day ||
      hour >= 24 ||
      minute >= 60 ||
      second >= 60) {
    return null;
  }
  return parsed;
}

/// Whether an incomplete visible response can be continued after a transport
/// failure. HTTP request and server errors are deliberately excluded.
bool shouldAutoContinueStream({
  required Object? error,
  required bool hasPartialOutput,
}) {
  if (!hasPartialOutput || error == null) return false;
  if (error is DioException) {
    if (error.response?.statusCode != null) return false;
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      DioExceptionType.unknown => _isNetworkTransportCause(error.error),
      _ => false,
    };
  }
  return _isNetworkTransportCause(error);
}

bool _isNetworkTransportCause(Object? error) {
  if (error is TimeoutException) return true;
  final type = error?.runtimeType.toString();
  if (type == 'SocketException') return true;
  return type == 'HttpException' &&
      error.toString().toLowerCase().contains('connection closed');
}
