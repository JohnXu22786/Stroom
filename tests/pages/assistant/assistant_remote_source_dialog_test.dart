import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/pages/assistant/assistant_remote_source_dialog.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/services/assistant_catalog_service.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('measures the catalog URL hint in the production dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            inputDecorationTheme: InputDecorationTheme(
              hintStyle: WidgetStateTextStyle.resolveWith((states) {
                return TextStyle(
                  color: states.contains(WidgetState.focused)
                      ? Colors.red
                      : Colors.blue,
                );
              }),
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => showAssistantRemoteSourceDialog(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    const hint = 'https://…/catalog.json';
    final hintFinder = find.byWidgetPredicate(
      (widget) => widget is ConstrainedText && widget.data == hint,
    );
    expect(hintFinder, findsOneWidget);
    final hintWidget = tester.widget<ConstrainedText>(hintFinder);
    final hintContext = tester.element(hintFinder);
    final naturalHint = TextPainter(
      text: TextSpan(text: hint, style: hintWidget.style),
      textDirection: Directionality.of(hintContext),
      textScaler: MediaQuery.textScalerOf(hintContext),
    )..layout();
    final hintSlot = tester.getSize(find.byType(ConstrainedInputHint));
    expect(naturalHint.width, greaterThan(hintSlot.width));
    debugPrint(
      'assistant catalog hint=$hint slot=$hintSlot '
      'intrinsicWidth=${naturalHint.width}',
    );

    final field = find.byType(TextField).first;
    final semantics = tester.ensureSemantics();
    final editable = find.descendant(
      of: field,
      matching: find.byType(EditableText),
    );
    expect(tester.getSemantics(editable).getSemanticsData().hint, hint);
    expect(
        tester.widget<ConstrainedText>(hintFinder).style!.color, Colors.blue);
    await tester.tap(field);
    await tester.pump();
    expect(tester.widget<ConstrainedText>(hintFinder).style!.color, Colors.red);
    await tester.enterText(field, 'https://example.test/catalog.json');
    await tester.pump();
    expect(tester.getSemantics(editable).getSemanticsData().hint, hint);
    expect(
      tester
          .widget<EditableText>(find.descendant(
            of: field,
            matching: find.byType(EditableText),
          ))
          .controller
          .text,
      'https://example.test/catalog.json',
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
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
                  serviceFactory: () => AssistantCatalogService.testing(
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
                    addressLookup: _publicAddressLookup,
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => showAssistantRemoteSourceDialog(
                  context,
                  ref,
                  serviceFactory: () => AssistantCatalogService.testing(
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
                    addressLookup: _publicAddressLookup,
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

  testWidgets('persists remote model identity and tool defaults on import', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        providerEntriesProvider.overrideWith(
          (ref) => _ProviderEntriesNotifier(
            ProviderEntriesState(
              entries: [
                ProviderEntry(
                  type: 'llm',
                  name: 'LLM providers',
                  configs: [
                    ProviderConfigItem(
                      providerName: 'Provider A',
                      host: 'https://api.example.test',
                      key: 'test-key',
                      models: [
                        ModelConfig(
                          name: 'Friendly Model',
                          modelId: 'model-xyz',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(assistantProvider.notifier).ready;
    const assistantJson = '''
{
  "schemaVersion": 1,
  "id": "stroom.remote-defaults",
  "name": "Remote defaults",
  "version": "1.0.0",
  "prompt": "Use the supplied defaults.",
  "defaultModelId": "model-xyz",
  "defaultModelName": "Friendly Model",
  "defaultProviderName": "Provider A",
  "defaultToolNames": ["web_search"]
}
''';

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => showAssistantRemoteSourceDialog(
                  context,
                  ref,
                  serviceFactory: () => AssistantCatalogService.testing(
                    client: MockClient(
                      (request) async => http.Response.bytes(
                        utf8.encode(assistantJson),
                        200,
                        request: request,
                      ),
                    ),
                    addressLookup: _publicAddressLookup,
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
    await tester.pumpAndSettle();
    expect(
      container
          .read(assistantProvider)
          .where(
            (assistant) =>
                assistant.remoteAssistantId == 'stroom.remote-defaults',
          ),
      hasLength(1),
    );
    final preferences = await SharedPreferences.getInstance();
    final savedRows = jsonDecode(preferences.getString('assistants')!) as List;
    final savedAssistant = Assistant.fromMap(
      Map<String, dynamic>.from(
        savedRows.cast<Map>().firstWhere(
          (row) => row['remoteAssistantId'] == 'stroom.remote-defaults',
        ),
      ),
    );
    expect(savedAssistant.defaultModelName, 'Friendly Model | Provider A');
    expect(savedAssistant.defaultModelId, 'model-xyz');
    expect(savedAssistant.defaultProviderName, 'Provider A');
    expect(savedAssistant.defaultToolNames, {'web_search'});
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
                  serviceFactory: () => AssistantCatalogService.testing(
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
                    addressLookup: _publicAddressLookup,
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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

Future<List<String>> _publicAddressLookup(String _) async =>
    const ['93.184.216.34'];

class _ProviderEntriesNotifier extends ProviderEntriesNotifier {
  _ProviderEntriesNotifier(ProviderEntriesState initialState) {
    state = initialState;
  }
}
