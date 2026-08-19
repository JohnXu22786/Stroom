import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/file_manifest.dart';

void main() {
  group('AudioRecord', () {
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
