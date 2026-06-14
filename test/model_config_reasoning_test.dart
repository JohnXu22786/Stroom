import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  group('ModelConfig reasoningParams with ReasoningParam', () {
    test('default reasoningParams is empty', () {
      final config = ModelConfig(name: 'Test', modelId: 'test');
      expect(config.reasoningParams, isEmpty);
    });

    test('can set reasoningParams with ReasoningParam list', () {
      final config = ModelConfig(
        name: 'Test',
        modelId: 'test',
        reasoningParams: [
          ReasoningParam(
            paramName: 'reasoning_effort',
            options: ['low', 'medium', 'high'],
          ),
        ],
      );
      expect(config.reasoningParams.length, 1);
      expect(config.reasoningParams[0].paramName, 'reasoning_effort');
      expect(config.reasoningParams[0].options, ['low', 'medium', 'high']);
    });

    test('multiple reasoning params with different options', () {
      final config = ModelConfig(
        name: 'Test',
        modelId: 'test',
        reasoningParams: [
          ReasoningParam(
            paramName: 'reasoning_effort',
            options: ['low', 'medium', 'high'],
          ),
          ReasoningParam(
            paramName: 'thinking.type',
            options: ['enabled'],
          ),
          ReasoningParam(
            paramName: 'budget_tokens',
            options: ['max'],
          ),
        ],
      );
      expect(config.reasoningParams.length, 3);
    });

    test('toMap serialization includes reasoningParams', () {
      final config = ModelConfig(
        name: 'Test',
        modelId: 'test',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'reasoning_effort',
            options: ['low', 'medium', 'high'],
          ),
        ],
      );
      final map = config.toMap();
      expect(map['reasoningParams'], isA<List>());
      expect((map['reasoningParams'] as List).length, 1);
      final param = (map['reasoningParams'] as List).first as Map;
      expect(param['paramName'], 'reasoning_effort');
      expect(param['options'], ['low', 'medium', 'high']);
    });

    test('fromMap deserialization of reasoningParams', () {
      final config = ModelConfig.fromMap({
        'name': 'Test',
        'modelId': 'test',
        'typeConfig': {'context': 4096},
        'reasoningParams': [
          {'paramName': 'reasoning_effort', 'options': ['low', 'medium', 'high']},
          {'paramName': 'thinking.type', 'options': ['enabled', 'disabled']},
        ],
      });
      expect(config.reasoningParams.length, 2);
      expect(config.reasoningParams[0].paramName, 'reasoning_effort');
      expect(config.reasoningParams[0].options, ['low', 'medium', 'high']);
      expect(config.reasoningParams[1].paramName, 'thinking.type');
      expect(config.reasoningParams[1].options, ['enabled', 'disabled']);
    });

    test('fromMap handles old format CustomParam reasoningParams gracefully', () {
      // Old format had paramName, defaultValue, type instead of options
      final config = ModelConfig.fromMap({
        'name': 'Test',
        'modelId': 'test',
        'typeConfig': {'context': 4096},
        'reasoningParams': [
          {'paramName': 'thinking.type', 'defaultValue': 'enabled', 'type': 'string'},
          {'paramName': 'reasoning_effort', 'defaultValue': 'medium', 'type': 'string'},
        ],
      });
      // Should convert old format to new format gracefully
      expect(config.reasoningParams.length, 2);
      // Old format without options should have empty options
      expect(config.reasoningParams[0].paramName, 'thinking.type');
      expect(config.reasoningParams[1].paramName, 'reasoning_effort');
    });

    test('copy preserves reasoningParams', () {
      final config = ModelConfig(
        name: 'Test',
        modelId: 'test',
        reasoningParams: [
          ReasoningParam(
            paramName: 'test',
            options: ['a', 'b'],
          ),
        ],
      );
      final copy = config.copy();
      expect(copy.reasoningParams.length, 1);
      expect(copy.reasoningParams[0].paramName, 'test');
      expect(copy.reasoningParams[0].options, ['a', 'b']);
    });
  });
}
