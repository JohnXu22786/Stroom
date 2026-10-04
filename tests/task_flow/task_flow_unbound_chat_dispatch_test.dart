// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/providers/chat_manager_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/services/chat_service.dart';
import 'package:stroom/services/chat_stream_manager.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/flow_launch_snapshot.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/services/task_flow_execution_service.dart';
import 'package:stroom/task_flow/services/task_flow_scheduler.dart';

class _Documents extends PathProviderPlatform {
  _Documents(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

/// Runs production stream setup and records its actual service. Cancellation
/// happens before streaming yields, so these dispatch tests perform no HTTP.
class _InspectingManager extends ChatStreamManager {
  final services = <ChatService?>[];
  final assistants = <Assistant?>[];
  bool failStreamSetup = false;

  @override
  Future<StreamResult> startStreaming({
    required String text,
    required String convId,
    required List<ChatMessage> history,
    List<ToolDefinition> tools = const [],
    bool reasoning = false,
    String reasoningEffort = 'medium',
    Map<String, String> reasoningParamValues = const {},
    String? streamingMsgId,
    Assistant? assistant,
    ProviderEntriesState? entriesStateOverride,
  }) {
    if (failStreamSetup) throw StateError('stream setup failed');
    final pending = super.startStreaming(
      text: text,
      convId: convId,
      history: history,
      tools: tools,
      reasoning: reasoning,
      reasoningEffort: reasoningEffort,
      reasoningParamValues: reasoningParamValues,
      streamingMsgId: streamingMsgId,
      assistant: assistant,
      entriesStateOverride: entriesStateOverride,
    );
    services.add(adapter.currentChatService);
    assistants.add(assistant);
    cancel(convId);
    return pending;
  }
}

class _FailingMessages extends ConversationsNotifier {
  _FailingMessages(super.ref);

  @override
  set state(List<Conversation> conversations) {
    if (conversations.any((conversation) => conversation.messages.isNotEmpty)) {
      throw StateError('message preparation failed');
    }
    super.state = conversations;
  }
}

ProviderEntriesState _providers(
        {bool edited = false, bool anthropic = false}) =>
    ProviderEntriesState(entries: [
      ProviderEntry(id: 'llm', type: 'llm', name: 'LLM', configs: [
        ProviderConfigItem(
          id: 'config-A',
          providerName: 'Provider A',
          host: edited
              ? 'https://edited.invalid/v2?region=edited&token=fresh-host-token'
              : 'https://launch.invalid/v1?region=launch&token=old-host-token',
          key: edited ? 'fresh-key' : 'old-key',
          typeConfig: {
            'headers': jsonEncode({
              'Authorization': edited ? 'fresh-auth' : 'old-auth',
              'region': edited ? 'edited' : 'launch',
            }),
          },
          models: [
            ModelConfig(
              id: 'model-A',
              name: 'A',
              modelId: edited ? 'edited-api-A' : 'api-A',
              endpointType: anthropic && !edited ? 'anthropic' : 'openai',
              typeConfig: {'maxTokens': edited ? 900 : 100},
              customParams: [
                CustomParam(
                    paramName: 'temperature',
                    defaultValue: edited ? '0.9' : '0.2'),
              ],
            ),
          ],
        ),
        ProviderConfigItem(
          id: 'config-B',
          providerName: 'Provider B',
          host: 'https://other.invalid',
          key: 'other-key',
          models: [ModelConfig(id: 'model-B', name: 'B', modelId: 'api-B')],
        ),
      ]),
    ]);

const _referenceA = {'configId': 'config-A', 'modelId': 'model-A'};

Future<void> _waitFor(bool Function() ready) async {
  final timer = Stopwatch()..start();
  while (!ready()) {
    if (timer.elapsed > const Duration(seconds: 5)) {
      throw TimeoutException('Dispatch did not settle');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PathProviderPlatform previous;
  late _InspectingManager manager;
  late ProviderContainer container;
  late TaskFlowScheduler scheduler;

  Future<void> prepare(ProviderEntriesState providers,
      {bool failMessageSave = false}) async {
    SharedPreferences.setMockInitialValues({
      'provider_entries':
          jsonEncode(providers.entries.map((e) => e.toMap()).toList()),
    });
    manager = _InspectingManager();
    scheduler = TaskFlowScheduler(coreCount: 4, rssBytes: () => 0);
    container = ProviderContainer(overrides: [
      chatStreamManagerProvider.overrideWithValue(manager),
      taskFlowSchedulerProvider.overrideWithValue(scheduler),
      if (failMessageSave)
        conversationsProvider.overrideWith((ref) => _FailingMessages(ref)),
    ]);
    await container.read(providerEntriesProvider.notifier).ready;
  }

  Future<String> saveQueued(ProviderEntriesState providers,
      {IOType inputType = IOType.text, String input = 'Summarize'}) async {
    final flow = TaskFlowDefinition(id: 'flow', inputType: inputType, blocks: [
      TaskFlowBlock(
          id: 'chat-block',
          typeKey: BlockType.chat,
          params: {'assistantId': ''}),
    ]);
    final snapshot = FlowLaunchSnapshot.fromMap(FlowLaunchSnapshot.capture(
      flow,
      providers,
      [],
      selectedChatModel: _referenceA,
    ).toMap());
    final execution = TaskFlowExecution(
      flowId: flow.id,
      flowName: flow.name,
      status: FlowExecutionStatus.waiting,
      inputText: input,
      snapshot: snapshot,
      subTasks: [
        FlowSubTask(
          blockTypeKey: 'chat',
          blockLabel: 'Chat',
          subTaskId: 'pending_chat_0',
          subTaskType: 'background',
          status: TaskStatus.waiting,
        )
      ],
    );
    expect(
        await container
            .read(taskFlowExecutionsProvider.notifier)
            .addExecutions([execution]),
        true);
    return execution.id;
  }

  Future<void> settle(String id) => _waitFor(() =>
      container
          .read(taskFlowExecutionsProvider.notifier)
          .execution(id)
          ?.isTerminal ==
      true);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('unbound_chat_dispatch_');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Documents(directory.path);
    AppStorage.resetCache();
  });
  tearDown(() async {
    container.dispose();
    manager.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    PathProviderPlatform.instance = previous;
    AppStorage.resetCache();
    await directory.delete(recursive: true);
  });

  test('queued unbound Chat dispatch keeps captured A after global selection B',
      () async {
    final providers = _providers();
    await prepare(providers);
    manager.adapter.configure(providers);
    final id = await saveQueued(providers);
    await scheduler.acquire('held-slot', 2);
    final service = container.read(taskFlowExecutionServiceProvider);
    await service.restorePendingExecutions();
    await _waitFor(() => scheduler.queuedCount == 1);
    manager.adapter.selectModel(providers, 1, 0);
    scheduler.release('held-slot');
    await settle(id);

    expect(manager.services.single?.modelConfig?.id, 'model-A');
    expect(manager.services.single?.providerConfig?.id, 'config-A');
    expect(manager.assistants.single, isNull);
    expect(manager.adapter.modelConfig?.id, 'model-B');
    expect(manager.adapter.currentConfigIndex, 1);
  });

  test('restored unbound Chat dispatch works with an empty adapter cache',
      () async {
    final providers = _providers();
    await prepare(providers);
    final id = await saveQueued(providers);
    expect(manager.adapter.isConfigured, false);
    await container
        .read(taskFlowExecutionServiceProvider)
        .restorePendingExecutions();
    await settle(id);

    expect(manager.services.single, isNotNull);
    expect(manager.services.single?.modelConfig?.id, 'model-A');
    expect(manager.adapter.isConfigured, false);
    expect(manager.adapter.selectedProviderModelReference, isNull);
    expect(manager.assistants.single, isNull);
  });

  test(
      'real unbound dispatch freezes endpoint and tuning but refreshes credentials',
      () async {
    final original = _providers(anthropic: true);
    await prepare(original);
    manager.adapter.configure(original);
    final id = await saveQueued(original);
    await scheduler.acquire('held-slot', 2);
    await container
        .read(taskFlowExecutionServiceProvider)
        .restorePendingExecutions();
    await _waitFor(() => scheduler.queuedCount == 1);
    final edited = _providers(edited: true, anthropic: true);
    container.read(providerEntriesProvider.notifier).state = edited;
    manager.adapter.selectModel(edited, 1, 0);
    scheduler.release('held-slot');
    await settle(id);

    final actual = manager.services.single;
    expect(actual?.modelConfig?.modelId, 'api-A');
    expect(actual?.protocol.name, 'anthropic');
    expect(actual?.modelConfig?.typeConfig['maxTokens'], 100);
    expect(actual?.modelConfig?.customParams.single.defaultValue, '0.2');
    expect(actual?.providerConfig?.key, 'fresh-key');
    expect(actual?.providerConfig?.host,
        'https://launch.invalid/v1?region=launch&token=fresh-host-token');
    expect(jsonDecode(actual!.providerConfig!.typeConfig['headers'] as String),
        {'Authorization': 'fresh-auth', 'region': 'launch'});
    expect(manager.adapter.modelConfig?.id, 'model-B');
  });

  test(
      'captured attachment endpoint rejects audio before creating a stream service',
      () async {
    final original = _providers(anthropic: true);
    await prepare(original);
    manager.adapter.selectModel(original, 1, 0);
    final file = await File('tests/fixtures/catcatch/audio_only.wav')
        .copy('${directory.path}/input.wav');
    final id =
        await saveQueued(original, inputType: IOType.audio, input: file.path);
    await container
        .read(taskFlowExecutionServiceProvider)
        .restorePendingExecutions();
    await settle(id);

    expect(manager.services, isEmpty);
    expect(manager.adapter.currentChatService, isNull);
    expect(container.read(conversationsProvider), isEmpty);
    expect(
        container
            .read(taskFlowExecutionsProvider.notifier)
            .execution(id)
            ?.error,
        contains('Anthropic'));
    expect(manager.adapter.modelConfig?.id, 'model-B');
  });

  test('pre-stream message preparation failure leaves no unused ChatService',
      () async {
    final providers = _providers();
    await prepare(providers, failMessageSave: true);
    manager.adapter.selectModel(providers, 1, 0);
    final id = await saveQueued(providers);
    await container
        .read(taskFlowExecutionServiceProvider)
        .restorePendingExecutions();
    await settle(id);

    expect(manager.services, isEmpty);
    expect(manager.adapter.currentChatService, isNull);
    expect(container.read(conversationsProvider), isEmpty);
    expect(
        container
            .read(taskFlowExecutionsProvider.notifier)
            .execution(id)
            ?.error,
        contains('message preparation failed'));
  });

  test('stream setup failure releases the explicitly prepared ChatService',
      () async {
    final providers = _providers();
    await prepare(providers);
    manager.failStreamSetup = true;
    manager.adapter.selectModel(providers, 1, 0);
    final id = await saveQueued(providers);
    await container
        .read(taskFlowExecutionServiceProvider)
        .restorePendingExecutions();
    await settle(id);

    expect(manager.adapter.currentChatService, isNull);
    expect(container.read(conversationsProvider), isEmpty);
    expect(
        container
            .read(taskFlowExecutionsProvider.notifier)
            .execution(id)
            ?.error,
        contains('stream setup failed'));
    expect(manager.adapter.modelConfig?.id, 'model-B');
  });

  test(
      'ordinary unbound chat keeps global selection with supplied provider entries',
      () async {
    final providers = _providers();
    await prepare(providers);
    manager.adapter.selectModel(providers, 1, 0);
    final snapshot = FlowLaunchSnapshot.capture(
      TaskFlowDefinition(blocks: [TaskFlowBlock(typeKey: BlockType.chat)]),
      providers,
      [],
      selectedChatModel: _referenceA,
    );
    final resolved = snapshot.resolveProviders(providers);
    final service = manager.adapter
        .getOrCreateService('interactive', entriesState: resolved);

    expect(service?.modelConfig?.id, 'model-B');
    expect(manager.adapter.modelConfig?.id, 'model-B');
  });
}
