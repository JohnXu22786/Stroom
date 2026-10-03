import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/chat_manager_provider.dart';
import 'package:stroom/services/chat_stream_manager.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/flow_launch_snapshot.dart';
import 'package:stroom/task_flow/models/flow_payload.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/providers/task_flow_provider.dart';
import 'package:stroom/task_flow/services/task_flow_execution_service.dart';
import 'package:stroom/task_flow/services/task_flow_scheduler.dart';
import 'package:stroom/task_flow/services/task_flow_validator.dart';
import 'package:stroom/utils/provider_models.dart';

class _Documents extends PathProviderPlatform {
  _Documents(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

const _dispatchWait = Duration(seconds: 10);

Future<void> _waitFor(bool Function() ready, String description) async {
  final timer = Stopwatch()..start();
  while (!ready()) {
    if (timer.elapsed >= _dispatchWait) {
      throw TimeoutException(
          'Timed out waiting for $description', _dispatchWait);
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _ManualDownloads extends CatCatchNotifier {
  _ManualDownloads(super.ref);

  final idsByUrl = <String, String>{};
  final selected = <String>[];
  final confirmed = <String>[];
  void Function(String)? onSelect;
  void Function(String)? onConfirm;

  @override
  String addTask(String url, int expectedDurationSec,
      {String videoFolder = '', String audioFolder = '', String? taskId}) {
    final id = taskId!;
    idsByUrl[url] = id;
    final confirming = url.endsWith('/confirm');
    state = [
      ...state,
      catcatch.CatCatchTask(
        id: id,
        url: url,
        expectedDurationSec: expectedDurationSec,
        createdAt: DateTime(2026),
        detectedMedia: [
          const MediaResource(
              url: 'https://x/one.mp4', name: 'one', ext: 'mp4'),
          if (!url.endsWith('/single'))
            const MediaResource(
                url: 'https://x/two.mp4', name: 'two', ext: 'mp4'),
        ],
        selectedMedia: confirming
            ? const MediaResource(
                url: 'https://x/one.mp4', name: 'one', ext: 'mp4')
            : null,
        metadata: confirming ? {'pendingConfirm': 'special_format'} : {},
        steps: [
          catcatch.StepStatus.running(confirming
              ? catcatch.StepType.converting
              : (url.endsWith('/first') || url.endsWith('/single'))
                  ? catcatch.StepType.userSelecting
                  : catcatch.StepType.fetching),
        ],
      ),
    ];
    return id;
  }

  @override
  void selectMedia(String id, MediaResource media, {String? mergeAudioUrl}) {
    selected.add(id);
    onSelect?.call(id);
    finish(id);
  }

  @override
  void confirmAndContinue(String id) {
    confirmed.add(id);
    onConfirm?.call(id);
    finish(id);
  }

  @override
  void resumeTask(String id) {
    state = [
      for (final task in state)
        task.id == id
            ? task.copyWith(status: catcatch.TaskStatus.running)
            : task,
    ];
  }

  void finish(String id) {
    state = [
      for (final task in state)
        task.id == id
            ? task.copyWith(
                status: catcatch.TaskStatus.completed,
                downloadedFilePath: '/downloads/video.mp4')
            : task,
    ];
  }

  @override
  void removeTask(String id) {
    state = state.where((task) => task.id != id).toList();
  }
}

/// Hold the return of one durable write so controls can race with its await.
class _GatedNotifier extends TaskFlowExecutionNotifier {
  bool Function(List<TaskFlowExecution>)? shouldHold;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<bool> persist() async {
    final hold = shouldHold?.call(state) == true;
    if (hold) shouldHold = null;
    final saved = await super.persist();
    if (hold) {
      entered.complete();
      await release.future;
    }
    return saved;
  }
}

class _Tasks extends TaskListNotifier {
  _Tasks(super.ref);
  ProviderConfigItem? resumedConfig;
  ModelConfig? resumedModel;
  int resumes = 0;
  @override
  void resumeTask(String taskId,
      {ProviderConfigItem? providerConfig, ModelConfig? modelConfig}) {
    resumes++;
    resumedConfig = providerConfig;
    resumedModel = modelConfig;
  }

  @override
  void removeTask(String taskId) {
    state = state.where((t) => t.id != taskId).toList();
  }
}

class _Assistants extends AssistantsNotifier {
  final loaded = Completer<void>();
  @override
  Future<void> get ready => loaded.future;
}

class _Manager extends ChatStreamManager {
  final assistants = <Assistant?>[];
  final entries = <ProviderEntriesState?>[];
  @override
  Future<StreamResult> startStreaming(
      {required String text,
      required String convId,
      required List<ChatMessage> history,
      List<ToolDefinition> tools = const [],
      bool reasoning = false,
      String reasoningEffort = 'medium',
      Map<String, String> reasoningParamValues = const {},
      String? streamingMsgId,
      Assistant? assistant,
      ProviderEntriesState? entriesStateOverride}) async {
    assistants.add(assistant);
    entries.add(entriesStateOverride);
    final reply = ChatMessage(role: 'assistant', content: 'done');
    return StreamResult(
        history: [...history, reply],
        assistantMessage: reply,
        fullReply: reply.content);
  }

  @override
  void cancel([String? convId]) {}
}

ProviderEntriesState _providers(String type, String id,
        {String api = 'api',
        String key = 'old-key',
        String host = 'https://old.invalid',
        Map<String, dynamic> auth = const {},
        double speedMax = 2}) =>
    ProviderEntriesState(entries: [
      ProviderEntry(id: 'entry-$id', type: type, name: 'P', configs: [
        ProviderConfigItem(
            id: 'config-$id',
            providerName: 'P',
            host: host,
            key: key,
            typeConfig: auth,
            models: [
              ModelConfig(id: id, name: 'M', modelId: api, speedMax: speedMax)
            ])
      ])
    ]);

Map<String, String> _reference(String id) =>
    {'configId': 'config-$id', 'modelId': id};
FlowSubTask _step(String type, {FlowPayload? result, String? child}) =>
    FlowSubTask(
        blockTypeKey: type,
        blockLabel: type,
        subTaskId: child ?? 'pending_${type}_0',
        subTaskType: type == 'tts' ? 'synthesis' : 'background',
        status: result == null ? TaskStatus.waiting : TaskStatus.completed,
        result: result);

void main() {
  for (final requested in ['missing API model', 'deleted provider']) {
    test('launch preflight rejects assistant bound to $requested', () async {
      final model = _providers('llm', 'live');
      final assistant = Assistant(
          id: 'assistant',
          name: 'A',
          prompt: 'P',
          defaultModelId: requested == 'deleted provider' ? 'api' : 'missing',
          defaultProviderName: requested == 'deleted provider' ? 'gone' : 'P');
      final flow = TaskFlowDefinition(inputType: IOType.text, blocks: [
        TaskFlowBlock(
            typeKey: BlockType.chat, params: const {'assistantId': 'assistant'})
      ]);
      await expectLater(
          validateTaskFlow(flow, [const FlowRunInput(text: 'input')],
              providers: model, assistants: [assistant]),
          throwsA(isA<TaskFlowValidationException>()
              .having((e) => e.blockIndex, 'blockIndex', 0)
              .having((e) => e.message, 'message', contains('模型'))));
    });
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PathProviderPlatform previous;
  final containers = <ProviderContainer>[];
  late TaskFlowDefinition flow;
  ProviderContainer make(
      {TaskFlowExecutionNotifier? notifier,
      FlowBlockRunner? runner,
      _ManualDownloads Function(Ref)? downloads,
      TaskFlowScheduler? scheduler,
      _Tasks Function(Ref)? tasks,
      _Assistants? assistants,
      _Manager? manager}) {
    final container = ProviderContainer(overrides: [
      if (notifier != null)
        taskFlowExecutionsProvider.overrideWith((ref) => notifier),
      if (runner != null) taskFlowBlockRunnerProvider.overrideWithValue(runner),
      if (downloads != null) catcatchTasksProvider.overrideWith(downloads),
      if (scheduler != null)
        taskFlowSchedulerProvider.overrideWithValue(scheduler),
      if (tasks != null) taskListProvider.overrideWith(tasks),
      if (assistants != null)
        assistantProvider.overrideWith((ref) => assistants),
      if (manager != null) chatStreamManagerProvider.overrideWithValue(manager),
    ]);
    containers.add(container);
    container.read(taskFlowListProvider.notifier).state = [flow];
    return container;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('flow_review_');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Documents(directory.path);
    AppStorage.resetCache();
    SharedPreferences.setMockInitialValues({
      'assistants': jsonEncode(
          [Assistant(id: 'assistant', name: 'A', prompt: 'P').toMap()])
    });
    flow = TaskFlowDefinition(id: 'flow', blocks: [
      TaskFlowBlock(
          typeKey: BlockType.chat, params: {'assistantId': 'assistant'})
    ]);
  });
  tearDown(() async {
    for (final container in containers) {
      container.dispose();
    }
    containers.clear();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    PathProviderPlatform.instance = previous;
    AppStorage.resetCache();
    await directory.delete(recursive: true);
  });

  test('pause during start-state save blocks child dispatch until resume',
      () async {
    final notifier = _GatedNotifier()
      ..shouldHold = (records) =>
          records.any((e) => e.status == FlowExecutionStatus.running);
    var calls = 0;
    final container = make(
        notifier: notifier,
        runner: (b, input, id, step) async {
          calls++;
          return const FlowPayload.text('done');
        });
    final service = container.read(taskFlowExecutionServiceProvider);
    final ids = await service
        .launchFlowMany('flow', [const FlowRunInput(text: 'input')]);
    await notifier.entered.future;
    await service.pauseExecution(ids.single);
    notifier.release.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(calls, 0);
    expect(notifier.execution(ids.single)!.status, FlowExecutionStatus.paused);
    await service.resumeExecution(ids.single);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(calls, 1);
  });

  for (final action in ['cancel', 'pause']) {
    test('$action during resume save cannot revive or unpause the execution',
        () async {
      final original = _providers('tts', 'voice');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('provider_entries',
          jsonEncode(original.entries.map((e) => e.toMap()).toList()));
      flow = flow.copyWith(blocks: [
        TaskFlowBlock(
            typeKey: BlockType.tts, params: {'modelRef': _reference('voice')})
      ]);
      final notifier = _GatedNotifier();
      late _Tasks tasks;
      late ProviderContainer container;
      final done = Completer<FlowPayload>();
      var calls = 0;
      container = make(
          notifier: notifier,
          tasks: (ref) => tasks = _Tasks(ref),
          runner: (b, input, id, step) {
            tasks.state = [
              SynthesisTask(
                  id: 'child',
                  title: 'T',
                  text: input.value,
                  status: TaskStatus.paused,
                  providerConfig: original.entries.single.configs.single,
                  modelConfig:
                      original.entries.single.configs.single.models.single)
            ];
            notifier.updateSubTaskId(id, step.id, 'child');
            calls++;
            return done.future;
          });
      container.read(taskListProvider);
      final service = container.read(taskFlowExecutionServiceProvider);
      final ids = await service
          .launchFlowMany('flow', [const FlowRunInput(text: 'input')]);
      await _waitFor(() => calls == 1, 'initial synthesis dispatch');
      await service.pauseExecution(ids.single);
      notifier.shouldHold = (records) =>
          records.any((e) => e.status == FlowExecutionStatus.running);
      final resume = service.resumeExecution(ids.single);
      await notifier.entered.future.timeout(_dispatchWait);
      if (action == 'cancel') {
        await service.cancelExecution(ids.single);
      } else {
        await service.pauseExecution(ids.single);
      }
      notifier.release.complete();
      await resume;
      done.complete(const FlowPayload.text('done'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(calls, 1);
      expect(tasks.resumes, 0);
      expect(
          notifier.execution(ids.single)!.status,
          action == 'cancel'
              ? FlowExecutionStatus.cancelled
              : FlowExecutionStatus.paused);
    });
  }

  test('cancel during checkpoint resume save prevents a replacement worker',
      () async {
    final notifier = _GatedNotifier();
    var calls = 0;
    final container = make(
        notifier: notifier,
        runner: (b, input, id, step) async {
          calls++;
          throw StateError('fixture failure');
        });
    final service = container.read(taskFlowExecutionServiceProvider);
    final ids = await service
        .launchFlowMany('flow', [const FlowRunInput(text: 'input')]);
    await Future<void>.delayed(const Duration(milliseconds: 25));
    notifier.shouldHold = (records) =>
        records.any((e) => e.status == FlowExecutionStatus.waiting);
    final resume = service.resumeExecution(ids.single);
    await notifier.entered.future;
    await service.cancelExecution(ids.single);
    notifier.release.complete();
    await resume;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(calls, 1);
    expect(
        notifier.execution(ids.single)!.status, FlowExecutionStatus.cancelled);
  });

  for (final action in ['cancel', 'pause']) {
    test('$action during saved artifact read invalidates checkpoint resume',
        () async {
      final file = File('${directory.path}/checkpoint.txt');
      await file.writeAsString('saved text');
      final container = make(
          runner: (b, input, id, step) async => const FlowPayload.text('done'));
      final notifier = container.read(taskFlowExecutionsProvider.notifier);
      final savedFlow = flow.copyWith(blocks: [...flow.blocks, ...flow.blocks]);
      await notifier.addExecutions([
        TaskFlowExecution(
            id: 'read-race',
            flowId: 'flow',
            flowName: 'F',
            status: FlowExecutionStatus.paused,
            inputText: 'original',
            snapshot: FlowLaunchSnapshot.capture(
                savedFlow,
                const ProviderEntriesState(),
                [Assistant(id: 'assistant', name: 'A', prompt: 'P')]),
            subTasks: [
              _step('chat',
                  result: FlowPayload.file(
                      fileReference: file.path, type: IOType.text)),
              _step('chat')
            ])
      ]);
      final service = container.read(taskFlowExecutionServiceProvider);
      final resume = service.resumeExecution('read-race');
      if (action == 'cancel') {
        await service.cancelExecution('read-race');
      } else {
        await service.pauseExecution('read-race');
      }
      await resume;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
          notifier.execution('read-race')!.status,
          action == 'cancel'
              ? FlowExecutionStatus.cancelled
              : FlowExecutionStatus.paused);
    });
  }

  test(
      'untouched batch input stays waiting after pause resume and cold restore',
      () async {
    final active = Completer<FlowPayload>();
    final firstDispatched = Completer<void>();
    final container = make(runner: (b, input, id, step) {
      if (!firstDispatched.isCompleted) firstDispatched.complete();
      return active.future;
    });
    final service = container.read(taskFlowExecutionServiceProvider);
    final ids = await service.launchFlowMany('flow', [
      const FlowRunInput(text: 'first'),
      const FlowRunInput(text: 'second')
    ]);
    await firstDispatched.future.timeout(_dispatchWait);
    await service.pauseExecution(ids.last);
    await service.resumeExecution(ids.last);
    expect(
        container
            .read(taskFlowExecutionsProvider.notifier)
            .execution(ids.last)!
            .status,
        FlowExecutionStatus.waiting);
    service.dispose();
    active.complete(const FlowPayload.text('late'));
    final oldNotifier = container.read(taskFlowExecutionsProvider.notifier);
    await _waitFor(
        () =>
            oldNotifier.execution(ids.first)?.status ==
            FlowExecutionStatus.interrupted,
        'first batch input interruption');
    expect(await oldNotifier.persist(), isTrue);
    final inputs = <String>[];
    final fresh = make(runner: (b, input, id, step) async {
      inputs.add(input.value);
      return const FlowPayload.text('done');
    });
    await fresh
        .read(taskFlowExecutionsProvider.notifier)
        .restoreFromPersistence();
    await fresh
        .read(taskFlowExecutionServiceProvider)
        .restorePendingExecutions();
    await _waitFor(() => inputs.length == 1, 'restored second input dispatch');
    await _waitFor(
        () =>
            fresh
                .read(taskFlowExecutionsProvider.notifier)
                .execution(ids.last)
                ?.status ==
            FlowExecutionStatus.completed,
        'restored second input completion');
    expect(inputs, ['second']);
    expect(
        fresh
            .read(taskFlowExecutionsProvider.notifier)
            .execution(ids.last)!
            .status,
        FlowExecutionStatus.completed);
  });

  test('snapshot preserves assistants whose display names are credential words',
      () {
    final assistants = ['Token', 'Key', 'Secret']
        .map((name) => Assistant(id: name, name: name, prompt: 'public prompt'))
        .toList();
    final snapshot = FlowLaunchSnapshot.capture(
        TaskFlowDefinition(blocks: [
          for (final a in assistants)
            TaskFlowBlock(
                typeKey: BlockType.chat, params: {'assistantId': a.id})
        ]),
        const ProviderEntriesState(),
        assistants);
    expect(snapshot.assistants.map((a) => a.name), ['Token', 'Key', 'Secret']);
  });

  test(
      'assistant snapshot hydrates only same-ID current authentication parameters',
      () {
    Assistant assistant(String id, String secret, String tuning) => Assistant(
        id: id,
        name: 'A',
        prompt: tuning,
        settings: AssistantSettings(customParameters: [
          CustomParameter(name: 'Authorization', type: 'string', value: secret),
          CustomParameter(name: 'publicOption', type: 'string', value: tuning),
        ]));
    final snapshot = FlowLaunchSnapshot.capture(
        flow,
        const ProviderEntriesState(),
        [assistant('assistant', 'old-secret', 'frozen')]);
    expect(jsonEncode(snapshot.toMap()), isNot(contains('old-secret')));
    final hydrated = snapshot.resolveAssistants([
      assistant('other', 'wrong-secret', 'wrong'),
      assistant('assistant', 'new-secret', 'edited'),
    ]) as List<Assistant>;
    expect(hydrated.single.prompt, 'frozen');
    expect(hydrated.single.settings.customParameters.map((p) => p.value),
        ['frozen', 'new-secret']);
    final missing = snapshot
            .resolveAssistants([assistant('other', 'wrong-secret', 'wrong')])
        as List<Assistant>;
    expect(missing.single.settings.customParameters.map((p) => p.value),
        ['frozen']);
  });

  test('cold chat queue waits for live assistant credential hydration',
      () async {
    final assistants = _Assistants();
    final manager = _Manager();
    final container = make(assistants: assistants, manager: manager);
    final frozen = Assistant(
        id: 'assistant',
        name: 'A',
        prompt: 'launch prompt',
        settings: AssistantSettings(customParameters: [
          CustomParameter(
              name: 'Authorization', type: 'string', value: 'old-secret')
        ]));
    final notifier = container.read(taskFlowExecutionsProvider.notifier);
    await notifier.addExecutions([
      TaskFlowExecution(
          id: 'cold',
          flowId: 'flow',
          flowName: 'F',
          status: FlowExecutionStatus.waiting,
          inputText: 'input',
          snapshot: FlowLaunchSnapshot.capture(
              flow, const ProviderEntriesState(), [frozen]),
          subTasks: [_step('chat')])
    ]);
    await container.read(providerEntriesProvider.notifier).ready;
    final restoring = container
        .read(taskFlowExecutionServiceProvider)
        .restorePendingExecutions();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(manager.assistants, isEmpty);
    assistants.state = [
      frozen.copyWith(
          prompt: 'edited',
          settings: AssistantSettings(customParameters: [
            CustomParameter(
                name: 'Authorization', type: 'string', value: 'new-secret')
          ]))
    ];
    assistants.loaded.complete();
    await restoring;
    // Cold dispatch is fire-and-forget; its durable writes can take longer
    // than a fixed delay when the complete suite runs concurrently.
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (
        notifier.execution('cold')!.status != FlowExecutionStatus.completed &&
            DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(manager.assistants.single!.prompt, 'launch prompt');
    expect(manager.assistants.single!.settings.customParameters.single.value,
        'new-secret');
    expect(notifier.execution('cold')!.status, FlowExecutionStatus.completed);
  });

  test(
      'saved chat model uses stable binding despite an earlier duplicate API ID',
      () {
    final selected = _providers('llm', 'selected');
    final assistant = Assistant(
        id: 'assistant',
        name: 'A',
        prompt: 'P',
        defaultModelId: 'api',
        defaultProviderName: 'P');
    final snapshot = FlowLaunchSnapshot.capture(flow, selected, [assistant]);
    final current = ProviderEntriesState(entries: [
      ..._providers('llm', 'competitor', key: 'wrong-key').entries,
      ..._providers('llm', 'selected', key: 'current-key').entries,
    ]);
    final resolved = snapshot.resolveProviders(current);
    final available = flattenProviderModels(resolved, 'llm');
    expect(available.map((m) => m.model.id), ['selected']);
    expect(available.single.config.key, 'current-key');
  });

  test('launch snapshot keeps the chat adapter selected model', () async {
    final providers = ProviderEntriesState(entries: [
      ProviderEntry(id: 'llm', type: 'llm', name: 'P', configs: [
        ProviderConfigItem(
            id: 'config',
            providerName: 'P',
            host: 'https://example.invalid',
            key: 'test-key',
            models: [
              ModelConfig(id: 'first', name: 'First', modelId: 'first-api'),
              ModelConfig(
                  id: 'selected', name: 'Second', modelId: 'second-api'),
            ])
      ])
    ]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('provider_entries',
        jsonEncode(providers.entries.map((e) => e.toMap()).toList()));
    final manager = _Manager();
    manager.adapter.selectModel(providers, 0, 1);
    final container = make(
        manager: manager,
        runner: (b, input, id, step) async => const FlowPayload.text('done'));
    final ids = await container
        .read(taskFlowExecutionServiceProvider)
        .launchFlowMany('flow', [const FlowRunInput(text: 'input')]);
    final snapshot = container
        .read(taskFlowExecutionsProvider.notifier)
        .execution(ids.single)!
        .snapshot!;
    expect(
        (snapshot.toMap()['chatModels'] as List).single['modelId'], 'selected');
  });

  test('explicit assistant model ignores stale default provider name', () {
    final first = _providers('llm', 'first');
    final second = _providers('llm', 'second');
    final firstConfig = first.entries.single.configs.single;
    final secondConfig = second.entries.single.configs.single;
    secondConfig.providerName = 'Other';
    final providers = ProviderEntriesState(entries: [
      ProviderEntry(
          id: 'llm',
          type: 'llm',
          name: 'P',
          configs: [firstConfig, secondConfig])
    ]);
    final assistant = Assistant(
        id: 'assistant',
        name: 'A',
        prompt: 'P',
        modelId: 'api',
        defaultProviderName: 'Other');
    final snapshot = FlowLaunchSnapshot.capture(flow, providers, [assistant]);
    expect((snapshot.toMap()['chatModels'] as List).single['configId'],
        'config-first');
  });

  test('legacy assistant display name takes precedence over global selection',
      () {
    final providers = ProviderEntriesState(entries: [
      ProviderEntry(id: 'llm', type: 'llm', name: 'P', configs: [
        ProviderConfigItem(
            id: 'config',
            providerName: 'P',
            host: 'https://example.invalid',
            key: 'test-key',
            models: [
              ModelConfig(id: 'global', name: 'Global', modelId: 'global-api'),
              ModelConfig(id: 'named', name: 'Named', modelId: 'named-api'),
            ])
      ])
    ]);
    final assistant = Assistant(
        id: 'assistant',
        name: 'Legacy',
        prompt: 'P',
        defaultModelName: 'Named | P');
    final snapshot = FlowLaunchSnapshot.capture(flow, providers, [assistant],
        selectedChatModel: {'configId': 'config', 'modelId': 'global'});
    expect((snapshot.toMap()['chatModels'] as List).single['modelId'], 'named');
  });

  test('unbound assistant without a selected chat model fails before queueing',
      () async {
    final providers = _providers('llm', 'first');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('provider_entries',
        jsonEncode(providers.entries.map((e) => e.toMap()).toList()));
    final container = make(manager: _Manager());
    final service = container.read(taskFlowExecutionServiceProvider);
    await expectLater(
        service.launchFlowMany('flow', [const FlowRunInput(text: 'input')]),
        throwsA(isA<TaskFlowValidationException>()
            .having((e) => e.blockIndex, 'chat step', 0)
            .having((e) => e.message, 'selection hint', contains('模型'))));
    expect(container.read(taskFlowExecutionsProvider), isEmpty);
  });

  test('paused download releases its scheduler slot until resumed', () async {
    flow = TaskFlowDefinition(
        id: 'flow', blocks: [TaskFlowBlock(typeKey: BlockType.catcatch)]);
    final first = Completer<FlowPayload>();
    final second = Completer<FlowPayload>();
    final dispatched = <String>[];
    final container = make(runner: (b, input, id, step) {
      dispatched.add(input.value);
      return input.value.endsWith('/first') ? first.future : second.future;
    });
    final service = container.read(taskFlowExecutionServiceProvider);
    final scheduler = container.read(taskFlowSchedulerProvider);
    final firstId = (await service.launchFlowMany(
            'flow', [const FlowRunInput(text: 'https://example.com/first')]))
        .single;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await service.launchFlowMany(
        'flow', [const FlowRunInput(text: 'https://example.com/second')]);
    expect(dispatched, ['https://example.com/first']);
    expect(scheduler.activeWeight, 2);
    await service.pauseExecution(firstId);
    expect(scheduler.holds(firstId), isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 550));
    expect(dispatched,
        ['https://example.com/first', 'https://example.com/second']);
    final resuming = service.resumeExecution(firstId);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(scheduler.activeWeight, 2);
    expect(scheduler.queuedCount, 1);
    expect(
        container
            .read(taskFlowExecutionsProvider.notifier)
            .execution(firstId)!
            .status,
        isNot(FlowExecutionStatus.running));
    await service.pauseExecution(firstId);
    await resuming;
    expect(scheduler.queuedCount, 0);
    final resumed = service.resumeExecution(firstId);
    second.complete(const FlowPayload.text('done'));
    await resumed;
    expect(scheduler.activeWeight, 2);
    first.complete(const FlowPayload.text('done'));
  });

  test('manual CatCatch wait frees its slot and selection reacquires FIFO',
      () async {
    flow = TaskFlowDefinition(
        id: 'flow', blocks: [TaskFlowBlock(typeKey: BlockType.catcatch)]);
    late _ManualDownloads downloads;
    final container = make(
        scheduler: TaskFlowScheduler(coreCount: 4),
        downloads: (ref) {
          downloads = _ManualDownloads(ref);
          return downloads;
        });
    final service = container.read(taskFlowExecutionServiceProvider);
    final scheduler = container.read(taskFlowSchedulerProvider);
    final firstId = (await service.launchFlowMany(
            'flow', [const FlowRunInput(text: 'https://example.com/first')]))
        .single;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final firstTaskId = downloads.idsByUrl['https://example.com/first']!;
    expect(scheduler.holds(firstId), isTrue);
    final secondId = (await service.launchFlowMany(
            'flow', [const FlowRunInput(text: 'https://example.com/second')]))
        .single;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(scheduler.queuedCount, 1);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(scheduler.holds(firstId), isFalse);
    expect(
        downloads.idsByUrl.containsKey('https://example.com/second'), isTrue);
    expect(scheduler.holds(secondId), isTrue);

    final heldAtSelection = <bool>[];
    downloads.onSelect = (_) => heldAtSelection.add(scheduler.holds(firstId));
    const media =
        MediaResource(url: 'https://x/one.mp4', name: 'one', ext: 'mp4');
    final selecting = service.performManualCatCatchAction(firstTaskId, true,
        (notifier) => notifier.selectMedia(firstTaskId, media));
    final duplicate = service.performManualCatCatchAction(firstTaskId, true,
        (notifier) => notifier.selectMedia(firstTaskId, media));
    expect(await duplicate, isFalse);
    expect(scheduler.queuedCount, 1);
    expect(downloads.selected, isEmpty);
    downloads.finish(downloads.idsByUrl['https://example.com/second']!);
    expect(await selecting.timeout(const Duration(seconds: 3)), isTrue);
    expect(heldAtSelection, [true]);
    expect(downloads.selected, [firstTaskId]);
  });

  test('special-format confirmation also yields and reacquires its slot',
      () async {
    flow = TaskFlowDefinition(
        id: 'flow', blocks: [TaskFlowBlock(typeKey: BlockType.catcatch)]);
    late _ManualDownloads downloads;
    final container = make(
        scheduler: TaskFlowScheduler(coreCount: 4),
        downloads: (ref) {
          downloads = _ManualDownloads(ref);
          return downloads;
        });
    final service = container.read(taskFlowExecutionServiceProvider);
    final scheduler = container.read(taskFlowSchedulerProvider);
    final confirmId = (await service.launchFlowMany(
            'flow', [const FlowRunInput(text: 'https://example.com/confirm')]))
        .single;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(scheduler.holds(confirmId), isTrue);
    final secondId = (await service.launchFlowMany(
            'flow', [const FlowRunInput(text: 'https://example.com/second')]))
        .single;
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final taskId = downloads.idsByUrl['https://example.com/confirm']!;
    expect(scheduler.holds(confirmId), isFalse);
    expect(scheduler.holds(secondId), isTrue);

    final heldAtConfirm = <bool>[];
    downloads.onConfirm = (_) => heldAtConfirm.add(scheduler.holds(confirmId));
    final confirming = service.performManualCatCatchAction(
        taskId, false, (notifier) => notifier.confirmAndContinue(taskId));
    expect(scheduler.queuedCount, 1);
    expect(downloads.confirmed, isEmpty);
    downloads.finish(downloads.idsByUrl['https://example.com/second']!);
    expect(await confirming.timeout(const Duration(seconds: 3)), isTrue);
    expect(heldAtConfirm, [true]);
    expect(downloads.confirmed, [taskId]);
  });

  test('resuming a paused manual wait keeps the scheduler slot free', () async {
    flow = TaskFlowDefinition(
        id: 'flow', blocks: [TaskFlowBlock(typeKey: BlockType.catcatch)]);
    late _ManualDownloads downloads;
    final container = make(
        scheduler: TaskFlowScheduler(coreCount: 4),
        downloads: (ref) {
          downloads = _ManualDownloads(ref);
          return downloads;
        });
    final service = container.read(taskFlowExecutionServiceProvider);
    final scheduler = container.read(taskFlowSchedulerProvider);
    container.read(catcatchTasksProvider);
    final id = (await service.launchFlowMany(
            'flow', [const FlowRunInput(text: 'https://example.com/first')]))
        .single;
    await _waitFor(
        () =>
            downloads.idsByUrl.containsKey('https://example.com/first') &&
            !scheduler.holds(id),
        'manual selection slot release');
    expect(scheduler.holds(id), isFalse);
    await service.pauseExecution(id);
    await service.resumeExecution(id).timeout(const Duration(seconds: 2));
    expect(scheduler.holds(id), isFalse);
    expect(
        container
            .read(taskFlowExecutionsProvider.notifier)
            .execution(id)!
            .status,
        FlowExecutionStatus.running);
    final taskId = downloads.idsByUrl['https://example.com/first']!;
    expect(container.read(catcatchTasksProvider).single.id, taskId);
    await service.cancelExecution(id);
  });

  test('a single detected resource does not yield a live download slot',
      () async {
    flow = TaskFlowDefinition(
        id: 'flow', blocks: [TaskFlowBlock(typeKey: BlockType.catcatch)]);
    late _ManualDownloads downloads;
    final container = make(
        scheduler: TaskFlowScheduler(coreCount: 4),
        downloads: (ref) {
          downloads = _ManualDownloads(ref);
          return downloads;
        });
    final service = container.read(taskFlowExecutionServiceProvider);
    final scheduler = container.read(taskFlowSchedulerProvider);
    final id = (await service.launchFlowMany(
            'flow', [const FlowRunInput(text: 'https://example.com/single')]))
        .single;
    await Future<void>.delayed(const Duration(milliseconds: 550));
    expect(scheduler.holds(id), isTrue);
    expect(
        downloads.idsByUrl.containsKey('https://example.com/single'), isTrue);
    await service.cancelExecution(id);
  });

  for (final stop in ['pause', 'cancel']) {
    test('$stop while CatCatch selection queues prevents selection', () async {
      flow = TaskFlowDefinition(
          id: 'flow', blocks: [TaskFlowBlock(typeKey: BlockType.catcatch)]);
      late _ManualDownloads downloads;
      final container = make(
          scheduler: TaskFlowScheduler(coreCount: 4),
          downloads: (ref) {
            downloads = _ManualDownloads(ref);
            return downloads;
          });
      final service = container.read(taskFlowExecutionServiceProvider);
      final scheduler = container.read(taskFlowSchedulerProvider);
      final firstId = (await service.launchFlowMany(
              'flow', [const FlowRunInput(text: 'https://example.com/first')]))
          .single;
      await Future<void>.delayed(const Duration(milliseconds: 550));
      final firstTaskId = downloads.idsByUrl['https://example.com/first']!;
      await service.launchFlowMany(
          'flow', [const FlowRunInput(text: 'https://example.com/second')]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      const media =
          MediaResource(url: 'https://x/one.mp4', name: 'one', ext: 'mp4');
      final selecting = service.performManualCatCatchAction(firstTaskId, true,
          (notifier) => notifier.selectMedia(firstTaskId, media));
      expect(scheduler.queuedCount, 1);
      if (stop == 'pause') {
        await service.pauseExecution(firstId);
      } else {
        await service.cancelExecution(firstId);
      }
      expect(await selecting.timeout(const Duration(seconds: 3)), isFalse);
      expect(downloads.selected, isEmpty);
      expect(scheduler.queuedCount, 0);
      expect(
          await service.performManualCatCatchAction(firstTaskId, true,
              (notifier) => notifier.selectMedia(firstTaskId, media)),
          isFalse);
    });
  }

  test('pausing a queued heavy flow unblocks a lighter flow', () async {
    final chatFlow = TaskFlowDefinition(id: 'chat', blocks: [
      TaskFlowBlock(
          typeKey: BlockType.chat, params: {'assistantId': 'assistant'})
    ]);
    final downloadFlow = TaskFlowDefinition(
        id: 'download', blocks: [TaskFlowBlock(typeKey: BlockType.catcatch)]);
    final first = Completer<FlowPayload>();
    final dispatched = <String>[];
    final container = make(runner: (b, input, id, step) {
      dispatched.add(input.value);
      return input.value == 'first'
          ? first.future
          : Future.value(const FlowPayload.text('done'));
    });
    container.read(taskFlowListProvider.notifier).state = [
      chatFlow,
      downloadFlow
    ];
    final service = container.read(taskFlowExecutionServiceProvider);
    final scheduler = container.read(taskFlowSchedulerProvider);
    await service.launchFlowMany('chat', [const FlowRunInput(text: 'first')]);
    await _waitFor(() => dispatched.contains('first'), 'first chat dispatch');
    final queued = (await service.launchFlowMany('download',
            [const FlowRunInput(text: 'https://example.com/download')]))
        .single;
    await _waitFor(
        () => scheduler.queuedCount == 1, 'heavy download queue entry');
    expect(scheduler.queuedCount, 1);
    try {
      await service.pauseExecution(queued);
      expect(scheduler.queuedCount, 0);
      await service.launchFlowMany('chat', [const FlowRunInput(text: 'third')]);
      await _waitFor(() => dispatched.length == 2, 'third chat dispatch');
      expect(dispatched, ['first', 'third']);
      await service.resumeExecution(queued);
      first.complete(const FlowPayload.text('done'));
      await _waitFor(
          () => dispatched.length == 3, 'resumed heavy download dispatch');
      expect(dispatched, ['first', 'third', 'https://example.com/download']);
    } finally {
      if (!first.isCompleted) first.complete(const FlowPayload.text('done'));
      await service.cancelExecution(queued);
    }
  });

  test('provider resolution can validate only the remaining blocks', () {
    final prefix = TaskFlowBlock(
        typeKey: BlockType.asr, params: {'modelRef': _reference('asr')});
    final suffix = TaskFlowBlock(
        typeKey: BlockType.tts, params: {'modelRef': _reference('tts')});
    final original = ProviderEntriesState(entries: [
      ..._providers('asr', 'asr').entries,
      ..._providers('tts', 'tts').entries
    ]);
    final snapshot = FlowLaunchSnapshot.capture(
        TaskFlowDefinition(blocks: [prefix, suffix]), original, []);
    final current = _providers('tts', 'tts', key: 'fresh-key');
    final resolved = snapshot.resolveProviders(current, blocks: [suffix])
        as ProviderEntriesState;
    expect(resolveProviderModel(resolved, 'tts', _reference('tts'))!.config.key,
        'fresh-key');
    expect(() => snapshot.resolveProviders(current), throwsStateError);
  });

  test('spaced credential names are absent from snapshots and hydrated live',
      () {
    ProviderEntriesState configured(
        String secret, String header, String tuning) {
      final providers = _providers('tts', 'voice');
      final config = providers.entries.single.configs.single;
      config.typeConfig = {'X API Key': header, 'voice': tuning};
      config.models.single.customParams = [
        CustomParam(paramName: 'API Key', defaultValue: secret),
        CustomParam(paramName: 'temperature', defaultValue: tuning),
      ];
      return providers;
    }

    final launch = configured('old-secret', 'old-header', '0.5');
    final block = TaskFlowBlock(
        typeKey: BlockType.tts, params: {'modelRef': _reference('voice')});
    final snapshot = FlowLaunchSnapshot.capture(
        TaskFlowDefinition(blocks: [block]), launch, []);
    final encoded = jsonEncode(snapshot.toMap());
    expect(encoded, isNot(contains('old-secret')));
    expect(encoded, isNot(contains('old-header')));
    final current = configured('fresh-secret', 'fresh-header', '0.9');
    final resolved = snapshot.resolveProviders(current);
    final config = resolved.entries.single.configs.single;
    expect(config.typeConfig['X API Key'], 'fresh-header');
    expect(config.typeConfig['voice'], '0.5');
    expect({
      for (final param in config.models.single.customParams)
        param.paramName: param.defaultValue
    }, {
      'API Key': 'fresh-secret',
      'temperature': '0.5'
    });
  });

  test('checkpoint resume reuses successful ASR after its model was deleted',
      () async {
    final providers = _providers('asr', 'asr');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('provider_entries',
        jsonEncode(providers.entries.map((e) => e.toMap()).toList()));
    final prefix = TaskFlowBlock(
        typeKey: BlockType.asr, params: {'modelRef': _reference('asr')});
    final savedFlow = flow
        .copyWith(inputType: IOType.audio, blocks: [prefix, ...flow.blocks]);
    final snapshot = FlowLaunchSnapshot.capture(savedFlow, providers,
        [Assistant(id: 'assistant', name: 'A', prompt: 'P')]);
    final inputs = <String>[];
    final container = make(runner: (b, input, id, step) async {
      inputs.add(input.value);
      return const FlowPayload.text('done');
    });
    final notifier = container.read(taskFlowExecutionsProvider.notifier);
    await notifier.addExecutions([
      TaskFlowExecution(
          id: 'saved',
          flowId: 'flow',
          flowName: 'Saved',
          status: FlowExecutionStatus.interrupted,
          snapshot: snapshot,
          inputText: '/deleted-original.wav',
          subTasks: [
            _step('asr', result: const FlowPayload.text('transcribed')),
            _step('chat'),
          ])
    ]);
    await container.read(providerEntriesProvider.notifier).ready;
    container.read(providerEntriesProvider.notifier).state =
        const ProviderEntriesState();
    await container
        .read(taskFlowExecutionServiceProvider)
        .resumeExecution('saved');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(inputs, ['transcribed']);
    expect(notifier.execution('saved')!.status, FlowExecutionStatus.completed);
  });

  test('checkpoint resume preserves audio MIME for an MP4 media result',
      () async {
    final media = await File('${directory.path}/recording.mp4').writeAsBytes([
      0,
      0,
      0,
      24,
      ...ascii.encode('ftypisom'),
      0,
      0,
      0,
      1,
      ...ascii.encode('isommp41')
    ]);
    flow = flow.copyWith(blocks: [
      TaskFlowBlock(typeKey: BlockType.catcatch, params: {'audioOutput': true}),
      ...flow.blocks,
    ]);
    final snapshot = FlowLaunchSnapshot.capture(
        flow,
        const ProviderEntriesState(),
        [Assistant(id: 'assistant', name: 'A', prompt: 'P')]);
    final received = <FlowPayload>[];
    final container = make(runner: (block, input, id, step) async {
      received.add(input);
      return const FlowPayload.text('done');
    });
    final notifier = container.read(taskFlowExecutionsProvider.notifier);
    final saved = TaskFlowExecution(
        id: 'saved',
        flowId: flow.id,
        flowName: flow.name,
        status: FlowExecutionStatus.interrupted,
        snapshot: snapshot,
        inputText: 'https://example.com/audio',
        subTasks: [
          _step('catcatch',
              result: FlowPayload.file(
                  fileReference: media.path,
                  type: IOType.audio,
                  mimeType: 'audio/mp4')),
          _step('chat'),
        ]);
    await notifier.addExecutions([TaskFlowExecution.fromMap(saved.toMap())]);

    await container
        .read(taskFlowExecutionServiceProvider)
        .resumeExecution('saved');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(received, hasLength(1));
    expect(received.single.type, IOType.audio);
    expect(received.single.mimeType, 'audio/mp4');
    expect(notifier.execution('saved')!.status, FlowExecutionStatus.completed);
  });

  test(
      'audio MP4 launch persists MIME for dispatch, retry, and prefix-0 resume',
      () async {
    final media = await File('${directory.path}/recording.mp4').writeAsBytes([
      0,
      0,
      0,
      24,
      ...ascii.encode('ftypisom'),
      0,
      0,
      0,
      1,
      ...ascii.encode('isommp41')
    ]);
    final providers = _providers('asr', 'voice');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('provider_entries',
        jsonEncode(providers.entries.map((e) => e.toMap()).toList()));
    flow = TaskFlowDefinition(id: 'flow', inputType: IOType.audio, blocks: [
      TaskFlowBlock(
          typeKey: BlockType.asr, params: {'modelRef': _reference('voice')})
    ]);
    final received = <FlowPayload>[];
    final container = make(runner: (block, input, id, step) async {
      received.add(input);
      if (received.length < 3) throw StateError('retryable');
      return const FlowPayload.text('done');
    });
    final service = container.read(taskFlowExecutionServiceProvider);
    final ids = await service.launchFlowMany(
        'flow', [FlowRunInput(text: media.path, mimeType: 'audio/mp4')]);
    final notifier = container.read(taskFlowExecutionsProvider.notifier);
    await _waitFor(
        () =>
            received.length == 1 &&
            notifier.execution(ids.single)?.status ==
                FlowExecutionStatus.failed,
        'initial audio MP4 failure');
    final original = container.read(taskFlowExecutionsProvider).single;
    expect(original.toMap()['inputMimeType'], 'audio/mp4');
    expect(received.single.mimeType, 'audio/mp4');
    expect(flowFileMimeType(media.path, mimeType: received.single.mimeType),
        'audio/mp4');

    final retryIds = await service.retryExecution(ids.single);
    await _waitFor(
        () =>
            received.length == 2 &&
            notifier.execution(retryIds.single)?.status ==
                FlowExecutionStatus.failed,
        'snapshot audio MP4 retry');
    expect(received[1].mimeType, 'audio/mp4');
    expect(
        container
            .read(taskFlowExecutionsProvider.notifier)
            .execution(retryIds.single)!
            .inputMimeType,
        'audio/mp4');

    await service.resumeExecution(ids.single);
    await _waitFor(
        () =>
            received.length == 3 &&
            notifier.execution(ids.single)?.status ==
                FlowExecutionStatus.completed,
        'prefix-zero audio MP4 resume');
    expect(received[2].type, IOType.audio);
    expect(received[2].mimeType, 'audio/mp4');

    final latestIds =
        await service.retryExecution(ids.single, useLatestConfiguration: true);
    await _waitFor(
        () =>
            received.length == 4 &&
            notifier.execution(latestIds.single)?.status ==
                FlowExecutionStatus.completed,
        'latest-configuration audio MP4 retry');
    expect(received[3].mimeType, 'audio/mp4');
    expect(
        container
            .read(taskFlowExecutionsProvider.notifier)
            .execution(latestIds.single)!
            .inputMimeType,
        'audio/mp4');
    expect(
        TaskFlowExecution.fromMap({
          'flowId': 'legacy',
          'flowName': 'Legacy',
        }).inputMimeType,
        isNull);
  });

  test('cold restored audio MP4 dispatch uses persisted input MIME', () async {
    final media = await File('${directory.path}/recording.mp4').writeAsBytes([
      0,
      0,
      0,
      24,
      ...ascii.encode('ftypisom'),
      0,
      0,
      0,
      1,
      ...ascii.encode('isommp41')
    ]);
    flow = TaskFlowDefinition(
        id: 'flow',
        inputType: IOType.audio,
        blocks: [TaskFlowBlock(typeKey: BlockType.asr)]);
    final snapshot = FlowLaunchSnapshot.capture(
        flow, const ProviderEntriesState(), const []);
    final received = <FlowPayload>[];
    final container = make(runner: (block, input, id, step) async {
      received.add(input);
      return const FlowPayload.text('done');
    });
    final notifier = container.read(taskFlowExecutionsProvider.notifier);
    await notifier.addExecutions([
      TaskFlowExecution(
          id: 'cold',
          flowId: flow.id,
          flowName: flow.name,
          status: FlowExecutionStatus.waiting,
          snapshot: snapshot,
          inputText: media.path,
          inputMimeType: 'audio/mp4',
          subTasks: [_step('asr')])
    ]);
    notifier.state = [];
    await notifier.restoreFromPersistence();
    await container
        .read(taskFlowExecutionServiceProvider)
        .restorePendingExecutions();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(received.single.type, IOType.audio);
    expect(received.single.mimeType, 'audio/mp4');
  });

  test(
      'warm synthesis resume refreshes credentials and preserves captured tuning',
      () async {
    final original = _providers('tts', 'voice',
        auth: {'Authorization': 'old-auth'}, speedMax: 2);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('provider_entries',
        jsonEncode(original.entries.map((e) => e.toMap()).toList()));
    flow = flow.copyWith(blocks: [
      TaskFlowBlock(
          typeKey: BlockType.tts, params: {'modelRef': _reference('voice')})
    ]);
    late _Tasks tasks;
    final result = Completer<FlowPayload>();
    late ProviderContainer container;
    container = make(
        tasks: (ref) => tasks = _Tasks(ref),
        runner: (b, input, id, step) {
          tasks.state = [
            SynthesisTask(
                id: 'child',
                title: 'T',
                text: input.value,
                status: TaskStatus.paused,
                providerConfig: original.entries.single.configs.single,
                modelConfig:
                    original.entries.single.configs.single.models.single)
          ];
          container
              .read(taskFlowExecutionsProvider.notifier)
              .updateSubTaskId(id, step.id, 'child');
          return result.future;
        });
    container.read(taskListProvider);
    final service = container.read(taskFlowExecutionServiceProvider);
    final ids = await service
        .launchFlowMany('flow', [const FlowRunInput(text: 'input')]);
    await _waitFor(
        () =>
            container
                .read(taskFlowExecutionsProvider.notifier)
                .execution(ids.single)
                ?.subTasks
                .single
                .subTaskId ==
            'child',
        'initial synthesis child dispatch');
    await service.pauseExecution(ids.single);
    container.read(providerEntriesProvider.notifier).state = _providers(
        'tts', 'voice',
        key: 'new-key',
        host: 'https://new.invalid',
        auth: {'Authorization': 'new-auth'},
        speedMax: 9);
    await service.resumeExecution(ids.single);
    expect(tasks.resumes, 1);
    expect(tasks.resumedConfig?.key, 'new-key');
    expect(tasks.resumedConfig?.host, 'https://new.invalid');
    expect(tasks.resumedConfig?.typeConfig['Authorization'], 'new-auth');
    expect(tasks.resumedModel?.speedMax, 2);
    await service.cancelExecution(ids.single);
    result.complete(const FlowPayload.text('late'));
  });

  test(
      'synthesis notifier resumes with supplied configs without changing task inputs',
      () async {
    final container = make();
    final tasks = container.read(taskListProvider.notifier);
    final original = _providers('tts', 'voice');
    tasks.state = [
      SynthesisTask(
          id: 'child',
          title: 'T',
          text: 'input',
          status: TaskStatus.paused,
          providerConfig: original.entries.single.configs.single,
          modelConfig: original.entries.single.configs.single.models.single,
          customParams: {'voice': 'launch-voice', 'speed': '1.2'},
          folder: 'launch-folder')
    ];
    final current =
        _providers('tts', 'voice', key: 'new-key', host: 'https://new.invalid');
    tasks.resumeTask('child',
        providerConfig: current.entries.single.configs.single,
        modelConfig: current.entries.single.configs.single.models.single);
    expect(tasks.state.single.providerConfig.key, 'new-key');
    expect(tasks.state.single.providerConfig.host, 'https://new.invalid');
    expect(tasks.state.single.text, 'input');
    expect(tasks.state.single.customParams,
        {'voice': 'launch-voice', 'speed': '1.2'});
    expect(tasks.state.single.folder, 'launch-folder');
    tasks.removeTask('child');
  });
}
