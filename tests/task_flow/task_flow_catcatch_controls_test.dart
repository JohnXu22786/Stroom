import 'dart:async';

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
  Future<bool> Function(String, bool, void Function(CatCatchNotifier))? run;

  @override
  Future<bool> performManualCatCatchAction(String taskId, bool selecting,
      void Function(CatCatchNotifier) action) async {
    calls.add((taskId, selecting));
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

Future<_Downloads> _pump(WidgetTester tester, CatCatchTask task) async {
  late _Downloads downloads;
  final actions = _FlowActions(() => downloads);
  await tester.pumpWidget(ProviderScope(
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
                  isFlowManaged: true,
                )),
      )))));
  await tester.pump();
  return downloads;
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
