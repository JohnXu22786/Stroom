import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  group('ReasoningParam model', () {
    test('constructor with required name', () {
      final param = ReasoningParam(paramName: 'reasoning_effort');
      expect(param.paramName, 'reasoning_effort');
      expect(param.options, isEmpty);
    });

    test('constructor with name and options', () {
      final param = ReasoningParam(
        paramName: 'reasoning_effort',
        options: ['low', 'medium', 'high'],
      );
      expect(param.paramName, 'reasoning_effort');
      expect(param.options, ['low', 'medium', 'high']);
    });

    test('options preserved in order', () {
      final param = ReasoningParam(
        paramName: 'thinking.type',
        options: ['enabled'],
      );
      expect(param.options, ['enabled']);
    });

    test('toMap serialization', () {
      final param = ReasoningParam(
        paramName: 'reasoning_effort',
        options: ['low', 'medium', 'high'],
      );
      final map = param.toMap();
      expect(map, {
        'paramName': 'reasoning_effort',
        'options': ['low', 'medium', 'high'],
      });
    });

    test('fromMap deserialization', () {
      final param = ReasoningParam.fromMap({
        'paramName': 'thinking.type',
        'options': ['enabled'],
      });
      expect(param.paramName, 'thinking.type');
      expect(param.options, ['enabled']);
    });

    test('fromMap handles missing options', () {
      final param = ReasoningParam.fromMap({
        'paramName': 'reasoning_effort',
      });
      expect(param.paramName, 'reasoning_effort');
      expect(param.options, isEmpty);
    });

    test('fromMap handles null options', () {
      final param = ReasoningParam.fromMap({
        'paramName': 'test',
        'options': null,
      });
      expect(param.options, isEmpty);
    });

    test('copy creates independent instance', () {
      final param = ReasoningParam(
        paramName: 'test',
        options: ['a', 'b'],
      );
      final copy = param.copy();
      expect(copy.paramName, 'test');
      expect(copy.options, ['a', 'b']);
      
      // Verify independence
      copy.paramName = 'changed';
      copy.options.add('c');
      expect(param.paramName, 'test');
      expect(param.options, ['a', 'b']);
    });

    test('options with single value (e.g. only max)', () {
      final param = ReasoningParam(
        paramName: 'budget_tokens',
        options: ['max'],
      );
      expect(param.paramName, 'budget_tokens');
      expect(param.options, ['max']);
    });

    test('options with boolean values', () {
      final param = ReasoningParam(
        paramName: 'thinking.type',
        options: ['true', 'false'],
      );
      expect(param.options, ['true', 'false']);
    });
  });
}
