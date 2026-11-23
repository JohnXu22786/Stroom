import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/unified_task_list/catcatch_task_card.dart';

void main() {
  final task = catcatch.CatCatchTask(
    id: 'local-resource-badge-fixture',
    url: 'https://example.test/video',
    title: 'Example video',
    expectedDurationSec: 120,
    status: catcatch.TaskStatus.running,
    steps: [catcatch.StepStatus.running(catcatch.StepType.userSelecting)],
    detectedMedia: const [
      MediaResource(
        url: 'https://example.test/segments/segment-001.ts',
        name: 'segment-001',
        ext: 'ts',
        initiator: 'https://example.test/master.m3u8',
      ),
      MediaResource(
        url: 'https://example.test/master.m3u8',
        name: 'episode-playlist',
        ext: 'm3u8',
        isPlaylist: true,
      ),
      MediaResource(
        url: 'https://example.test/video.mp4',
        name: 'full-video',
        ext: 'mp4',
        isPlayable: true,
      ),
    ],
    createdAt: DateTime(2026, 11, 23),
  );
  final scale = double.tryParse(Uri.base.queryParameters['scale'] ?? '') ?? 1;
  final locale = Uri.base.queryParameters['locale'] == 'pt'
      ? const Locale('pt', 'BR')
      : const Locale('fr', 'FR');

  final viewState = CatCatchTaskCardViewState()
    ..expandedSegments.add(task.id)
    ..selectedMediaIdentities[task.id] = {
      task.detectedMedia[1].selectionIdentity
    };

  runApp(
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light(useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: Uri.base.queryParameters['motion'] != 'true',
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: ListView(
            children: [
              CatCatchTaskCard(
                task: task,
                isUnread: false,
                isFlowManaged: true,
                taskListViewportHeight: 640,
                viewState: viewState,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
