import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/unified_task_list/catcatch_task_card.dart';

void main() {
  final task = catcatch.CatCatchTask(
    id: 'local-media-metadata-fixture',
    url: 'https://example.test/video',
    title: 'Example video',
    expectedDurationSec: 120,
    status: catcatch.TaskStatus.running,
    steps: [catcatch.StepStatus.running(catcatch.StepType.userSelecting)],
    detectedMedia: const [
      MediaResource(
        url: 'https://example.test/video',
        name: 'example-video',
        ext: 'mp4',
        mimeType:
            'video/very-long-vendor-specific-container-with-additional-parameters',
        size: 123456789,
        isLikelySplitTrack: true,
      ),
    ],
    createdAt: DateTime(2026, 11, 22),
  );

  runApp(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('de', 'DE'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light(useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: Uri.base.queryParameters['motion'] != 'true',
          ),
          child: child!,
        ),
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
