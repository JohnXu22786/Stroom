import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  group('ModelConfig - LLM typeConfig parameters', () {
    test('stores temperature in typeConfig', () {
      final config = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {
          'context': 4096,
          'temperature': 0.7,
          'topP': 0.9,
        },
      );

      expect(config.typeConfig['context'], equals(4096));
      expect(config.typeConfig['temperature'], equals(0.7));
      expect(config.typeConfig['topP'], equals(0.9));
    });

    test('stores maxTokens in typeConfig', () {
      final config = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {
          'context': 8192,
          'maxTokens': 4096,
        },
      );

      expect(config.typeConfig['maxTokens'], equals(4096));
    });

    test('stores frequencyPenalty and presencePenalty in typeConfig', () {
      final config = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {
          'frequencyPenalty': 0.5,
          'presencePenalty': -0.3,
        },
      );

      expect(config.typeConfig['frequencyPenalty'], equals(0.5));
      expect(config.typeConfig['presencePenalty'], equals(-0.3));
    });

    test('stores seed in typeConfig', () {
      final config = ModelConfig(
        name: 'Test',
        modelId: 'test-model',
        typeConfig: {
          'seed': 42,
        },
      );

      expect(config.typeConfig['seed'], equals(42));
    });

    test('serializes and deserializes typeConfig with LLM params', () {
      final original = ModelConfig(
        name: 'GPT-4o',
        modelId: 'gpt-4o',
        typeConfig: {
          'context': 128000,
          'temperature': 0.5,
          'topP': 0.95,
          'maxTokens': 4096,
          'frequencyPenalty': 0.2,
          'presencePenalty': 0.1,
          'seed': 12345,
        },
      );

      final map = original.toMap();
      final restored = ModelConfig.fromMap(map);

      expect(restored.modelId, equals('gpt-4o'));
      expect(restored.typeConfig['context'], equals(128000));
      expect(restored.typeConfig['temperature'], equals(0.5));
      expect(restored.typeConfig['topP'], equals(0.95));
      expect(restored.typeConfig['maxTokens'], equals(4096));
      expect(restored.typeConfig['frequencyPenalty'], equals(0.2));
      expect(restored.typeConfig['presencePenalty'], equals(0.1));
      expect(restored.typeConfig['seed'], equals(12345));
    });

    test('typeConfig handles null/empty LLM params gracefully', () {
      final config = ModelConfig(
        name: 'Minimal',
        modelId: 'minimal-model',
      );

      // Should have defaults
      expect(config.typeConfig, isEmpty);
    });
  });
}
