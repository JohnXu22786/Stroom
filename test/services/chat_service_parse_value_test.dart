import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/chat_service.dart';

void main() {
  group('ChatService.parseJsonValue', () {
    test('parses valid JSON object', () {
      final result = ChatService.parseJsonValue('{"key": "value", "num": 42}');
      expect(result, isA<Map>());
      expect((result as Map)['key'], equals('value'));
      expect(result['num'], equals(42));
    });

    test('parses valid JSON array', () {
      final result = ChatService.parseJsonValue('[1, 2, 3]');
      expect(result, isA<List>());
      expect((result as List).length, equals(3));
    });

    test('parses JSON number', () {
      final result = ChatService.parseJsonValue('42');
      expect(result, equals(42));
    });

    test('parses JSON boolean', () {
      expect(ChatService.parseJsonValue('true'), isTrue);
      expect(ChatService.parseJsonValue('false'), isFalse);
    });

    test('returns raw string for invalid JSON', () {
      final result = ChatService.parseJsonValue('not-json');
      expect(result, equals('not-json'));
    });

    test('returns raw string for empty string', () {
      final result = ChatService.parseJsonValue('');
      expect(result, equals(''));
    });
  });

  group('ChatService.parseReasoningValue', () {
    test('string type returns the value as-is', () {
      expect(ChatService.parseReasoningValue('hello', 'string'), equals('hello'));
    });

    test('number type parses decimal string to double', () {
      expect(ChatService.parseReasoningValue('3.14', 'number'), closeTo(3.14, 0.001));
    });

    test('number type parses integer string to double', () {
      expect(ChatService.parseReasoningValue('42', 'number'), equals(42.0));
    });

    test('number type defaults to 0.0 for invalid', () {
      expect(ChatService.parseReasoningValue('abc', 'number'), equals(0.0));
    });

    test('boolean type parses "true" to true', () {
      expect(ChatService.parseReasoningValue('true', 'boolean'), isTrue);
    });

    test('boolean type parses "false" to false', () {
      expect(ChatService.parseReasoningValue('false', 'boolean'), isFalse);
    });

    test('boolean type is case-insensitive', () {
      expect(ChatService.parseReasoningValue('True', 'boolean'), isTrue);
      expect(ChatService.parseReasoningValue('TRUE', 'boolean'), isTrue);
    });

    test('boolean type defaults to false for unknown', () {
      expect(ChatService.parseReasoningValue('maybe', 'boolean'), isFalse);
    });

    test('json type parses valid JSON', () {
      final result = ChatService.parseReasoningValue('{"key": "val"}', 'json');
      expect(result, isA<Map>());
      expect((result as Map)['key'], equals('val'));
    });

    test('json type returns raw string for invalid JSON', () {
      expect(ChatService.parseReasoningValue('not-json', 'json'), equals('not-json'));
    });

    test('default type (string) returns value as-is', () {
      expect(ChatService.parseReasoningValue('anything', 'unknown_type'), equals('anything'));
    });
  });
}
