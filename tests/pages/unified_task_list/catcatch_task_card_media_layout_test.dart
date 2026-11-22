import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/unified_task_list/catcatch_task_card.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets('narrow media rows keep complete metadata and split label', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const metadata =
        'video/very-long-vendor-specific-container-with-additional-parameters';
    final task = catcatch.CatCatchTask(
      id: 'narrow-media-row',
      url: 'https://example.test/video',
      title: 'Sample video',
      expectedDurationSec: 120,
      status: catcatch.TaskStatus.running,
      steps: [catcatch.StepStatus.running(catcatch.StepType.userSelecting)],
      detectedMedia: const [
        MediaResource(
          url: 'https://example.test/video',
          name: 'sample',
          ext: 'mp4',
          mimeType: metadata,
          size: 123456789,
          isLikelySplitTrack: true,
          isPlayable: true,
        ),
      ],
      createdAt: DateTime(2026, 11, 22),
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
                  isFlowManaged: true,
                  taskListViewportHeight: 640,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final metadataText = find.byWidgetPredicate(
      (widget) => widget is ConstrainedText && widget.data.endsWith(metadata),
    );
    final strings = AppLocalizations.of(
      tester.element(find.byType(CatCatchTaskCard)),
    )!;
    final splitText = find.byWidgetPredicate(
      (widget) =>
          widget is ConstrainedText &&
          widget.data == strings.catcatchSeparateTracks,
    );
    expect(metadataText, findsOneWidget);
    expect(splitText, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
