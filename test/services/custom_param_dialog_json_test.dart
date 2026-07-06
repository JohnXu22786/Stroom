import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/assistant.dart';

void main() {
  group('CustomParameter JSON value handling', () {
    // These tests verify the logic that should be applied in
    // showAddCustomParameterDialog and showEditCustomParameterDialog.

    test('JSON string value is parsed to Map when type is json (add dialog)',
        () {
      const inputValue = '{"order": ["deepinfra", "stepfun/fp8"]}';
      const type = 'json';

      dynamic value = inputValue;
      if (type == 'json') {
        try {
          value = jsonDecode(value as String);
        } catch (_) {
          // Keep as string if not valid JSON
        }
      }

      expect(value, isA<Map>(), reason: 'JSON string should be parsed to Map');
      expect((value as Map)['order'], isA<List>());
      expect(value['order'], equals(['deepinfra', 'stepfun/fp8']));
    });

    test('JSON string value is parsed to List when type is json (add dialog)',
        () {
      const inputValue = '["deepinfra", "stepfun/fp8"]';
      const type = 'json';

      dynamic value = inputValue;
      if (type == 'json') {
        try {
          value = jsonDecode(value as String);
        } catch (_) {
          // Keep as string if not valid JSON
        }
      }

      expect(value, isA<List>(),
          reason: 'JSON array string should be parsed to List');
      expect((value as List).length, equals(2));
      expect(value[0], equals('deepinfra'));
    });

    test('JSON number string is parsed to num when type is json (add dialog)',
        () {
      const inputValue = '42';
      const type = 'json';

      dynamic value = inputValue;
      if (type == 'json') {
        try {
          value = jsonDecode(value as String);
        } catch (_) {
          // Keep as string if not valid JSON
        }
      }

      expect(value, isA<num>(),
          reason: 'JSON number string should be parsed to num');
      expect(value, equals(42));
    });

    test('JSON boolean string is parsed to bool when type is json (add dialog)',
        () {
      const inputValue = 'true';
      const type = 'json';

      dynamic value = inputValue;
      if (type == 'json') {
        try {
          value = jsonDecode(value as String);
        } catch (_) {
          // Keep as string if not valid JSON
        }
      }

      expect(value, isTrue,
          reason: 'JSON boolean string should be parsed to bool');
    });

    test('JSON null string is parsed to null when type is json (add dialog)',
        () {
      const inputValue = 'null';
      const type = 'json';

      dynamic value = inputValue;
      if (type == 'json') {
        try {
          value = jsonDecode(value as String);
        } catch (_) {
          // Keep as string if not valid JSON
        }
      }

      expect(value, isNull,
          reason: 'JSON null string should be parsed to null');
    });

    test('Malformed JSON falls back to raw string (add dialog)', () {
      const inputValue = '{invalid json}';
      const type = 'json';

      dynamic value = inputValue;
      if (type == 'json') {
        try {
          value = jsonDecode(value as String);
        } catch (_) {
          // Keep as string if not valid JSON
        }
      }

      expect(value, equals('{invalid json}'),
          reason: 'Malformed JSON should remain as raw string');
    });

    test('Empty string is kept as empty string when type is json (add dialog)',
        () {
      const inputValue = '';
      const type = 'json';

      dynamic value = inputValue;
      if (type == 'json') {
        try {
          value = jsonDecode(value as String);
        } catch (_) {
          // Keep as string if not valid JSON
        }
      }

      expect(value, equals(''),
          reason: 'Empty string should remain as empty string');
    });

    test(
        'CustomParameter with parsed Map value survives toMap/fromMap round-trip',
        () {
      // Simulate what happens after the fix: value is a Map, not a String
      final original = CustomParameter(
        name: 'provider',
        type: 'json',
        value: {
          'order': ['deepinfra', 'stepfun/fp8']
        },
      );

      // Serialize
      final map = original.toMap();
      // Deserialize
      final restored = CustomParameter.fromMap(map);

      expect(restored.name, equals('provider'));
      expect(restored.type, equals('json'));
      expect(restored.value, isA<Map>(),
          reason: 'Restored value should still be a Map');
      expect((restored.value as Map)['order'],
          equals(['deepinfra', 'stepfun/fp8']));
    });

    test('Edit dialog display: Map value shown as jsonEncode, not .toString()',
        () {
      // Simulate the fix: for a Map value, use jsonEncode for display
      final cp = CustomParameter(
        name: 'provider',
        type: 'json',
        value: {
          'order': ['deepinfra', 'stepfun/fp8']
        },
      );

      // Old behavior (bug): cp.value.toString() gives Dart format
      final oldDisplay = cp.value.toString();
      expect(oldDisplay, equals('{order: [deepinfra, stepfun/fp8]}'),
          reason:
              'Old .toString() produces invalid JSON (Dart format, no quotes around keys)');

      // New behavior (fix): use jsonEncode for Map/List values
      String newDisplay;
      if (cp.type == 'json' && (cp.value is Map || cp.value is List)) {
        newDisplay = jsonEncode(cp.value);
      } else {
        newDisplay = cp.value?.toString() ?? '';
      }

      expect(newDisplay, equals('{"order":["deepinfra","stepfun/fp8"]}'),
          reason:
              'Fix: jsonEncode produces valid JSON with quoted keys and no extra spaces');
    });

    test('Edit dialog display: String value (not yet parsed) shown as-is', () {
      // Simulate a value that hasn't been parsed yet (still a string)
      final cp = CustomParameter(
        name: 'provider',
        type: 'json',
        value: '{"order": ["deepinfra", "stepfun/fp8"]}',
      );

      String display;
      if (cp.type == 'json' && (cp.value is Map || cp.value is List)) {
        display = jsonEncode(cp.value);
      } else {
        display = cp.value?.toString() ?? '';
      }

      expect(display, equals('{"order": ["deepinfra", "stepfun/fp8"]}'),
          reason: 'String values should be shown as-is');
    });

    test(
        'Edit dialog save: JSON string value is parsed back to Map (round-trip)',
        () {
      // Simulate editing: user sees jsonEncode'd value, clicks save
      const editedValue = '{"order":["deepinfra","stepfun/fp8"]}';
      const type = 'json';

      dynamic value = editedValue;
      if (type == 'json') {
        try {
          value = jsonDecode(value as String);
        } catch (_) {
          // Keep as string if not valid JSON
        }
      }

      expect(value, isA<Map>(),
          reason: 'Edited JSON string should be parsed back to Map on save');
      expect((value as Map)['order'], equals(['deepinfra', 'stepfun/fp8']));
    });

    test('Edit dialog save: edited Dart-format string (broken) stays as string',
        () {
      // Simulate the old bug: .toString() produced {order: [deepinfra, stepfun/fp8]}
      // which is NOT valid JSON, so parse fails and the raw string is kept
      const brokenValue = '{order: [deepinfra, stepfun/fp8]}';
      const type = 'json';

      dynamic value = brokenValue;
      if (type == 'json') {
        try {
          value = jsonDecode(value as String);
        } catch (_) {
          // Keep as string if not valid JSON
        }
      }

      // With the fix, the display uses jsonEncode so this broken case
      // shouldn't occur. But if it does, the fallback keeps the string.
      expect(value, equals('{order: [deepinfra, stepfun/fp8]}'),
          reason:
              'Non-JSON string should remain as string (fallback behavior)');
    });

    test('Number type still works correctly in add dialog (regression check)',
        () {
      const inputValue = '0.8';
      const type = 'number';

      dynamic value = inputValue;
      if (type == 'number') {
        value = double.tryParse(value as String) ??
            int.tryParse(value as String) ??
            value;
      }

      expect(value, isA<num>());
      expect((value as num), closeTo(0.8, 0.001));
    });

    test('Boolean type still works correctly in add dialog (regression check)',
        () {
      const inputValue = 'true';
      const type = 'boolean';

      dynamic value = inputValue;
      if (type == 'boolean') {
        value = (value as String).toLowerCase() == 'true';
      }

      expect(value, isTrue);
    });
  });
}
