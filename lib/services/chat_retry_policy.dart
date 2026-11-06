import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';

const String kAutoContinuationMessage = 'Continue if not finished.';

/// Retry policy for actual HTTP 429 throttling responses.
///
/// Five retries follow the initial request. The delay schedule is based on
/// OpenCode CLI's 2/4/8/10/10 second backoff and adds approximately ±20%
/// jitter. The ten-second cap applies to the nominal schedule before jitter.
/// A valid Retry-After value is a minimum delay, bounded to fifteen minutes.
class RateLimitRetryPolicy {
  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final Duration maxRetryAfter;
  final bool jitter;

  const RateLimitRetryPolicy({
    this.maxRetries = 5,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(seconds: 10),
    this.maxRetryAfter = const Duration(minutes: 15),
    this.jitter = true,
  });

  Duration delayForRetry(int retryNumber, {double? randomValue}) {
    final multiplier = math.pow(2, retryNumber - 1).toInt();
    final rawMs = initialDelay.inMilliseconds * multiplier;
    final cappedMs = math.min(rawMs, maxDelay.inMilliseconds).toInt();
    if (!jitter) return Duration(milliseconds: cappedMs);
    final jitterMultiplier = _jitterMultiplier(randomValue);
    return Duration(milliseconds: (cappedMs * jitterMultiplier).round());
  }
}

/// Retry schedule for recognized network interruptions during chat streams.
class TransportRetryPolicy {
  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final bool jitter;

  const TransportRetryPolicy({
    this.maxRetries = 5,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(seconds: 30),
    this.jitter = true,
  });

  Duration delayForRetry(int retryNumber, {double? randomValue}) {
    final multiplier = math.pow(2, retryNumber - 1).toInt();
    final rawMs = initialDelay.inMilliseconds * multiplier;
    final cappedMs = math.min(rawMs, maxDelay.inMilliseconds).toInt();
    if (!jitter) return Duration(milliseconds: cappedMs);
    final jitteredMs = (cappedMs * _jitterMultiplier(randomValue)).round();
    return Duration(
        milliseconds: math.min(jitteredMs, maxDelay.inMilliseconds));
  }
}

double _jitterMultiplier(double? randomValue) {
  final value = (randomValue ?? math.Random().nextDouble()).clamp(0.0, 1.0);
  return 0.8 + value * 0.4;
}

/// Retries a failed stream only when its HTTP response is 429 and no event
/// has been emitted. This avoids replaying partial output or duplicating work.
Stream<T> retryRateLimitedStream<T>(
  Stream<T> Function() createStream, {
  RateLimitRetryPolicy policy = const RateLimitRetryPolicy(),
  Future<void> Function(Duration duration)? delay,
  Future<void>? cancellation,
  bool Function()? isCancelled,
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
      if (isCancelled?.call() == true ||
          emittedEvent ||
          retries >= policy.maxRetries ||
          !await _isRateLimit(error)) {
        rethrow;
      }
      retries++;
      final retryAfter = _retryAfter(error, maximum: policy.maxRetryAfter);
      final backoff = policy.delayForRetry(retries);
      final wait =
          retryAfter != null && retryAfter > backoff ? retryAfter : backoff;
      await waitForRetryOrCancellation(
        wait,
        delay: delay,
        cancellation: cancellation,
      );
      if (isCancelled?.call() == true) rethrow;
    }
  }
}

/// Waits for a retry delay, returning early when [cancellation] completes.
/// The default timer is cancelled when possible; injected delays are raced
/// against the cancellation signal for deterministic tests.
Future<void> waitForRetryOrCancellation(
  Duration duration, {
  Future<void> Function(Duration duration)? delay,
  Future<void>? cancellation,
}) async {
  if (cancellation == null) {
    await (delay?.call(duration) ?? Future<void>.delayed(duration));
    return;
  }
  if (delay != null) {
    await Future.any<void>([delay(duration), cancellation]);
    return;
  }

  final completed = Completer<void>();
  final timer = Timer(duration, () {
    if (!completed.isCompleted) completed.complete();
  });
  cancellation.then((_) {
    if (!completed.isCompleted) completed.complete();
  });
  await completed.future;
  timer.cancel();
}

Future<bool> _isRateLimit(Object error) async {
  if (error is! DioException || error.response?.statusCode != 429) return false;
  final responseData = error.response?.data;
  final responseBody = responseData is ResponseBody
      ? await _readResponseBody(responseData)
      : _flattenErrorDetails(responseData);
  final details = [
    responseBody,
    error.response?.statusMessage ?? '',
    error.message ?? '',
  ].join(' ').toLowerCase();
  const nonThrottleMarkers = [
    'insufficient_quota',
    'quota',
    'billing',
    'payment',
    'account',
    'hard_limit',
    'usage_limit',
    'credits',
    'invalid_request',
    'invalid_parameter',
    'invalid_api_key',
    'authentication_error',
    'unauthorized',
    'permission_denied',
    'validation_error',
    'bad_request',
    'server_error',
    'internal_error',
    'internal server error',
  ];
  if (nonThrottleMarkers.any(details.contains)) return false;
  const throttleMarkers = [
    'rate_limit',
    'rate limit',
    'too many requests',
    'throttl',
  ];
  return throttleMarkers.any(details.contains);
}

Future<String> _readResponseBody(ResponseBody body) async {
  try {
    final bytes = await body.stream.fold<List<int>>(
      <int>[],
      (buffer, chunk) => buffer..addAll(chunk),
    );
    return utf8.decode(bytes, allowMalformed: true).toLowerCase();
  } catch (_) {
    return '';
  }
}

String _flattenErrorDetails(Object? value) {
  if (value is Map) {
    return value.entries
        .map((entry) => '${entry.key} ${_flattenErrorDetails(entry.value)}')
        .join(' ');
  }
  if (value is Iterable) return value.map(_flattenErrorDetails).join(' ');
  return value?.toString() ?? '';
}

Duration? _retryAfter(Object error, {required Duration maximum}) {
  if (error is! DioException) return null;
  final value = error.response?.headers.value('retry-after');
  if (value == null) return null;
  final seconds = double.tryParse(value.trim());
  if (seconds != null && seconds >= 0 && seconds.isFinite) {
    final millis = math.min(seconds * 1000, maximum.inMilliseconds).round();
    return Duration(milliseconds: millis);
  }
  final date = _parseRetryAfterDate(value);
  if (date == null) return null;
  final remaining = date.difference(DateTime.now());
  if (remaining.isNegative) return Duration.zero;
  return remaining > maximum ? maximum : remaining;
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
  bool hasToolHistory = false,
}) {
  if (!hasPartialOutput || hasToolHistory) return false;
  return isRetryableTransportFailure(error);
}

/// True only for transport-level failures that can be retried without replaying
/// a completed request, validation failure, or server response.
bool isRetryableTransportFailure(Object? error) {
  if (error == null) return false;
  if (error is DioException) {
    if (error.response?.statusCode != null) return false;
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError =>
        true,
      DioExceptionType.unknown => _isNetworkTransportCause(error.error),
      _ => false,
    };
  }
  return _isNetworkTransportCause(error);
}

bool _isNetworkTransportCause(Object? error) {
  if (error is TimeoutException) return true;
  if (error is SocketException) return true;
  if (error is HttpException) {
    final message = error.message.toLowerCase();
    return message.contains('connection closed') ||
        message.contains('connection reset') ||
        message.contains('connection aborted') ||
        message.contains('connection broken');
  }
  return false;
}
