import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  group('ParamType - json type', () {
    test('fromValue returns default string for unknown value', () {
      expect(ParamType.fromValue('unknown').value, equals('string'));
    });
  });

  group('ReasoningParam - type field', () {
    test('fromMap defaults type to string when missing', () {
      final param = ReasoningParam.fromMap({
        'paramName': 'test',
        'options': ['a', 'b'],
      });
      expect(param.type, equals('string'));
    });
  });

  group('ReasoningParam - existing tests still pass with type field', () {
    test('toMap serialization', () {
      final param = ReasoningParam(
        paramName: 'reasoning_effort',
        options: ['low', 'medium', 'high'],
        enabled: false,
      );
      final map = param.toMap();
      expect(map, {
        'paramName': 'reasoning_effort',
        'options': ['low', 'medium', 'high'],
        'enabled': false,
        'isReasoningToggle': false,
        'isEffortParam': false,
        'type': 'string',
      });
    });

    test('fromMap deserialization', () {
      final param = ReasoningParam.fromMap({
        'paramName': 'thinking.type',
        'options': ['enabled'],
        'enabled': false,
      });
      expect(param.paramName, 'thinking.type');
      expect(param.options, ['enabled']);
      expect(param.enabled, isFalse);
      expect(param.type, equals('string'));
    });

    test('fromMap handles missing options', () {
      final param = ReasoningParam.fromMap({
        'paramName': 'reasoning_effort',
      });
      expect(param.paramName, 'reasoning_effort');
      expect(param.options, isEmpty);
    });
  });
}
