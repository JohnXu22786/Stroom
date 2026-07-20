import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/provider_settings_panel.dart' show validateJsonValue;

void main() {
  group('validateJsonValue', () {
    test('returns null for non-json type regardless of value', () {
      expect(validateJsonValue('string', 'not json at all'), isNull);
      expect(validateJsonValue('number', 'hello'), isNull);
      expect(validateJsonValue('boolean', 'maybe'), isNull);
    });

    test('returns null for empty value even with json type', () {
      expect(validateJsonValue('json', ''), isNull);
      expect(validateJsonValue('json', '   '), isNull);
    });

    test('returns null for valid JSON object', () {
      expect(validateJsonValue('json', '{"key": "value"}'), isNull);
      expect(validateJsonValue('json', '{"a":1,"b":2}'), isNull);
    });

    test('returns null for valid JSON array', () {
      expect(validateJsonValue('json', '[1, 2, 3]'), isNull);
      expect(validateJsonValue('json', '["a", "b"]'), isNull);
    });

    test('returns null for valid JSON primitives', () {
      expect(validateJsonValue('json', 'true'), isNull);
      expect(validateJsonValue('json', 'false'), isNull);
      expect(validateJsonValue('json', 'null'), isNull);
      expect(validateJsonValue('json', '123'), isNull);
      expect(validateJsonValue('json', '"hello"'), isNull);
    });

    test('returns error message for invalid JSON', () {
      final error = validateJsonValue('json', '{invalid}');
      expect(error, isNotNull);
      expect(error, contains('JSON'));
    });

    test('returns error for truncated JSON', () {
      final error = validateJsonValue('json', '{"key": "value"');
      expect(error, isNotNull);
    });

    test('returns error for single quote usage in JSON', () {
      final error = validateJsonValue('json', "{'key': 'value'}");
      expect(error, isNotNull);
    });

    test('returns error for trailing comma in JSON', () {
      final error = validateJsonValue('json', '{"a": 1,}');
      expect(error, isNotNull);
    });

    test('returns null for nested JSON', () {
      expect(
        validateJsonValue('json', '{"outer": {"inner": [1,2,3]}}'),
        isNull,
      );
    });

    test('returns error for garbage text', () {
      final error = validateJsonValue('json', 'this is definitely not json');
      expect(error, isNotNull);
    });
  });
}
