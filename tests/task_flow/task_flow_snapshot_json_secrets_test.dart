import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/flow_launch_snapshot.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/utils/provider_models.dart';

void main() {
  ProviderEntriesState modelProviders(String secret, String tuning) =>
      ProviderEntriesState(entries: [
        ProviderEntry(id: 'entry', type: 'tts', name: 'TTS', configs: [
          ProviderConfigItem(
              id: 'config',
              providerName: 'TTS',
              host: 'https://example.com',
              key: 'live-key',
              typeConfig: {
                'headers': jsonEncode(
                    {'Authorization': 'Bearer $secret', 'temperature': tuning})
              },
              models: [
                ModelConfig(
                    id: 'model',
                    name: 'Voice',
                    modelId: 'voice-api',
                    typeConfig: {
                      'headers': jsonEncode({
                        'Authorization': 'Bearer $secret',
                        'temperature': tuning
                      })
                    },
                    customParams: [
                      CustomParam(
                          paramName: 'headers',
                          type: 'json',
                          defaultValue: jsonEncode({
                            'Authorization': 'Bearer $secret',
                            'temperature': tuning
                          }),
                          options: [
                            jsonEncode(
                                {'X-API-Key': secret, 'temperature': tuning})
                          ],
                          optionOrder: [
                            jsonEncode(
                                {'X-API-Key': secret, 'temperature': tuning})
                          ])
                    ],
                    reasoningParams: [
                      ReasoningParam(
                          paramName: 'reasoning',
                          type: 'json',
                          options: [
                            jsonEncode(
                                {'Authorization': secret, 'effort': tuning})
                          ])
                    ])
              ])
        ])
      ]);

  final flow = TaskFlowDefinition(blocks: [
    TaskFlowBlock(typeKey: BlockType.tts, params: {
      'modelRef': {'configId': 'config', 'modelId': 'model'}
    })
  ]);

  test('JSON model and provider parameters redact then hydrate by identity',
      () {
    final snapshot = FlowLaunchSnapshot.capture(
        flow, modelProviders('old-secret', '0.5'), []);
    final encoded = jsonEncode(snapshot.toMap());
    expect(encoded, isNot(contains('old-secret')));
    expect(encoded, contains('temperature'));

    final restored = FlowLaunchSnapshot.fromMap(snapshot.toMap());
    expect(jsonEncode(restored.toMap()), isNot(contains('old-secret')));
    final hydrated = resolveProviderModel(
        restored.resolveProviders(modelProviders('fresh-secret', '0.9')),
        'tts',
        flow.blocks.single.params['modelRef'])!;
    final configHeaders =
        jsonDecode(hydrated.config.typeConfig['headers'] as String) as Map;
    expect(configHeaders,
        {'Authorization': 'Bearer fresh-secret', 'temperature': '0.5'});
    expect(jsonDecode(hydrated.model.typeConfig['headers'] as String),
        {'Authorization': 'Bearer fresh-secret', 'temperature': '0.5'});
    final param = hydrated.model.customParams.single;
    expect(jsonDecode(param.defaultValue),
        {'Authorization': 'Bearer fresh-secret', 'temperature': '0.5'});
    expect(jsonDecode(param.options.single),
        {'X-API-Key': 'fresh-secret', 'temperature': '0.5'});
    expect(jsonDecode(param.optionOrder.single),
        {'X-API-Key': 'fresh-secret', 'temperature': '0.5'});
    expect(jsonDecode(hydrated.model.reasoningParams.single.options.single),
        {'Authorization': 'fresh-secret', 'effort': '0.5'});
  });

  test('malformed JSON parameter fails closed and uses the live value', () {
    final old = modelProviders('old-secret', '0.5');
    old.entries.single.configs.single.models.single.customParams.single
        .defaultValue = '{"Authorization":"old-secret"';
    final snapshot = FlowLaunchSnapshot.capture(flow, old, []);
    expect(jsonEncode(snapshot.toMap()), isNot(contains('old-secret')));
    final live = modelProviders('fresh-secret', '0.9');
    live.entries.single.configs.single.models.single.customParams.single
        .defaultValue = '{"Authorization":"fresh-secret"';
    final hydrated = resolveProviderModel(
        FlowLaunchSnapshot.fromMap(snapshot.toMap()).resolveProviders(live),
        'tts',
        flow.blocks.single.params['modelRef'])!;
    expect(hydrated.model.customParams.single.defaultValue,
        '{"Authorization":"fresh-secret"');
  });

  test('bare invalid JSON values fail closed while valid scalars stay frozen',
      () {
    final old = modelProviders('old-secret', '0.5');
    final oldConfig = old.entries.single.configs.single;
    oldConfig.typeConfig['plainNote'] = 'plain-text-literal';
    final oldModel = oldConfig.models.single;
    oldModel.customParams.single
      ..defaultValue = 'old-secret'
      ..options = ['old-secret']
      ..optionOrder = ['old-secret'];
    oldModel.customParams.add(CustomParam(
        paramName: 'scalar',
        type: 'json',
        defaultValue: '0.5',
        options: ['true', '"quoted-old"']));
    oldModel.reasoningParams.single.options = ['old-secret'];
    final snapshot = FlowLaunchSnapshot.capture(flow, old, []);
    expect(jsonEncode(snapshot.toMap()), isNot(contains('old-secret')));
    expect(
        (snapshot.toMap()['configs'] as List).single['typeConfig']['plainNote'],
        'plain-text-literal');

    final live = modelProviders('fresh-secret', '0.9');
    final liveModel = live.entries.single.configs.single.models.single;
    liveModel.customParams.single
      ..defaultValue = 'fresh-secret'
      ..options = ['fresh-secret']
      ..optionOrder = ['fresh-secret'];
    liveModel.customParams.add(CustomParam(
        paramName: 'scalar',
        type: 'json',
        defaultValue: '0.9',
        options: ['false', '"quoted-new"']));
    liveModel.reasoningParams.single.options = ['fresh-secret'];
    final model = resolveProviderModel(
            FlowLaunchSnapshot.fromMap(snapshot.toMap()).resolveProviders(live),
            'tts',
            flow.blocks.single.params['modelRef'])!
        .model;
    expect(model.customParams.first.defaultValue, 'fresh-secret');
    expect(model.customParams.first.options, ['fresh-secret']);
    expect(model.customParams.first.optionOrder, ['fresh-secret']);
    expect(model.reasoningParams.single.options, ['fresh-secret']);
    expect(model.customParams.last.defaultValue, '0.5');
    expect(model.customParams.last.options, ['true', '"quoted-old"']);
  });

  test('bare invalid assistant JSON value is hydrated from the live assistant',
      () {
    Assistant withValue(String value) => Assistant(
        id: 'assistant',
        name: 'Assistant',
        prompt: '{"Authorization":"prompt-literal"}',
        settings: AssistantSettings(customParameters: [
          CustomParameter(name: 'headers', type: 'json', value: value)
        ]));
    final chatFlow = TaskFlowDefinition(blocks: [
      TaskFlowBlock(
          typeKey: BlockType.chat, params: {'assistantId': 'assistant'})
    ]);
    final snapshot = FlowLaunchSnapshot.capture(
        chatFlow, const ProviderEntriesState(), [withValue('old-secret')]);
    expect(jsonEncode(snapshot.toMap()), isNot(contains('old-secret')));
    final resolved = FlowLaunchSnapshot.fromMap(snapshot.toMap())
        .resolveAssistants([withValue('fresh-secret')]);
    expect(
        resolved.single.settings.customParameters.single.value, 'fresh-secret');
    expect(resolved.single.prompt, '{"Authorization":"prompt-literal"}');
  });

  Assistant assistant(String secret, String tuning) => Assistant(
      id: 'assistant',
      name: 'Assistant',
      prompt: '{"Authorization":"prompt-literal"}',
      settings: AssistantSettings(customParameters: [
        CustomParameter(
            name: 'headers',
            type: 'json',
            value: jsonEncode(
                {'Authorization': 'Bearer $secret', 'temperature': tuning})),
        CustomParameter(
            name: 'note',
            type: 'string',
            value: '{"Authorization":"plain-text-literal"}')
      ]));

  test('assistant JSON value hydrates without rewriting prompt or plain text',
      () {
    final assistantFlow = TaskFlowDefinition(blocks: [
      TaskFlowBlock(
          typeKey: BlockType.chat, params: {'assistantId': 'assistant'})
    ]);
    final snapshot = FlowLaunchSnapshot.capture(assistantFlow,
        const ProviderEntriesState(), [assistant('old-secret', '0.5')]);
    final encoded = jsonEncode(snapshot.toMap());
    expect(encoded, isNot(contains('old-secret')));
    expect(encoded, contains('prompt-literal'));
    expect(encoded, contains('plain-text-literal'));

    final restored = FlowLaunchSnapshot.fromMap(snapshot.toMap());
    final hydrated =
        restored.resolveAssistants([assistant('fresh-secret', '0.9')]).single;
    expect(jsonDecode(hydrated.settings.customParameters.first.value as String),
        {'Authorization': 'Bearer fresh-secret', 'temperature': '0.5'});
    expect(hydrated.prompt, '{"Authorization":"prompt-literal"}');
    expect(hydrated.settings.customParameters.last.value,
        '{"Authorization":"plain-text-literal"}');
  });
}
