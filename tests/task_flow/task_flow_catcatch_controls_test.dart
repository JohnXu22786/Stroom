import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart';
import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/pages/unified_task_list/catcatch_task_card.dart';
import 'package:stroom/task_flow/services/task_flow_execution_service.dart';

class _FlowActions extends Fake implements TaskFlowExecutionService {
  _FlowActions(this.downloads);
  final _Downloads Function() downloads;
  final calls = <(String, bool)>[];
  final selectedIdentities = <String?>[];
  Future<bool> Function(String, bool, void Function(CatCatchNotifier))? run;

  @override
  Future<bool> performManualCatCatchAction(
      String taskId, bool selecting, void Function(CatCatchNotifier) action,
      {String? selectedMediaIdentity,
      String? selectedMediaUrl,
      bool selectedMediaHasByteRange = false}) async {
    calls.add((taskId, selecting));
    selectedIdentities.add(selectedMediaIdentity ?? selectedMediaUrl);
    if (run != null) return run!(taskId, selecting, action);
    action(downloads());
    return true;
  }
}

class _Downloads extends CatCatchNotifier {
  late _FlowActions flowActions;
  final selected = <MediaResource>[];
  final batches = <List<MediaResource>>[];
  String? mergeAudio;
  int confirmations = 0;
  int rawSaves = 0;
  _Downloads(super.ref);

  @override
  void selectMedia(String id, MediaResource media, {String? mergeAudioUrl}) {
    selected.add(media);
    mergeAudio = mergeAudioUrl;
  }

  @override
  void batchSelectMedia(String id, List<MediaResource> media,
          {String? mergeAudioUrl}) =>
      batches.add(media);

  @override
  void confirmAndContinue(String id) => confirmations++;

  @override
  void skipConversion(String id) => rawSaves++;
}

Future<_Downloads> _pump(WidgetTester tester, CatCatchTask task,
    {bool flowManaged = true}) async {
  late _Downloads downloads;
  final actions = _FlowActions(() => downloads);
  await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        taskFlowExecutionServiceProvider.overrideWithValue(actions),
        catcatchTasksProvider.overrideWith((ref) {
          downloads = _Downloads(ref)..state = [task];
          downloads.flowActions = actions;
          return downloads;
        }),
      ],
      child: MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
        child: Consumer(
            builder: (context, ref, _) => CatCatchTaskCard(
                  task: ref.watch(catcatchTasksProvider).single,
                  isFlowManaged: flowManaged,
                )),
      )))));
  await tester.pump();
  return downloads;
}

Future<void> _pumpInShortTaskListViewport(
    WidgetTester tester, CatCatchTask task) async {
  await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        catcatchTasksProvider.overrideWith((ref) {
          return _Downloads(ref)..state = [task];
        }),
      ],
      child: MaterialApp(
          home: Scaffold(
              body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          key: const Key('task_list_main_viewport'),
          height: 300,
          child: LayoutBuilder(
            builder: (context, constraints) => ListView(
              children: [
                CatCatchTaskCard(
                  task: task,
                  taskListViewportHeight: constraints.maxHeight,
                ),
              ],
            ),
          ),
        ),
      )))));
  await tester.pump();
}

CatCatchTask _task(List<MediaResource> media, {bool confirmation = false}) =>
    CatCatchTask(
      id: 'download',
      url: 'https://example.com',
      expectedDurationSec: 0,
      createdAt: DateTime(2026),
      steps: [StepStatus.running(StepType.userSelecting)],
      detectedMedia: media,
      metadata: confirmation ? {'pendingConfirm': 'special_format'} : {},
    );

void main() {
  const one = MediaResource(url: 'https://x/one.mp4', name: 'one', ext: 'mp4');
  const two = MediaResource(url: 'https://x/two.mp4', name: 'two', ext: 'mp4');
  testWidgets(
      'flow media selection replaces the resource without spawning siblings',
      (tester) async {
    final downloads = await _pump(tester, _task([one, two]));
    await tester.tap(find.text('one.mp4'));
    await tester.pump();
    await tester.tap(find.text('two.mp4'));
    await tester.pump();
    final submit = find.textContaining('下载选中的');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(downloads.selected, [two]);
    expect(downloads.flowActions.calls, [('download', true)]);
    expect(downloads.batches, isEmpty);
  });

  testWidgets(
      'selecting one byte range does not select another range at the same URL',
      (tester) async {
    const firstRange = MediaResource(
      url: 'https://x/media.ts',
      name: 'first-range',
      ext: 'ts',
      initiator: 'https://x/playlist.m3u8',
      byteRangeStart: 0,
      byteRangeLength: 100,
    );
    const secondRange = MediaResource(
      url: 'https://x/media.ts',
      name: 'second-range',
      ext: 'ts',
      initiator: 'https://x/playlist.m3u8',
      byteRangeStart: 100,
      byteRangeLength: 100,
    );
    final downloads = await _pump(
      tester,
      _task([firstRange, secondRange]),
      flowManaged: false,
    );

    await tester.tap(find.byKey(const Key('m3u8_segments_toggle')));
    await tester.pump();
    await tester.tap(find.text('first-range.ts'));
    await tester.pump();
    final submit = find.textContaining('下载选中的');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(downloads.batches, [[firstRange]]);
  });

  testWidgets('same-URL non-range candidates keep URL-based selection',
      (tester) async {
    const first =
        MediaResource(url: 'https://x/media.mp4', name: 'first', ext: 'mp4');
    const duplicate = MediaResource(
        url: 'https://x/media.mp4', name: 'duplicate', ext: 'mp4');
    final downloads = await _pump(
      tester,
      _task([first, duplicate]),
      flowManaged: false,
    );

    await tester.tap(find.text('first.mp4'));
    await tester.pump();
    final submit = find.textContaining('下载选中的');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(downloads.batches, [[first, duplicate]]);
  });

  testWidgets('flow candidate filtering and handoff distinguish byte ranges',
      (tester) async {
    const firstRange = MediaResource(
      url: 'https://x/media.ts',
      name: 'first-range',
      ext: 'ts',
      initiator: 'https://x/playlist.m3u8',
      byteRangeStart: 0,
      byteRangeLength: 100,
    );
    const secondRange = MediaResource(
      url: 'https://x/media.ts',
      name: 'second-range',
      ext: 'ts',
      initiator: 'https://x/playlist.m3u8',
      byteRangeStart: 100,
      byteRangeLength: 100,
    );
    final task = _task([firstRange, secondRange]).copyWith(metadata: {
      CatCatchTask.flowManagedSelectionKey: 'true',
      CatCatchTask.flowSelectionCandidatesIdentityVersionKey:
          CatCatchTask.flowSelectionCandidatesIdentityVersion,
      CatCatchTask.flowSelectionCandidatesKey:
          jsonEncode([secondRange.selectionIdentity]),
    });
    final downloads = await _pump(tester, task);

    await tester.tap(find.byKey(const Key('m3u8_segments_toggle')));
    await tester.pump();
    expect(find.text('first-range.ts'), findsNothing);
    await tester.tap(find.text('second-range.ts'));
    await tester.pump();
    final submit = find.textContaining('下载选中的');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(downloads.selected, [secondRange]);
    expect(downloads.flowActions.selectedIdentities,
        [secondRange.selectionIdentity]);
  });

  testWidgets('versioned URL candidate does not admit a range sharing the URL',
      (tester) async {
    const wholeFile = MediaResource(
      url: 'https://x/media.ts',
      name: 'whole-file',
      ext: 'ts',
    );
    const range = MediaResource(
      url: 'https://x/media.ts',
      name: 'range',
      ext: 'ts',
      initiator: 'https://x/playlist.m3u8',
      byteRangeStart: 0,
      byteRangeLength: 100,
    );
    final task = _task([wholeFile, range]).copyWith(metadata: {
      CatCatchTask.flowManagedSelectionKey: 'true',
      CatCatchTask.flowSelectionCandidatesIdentityVersionKey:
          CatCatchTask.flowSelectionCandidatesIdentityVersion,
      CatCatchTask.flowSelectionCandidatesKey:
          jsonEncode([wholeFile.selectionIdentity]),
    });
    await _pump(tester, task);

    expect(find.text('whole-file.ts'), findsOneWidget);
    expect(find.text('range.ts'), findsNothing);
  });

  testWidgets(
      'expanded segment collapse control stays pinned while task details scroll',
      (tester) async {
    final segments = List.generate(
      40,
      (index) => MediaResource(
        url: 'https://x/$index.ts',
        name: 'segment-$index',
        ext: 'ts',
        initiator: 'https://x/playlist.m3u8',
      ),
    );
    final task = _task(segments).copyWith(steps: [
      StepStatus.done(
        StepType.fetching,
        detail: List.filled(100, 'expanded task detail').join(' '),
      ),
      StepStatus.running(StepType.userSelecting),
    ]);
    await _pump(tester, task);
    await tester.tap(find.text(StepType.fetching.label));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('m3u8_segments_toggle')));
    await tester.tap(find.byKey(const Key('m3u8_segments_toggle')));
    await tester.pump();

    final details = find.textContaining('expanded task detail');
    await tester.ensureVisible(details);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.drag(details, const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 100));

    final toggle = find.byKey(const Key('m3u8_segments_toggle'));
    expect(toggle.hitTestable(), findsOneWidget);
    final toggleRect = tester.getRect(toggle);
    final viewportRect = tester
        .getRect(find.byKey(const Key('catcatch_task_resource_viewport')));
    expect(toggleRect.top, greaterThanOrEqualTo(viewportRect.top));
    expect(toggleRect.top, lessThan(viewportRect.top + 52));
    expect(toggleRect.bottom, lessThanOrEqualTo(viewportRect.bottom));
  });

  testWidgets(
      'resource viewport is capped by a short task-list viewport, not the screen',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpInShortTaskListViewport(
      tester,
      _task([one])
          .copyWith(steps: [StepStatus.running(StepType.userSelecting)]),
    );

    final taskListViewport =
        tester.getRect(find.byKey(const Key('task_list_main_viewport')));
    final resourceViewport = tester
        .getRect(find.byKey(const Key('catcatch_task_resource_viewport')));
    expect(
      resourceViewport.height,
      lessThanOrEqualTo(taskListViewport.height * 2 / 3),
    );
  });

  testWidgets(
      'media action stays reachable while the resource list scrolls within its cap',
      (tester) async {
    final media = List.generate(
      60,
      (index) => MediaResource(
        url: 'https://x/$index.mp4',
        name: 'resource-$index',
        ext: 'mp4',
      ),
    );
    final task = _task(media).copyWith(steps: [
      StepStatus.done(
        StepType.fetching,
        detail: List.filled(80, 'expanded task detail').join(' '),
      ),
      StepStatus.running(StepType.userSelecting),
    ]);
    await _pump(tester, task);
    await tester.tap(find.text(StepType.fetching.label));
    await tester.pump();

    final action = find.text('请选择要下载的资源');
    final actionRect = tester.getRect(action);
    final listRect =
        tester.getRect(find.byKey(const Key('catcatch_resource_list')));
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(actionRect.bottom, lessThanOrEqualTo(screenHeight));
    expect(listRect.height, lessThanOrEqualTo(screenHeight * 2 / 3));
  });

  testWidgets(
      'downstream-filtered prompt hides incompatible resource and submits allowed item',
      (tester) async {
    const audioA =
        MediaResource(url: 'https://x/a.mp3', name: 'audio-a', ext: 'mp3');
    const audioB =
        MediaResource(url: 'https://x/b.wav', name: 'audio-b', ext: 'wav');
    const video =
        MediaResource(url: 'https://x/v.mp4', name: 'video', ext: 'mp4');
    final task = _task([audioA, audioB, video]).copyWith(metadata: {
      CatCatchTask.flowManagedSelectionKey: 'true',
      CatCatchTask.flowSelectionCandidatesKey:
          jsonEncode([audioA.url, audioB.url]),
    });
    final downloads = await _pump(tester, task);

    expect(find.text('video.mp4'), findsNothing);
    expect(find.text('audio-a.mp3'), findsOneWidget);
    expect(find.text('audio-b.wav'), findsOneWidget);
    await tester.tap(find.text('audio-b.wav'));
    await tester.pump();
    final submit = find.textContaining('下载选中的');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(downloads.selected, [audioB]);
    expect(downloads.flowActions.selectedIdentities, [audioB.url]);
    expect(downloads.state.single.detectedMedia, [audioA, audioB, video]);
  });

  testWidgets('only flow prompts expose a matching split track by itself',
      (tester) async {
    const audio = MediaResource(
      url: 'https://x/audio.m4a',
      name: 'audio',
      ext: 'm4a',
      groupId: 'split',
      isLikelySplitTrack: true,
    );
    final promptTask = _task([audio]).copyWith(metadata: {
      CatCatchTask.flowManagedSelectionKey: 'true',
      CatCatchTask.flowSelectionCandidatesKey: jsonEncode([audio.url]),
    });
    final downloads = await _pump(tester, promptTask);
    expect(find.text('audio.m4a'), findsOneWidget);
    await tester.tap(find.text('audio.m4a'));
    await tester.pump();
    final submit = find.textContaining('下载选中的');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(downloads.selected, [audio]);

    await _pump(tester, _task([audio]), flowManaged: false);
    expect(find.text('audio.m4a'), findsNothing);
  });

  testWidgets(
      'flow split-track merging creates one video result with its audio',
      (tester) async {
    const video = MediaResource(
        url: 'https://x/video.mp4',
        name: 'video',
        ext: 'mp4',
        groupId: 'group',
        isLikelySplitTrack: true);
    const audio = MediaResource(
        url: 'https://x/audio.mp3',
        name: 'audio',
        ext: 'mp3',
        groupId: 'group',
        isLikelySplitTrack: true);
    final downloads = await _pump(tester, _task([video, audio]));
    await tester.ensureVisible(find.text('合并音视频'));
    await tester.tap(find.text('合并音视频'));
    await tester.pump();
    final submit = find.textContaining('下载选中的');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(downloads.selected, [video]);
    expect(downloads.flowActions.calls, [('download', true)]);
    expect(downloads.mergeAudio, audio.url);
    expect(downloads.batches, isEmpty);
  });

  testWidgets('paused flow confirmation cannot restart work until flow resumes',
      (tester) async {
    final downloads = await _pump(tester, _task([], confirmation: true));
    downloads.state = [
      downloads.state.single.copyWith(status: TaskStatus.paused)
    ];
    await tester.pump();
    for (final label in ['自动处理', '保留原始格式']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
    }
    expect(downloads.confirmations, 0);
    expect(downloads.rawSaves, 0);
    downloads.state = [
      downloads.state.single.copyWith(status: TaskStatus.running)
    ];
    await tester.pump();
    await tester.tap(find.text('自动处理'));
    await tester.pump();
    expect(downloads.confirmations, 1);
    expect(downloads.flowActions.calls, [('download', false)]);
  });

  testWidgets('flow raw-format save requests a reservation', (tester) async {
    final downloads = await _pump(tester, _task([], confirmation: true));
    await tester.tap(find.text('保留原始格式'));
    await tester.pump();
    expect(downloads.rawSaves, 1);
    expect(downloads.flowActions.calls, [('download', false)]);
  });

  testWidgets('queued selection shows pending and ignores duplicate taps',
      (tester) async {
    final downloads = await _pump(tester, _task([one, two]));
    final reservation = Completer<bool>();
    downloads.flowActions.run = (id, selecting, action) async {
      final granted = await reservation.future;
      if (granted) action(downloads);
      return granted;
    };
    await tester.tap(find.text('one.mp4'));
    await tester.pump();
    await tester.tap(find.textContaining('下载选中的'));
    await tester.pump();
    expect(find.text('正在等待任务流资源'), findsOneWidget);
    expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull);
    await tester.tap(find.text('正在等待任务流资源'));
    expect(downloads.flowActions.calls, [('download', true)]);
    expect(downloads.selected, isEmpty);
    reservation.complete(true);
    await tester.pump();
    expect(find.text('正在等待任务流资源'), findsNothing);
    expect(downloads.selected, [one]);
  });

  testWidgets('failed queued selection restores the button with feedback',
      (tester) async {
    final downloads = await _pump(tester, _task([one, two]));
    final reservation = Completer<bool>();
    downloads.flowActions.run = (_, __, ___) => reservation.future;
    await tester.tap(find.text('one.mp4'));
    await tester.pump();
    await tester.tap(find.textContaining('下载选中的'));
    await tester.pump();
    reservation.complete(false);
    await tester.pump();
    expect(find.text('正在等待任务流资源'), findsNothing);
    expect(find.textContaining('请检查流程状态后重试'), findsOneWidget);
    expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNotNull);
    expect(downloads.selected, isEmpty);
  });

  testWidgets(
      'queued format confirmation disables both choices and reports errors',
      (tester) async {
    final downloads = await _pump(tester, _task([], confirmation: true));
    final reservation = Completer<bool>();
    downloads.flowActions.run = (_, __, ___) => reservation.future;
    await tester.tap(find.text('自动处理'));
    await tester.pump();
    expect(find.text('正在等待任务流资源'), findsOneWidget);
    expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull);
    expect(
        tester
            .widget<OutlinedButton>(find.byType(OutlinedButton).last)
            .onPressed,
        isNull);
    await tester.tap(find.text('保留原始格式'));
    expect(downloads.flowActions.calls, [('download', false)]);
    reservation.completeError(StateError('资源暂不可用'));
    await tester.pump();
    expect(find.text('正在等待任务流资源'), findsNothing);
    expect(find.textContaining('资源暂不可用'), findsOneWidget);
    expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNotNull);
    expect(
        tester
            .widget<OutlinedButton>(find.byType(OutlinedButton).last)
            .onPressed,
        isNotNull);
    expect(downloads.confirmations, 0);
    expect(downloads.rawSaves, 0);
  });
}
