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
    'toolbar zoom controls continue from the JavaScript-fitted zoom '
    'without a transform handler',
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
      final platform = _ZoomTrackingWebViewPlatform();
      InAppWebViewPlatform.instance = platform;
      addTearDown(() => InAppWebViewPlatform.instance =
          previousPlatform ?? _ZoomTrackingWebViewPlatform());

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
        expect(platform.webView, isNull);
        delayedAsset.complete(assetBytes);
      }
      await tester.pump();
      await tester.pump();

      final webView = platform.webView!;
      final controller = webView.controllerFromPlatform<InAppWebViewController>(
        webView.controller,
      );
      webView.params.onWebViewCreated!(controller);
      webView.params.onLoadStop?.call(controller, null);
      await tester.pump();

      // Model web's unsupported bridge: JavaScript fit has changed the zoom,
      // but the dialog has not received that fitted value.
      webView.controller.simulateJsFitToViewport(0.45);

      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();

      expect(webView.controller.zoomLevel, closeTo(0.55, 0.0001));
      await tester.tap(find.byIcon(Icons.zoom_out));
      await tester.pump();
      expect(webView.controller.zoomLevel, closeTo(0.45, 0.0001));
      expect(
        webView.controller.evaluatedScripts,
        contains(predicate<String>((script) =>
            script.contains('window.applyZoomDeltasAfterFit([0.1])'))),
      );
      expect(
        webView.controller.evaluatedScripts,
        contains(predicate<String>((script) =>
            script.contains('window.applyZoomDeltasAfterFit([-0.1])'))),
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _ZoomTrackingWebViewPlatform extends InAppWebViewPlatform {
  _ZoomTrackingWebView? webView;

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) =>
      webView = _ZoomTrackingWebView(params);
}

class _ZoomTrackingWebView extends PlatformInAppWebViewWidget {
  final controller = _ZoomTrackingWebViewController();

  _ZoomTrackingWebView(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      params.controllerFromPlatform!(controller) as T;

  @override
  void dispose() {}
}

class _ZoomTrackingWebViewController extends PlatformInAppWebViewController {
  final evaluatedScripts = <String>[];
  double zoomLevel = 1.0;

  _ZoomTrackingWebViewController()
      : super.implementation(
            const PlatformInAppWebViewControllerCreationParams(id: 0));

  void simulateJsFitToViewport(double fittedZoom) {
    zoomLevel = fittedZoom;
  }

  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    Uri? iosAllowingReadAccessTo,
    WebUri? allowingReadAccessTo,
  }) async {}

  @override
  Future<void> loadData({
    required String data,
    String mimeType = 'text/html',
    String encoding = 'utf8',
    WebUri? baseUrl,
    Uri? androidHistoryUrl,
    WebUri? historyUrl,
    Uri? iosAllowingReadAccessTo,
    WebUri? allowingReadAccessTo,
  }) async {}

  @override
  void addJavaScriptHandler({
    required String handlerName,
    required JavaScriptHandlerCallback callback,
  }) =>
      throw UnimplementedError('JavaScript handlers are unavailable on web');

  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async {
    evaluatedScripts.add(source);
    final relativeZoom = RegExp(
      r'window\.applyZoomDeltasAfterFit\(\[(-?\d+(?:\.\d+)?)\]\)',
    ).firstMatch(source);
    if (relativeZoom != null) {
      final delta = double.parse(relativeZoom.group(1)!);
      zoomLevel = (zoomLevel + delta).clamp(0.1, 10.0).toDouble();
      return null;
    }

    final absoluteZoom =
        RegExp(r'window\.setZoom\((-?\d+(?:\.\d+)?),').firstMatch(source);
    if (absoluteZoom != null) {
      zoomLevel = double.parse(absoluteZoom.group(1)!);
    }
    return null;
  }
}
