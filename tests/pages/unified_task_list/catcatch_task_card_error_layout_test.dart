import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/unified_task_list/catcatch_task_card.dart';

const _diagnostic =
    'The media download failed after the server closed the connection before '
    'the response finished. The request was retried three times, but each '
    'attempt returned an incomplete byte range. Check the server logs for '
    'request 7f31a9c2 and verify that range requests are enabled for this '
    'resource. The original response ended at byte 18432 of 98304.';

void main() {
  testWidgets('expanded failed step shows the complete selectable diagnostic', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final task = catcatch.CatCatchTask(
      id: 'failed-download',
      url: 'https://example.test/video',
      title: 'Sample video',
      expectedDurationSec: 120,
      status: catcatch.TaskStatus.failed,
      steps: [
        catcatch.StepStatus.fail(catcatch.StepType.downloading, _diagnostic),
      ],
      createdAt: DateTime(2026, 11, 21),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en', 'US'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData.light(useMaterial3: true),
          home: Scaffold(
            body: ListView(
              children: [
                CatCatchTaskCard(
                  task: task,
                  isUnread: false,
                  taskListViewportHeight: 640,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SelectableText), findsNothing);
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    final error = find.byType(SelectableText);
    expect(error, findsOneWidget);
    final selectable = tester.widget<SelectableText>(error);
    expect(selectable.data, _diagnostic);
    expect(selectable.maxLines, isNull);
    expect(tester.getSize(error).height, greaterThan(3 * 14));
    final strings = AppLocalizations.of(
      tester.element(find.byType(CatCatchTaskCard)),
    )!;
    expect(find.text(strings.catcatchRetryStep), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
