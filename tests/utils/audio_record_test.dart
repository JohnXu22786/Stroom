import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/file_manifest.dart';

void main() {
  group('AudioRecord', () {
    test('fromMap sanitizes Windows-invalid format characters for storage', () {
      final restored = AudioRecord.fromMap({
        'id': 'audio_invalid_format',
        'name': 'imported',
        'hash': 'hash123',
        'format': 'wa?v',
        'createdAt': '2024-01-01T00:00:00.000',
        'size': 100,
      });

      expect(restored.format, equals('wa?v'));
      expect(restored.storagePath, equals('hash123.wa%003fv'));
      expect(
        AudioRecord(
          name: 'percent format',
          hash: 'hash123',
          format: 'wa%003fv',
          createdAt: DateTime(2024, 1, 1),
          size: 100,
        ).storagePath,
        isNot(restored.storagePath),
      );
      final longFormatRecord = AudioRecord(
        name: 'long format',
        hash: 'a' * 64,
        format: '?' * 39,
        createdAt: DateTime(2024, 1, 1),
        size: 100,
      );
      expect(longFormatRecord.storagePath.length, lessThanOrEqualTo(255));
      expect(longFormatRecord.storagePath, isNot(contains('?')));
      expect(
        AudioRecord(
          name: 'empty format',
          hash: 'hash123',
          format: '',
          createdAt: DateTime(2024, 1, 1),
          size: 100,
        ).storagePath,
        equals('hash123.%'),
      );
    });

    test('toMap and fromMap round-trip preserves sourceText', () {
      const sourceText = '这是一段源文本';
      final record = AudioRecord(
        name: 'test',
        hash: 'hash123',
        format: 'wav',
        createdAt: DateTime(2024, 1, 1),
        size: 100,
        sourceText: sourceText,
      );

      final map = record.toMap();
      final restored = AudioRecord.fromMap(map);

      expect(restored.sourceText, equals(sourceText));
      expect(restored.id, equals(record.id));
      expect(restored.name, equals(record.name));
    });
  });
}
