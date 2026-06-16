import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  group('ParamType - json type', () {
    test('includes json type', () {
      expect(ParamType.values.any((t) => t.value == 'json'), isTrue,
          reason: 'ParamType should include json type');
    });

    test('json type label is correct', () {
      final jsonType = ParamType.fromValue('json');
      expect(jsonType.label, equals('JSON'));
    });

    test('json type needsQuotes is false (sent as raw object, not quoted string)', () {
      final jsonType = ParamType.fromValue('json');
      // JSON is serialized as a raw object, not a quoted string
      // For model API calls, json values are sent as objects, not strings
      expect(jsonType.needsQuotes, isFalse);
    });

    test('fromValue returns json for json value', () {
      expect(ParamType.fromValue('json').value, equals('json'));
    });

    test('fromValue returns default string for unknown value', () {
      expect(ParamType.fromValue('unknown').value, equals('string'));
    });

    test('all type values are unique', () {
      final values = ParamType.values.map((t) => t.value).toSet();
      expect(values.length, equals(ParamType.values.length));
    });
  });

  group('ReasoningParam - type field', () {
    test('default type is string', () {
      final param = ReasoningParam(paramName: 'test');
      expect(param.type, equals('string'));
    });

    test('can set type to number', () {
      final param = ReasoningParam(paramName: 'test', type: 'number');
      expect(param.type, equals('number'));
    });

    test('can set type to boolean', () {
      final param = ReasoningParam(paramName: 'test', type: 'boolean');
      expect(param.type, equals('boolean'));
    });

    test('can set type to json', () {
      final param = ReasoningParam(paramName: 'test', type: 'json');
      expect(param.type, equals('json'));
    });

    test('toMap serializes type field', () {
      final param = ReasoningParam(
        paramName: 'test',
        type: 'number',
        options: ['1', '2', '3'],
      );
      final map = param.toMap();
      expect(map['type'], equals('number'));
    });

    test('fromMap deserializes type field', () {
      final param = ReasoningParam.fromMap({
        'paramName': 'test',
        'type': 'boolean',
        'options': ['true', 'false'],
      });
      expect(param.type, equals('boolean'));
    });

    test('fromMap defaults type to string when missing', () {
      final param = ReasoningParam.fromMap({
        'paramName': 'test',
        'options': ['a', 'b'],
      });
      expect(param.type, equals('string'));
    });

    test('copy preserves type field', () {
      final param = ReasoningParam(
        paramName: 'test',
        type: 'number',
        options: ['1', '2'],
      );
      final copy = param.copy();
      expect(copy.type, equals('number'));

      // Verify independence
      copy.type = 'string';
      expect(param.type, equals('number'));
    });

    test('toggle param with type string has correct serialization', () {
      final param = ReasoningParam(
        paramName: 'thinking.type',
        isReasoningToggle: true,
        onValue: 'enabled',
        offValue: 'disabled',
        type: 'string',
      );
      final map = param.toMap();
      expect(map['type'], equals('string'));
    });
  });

  group('ReasoningParam - existing tests still pass with type field', () {
    test('constructor with required name', () {
      final param = ReasoningParam(paramName: 'reasoning_effort');
      expect(param.paramName, 'reasoning_effort');
      expect(param.options, isEmpty);
      expect(param.type, equals('string'));
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
      expect(param.type, equals('string'));
    });

    test('fromMap handles missing options', () {
      final param = ReasoningParam.fromMap({
        'paramName': 'reasoning_effort',
      });
      expect(param.paramName, 'reasoning_effort');
      expect(param.options, isEmpty);
    });

    test('copy preserves all fields', () {
      final param = ReasoningParam(
        paramName: 'test',
        enabled: false,
        options: ['a', 'b'],
        isReasoningToggle: true,
        onValue: 'on',
        offValue: 'off',
        type: 'boolean',
      );
      final copy = param.copy();
      expect(copy.paramName, equals('test'));
      expect(copy.enabled, isFalse);
      expect(copy.options, ['a', 'b']);
      expect(copy.isReasoningToggle, isTrue);
      expect(copy.onValue, equals('on'));
      expect(copy.offValue, equals('off'));
      expect(copy.type, equals('boolean'));

      // Verify independence
      copy.type = 'string';
      expect(param.type, equals('boolean'));
    });
  });
}
