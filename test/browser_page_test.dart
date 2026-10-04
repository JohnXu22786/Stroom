import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/browser_page.dart';
import 'package:stroom/services/browser_cookie_service.dart';

void main() {
  group('BrowserCookieStorePreparation', () {
    test('shares preparation between initial load and address submission',
        () async {
      final preparationCompleter = Completer<bool>();
      var preparationCalls = 0;
      final cookiePreparation = BrowserCookieStorePreparation(() {
        preparationCalls++;
        return preparationCompleter.future;
      });
      final loadedUrls = <String>[];

      final initialLoad = navigateBrowserPageAfterCookiePreparation(
        prepareCookies: cookiePreparation.ensurePrepared,
        loadUrl: () async => loadedUrls.add('initial'),
      );
      var address = 'https://previous.example/';
      final addressSubmit = navigateBrowserPageFromAddress(
        requestedUrl: 'https://requested.example/page',
        previousAddress: address,
        currentUrl: address,
        updateAddress: (value) => address = value,
        prepareCookies: cookiePreparation.ensurePrepared,
        loadUrl: (url) async => loadedUrls.add(url),
        onPreparationFailure: () {},
      );

      expect(loadedUrls, isEmpty);
      final preparationCallsWhileWaiting = preparationCalls;

      preparationCompleter.complete(true);

      expect(await initialLoad, isTrue);
      expect(await addressSubmit, isTrue);
      expect(preparationCallsWhileWaiting, 1);
      expect(preparationCalls, 1);
      expect(loadedUrls,
          unorderedEquals(['initial', 'https://requested.example/page']));
      expect(address, 'https://requested.example/page');
    });
  });

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

  group('BrowserPage redirect cookie tracking', () {
    late _HostOnlyCookiePlatform cookiePlatform;

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'browser_cookie_retention': true,
      });
      BrowserCookieService.enableTestMode();
      cookiePlatform = _HostOnlyCookiePlatform();
      BrowserCookieService.cookiePlatform = cookiePlatform;
    });

    tearDown(BrowserCookieService.disableTestMode);

    test('persists cookies from both the starting and redirect hosts',
        () async {
      // These events mirror the top-level onLoadStart and onLoadStop callbacks.
      noteBrowserPageNavigationUrl('https://start.example/start');
      noteBrowserPageNavigationUrl('https://redirect.example/final');

      await BrowserCookieService.persistCookiesToFile();

      expect(BrowserCookieService.visitedDomainsForTest,
          {'start.example', 'redirect.example'});
      expect(
          cookiePlatform.queriedHosts, {'start.example', 'redirect.example'});

      final persistedCookies = await BrowserCookieService.getCookiesFromFile();
      expect(persistedCookies.keys,
          containsAll({'start.example', 'redirect.example'}));
      expect(
          persistedCookies['start.example']!.single['value'], 'start.example');
      expect(persistedCookies['redirect.example']!.single['value'],
          'redirect.example');
    });
  });
}

class _HostOnlyCookiePlatform extends Fake implements CookiePlatform {
  final queriedHosts = <String>{};

  @override
  Future<List<Cookie>> getAllCookies() async => throw UnimplementedError();

  @override
  Future<List<Cookie>> getCookies({required WebUri url}) async {
    final host = Uri.parse(url.toString()).host;
    queriedHosts.add(host);
    return [Cookie(name: 'session', value: host)];
  }
}
