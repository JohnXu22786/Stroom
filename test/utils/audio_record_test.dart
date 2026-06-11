import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/file_manifest.dart';

void main() {
  group('AudioRecord', () {
    final baseRecord = AudioRecord(
      id: 'test_id',
      name: '测试音频',
      hash: 'abc123',
      format: 'wav',
      createdAt: DateTime(2024, 1, 1),
      size: 1024,
      folder: '',
      sourceText: '原始源文本',
      duration: 60,
    );

    test('copyWith preserves all fields when no arguments given', () {
      final copy = baseRecord.copyWith();
      expect(copy.id, equals(baseRecord.id));
      expect(copy.name, equals(baseRecord.name));
      expect(copy.hash, equals(baseRecord.hash));
      expect(copy.format, equals(baseRecord.format));
      expect(copy.createdAt, equals(baseRecord.createdAt));
      expect(copy.size, equals(baseRecord.size));
      expect(copy.folder, equals(baseRecord.folder));
      expect(copy.sourceText, equals(baseRecord.sourceText));
      expect(copy.duration, equals(baseRecord.duration));
    });

    test('copyWith updates sourceText', () {
      const newText = '修改后的源文本';
      final copy = baseRecord.copyWith(sourceText: newText);
      expect(copy.sourceText, equals(newText));
      // Other fields should be unchanged
      expect(copy.id, equals(baseRecord.id));
      expect(copy.name, equals(baseRecord.name));
      expect(copy.hash, equals(baseRecord.hash));
      expect(copy.size, equals(baseRecord.size));
    });

    test('copyWith updates multiple fields simultaneously', () {
      const newText = '新文本';
      const newName = '新名称';
      const newSize = 2048;
      final copy = baseRecord.copyWith(
        sourceText: newText,
        name: newName,
        size: newSize,
      );
      expect(copy.sourceText, equals(newText));
      expect(copy.name, equals(newName));
      expect(copy.size, equals(newSize));
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

    test('empty sourceText when not provided', () {
      final record = AudioRecord(
        name: 'test',
        hash: 'hash123',
        format: 'wav',
        createdAt: DateTime(2024, 1, 1),
        size: 100,
      );
      expect(record.sourceText, isEmpty);
    });

    test('toMap includes sourceText field', () {
      const sourceText = 'map测试源文本';
      final record = baseRecord.copyWith(sourceText: sourceText);
      final map = record.toMap();
      expect(map['sourceText'], equals(sourceText));
    });

    test('fromMap handles null sourceText', () {
      final map = <String, dynamic>{
        'id': 'test_id',
        'name': 'test',
        'hash': 'hash123',
        'format': 'wav',
        'createdAt': DateTime(2024, 1, 1).toIso8601String(),
        'size': 100,
      };
      final record = AudioRecord.fromMap(map);
      expect(record.sourceText, isEmpty);
    });

    test('copyWithName preserves sourceText', () {
      final renamed = baseRecord.copyWithName('新名称');
      expect(renamed.sourceText, equals(baseRecord.sourceText));
      expect(renamed.name, equals('新名称'));
    });

    test('copyWithFolder preserves sourceText', () {
      final moved = baseRecord.copyWithFolder('new_folder');
      expect(moved.sourceText, equals(baseRecord.sourceText));
      expect(moved.folder, equals('new_folder'));
    });
  });
}
