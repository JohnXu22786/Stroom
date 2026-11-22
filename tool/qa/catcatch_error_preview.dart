import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/unified_task_list/catcatch_task_card.dart';

void main() {
  const diagnostic =
      'The media download failed after the server closed the connection '
      'before the response finished. The request was retried three times, '
      'but each attempt returned an incomplete byte range. Check the server '
      'logs for request 7f31a9c2 and verify that range requests are enabled '
      'for this resource. The original response ended at byte 18432 of 98304.';
  final task = catcatch.CatCatchTask(
    id: 'screenshot-failed-download',
    url: 'https://example.test/video',
    title: 'Sample video',
    expectedDurationSec: 120,
    status: catcatch.TaskStatus.failed,
    steps: [
      catcatch.StepStatus.fail(catcatch.StepType.downloading, diagnostic),
    ],
    createdAt: DateTime(2026, 11, 22),
  );

  runApp(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
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
}
