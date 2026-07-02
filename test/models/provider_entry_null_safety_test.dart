import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tts_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProviderEntry.fromMap - null safety', () {
    test('handles null id without crashing (generates fallback)', () {
      final map = <String, dynamic>{
        'id': null, // This would previously crash with TypeError
        'type': 'tts',
        'name': 'Test Provider',
        'configs': <Map<String, dynamic>>[],
      };

      // Should not throw
      final entry = ProviderEntry.fromMap(map);

      // Should have generated a fallback id (not null, not empty)
      expect(entry.id, isNotNull);
      expect(entry.id, isNotEmpty);
      expect(entry.type, equals('tts'));
      expect(entry.name, equals('Test Provider'));
    });

    test('handles missing id key without crashing', () {
      final map = <String, dynamic>{
        // No 'id' key at all
        'type': 'llm',
        'name': 'LLM Provider',
        'configs': <Map<String, dynamic>>[],
      };

      // Should not throw
      final entry = ProviderEntry.fromMap(map);

      expect(entry.id, isNotNull);
      expect(entry.id, isNotEmpty);
      expect(entry.type, equals('llm'));
      expect(entry.name, equals('LLM Provider'));
    });

    test('handles null id in old format (flat config) without crashing', () {
      final map = <String, dynamic>{
        'id': null, // null id in old format
        'type': 'tts',
        'name': 'Old Provider',
        'providerName': 'OldName',
        'host': 'http://example.com',
        'key': 'test-key',
        'models': <Map<String, dynamic>>[],
      };

      // Should not throw
      final entry = ProviderEntry.fromMap(map);

      expect(entry.id, isNotNull);
      expect(entry.id, isNotEmpty);
      expect(entry.type, equals('tts'));
      expect(entry.name, equals('Old Provider'));
    });

    test('handles empty string id gracefully', () {
      final map = <String, dynamic>{
        'id': '',
        'type': 'ocr',
        'name': 'OCR Provider',
        'configs': <Map<String, dynamic>>[],
      };

      // Should not throw
      final entry = ProviderEntry.fromMap(map);

      // Empty string id should result in a generated id
      // (empty id is the same problem as null)
      expect(entry.id, isNotNull);
      expect(entry.id, isNotEmpty);
      expect(entry.id, isNot(equals('')));
    });

    test('preserves valid id when present', () {
      final map = <String, dynamic>{
        'id': 'my_custom_id_123',
        'type': 'asr',
        'name': 'ASR Provider',
        'configs': <Map<String, dynamic>>[],
      };

      final entry = ProviderEntry.fromMap(map);

      expect(entry.id, equals('my_custom_id_123'));
    });

    test('handles null configs list gracefully', () {
      final map = <String, dynamic>{
        'id': 'test_id',
        'type': 'mcp',
        'name': 'MCP Provider',
        // configs is explicitly null
        'configs': null,
      };

      // Should not throw
      final entry = ProviderEntry.fromMap(map);

      expect(entry.id, equals('test_id'));
      expect(entry.configs, isEmpty);
    });

    test('handles all-null map without crashing', () {
      final map = <String, dynamic>{
        'id': null,
        'type': null,
        'name': null,
      };

      // Should not throw
      final entry = ProviderEntry.fromMap(map);

      expect(entry.id, isNotNull);
      expect(entry.id, isNotEmpty);
      expect(entry.type, equals('tts')); // default
      expect(entry.name, equals('')); // empty fallback
    });
  });

  group('ProviderEntry roundtrip', () {
    test('toMap and fromMap roundtrip with null id produces valid entry', () {
      final map = <String, dynamic>{
        'id': null,
        'type': 'tts',
        'name': 'Roundtrip Test',
        'configs': <Map<String, dynamic>>[],
      };

      final entry = ProviderEntry.fromMap(map);
      final roundtripped = entry.toMap();

      // The id should be a generated one (not null)
      expect(roundtripped['id'], isNotNull);
      expect(roundtripped['id'], isNotEmpty);
      expect(roundtripped['type'], equals('tts'));
      expect(roundtripped['name'], equals('Roundtrip Test'));
    });
  });
}
