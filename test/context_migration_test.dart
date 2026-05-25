import 'package:flutter_test/flutter_test.dart';

/// Simulate the migration logic used in provider_config.dart and llm_model_config_page.dart
int? _readContext(Map<String, dynamic> typeConfig) {
  return (typeConfig['context'] as num?)?.toInt()
      ?? (typeConfig['maxTokens'] as num?)?.toInt();
}

Map<String, dynamic> _migrateOldModel(Map<String, dynamic> oldModel) {
  final typeConfig = <String, dynamic>{};
  final maxTokens = oldModel['maxTokens'] ?? oldModel['context'];
  if (maxTokens != null) typeConfig['context'] = maxTokens;
  final temperature = oldModel['temperature'];
  if (temperature != null) typeConfig['temperature'] = temperature;
  return typeConfig;
}

void main() {
  group('context backward compatibility', () {
    test('reads from new "context" key', () {
      expect(_readContext({'context': 8192}), 8192);
    });

    test('reads from old "maxTokens" key as fallback', () {
      expect(_readContext({'maxTokens': 4096}), 4096);
    });

    test('new "context" key takes priority over old "maxTokens"', () {
      expect(_readContext({'context': 8192, 'maxTokens': 4096}), 8192);
    });

    test('returns null when neither key exists', () {
      expect(_readContext({'temperature': 0.7}), isNull);
    });

    test('handles num types (double stored as int)', () {
      expect(_readContext({'context': 4096.0}), 4096);
    });

    test('migrate old format with maxTokens', () {
      final result = _migrateOldModel({'maxTokens': 2048, 'temperature': 0.5});
      expect(result['context'], 2048);
      expect(result['temperature'], 0.5);
      expect(result.containsKey('maxTokens'), isFalse);
    });

    test('migrate old format with context already present', () {
      final result = _migrateOldModel({'context': 4096, 'temperature': 0.7});
      expect(result['context'], 4096);
      expect(result['temperature'], 0.7);
    });

    test('migrate old format without maxTokens', () {
      final result = _migrateOldModel({'temperature': 0.3});
      expect(result.containsKey('context'), isFalse);
      expect(result['temperature'], 0.3);
    });
  });
}
