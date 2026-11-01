import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stroom/pages/chat/message_view/dsh_message_view.dart';
import 'package:stroom/pages/chat/message_view/message_web_host.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native message document renders and applies message patches',
      (tester) async {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final probeEvents = <Map<String, dynamic>>[];
      final probeCommands = ValueNotifier<Map<String, dynamic>?>(null);
      print('DSH native smoke: macOS minimal document probe mounting');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MessageWebHost(
            html:
                '<!doctype html><script>window.StroomMessageView = {};</script>',
            commands: probeCommands,
            onEvent: probeEvents.add,
          ),
        ),
      ));
      for (var i = 0;
          i < 300 && !probeEvents.any((e) => e['type'] == 'ready');
          i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        probeEvents.any((e) => e['type'] == 'ready'),
        isTrue,
        reason:
            'A minimal local document must load before testing the DSH bundle',
      );
      print('DSH native smoke: macOS minimal document probe passed');
      await tester.pumpWidget(const SizedBox());
      probeCommands.dispose();
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
                    {'type': 'text', 'text': text}
                  ],
                  'actions': <String>[],
                }
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
          () => events
              .any((e) => e['type'] == 'searchResults' && e['query'] == query),
          'The native document must return search results for $query');
      return events.lastWhere((e) =>
              e['type'] == 'searchResults' && e['query'] == query)['matches']
          as List<dynamic>;
    }

    print('DSH native smoke: mounting DSH document');
    await tester.pumpWidget(
        render('**native smoke**\n\n```dart\nfinal value = 1;\n```'));
    print('DSH native smoke: DSH document mounted; waiting for ready bridge');
    await waitFor(() => events.any((e) => e['type'] == 'ready'),
        'The bundled document must initialize its real WebView bridge');
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
  }, timeout: const Timeout(Duration(minutes: 5)));
}
