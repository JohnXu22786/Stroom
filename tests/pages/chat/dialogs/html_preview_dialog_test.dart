import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/chat/dialogs/html_preview_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a failed subresource does not cover the preview with an error', (
    tester,
  ) async {
    final preview = await _openPreview(tester);

    preview.webView.params.onLoadStop!(
      preview.controller,
      WebUri('about:blank'),
    );
    await tester.pump();
    preview.webView.params.onReceivedError!(
      preview.controller,
      WebResourceRequest(
        url: WebUri('https://cdn.example/image.png'),
        isForMainFrame: false,
      ),
      WebResourceError(
        type: WebResourceErrorType.UNKNOWN,
        description: 'resource failed',
      ),
    );
    await tester.pump();

    expect(find.text('Preview failed to load'), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed main-frame load shows the preview error', (
    tester,
  ) async {
    final preview = await _openPreview(tester);

    preview.webView.params.onReceivedError!(
      preview.controller,
      WebResourceRequest(
        url: WebUri('https://example.com/document.html'),
        isForMainFrame: true,
      ),
      WebResourceError(
        type: WebResourceErrorType.UNKNOWN,
        description: 'document failed',
      ),
    );
    await tester.pump();

    expect(find.text('Preview failed to load'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<_PreviewHarness> _openPreview(WidgetTester tester) async {
  final previousPlatform = InAppWebViewPlatform.instance;
  final platform = _PreviewPlatform();
  InAppWebViewPlatform.instance = platform;
  addTearDown(
    () =>
        InAppWebViewPlatform.instance = previousPlatform ?? _PreviewPlatform(),
  );

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en', 'US'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showHtmlPreviewDialog(
            context: context,
            htmlCode: '<p>Preview</p>',
          ),
          child: const Text('Open preview'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open preview'));
  await tester.pump();

  final webView = platform.webView!;
  final controller = webView.controllerFromPlatform<InAppWebViewController>(
    webView.controller,
  );
  webView.params.onWebViewCreated!(controller);
  await tester.pump();
  return _PreviewHarness(webView, controller);
}

class _PreviewHarness {
  final _PreviewWebView webView;
  final InAppWebViewController controller;

  const _PreviewHarness(this.webView, this.controller);
}

class _PreviewPlatform extends InAppWebViewPlatform {
  _PreviewWebView? webView;

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) => webView = _PreviewWebView(params);
}

class _PreviewWebView extends PlatformInAppWebViewWidget {
  final _PreviewController controller = _PreviewController();

  _PreviewWebView(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      params.controllerFromPlatform!(controller) as T;

  @override
  void dispose() {}
}

class _PreviewController extends PlatformInAppWebViewController {
  _PreviewController()
    : super.implementation(
        const PlatformInAppWebViewControllerCreationParams(id: 0),
      );

  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    Uri? iosAllowingReadAccessTo,
    WebUri? allowingReadAccessTo,
  }) async {}

  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async => null;

  @override
  void addJavaScriptHandler({
    required String handlerName,
    required JavaScriptHandlerCallback callback,
  }) {}

  @override
  void dispose({bool isKeepAlive = false}) {}
}
