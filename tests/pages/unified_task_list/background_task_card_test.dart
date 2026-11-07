import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
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
  List<(BackgroundTask, bool)> tasks,
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
              for (final (task, isFlowManaged) in tasks)
                BackgroundTaskCard(
                  task: task,
                  isFlowManaged: isFlowManaged,
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
    final tasks = [
      (ocr, true),
      (audio, true),
      (custom, true),
      (otherType, true),
      (regularTask, false),
    ];

    await _pumpCards(tester, tasks, const Locale('en', 'US'));

    expect(find.text('OCR: photo_01'), findsOneWidget);
    expect(find.text('Audio separation: clip_02'), findsOneWidget);
    expect(find.text(custom.title), findsOneWidget);
    expect(find.text(otherType.title), findsOneWidget);
    expect(find.text(regularTask.title), findsOneWidget);
    expect(ocr.title, '文字识别_photo_01');
    expect(audio.title, '音频分离_clip_02');

    await _pumpCards(tester, tasks, const Locale('zh', 'CN'));

    expect(find.text(ocr.title), findsOneWidget);
    expect(find.text(audio.title), findsOneWidget);
    expect(find.text(custom.title), findsOneWidget);
    expect(find.text(otherType.title), findsOneWidget);
    expect(find.text(regularTask.title), findsOneWidget);
    expect(ocr.title, '文字识别_photo_01');
    expect(audio.title, '音频分离_clip_02');
  });
}
