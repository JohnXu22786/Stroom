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
