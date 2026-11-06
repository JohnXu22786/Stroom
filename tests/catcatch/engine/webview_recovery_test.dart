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

  test('recovered media keeps the initiator associated with each URL', () {
    final resources = recoveredBrowserMediaResources(
      mediaUrls: [
        'https://cdn.example.net/a/master.m3u8',
        'https://cdn.example.net/b/video.mp4',
      ],
      fallbackInitiator: 'https://example.net/current-page',
      initiatorsByUrl: {
        'https://cdn.example.net/a/master.m3u8':
            'https://example.net/first-watch-page',
        'https://cdn.example.net/b/video.mp4':
            'https://example.net/second-watch-page',
      },
    );

    expect(resources.map((resource) => resource.initiator), [
      'https://example.net/first-watch-page',
      'https://example.net/second-watch-page',
    ]);
  });

  test('cleanup completion yields to a scan completed during disposal',
      () async {
    final completer = Completer<String>();
    final disposalStarted = Completer<void>();
    final finishDisposal = Completer<void>();
    var timeoutCompletions = 0;

    final timeoutCompletion = completeAfterCleanupIfPending(
      completer: completer,
      cleanup: () {
        disposalStarted.complete();
        return finishDisposal.future;
      },
      complete: () {
        timeoutCompletions++;
        completer.complete('timeout');
      },
    );
    await disposalStarted.future;
    completer.complete('load-stop');
    finishDisposal.complete();
    await timeoutCompletion;

    expect(await completer.future, 'load-stop');
    expect(timeoutCompletions, 0);
  });

  test('cancellation cleanup waits for timeout-owned disposal', () async {
    final cleanup = SingleFlightAsyncCleanup();
    final disposalStarted = Completer<void>();
    final finishDisposal = Completer<void>();
    var disposalCalls = 0;
    var timeoutCleanupFinished = false;
    var cancellationCleanupFinished = false;

    final timeoutCleanup = cleanup.run(() async {
      disposalCalls++;
      disposalStarted.complete();
      await finishDisposal.future;
    }).then((_) => timeoutCleanupFinished = true);
    await disposalStarted.future;

    final cancellationCleanup = cleanup
        .run(() async => disposalCalls++)
        .then((_) => cancellationCleanupFinished = true);
    await Future<void>.delayed(Duration.zero);

    expect(disposalCalls, 1);
    expect(timeoutCleanupFinished, isFalse);
    expect(cancellationCleanupFinished, isFalse);
    finishDisposal.complete();
    await Future.wait([timeoutCleanup, cancellationCleanup]);

    expect(timeoutCleanupFinished, isTrue);
    expect(cancellationCleanupFinished, isTrue);
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

    test('headed recovery consumes exactly two timeout attempts', () {
      final attempts = HeadedRecoveryAttemptSchedule();

      expect(attempts.hasRemainingAttempts, isTrue);
      expect(attempts.startNextAttempt(), 0);
      expect(attempts.hasRemainingAttempts, isTrue);
      expect(attempts.startNextAttempt(), 1);
      expect(attempts.hasRemainingAttempts, isFalse);
      expect(attempts.startNextAttempt(), isNull);
      expect(WebViewSniffer.headedRecoveryTimeouts, const [
        Duration(seconds: 20),
        Duration(seconds: 20),
      ]);
    });

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
