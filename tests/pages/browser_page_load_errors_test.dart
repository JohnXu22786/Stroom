import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/browser_page.dart';
import 'package:stroom/services/browser_cookie_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BrowserCookieService.enableTestMode();
  });

  tearDown(BrowserCookieService.disableTestMode);

  testWidgets('sniff panel toggle tooltip follows the active locale',
      (tester) async {
    final previousPlatform = InAppWebViewPlatform.instance;
    final platform = _installBrowserPagePlatform();
    addTearDown(() => InAppWebViewPlatform.instance =
        previousPlatform ?? _BrowserPagePlatform());

    await _startNavigation(tester, platform, locale: const Locale('en', 'US'));
    expect(find.byTooltip('Hide sniff panel'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide sniff panel'));
    await tester.pump();
    expect(find.byTooltip('Show sniff panel'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _startNavigation(tester, platform, locale: const Locale('zh', 'CN'));
    expect(find.byTooltip('隐藏嗅探面板'), findsOneWidget);

    await tester.tap(find.byTooltip('隐藏嗅探面板'));
    await tester.pump();
    expect(find.byTooltip('显示嗅探面板'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('recovery guidance wraps and remains scrollable at large text',
      (tester) async {
    final previousPlatform = InAppWebViewPlatform.instance;
    final platform = _installBrowserPagePlatform();
    addTearDown(() => InAppWebViewPlatform.instance =
        previousPlatform ?? _BrowserPagePlatform());

    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: BrowserPage(initialUrl: 'about:blank', recoveryMode: true),
        ),
      ),
    );
    final webView = platform.webView!;
    final controller = webView
        .controllerFromPlatform<InAppWebViewController>(webView.controller);
    webView.params.onLoadStart!(controller, WebUri('about:blank'));
    await tester.pump();

    final guidance = find.byKey(const Key('browser-recovery-guidance-scroll'));
    expect(guidance, findsOneWidget);
    final guidanceText = tester.widget<Text>(
      find.descendant(of: guidance, matching: find.byType(Text)),
    );
    expect(
      guidanceText.data,
      AppLocalizations.of(tester.element(find.byType(BrowserPage)))!
          .catcatchWebViewRecoveryGuidance,
    );
    expect(guidanceText.maxLines, isNull);
    expect(guidanceText.overflow, isNull);
    expect(find.byTooltip('Continue flow'), findsOneWidget);

    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: guidance, matching: find.byType(Scrollable)),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    await tester.drag(guidance, const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('browser permits externally hosted mixed-content resources',
      (tester) async {
    final previousPlatform = InAppWebViewPlatform.instance;
    final platform = _installBrowserPagePlatform();
    addTearDown(() => InAppWebViewPlatform.instance =
        previousPlatform ?? _BrowserPagePlatform());

    await _startNavigation(tester, platform);

    expect(
      platform.webView!.params.initialSettings?.mixedContentMode,
      MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('injects saved userscripts when preferences load after page',
      (tester) async {
    final previousPlatform = InAppWebViewPlatform.instance;
    final platform = _installBrowserPagePlatform();
    addTearDown(() => InAppWebViewPlatform.instance =
        previousPlatform ?? _BrowserPagePlatform());
    final preferencesReady = Completer<void>();
    SharedPreferencesStorePlatform.instance = _DelayedPreferencesStore(
      {
        'flutter.browser_user_scripts': jsonEncode([
          {
            'id': 'saved-script',
            'name': 'Saved script',
            'code': 'window.savedUserscriptRan = true;',
            'enabled': true,
            'origin': 'manual',
          },
        ]),
      },
      preferencesReady,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BrowserPage(initialUrl: 'https://example.com/'),
      ),
    );
    final webView = platform.webView!;
    final controller = webView
        .controllerFromPlatform<InAppWebViewController>(webView.controller);
    webView.params.onWebViewCreated!(controller);
    webView.params.onLoadStop!(controller, WebUri('https://example.com/'));
    await tester.pump();

    expect(
      webView.controller.evaluatedScripts.where(
          (script) => script.contains('window.savedUserscriptRan = true;')),
      isEmpty,
    );

    preferencesReady.complete();
    await tester.pump();
    await tester.pump();

    expect(
      webView.controller.evaluatedScripts.where(
          (script) => script.contains('window.savedUserscriptRan = true;')),
      [
        'window.savedUserscriptRan = true;\n'
            '//# sourceURL=stroom-userscript-saved-script.js'
      ],
    );

    final scriptsTooltip = AppLocalizations.of(
      tester.element(find.byType(BrowserPage)),
    )!
        .browserUserScripts;
    await tester.tap(find.byTooltip(scriptsTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(
      webView.controller.evaluatedScripts.where(
          (script) => script.contains('window.savedUserscriptRan = true;')),
      hasLength(2),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('waits for load stop and injects each saved userscript once',
      (tester) async {
    final previousPlatform = InAppWebViewPlatform.instance;
    final platform = _installBrowserPagePlatform();
    addTearDown(() => InAppWebViewPlatform.instance =
        previousPlatform ?? _BrowserPagePlatform());
    final preferencesReady = Completer<void>();
    SharedPreferencesStorePlatform.instance = _DelayedPreferencesStore(
      {
        'flutter.browser_user_scripts': jsonEncode([
          {
            'id': 'saved-script',
            'name': 'Saved script',
            'code': 'window.savedUserscriptRan = true;',
            'enabled': true,
            'origin': 'manual',
          },
        ]),
      },
      preferencesReady,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BrowserPage(initialUrl: 'https://example.com/'),
      ),
    );
    final webView = platform.webView!;
    final controller = webView
        .controllerFromPlatform<InAppWebViewController>(webView.controller);
    webView.params.onWebViewCreated!(controller);
    webView.params.onLoadStart!(controller, WebUri('https://example.com/'));

    preferencesReady.complete();
    await tester.pump();
    await tester.pump();
    expect(
      webView.controller.evaluatedScripts.where(
          (script) => script.contains('window.savedUserscriptRan = true;')),
      isEmpty,
    );

    webView.params.onLoadStop!(controller, WebUri('https://example.com/'));
    await tester.pump();
    await tester.pump();
    webView.params.onLoadStop!(controller, WebUri('https://example.com/'));
    await tester.pump();

    expect(
      webView.controller.evaluatedScripts.where(
          (script) => script.contains('window.savedUserscriptRan = true;')),
      [
        'window.savedUserscriptRan = true;\n'
            '//# sourceURL=stroom-userscript-saved-script.js'
      ],
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ignores stale script failures after same-URL navigation',
      (tester) async {
    final previousPlatform = InAppWebViewPlatform.instance;
    final platform = _installBrowserPagePlatform();
    addTearDown(() => InAppWebViewPlatform.instance =
        previousPlatform ?? _BrowserPagePlatform());
    SharedPreferencesStorePlatform.instance =
        InMemorySharedPreferencesStore.withData({
      'flutter.browser_user_scripts': jsonEncode([
        {
          'id': 'saved-script',
          'name': 'Saved script',
          'code': 'window.savedUserscriptRan = true;',
          'enabled': true,
          'origin': 'manual',
        },
      ]),
    });
    final evaluationStarted = Completer<void>();
    final evaluationGate = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BrowserPage(initialUrl: 'https://example.com/'),
      ),
    );
    final webView = platform.webView!;
    final controller = webView
        .controllerFromPlatform<InAppWebViewController>(webView.controller);
    webView.controller.userScriptEvaluationStarted = evaluationStarted;
    webView.controller.userScriptEvaluationGate = evaluationGate;
    webView.params.onWebViewCreated!(controller);
    webView.params.onLoadStart!(controller, WebUri('https://example.com/'));
    webView.params.onLoadStop!(controller, WebUri('https://example.com/'));
    await tester.pump();
    await tester.pump();
    expect(evaluationStarted.isCompleted, isTrue);

    webView.params.onLoadStart!(controller, WebUri('https://example.com/'));
    webView.params.onLoadStop!(controller, WebUri('https://example.com/'));
    await tester.pump();
    await tester.pump();
    evaluationGate.completeError(StateError('stale evaluation failed'));
    await tester.pump();

    final scriptsTooltip = AppLocalizations.of(
      tester.element(find.byType(BrowserPage)),
    )!
        .browserUserScripts;
    await tester.tap(find.byTooltip(scriptsTooltip));
    await tester.pumpAndSettle();
    expect(
      find.text(AppLocalizations.of(
        tester.element(find.byType(BrowserPage)),
      )!
          .browserScriptRuntimeError),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('re-enabling while evaluation is pending requests a rerun',
      (tester) async {
    final previousPlatform = InAppWebViewPlatform.instance;
    final platform = _installBrowserPagePlatform();
    addTearDown(() => InAppWebViewPlatform.instance =
        previousPlatform ?? _BrowserPagePlatform());
    SharedPreferencesStorePlatform.instance =
        InMemorySharedPreferencesStore.withData({
      'flutter.browser_user_scripts': jsonEncode([
        {
          'id': 'saved-script',
          'name': 'Saved script',
          'code': 'window.savedUserscriptRan = true;',
          'enabled': true,
          'origin': 'manual',
        },
      ]),
    });
    final evaluationStarted = Completer<void>();
    final evaluationGate = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BrowserPage(initialUrl: 'https://example.com/'),
      ),
    );
    final webView = platform.webView!;
    final controller = webView
        .controllerFromPlatform<InAppWebViewController>(webView.controller);
    webView.controller.userScriptEvaluationStarted = evaluationStarted;
    webView.controller.userScriptEvaluationGate = evaluationGate;
    webView.params.onWebViewCreated!(controller);
    webView.params.onLoadStart!(controller, WebUri('https://example.com/'));
    webView.params.onLoadStop!(controller, WebUri('https://example.com/'));
    await tester.pump();
    await tester.pump();
    expect(evaluationStarted.isCompleted, isTrue);

    final scriptsTooltip = AppLocalizations.of(
      tester.element(find.byType(BrowserPage)),
    )!
        .browserUserScripts;
    await tester.tap(find.byTooltip(scriptsTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    evaluationGate.complete();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(
      webView.controller.evaluatedScripts.where(
          (script) => script.contains('window.savedUserscriptRan = true;')),
      hasLength(2),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('manager changes during error monitor do not duplicate script',
      (tester) async {
    final previousPlatform = InAppWebViewPlatform.instance;
    final platform = _installBrowserPagePlatform();
    addTearDown(() => InAppWebViewPlatform.instance =
        previousPlatform ?? _BrowserPagePlatform());
    SharedPreferencesStorePlatform.instance =
        InMemorySharedPreferencesStore.withData({
      'flutter.browser_user_scripts': jsonEncode([
        {
          'id': 'saved-script',
          'name': 'Saved script',
          'code': 'window.savedUserscriptRan = true;',
          'enabled': true,
          'origin': 'manual',
        },
      ]),
    });
    final evaluationStarted = Completer<void>();
    final evaluationGate = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BrowserPage(initialUrl: 'https://example.com/'),
      ),
    );
    final webView = platform.webView!;
    final controller = webView
        .controllerFromPlatform<InAppWebViewController>(webView.controller);
    webView.controller.userScriptEvaluationStarted = evaluationStarted;
    webView.controller.userScriptEvaluationGate = evaluationGate;
    webView.controller.userScriptEvaluationMatch = 'var errorScriptId';
    webView.params.onWebViewCreated!(controller);
    webView.params.onLoadStart!(controller, WebUri('https://example.com/'));
    webView.params.onLoadStop!(controller, WebUri('https://example.com/'));
    await tester.pump();
    await tester.pump();
    expect(evaluationStarted.isCompleted, isTrue);

    final scriptsTooltip = AppLocalizations.of(
      tester.element(find.byType(BrowserPage)),
    )!
        .browserUserScripts;
    await tester.tap(find.byTooltip(scriptsTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    evaluationGate.complete();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(
      webView.controller.evaluatedScripts.where(
          (script) => script.contains('window.savedUserscriptRan = true;')),
      hasLength(1),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ambiguous same-URL error waits for active load completion',
      (tester) async {
    final previousPlatform = InAppWebViewPlatform.instance;
    final platform = _installBrowserPagePlatform();
    addTearDown(() => InAppWebViewPlatform.instance =
        previousPlatform ?? _BrowserPagePlatform());
    final controller = await _startNavigation(tester, platform);
    final webView = platform.webView!;

    // A repeated same-URL start makes the next error callback ambiguous: it
    // could belong to the earlier load or to this active one.
    webView.params.onLoadStart!(controller, WebUri('https://failed.example/'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    webView.params.onReceivedError!(
      controller,
      WebResourceRequest(
        url: WebUri('https://failed.example/'),
        isForMainFrame: true,
      ),
      WebResourceError(
        type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
        description: 'Could not connect to host',
      ),
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // The newer same-URL load advances and completes before the error grace
    // window expires, so the ambiguous error must not stop it early.
    webView.params.onProgressChanged!(controller, 25);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    webView.params.onLoadStop!(controller, WebUri('https://failed.example/'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('same-URL errors in reverse callback order keep one deadline',
      (tester) async {
    final previousPlatform = InAppWebViewPlatform.instance;
    final platform = _installBrowserPagePlatform();
    addTearDown(() => InAppWebViewPlatform.instance =
        previousPlatform ?? _BrowserPagePlatform());
    final controller = await _startNavigation(tester, platform);
    final webView = platform.webView!;
    webView.params.onLoadStart!(controller, WebUri('https://failed.example/'));
    await tester.pump();

    // Model the active request failing before the stale same-URL callback.
    webView.params.onReceivedError!(
      controller,
      WebResourceRequest(
        url: WebUri('https://failed.example/'),
        isForMainFrame: true,
      ),
      WebResourceError(
        type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
        description: 'Could not connect to host',
      ),
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // A later stale error cannot identify a different request and must not
    // extend the no-progress deadline by itself.
    webView.params.onReceivedError!(
      controller,
      WebResourceRequest(
        url: WebUri('https://failed.example/'),
        isForMainFrame: true,
      ),
      WebResourceError(
        type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
        description: 'Could not connect to host',
      ),
    );
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('regressing progress does not postpone the error timeout',
      (tester) async {
    final previousPlatform = InAppWebViewPlatform.instance;
    final platform = _installBrowserPagePlatform();
    addTearDown(() => InAppWebViewPlatform.instance =
        previousPlatform ?? _BrowserPagePlatform());
    final controller = await _startNavigation(tester, platform);
    final webView = platform.webView!;

    webView.params.onReceivedError!(
      controller,
      WebResourceRequest(
        url: WebUri('https://failed.example/'),
        isForMainFrame: true,
      ),
      WebResourceError(
        type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
        description: 'Could not connect to host',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    webView.params.onProgressChanged!(controller, 30);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // A decreasing progress callback is not evidence that the load advanced.
    webView.params.onProgressChanged!(controller, 20);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('subframe load error keeps the top-level indicator active',
      (tester) async {
    final previousPlatform = InAppWebViewPlatform.instance;
    final platform = _installBrowserPagePlatform();
    addTearDown(() => InAppWebViewPlatform.instance =
        previousPlatform ?? _BrowserPagePlatform());
    final controller = await _startNavigation(tester, platform);
    final webView = platform.webView!;

    webView.params.onReceivedError!(
      controller,
      WebResourceRequest(
        url: WebUri('https://failed.example/embedded-resource'),
        isForMainFrame: false,
      ),
      WebResourceError(
        type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
        description: 'Could not connect to embedded resource',
      ),
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('late error from a superseded navigation keeps the indicator',
      (tester) async {
    final previousPlatform = InAppWebViewPlatform.instance;
    final platform = _installBrowserPagePlatform();
    addTearDown(() => InAppWebViewPlatform.instance =
        previousPlatform ?? _BrowserPagePlatform());
    final controller = await _startNavigation(tester, platform);
    final webView = platform.webView!;
    webView.params.onLoadStart!(
      controller,
      WebUri('https://newer.example/'),
    );
    await tester.pump();

    webView.params.onReceivedError!(
      controller,
      WebResourceRequest(
        url: WebUri('https://failed.example/'),
        isForMainFrame: true,
      ),
      WebResourceError(
        type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
        description: 'Could not connect to host',
      ),
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('redirected main-frame HTTP error keeps progress until load stop',
      (tester) async {
    final previousPlatform = InAppWebViewPlatform.instance;
    final platform = _installBrowserPagePlatform();
    addTearDown(() => InAppWebViewPlatform.instance =
        previousPlatform ?? _BrowserPagePlatform());
    final controller = await _startNavigation(tester, platform);
    final webView = platform.webView!;
    const redirectUrl = 'https://redirected.example/missing';

    expect(webView.params.initialSettings?.useShouldOverrideUrlLoading, isTrue);
    final navigationPolicy = await webView.params.shouldOverrideUrlLoading!(
      controller,
      NavigationAction(
        request: URLRequest(url: WebUri(redirectUrl)),
        isForMainFrame: true,
        isRedirect: true,
      ),
    );
    expect(navigationPolicy, NavigationActionPolicy.ALLOW);

    webView.params.onReceivedHttpError!(
      controller,
      WebResourceRequest(
        url: WebUri(redirectUrl),
        isForMainFrame: true,
      ),
      WebResourceResponse(
        statusCode: 404,
        reasonPhrase: 'Not Found',
        headers: const {},
      ),
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    webView.params.onProgressChanged!(controller, 100);
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    webView.params.onLoadStop!(controller, WebUri(redirectUrl));
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('redirect cancels the prior URL error timeout', (tester) async {
    final previousPlatform = InAppWebViewPlatform.instance;
    final platform = _installBrowserPagePlatform();
    addTearDown(() => InAppWebViewPlatform.instance =
        previousPlatform ?? _BrowserPagePlatform());
    final controller = await _startNavigation(tester, platform);
    final webView = platform.webView!;
    const redirectUrl = 'https://redirected.example/final';

    webView.params.onReceivedError!(
      controller,
      WebResourceRequest(
        url: WebUri('https://failed.example/'),
        isForMainFrame: true,
      ),
      WebResourceError(
        type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
        description: 'Could not connect to host',
      ),
    );
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    final navigationPolicy = await webView.params.shouldOverrideUrlLoading!(
      controller,
      NavigationAction(
        request: URLRequest(url: WebUri(redirectUrl)),
        isForMainFrame: true,
        isRedirect: true,
      ),
    );
    expect(navigationPolicy, NavigationActionPolicy.ALLOW);
    await tester.pump();

    // The previous URL's pending error cannot end a redirected navigation.
    await tester.pump(const Duration(seconds: 6));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    webView.params.onLoadStart!(controller, WebUri(redirectUrl));
    await tester.pump();
    webView.params.onLoadStop!(controller, WebUri(redirectUrl));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

_BrowserPagePlatform _installBrowserPagePlatform() {
  final platform = _BrowserPagePlatform();
  InAppWebViewPlatform.instance = platform;
  return platform;
}

Future<InAppWebViewController> _startNavigation(
    WidgetTester tester, _BrowserPagePlatform platform,
    {Locale locale = const Locale('en', 'US')}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const BrowserPage(initialUrl: 'https://failed.example/'),
    ),
  );
  final webView = platform.webView!;
  final controller = webView
      .controllerFromPlatform<InAppWebViewController>(webView.controller);
  webView.params.onLoadStart!(controller, WebUri('https://failed.example/'));
  await tester.pump();
  return controller;
}

class _BrowserPagePlatform extends InAppWebViewPlatform {
  _BrowserPageWebView? webView;

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
          PlatformInAppWebViewWidgetCreationParams params) =>
      webView = _BrowserPageWebView(params);
}

class _BrowserPageWebView extends PlatformInAppWebViewWidget {
  final controller = _BrowserPageController();

  _BrowserPageWebView(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      params.controllerFromPlatform!(controller) as T;

  @override
  void dispose() {}
}

class _BrowserPageController extends PlatformInAppWebViewController {
  final evaluatedScripts = <String>[];
  Completer<void>? userScriptEvaluationStarted;
  Completer<void>? userScriptEvaluationGate;
  String? userScriptEvaluationMatch;

  _BrowserPageController()
      : super.implementation(
            const PlatformInAppWebViewControllerCreationParams(id: 0));

  @override
  Future<dynamic> evaluateJavascript(
      {required String source, ContentWorld? contentWorld}) async {
    evaluatedScripts.add(source);
    if (source.contains(
          userScriptEvaluationMatch ?? 'window.savedUserscriptRan = true;',
        ) &&
        userScriptEvaluationStarted != null &&
        !userScriptEvaluationStarted!.isCompleted) {
      userScriptEvaluationStarted!.complete();
      await userScriptEvaluationGate!.future;
    }
    return null;
  }

  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    Uri? iosAllowingReadAccessTo,
    WebUri? allowingReadAccessTo,
  }) async {}

  @override
  void addJavaScriptHandler(
      {required String handlerName,
      required JavaScriptHandlerCallback callback}) {}

  @override
  void dispose({bool isKeepAlive = false}) {}
}

class _DelayedPreferencesStore extends InMemorySharedPreferencesStore {
  _DelayedPreferencesStore(super.data, this.preferencesReady)
      : super.withData();

  final Completer<void> preferencesReady;

  @override
  Future<Map<String, Object>> getAll() async {
    await preferencesReady.future;
    return super.getAll();
  }
}
