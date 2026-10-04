import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/browser_page.dart';
import 'package:stroom/services/browser_cookie_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BrowserCookieService.enableTestMode();
  });

  tearDown(BrowserCookieService.disableTestMode);

  testWidgets('main-frame load error clears the loading indicator',
      (tester) async {
    final previousPlatform = InAppWebViewPlatform.instance;
    final platform = _installBrowserPagePlatform();
    addTearDown(() => InAppWebViewPlatform.instance =
        previousPlatform ?? _BrowserPagePlatform());
    final controller = await _startNavigation(tester, platform);
    final webView = platform.webView!;

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

  testWidgets('redirected main-frame HTTP error clears the loading indicator',
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
  WidgetTester tester,
  _BrowserPagePlatform platform,
) async {
  await tester.pumpWidget(
    const MaterialApp(home: BrowserPage(initialUrl: 'https://failed.example/')),
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
  _BrowserPageController()
      : super.implementation(
            const PlatformInAppWebViewControllerCreationParams(id: 0));

  @override
  Future<dynamic> evaluateJavascript(
          {required String source, ContentWorld? contentWorld}) async =>
      null;

  @override
  void addJavaScriptHandler(
      {required String handlerName,
      required JavaScriptHandlerCallback callback}) {}

  @override
  void dispose({bool isKeepAlive = false}) {}
}
