import 'dart:io';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/models/assistant.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/providers/task_flow_provider.dart';
import 'package:stroom/task_flow/services/task_flow_execution_service.dart';
import 'package:stroom/task_flow/services/task_flow_validator.dart';
import 'package:stroom/utils/provider_models.dart';

class _Flows extends TaskFlowNotifier {
  @override
  Future<bool> persist() async => true;
}

class _Entries extends ProviderEntriesNotifier {
  _Entries(ProviderEntriesState entries) {
    state = entries;
  }
}

class _Assistants extends AssistantsNotifier {
  _Assistants(List<Assistant> assistants) {
    state = assistants;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('configuration and model identities survive serialization and editing',
      () {
    final config = ProviderConfigItem.fromMap({
      'id': 'config-1',
      'providerName': 'Provider',
      'models': [
        {'id': 'model-1', 'name': 'Model', 'modelId': 'remote-name'},
      ],
    });
    final edited = config.copy();
    edited.models.single.name = 'Renamed';
    expect(edited.toMap()['id'], 'config-1');
    expect(edited.models.single.toMap()['id'], 'model-1');
    expect(ProviderConfigItem().id, isNot(config.id));
  });

  for (final type in ['asr', 'ocr', 'tts']) {
    test('$type selection survives reorder and deletion of preceding models',
        () {
      final first = ModelConfig(name: 'First', modelId: 'same-api-name');
      final selected = ModelConfig(name: 'Selected', modelId: 'same-api-name');
      final config = ProviderConfigItem(
          host: 'https://example.com',
          key: 'secret',
          models: [first, selected]);
      final other = ProviderConfigItem(
          host: config.host, key: config.key, models: [first.copy()]);
      final entry =
          ProviderEntry(name: type, type: type, configs: [other, config]);
      final state = ProviderEntriesState(entries: [entry]);
      final reference =
          providerModelReference((config: config, model: selected));
      config.models = [selected, first];
      entry.configs = [config, other];
      expect(
          resolveProviderModel(state, type, reference)?.model, same(selected));
      config.models.remove(first);
      entry.configs.remove(other);
      expect(
          resolveProviderModel(state, type, reference)?.model, same(selected));
      final restored =
          ProviderEntriesState(entries: [ProviderEntry.fromMap(entry.toMap())]);
      expect(resolveProviderModel(restored, type, reference)?.model.id,
          selected.id);
      expect(reference.keys, unorderedEquals(['configId', 'modelId']));
      expect(reference.toString(), isNot(contains('secret')));
    });
  }

  test('deleted, ambiguous and unconfigured models never fall back', () {
    final model = ModelConfig(name: 'Selected', modelId: 'same-api-name');
    final config = ProviderConfigItem(
        host: 'https://example.com', key: 'secret', models: [model]);
    final entry = ProviderEntry(name: 'TTS', type: 'tts', configs: [config]);
    final state = ProviderEntriesState(entries: [entry]);
    final reference = providerModelReference((config: config, model: model));
    config.models = [ModelConfig(name: 'Replacement', modelId: model.modelId)];
    expect(resolveProviderModel(state, 'tts', reference), isNull);
    expect(resolveProviderModel(state, 'tts', 0), isNull);
    config.models = [model, model.copy()];
    expect(resolveProviderModel(state, 'tts', reference), isNull);
    config.models = [model];
    config.key = '';
    expect(resolveProviderModel(state, 'tts', reference), isNull);
  });

  Future<void> validate(TaskFlowDefinition flow, List<FlowRunInput> inputs,
          {List<Assistant> assistants = const []}) =>
      validateTaskFlow(
        flow,
        inputs,
        providers: const ProviderEntriesState(),
        assistants: assistants,
      );

  test('preflight locates missing assistants, incompatible links and inputs',
      () async {
    final assistant =
        Assistant(id: 'assistant', name: 'Assistant', prompt: 'Help');
    final chat = TaskFlowBlock(
        typeKey: BlockType.chat, params: {'assistantId': assistant.id});
    final flow = TaskFlowDefinition(name: 'Flow', blocks: [chat]);
    await expectLater(
        validate(flow, [const FlowRunInput(text: 'input')]),
        throwsA(isA<TaskFlowValidationException>()
            .having((e) => e.blockId, 'block', chat.id)));
    await expectLater(
        validate(flow, [], assistants: [assistant]),
        throwsA(isA<TaskFlowValidationException>()
            .having((e) => e.isInputError, 'input', true)));
    final incompatible =
        flow.addBlock(TaskFlowBlock(typeKey: BlockType.audioSeparation));
    await expectLater(
        validate(incompatible, [const FlowRunInput(text: 'input')],
            assistants: [assistant]),
        throwsA(isA<TaskFlowValidationException>()
            .having((e) => e.blockIndex, 'step', 1)));
    await validate(flow, [const FlowRunInput(text: 'input')],
        assistants: [assistant]);
  });

  test('preflight checks every media input for readability', () async {
    final dir = await Directory.systemTemp.createTemp('flow_validation_');
    addTearDown(() => dir.delete(recursive: true));
    final good = await File('${dir.path}/video.mp4').writeAsBytes([1, 2, 3]);
    final flow = TaskFlowDefinition(
        name: 'Media',
        inputType: IOType.video,
        blocks: [TaskFlowBlock(typeKey: BlockType.audioSeparation)]);
    await validate(flow, [FlowRunInput(text: good.path)]);
    for (final bad in [
      '${dir.path}/missing.mp4',
      dir.path,
      (await File('${dir.path}/empty.mp4').writeAsBytes([])).path
    ]) {
      await expectLater(
          validate(
              flow, [FlowRunInput(text: good.path), FlowRunInput(text: bad)]),
          throwsA(isA<TaskFlowValidationException>()
              .having((e) => e.inputIndex, 'input', 1)));
    }
  });

  test('preflight waits for model and assistant providers to finish loading',
      () async {
    final config = ProviderConfigItem(
        host: 'https://example.com',
        key: 'key',
        models: [ModelConfig(name: 'Model', modelId: 'remote-model')]);
    final assistant = Assistant(id: 'a', name: 'Assistant', prompt: 'Help');
    SharedPreferences.setMockInitialValues({
      'provider_entries': jsonEncode([
        ProviderEntry(name: 'TTS', type: 'tts', configs: [config]).toMap()
      ]),
      'assistants': jsonEncode([assistant.toMap()]),
    });
    final flows = _Flows();
    final flow = TaskFlowDefinition(name: 'Flow', blocks: [
      TaskFlowBlock(typeKey: BlockType.tts, params: {
        'modelRef': providerModelReference(
            (config: config, model: config.models.single)),
      }),
      TaskFlowBlock(
          typeKey: BlockType.chat, params: {'assistantId': assistant.id}),
      TaskFlowBlock(typeKey: BlockType.custom),
    ]);
    await flows.saveFlow(flow);
    final container = ProviderContainer(
        overrides: [taskFlowListProvider.overrideWith((ref) => flows)]);
    addTearDown(container.dispose);
    await expectLater(
        container
            .read(taskFlowExecutionServiceProvider)
            .startFlow(flow.id, 'input'),
        throwsA(isA<TaskFlowValidationException>().having(
            (e) => e.blockIndex, 'unsupported step after loaded config', 2)));
    expect(container.read(taskFlowExecutionsProvider), isEmpty);
  });

  test('normal, batch and retry starts reject invalid flows before work',
      () async {
    final flows = _Flows();
    final empty = TaskFlowDefinition(name: 'Empty');
    final missingModel = TaskFlowDefinition(name: 'Missing model', blocks: [
      TaskFlowBlock(typeKey: BlockType.tts, params: {'modelIndex': 0})
    ]);
    await flows.saveFlow(empty);
    await flows.saveFlow(missingModel);
    final container = ProviderContainer(overrides: [
      taskFlowListProvider.overrideWith((ref) => flows),
      providerEntriesProvider
          .overrideWith((ref) => _Entries(const ProviderEntriesState())),
      assistantProvider.overrideWith((ref) => _Assistants([])),
    ]);
    addTearDown(container.dispose);
    final service = container.read(taskFlowExecutionServiceProvider);
    for (final id in [empty.id, missingModel.id, 'deleted-flow']) {
      await expectLater(service.startFlow(id, 'input'),
          throwsA(isA<TaskFlowValidationException>()));
      await expectLater(
          service.startFlowMany(id, [const FlowRunInput(text: 'input')]),
          throwsA(isA<TaskFlowValidationException>()));
      await expectLater(
          service.launchFlowMany(id, [const FlowRunInput(text: 'input')]),
          throwsA(isA<TaskFlowValidationException>()));
      expect(container.read(taskFlowExecutionsProvider), isEmpty);
    }
  });
}
