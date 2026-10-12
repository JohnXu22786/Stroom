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
    'queues zoom tapped before WebView creation until the page is ready',
    (tester) async {
      final preview = await _openPreviewWithEarlyControls(tester);

      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();
      expect(preview.webView.controller.evaluatedScripts, isEmpty);

      preview.webView.params.onWebViewCreated!(preview.controller);
      await tester.pump();
      preview.webView.controller.simulateJsFitToViewport(0.45);
      expect(preview.webView.controller.evaluatedScripts, isEmpty);

      preview.webView.params.onLoadStop!(preview.controller, null);
      await tester.pump();

      expect(preview.webView.controller.evaluatedScripts, [
        'window.applyZoomDeltasAfterFit([0.1])',
      ]);
      expect(preview.webView.controller.zoomLevel, closeTo(0.55, 0.0001));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'queues zoom tapped before onLoadStop until the page is ready',
    (tester) async {
      final preview = await _openPreviewWithEarlyControls(tester);
      preview.webView.params.onWebViewCreated!(preview.controller);
      await tester.pump();
      preview.webView.controller.simulateJsFitToViewport(0.45);

      await tester.tap(find.byIcon(Icons.zoom_out));
      await tester.pump();
      expect(preview.webView.controller.evaluatedScripts, isEmpty);

      await tester.pump(const Duration(seconds: 3));
      expect(preview.webView.controller.evaluatedScripts, isEmpty);

      preview.webView.params.onLoadStop!(preview.controller, null);
      await tester.pump();

      expect(preview.webView.controller.evaluatedScripts, [
        'window.applyZoomDeltasAfterFit([-0.1])',
      ]);
      expect(preview.webView.controller.zoomLevel, closeTo(0.35, 0.0001));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'rechecks queued zoom when WebView creation follows its timeout',
    (tester) async {
      final preview = await _openPreviewWithEarlyControls(tester);

      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();
      expect(preview.webView.controller.evaluatedScripts, isEmpty);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(preview.webView.controller.evaluatedScripts, isEmpty);

      preview.webView.controller.zoomHelperAvailable = true;
      preview.webView.params.onWebViewCreated!(preview.controller);
      await tester.pump();

      expect(preview.webView.controller.evaluatedScripts, [
        'window.applyZoomDeltasAfterFit([0.1])',
      ]);
      expect(preview.webView.controller.zoomLevel, closeTo(1.1, 0.0001));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'does not drop deltas at a stale native zoom cache boundary',
    (tester) async {
      final preview = await _openPreviewWithEarlyControls(tester);
      preview.webView.params.onWebViewCreated!(preview.controller);
      await tester.pump();
      preview.webView.controller.simulateJsFitToViewport(2.0);
      preview.webView.controller.zoomHelperAvailable = true;

      for (var i = 0; i < 10; i++) {
        await tester.tap(find.byIcon(Icons.zoom_out));
        await tester.pump();
      }
      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();
      expect(preview.webView.controller.evaluatedScripts, [
        ...List<String>.filled(
          10,
          'window.applyZoomDeltasAfterFit([-0.1])',
        ),
        'window.applyZoomDeltasAfterFit([0.1])',
      ]);
      expect(preview.webView.controller.zoomLevel, closeTo(1.1, 0.0001));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'keeps queued zoom commands until the helper appears after the fallback',
    (tester) async {
      final preview = await _openPreviewWithEarlyControls(tester);

      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();
      expect(preview.webView.controller.evaluatedScripts, isEmpty);

      preview.webView.params.onWebViewCreated!(preview.controller);
      await tester.pump();
      preview.webView.controller.simulateJsFitToViewport(0.45);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(preview.webView.controller.evaluatedScripts, isEmpty);

      await tester.tap(find.byIcon(Icons.zoom_out));
      await tester.pump();
      expect(preview.webView.controller.evaluatedScripts, isEmpty);

      preview.webView.controller.zoomHelperAvailable = true;
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(preview.webView.controller.evaluatedScripts, [
        'window.applyZoomDeltasAfterFit([0.1,-0.1])',
      ]);
      expect(preview.webView.controller.zoomLevel, closeTo(0.45, 0.0001));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'retries readiness when another tap arrives during a pending probe',
    (tester) async {
      final preview = await _openPreviewWithEarlyControls(tester);
      final controller = preview.webView.controller;
      final pendingProbe = Completer<bool>();
      controller.nextReadinessProbe = pendingProbe;
      preview.webView.params.onWebViewCreated!(preview.controller);
      await tester.pump();
      controller.simulateJsFitToViewport(0.45);

      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();
      expect(controller.evaluatedScripts, isEmpty);

      controller.zoomHelperAvailable = true;
      await tester.tap(find.byIcon(Icons.zoom_out));
      await tester.pump();
      expect(controller.evaluatedScripts, isEmpty);

      pendingProbe.complete(false);
      await tester.pump();
      await tester.pump();

      expect(controller.evaluatedScripts, [
        'window.applyZoomDeltasAfterFit([0.1,-0.1])',
      ]);
      expect(controller.zoomLevel, closeTo(0.45, 0.0001));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'retains queued zoom when JavaScript evaluation fails before retry',
    (tester) async {
      final preview = await _openPreviewWithEarlyControls(tester);
      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();

      preview.webView.controller.zoomHelperAvailable = true;
      preview.webView.controller.failNextZoomEvaluation = true;
      preview.webView.params.onWebViewCreated!(preview.controller);
      await tester.pump();
      preview.webView.controller.simulateJsFitToViewport(0.45);

      expect(preview.webView.controller.evaluatedScripts, [
        'window.applyZoomDeltasAfterFit([0.1])',
      ]);
      expect(preview.webView.controller.zoomLevel, closeTo(0.45, 0.0001));

      preview.webView.params.onLoadStop!(preview.controller, null);
      await tester.pump();
      expect(preview.webView.controller.evaluatedScripts, [
        'window.applyZoomDeltasAfterFit([0.1])',
        'window.applyZoomDeltasAfterFit([0.1])',
      ]);
      expect(preview.webView.controller.zoomLevel, closeTo(0.55, 0.0001));

      await tester.pump(const Duration(milliseconds: 500));
      expect(preview.webView.controller.zoomLevel, closeTo(0.55, 0.0001));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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

Future<_WebPreviewHarness> _openPreviewWithEarlyControls(
  WidgetTester tester,
) async {
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
            showControlsBeforeWebViewReadyForTesting: true,
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
  return _WebPreviewHarness(webView, controller);
}

class _WebPreviewHarness {
  final _ZoomTrackingWebView webView;
  final InAppWebViewController controller;

  const _WebPreviewHarness(this.webView, this.controller);
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
  bool zoomHelperAvailable = false;
  bool failNextZoomEvaluation = false;
  Completer<bool>? nextReadinessProbe;

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
    if (source == "typeof window.applyZoomDeltasAfterFit === 'function'") {
      final pendingProbe = nextReadinessProbe;
      nextReadinessProbe = null;
      if (pendingProbe != null) return pendingProbe.future;
      return zoomHelperAvailable;
    }

    evaluatedScripts.add(source);
    final relativeZoom = RegExp(
      r'window\.applyZoomDeltasAfterFit\((\[.*\])\)',
    ).firstMatch(source);
    if (relativeZoom != null) {
      if (failNextZoomEvaluation) {
        failNextZoomEvaluation = false;
        throw StateError('Simulated JavaScript evaluation failure');
      }
      final deltas = (jsonDecode(relativeZoom.group(1)!) as List).cast<num>();
      for (final delta in deltas) {
        zoomLevel = (zoomLevel + delta).clamp(0.1, 10.0).toDouble();
      }
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
