import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/assistant.dart' show CustomParameter;
import 'package:stroom/models/tts_models.dart'
    show CustomParam, ModelConfig, ParamType;
import 'package:stroom/services/chat_service.dart';

void main() {
  // ====================================================================
  // Tests for ChatService.parseJsonValue — the core JSON parsing utility
  // ====================================================================
  group('ChatService.parseJsonValue', () {
    test('parses valid JSON object string to Map', () {
      final result = ChatService.parseJsonValue('{"key": "value"}');
      expect(result, isA<Map>());
      expect((result as Map)['key'], equals('value'));
    });

    test('parses valid JSON array string to List', () {
      final result = ChatService.parseJsonValue('["a", "b", "c"]');
      expect(result, isA<List>());
      expect((result as List).length, equals(3));
    });

    test('parses valid JSON number string to num', () {
      final result = ChatService.parseJsonValue('42');
      expect(result, isA<num>());
      expect(result, equals(42));
    });

    test('parses valid JSON boolean string to bool', () {
      final result = ChatService.parseJsonValue('true');
      expect(result, isTrue);
    });

    test('parses null JSON string to null', () {
      final result = ChatService.parseJsonValue('null');
      expect(result, isNull);
    });

    test('empty string stays as raw string (invalid JSON)', () {
      final result = ChatService.parseJsonValue('');
      expect(result, equals(''));
    });

    test('malformed JSON stays as raw string', () {
      final result = ChatService.parseJsonValue('{invalid json}');
      expect(result, equals('{invalid json}'));
    });

    test('Dart format map (no quotes) stays as raw string', () {
      // This is a KEY edge case: {key: value} is NOT valid JSON
      final result = ChatService.parseJsonValue('{key: value}');
      expect(result, equals('{key: value}'));
    });

    test('deeply nested JSON object is properly parsed', () {
      const nested =
          '{"outer": {"inner": "value", "numbers": [1, 2, 3], "flag": true}}';
      final result = ChatService.parseJsonValue(nested);
      expect(result, isA<Map>());
      final map = result as Map;
      expect(map['outer'], isA<Map>());
      expect((map['outer'] as Map)['inner'], equals('value'));
      expect((map['outer'] as Map)['numbers'], isA<List>());
      expect((map['outer'] as Map)['flag'], isTrue);
    });
  });

  // ====================================================================
  // Tests for ChatService.parseJsonParam — handles both String & pre-parsed
  // ====================================================================
  group('ChatService.parseJsonParam', () {
    test('String value is parsed via jsonDecode', () {
      final result = ChatService.parseJsonParam('{"key": "value"}');
      expect(result, isA<Map>());
    });

    test('Map value is returned as-is (no double-parse)', () {
      final map = {'key': 'value'};
      final result = ChatService.parseJsonParam(map);
      expect(result, same(map));
    });

    test('List value is returned as-is (no double-parse)', () {
      final list = ['a', 'b'];
      final result = ChatService.parseJsonParam(list);
      expect(result, same(list));
    });

    test('num value is returned as-is', () {
      final result = ChatService.parseJsonParam(42);
      expect(result, equals(42));
    });

    test('bool value is returned as-is', () {
      final result = ChatService.parseJsonParam(true);
      expect(result, isTrue);
    });

    test('null value returns null', () {
      final result = ChatService.parseJsonParam(null);
      expect(result, isNull);
    });
  });

  // ====================================================================
  // Tests for CustomParam — model-level parameter storage
  // ====================================================================
  group('CustomParam defaultValue type behavior', () {
    test('defaultValue is always stored as String', () {
      final param = CustomParam(
        paramName: 'cfg',
        defaultValue: '{"enabled": true}',
        type: 'json',
      );
      expect(param.defaultValue, isA<String>());
      expect(param.defaultValue, equals('{"enabled": true}'));
    });

    test('defaultValue survives toMap/fromMap round-trip', () {
      final original = CustomParam(
        paramName: 'config',
        defaultValue: '{"key": "value"}',
        type: 'json',
      );
      final map = original.toMap();
      final restored = CustomParam.fromMap(map);

      expect(restored.defaultValue, isA<String>());
      expect(restored.defaultValue, equals('{"key": "value"}'));
      expect(restored.type, equals('json'));
    });

    test('defaultValue survives ModelConfig jsonEncode/jsonDecode round-trip',
        () {
      final model = ModelConfig(
        modelId: 'test',
        name: 'Test',
        customParams: [
          CustomParam(
            paramName: 'response_format',
            defaultValue: '{"type": "json_object"}',
            type: 'json',
          ),
        ],
      );

      // Full round-trip: toMap -> jsonEncode -> jsonDecode -> fromMap
      final jsonStr = jsonEncode(model.toMap());
      final decodedMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      final restored = ModelConfig.fromMap(decodedMap);

      expect(restored.customParams.length, equals(1));
      final param = restored.customParams[0];
      expect(param.defaultValue, isA<String>());
      expect(param.defaultValue, equals('{"type": "json_object"}'));
    });

    test('ParamType.json has correct value and label', () {
      expect(ParamType.json.value, equals('json'));
      expect(ParamType.json.label, equals('JSON'));
    });
  });

  // ====================================================================
  // Tests for CustomParameter — assistant-level dynamic value
  // ====================================================================
  group('CustomParameter JSON value handling', () {
    test('CustomParameter with Map value survives toMap/fromMap', () {
      final original = CustomParameter(
        name: 'provider',
        type: 'json',
        value: {
          'order': ['deepinfra', 'stepfun/fp8']
        },
      );
      final map = original.toMap();
      final restored = CustomParameter.fromMap(map);

      expect(restored.value, isA<Map>());
      expect((restored.value as Map)['order'], isA<List>());
      expect((restored.value as Map)['order'],
          equals(['deepinfra', 'stepfun/fp8']));
    });

    test('CustomParameter Map value survives jsonEncode/jsonDecode round-trip',
        () {
      final original = CustomParameter(
        name: 'provider',
        type: 'json',
        value: {
          'order': ['deepinfra', 'stepfun/fp8']
        },
      );
      final jsonStr = jsonEncode(original.toMap());
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final restored = CustomParameter.fromMap(decoded);

      expect(restored.value, isA<Map>());
      expect((restored.value as Map)['order'],
          equals(['deepinfra', 'stepfun/fp8']));
    });

    test('CustomParameter with List value survives round-trip', () {
      final original = CustomParameter(
        name: 'items',
        type: 'json',
        value: ['a', 'b', 42, true, null],
      );
      final jsonStr = jsonEncode(original.toMap());
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final restored = CustomParameter.fromMap(decoded);

      expect(restored.value, isA<List>());
      expect((restored.value as List).length, equals(5));
      expect((restored.value as List)[2], equals(42));
    });

    test('CustomParameter number value survives round-trip', () {
      final original =
          CustomParameter(name: 'count', type: 'number', value: 42);
      final jsonStr = jsonEncode(original.toMap());
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final restored = CustomParameter.fromMap(decoded);
      expect(restored.value, equals(42));
    });

    test('CustomParameter boolean value survives round-trip', () {
      final original =
          CustomParameter(name: 'flag', type: 'boolean', value: true);
      final jsonStr = jsonEncode(original.toMap());
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final restored = CustomParameter.fromMap(decoded);
      expect(restored.value, isTrue);
    });

    test('CustomParameter string value survives round-trip', () {
      final original =
          CustomParameter(name: 'name', type: 'string', value: 'hello');
      final jsonStr = jsonEncode(original.toMap());
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final restored = CustomParameter.fromMap(decoded);
      expect(restored.value, equals('hello'));
    });
  });

  // ====================================================================
  // Tests verifying that default string values for JSON params are NOT
  // valid JSON (ensuring we understand the edge cases)
  // ====================================================================
  group('JSON custom param edge cases', () {
    test('A plain string like "hello" IS valid JSON after jsonDecode', () {
      // jsonDecode('"hello"') returns 'hello' (a Dart String)
      final result = ChatService.parseJsonValue('"hello"');
      // The JSON string "hello" is parsed to the Dart string 'hello'
      expect(result, equals('hello'));
    });

    test(
        'A raw string "hello" WITHOUT quotes is NOT valid JSON (stays as string)',
        () {
      // jsonDecode('hello') throws because it's not valid JSON
      final result = ChatService.parseJsonValue('hello');
      // Falls back to raw string
      expect(result, equals('hello'));
    });

    test('Number string in json type is parsed as number', () {
      // Some users might enter a plain number in a json field
      final result = ChatService.parseJsonValue('42');
      expect(result, isA<num>());
      expect(result, equals(42));
    });

    test('Boolean string in json type is parsed as bool', () {
      final result = ChatService.parseJsonValue('true');
      expect(result, isTrue);
    });

    test('Map/List value for non-json type stays as-is', () {
      // This tests the edge case where someone passes a parsed Map
      // through a non-json type (just verifying behavior)
      final result = ChatService.parseJsonParam({'key': 'value'});
      expect(result, isA<Map>());
    });
  });
}
