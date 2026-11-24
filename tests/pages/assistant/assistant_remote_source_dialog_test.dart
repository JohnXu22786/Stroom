import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/assistant/assistant_remote_source_dialog.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/services/assistant_catalog_service.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('discards a catalog response after its URL changes', (
    tester,
  ) async {
    final firstResponse = Completer<http.Response>();
    final firstRequestStarted = Completer<void>();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => showAssistantRemoteSourceDialog(
                  context,
                  ref,
                  serviceFactory: () => AssistantCatalogService(
                    client: MockClient((request) {
                      if (request.url.host == 'first.example.com') {
                        if (!firstRequestStarted.isCompleted) {
                          firstRequestStarted.complete();
                        }
                        return firstResponse.future;
                      }
                      return Future.value(
                        http.Response(
                          jsonEncode({
                            'schemaVersion': 1,
                            'catalogId': 'second-catalog',
                            'assistants': [],
                          }),
                          200,
                          request: request,
                        ),
                      );
                    }),
                  ),
                ),
                child: const Text('open remote source'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open remote source'));
    await tester.pumpAndSettle();
    final urlField = find.byType(TextField).first;
    await tester.enterText(urlField, 'https://first.example.com/catalog.json');
    await tester.pump();
    await tester.tap(find.text('Load catalog'));
    await tester.pump();
    expect(firstRequestStarted.isCompleted, isTrue);

    await tester.enterText(urlField, 'https://second.example.com/catalog.json');
    firstResponse.complete(
      http.Response(
        jsonEncode({
          'schemaVersion': 1,
          'catalogId': 'first-catalog',
          'assistants': [],
        }),
        200,
      ),
    );
    await tester.pump();

    expect(find.text('Catalog: first-catalog'), findsNothing);
    await tester.tap(find.text('Load catalog'));
    await tester.pumpAndSettle();
    expect(find.text('Catalog: second-catalog'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('continues import when schema info covers the dialog', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(assistantProvider.notifier).ready;
    final assistantsBefore = container.read(assistantProvider).length;
    final downloadCompleted = Completer<void>();
    final downloadStarted = Completer<void>();
    const assistantJson = '''
{
  "schemaVersion": 1,
  "id": "stroom.covered-import",
  "name": "Covered assistant",
  "description": "Should still be imported",
  "emoji": "🤖",
  "version": "1.0.0",
  "prompt": "Be helpful."
}
''';

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => showAssistantRemoteSourceDialog(
                  context,
                  ref,
                  serviceFactory: () => AssistantCatalogService(
                    client: MockClient((request) async {
                      if (!downloadStarted.isCompleted) {
                        downloadStarted.complete();
                      }
                      await downloadCompleted.future;
                      return http.Response.bytes(
                        utf8.encode(assistantJson),
                        200,
                        request: request,
                      );
                    }),
                  ),
                ),
                child: const Text('open remote source'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open remote source'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'https://example.com/assistant.json',
    );
    await tester.pump();
    await tester.tap(find.text('Import file'));
    await tester.pump();
    expect(downloadStarted.isCompleted, isTrue);

    await tester.tap(find.byTooltip('Parameter reference'));
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('Remote assistant schema'), findsOneWidget);

    downloadCompleted.complete();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(container.read(assistantProvider), hasLength(assistantsBefore + 1));
    expect(find.text('Remote assistant schema'), findsNothing);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('does not import after the dialog is dismissed during download', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(assistantProvider.notifier).ready;
    final assistantsBefore = container
        .read(assistantProvider)
        .map((assistant) => assistant.toMap())
        .toList();
    final downloadCompleted = Completer<void>();
    final downloadStarted = Completer<void>();
    const assistantJson = '''
{
  "schemaVersion": 1,
  "id": "stroom.cancelled-import",
  "name": "Cancelled assistant",
  "description": "Should not be imported",
  "emoji": "🤖",
  "version": "1.0.0",
  "prompt": "Be helpful."
}
''';

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => showAssistantRemoteSourceDialog(
                  context,
                  ref,
                  serviceFactory: () => AssistantCatalogService(
                    client: MockClient((request) async {
                      if (!downloadStarted.isCompleted) {
                        downloadStarted.complete();
                      }
                      await downloadCompleted.future;
                      return http.Response.bytes(
                        utf8.encode(assistantJson),
                        200,
                        request: request,
                      );
                    }),
                  ),
                ),
                child: const Text('open remote source'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open remote source'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'https://example.com/assistant.json',
    );
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'https://example.com/assistant.json',
    );
    final importButton = find.ancestor(
      of: find.text('Import file'),
      matching: find.byType(TextButton),
    );
    expect(tester.widget<TextButton>(importButton).onPressed, isNotNull);
    await tester.tap(find.text('Import file'));
    await tester.pump();
    expect(downloadStarted.isCompleted, isTrue);

    await tester.tapAt(const Offset(5, 5));
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.byType(AlertDialog), findsOneWidget);

    downloadCompleted.complete();
    await tester.pump(const Duration(milliseconds: 10));

    expect(
      container
          .read(assistantProvider)
          .map((assistant) => assistant.toMap())
          .toList(),
      assistantsBefore,
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('shows URL entry, update policy, safety option, and schema info',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => showAssistantRemoteSourceDialog(
                  context,
                  ref,
                ),
                child: const Text('open remote source'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open remote source'));
    await tester.pumpAndSettle();

    expect(find.text('Connect remote assistants'), findsOneWidget);
    expect(find.text('Automatic updates'), findsOneWidget);
    expect(find.text('Review with the built-in safety agent'), findsOneWidget);
    expect(find.byTooltip('Parameter reference'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(2));

    final urlField = find.byType(TextField).first;
    final urlInput = tester.widget<TextField>(urlField);
    expect(urlInput.decoration!.label, isA<ConstrainedText>());
    await tester.tap(urlField);
    await tester.enterText(urlField, 'https://example.test/assistant.yaml');
    await tester.pump();
    expect(urlInput.controller!.text, 'https://example.test/assistant.yaml');
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
    expect(tester.testTextInput.hasAnyClients, isTrue);

    await tester.tap(find.byTooltip('Parameter reference'));
    await tester.pumpAndSettle();
    expect(find.text('Remote assistant schema'), findsOneWidget);
    expect(find.text('Catalog manifest fields'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining(
        'stroom-json-v1 / stroom-yaml-v1 / stroom-markdown-yaml-v1',
      ),
      260,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.textContaining(
        'stroom-json-v1 / stroom-yaml-v1 / stroom-markdown-yaml-v1',
      ),
      findsOneWidget,
    );
  });
}
