import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/engine/webview_sniffer.dart';
import 'package:stroom/catcatch/providers/catcatch_provider.dart';

void main() {
  test('recovered extensionless video keeps MIME classification', () {
    final resource = recoveredBrowserMediaResource(
      url: 'https://cdn.example.net/stream?token=abc',
      initiator: 'https://example.net/watch',
      mimeType: 'video/*',
    );

    expect(resource.ext, isEmpty);
    expect(resource.mimeType, 'video/*');
    expect(resource.isPlayable, isTrue);
    expect(resource.isPlaylist, isFalse);
  });

  group('WebViewSniffer recovery attempts', () {
    test(
      'uses the exact headless timeout schedule and stops on success',
      () async {
        final attempts = <({bool headless, Duration timeout})>[];

        final result = await WebViewSniffer.runHeadlessRecoveryAttempts<int>(
          runAttempt: (timeout) async {
            attempts.add((headless: true, timeout: timeout));
            if (attempts.length == 1) throw TimeoutException('stalled');
            return 7;
          },
        );

        expect(result, 7);
        expect(attempts, [
          (headless: true, timeout: const Duration(seconds: 10)),
          (headless: true, timeout: const Duration(seconds: 20)),
        ]);
      },
    );

    test('enters interactive recovery after both headless timeouts', () async {
      final attempts = <Duration>[];

      final result = await WebViewSniffer.runHeadlessRecoveryAttempts<int>(
        runAttempt: (timeout) async {
          attempts.add(timeout);
          throw TimeoutException('stalled');
        },
      );

      expect(result, isNull);
      expect(attempts, const [Duration(seconds: 10), Duration(seconds: 20)]);
      expect(WebViewSniffer.headedRecoveryTimeouts, const [
        Duration(seconds: 20),
        Duration(seconds: 20),
      ]);
    });

    test(
      'does not retry non-timeout errors or continue after cancellation',
      () async {
        var calls = 0;
        await expectLater(
          WebViewSniffer.runHeadlessRecoveryAttempts<int>(
            runAttempt: (_) async {
              calls++;
              throw StateError('not a timeout');
            },
          ),
          throwsA(isA<StateError>()),
        );
        expect(calls, 1);

        final canceledResult =
            await WebViewSniffer.runHeadlessRecoveryAttempts<int>(
          isCancelled: () => true,
          runAttempt: (_) async {
            calls++;
            return 1;
          },
        );
        expect(canceledResult, isNull);
        expect(calls, 1);
      },
    );
  });
}
