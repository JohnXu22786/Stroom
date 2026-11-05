import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/chat_retry_policy.dart';

void main() {
  group('retryRateLimitedStream', () {
    test('jitter stays within half to all of the scheduled delay', () {
      const policy = RateLimitRetryPolicy();
      expect(
        policy.delayForRetry(1, randomValue: 0.5),
        const Duration(seconds: 1),
      );
      expect(
        policy.delayForRetry(1, randomValue: 1),
        const Duration(seconds: 2),
      );
      expect(
        policy.delayForRetry(4, randomValue: 1),
        const Duration(seconds: 10),
      );
    });

    test('retries a throttled 429 five times with OpenCode-style waits', () async {
      var calls = 0;
      final delays = <Duration>[];
      final events = await retryRateLimitedStream<String>(
        () {
          calls++;
          if (calls < 6) {
            return Stream.error(DioException(
              requestOptions: RequestOptions(path: '/chat'),
              response: Response(
                requestOptions: RequestOptions(path: '/chat'),
                statusCode: 429,
                data: {'error': {'type': 'rate_limit_error'}},
              ),
              type: DioExceptionType.badResponse,
            ));
          }
          return Stream.value('ok');
        },
        policy: const RateLimitRetryPolicy(jitter: false),
        delay: (duration) async => delays.add(duration),
      ).toList();

      expect(events, ['ok']);
      expect(calls, 6);
      expect(delays, [
        const Duration(seconds: 2),
        const Duration(seconds: 4),
        const Duration(seconds: 8),
        const Duration(seconds: 10),
        const Duration(seconds: 10),
      ]);
    });

    test('does not retry quota or account-cap 429 responses', () async {
      for (final message in [
        'insufficient_quota',
        'Your account billing limit has been reached',
        'Invalid request parameter',
        'Authentication error: invalid API key',
      ]) {
        var calls = 0;
        final failure = DioException(
          requestOptions: RequestOptions(path: '/chat'),
          response: Response(
            requestOptions: RequestOptions(path: '/chat'),
            statusCode: 429,
            data: {
              'error': {
                'type': message.startsWith('Invalid')
                    ? 'invalid_request_error'
                    : message.startsWith('Authentication')
                        ? 'authentication_error'
                        : 'insufficient_quota',
                'message': message,
              }
            },
          ),
          type: DioExceptionType.badResponse,
        );
        await expectLater(
          retryRateLimitedStream<String>(() {
            calls++;
            return Stream.error(failure);
          }, delay: (_) async {}),
          emitsError(same(failure)),
        );
        expect(calls, 1, reason: message);
      }
    });

    test('does not retry non-429 errors or retry after its budget', () async {
      var calls = 0;
      final failure = DioException(
        requestOptions: RequestOptions(path: '/chat'),
        response: Response(
          requestOptions: RequestOptions(path: '/chat'),
          statusCode: 503,
        ),
        type: DioExceptionType.badResponse,
      );
      await expectLater(
        retryRateLimitedStream<String>(() {
          calls++;
          return Stream.error(failure);
        }, delay: (_) async {}),
        emitsError(same(failure)),
      );
      expect(calls, 1);

      calls = 0;
      await expectLater(
        retryRateLimitedStream<String>(() {
          calls++;
          return Stream.error(DioException(
            requestOptions: RequestOptions(path: '/chat'),
            response: Response(
              requestOptions: RequestOptions(path: '/chat'),
              statusCode: 429,
              data: {'error': {'code': 'rate_limit_exceeded'}},
            ),
            type: DioExceptionType.badResponse,
          ));
        },
            policy: const RateLimitRetryPolicy(maxRetries: 2, jitter: false),
            delay: (_) async {}),
        emitsError(isA<DioException>()),
      );
      expect(calls, 3);
    });

    test('honors an HTTP-date Retry-After header', () async {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const longWeekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final retryAt = DateTime.now().toUtc().add(const Duration(seconds: 8));
      String twoDigits(int value) => value.toString().padLeft(2, '0');
      final month = months[retryAt.month - 1];
      final time = '${twoDigits(retryAt.hour)}:${twoDigits(retryAt.minute)}:'
          '${twoDigits(retryAt.second)}';
      final asctimeDay =
          retryAt.day < 10 ? ' ${retryAt.day}' : '${retryAt.day}';
      final retryAfterValues = [
        '${weekdays[retryAt.weekday - 1]}, ${twoDigits(retryAt.day)} '
            '$month ${retryAt.year} $time GMT',
        '${longWeekdays[retryAt.weekday - 1]}, ${twoDigits(retryAt.day)}-'
            '$month-${twoDigits(retryAt.year % 100)} $time GMT',
        '${weekdays[retryAt.weekday - 1]} $month $asctimeDay $time '
            '${retryAt.year}',
      ];

      for (final retryAfter in retryAfterValues) {
        final headers = Headers.fromMap({
          'retry-after': [retryAfter]
        });
        final waits = <Duration>[];
        var calls = 0;
        await retryRateLimitedStream<String>(() {
          calls++;
          if (calls == 1) {
            return Stream.error(DioException(
              requestOptions: RequestOptions(path: '/chat'),
              response: Response(
                requestOptions: RequestOptions(path: '/chat'),
                statusCode: 429,
                data: {'error': {'type': 'rate_limit_error'}},
                headers: headers,
              ),
              type: DioExceptionType.badResponse,
            ));
          }
          return Stream.value('ok');
        }, delay: (duration) async => waits.add(duration)).toList();

        expect(calls, 2, reason: retryAfter);
        expect(waits.single.inSeconds, inInclusiveRange(6, 8),
            reason: retryAfter);
      }
    });

    test('honors Retry-After seconds beyond the exponential backoff cap',
        () async {
      final waits = <Duration>[];
      var calls = 0;
      await retryRateLimitedStream<String>(() {
        calls++;
        if (calls == 1) {
          return Stream.error(DioException(
            requestOptions: RequestOptions(path: '/chat'),
            response: Response(
              requestOptions: RequestOptions(path: '/chat'),
              statusCode: 429,
              data: {'error': {'type': 'rate_limit_error'}},
              headers: Headers.fromMap({
                'retry-after': ['8']
              }),
            ),
            type: DioExceptionType.badResponse,
          ));
        }
        return Stream.value('ok');
      }, delay: (duration) async => waits.add(duration)).toList();

      expect(calls, 2);
      expect(waits.single, const Duration(seconds: 8));
    });

    test('bounds Retry-After waits', () async {
      final waits = <Duration>[];
      var calls = 0;
      await retryRateLimitedStream<String>(() {
        calls++;
        if (calls == 1) {
          return Stream.error(DioException(
            requestOptions: RequestOptions(path: '/chat'),
            response: Response(
              requestOptions: RequestOptions(path: '/chat'),
              statusCode: 429,
              data: {'error': {'type': 'rate_limit_error'}},
              headers: Headers.fromMap({
                'retry-after': ['3600']
              }),
            ),
            type: DioExceptionType.badResponse,
          ));
        }
        return Stream.value('ok');
      }, delay: (duration) async => waits.add(duration)).toList();

      expect(waits.single, const Duration(minutes: 15));
    });
  });

  group('network continuation policy', () {
    test('continues only when a network failure interrupts visible output', () {
      final networkFailure = DioException(
        requestOptions: RequestOptions(path: '/chat'),
        type: DioExceptionType.connectionError,
      );
      expect(
          shouldAutoContinueStream(
            error: networkFailure,
            hasPartialOutput: true,
          ),
          isTrue);
      expect(kAutoContinuationMessage, 'Continue if not finished.');
    });

    test('does not continue after completion or on request/server errors', () {
      final requestFailure = DioException(
        requestOptions: RequestOptions(path: '/chat'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/chat'),
          statusCode: 400,
        ),
      );
      final serverFailure = DioException(
        requestOptions: RequestOptions(path: '/chat'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/chat'),
          statusCode: 500,
        ),
      );
      final networkFailure = DioException(
        requestOptions: RequestOptions(path: '/chat'),
        type: DioExceptionType.connectionError,
      );
      expect(shouldAutoContinueStream(error: null, hasPartialOutput: true),
          isFalse);
      expect(
          shouldAutoContinueStream(
              error: networkFailure, hasPartialOutput: false),
          isFalse);
      expect(
          shouldAutoContinueStream(
            error: networkFailure,
            hasPartialOutput: true,
            hasToolHistory: true,
          ),
          isFalse);
      expect(
          shouldAutoContinueStream(
              error: requestFailure, hasPartialOutput: true),
          isFalse);
      expect(
          shouldAutoContinueStream(
              error: serverFailure, hasPartialOutput: true),
          isFalse);
      expect(
          shouldAutoContinueStream(
              error: StateError('bad request'), hasPartialOutput: true),
          isFalse);
      expect(
        shouldAutoContinueStream(
          error: DioException(
            requestOptions: RequestOptions(path: '/chat'),
            error: HttpException(
                'Connection closed before full header was received'),
            type: DioExceptionType.unknown,
          ),
          hasPartialOutput: true,
        ),
        isTrue,
      );
      expect(
        shouldAutoContinueStream(
          error: DioException(
            requestOptions: RequestOptions(path: '/chat'),
            error: HttpException('Invalid HTTP response'),
            type: DioExceptionType.unknown,
          ),
          hasPartialOutput: true,
        ),
        isFalse,
      );
      expect(
        shouldAutoContinueStream(
          error: DioException(
            requestOptions: RequestOptions(path: '/chat'),
            error: const SocketException('Network is unreachable'),
            type: DioExceptionType.unknown,
          ),
          hasPartialOutput: true,
        ),
        isTrue,
      );
      expect(
        shouldAutoContinueStream(
          error: DioException(
            requestOptions: RequestOptions(path: '/chat'),
            error: FormatException('Invalid JSON from server'),
            type: DioExceptionType.unknown,
          ),
          hasPartialOutput: true,
        ),
        isFalse,
      );
    });
  });
}
