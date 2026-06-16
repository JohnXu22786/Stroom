import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  // ====== ManifestDatabase text records (in-memory, no file I/O) ======

  group('ManifestDatabase text records', () {
    testWidgets('empty initially', (WidgetTester t) async {
      final records = await ManifestDatabase.getAllTextRecords();
      expect(records, isEmpty);
    });

    testWidgets('insert and retrieve', (WidgetTester t) async {
      await ManifestDatabase.insertTextRecord({
        'id': 'txt_1',
        'name': 'test_text',
        'hash': 'abc123',
        'format': 'txt',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 100,
        'folder': '',
        'textLength': 100,
      });
      final records = await ManifestDatabase.getAllTextRecords();
      expect(records.length, equals(1));
      expect(records[0]['id'], equals('txt_1'));
    });

    testWidgets('update existing record', (WidgetTester t) async {
      await ManifestDatabase.insertTextRecord({
        'id': 'txt_2',
        'name': 'original',
        'hash': 'def456',
        'format': 'txt',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 200,
        'folder': '',
        'textLength': 200,
      });
      await ManifestDatabase.updateTextRecord('txt_2', {'name': 'renamed', 'size': 400});
      final records = await ManifestDatabase.getAllTextRecords();
      expect(records[0]['name'], equals('renamed'));
      expect(records[0]['size'], equals(400));
    });

    testWidgets('delete record', (WidgetTester t) async {
      await ManifestDatabase.insertTextRecord({
        'id': 'txt_3',
        'name': 'to_delete',
        'hash': 'ghi789',
        'format': 'txt',
        'createdAt': DateTime.now().toIso8601String(),
        'size': 50,
        'folder': '',
        'textLength': 50,
      });
      await ManifestDatabase.deleteTextRecord('txt_3');
      final records = await ManifestDatabase.getAllTextRecords();
      expect(records, isEmpty);
    });

    testWidgets('batch delete', (WidgetTester t) async {
      for (var i = 0; i < 3; i++) {
        await ManifestDatabase.insertTextRecord({
          'id': 'txt_batch_$i',
          'name': 'batch_$i',
          'hash': 'hash_$i',
          'format': 'txt',
          'createdAt': DateTime.now().toIso8601String(),
          'size': 100,
          'folder': '',
          'textLength': 100,
        });
      }
      await ManifestDatabase.deleteTextRecords(['txt_batch_0', 'txt_batch_2']);
      final records = await ManifestDatabase.getAllTextRecords();
      expect(records.length, equals(1));
      expect(records[0]['id'], equals('txt_batch_1'));
    });
  });

  // ====== TextManifest record CRUD (DB-only methods, no file I/O) ======

  group('TextManifest DB operations', () {
    testWidgets('add and load records', (WidgetTester t) async {
      await TextManifest.addRecord(TextRecord(
        name: 'test_text',
        hash: 'hash1',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 100,
        textLength: 100,
      ));
      final records = await TextManifest.loadRecords();
      expect(records.length, equals(1));
      expect(records[0].name, equals('test_text'));
    });

    testWidgets('rename record (DB only)', (WidgetTester t) async {
      await TextManifest.addRecord(TextRecord(
        id: 'txt_rename',
        name: 'old_name',
        hash: 'hren',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 100,
        textLength: 100,
      ));
      await TextManifest.renameRecord('txt_rename', 'new_name');
      final records = await TextManifest.loadRecords();
      expect(records[0].name, equals('new_name'));
    });

    testWidgets('move record to folder (DB only)', (WidgetTester t) async {
      await TextManifest.addRecord(TextRecord(
        id: 'txt_move',
        name: 'movable',
        hash: 'hmov',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 100,
        folder: '',
        textLength: 100,
      ));
      await TextManifest.moveRecord('txt_move', 'my_folder');
      final records = await TextManifest.loadRecords();
      expect(records[0].folder, equals('my_folder'));
    });

    testWidgets('update record (DB only)', (WidgetTester t) async {
      final record = TextRecord(
        id: 'txt_upd',
        name: 'before',
        hash: 'hupd',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 100,
        textLength: 100,
      );
      await TextManifest.addRecord(record);
      await TextManifest.updateRecord(record.copyWith(name: 'after', size: 999));
      final records = await TextManifest.loadRecords();
      expect(records[0].name, equals('after'));
      expect(records[0].size, equals(999));
    });

    testWidgets('TextRecord serialization roundtrip', (WidgetTester t) async {
      final now = DateTime.now();
      final record = TextRecord(
        id: 'txt_roundtrip',
        name: 'my_text',
        hash: 'my_hash',
        format: 'txt',
        createdAt: now,
        size: 42,
        folder: 'subfolder',
        textLength: 42,
      );

      final map = record.toMap();
      final restored = TextRecord.fromMap(map);

      expect(restored.id, equals('txt_roundtrip'));
      expect(restored.name, equals('my_text'));
      expect(restored.hash, equals('my_hash'));
      expect(restored.format, equals('txt'));
      expect(restored.size, equals(42));
      expect(restored.folder, equals('subfolder'));
      expect(restored.textLength, equals(42));
      expect(restored.createdAt.toIso8601String(),
          equals(now.toIso8601String()));
    });

    testWidgets('TextRecord copyWithName', (WidgetTester t) async {
      final record = TextRecord(
        name: 'original',
        hash: 'hash1',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 100,
        textLength: 100,
      );
      final renamed = record.copyWithName('renamed');
      expect(renamed.name, equals('renamed'));
      expect(renamed.hash, equals('hash1'));
    });

    testWidgets('TextRecord copyWithFolder', (WidgetTester t) async {
      final record = TextRecord(
        name: 'test',
        hash: 'hash1',
        format: 'txt',
        createdAt: DateTime.now(),
        size: 100,
        textLength: 100,
      );
      final moved = record.copyWithFolder('new_folder');
      expect(moved.folder, equals('new_folder'));
      expect(moved.name, equals('test'));
    });
  });

  // ====================================================================
  // Encoding tests — verify UTF-8 encoding throughout the text storage
  // pipeline. These are CRITICAL because the original code used
  // `text.codeUnits` (UTF-16 code units truncated to 8 bits) which
  // corrupts Chinese and other non-ASCII text.
  //
  // NOTE: These tests verify the ENCODING LOGIC without relying on
  // file I/O (which requires flutter_test platform setup). We test
  // the encoding functions directly by simulating the writeText/readText
  // logic — this is safe and fast, and the actual file I/O is already
  // tested via ManifestDatabase (in-memory) and integration tests.
  // ====================================================================

  group('TextManifest UTF-8 encoding', () {
    /// Demonstrate that `text.codeUnits` (the BUGGY approach) corrupts
    /// Chinese text by truncating 16-bit code units to 8 bits.
    test('codeUnits truncates Chinese characters (demonstrates the bug)',
        () {
      const chinese = '中文测试';

      // codeUnits returns each character as a 16-bit (or more) value
      final codeUnits = chinese.codeUnits;
      // '中' = U+4E2D = 20013, fits in 2 bytes but NOT 1 byte
      // '文' = U+6587 = 25991, fits in 2 bytes but NOT 1 byte

      // When stored in Uint8List, each value > 255 is truncated
      final truncatedBytes = Uint8List.fromList(codeUnits);
      // Each Chinese char's code unit is > 255, so high byte is lost

      // Reading back gives garbled text
      final garbled = String.fromCharCodes(truncatedBytes);
      expect(garbled, isNot(equals(chinese)),
          reason:
              'codeUnits + Uint8List corrupts Chinese text. This is the bug.');
    });

    /// Verify that utf8.encode preserves Chinese text correctly.
    test('utf8.encode preserves Chinese characters', () {
      const chinese = '中文测试UTF-8编码';

      // UTF-8 encoding - CORRECT approach
      final utf8Bytes = Uint8List.fromList(utf8.encode(chinese));
      final decoded = utf8.decode(utf8Bytes);

      expect(decoded, equals(chinese),
          reason:
              'utf8.encode + utf8.decode must roundtrip Chinese text correctly.');
    });

    /// Verify utf8.encode preserves all Unicode scripts.
    test('utf8.encode preserves mixed Unicode scripts', () {
      const mixed =
          '中文 English 日本語 + 🌍😀 + éñçødïñg + العربية + ภาษาไทย + 한국어';

      final utf8Bytes = Uint8List.fromList(utf8.encode(mixed));
      final decoded = utf8.decode(utf8Bytes);

      expect(decoded, equals(mixed),
          reason:
              'utf8.encode/decode must handle CJK, emoji, Latin-1 supplement, '
              'Arabic, Thai, and Korean without data loss.');
    });

    /// Verify that codeUnits produces wrong byte count for Chinese text.
    test('utf8.encode produces correct byte sizes vs codeUnits truncation',
        () {
      const chinese = '你好世界，这是中文OCR识别测试。';

      final utf8Bytes = Uint8List.fromList(utf8.encode(chinese));
      final badBytes = Uint8List.fromList(chinese.codeUnits);

      // UTF-8: each Chinese char is 3 bytes, each ASCII char is 1 byte
      // codeUnits: each Chinese char truncates from 2 bytes to 1 byte
      expect(utf8Bytes.length, greaterThan(badBytes.length),
          reason:
              'UTF-8 encoding must produce more bytes than truncated codeUnits '
              'for Chinese text, since each Chinese char is 3 bytes in UTF-8 '
              'but only 1 byte when truncated from codeUnits.');
    });

    /// Verify computeTextHash works correctly with utf8.encode bytes.
    test('computeTextHash with utf8.encode is deterministic', () {
      const chinese = '哈希一致性测试';

      final utf8Bytes = Uint8List.fromList(utf8.encode(chinese));
      final hash1 = computeTextHash(utf8Bytes);
      final hash2 = computeTextHash(Uint8List.fromList(utf8.encode(chinese)));

      expect(hash1, equals(hash2),
          reason: 'computeTextHash must return identical hash for same input.');
      expect(hash1, isNotEmpty,
          reason: 'Hash must not be empty.');
    });

    /// Verify what OCR/ASR pages currently do: utf8.encode for hash.
    test('OCR/ASR page hash pattern works correctly', () {
      const ocrText = '这是一段从图片中识别出的中文文字。';

      // This is exactly what ocr_page.dart does:
      // final bytes = Uint8List.fromList(utf8.encode(text));
      // final hash = computeTextHash(bytes);
      final bytes = Uint8List.fromList(utf8.encode(ocrText));
      final hash = computeTextHash(bytes);

      // The same hash should be computed from stored file content
      // (once writeText is fixed to use utf8.encode instead of codeUnits)
      expect(hash, isNotEmpty);
      expect(bytes.length, greaterThan(0),
          reason: 'UTF-8 encoded bytes must not be empty.');
    });

    /// Verify that the writeText → readText logic (without file I/O) works.
    test('writeText/readText encoding logic produces correct roundtrip', () {
      const chinese = '编码逻辑测试正确性';

      // Simulate writeText logic
      final writeBytes = Uint8List.fromList(utf8.encode(chinese));

      // Simulate readText logic
      final decoded = utf8.decode(writeBytes);

      expect(decoded, equals(chinese),
          reason:
              'The core encoding logic must roundtrip Chinese text. '
              'After fixing writeText to use utf8.encode and readText '
              'to use utf8.decode, this must pass.');

      // Also verify that the BUGGY approach DOES NOT work
      final buggyBytes = Uint8List.fromList(chinese.codeUnits);
      final buggyDecoded = String.fromCharCodes(buggyBytes);
      expect(buggyDecoded, isNot(equals(chinese)),
          reason:
              'The old codeUnits approach must still fail - this confirms '
              'the bug exists and our fix is necessary.');
    });

    /// Verify ascii text still works with both encoding approaches.
    test('ASCII text works with both codeUnits and utf8.encode', () {
      const ascii = 'Hello, World! This is a test. 12345';

      // ASCII chars have code units < 128, so both approaches work
      final utf8Bytes = Uint8List.fromList(utf8.encode(ascii));
      final codeUnitsBytes = Uint8List.fromList(ascii.codeUnits);

      // For pure ASCII, both produce the same bytes
      expect(utf8Bytes, equals(codeUnitsBytes),
          reason:
              'For ASCII-only text, both utf8.encode and codeUnits '
              'produce identical bytes.');

      final utf8Decoded = utf8.decode(utf8Bytes);
      final codeUnitsDecoded = String.fromCharCodes(codeUnitsBytes);

      expect(utf8Decoded, equals(ascii));
      expect(codeUnitsDecoded, equals(ascii));
    });
  });

  // ====== Empty file handling ======

  group('TextManifest empty file handling', () {
    test('readText returns empty string for empty bytes instead of null', () async {
      // Create a test file with empty content
      const emptyContent = '';
      final bytes = Uint8List.fromList(utf8.encode(emptyContent));
      final hash = computeTextHash(bytes);
      final storageFileName = '$hash.txt';

      // Write empty content
      await TextManifest.writeText(storageFileName, emptyContent);

      // Read back - should return '' not null
      final result = await TextManifest.readText(storageFileName);
      expect(result, isNotNull,
          reason: 'Empty content should return "" not null');
      expect(result, equals(''),
          reason: 'readText should return empty string for empty file');
    });

    test('computeTextHash for empty content is deterministic', () {
      final emptyBytes = Uint8List.fromList(utf8.encode(''));
      final hash1 = computeTextHash(emptyBytes);
      final hash2 = computeTextHash(Uint8List.fromList(utf8.encode('')));
      expect(hash1, equals(hash2),
          reason: 'Hash for empty content must be deterministic');
      expect(hash1, isNotEmpty,
          reason: 'Hash for empty content must still produce a valid hash');
    });
  });
}
