import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/browser_cookies_page.dart';
import 'package:stroom/pages/browser_page.dart';
import 'package:stroom/services/browser_cookie_service.dart';

const _captureKey = ValueKey('browser-dialog-body-capture');
const _deletionCapture =
    '../../docs/ui-constrained-text-qa/vertical-browser-dialog-body/browser-script-delete-de-DE-320x320-scale2-light.png';
const _deletionScrolledCapture =
    '../../docs/ui-constrained-text-qa/vertical-browser-dialog-body/browser-script-delete-de-DE-320x320-scale2-light-scrolled.png';
const _trustCapture =
    '../../docs/ui-constrained-text-qa/vertical-browser-dialog-body/browser-script-trust-de-DE-320x320-scale2-light.png';
const _trustScrolledCapture =
    '../../docs/ui-constrained-text-qa/vertical-browser-dialog-body/browser-script-trust-de-DE-320x320-scale2-light-scrolled.png';
const _cookiesCapture =
    '../../docs/ui-constrained-text-qa/vertical-browser-dialog-body/browser-clear-cookies-de-DE-320x320-scale2-light.png';
const _cookiesScrolledCapture =
    '../../docs/ui-constrained-text-qa/vertical-browser-dialog-body/browser-clear-cookies-de-DE-320x320-scale2-light-scrolled.png';

Widget _app(Widget home, {double textScale = 2}) => MaterialApp(
  locale: const Locale('de', 'DE'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: RepaintBoundary(key: _captureKey, child: child!),
  ),
  home: home,
);

void _useViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _expectBodyScrollable(
  WidgetTester tester, {
  required String text,
  required String screenshot,
  required String scrolledScreenshot,
}) async {
  final dialog = find.byType(AlertDialog);
  expect(dialog, findsOneWidget);
  final body = find.descendant(of: dialog, matching: find.text(text));
  expect(body, findsOneWidget);
  final scrollableFinder = find.descendant(
    of: dialog,
    matching: find.byType(Scrollable),
  );
  expect(scrollableFinder, findsOneWidget);
  final scrollable = tester.state<ScrollableState>(scrollableFinder);
  expect(scrollable.position.maxScrollExtent, greaterThan(0));

  final actions = find.descendant(
    of: dialog,
    matching: find.byType(TextButton),
  );
  expect(actions, findsWidgets);
  await expectLater(find.byKey(_captureKey), matchesGoldenFile(screenshot));

  scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
  await tester.pumpAndSettle();
  final scrollRect = tester.getRect(scrollableFinder);
  final bodyRect = tester.getRect(body);
  expect(bodyRect.bottom, lessThanOrEqualTo(scrollRect.bottom + 1));
  expect(
    tester.getRect(actions.first).bottom,
    lessThanOrEqualTo(tester.getRect(dialog).bottom),
  );
  await expectLater(
    find.byKey(_captureKey),
    matchesGoldenFile(scrolledScreenshot),
  );
  expect(tester.takeException(), isNull);
}

Future<void> _expectBodyFitsWithoutScrolling(
  WidgetTester tester,
  String text,
) async {
  final dialog = find.byType(AlertDialog);
  final body = find.descendant(of: dialog, matching: find.text(text));
  expect(dialog, findsOneWidget);
  expect(body, findsOneWidget);
  final scrollable = tester.state<ScrollableState>(
    find.descendant(of: dialog, matching: find.byType(Scrollable)),
  );
  expect(scrollable.position.maxScrollExtent, 0);
  final action = find.descendant(of: dialog, matching: find.byType(TextButton));
  expect(
    tester.getRect(action).bottom,
    lessThanOrEqualTo(tester.getRect(dialog).bottom),
  );
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot == null) return;
    final fontDirectory = '$flutterRoot/bin/cache/artifacts/material_fonts';
    for (final (family, fileName) in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final bytes = File('$fontDirectory/$fileName').readAsBytesSync();
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BrowserCookieService.enableTestMode();
  });

  tearDown(BrowserCookieService.disableTestMode);

  testWidgets('script deletion confirmation body scrolls when constrained', (
    tester,
  ) async {
    _useViewport(tester, const Size(320, 320));
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => confirmBrowserUserScriptDeletion(context),
              child: const Text('Open deletion confirmation'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open deletion confirmation'));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(AlertDialog)))!;
    await _expectBodyScrollable(
      tester,
      text: l10n.browserDeleteScriptConfirmation,
      screenshot: _deletionCapture,
      scrolledScreenshot: _deletionScrolledCapture,
    );
  });

  testWidgets('script trust warning body scrolls when constrained', (
    tester,
  ) async {
    _useViewport(tester, const Size(320, 320));
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => confirmBrowserUserScriptTrust(context),
              child: const Text('Open trust confirmation'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open trust confirmation'));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(AlertDialog)))!;
    await _expectBodyScrollable(
      tester,
      text: l10n.browserScriptTrustWarning,
      screenshot: _trustCapture,
      scrolledScreenshot: _trustScrolledCapture,
    );
  });

  testWidgets('cookie clearing confirmation body scrolls when constrained', (
    tester,
  ) async {
    _useViewport(tester, const Size(320, 320));
    await tester.pumpWidget(_app(const BrowserCookiesPage()));
    await tester.pumpAndSettle();
    final pageL10n = AppLocalizations.of(
      tester.element(find.byType(Scaffold)),
    )!;
    final clearAllTile = find.text(pageL10n.browserCookiesClearAllTitle);
    await tester.scrollUntilVisible(
      clearAllTile,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(clearAllTile);
    await tester.pumpAndSettle();
    final dialogL10n = AppLocalizations.of(
      tester.element(find.byType(AlertDialog)),
    )!;
    await _expectBodyScrollable(
      tester,
      text: dialogL10n.browserCookiesConfirmClearAll,
      screenshot: _cookiesCapture,
      scrolledScreenshot: _cookiesScrolledCapture,
    );
  });

  testWidgets('confirmation bodies fit without scrolling at normal size', (
    tester,
  ) async {
    _useViewport(tester, const Size(320, 640));

    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => confirmBrowserUserScriptDeletion(context),
              child: const Text('Open deletion confirmation'),
            ),
          ),
        ),
        textScale: 1,
      ),
    );
    await tester.tap(find.text('Open deletion confirmation'));
    await tester.pumpAndSettle();
    var l10n = AppLocalizations.of(tester.element(find.byType(AlertDialog)))!;
    await _expectBodyFitsWithoutScrolling(
      tester,
      l10n.browserDeleteScriptConfirmation,
    );
    await tester.tap(find.text(l10n.browserCancel));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => confirmBrowserUserScriptTrust(context),
              child: const Text('Open trust confirmation'),
            ),
          ),
        ),
        textScale: 1,
      ),
    );
    await tester.tap(find.text('Open trust confirmation'));
    await tester.pumpAndSettle();
    l10n = AppLocalizations.of(tester.element(find.byType(AlertDialog)))!;
    await _expectBodyFitsWithoutScrolling(
      tester,
      l10n.browserScriptTrustWarning,
    );
    await tester.tap(find.text(l10n.browserCancel));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_app(const BrowserCookiesPage(), textScale: 1));
    await tester.pumpAndSettle();
    l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
    await tester.tap(find.text(l10n.browserCookiesClearAllTitle));
    await tester.pumpAndSettle();
    l10n = AppLocalizations.of(tester.element(find.byType(AlertDialog)))!;
    await _expectBodyFitsWithoutScrolling(
      tester,
      l10n.browserCookiesConfirmClearAll,
    );
  });
}
