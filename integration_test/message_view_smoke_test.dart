import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stroom/pages/chat/message_view/dsh_message_view.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native message document renders and applies message patches',
      (tester) async {
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

    await tester.pumpWidget(
        render('**native smoke**\n\n```dart\nfinal value = 1;\n```'));
    await waitFor(() => events.any((e) => e['type'] == 'ready'),
        'The bundled document must initialize its real WebView bridge');
    final matches = await search('native smoke');
    expect(matches, hasLength(1));
    expect(matches.single['messageId'], 'assistant-1');

    await tester.pumpWidget(render('**updated smoke**'));
    await tester.pump();
    expect(await search('native smoke'), isEmpty);
    final updated = await search('updated smoke');
    expect(updated, hasLength(1));
    expect(updated.single['messageId'], 'assistant-1');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 2)));
}
