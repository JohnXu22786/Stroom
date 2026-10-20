import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/dialogs/mermaid_preview_dialog.dart';
import 'package:stroom/widgets/mermaid_render_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'shows an error if the WebView never creates after it is eligible to mount',
    (tester) async {
      final delayedAsset = Completer<ByteData>();
      final assetBytes = ByteData.view(
        Uint8List.fromList(utf8.encode('var mermaid = {};')).buffer,
      );
      var assetLoadCount = 0;
      if (!kIsWeb) {
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMessageHandler('flutter/assets', (message) async {
          final assetKey = utf8.decode(
            message!.buffer.asUint8List(
              message.offsetInBytes,
              message.lengthInBytes,
            ),
          );
          if (assetKey != MermaidRenderWidget.bundledMermaidJsAsset) {
            return null;
          }
          assetLoadCount++;
          return delayedAsset.future;
        });
        addTearDown(() {
          messenger.setMockMessageHandler('flutter/assets', null);
        });
      }

      final previousPlatform = InAppWebViewPlatform.instance;
      final platform = _NeverCreatedWebViewPlatform();
      InAppWebViewPlatform.instance = platform;
      addTearDown(() {
        InAppWebViewPlatform.instance =
            previousPlatform ?? _NeverCreatedWebViewPlatform();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showMermaidPreviewDialog(
                context: context,
                mermaidCode: 'graph TD\nA-->B',
              ),
              child: const Text('Open preview'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open preview'));
      await tester.pump();

      if (!kIsWeb) {
        expect(assetLoadCount, 1);
        await tester.pump(const Duration(seconds: 4));

        expect(platform.webView, isNull);
        expect(find.text('加载失败'), findsNothing,
            reason: 'asset loading must not count as a WebView mount timeout');

        delayedAsset.complete(assetBytes);
        await tester.pump();
        await tester.pump();
      }

      expect(platform.webView, isNotNull);
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('加载失败'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'shows an error if a created web WebView never finishes navigation',
    (tester) async {
      final preview = await _openPreviewWithCreatedWebView(tester);

      expect(preview.webView.created, isTrue);
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('加载失败'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !kIsWeb,
  );

  testWidgets(
    'removes large source storage after asynchronous navigation failure',
    (tester) async {
      final code = 'graph TD\n${'A-->B\n' * 2000}';
      final preview = await _openPreviewWithCreatedWebView(
        tester,
        mermaidCode: code,
      );
      await tester.pump();

      final url = preview.webView.controller.loadedUrls.single;
      preview.webView.params.onReceivedError!(
        preview.controller,
        WebResourceRequest(url: url, isForMainFrame: true),
        WebResourceError(
          type: WebResourceErrorType.UNKNOWN,
          description: 'document request failed',
        ),
      );
      await tester.pump();

      final setScript = preview.webView.controller.evaluatedScripts.singleWhere(
        (script) => script.startsWith('window.sessionStorage.setItem('),
      );
      final removeScript =
          preview.webView.controller.evaluatedScripts.singleWhere(
        (script) => script.contains('window.sessionStorage.removeItem('),
      );
      String sourceKeyIn(String script) {
        return RegExp(r'"(mermaid-[^"]+)"').firstMatch(script)!.group(1)!;
      }

      expect(sourceKeyIn(removeScript), sourceKeyIn(setScript));
      expect(
        preview.webView.controller.storedSources,
        isNot(contains(sourceKeyIn(setScript))),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !kIsWeb,
  );

  testWidgets(
    'removes large source storage when web navigation times out',
    (tester) async {
      final preview = await _openPreviewWithCreatedWebView(
        tester,
        mermaidCode: 'graph TD\n${'A-->B\n' * 2000}',
      );
      await tester.pump(const Duration(seconds: 3));

      final setScript = preview.webView.controller.evaluatedScripts.singleWhere(
        (script) => script.startsWith('window.sessionStorage.setItem('),
      );
      final removeScript =
          preview.webView.controller.evaluatedScripts.singleWhere(
        (script) => script.contains('window.sessionStorage.removeItem('),
      );
      String sourceKeyIn(String script) {
        return RegExp(r'"(mermaid-[^"]+)"').firstMatch(script)!.group(1)!;
      }

      expect(sourceKeyIn(removeScript), sourceKeyIn(setScript));
      expect(
        preview.webView.controller.storedSources,
        isNot(contains(sourceKeyIn(setScript))),
      );
      expect(find.text('加载失败'), findsOneWidget);
      expect(tester.takeException(), isNull);
      preview.webView.params.onLoadStop!(
        preview.controller,
        preview.webView.controller.loadedUrls.single,
      );
      await tester.pump();
      expect(find.text('加载失败'), findsOneWidget,
          reason: 'a late load must not hide that its source was abandoned');
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !kIsWeb,
  );

  testWidgets(
    'removes unconsumed large source storage when the dialog is disposed',
    (tester) async {
      final preview = await _openPreviewWithCreatedWebView(
        tester,
        mermaidCode: 'graph TD\n${'A-->B\n' * 2000}',
      );
      await tester.pumpWidget(const SizedBox.shrink());

      final setScript = preview.webView.controller.evaluatedScripts.singleWhere(
        (script) => script.startsWith('window.sessionStorage.setItem('),
      );
      final removeScript =
          preview.webView.controller.evaluatedScripts.singleWhere(
        (script) => script.contains('window.sessionStorage.removeItem('),
      );
      String sourceKeyIn(String script) {
        return RegExp(r'"(mermaid-[^"]+)"').firstMatch(script)!.group(1)!;
      }

      expect(sourceKeyIn(removeScript), sourceKeyIn(setScript));
      expect(
        preview.webView.controller.storedSources,
        isNot(contains(sourceKeyIn(setScript))),
      );
      expect(tester.takeException(), isNull);
    },
    skip: !kIsWeb,
  );

  testWidgets(
    'shows an error and cleans up when large-source storage fails',
    (tester) async {
      final preview = await _openPreviewWithCreatedWebView(
        tester,
        mermaidCode: 'graph TD\n${'A-->B\n' * 2000}',
        evaluateJavascriptError: StateError('storage failed'),
      );

      expect(find.text('加载失败'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(preview.webView.controller.loadedUrls, isEmpty);
      expect(tester.takeException(), isNull);

      final setScript = preview.webView.controller.evaluatedScripts.singleWhere(
        (script) => script.startsWith('window.sessionStorage.setItem('),
      );
      final removeScript =
          preview.webView.controller.evaluatedScripts.singleWhere(
        (script) => script.contains('window.sessionStorage.removeItem('),
      );
      String sourceKeyIn(String script) {
        return RegExp(r'"(mermaid-[^"]+)"').firstMatch(script)!.group(1)!;
      }

      expect(sourceKeyIn(removeScript), sourceKeyIn(setScript));
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !kIsWeb,
  );

  testWidgets(
    'cancels the web navigation fallback when loading completes',
    (tester) async {
      final preview = await _openPreviewWithCreatedWebView(tester);
      preview.webView.params.onLoadStop!(preview.controller, null);
      await tester.pump();

      await tester.pump(const Duration(seconds: 3));

      expect(find.text('加载失败'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !kIsWeb,
  );

  testWidgets(
    'keeps a web main-frame error if load-stop follows the failure',
    (tester) async {
      final preview = await _openPreviewWithCreatedWebView(tester);
      preview.webView.params.onReceivedError!(
        preview.controller,
        WebResourceRequest(
          url: WebUri('https://example.com/diagram.html'),
          isForMainFrame: true,
        ),
        WebResourceError(
          type: WebResourceErrorType.UNKNOWN,
          description: 'document request failed',
        ),
      );
      await tester.pump();

      preview.webView.params.onLoadStop!(preview.controller, null);
      await tester.pump();

      expect(find.text('加载失败'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !kIsWeb,
  );

  testWidgets(
    'clears a web navigation timeout when loading later completes',
    (tester) async {
      final preview = await _openPreviewWithCreatedWebView(tester);
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('加载失败'), findsOneWidget);

      preview.webView.params.onLoadStop!(preview.controller, null);
      await tester.pump();

      expect(find.text('加载失败'), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !kIsWeb,
  );
}

Future<_CreatedWebPreviewHarness> _openPreviewWithCreatedWebView(
  WidgetTester tester, {
  String mermaidCode = 'graph TD\nA-->B',
  Object? evaluateJavascriptError,
}) async {
  final previousPlatform = InAppWebViewPlatform.instance;
  final platform = _CreatedWebViewPlatform();
  InAppWebViewPlatform.instance = platform;
  addTearDown(() {
    InAppWebViewPlatform.instance =
        previousPlatform ?? _CreatedWebViewPlatform();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showMermaidPreviewDialog(
            context: context,
            mermaidCode: mermaidCode,
          ),
          child: const Text('Open preview'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open preview'));
  await tester.pump();
  await tester.pump();

  final webView = platform.webView!;
  final controller = webView.controllerFromPlatform<InAppWebViewController>(
    webView.controller,
  );
  webView.controller.evaluateJavascriptError = evaluateJavascriptError;
  webView.params.onWebViewCreated!(controller);
  webView.created = true;
  await tester.pump();

  return _CreatedWebPreviewHarness(webView, controller);
}

class _CreatedWebPreviewHarness {
  final _CreatedWebView webView;
  final InAppWebViewController controller;

  const _CreatedWebPreviewHarness(this.webView, this.controller);
}

class _CreatedWebViewPlatform extends InAppWebViewPlatform {
  _CreatedWebView? webView;

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) =>
      webView = _CreatedWebView(params);
}

class _CreatedWebView extends PlatformInAppWebViewWidget {
  final controller = _CreatedWebViewController();
  bool created = false;

  _CreatedWebView(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      params.controllerFromPlatform!(controller) as T;

  @override
  void dispose() {}
}

class _CreatedWebViewController extends PlatformInAppWebViewController {
  final evaluatedScripts = <String>[];
  final loadedUrls = <WebUri>[];
  final storedSources = <String, String>{};
  Object? evaluateJavascriptError;

  _CreatedWebViewController()
      : super.implementation(
            const PlatformInAppWebViewControllerCreationParams(id: 0));

  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    Uri? iosAllowingReadAccessTo,
    WebUri? allowingReadAccessTo,
  }) async {
    final url = urlRequest.url;
    if (url != null) loadedUrls.add(url);
  }

  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async {
    evaluatedScripts.add(source);
    final error = evaluateJavascriptError;
    evaluateJavascriptError = null;
    if (error != null) throw error;
    final setMatch = RegExp(
      r'^window\.sessionStorage\.setItem\(("[^"]+"), (.+)\);$',
    ).firstMatch(source);
    if (setMatch != null) {
      storedSources[jsonDecode(setMatch.group(1)!) as String] =
          jsonDecode(setMatch.group(2)!) as String;
      return;
    }
    final cleanupKey = RegExp(r'const key = ("[^"]+");').firstMatch(source);
    if (cleanupKey != null && source.contains('sessionStorage.removeItem')) {
      final key = jsonDecode(cleanupKey.group(1)!) as String;
      final wasPending = storedSources.containsKey(key);
      storedSources.remove(key);
      return wasPending;
    }
    final removeMatch = RegExp(
      r'^window\.sessionStorage\.removeItem\(("[^"]+")\);$',
    ).firstMatch(source);
    if (removeMatch != null) {
      storedSources.remove(jsonDecode(removeMatch.group(1)!) as String);
    }
  }

  @override
  void addJavaScriptHandler({
    required String handlerName,
    required JavaScriptHandlerCallback callback,
  }) =>
      throw UnimplementedError('JavaScript handlers are unavailable on web');
}

class _NeverCreatedWebViewPlatform extends InAppWebViewPlatform {
  _NeverCreatedWebView? webView;

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) =>
      webView = _NeverCreatedWebView(params);
}

class _NeverCreatedWebView extends PlatformInAppWebViewWidget {
  _NeverCreatedWebView(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      params.controllerFromPlatform!(controller) as T;

  @override
  void dispose() {}
}
