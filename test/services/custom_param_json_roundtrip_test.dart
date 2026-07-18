import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tts_models.dart';

void main() {
  group('CustomParam JSON defaultValue behavior', () {
    test('CustomParam.defaultValue is always stored as String', () {
      final param = CustomParam(
        paramName: 'config',
        defaultValue: '{"key": "value"}',
        type: 'json',
      );
      expect(param.defaultValue, isA<String>());
    });

    test('CustomParam JSON defaultValue round-trips through toMap/fromMap', () {
      final original = CustomParam(
        paramName: 'config',
        defaultValue: '{"key": "value", "nested": {"a": 1}}',
        type: 'json',
      );

      // What happens when the model config is saved to SharedPreferences
      final modelConfig = ModelConfig(
        modelId: 'test',
        name: 'Test',
        customParams: [original],
      );

      // Serialize (as SharedPreferences would)
      final jsonStr = jsonEncode(modelConfig.toMap());

      // Verify the JSON output contains defaultValue as a String (quoted)
      // This is IMPORTANT - the JSON string must be a valid JSON string value
      final raw = jsonDecode(jsonStr) as Map<String, dynamic>;
      final params = raw['customParams'] as List;
      final paramMap = params[0] as Map<String, dynamic>;

      // In JSON, the defaultValue should be a string value (quoted)
      expect(paramMap['defaultValue'], isA<String>());
      expect(paramMap['defaultValue'], equals('{"key": "value", "nested": {"a": 1}}'));

      // Deserialize back
      final restoredModel = ModelConfig.fromMap(raw);
      final restoredParam = restoredModel.customParams[0];

      // The defaultValue should remain a String
      expect(restoredParam.defaultValue, isA<String>());
      expect(restoredParam.defaultValue, equals('{"key": "value", "nested": {"a": 1}}'));
    });

    test('Empty string defaultValue is handled correctly', () {
      final param = CustomParam(
        paramName: 'config',
        defaultValue: '',
        type: 'json',
      );

      // Simulate what parseJsonValue does
      dynamic parsed;
      try {
        parsed = jsonDecode(param.defaultValue);
      } catch (_) {
        parsed = param.defaultValue;
      }

      // Empty string is NOT valid JSON, so it stays as string
      expect(parsed, isA<String>());
      expect(parsed, equals(''));
    });

    test('jsonDecode correctly parses valid JSON from CustomParam.defaultValue',
        () {
      final testCases = [
        {'defaultValue': '{"key": "value"}', 'expectedType': Map},
        {'defaultValue': '["a", "b"]', 'expectedType': List},
        {'defaultValue': '42', 'expectedType': num},
        {'defaultValue': 'true', 'expectedType': bool},
        {'defaultValue': 'null', 'expectedType': Null},
      ];

      for (final tc in testCases) {
        final value = tc['defaultValue'] as String;
        final result = jsonDecode(value);

        if (tc['expectedType'] == Null) {
          expect(result, isNull);
        } else {
          expect(result, isA(tc['expectedType'] as Type),
              reason: 'Failed for value: $value');
        }
      }
    });
  });

  group('ModelConfig JSON round-trip with custom params', () {
    test('full ModelConfig serialization preserves JSON defaultValue as string',
        () {
      final config = ModelConfig(
        modelId: 'test-model',
        name: 'Test Model',
        customParams: [
          CustomParam(paramName: 'str', defaultValue: 'hello', type: 'string'),
          CustomParam(paramName: 'num', defaultValue: '42', type: 'number'),
          CustomParam(paramName: 'bool', defaultValue: 'true', type: 'boolean'),
          CustomParam(
              paramName: 'json', defaultValue: '{"key": "value"}', type: 'json'),
        ],
      );

      final jsonStr = jsonEncode(config.toMap());
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final restored = ModelConfig.fromMap(decoded);

      expect(restored.customParams.length, equals(4));
      expect(restored.customParams[3].defaultValue,
          equals('{"key": "value"}'));
      expect(restored.customParams[3].type, equals('json'));
    });
  });
}
