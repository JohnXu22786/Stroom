import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/unified_task_list/synthesis_task_card.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider.dart';

const _error =
    'The request could not be completed because the upstream speech service returned an invalid response after the connection timed out. Please check the configured endpoint and model settings, then retry the task. Diagnostic reference: req_7f31a9c2.';

Future<void> _pumpFailedCard(
  WidgetTester tester,
  double width, {
  double textScale = 1,
  bool darkMode = false,
  String taskText = 'Sample synthesis request.',
  bool settle = true,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final task = SynthesisTask(
    id: 'failed-synthesis',
    title: 'Long meeting notes recording',
    status: TaskStatus.failed,
    error: _error,
    createdAt: DateTime(2026, 11, 15, 8, 56),
    completedAt: DateTime(2026, 11, 15, 9),
    text: taskText,
    providerConfig: ProviderConfigItem(providerName: 'Example Provider'),
    modelConfig: ModelConfig(name: 'Example Voice', modelId: 'voice-v2'),
    originalRequest: '{"model":"voice-v2"}',
    originalResponse: '{"error":"invalid response after timeout"}',
  );

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 844),
            devicePixelRatio: 1,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: ListView(children: [SynthesisTaskCard(task: task)]),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  testWidgets('very narrow phone keeps failed task header readable', (
    tester,
  ) async {
    await _pumpFailedCard(tester, 280);
    expect(tester.takeException(), isNull);

    final title = tester.getSize(find.text('Long meeting notes recording'));
    final metadata = tester.getSize(find.byType(Wrap).first);

    expect(title.width, greaterThan(120));
    expect(metadata.height, lessThan(48));
  });

  testWidgets('phone wraps the task title without hiding failed task actions', (
    tester,
  ) async {
    await _pumpFailedCard(tester, 390);
    expect(tester.takeException(), isNull);

    final title = find.text('Long meeting notes recording');
    expect(tester.getSize(title).height, greaterThan(24));
    final retry = tester.getRect(find.byIcon(Icons.refresh));
    final more = tester.getRect(find.byIcon(Icons.more_vert));
    expect(retry.right, lessThanOrEqualTo(390));
    expect(more.right, lessThanOrEqualTo(390));
  });

  testWidgets('long synthesis text opens in a scrollable full-text view', (
    tester,
  ) async {
    const paragraph =
        'Synthesis output begins with a detailed account of the meeting. '
        'The participants reviewed milestones, assigned owners, and discussed '
        'open questions. The next section records decisions and follow-up '
        'actions, including dates, dependencies, risks, and expected outcomes.';
    final longText = List.filled(12, paragraph).join('\n\n');
    await _pumpFailedCard(tester, 390, taskText: longText, settle: false);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('View full synthesized text'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Synthesized text'),
      ),
      findsOneWidget,
    );
    final fullText = find.byType(SelectableText);
    expect(fullText, findsOneWidget);
    expect(tester.widget<SelectableText>(fullText).data, longText);
    final dialogContent = find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(SingleChildScrollView),
        )
        .last;
    final dialogScrollable = find
        .descendant(of: dialogContent, matching: find.byType(Scrollable))
        .first;
    final scrollableState = tester.state<ScrollableState>(dialogScrollable);
    expect(scrollableState.position.maxScrollExtent, greaterThan(0));
    await tester.drag(dialogScrollable, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(scrollableState.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone gives the error summary its own line above Details', (
    tester,
  ) async {
    await _pumpFailedCard(tester, 390);
    expect(tester.takeException(), isNull);

    final error = find.text(_error);
    final details = find.text('Details');
    expect(error, findsOneWidget);
    expect(details, findsOneWidget);
    expect(
      tester.getTopLeft(details).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(error).dy),
    );

    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final strings = AppLocalizations.of(
      tester.element(find.byType(SynthesisTaskCard)),
    )!;
    expect(find.text(strings.unifiedTaskRawRequestResponse), findsOneWidget);
  });

  testWidgets('tablet keeps Details beside the error summary', (tester) async {
    await _pumpFailedCard(tester, 700);

    final error = find.text(_error);
    final details = find.text('Details');
    expect(error, findsOneWidget);
    expect(details, findsOneWidget);
    expect(
      tester.getTopLeft(details).dy,
      lessThan(tester.getBottomLeft(error).dy),
    );
  });

  testWidgets('dark mode and larger text keep the mobile error readable', (
    tester,
  ) async {
    await _pumpFailedCard(tester, 390, textScale: 1.5, darkMode: true);
    expect(tester.takeException(), isNull);

    final error = find.text(_error);
    final details = find.text('Details');
    expect(error, findsOneWidget);
    expect(details, findsOneWidget);
    expect(
      tester.getTopLeft(details).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(error).dy),
    );
  });
}
