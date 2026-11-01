import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stroom/pages/chat/message_view/dsh_message_view.dart';
import 'package:stroom/pages/chat/message_view/message_web_host.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native message document renders and applies message patches',
    (tester) async {
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final probeEvents = <Map<String, dynamic>>[];
        final probeCommands = ValueNotifier<Map<String, dynamic>?>(null);
        debugPrint('DSH native smoke: macOS minimal document probe mounting');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageWebHost(
                html: '''<!doctype html>
<script>
window.StroomMessageView = {};
let bridgeAnnounced = false;
function announceBridgeReady() {
  if (bridgeAnnounced) return true;
  const bridge = window.flutter_inappwebview;
  if (!bridge || typeof bridge.callHandler !== "function") return false;
  bridgeAnnounced = true;
  bridge.callHandler("StroomMessageView", { type: "ready" });
  bridge.callHandler("StroomMessageView", {
    type: "probeBridge",
    marker: "macos-local-document"
  });
  return true;
}
window.addEventListener("flutterInAppWebViewPlatformReady", announceBridgeReady);
const probeTimer = setInterval(() => {
  if (announceBridgeReady()) clearInterval(probeTimer);
}, 25);
</script>''',
                commands: probeCommands,
                onEvent: probeEvents.add,
              ),
            ),
          ),
        );
        bool bridgeReady() =>
            probeEvents.any((e) => e['type'] == 'ready') &&
            probeEvents.any(
              (e) =>
                  e['type'] == 'probeBridge' &&
                  e['marker'] == 'macos-local-document',
            );
        for (var i = 0; i < 300 && !bridgeReady(); i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          probeEvents.any((e) => e['type'] == 'ready'),
          isTrue,
          reason:
              'A minimal local document must load before testing the DSH bundle',
        );
        expect(
          probeEvents.any(
            (e) =>
                e['type'] == 'probeBridge' &&
                e['marker'] == 'macos-local-document',
          ),
          isTrue,
          reason: 'The macOS document must call through the JavaScript bridge',
        );
        debugPrint('DSH native smoke: macOS minimal document probe passed');
        await tester.pumpWidget(const SizedBox());
        probeCommands.dispose();
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        final bridgeEvents = <dynamic>[];
        dynamic recordBridgeEvent(JavaScriptHandlerFunctionData data) =>
            bridgeEvents.add(data.args.single);
        debugPrint('DSH native smoke: Android minimal WebView bridge probe');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InAppWebView(
                initialData: InAppWebViewInitialData(
                  data: '<!doctype html><html><body>bridge probe</body></html>',
                  baseUrl: WebUri(
                    'file:///assets/vendor/dsh_message_view/index.html',
                  ),
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  javaScriptHandlersForMainFrameOnly: true,
                ),
                onWebViewCreated: (controller) {
                  controller.addJavaScriptHandler(
                    handlerName: 'StroomMessageView',
                    callback: recordBridgeEvent,
                  );
                },
                onLoadStop: (controller, url) async {
                  await controller.evaluateJavascript(
                    source: '''window.flutter_inappwebview.callHandler(
                  "StroomMessageView", {type: "probeBridge"}
                )''',
                  );
                },
              ),
            ),
          ),
        );
        for (var i = 0; i < 300 && bridgeEvents.isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          bridgeEvents,
          isNotEmpty,
          reason:
              'Android WebView must load a minimal document and call its bridge',
        );
        debugPrint('DSH native smoke: Android minimal bridge probe passed');
        await tester.pumpWidget(const SizedBox());
      }

      final key = GlobalKey<DshMessageViewState>();
      final events = <Map<String, dynamic>>[];

      Widget render(String text) => MaterialApp(
            home: Scaffold(
              body: DshMessageView(
                key: key,
                conversationId: 'native-smoke',
                messages: [
                  {
                    'id': 'assistant-1',
                    'role': 'assistant',
                    'blocks': [
                      {'type': 'text', 'text': text},
                    ],
                    'actions': <String>[],
                  },
                ],
                theme: const {'dark': false, 'fontSize': 16},
                hasOlder: false,
                onEvent: events.add,
              ),
            ),
          );

      Future<void> waitFor(bool Function() ready, String reason) async {
        for (var i = 0; i < 300 && !ready(); i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(ready(), isTrue, reason: reason);
      }

      Future<List<dynamic>> search(String query) async {
        events.clear();
        key.currentState!.send({'type': 'search', 'query': query});
        await waitFor(
          () => events.any(
            (e) => e['type'] == 'searchResults' && e['query'] == query,
          ),
          'The native document must return search results for $query',
        );
        return events.lastWhere(
          (e) => e['type'] == 'searchResults' && e['query'] == query,
        )['matches'] as List<dynamic>;
      }

      debugPrint('DSH native smoke: mounting DSH document');
      await tester.pumpWidget(
        render('**native smoke**\n\n```dart\nfinal value = 1;\n```'),
      );
      debugPrint(
        'DSH native smoke: DSH document mounted; waiting for ready bridge',
      );
      await waitFor(
        () => events.any((e) => e['type'] == 'ready'),
        'The bundled document must initialize its real WebView bridge',
      );
      debugPrint('DSH native smoke: document ready');
      final matches = await search('native smoke');
      expect(matches, hasLength(1));
      expect(matches.single['messageId'], 'assistant-1');
      debugPrint('DSH native smoke: initial Markdown search passed');

      await tester.pumpWidget(render('**updated smoke**'));
      await tester.pump();
      expect(await search('native smoke'), isEmpty);
      final updated = await search('updated smoke');
      expect(updated, hasLength(1));
      expect(updated.single['messageId'], 'assistant-1');
      debugPrint('DSH native smoke: message patch search passed');
      expect(tester.takeException(), isNull);
      debugPrint('DSH native smoke: disposing document');
      await tester.pumpWidget(const SizedBox());
      debugPrint('DSH native smoke: document disposed');
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
