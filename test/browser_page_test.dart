import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/browser_page.dart';

void main() {
  group('navigateBrowserPageFromAddress', () {
    test('restores the loaded URL and reports cookie preparation failure',
        () async {
      var address = 'https://attempted.example/page';
      var loadAttempts = 0;
      var failureSignals = 0;

      final navigated = await navigateBrowserPageFromAddress(
        requestedUrl: 'https://attempted.example/page',
        previousAddress: address,
        currentUrl: 'https://loaded.example/current',
        updateAddress: (value) => address = value,
        prepareCookies: () async => false,
        loadUrl: (_) async => loadAttempts++,
        onPreparationFailure: () => failureSignals++,
      );

      expect(navigated, isFalse);
      expect(address, 'https://loaded.example/current');
      expect(loadAttempts, 0);
      expect(failureSignals, 1);
    });

    test('keeps the address unchanged when no page has loaded', () async {
      var address = 'attempted.example/page';
      var loadAttempts = 0;

      final navigated = await navigateBrowserPageFromAddress(
        requestedUrl: address,
        previousAddress: address,
        currentUrl: '',
        updateAddress: (value) => address = value,
        prepareCookies: () async => false,
        loadUrl: (_) async => loadAttempts++,
        onPreparationFailure: () {},
      );

      expect(navigated, isFalse);
      expect(address, 'attempted.example/page');
      expect(loadAttempts, 0);
    });

    test('preserves normalized address on successful navigation', () async {
      var address = 'https://loaded.example/current';
      final loadedUrls = <String>[];
      var failureSignals = 0;

      final navigated = await navigateBrowserPageFromAddress(
        requestedUrl: 'example.com/page',
        previousAddress: address,
        currentUrl: address,
        updateAddress: (value) => address = value,
        prepareCookies: () async => true,
        loadUrl: (url) async => loadedUrls.add(url),
        onPreparationFailure: () => failureSignals++,
      );

      expect(navigated, isTrue);
      expect(address, 'https://example.com/page');
      expect(loadedUrls, ['https://example.com/page']);
      expect(failureSignals, 0);
    });
  });
}
