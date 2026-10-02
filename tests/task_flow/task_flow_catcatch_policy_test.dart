import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/task_flow/services/task_flow_validator.dart';
import 'package:stroom/utils/provider_models.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_exception.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/services/block_executors/catcatch_executor.dart';

class _Notifier extends Mock implements CatCatchNotifier {}

void main() {
  setUpAll(() => registerFallbackValue(const MediaResource(
      url: 'https://example.com', name: 'fallback', ext: 'mp4')));

  const audio =
      MediaResource(url: 'https://x/a.mp3', name: 'audio', ext: 'mp3');
  const split = MediaResource(
      url: 'https://x/s.mp4',
      name: 'split',
      ext: 'mp4',
      isLikelySplitTrack: true);
  const videoZ =
      MediaResource(url: 'https://x/z.mp4', name: 'video', ext: 'mp4');
  const videoA =
      MediaResource(url: 'https://x/a.mp4', name: 'video', ext: 'mp4');
  const playlist = MediaResource(
      url: 'https://x/list.m3u8', name: 'list', ext: 'm3u8', isPlaylist: true);

  test('manual selection and confirmation is the explicit safe default', () {
    final policy = BlockTypeDefinition.catcatch.params
        .singleWhere((p) => p.key == 'automaticResourceSelection');
    expect(policy.defaultValue, false);
    expect(policy.hintText, contains('手动'));
    expect(policy.hintText, contains('链接'));
  });

  test('automatic resource choice is deterministic and avoids split tracks',
      () {
    for (final resources in [
      [audio, split, videoZ, playlist, videoA],
      [videoA, playlist, videoZ, split, audio],
    ]) {
      expect(selectAutomaticCatCatchResource(resources), videoA);
    }
    expect(selectAutomaticCatCatchResource([audio, playlist]), playlist);
    expect(selectAutomaticCatCatchResource([audio]), audio);
    expect(selectAutomaticCatCatchResource([split]), isNull);
  });

  test('declared audio output connects to ASR and survives serialization',
      () async {
    final model = ModelConfig(name: 'ASR', modelId: 'asr');
    final config = ProviderConfigItem(
        host: 'https://example.com', key: 'key', models: [model]);
    final providers = ProviderEntriesState(entries: [
      ProviderEntry(name: 'ASR', type: 'asr', configs: [config])
    ]);
    final download = TaskFlowBlock(
        typeKey: BlockType.catcatch, params: {'audioOutput': true});
    final restored = TaskFlowBlock.fromMap(download.toMap());
    expect(restored.getDefinition()!.outputType, IOType.audio);
    final flow = TaskFlowDefinition(name: 'Audio', blocks: [
      restored,
      TaskFlowBlock(typeKey: BlockType.asr, params: {
        'modelRef': providerModelReference((config: config, model: model))
      })
    ]);
    await validateTaskFlow(
        flow, [const FlowRunInput(text: 'https://example.com')],
        providers: providers, assistants: []);
    final video = flow.copyWith(blocks: [
      restored.copyWithParam('audioOutput', false),
      flow.blocks.last
    ]);
    await expectLater(
        validateTaskFlow(
            video, [const FlowRunInput(text: 'https://example.com')],
            providers: providers, assistants: []),
        throwsA(isA<TaskFlowValidationException>()
            .having((e) => e.blockIndex, 'video incompatible with ASR', 1)));
    expect(
        selectAutomaticCatCatchResource([audio, videoA],
            desiredType: IOType.audio),
        audio);
    expect(selectAutomaticCatCatchResource([audio], desiredType: IOType.video),
        isNull);
  });

  test('output type uses selected audio MIME even in an MP4 container', () {
    final task = catcatch.CatCatchTask(
      id: 'task',
      url: 'https://x',
      expectedDurationSec: 0,
      createdAt: DateTime(2026),
      downloadedFilePath: '/downloads/recording.mp4',
      selectedMedia: const MediaResource(
          url: 'https://x/audio.mp4',
          name: 'audio',
          ext: 'mp4',
          mimeType: 'audio/mp4'),
    );
    expect(catCatchOutputType(task), IOType.audio);
  });

  for (final pendingConfirm in [false, true]) {
    test(
        'manual ${pendingConfirm ? 'confirmation' : 'selection'} is exempt from stall timeout',
        () async {
      final notifier = _Notifier();
      final executions = TaskFlowExecutionNotifier();
      final execId = executions.addExecution(flowId: 'flow', flowName: 'Flow');
      final subTask = FlowSubTask(
          blockTypeKey: 'catcatch',
          blockLabel: '下载',
          subTaskId: 'pending',
          subTaskType: 'catcatch',
          status: TaskStatus.waiting);
      executions.addSubTask(execId, subTask);
      late String taskId;
      var reads = 0;
      when(() => notifier.addTask(any(), any(), taskId: any(named: 'taskId')))
          .thenAnswer((invocation) {
        taskId = invocation.namedArguments[#taskId] as String;
        return taskId;
      });
      when(() => notifier.state).thenAnswer((_) {
        reads++;
        return [
          catcatch.CatCatchTask(
            id: taskId,
            url: 'https://x',
            expectedDurationSec: 0,
            createdAt: DateTime(2026),
            status: reads < 5
                ? catcatch.TaskStatus.running
                : catcatch.TaskStatus.completed,
            detectedMedia: const [videoZ, videoA],
            metadata: pendingConfirm && reads < 5
                ? {'pendingConfirm': 'special_format'}
                : {},
            steps: reads < 5
                ? [
                    catcatch.StepStatus(
                        type: pendingConfirm
                            ? catcatch.StepType.converting
                            : catcatch.StepType.userSelecting,
                        running: true)
                  ]
                : [],
            downloadedFilePath: reads < 5 ? null : '/downloads/video.mp4',
          )
        ];
      });
      when(() => notifier.removeTask(any())).thenReturn(null);
      when(() => notifier.selectMedia(any(), any())).thenReturn(null);
      when(() => notifier.confirmAndContinue(any())).thenReturn(null);
      final result = await executeCatCatchBlock(
        def: BlockTypeDefinition.catcatch,
        block: TaskFlowBlock(typeKey: BlockType.catcatch),
        input: 'https://x',
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        catcatchNotifier: notifier,
        stallTimeout: const Duration(milliseconds: 1),
        pollInterval: const Duration(milliseconds: 5),
      );
      expect(result, '/downloads/video.mp4');
      expect(reads, greaterThanOrEqualTo(5));
      verifyNever(() => notifier.selectMedia(any(), any()));
      verifyNever(() => notifier.confirmAndContinue(any()));
      verifyNever(() => notifier.removeTask(any()));
    });
  }

  test('automatic policy selects the declared resource and confirms conversion',
      () async {
    final notifier = _Notifier();
    final executions = TaskFlowExecutionNotifier();
    final execId = executions.addExecution(flowId: 'flow', flowName: 'Flow');
    final subTask = FlowSubTask(
        blockTypeKey: 'catcatch',
        blockLabel: '下载',
        subTaskId: 'pending',
        subTaskType: 'catcatch',
        status: TaskStatus.waiting);
    executions.addSubTask(execId, subTask);
    late String taskId;
    var stage = 0;
    MediaResource? selected;
    when(() => notifier.addTask(any(), any(), taskId: any(named: 'taskId')))
        .thenAnswer((invocation) {
      taskId = invocation.namedArguments[#taskId] as String;
      return taskId;
    });
    when(() => notifier.selectMedia(any(), any())).thenAnswer((invocation) {
      selected = invocation.positionalArguments[1] as MediaResource;
      stage = 1;
    });
    when(() => notifier.confirmAndContinue(any())).thenAnswer((_) => stage = 2);
    when(() => notifier.state).thenAnswer((_) => [
          catcatch.CatCatchTask(
            id: taskId,
            url: 'https://x',
            expectedDurationSec: 0,
            createdAt: DateTime(2026),
            status: stage == 2
                ? catcatch.TaskStatus.completed
                : catcatch.TaskStatus.running,
            detectedMedia: const [audio, videoZ, videoA],
            selectedMedia: selected,
            metadata: stage == 1 ? {'pendingConfirm': 'special_format'} : {},
            steps: stage == 0
                ? [
                    const catcatch.StepStatus(
                        type: catcatch.StepType.userSelecting, running: true)
                  ]
                : [],
            downloadedFilePath: stage == 2 ? '/downloads/video.mp4' : null,
          )
        ]);
    final result = await executeCatCatchBlock(
      def: BlockTypeDefinition.catcatch,
      block: TaskFlowBlock(
          typeKey: BlockType.catcatch,
          params: {'automaticResourceSelection': true}),
      input: 'https://x',
      execId: execId,
      execNotifier: executions,
      flowSubTask: subTask,
      catcatchNotifier: notifier,
      pollInterval: const Duration(milliseconds: 1),
    );
    expect(result, '/downloads/video.mp4');
    expect(selected, videoA);
    verify(() => notifier.confirmAndContinue(taskId)).called(1);
  });

  test('downloaded audio fails before a declared-video consumer starts',
      () async {
    final notifier = _Notifier();
    final executions = TaskFlowExecutionNotifier();
    final execId = executions.addExecution(flowId: 'flow', flowName: 'Flow');
    final subTask = FlowSubTask(
        blockTypeKey: 'catcatch',
        blockLabel: '下载',
        subTaskId: 'pending',
        subTaskType: 'catcatch',
        status: TaskStatus.waiting);
    executions.addSubTask(execId, subTask);
    late String taskId;
    when(() => notifier.addTask(any(), any(), taskId: any(named: 'taskId')))
        .thenAnswer((invocation) {
      taskId = invocation.namedArguments[#taskId] as String;
      return taskId;
    });
    when(() => notifier.state).thenAnswer((_) => [
          catcatch.CatCatchTask(
            id: taskId,
            url: 'https://x',
            expectedDurationSec: 0,
            createdAt: DateTime(2026),
            status: catcatch.TaskStatus.completed,
            downloadedFilePath: '/downloads/audio.mp3',
            selectedMedia: audio,
          )
        ]);
    await expectLater(
        executeCatCatchBlock(
          def: BlockTypeDefinition.catcatch,
          block: TaskFlowBlock(typeKey: BlockType.catcatch),
          input: 'https://x',
          execId: execId,
          execNotifier: executions,
          flowSubTask: subTask,
          catcatchNotifier: notifier,
          nextInputType: IOType.video,
          pollInterval: const Duration(milliseconds: 1),
        ),
        throwsA(isA<BlockExecutionException>()
            .having((e) => e.message, 'message', contains('音频'))));
    expect(executions.state.single.subTasks.single.status, TaskStatus.failed);
  });
}
