import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/assistant.dart';

void main() {
  group('CustomParameter JSON value handling', () {
    // These tests verify the logic that should be applied in
    // showAddCustomParameterDialog and showEditCustomParameterDialog.

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
  });
}
