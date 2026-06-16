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
        enabled: false,
      );
      final map = param.toMap();
      expect(map, {
        'paramName': 'reasoning_effort',
        'options': ['low', 'medium', 'high'],
        'enabled': false,
        'isReasoningToggle': false,
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

    test('constructor with default enabled', () {
      final param = ReasoningParam(paramName: 'thinking.type');
      expect(param.enabled, isTrue);
    });

    test('constructor with explicit enabled', () {
      final param = ReasoningParam(
        paramName: 'thinking.type',
        enabled: false,
      );
      expect(param.enabled, isFalse);
    });

    test('toMap serialization includes enabled', () {
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
        'type': 'string',
      });
    });

    test('fromMap deserialization includes enabled', () {
      final param = ReasoningParam.fromMap({
        'paramName': 'thinking.type',
        'options': ['enabled'],
        'enabled': false,
      });
      expect(param.paramName, 'thinking.type');
      expect(param.options, ['enabled']);
      expect(param.enabled, isFalse);
    });

    test('fromMap defaults enabled to true when missing', () {
      final param = ReasoningParam.fromMap({
        'paramName': 'thinking.type',
        'options': ['enabled'],
      });
      expect(param.enabled, isTrue);
    });

    test('copy preserves enabled', () {
      final param = ReasoningParam(
        paramName: 'test',
        enabled: false,
        options: ['a', 'b'],
      );
      final copy = param.copy();
      expect(copy.enabled, isFalse);
      
      // Verify independence
      copy.enabled = true;
      expect(param.enabled, isFalse);
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

  group('ReasoningParam validation (toggle required)', () {
    // ========== Toggle: fully empty = valid (optional) ==========
    test('toggle with all fields empty has no validation error (optional)',
        () {
      final param = ReasoningParam(
        paramName: '',
        isReasoningToggle: true,
        onValue: '',
        offValue: '',
        options: [],
      );
      expect(param.validationError, isNull);
    });

    test('toggle with null onValue and offValue has no validation error when name also empty',
        () {
      final param = ReasoningParam(
        paramName: '',
        isReasoningToggle: true,
        onValue: null,
        offValue: null,
        options: [],
      );
      expect(param.validationError, isNull);
    });

    // ========== Toggle: partially filled = error ==========
    test('toggle with name but no values has validation error', () {
      final param = ReasoningParam(
        paramName: 'thinking.type',
        isReasoningToggle: true,
        onValue: '',
        offValue: '',
        options: [],
      );
      expect(param.validationError, isNotNull);
    });

    test('toggle with onValue but no name has validation error', () {
      final param = ReasoningParam(
        paramName: '',
        isReasoningToggle: true,
        onValue: 'enabled',
        offValue: '',
        options: [],
      );
      expect(param.validationError, isNotNull);
    });

    test('toggle with offValue but no name has validation error', () {
      final param = ReasoningParam(
        paramName: '',
        isReasoningToggle: true,
        onValue: '',
        offValue: 'disabled',
        options: [],
      );
      expect(param.validationError, isNotNull);
    });

    test('toggle with name and onValue but missing offValue has validation error',
        () {
      final param = ReasoningParam(
        paramName: 'thinking.type',
        isReasoningToggle: true,
        onValue: 'enabled',
        offValue: '',
        options: [],
      );
      expect(param.validationError, isNotNull);
    });

    test('toggle with name and offValue but missing onValue has validation error',
        () {
      final param = ReasoningParam(
        paramName: 'thinking.type',
        isReasoningToggle: true,
        onValue: '',
        offValue: 'disabled',
        options: [],
      );
      expect(param.validationError, isNotNull);
    });

    // ========== Toggle: fully filled = valid ==========
    test('toggle with all fields filled has no validation error', () {
      final param = ReasoningParam(
        paramName: 'thinking.type',
        isReasoningToggle: true,
        onValue: 'enabled',
        offValue: 'disabled',
        options: [],
      );
      expect(param.validationError, isNull);
    });

    // ========== Non-toggle params ==========
    test('non-toggle param with empty paramName has validation error', () {
      final param = ReasoningParam(
        paramName: '',
        isReasoningToggle: false,
        options: ['low', 'medium'],
      );
      expect(param.validationError, isNotNull);
    });

    test('non-toggle param with empty option has validation error', () {
      final param = ReasoningParam(
        paramName: 'reasoning_effort',
        isReasoningToggle: false,
        options: ['low', '', 'high'],
      );
      expect(param.validationError, isNotNull);
    });

    test('non-toggle param fully filled has no validation error', () {
      final param = ReasoningParam(
        paramName: 'reasoning_effort',
        isReasoningToggle: false,
        options: ['low', 'medium', 'high'],
      );
      expect(param.validationError, isNull);
    });

    test('non-toggle param with no options but valid name has no validation error',
        () {
      final param = ReasoningParam(
        paramName: 'some_param',
        isReasoningToggle: false,
        options: [],
      );
      expect(param.validationError, isNull);
    });
  });

  group('ReasoningParam.isFilledToggle', () {
    test('returns true when all toggle fields are non-empty', () {
      final param = ReasoningParam(
        paramName: 'thinking.type',
        isReasoningToggle: true,
        onValue: 'enabled',
        offValue: 'disabled',
      );
      expect(param.isFilledToggle, isTrue);
    });

    test('returns false when all toggle fields are empty', () {
      final param = ReasoningParam(
        paramName: '',
        isReasoningToggle: true,
        onValue: '',
        offValue: '',
      );
      expect(param.isFilledToggle, isFalse);
    });

    test('returns false when onValue is empty but name is filled', () {
      final param = ReasoningParam(
        paramName: 'thinking.type',
        isReasoningToggle: true,
        onValue: '',
        offValue: 'disabled',
      );
      expect(param.isFilledToggle, isFalse);
    });

    test('returns false when offValue is empty but name is filled', () {
      final param = ReasoningParam(
        paramName: 'thinking.type',
        isReasoningToggle: true,
        onValue: 'enabled',
        offValue: '',
      );
      expect(param.isFilledToggle, isFalse);
    });

    test('returns false when name is empty but values are filled', () {
      final param = ReasoningParam(
        paramName: '',
        isReasoningToggle: true,
        onValue: 'enabled',
        offValue: 'disabled',
      );
      expect(param.isFilledToggle, isFalse);
    });

    test('returns false for non-toggle param', () {
      final param = ReasoningParam(
        paramName: 'some_param',
        isReasoningToggle: false,
        options: ['low', 'high'],
      );
      expect(param.isFilledToggle, isFalse);
    });

    test('returns false when all fields are nullish (null values)', () {
      final param = ReasoningParam(
        paramName: '',
        isReasoningToggle: true,
        onValue: null,
        offValue: null,
      );
      expect(param.isFilledToggle, isFalse);
    });
  });
}
