import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/flow_payload.dart';
import 'package:stroom/task_flow/models/flow_launch_snapshot.dart';
import 'package:stroom/task_flow/services/task_flow_validator.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/utils/provider_models.dart';
import 'package:stroom/services/flow_execution_migration.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/providers/task_flow_provider.dart';
import 'package:stroom/task_flow/services/task_flow_execution_service.dart';

class _Documents extends PathProviderPlatform {
  _Documents(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _CompletionFailNotifier extends TaskFlowExecutionNotifier {
  @override
  Future<bool> persist() {
    if (state.any((e) => e.status == FlowExecutionStatus.completed))
      return Future.value(false);
    return super.persist();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late PathProviderPlatform previous;
  late ProviderContainer container;
  late List<String> dispatches;
  late Completer<FlowPayload> first;
  Future<FlowPayload> Function(TaskFlowBlock, FlowPayload, String, FlowSubTask)?
      runner;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('flow_queue_');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Documents(dir.path);
    AppStorage.resetCache();
    SharedPreferences.setMockInitialValues({
      'assistants': jsonEncode(
          [Assistant(id: 'assistant', name: 'A', prompt: 'Prompt').toMap()]),
    });
    dispatches = [];
    runner = null;
    first = Completer<FlowPayload>();
    container = ProviderContainer(overrides: [
      taskFlowBlockRunnerProvider.overrideWithValue((block, input, id, step) {
        dispatches.add('${block.params['marker']}:${input.value}');
        if (runner != null) return runner!(block, input, id, step);
        return dispatches.length == 1
            ? first.future
            : Future.value(FlowPayload.fromValue('done', IOType.text));
      }),
    ]);
    container.read(taskFlowListProvider.notifier).state = [
      TaskFlowDefinition(id: 'flow', name: 'Flow', blocks: [
        TaskFlowBlock(typeKey: BlockType.chat, params: {
          'assistantId': 'assistant',
          'marker': 'original',
        }),
        TaskFlowBlock(
            typeKey: BlockType.chat, params: {'assistantId': 'assistant'}),
      ]),
    ];
  });

  tearDown(() async {
    container.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    PathProviderPlatform.instance = previous;
    AppStorage.resetCache();
    await dir.delete(recursive: true);
  });

  test('batch submission saves every waiting input before dispatch', () async {
    final service = container.read(taskFlowExecutionServiceProvider);
    final ids = await service.launchFlowMany('flow', [
      const FlowRunInput(text: 'one'),
      const FlowRunInput(text: 'two'),
    ]);
    final saved = jsonDecode(
            await File('${dir.path}/task_flows/executions.json').readAsString())
        as List;
    expect(ids, hasLength(2));
    expect(saved.map((e) => e['inputText']).toSet(), {'one', 'two'});
    expect(saved.every((e) => e['snapshot'] != null), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await service
        .cancelBatch(container.read(taskFlowExecutionsProvider).first.batchId!);
    first.complete(FlowPayload.fromValue('late', IOType.text));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(dispatches, hasLength(1));
    expect(
        container
            .read(taskFlowExecutionsProvider)
            .every((e) => e.status == FlowExecutionStatus.cancelled),
        isTrue);
  });

  test(
      'pause preserves active step and resume advances only after checkpoint save',
      () async {
    final service = container.read(taskFlowExecutionServiceProvider);
    final ids =
        await service.launchFlowMany('flow', [const FlowRunInput(text: 'one')]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await service.pauseExecution(ids.single);
    first.complete(FlowPayload.fromValue('prefix', IOType.text));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(dispatches, hasLength(1));
    expect(container.read(taskFlowExecutionsProvider).single.status,
        FlowExecutionStatus.paused);
    await service.resumeExecution(ids.single);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(dispatches, ['original:one', 'null:prefix']);
    expect(container.read(taskFlowExecutionsProvider).single.status,
        FlowExecutionStatus.completed);
  });

  test('removing all saved records prevents later batch inputs', () async {
    final service = container.read(taskFlowExecutionServiceProvider);
    final ids = await service.launchFlowMany('flow',
        [const FlowRunInput(text: 'one'), const FlowRunInput(text: 'two')]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final notifier = container.read(taskFlowExecutionsProvider.notifier);
    for (final id in ids) {
      notifier.removeExecution(id);
    }
    first.complete(FlowPayload.fromValue('late', IOType.text));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(dispatches, hasLength(1));
    expect(notifier.state, isEmpty);
  });

  test('failed submission persistence prevents every dispatch', () async {
    await File('${dir.path}/task_flows').writeAsString('blocked');
    await expectLater(
        container
            .read(taskFlowExecutionServiceProvider)
            .launchFlowMany('flow', [const FlowRunInput(text: 'one')]),
        throwsA(isA<TaskFlowPersistenceException>()));
    expect(dispatches, isEmpty);
    expect(container.read(taskFlowExecutionsProvider).single.status,
        FlowExecutionStatus.interrupted);
  });
  test(
      'snapshot retry preserves launch parameters after original is edited; latest retry is explicit',
      () async {
    final service = container.read(taskFlowExecutionServiceProvider);
    final ids =
        await service.launchFlowMany('flow', [const FlowRunInput(text: 'one')]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    first.complete(FlowPayload.fromValue('prefix', IOType.text));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final flows = container.read(taskFlowListProvider.notifier);
    flows.state = [
      flows.state.single.updateBlockParams(
          flows.state.single.blocks.first.id, {'marker': 'edited'})
    ];
    await service.retryExecution(ids.single);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(dispatches[2], 'original:one');
    await service.retryExecution(ids.single, useLatestConfiguration: true);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(dispatches[4], 'edited:one');
  });

  test('resume reuses only successful prefix and reads its persisted output',
      () async {
    runner = (block, input, id, step) async {
      if (dispatches.length == 2) throw StateError('second failed');
      return FlowPayload.fromValue(
          dispatches.length == 1 ? 'checkpoint' : 'done', IOType.text);
    };
    final service = container.read(taskFlowExecutionServiceProvider);
    final ids =
        await service.launchFlowMany('flow', [const FlowRunInput(text: 'one')]);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    final failed = container.read(taskFlowExecutionsProvider).single;
    expect(failed.status, FlowExecutionStatus.failed);
    expect(failed.subTasks.first.result!.value, 'checkpoint');
    expect(failed.subTasks.last.outcome, FlowStepOutcome.failed);
    await service.resumeExecution(ids.single);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(dispatches, ['original:one', 'null:checkpoint', 'null:checkpoint']);
    expect(container.read(taskFlowExecutionsProvider).single.status,
        FlowExecutionStatus.completed);
  });

  test('resume checks saved artifacts before starting remaining steps',
      () async {
    final missing = '${dir.path}/missing.wav';
    runner = (block, input, id, step) async {
      if (dispatches.length == 1)
        return FlowPayload.file(fileReference: missing, type: IOType.audio);
      throw StateError('suffix failed');
    };
    final service = container.read(taskFlowExecutionServiceProvider);
    final ids =
        await service.launchFlowMany('flow', [const FlowRunInput(text: 'one')]);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    await expectLater(service.resumeExecution(ids.single),
        throwsA(isA<TaskFlowValidationException>()));
    expect(dispatches, hasLength(2));
    expect(container.read(taskFlowExecutionsProvider).single.status,
        FlowExecutionStatus.failed);
  });

  test('restored pending records dispatch with saved input and snapshot',
      () async {
    final notifier = container.read(taskFlowExecutionsProvider.notifier);
    final flow = container.read(taskFlowListProvider).single;
    final saved = TaskFlowExecution(
        id: 'restored',
        flowId: flow.id,
        flowName: flow.name,
        status: FlowExecutionStatus.waiting,
        inputText: 'saved input',
        snapshot: FlowLaunchSnapshot.capture(flow, const ProviderEntriesState(),
            [Assistant(id: 'assistant', name: 'A', prompt: 'P')]),
        subTasks: flow.blocks
            .asMap()
            .entries
            .map((e) => FlowSubTask(
                blockTypeKey: 'chat',
                blockLabel: 'Chat',
                subTaskId: 'pending_chat_${e.key}',
                subTaskType: 'background',
                status: TaskStatus.waiting))
            .toList());
    await notifier.addExecutions([saved]);
    notifier.state = [];
    await notifier.restoreFromPersistence();
    await container
        .read(taskFlowExecutionServiceProvider)
        .restorePendingExecutions();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(dispatches, ['original:saved input']);
    first.complete(FlowPayload.fromValue('prefix', IOType.text));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(notifier.state.single.status, FlowExecutionStatus.completed);
  });

  test('failed checkpoint persistence blocks subsequent dispatch', () async {
    final firstDispatched = Completer<void>();
    runner = (block, input, id, step) {
      if (!firstDispatched.isCompleted) firstDispatched.complete();
      return first.future;
    };
    final service = container.read(taskFlowExecutionServiceProvider);
    await service.launchFlowMany('flow', [const FlowRunInput(text: 'one')]);
    await firstDispatched.future.timeout(const Duration(seconds: 3));
    final interrupted = Completer<void>();
    final subscription =
        container.listen(taskFlowExecutionsProvider, (previous, next) {
      if (next.any((e) => e.status == FlowExecutionStatus.interrupted) &&
          !interrupted.isCompleted) {
        interrupted.complete();
      }
    });
    addTearDown(subscription.close);
    final path = '${dir.path}/task_flows/executions.json';
    await File(path).delete();
    await Directory(path).create();
    first.complete(FlowPayload.fromValue('checkpoint', IOType.text));
    await interrupted.future.timeout(const Duration(seconds: 3));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(dispatches, hasLength(1));
    expect(container.read(taskFlowExecutionsProvider).single.status,
        FlowExecutionStatus.interrupted);
  });

  test('disposal and late completion cannot dispatch a suffix', () async {
    final service = container.read(taskFlowExecutionServiceProvider);
    final ids =
        await service.launchFlowMany('flow', [const FlowRunInput(text: 'one')]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    service.dispose();
    await Future<void>.delayed(Duration.zero);
    first.complete(FlowPayload.fromValue('late', IOType.text));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(dispatches, hasLength(1));
    expect(container.read(taskFlowExecutionsProvider).single.status,
        FlowExecutionStatus.interrupted);
    expect(container.read(taskFlowExecutionsProvider).single.id, ids.single);
  });

  test('legacy snapshot retry requires explicit latest configuration',
      () async {
    final id = container
        .read(taskFlowExecutionsProvider.notifier)
        .addExecution(flowId: 'flow', flowName: 'Legacy', inputText: 'input');
    container.read(taskFlowExecutionsProvider.notifier).failExecution(id);
    await expectLater(
        container.read(taskFlowExecutionServiceProvider).retryExecution(id),
        throwsA(isA<TaskFlowValidationException>()));
    expect(dispatches, isEmpty);
  });

  test(
      'model snapshot freezes tuning but resolves credentials from the current provider identity',
      () {
    final model =
        ModelConfig(id: 'model', name: 'Original', modelId: 'original-api');
    final config = ProviderConfigItem(
        id: 'config',
        providerName: 'P',
        host: 'https://example.com',
        key: 'fixture-key',
        models: [model]);
    final providers = ProviderEntriesState(entries: [
      ProviderEntry(id: 'entry', type: 'tts', name: 'P', configs: [config])
    ]);
    final flow = TaskFlowDefinition(blocks: [
      TaskFlowBlock(typeKey: BlockType.tts, params: {
        'modelRef': {'configId': 'config', 'modelId': 'model'}
      })
    ]);
    final snapshot = FlowLaunchSnapshot.capture(flow, providers, []);
    final encoded = jsonEncode(snapshot.toMap());
    expect(encoded, isNot(contains('fixture-key')));
    final current = ProviderEntriesState(entries: [
      ProviderEntry(id: 'entry', type: 'tts', name: 'P', configs: [
        ProviderConfigItem(
            id: 'config',
            providerName: 'P',
            host: 'https://example.com',
            key: 'rotated-key',
            models: [
              ModelConfig(id: 'model', name: 'Edited', modelId: 'edited-api')
            ])
      ])
    ]);
    final resolved = resolveProviderModel(snapshot.resolveProviders(current),
        'tts', flow.blocks.single.params['modelRef'])!;
    expect(resolved.model.modelId, 'original-api');
    expect(resolved.config.key, 'rotated-key');
    snapshot.flow.blocks.single.params['modelRef'] = null;
    expect(snapshot.flow.blocks.single.params['modelRef'], isNotNull);
  });

  test(
      'startup history migration is idempotent and distinguishes unrun legacy steps',
      () async {
    final file = File('${dir.path}/task_flows/executions.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode([
      {
        'id': 'legacy',
        'status': 'failed',
        'subTasks': [
          {'subTaskId': 'real', 'status': 'failed'},
          {'subTaskId': 'pending_asr_1', 'status': 'failed'}
        ]
      }
    ]));
    await FlowExecutionMigration.migrate();
    final encoded = await file.readAsString();
    final steps = (jsonDecode(encoded) as List).single['subTasks'] as List;
    expect(steps.first['outcome'], 'failed');
    expect(steps.last['outcome'], 'skipped');
    expect(steps.last['status'], 'paused');
    await FlowExecutionMigration.migrate();
    expect(await file.readAsString(), encoded);
  });

  test('deleting one active record cancels its saved batch siblings', () async {
    final service = container.read(taskFlowExecutionServiceProvider);
    final ids = await service.launchFlowMany('flow',
        [const FlowRunInput(text: 'one'), const FlowRunInput(text: 'two')]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    container
        .read(taskFlowExecutionsProvider.notifier)
        .removeExecution(ids.first);
    first.complete(FlowPayload.fromValue('late', IOType.text));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(dispatches, hasLength(1));
    final remaining = container.read(taskFlowExecutionsProvider).single;
    expect(remaining.id, ids.last);
    expect(remaining.status, FlowExecutionStatus.cancelled);
    expect(
        remaining.subTasks.every((s) => s.outcome == FlowStepOutcome.cancelled),
        isTrue);
  });

  test(
      'pause and cancel report save failure while retaining effective local control',
      () async {
    final service = container.read(taskFlowExecutionServiceProvider);
    final ids = await service.launchFlowMany('flow',
        [const FlowRunInput(text: 'one'), const FlowRunInput(text: 'two')]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final path = '${dir.path}/task_flows/executions.json';
    await File(path).delete();
    await Directory(path).create();
    await expectLater(service.pauseExecution(ids.first),
        throwsA(isA<TaskFlowPersistenceException>()));
    expect(
        container
            .read(taskFlowExecutionsProvider)
            .where((e) => e.id == ids.first)
            .single
            .status,
        FlowExecutionStatus.paused);
    await expectLater(
        service.cancelBatch(
            container.read(taskFlowExecutionsProvider).first.batchId!),
        throwsA(isA<TaskFlowPersistenceException>()));
    first.complete(FlowPayload.fromValue('late', IOType.text));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(dispatches, hasLength(1));
    expect(
        container.read(taskFlowExecutionsProvider).every((e) =>
            e.status == FlowExecutionStatus.cancelled && e.error != null),
        isTrue);
  });
  test('failed final save exposes interruption after successful checkpoints',
      () async {
    final notifier = _CompletionFailNotifier();
    final other = ProviderContainer(overrides: [
      taskFlowExecutionsProvider.overrideWith((ref) => notifier),
      taskFlowBlockRunnerProvider.overrideWithValue(
          (block, input, id, step) async =>
              FlowPayload.fromValue('done', IOType.text)),
    ]);
    final flow = container.read(taskFlowListProvider).single;
    other.read(taskFlowListProvider.notifier).state = [flow];
    await other
        .read(taskFlowExecutionServiceProvider)
        .startFlowMany('flow', [const FlowRunInput(text: 'one')]);
    expect(notifier.state.single.status, FlowExecutionStatus.interrupted);
    expect(notifier.state.single.error, contains('无法保存完成状态'));
    expect(
        notifier.state.single.subTasks.every(
            (s) => s.result != null && s.outcome == FlowStepOutcome.succeeded),
        isTrue);
    other.dispose();
  });

  test('synthesis defaults are detached in the immutable flow snapshot', () {
    final defaults = {'voice': 'launch-voice', 'volume': 0.8, 'format': 'wav'};
    final flow =
        TaskFlowDefinition(blocks: [TaskFlowBlock(typeKey: BlockType.tts)]);
    final snapshot = FlowLaunchSnapshot.capture(
        flow, const ProviderEntriesState(), [],
        synthesisDefaults: defaults);
    defaults['volume'] = 1.8;
    expect(
        (snapshot.flow.blocks.single.params['_launchSynthesisConfig']
            as Map)['volume'],
        0.8);
    expect(flow.blocks.single.params.containsKey('_launchSynthesisConfig'),
        isFalse);
  });
  test('cold queue restoration waits for fresh provider credential loading',
      () async {
    final model =
        ModelConfig(id: 'restored-model', name: 'Voice', modelId: 'voice-api');
    final config = ProviderConfigItem(
        id: 'restored-config',
        providerName: 'P',
        host: 'https://example.com',
        key: 'fixture-key',
        models: [model]);
    final entry = ProviderEntry(
        id: 'restored-entry', type: 'tts', name: 'TTS供应商', configs: [config]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('provider_entries', jsonEncode([entry.toMap()]));
    final flow = TaskFlowDefinition(id: 'cold-flow', blocks: [
      TaskFlowBlock(typeKey: BlockType.tts, params: {
        'modelRef': {'configId': config.id, 'modelId': model.id}
      })
    ]);
    final record = TaskFlowExecution(
        id: 'cold-execution',
        flowId: flow.id,
        flowName: 'Cold',
        status: FlowExecutionStatus.waiting,
        inputText: 'cold input',
        snapshot: FlowLaunchSnapshot.capture(
            flow, ProviderEntriesState(entries: [entry]), []),
        subTasks: [
          FlowSubTask(
              blockTypeKey: 'tts',
              blockLabel: 'TTS',
              subTaskId: 'pending_tts_0',
              subTaskType: 'synthesis',
              status: TaskStatus.waiting)
        ]);
    await container
        .read(taskFlowExecutionsProvider.notifier)
        .addExecutions([record]);
    late ProviderContainer fresh;
    var calls = 0;
    fresh = ProviderContainer(overrides: [
      taskFlowBlockRunnerProvider
          .overrideWithValue((block, input, id, step) async {
        final providers = fresh.read(providerEntriesProvider);
        expect(resolveProviderModel(providers, 'tts', block.params['modelRef']),
            isNotNull);
        expect(input.value, 'cold input');
        calls++;
        return FlowPayload.fromValue('saved.wav', IOType.audio);
      })
    ]);
    await fresh
        .read(taskFlowExecutionsProvider.notifier)
        .restoreFromPersistence();
    await fresh
        .read(taskFlowExecutionServiceProvider)
        .restorePendingExecutions();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(calls, 1);
    expect(fresh.read(taskFlowExecutionsProvider).single.status,
        FlowExecutionStatus.completed);
    fresh.dispose();
  });
  test(
      'snapshots omit nested authentication values and hydrate them by identity',
      () {
    final model = ModelConfig(
        id: 'model',
        name: 'M',
        modelId: 'api',
        typeConfig: {
          'api_key': 'model-secret'
        },
        customParams: [
          CustomParam(paramName: 'access_token', defaultValue: 'param-secret')
        ]);
    final config = ProviderConfigItem(
        id: 'config',
        host: 'https://example.com',
        key: 'provider-secret',
        models: [model],
        typeConfig: {'Authorization': 'Bearer config-secret'});
    final providers = ProviderEntriesState(entries: [
      ProviderEntry(id: 'entry', type: 'tts', name: 'P', configs: [config])
    ]);
    final flow = TaskFlowDefinition(blocks: [
      TaskFlowBlock(typeKey: BlockType.tts, params: {
        'modelRef': {'configId': 'config', 'modelId': 'model'}
      })
    ]);
    final snapshot = FlowLaunchSnapshot.capture(flow, providers, []);
    expect(jsonEncode(snapshot.toMap()), isNot(contains('secret')));
    final resolved = resolveProviderModel(snapshot.resolveProviders(providers),
        'tts', flow.blocks.single.params['modelRef'])!;
    expect(resolved.config.typeConfig['Authorization'], 'Bearer config-secret');
    expect(resolved.model.typeConfig['api_key'], 'model-secret');
    expect(resolved.model.customParams.single.defaultValue, 'param-secret');
  });
  test('removed snapshot model identity prevents fallback to current models',
      () {
    final original = ModelConfig(id: 'original', name: 'M', modelId: 'api');
    final config = ProviderConfigItem(
        id: 'config',
        host: 'https://example.com',
        key: 'fixture-key',
        models: [original]);
    final providers = ProviderEntriesState(entries: [
      ProviderEntry(id: 'entry', type: 'tts', name: 'P', configs: [config])
    ]);
    final flow = TaskFlowDefinition(blocks: [
      TaskFlowBlock(typeKey: BlockType.tts, params: {
        'modelRef': {'configId': 'config', 'modelId': 'original'}
      })
    ]);
    final snapshot = FlowLaunchSnapshot.capture(flow, providers, []);
    config.models = [ModelConfig(id: 'replacement', name: 'M', modelId: 'api')];
    expect(() => snapshot.resolveProviders(providers), throwsStateError);
  });

  test('X-API-Key custom parameter is never persisted in a snapshot', () {
    ProviderEntriesState providers(String secret) =>
        ProviderEntriesState(entries: [
          ProviderEntry(id: 'entry', type: 'tts', name: 'P', configs: [
            ProviderConfigItem(
                id: 'config',
                host: 'https://example.com',
                key: 'provider-key',
                models: [
                  ModelConfig(
                      id: 'model',
                      name: 'M',
                      modelId: 'api',
                      customParams: [
                        CustomParam(
                            paramName: 'X-API-Key', defaultValue: secret)
                      ])
                ])
          ])
        ]);
    final flow = TaskFlowDefinition(blocks: [
      TaskFlowBlock(typeKey: BlockType.tts, params: {
        'modelRef': {'configId': 'config', 'modelId': 'model'}
      })
    ]);
    final snapshot =
        FlowLaunchSnapshot.capture(flow, providers('old-secret'), []);
    expect(jsonEncode(snapshot.toMap()), isNot(contains('old-secret')));
    final selected = resolveProviderModel(
        snapshot.resolveProviders(providers('new-secret')),
        'tts',
        flow.blocks.single.params['modelRef'])!;
    expect(selected.model.customParams.single.defaultValue, 'new-secret');
  });
}
