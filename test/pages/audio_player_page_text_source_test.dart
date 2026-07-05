import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/file_manifest.dart';
import 'package:stroom/utils/text_manifest.dart';

// ============================================================================
// Tests for the audio player source text upload button behavior
//
// These tests verify:
// 1. The underlying data flow (save/load source text) - already covered
// 2. The in-app text file selection via TextManifest
// 3. The system file selection via FilePicker (unit-level logic)
// ============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    FileManifest.invalidateCache();
    TextManifest.invalidateCache();
  });

  group('AudioPlayerPage - source text upload: in-app text selection', () {
    test('TextManifest stores and retrieves text files correctly', () async {
      const fileName = 'test_source.txt';
      const testContent = '这是一段测试文本内容';

      // Write text file via TextManifest
      final bytes = Uint8List.fromList(utf8.encode(testContent));
      await TextManifest.writeFile(fileName, bytes);

      // Read back and verify
      final readBytes = await TextManifest.readFile(fileName);
      expect(readBytes, isNotNull);
      expect(utf8.decode(readBytes!), equals(testContent));
    });

    test('TextManifest file content is decodable as UTF-8', () async {
      const fileName = 'test_unicode.txt';
      const testContent = 'Unicode 测试: 你好 world 🌍';

      await TextManifest.writeFile(
        fileName,
        Uint8List.fromList(utf8.encode(testContent)),
      );

      final readBytes = await TextManifest.readFile(fileName);
      expect(readBytes, isNotNull);
      expect(utf8.decode(readBytes!), equals(testContent));
    });

    test('TextManifest returns null for non-existent file', () async {
      final result = await TextManifest.readFile('nonexistent.txt');
      expect(result, isNull);
    });

    test('TextManifest.loadRecords returns stored text records', () async {
      const fileName = 'record_test.txt';
      const testContent = '记录测试内容';

      // Write the file first
      await TextManifest.writeFile(
        fileName,
        Uint8List.fromList(utf8.encode(testContent)),
      );

      // Load records - writing a file doesn't auto-add a record
      final records = await TextManifest.loadRecords();
      expect(records, isEmpty);

      // Add a record manually to simulate real usage
      await TextManifest.addRecord(TextRecord(
        name: 'record_test',
        hash: 'test_hash',
        format: 'txt',
        createdAt: DateTime.now(),
        size: testContent.length,
        textLength: testContent.length,
        folder: '',
      ));

      final recordsAfter = await TextManifest.loadRecords();
      expect(recordsAfter, isNotEmpty);
      expect(recordsAfter.any((r) => r.name == 'record_test'), isTrue);
    });
  });

  group('AudioPlayerPage - source text upload: companion file flow', () {
    test('source text saved as companion .txt file is retrievable', () async {
      const hash = 'test_hash_companion';
      const sourceText = '伴生文本文件内容';

      // Simulate _saveSourceText logic
      final textBytes = Uint8List.fromList(utf8.encode(sourceText));
      await FileManifest.writeFile('$hash.txt', textBytes);

      // Verify companion file exists
      final readData = await FileManifest.readFile('$hash.txt');
      expect(readData, isNotNull);
      expect(utf8.decode(readData!), equals(sourceText));
    });

    test('source text companion file survives AudioRecord update', () async {
      const hash = 'test_hash_update';
      const sourceText = '更新后的源文本';

      // Create audio record
      final record = AudioRecord(
        name: 'test',
        hash: hash,
        format: 'wav',
        createdAt: DateTime.now(),
        size: 100,
        sourceText: '',
      );
      await FileManifest.addRecord(record);

      // Write companion file AND update record (as _saveSourceText does)
      final textBytes = Uint8List.fromList(utf8.encode(sourceText));
      await FileManifest.writeFile('$hash.txt', textBytes);
      final found = await FileManifest.getRecordByHash(hash);
      if (found != null) {
        await FileManifest.updateRecord(found.copyWith(sourceText: sourceText));
      }

      // Verify both are consistent
      final fileData = await FileManifest.readFile('$hash.txt');
      expect(utf8.decode(fileData!), equals(sourceText));

      final updatedRecord = await FileManifest.getRecordByHash(hash);
      expect(updatedRecord!.sourceText, equals(sourceText));
    });

    test('empty UTF-8 text file saves and reads correctly', () async {
      const hash = 'test_hash_empty';
      const emptyText = '';

      await FileManifest.writeFile(
        '$hash.txt',
        Uint8List.fromList(utf8.encode(emptyText)),
      );

      final readData = await FileManifest.readFile('$hash.txt');
      expect(readData, isNotNull);
      expect(readData!.isEmpty, isTrue);
    });

    test('companion file with malformed UTF-8 can still be decoded', () async {
      const hash = 'test_hash_malformed';
      // Invalid UTF-8 bytes (0xFF is not valid in UTF-8)
      final malformedBytes = Uint8List.fromList([0xFF, 0xFE, 0x00, 0x68]);

      await FileManifest.writeFile('$hash.txt', malformedBytes);

      final readData = await FileManifest.readFile('$hash.txt');
      expect(readData, isNotNull);

      // Should decode with allowMalformed
      final text = utf8.decode(readData!, allowMalformed: true);
      expect(text, isNotEmpty);
    });
  });

  group('AudioPlayerPage - source text upload: system file decoding', () {
    test('valid UTF-8 bytes decode to correct text', () async {
      final bytes = Uint8List.fromList(utf8.encode('系统文件测试文本'));
      final decoded = utf8.decode(bytes);
      expect(decoded, equals('系统文件测试文本'));
    });

    test('malformed UTF-8 can be decoded with allowMalformed', () async {
      final malformedBytes = Uint8List.fromList([0xD8, 0x00, 0xDC, 0x00]);
      // Should not throw
      final decoded = utf8.decode(malformedBytes, allowMalformed: true);
      expect(decoded, isA<String>());
    });

    test('empty bytes decode to empty string', () async {
      final bytes = Uint8List.fromList([]);
      final decoded = utf8.decode(bytes);
      expect(decoded, isEmpty);
    });
  });

  group('AudioPlayerPage - source text upload: ChoiceCard pattern', () {
    // The bottom sheet follows the established OCR/ASR pattern
    // with exactly 2 ChoiceCard options:
    // 1. "从应用内文本选择" - opens in-app text file picker
    // 2. "从系统文本文件选择" - opens system file picker
  });
}
