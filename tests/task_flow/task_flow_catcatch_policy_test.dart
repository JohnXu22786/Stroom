import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_exception.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/services/block_executors/catcatch_executor.dart';
import 'package:stroom/task_flow/services/task_flow_validator.dart';
import 'package:stroom/utils/provider_models.dart';

class _Notifier extends Mock implements CatCatchNotifier {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(
    () => registerFallbackValue(
      const MediaResource(
        url: 'https://example.com',
        name: 'fallback',
        ext: 'mp4',
      ),
    ),
  );

  const audio = MediaResource(
    url: 'https://x/a.mp4',
    name: 'audio',
    ext: 'mp4',
    mimeType: 'audio/mp4',
  );
  const split = MediaResource(
    url: 'https://x/s.mp4',
    name: 'split',
    ext: 'mp4',
    isLikelySplitTrack: true,
  );
  const videoZ = MediaResource(
    url: 'https://x/z.mp4',
    name: 'video',
    ext: 'mp4',
  );
  const videoA = MediaResource(
    url: 'https://x/b.mp4',
    name: 'video',
    ext: 'mp4',
  );
  const playlist = MediaResource(
    url: 'https://x/list.m3u8',
    name: 'list',
    ext: 'm3u8',
    isPlaylist: true,
  );

  test(
    'automatic choice ignores discovery order and incomplete split tracks',
    () {
      for (final resources in [
        [audio, split, videoZ, playlist, videoA],
        [videoA, playlist, videoZ, split, audio],
      ]) {
        expect(
          selectAutomaticCatCatchResource(resources, desiredType: IOType.video),
          videoA,
        );
        expect(
          selectAutomaticCatCatchResource(resources, desiredType: IOType.audio),
          audio,
        );
      }
      expect(
        selectAutomaticCatCatchResource([
          playlist,
          audio,
        ], desiredType: IOType.video),
        playlist,
      );
      expect(
        selectAutomaticCatCatchResource([split], desiredType: IOType.video),
        isNull,
      );
      expect(
        selectAutomaticCatCatchResource([audio], desiredType: IOType.video),
        isNull,
      );
    },
  );

  test('audio output survives serialization and connects to ASR', () async {
    final model = ModelConfig(name: 'ASR', modelId: 'asr');
    final config = ProviderConfigItem(
      host: 'https://example.com',
      key: 'key',
      models: [model],
    );
    final providers = ProviderEntriesState(
      entries: [
        ProviderEntry(name: 'ASR', type: 'asr', configs: [config]),
      ],
    );
    final download = TaskFlowBlock(
      typeKey: BlockType.catcatch,
      params: {'audioOutput': true},
    );
    final restored = TaskFlowBlock.fromMap(download.toMap());
    expect(restored.getDefinition()!.outputType, IOType.audio);
    final flow = TaskFlowDefinition(
      name: 'Audio',
      blocks: [
        restored,
        TaskFlowBlock(
          typeKey: BlockType.asr,
          params: {
            'modelRef': providerModelReference((config: config, model: model)),
          },
        ),
      ],
    );
    await validateTaskFlow(
      flow,
      [const FlowRunInput(text: 'https://example.com')],
      providers: providers,
      assistants: [],
    );
    final video = flow.copyWith(
      blocks: [restored.copyWithParam('audioOutput', false), flow.blocks.last],
    );
    await expectLater(
      validateTaskFlow(
        video,
        [const FlowRunInput(text: 'https://example.com')],
        providers: providers,
        assistants: [],
      ),
      throwsA(
        isA<TaskFlowValidationException>().having(
          (e) => e.blockIndex,
          'incompatible ASR step',
          1,
        ),
      ),
    );
  });

  test(
    'automatic download chooses declared video and confirms conversion',
    () async {
      final notifier = _Notifier();
      final executions = TaskFlowExecutionNotifier();
      final execId = executions.addExecution(flowId: 'flow', flowName: 'Flow');
      final subTask = FlowSubTask(
        blockTypeKey: 'catcatch',
        blockLabel: '下载',
        subTaskId: 'pending',
        subTaskType: 'catcatch',
        status: TaskStatus.waiting,
      );
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
      when(() => notifier.confirmAndContinue(any()))
          .thenAnswer((_) => stage = 2);
      when(() => notifier.state).thenAnswer(
        (_) => [
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
                      type: catcatch.StepType.userSelecting,
                      running: true,
                    ),
                  ]
                : [],
            downloadedFilePath: stage == 2 ? '/downloads/video.mp4' : null,
          ),
        ],
      );
      final result = await executeCatCatchBlock(
        def: BlockTypeDefinition.catcatch,
        block: TaskFlowBlock(typeKey: BlockType.catcatch),
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
    },
  );

  test('wrong downloaded media type fails before the next block', () async {
    final notifier = _Notifier();
    final executions = TaskFlowExecutionNotifier();
    final execId = executions.addExecution(flowId: 'flow', flowName: 'Flow');
    final subTask = FlowSubTask(
      blockTypeKey: 'catcatch',
      blockLabel: '下载',
      subTaskId: 'pending',
      subTaskType: 'catcatch',
      status: TaskStatus.waiting,
    );
    executions.addSubTask(execId, subTask);
    late String taskId;
    when(() => notifier.addTask(any(), any(), taskId: any(named: 'taskId')))
        .thenAnswer((invocation) {
          taskId = invocation.namedArguments[#taskId] as String;
          return taskId;
        });
    when(() => notifier.state).thenAnswer(
      (_) => [
        catcatch.CatCatchTask(
          id: taskId,
          url: 'https://x',
          expectedDurationSec: 0,
          createdAt: DateTime(2026),
          status: catcatch.TaskStatus.completed,
          downloadedFilePath: '/downloads/audio.mp3',
        ),
      ],
    );
    await expectLater(
      executeCatCatchBlock(
        def: BlockTypeDefinition.catcatch,
        block: TaskFlowBlock(typeKey: BlockType.catcatch),
        input: 'https://x',
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        catcatchNotifier: notifier,
        pollInterval: const Duration(milliseconds: 1),
      ),
      throwsA(
        isA<BlockExecutionException>().having(
          (e) => e.message,
          'message',
          contains('音频'),
        ),
      ),
    );
    expect(executions.state.single.subTasks.single.status, TaskStatus.failed);
  });

  test('converted audio remains audio inside an MP4 container', () {
    final task = catcatch.CatCatchTask(
      id: 'task',
      url: 'https://x',
      expectedDurationSec: 0,
      createdAt: DateTime(2026),
      downloadedFilePath: '/downloads/recording.mp4',
      selectedMedia: audio,
    );
    expect(catCatchOutputType(task), IOType.audio);
  });
}
