import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/mermaid_render_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'delayed asset loading does not consume the WebView creation fallback',
    (tester) async {
      final assetBytes = ByteData.view(
        Uint8List.fromList(utf8.encode('var mermaid = {};')).buffer,
      );
      final delayedAsset = Completer<ByteData>();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var assetLoadCount = 0;
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

      final previousPlatform = InAppWebViewPlatform.instance;
      final platform = _DelayedAssetWebViewPlatform();
      InAppWebViewPlatform.instance = platform;
      addTearDown(() {
        InAppWebViewPlatform.instance =
            previousPlatform ?? _DelayedAssetWebViewPlatform();
      });

      const creationError = '图表渲染引擎初始化失败，请重试';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MermaidRenderWidget(mermaidCode: 'graph TD\nA-->B'),
          ),
        ),
      );
      final bundledLoad = MermaidRenderWidget.loadBundledMermaidJs();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 12));

      delayedAsset.complete(assetBytes);
      expect(await bundledLoad, isNotNull);
      await tester.pump();

      expect(assetLoadCount, 1);
      expect(platform.webView, isNotNull);
      expect(
        find.text(creationError),
        findsNothing,
        reason:
            'the asset delay must not leave a stale timeout over the diagram',
      );

      await tester.pump(const Duration(seconds: 12));
      expect(
        find.text(creationError),
        findsOneWidget,
        reason: 'the fallback must still report a WebView that never mounts',
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _DelayedAssetWebViewPlatform extends InAppWebViewPlatform {
  _DelayedAssetWebView? webView;

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) => webView = _DelayedAssetWebView(params);
}

class _DelayedAssetWebView extends PlatformInAppWebViewWidget {
  _DelayedAssetWebView(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      params.controllerFromPlatform!(controller) as T;

  @override
  void dispose() {}
}
