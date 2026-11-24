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
import 'package:stroom/widgets/constrained_text.dart';

class _TaskFlowServiceMock extends Mock implements TaskFlowExecutionService {}

class _CatCatchNotifierMock extends Mock implements CatCatchNotifier {}

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
) =>
    catcatch.CatCatchTask(
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
        catcatch.StepStatus(
            type: catcatch.StepType.userSelecting, running: true),
      ],
    );

Future<void> _pumpFlowSelection(
  WidgetTester tester,
  List<MediaResource> media, {
  List<MediaResource>? candidates,
  TaskFlowExecutionService? service,
  Locale locale = const Locale('en'),
  double textScaleFactor = 1,
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
      child: MaterialApp(
        locale: locale,
        theme: ThemeData.light(),
        themeMode: ThemeMode.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: child!,
        ),
        home: const HomePage(),
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

  testWidgets('localized media badge stays within a narrow scaled row', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const playlist = MediaResource(
      url: 'https://example.com/list.m3u8',
      name: 'playlist',
      ext: 'm3u8',
      isPlaylist: true,
    );
    await _pumpFlowSelection(
      tester,
      [playlist],
      locale: const Locale('de'),
    );

    final badge = find.byWidgetPredicate(
      (widget) => widget is ConstrainedText && widget.data == 'Wiedergabeliste',
    );
    expect(badge, findsOneWidget);
    expect(
      find.descendant(of: badge, matching: find.byType(AnimatedBuilder)),
      findsOneWidget,
    );
    final semantics = tester.ensureSemantics();
    expect(tester.getSemantics(badge).label, contains('Wiedergabeliste'));
    semantics.dispose();
    expect(tester.takeException(), isNull);

    await _pumpFlowSelection(
      tester,
      [playlist],
      locale: const Locale('de'),
      textScaleFactor: 3,
    );
    final scaledBadge = find.byWidgetPredicate(
      (widget) => widget is ConstrainedText && widget.data == 'Wiedergabeliste',
    );
    expect(
      find.descendant(
        of: scaledBadge,
        matching: find.byType(AnimatedBuilder),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 1500));
    expect(tester.takeException(), isNull);
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

  testWidgets(
    'implicit video confirmation includes only its paired split audio',
    (tester) async {
      const video = MediaResource(
        url: 'https://example.com/video.mp4',
        name: 'video',
        ext: 'mp4',
        mimeType: 'video/mp4',
        groupId: 'split-group',
        isLikelySplitTrack: true,
      );
      const pairedAudio = MediaResource(
        url: 'https://example.com/audio.m4a',
        name: 'audio',
        ext: 'm4a',
        mimeType: 'audio/mp4',
        groupId: 'split-group',
        isLikelySplitTrack: true,
      );
      const playlistSegment = MediaResource(
        url: 'https://example.com/playlist-segment.m4a',
        name: 'playlist segment',
        ext: 'm4a',
        mimeType: 'audio/mp4',
        initiator: 'https://example.com/playlist.m3u8',
        groupId: 'split-group',
        isLikelySplitTrack: true,
      );
      const unrelatedAudio = MediaResource(
        url: 'https://example.com/unrelated.m4a',
        name: 'unrelated audio',
        ext: 'm4a',
        mimeType: 'audio/mp4',
        groupId: 'other-group',
        isLikelySplitTrack: true,
      );
      final service = _TaskFlowServiceMock();
      final notifier = _CatCatchNotifierMock();
      when(
        () => service.performManualCatCatchAction(
          any(),
          any(),
          any(),
          selectedMediaUrl: any(named: 'selectedMediaUrl'),
          selectedMediaIdentity: any(named: 'selectedMediaIdentity'),
          selectedMediaHasByteRange: any(named: 'selectedMediaHasByteRange'),
        ),
      ).thenAnswer((invocation) async {
        final action = invocation.positionalArguments[2] as void Function(
          CatCatchNotifier,
        );
        action(notifier);
        return true;
      });
      await _pumpFlowSelection(
        tester,
        [video, playlistSegment, pairedAudio, unrelatedAudio],
        candidates: [video],
        service: service,
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('catcatch_media_selection_dialog')),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      verify(
        () => notifier.selectMedia(
          'flow-task',
          video,
          mergeAudioUrl: pairedAudio.url,
        ),
      ).called(1);
    },
  );

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

  testWidgets('an audio-only candidate is selected without merge audio', (
    tester,
  ) async {
    const audio = MediaResource(
      url: 'https://example.com/only.m4a',
      name: 'only',
      ext: 'm4a',
      groupId: 'audio-only-group',
      isLikelySplitTrack: true,
    );
    final service = _TaskFlowServiceMock();
    final notifier = _CatCatchNotifierMock();
    when(
      () => service.performManualCatCatchAction(
        any(),
        any(),
        any(),
        selectedMediaUrl: any(named: 'selectedMediaUrl'),
        selectedMediaIdentity: any(named: 'selectedMediaIdentity'),
        selectedMediaHasByteRange: any(named: 'selectedMediaHasByteRange'),
      ),
    ).thenAnswer((invocation) async {
      final action =
          invocation.positionalArguments[2] as void Function(CatCatchNotifier);
      action(notifier);
      return true;
    });
    await _pumpFlowSelection(tester, [audio], service: service);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('catcatch_media_selection_dialog')),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    verify(
      () => notifier.selectMedia('flow-task', audio, mergeAudioUrl: null),
    ).called(1);
  });
}
