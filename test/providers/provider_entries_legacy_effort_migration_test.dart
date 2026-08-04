import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/providers/provider_config.dart';

/// Behavior tests for the legacy effort-param data migration:
/// reasoning params saved before the isEffortParam flag existed are
/// promoted so the first non-toggle param becomes the effort param
/// (the pre-flag "effort = first non-toggle" semantics).
void main() {
  Map<String, dynamic> legacyParam(String name, List<String> options,
      {bool isToggle = false}) {
    return {
      'paramName': name,
      'options': options,
      'enabled': true,
      'isReasoningToggle': isToggle,
      if (isToggle) 'onValue': 'enabled',
      if (isToggle) 'offValue': 'disabled',
      'type': 'string',
    };
  }

  String providerEntriesJson({
    required List<Map<String, dynamic>> modelReasoningParams,
    List<Map<String, dynamic>> providerReasoningParams = const [],
  }) {
    final llmEntry = {
      'id': 'llm1',
      'type': 'llm',
      'name': 'LLM供应商',
      'configs': [
        {
          'providerName': '测试供应商',
          'host': 'https://example.com',
          'key': 'k',
          'typeConfig': <String, dynamic>{},
          'customParams': <Map<String, dynamic>>[],
          'reasoningParams': providerReasoningParams,
          'endpointType': 'openai',
          'models': [
            {
              'name': '模型A',
              'modelId': 'model-a',
              'voices': <Map<String, dynamic>>[],
              'volumeMin': 0.1,
              'volumeMax': 2.0,
              'speedMin': 0.5,
              'speedMax': 2.0,
              'hasVolume': false,
              'hasSpeed': false,
              'customParams': <Map<String, dynamic>>[],
              'reasoningParams': modelReasoningParams,
              'maxWordsPerRequest': 0,
              'supportStream': false,
              'supportInstruction': false,
              'typeConfig': <String, dynamic>{},
            }
          ],
        }
      ],
    };
    return jsonEncode([llmEntry]);
  }

  Future<ProviderContainer> loadContainer(String json) async {
    SharedPreferences.setMockInitialValues({'provider_entries': json});
    final container = ProviderContainer(
      overrides: [
        providerEntriesProvider.overrideWith(
          (ref) => ProviderEntriesNotifier(),
        ),
      ],
    );
    await container.read(providerEntriesProvider.notifier).load();
    return container;
  }

  List<ReasoningParam> loadModelReasoningParams(ProviderContainer container) {
    final llm = container
        .read(providerEntriesProvider)
        .entries
        .firstWhere((e) => e.type == 'llm');
    return llm.configs.first.models.first.reasoningParams;
  }

  group('Legacy effort param migration', () {
    test('promotes the first non-toggle param to effort for legacy model data',
        () async {
      final container = await loadContainer(providerEntriesJson(
        modelReasoningParams: [
          legacyParam('thinking.type', [], isToggle: true),
          legacyParam('reasoning_effort', ['low', 'medium', 'high']),
          legacyParam('budget_tokens', ['5000', '10000']),
        ],
      ));
      addTearDown(container.dispose);

      final params = loadModelReasoningParams(container);
      expect(params[0].isEffortParam, isFalse);
      expect(params[1].isEffortParam, isTrue,
          reason: 'first non-toggle legacy param becomes the effort param');
      expect(params[2].isEffortParam, isFalse);
    });

    test('persists the promoted flag to SharedPreferences', () async {
      final json = providerEntriesJson(
        modelReasoningParams: [
          legacyParam('thinking.type', [], isToggle: true),
          legacyParam('reasoning_effort', ['low', 'medium', 'high']),
        ],
      );
      await loadContainer(json);

      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('provider_entries')!;
      final entries = (jsonDecode(saved) as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((e) => e['type'] == 'llm');
      final configs = (entries['configs'] as List).cast<Map<String, dynamic>>();
      final model = configs.first['models'] as List;
      final reasoningParams =
          (model.first as Map<String, dynamic>)['reasoningParams'] as List;
      final effort = reasoningParams.cast<Map<String, dynamic>>()[1];
      expect(effort['isEffortParam'], isTrue);
    });

    test('is idempotent — second load does not change the data', () async {
      final json = providerEntriesJson(
        modelReasoningParams: [
          legacyParam('thinking.type', [], isToggle: true),
          legacyParam('reasoning_effort', ['low', 'medium', 'high']),
        ],
      );
      SharedPreferences.setMockInitialValues({'provider_entries': json});
      final container = ProviderContainer(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
      );
      await container.read(providerEntriesProvider.notifier).load();
      final afterFirst = await SharedPreferences.getInstance()
          .then((p) => p.getString('provider_entries'));
      await container.read(providerEntriesProvider.notifier).load();
      final afterSecond = await SharedPreferences.getInstance()
          .then((p) => p.getString('provider_entries'));
      container.dispose();
      expect(afterSecond, afterFirst);
    });

    test('modern data (keys present, false) is left untouched', () async {
      final modernParams = [
        legacyParam('thinking.type', [], isToggle: true),
        {
          ...legacyParam('budget_tokens', ['5000', '10000']),
          'isEffortParam': false,
        },
      ];
      final json = providerEntriesJson(modelReasoningParams: modernParams);
      SharedPreferences.setMockInitialValues({'provider_entries': json});
      final container = ProviderContainer(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
      );
      await container.read(providerEntriesProvider.notifier).load();

      final params = loadModelReasoningParams(container);
      expect(params.every((p) => !p.isEffortParam), isTrue,
          reason: 'modern data deliberately has no effort param');

      final saved = await SharedPreferences.getInstance()
          .then((p) => p.getString('provider_entries'));
      final savedModel = ((jsonDecode(saved!) as List)
              .cast<Map<String, dynamic>>()
              .firstWhere((e) => e['type'] == 'llm')['configs'] as List)
          .cast<Map<String, dynamic>>()
          .first['models'] as List;
      final savedParams =
          (savedModel.first as Map<String, dynamic>)['reasoningParams'] as List;
      expect(
        savedParams.every(
            (p) => (p as Map<String, dynamic>)['isEffortParam'] == false),
        isTrue,
      );
      container.dispose();
    });

    test('model with only a toggle is left untouched', () async {
      final json = providerEntriesJson(
        modelReasoningParams: [
          legacyParam('thinking.type', [], isToggle: true)
        ],
      );
      SharedPreferences.setMockInitialValues({'provider_entries': json});
      final container = ProviderContainer(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
      );
      await container.read(providerEntriesProvider.notifier).load();

      final params = loadModelReasoningParams(container);
      expect(params.every((p) => !p.isEffortParam), isTrue);
      container.dispose();
    });

    test('provider-level legacy reasoning params are left untouched', () async {
      final json = providerEntriesJson(
        modelReasoningParams: [
          legacyParam('thinking.type', [], isToggle: true),
        ],
        providerReasoningParams: [
          legacyParam('provider_effort', ['low', 'high']),
        ],
      );
      SharedPreferences.setMockInitialValues({'provider_entries': json});
      final container = ProviderContainer(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
      );
      await container.read(providerEntriesProvider.notifier).load();

      final llm = container
          .read(providerEntriesProvider)
          .entries
          .firstWhere((e) => e.type == 'llm');
      expect(llm.configs.first.reasoningParams.first.isEffortParam, isFalse);
      container.dispose();
    });

    test('promotion skips empty-named non-toggle params', () async {
      final json = providerEntriesJson(
        modelReasoningParams: [
          legacyParam('thinking.type', [], isToggle: true),
          legacyParam('', ['a']),
          legacyParam('reasoning_effort', ['low', 'medium', 'high']),
        ],
      );
      SharedPreferences.setMockInitialValues({'provider_entries': json});
      final container = ProviderContainer(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
      );
      await container.read(providerEntriesProvider.notifier).load();

      final params = loadModelReasoningParams(container);
      expect(params[0].isEffortParam, isFalse);
      expect(params[1].isEffortParam, isFalse);
      expect(params[2].isEffortParam, isTrue,
          reason: 'first NAMED non-toggle param is promoted');
      container.dispose();
    });

    test('defaultValue-era params are not promoted', () async {
      final json = providerEntriesJson(
        modelReasoningParams: [
          legacyParam('thinking.type', [], isToggle: true),
          {
            'paramName': 'legacy_effort',
            'defaultValue': 'high',
          },
        ],
      );
      SharedPreferences.setMockInitialValues({'provider_entries': json});
      final container = ProviderContainer(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
      );
      await container.read(providerEntriesProvider.notifier).load();

      final params = loadModelReasoningParams(container);
      expect(params.every((p) => !p.isEffortParam), isTrue);
      container.dispose();
    });

    test('params without options are not promoted', () async {
      final json = providerEntriesJson(
        modelReasoningParams: [
          legacyParam('thinking.type', [], isToggle: true),
          legacyParam('no_options', []),
          legacyParam('reasoning_effort', ['low', 'medium', 'high']),
        ],
      );
      SharedPreferences.setMockInitialValues({'provider_entries': json});
      final container = ProviderContainer(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
      );
      await container.read(providerEntriesProvider.notifier).load();

      final params = loadModelReasoningParams(container);
      expect(params[1].isEffortParam, isFalse,
          reason: 'an option-less param cannot be the effort param');
      expect(params[2].isEffortParam, isTrue);
      container.dispose();
    });

    test('non-llm entries are left untouched', () async {
      final llmJson = jsonDecode(providerEntriesJson(
        modelReasoningParams: [
          legacyParam('thinking.type', [], isToggle: true),
          legacyParam('tts_effort', ['low', 'high']),
        ],
      )) as List;
      final ttsEntry = {
        'id': 'builtin_tts',
        'type': 'tts',
        'name': 'TTS供应商',
        'configs': [
          {
            'providerName': 'TTS供应商',
            'host': '',
            'key': '',
            'typeConfig': <String, dynamic>{},
            'customParams': <Map<String, dynamic>>[],
            'reasoningParams': <Map<String, dynamic>>[],
            'endpointType': 'openai',
            'models': [
              {
                'name': 'TTS模型',
                'modelId': 'tts-model',
                'voices': <Map<String, dynamic>>[],
                'volumeMin': 0.1,
                'volumeMax': 2.0,
                'speedMin': 0.5,
                'speedMax': 2.0,
                'hasVolume': false,
                'hasSpeed': false,
                'customParams': <Map<String, dynamic>>[],
                'reasoningParams': [
                  legacyParam('voice_effort', ['a', 'b']),
                ],
                'maxWordsPerRequest': 0,
                'supportStream': false,
                'supportInstruction': false,
                'typeConfig': <String, dynamic>{},
              }
            ],
          }
        ],
      };
      SharedPreferences.setMockInitialValues({
        'provider_entries': jsonEncode([...llmJson, ttsEntry]),
      });
      final container = ProviderContainer(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifier(),
          ),
        ],
      );
      await container.read(providerEntriesProvider.notifier).load();

      final tts = container
          .read(providerEntriesProvider)
          .entries
          .firstWhere((e) => e.type == 'tts');
      expect(tts.configs.first.models.first.reasoningParams.first.isEffortParam,
          isFalse,
          reason: 'effort migration only applies to llm entries');
      container.dispose();
    });
  });
}
