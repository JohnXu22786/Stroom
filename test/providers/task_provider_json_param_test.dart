import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  group('TaskListNotifier.parseJsonCustomParams - JSON type handling', () {
    test('JSON string value is parsed to Map when type is json', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'response_format': '{"type": "json_object"}',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(
            paramName: 'response_format',
            defaultValue: '{"type": "json_object"}',
            type: 'json',
          ),
        ],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      final responseFormat = params['response_format'];
      expect(responseFormat, isA<Map>(),
          reason: 'JSON type param should be a Map, not a String');
      expect((responseFormat as Map)['type'], equals('json_object'));
    });

    test('JSON string value is parsed to List when type is json', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'tools_config': '["tool_a", "tool_b"]',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(
            paramName: 'tools_config',
            defaultValue: '["tool_a", "tool_b"]',
            type: 'json',
          ),
        ],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      final toolsConfig = params['tools_config'];
      expect(toolsConfig, isA<List>(),
          reason: 'JSON type param (array) should be a List, not a String');
      expect((toolsConfig as List).length, equals(2));
      expect(toolsConfig[0], equals('tool_a'));
    });

    test('Invalid JSON string falls back to raw string for json type', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'bad_json': '{invalid json}',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(
            paramName: 'bad_json',
            defaultValue: '{invalid json}',
            type: 'json',
          ),
        ],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      // Malformed JSON should return the raw string
      expect(params['bad_json'], equals('{invalid json}'));
    });

    test('Non-JSON type params are NOT parsed', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'top_k': '50',
        'use_cache': 'true',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(paramName: 'top_k', defaultValue: '50', type: 'number'),
          CustomParam(
              paramName: 'use_cache', defaultValue: 'true', type: 'boolean'),
        ],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      // Number and boolean type params should NOT be parsed by this function
      expect(params['top_k'], equals('50'),
          reason: 'number type param should remain as string');
      expect(params['use_cache'], equals('true'),
          reason: 'boolean type param should remain as string');
    });

    test('Empty string is kept as empty string for json type', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'empty_json': '',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(
            paramName: 'empty_json',
            defaultValue: '',
            type: 'json',
          ),
        ],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      expect(params['empty_json'], equals(''));
    });

    test('Params with names not in modelConfig.customParams are kept as-is',
        () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'unknown_param': '{"some": "json"}',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        // No custom params defined in config
        customParams: [],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      // Without type info, the param should remain unchanged
      expect(params['unknown_param'], equals('{"some": "json"}'));
    });

    test('Already-parsed Map values are not double-parsed', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'response_format': {'type': 'json_object'},
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(
            paramName: 'response_format',
            defaultValue: '{"type": "json_object"}',
            type: 'json',
          ),
        ],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      // Already a Map, should remain unchanged
      final responseFormat = params['response_format'];
      expect(responseFormat, isA<Map>());
      expect((responseFormat as Map)['type'], equals('json_object'));
    });

    test('JSON number string is parsed to num when type is json', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'temperature': '0.8',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(
            paramName: 'temperature',
            defaultValue: '0.8',
            type: 'json',
          ),
        ],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      final value = params['temperature'];
      expect(value, isA<num>(),
          reason: 'JSON number string should be parsed to num');
      expect((value as num), closeTo(0.8, 0.001));
    });

    test('JSON boolean string is parsed to bool when type is json', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'flag': 'true',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(
            paramName: 'flag',
            defaultValue: 'true',
            type: 'json',
          ),
        ],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      expect(params['flag'], isTrue,
          reason: 'JSON boolean string should be parsed to bool');
    });

    test('JSON null string is parsed to null when type is json', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'nullable': 'null',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(
            paramName: 'nullable',
            defaultValue: 'null',
            type: 'json',
          ),
        ],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      expect(params['nullable'], isNull,
          reason: 'JSON null string should be parsed to null');
    });

    test('Multiple JSON params are all parsed correctly', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'config_a': '{"type": "json_object"}',
        'config_b': '["item1", "item2"]',
        'count': '42',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(
            paramName: 'config_a',
            defaultValue: '{"type": "json_object"}',
            type: 'json',
          ),
          CustomParam(
            paramName: 'config_b',
            defaultValue: '["item1", "item2"]',
            type: 'json',
          ),
          CustomParam(
            paramName: 'count',
            defaultValue: '42',
            type: 'json',
          ),
        ],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      expect(params['config_a'], isA<Map>());
      expect(params['config_b'], isA<List>());
      expect(params['count'], isA<num>());
      expect((params['count'] as num), equals(42));
    });

    test('Complex nested JSON object is parsed correctly', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'config': '{"nested": {"key": "value", "list": [1, 2, 3]}}',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(
            paramName: 'config',
            defaultValue: '{"nested": {"key": "value", "list": [1, 2, 3]}}',
            type: 'json',
          ),
        ],
      );

      TaskListNotifier.parseJsonCustomParams(params, modelConfig);

      final config = params['config'];
      expect(config, isA<Map>());
      expect((config as Map)['nested']['key'], equals('value'));
      expect((config['nested']['list'] as List).length, equals(3));
    });

    test('Null params map is handled without crash', () {
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
        customParams: [
          CustomParam(
            paramName: 'response_format',
            defaultValue: '{"type": "json_object"}',
            type: 'json',
          ),
        ],
      );

      // Should not throw when params is null
      expect(
        () => TaskListNotifier.parseJsonCustomParams(null, modelConfig),
        returnsNormally,
      );
    });

    test('ModelConfig with no custom params is handled without crash', () {
      final params = <String, dynamic>{
        'voice': 'alloy',
        'model': 'test-model',
        'some_param': 'value',
      };
      final modelConfig = ModelConfig(
        modelId: 'test-model',
        name: 'Test',
      );

      // Should not throw when customParams is empty
      expect(
        () => TaskListNotifier.parseJsonCustomParams(params, modelConfig),
        returnsNormally,
      );
      expect(params['some_param'], equals('value'));
    });
  });
}
