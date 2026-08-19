import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/utils/http_timeout.dart';

void main() {
  group('http timeout policy', () {
    test('layered ordering: connect < send < response fallback', () {
      // The whole point of the layered policy: connection-phase failures
      // fail fast (seconds), uploads get size-scaled headroom, and the
      // response bound is a long last resort that never kills slow-but-
      // healthy servers.
      expect(
        connectTimeoutDefault < sendTimeoutForBytes(0),
        isTrue,
        reason: 'connect must fail fast, before any upload budget',
      );
      expect(
        sendTimeoutForBytes(0) < receiveTimeoutFallback,
        isTrue,
        reason: 'response bound must be far beyond the upload budget',
      );
      expect(
        connectTimeoutDefault < receiveTimeoutFallback,
        isTrue,
      );
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
