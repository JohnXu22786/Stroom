import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/file_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    FileManifest.invalidateCache();
  });

  group('AudioPlayerPage source text integration', () {
    test('save source text via FileManifest and retrieve by hash', () async {
      const hash = 'test_hash_001';
      const format = 'wav';
      const sourceText = '这是一段测试源文本';

      // Create an audio record
      final record = AudioRecord(
        name: 'test',
        hash: hash,
        format: format,
        createdAt: DateTime.now(),
        size: 100,
        sourceText: '',
      );
      await FileManifest.addRecord(record);

      // Save companion .txt file
      final textBytes = Uint8List.fromList(utf8.encode(sourceText));
      await FileManifest.writeFile('$hash.txt', textBytes);

      // Update record sourceText
      final found = await FileManifest.getRecordByHash(hash);
      expect(found, isNotNull);
      if (found != null) {
        final updated = found.copyWith(sourceText: sourceText);
        await FileManifest.updateRecord(updated);
      }

      // Verify the .txt file was saved
      final savedTextData = await FileManifest.readFile('$hash.txt');
      expect(savedTextData, isNotNull);
      expect(utf8.decode(savedTextData!), equals(sourceText));

      // Verify record was updated
      final updatedRecord = await FileManifest.getRecordByHash(hash);
      expect(updatedRecord, isNotNull);
      expect(updatedRecord!.sourceText, equals(sourceText));
    });

    test('source text is empty when no companion .txt file exists', () async {
      const hash = 'test_no_text_002';
      final record = AudioRecord(
        name: 'test_no_text',
        hash: hash,
        format: 'wav',
        createdAt: DateTime.now(),
        size: 100,
      );

      // Record should have empty sourceText by default
      expect(record.sourceText, isEmpty);

      await FileManifest.addRecord(record);

      // No .txt file saved yet
      final textData = await FileManifest.readFile('$hash.txt');
      expect(textData, isNull);
    });

    test('update source text preserves other AudioRecord fields', () async {
      const hash = 'test_update_003';
      const originalName = 'original_name';
      const originalSize = 1024;
      const newText = '新的源文本';

      // Create initial record without source text
      final record = AudioRecord(
        name: originalName,
        hash: hash,
        format: 'wav',
        createdAt: DateTime.now(),
        size: originalSize,
        sourceText: '',
      );
      await FileManifest.addRecord(record);

      // Update source text
      final found = await FileManifest.getRecordByHash(hash);
      expect(found, isNotNull);
      if (found != null) {
        final updated = found.copyWith(sourceText: newText);
        await FileManifest.updateRecord(updated);
      }

      // Verify record updated correctly
      final updatedRecord = await FileManifest.getRecordByHash(hash);
      expect(updatedRecord, isNotNull);
      expect(updatedRecord!.sourceText, equals(newText));
      expect(updatedRecord.name, equals(originalName));
      expect(updatedRecord.size, equals(originalSize));
      expect(updatedRecord.hash, equals(hash));
    });

    test('companion .txt file content matches record sourceText', () async {
      const hash = 'test_match_004';
      const sourceText = '伴生文件内容匹配测试';

      // Save .txt file first
      final textBytes = Uint8List.fromList(utf8.encode(sourceText));
      await FileManifest.writeFile('$hash.txt', textBytes);

      // Create record with matching sourceText
      final record = AudioRecord(
        name: 'match_test',
        hash: hash,
        format: 'wav',
        createdAt: DateTime.now(),
        size: 50,
        sourceText: sourceText,
      );
      await FileManifest.addRecord(record);

      // Read back .txt file
      final readBytes = await FileManifest.readFile('$hash.txt');
      expect(readBytes, isNotNull);
      final readText = utf8.decode(readBytes!);
      expect(readText, equals(sourceText));

      // Record sourceText should match
      expect(record.sourceText, equals(readText));
    });

    test('getRecordByHash returns null for non-existent hash', () async {
      final result = await FileManifest.getRecordByHash('nonexistent_hash');
      expect(result, isNull);
    });

    test('multiple source text saves update companion file correctly', () async {
      const hash = 'test_multi_005';
      const text1 = '第一次保存的源文本';
      const text2 = '第二次修改后的源文本';

      // Create record
      final record = AudioRecord(
        name: 'multi',
        hash: hash,
        format: 'wav',
        createdAt: DateTime.now(),
        size: 50,
      );
      await FileManifest.addRecord(record);

      // First save
      var textBytes = Uint8List.fromList(utf8.encode(text1));
      await FileManifest.writeFile('$hash.txt', textBytes);
      var found = await FileManifest.getRecordByHash(hash);
      if (found != null) {
        await FileManifest.updateRecord(found.copyWith(sourceText: text1));
      }

      // Verify first save
      var readData = await FileManifest.readFile('$hash.txt');
      expect(utf8.decode(readData!), equals(text1));
      var rec = await FileManifest.getRecordByHash(hash);
      expect(rec!.sourceText, equals(text1));

      // Second save (update)
      textBytes = Uint8List.fromList(utf8.encode(text2));
      await FileManifest.writeFile('$hash.txt', textBytes);
      found = await FileManifest.getRecordByHash(hash);
      if (found != null) {
        await FileManifest.updateRecord(found.copyWith(sourceText: text2));
      }

      // Verify second save overwrote first
      readData = await FileManifest.readFile('$hash.txt');
      expect(utf8.decode(readData!), equals(text2));
      rec = await FileManifest.getRecordByHash(hash);
      expect(rec!.sourceText, equals(text2));
    });
  });
}
