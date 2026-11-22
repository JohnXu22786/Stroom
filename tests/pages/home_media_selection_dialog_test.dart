// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/home_page.dart';
import 'package:stroom/task_flow/services/task_flow_execution_service.dart';

class _TaskFlowServiceMock extends Mock implements TaskFlowExecutionService {}

catcatch.CatCatchTask _flowTask(List<MediaResource> media) =>
    catcatch.CatCatchTask(
      id: 'flow-task',
      url: 'https://example.com/watch',
      expectedDurationSec: 0,
      createdAt: DateTime(2026),
      detectedMedia: media,
      metadata: {
        catcatch.CatCatchTask.flowManagedSelectionKey: 'true',
        catcatch.CatCatchTask.flowSelectionCandidatesKey: jsonEncode(
          media.map((item) => item.selectionIdentity).toList(),
        ),
        catcatch.CatCatchTask.flowSelectionCandidatesIdentityVersionKey:
            catcatch.CatCatchTask.flowSelectionCandidatesIdentityVersion,
      },
      steps: const [
        catcatch.StepStatus(
          type: catcatch.StepType.userSelecting,
          running: true,
        ),
      ],
    );

catcatch.CatCatchTask _flowTaskWithCandidates(
  List<MediaResource> media,
  List<MediaResource> candidates,
) => catcatch.CatCatchTask(
  id: 'flow-task',
  url: 'https://example.com/watch',
  expectedDurationSec: 0,
  createdAt: DateTime(2026),
  detectedMedia: media,
  metadata: {
    catcatch.CatCatchTask.flowManagedSelectionKey: 'true',
    catcatch.CatCatchTask.flowSelectionCandidatesKey: jsonEncode(
      candidates.map((item) => item.selectionIdentity).toList(),
    ),
    catcatch.CatCatchTask.flowSelectionCandidatesIdentityVersionKey:
        catcatch.CatCatchTask.flowSelectionCandidatesIdentityVersion,
  },
  steps: const [
    catcatch.StepStatus(type: catcatch.StepType.userSelecting, running: true),
  ],
);

Future<void> _pumpFlowSelection(
  WidgetTester tester,
  List<MediaResource> media, {
  List<MediaResource>? candidates,
  TaskFlowExecutionService? service,
}) async {
  final container = ProviderContainer(
    overrides: [
      catcatchTasksProvider.overrideWith((ref) {
        final notifier = CatCatchNotifier(ref);
        notifier.state = [];
        return notifier;
      }),
      if (service != null)
        taskFlowExecutionServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomePage(),
      ),
    ),
  );
  container.read(catcatchTasksProvider.notifier).state = [
    candidates == null
        ? _flowTask(media)
        : _flowTaskWithCandidates(media, candidates),
  ];
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() {
    registerFallbackValue((CatCatchNotifier _) {});
  });

  testWidgets('Task Flow opens the shared picker and enables one resource', (
    tester,
  ) async {
    const media = MediaResource(
      url: 'https://example.com/only.mp4',
      name: 'only',
      ext: 'mp4',
    );
    await _pumpFlowSelection(tester, [media]);

    expect(
      find.byKey(const Key('catcatch_media_selection_dialog')),
      findsOneWidget,
    );
    final confirm = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('catcatch_media_selection_dialog')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(confirm.onPressed, isNotNull);
  });

  testWidgets('multiple Task Flow resources require an explicit choice', (
    tester,
  ) async {
    const first = MediaResource(
      url: 'https://example.com/first.mp4',
      name: 'first',
      ext: 'mp4',
    );
    const second = MediaResource(
      url: 'https://example.com/second.mp4',
      name: 'second',
      ext: 'mp4',
    );
    await _pumpFlowSelection(tester, [first, second]);

    final confirm = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('catcatch_media_selection_dialog')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(confirm.onPressed, isNull);

    await tester.tap(
      find.byKey(Key('media_selection_${first.selectionIdentity}')),
    );
    await tester.pump();
    final enabledConfirm = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('catcatch_media_selection_dialog')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(enabledConfirm.onPressed, isNotNull);
  });

  testWidgets('video candidate keeps its paired split audio available', (
    tester,
  ) async {
    const video = MediaResource(
      url: 'https://example.com/video.mp4',
      name: 'video',
      ext: 'mp4',
      mimeType: 'video/mp4',
      groupId: 'split-group',
      isLikelySplitTrack: true,
    );
    const audio = MediaResource(
      url: 'https://example.com/audio.m4a',
      name: 'audio',
      ext: 'm4a',
      mimeType: 'audio/mp4',
      groupId: 'split-group',
      isLikelySplitTrack: true,
    );
    await _pumpFlowSelection(tester, [video, audio], candidates: [video]);

    var confirm = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('catcatch_media_selection_dialog')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(confirm.onPressed, isNotNull);

    await tester.tap(
      find.byKey(Key('media_selection_${audio.selectionIdentity}')),
    );
    await tester.pump();
    confirm = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('catcatch_media_selection_dialog')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(confirm.onPressed, isNull);

    await tester.tap(
      find.byKey(Key('media_selection_${video.selectionIdentity}')),
    );
    await tester.pump();
    confirm = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('catcatch_media_selection_dialog')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(confirm.onPressed, isNotNull);
  });

  testWidgets('allowed split audio is not duplicated as a companion', (
    tester,
  ) async {
    const video = MediaResource(
      url: 'https://example.com/video.mp4',
      name: 'video',
      ext: 'mp4',
      mimeType: 'video/mp4',
      groupId: 'split-group',
      isLikelySplitTrack: true,
    );
    const audio = MediaResource(
      url: 'https://example.com/audio.m4a',
      name: 'audio',
      ext: 'm4a',
      mimeType: 'audio/mp4',
      groupId: 'split-group',
      isLikelySplitTrack: true,
    );
    await _pumpFlowSelection(tester, [video, audio]);

    expect(
      find.byKey(Key('media_selection_${video.selectionIdentity}')),
      findsOneWidget,
    );
    expect(
      find.byKey(Key('media_selection_${audio.selectionIdentity}')),
      findsOneWidget,
    );
  });

  testWidgets('a rejected flow action leaves the picker available to retry', (
    tester,
  ) async {
    const media = MediaResource(
      url: 'https://example.com/only.mp4',
      name: 'only',
      ext: 'mp4',
    );
    final service = _TaskFlowServiceMock();
    when(
      () => service.performManualCatCatchAction(
        any(),
        any(),
        any(),
        selectedMediaUrl: any(named: 'selectedMediaUrl'),
        selectedMediaIdentity: any(named: 'selectedMediaIdentity'),
        selectedMediaHasByteRange: any(named: 'selectedMediaHasByteRange'),
      ),
    ).thenAnswer((_) async => false);
    await _pumpFlowSelection(tester, [media], service: service);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('catcatch_media_selection_dialog')),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const Key('catcatch_media_selection_dialog')),
      findsOneWidget,
    );
    verify(
      () => service.performManualCatCatchAction(
        any(),
        true,
        any(),
        selectedMediaUrl: media.url,
        selectedMediaIdentity: media.selectionIdentity,
        selectedMediaHasByteRange: false,
      ),
    ).called(1);
  });
}
