import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/l10n/app_localizations_ar.dart';
import 'package:stroom/models/ocr_batch_execution.dart';
import 'package:stroom/pages/unified_task_list/background_task_card.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/task_provider_shared.dart';

BackgroundTask _task(BackgroundTaskType type, String title) => BackgroundTask(
      id: title,
      type: type,
      title: title,
      status: TaskStatus.completed,
      createdAt: DateTime(2025, 1, 1),
    );

Future<void> _pumpCards(
  WidgetTester tester,
  List<(BackgroundTask, String?)> tasks,
  Locale locale,
) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListView(
            children: [
              for (final (task, flowBlockTypeKey) in tasks)
                BackgroundTaskCard(
                  task: task,
                  isFlowManaged: flowBlockTypeKey != null,
                  flowBlockTypeKey: flowBlockTypeKey,
                ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('OCR page outcomes reflow without losing labels or errors', (
    tester,
  ) async {
    const size = Size(320, 640);
    final localizations = AppLocalizationsAr();
    final errorDetail = localizations.bgTaskOcrRequestSizeExceeded(
      123456,
      1000,
    );
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final task = BackgroundTask(
      id: 'OCR results',
      type: BackgroundTaskType.ocr,
      title: 'OCR results',
      status: TaskStatus.completed,
      createdAt: DateTime(2025, 1, 1),
      localizations: localizations,
      ocrPageOutcomes: [
        OcrPageOutcome(
          imageIndex: 0,
          status: OcrPageOutcomeStatus.failed,
          error: errorDetail,
        ),
      ],
    );
    expect(task.ocrPageOutcomes.single.error, errorDetail);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(
              size: size,
              devicePixelRatio: 1,
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: ListView(children: [BackgroundTaskCard(task: task)]),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    final strings = AppLocalizations.of(
      tester.element(find.byType(BackgroundTaskCard)),
    )!;
    expect(find.text(strings.unifiedTaskOcrPageIndex(1)), findsOneWidget);
    expect(find.text(strings.unifiedTaskOcrFailed), findsOneWidget);
    expect(find.text(errorDetail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('localizes generated task titles for display only', (
    tester,
  ) async {
    final ocr = _task(BackgroundTaskType.ocr, '文字识别_photo_01');
    final audio = _task(BackgroundTaskType.audioSeparation, '音频分离_clip_02');
    final custom = _task(BackgroundTaskType.ocr, '文字识别 custom title');
    final otherType = _task(BackgroundTaskType.chat, '文字识别_chat_title');
    final regularTask = _task(
      BackgroundTaskType.audioSeparation,
      '音频分离_regular_task',
    );
    final mismatchedFlowBlock = _task(
      BackgroundTaskType.ocr,
      '文字识别_other_block',
    );
    final tasks = [
      (ocr, 'ocr'),
      (audio, 'audioSeparation'),
      (custom, 'ocr'),
      (otherType, 'chat'),
      (regularTask, null),
      (mismatchedFlowBlock, 'chat'),
    ];

    await _pumpCards(tester, tasks, const Locale('en', 'US'));

    expect(find.text('OCR: photo_01'), findsOneWidget);
    expect(find.text('Audio separation: clip_02'), findsOneWidget);
    expect(find.text(custom.title), findsOneWidget);
    expect(find.text(otherType.title), findsOneWidget);
    expect(find.text(regularTask.title), findsOneWidget);
    expect(find.text(mismatchedFlowBlock.title), findsOneWidget);
    expect(ocr.title, '文字识别_photo_01');
    expect(audio.title, '音频分离_clip_02');

    await _pumpCards(tester, tasks, const Locale('zh', 'CN'));

    expect(find.text(ocr.title), findsOneWidget);
    expect(find.text(audio.title), findsOneWidget);
    expect(find.text(custom.title), findsOneWidget);
    expect(find.text(otherType.title), findsOneWidget);
    expect(find.text(regularTask.title), findsOneWidget);
    expect(find.text(mismatchedFlowBlock.title), findsOneWidget);
    expect(ocr.title, '文字识别_photo_01');
    expect(audio.title, '音频分离_clip_02');
  });
}
