import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/utils/http_timeout.dart';

void main() {
  group('http timeout policy', () {
    test('connect timeout fails fast on unreachable hosts', () {
      expect(connectTimeoutDefault, const Duration(seconds: 30));
    });

    test('response fallback is a long bound (60 min)', () {
      expect(receiveTimeoutFallback, const Duration(minutes: 60));
    });

    test('sendTimeout base for empty/small bodies', () {
      expect(sendTimeoutForBytes(0), const Duration(minutes: 1));
      expect(sendTimeoutForBytes(1024), const Duration(minutes: 1));
    });

    test('sendTimeout scales with body size (2s per MiB)', () {
      expect(
        sendTimeoutForBytes(1 * 1024 * 1024),
        const Duration(minutes: 1, seconds: 2),
      );
      expect(
        sendTimeoutForBytes(100 * 1024 * 1024),
        const Duration(minutes: 1, seconds: 200),
      );
    });

    test('sendTimeout caps at 15 minutes for very large bodies', () {
      expect(
        sendTimeoutForBytes(1000 * 1024 * 1024),
        const Duration(minutes: 15),
      );
    });
  });
}
