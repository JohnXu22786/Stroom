import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/file_manifest.dart';

void main() {
  group('AudioRecord', () {
    const testName = 'test_audio';
    const testHash = 'f0e1d2c3b4a5';
    const testFormat = 'wav';
    const testSize = 2048;
    const testFolder = 'recordings';
    const testSourceText = 'Hello, this is a test recording.';
    final testCreatedAt = DateTime(2025, 3, 10, 14, 45, 0);

    late AudioRecord defaultRecord;
    late AudioRecord fullRecord;

    setUp(() {
      defaultRecord = AudioRecord(
        name: testName,
        hash: testHash,
        format: testFormat,
        createdAt: testCreatedAt,
        size: testSize,
      );

      fullRecord = AudioRecord(
        id: 'rec_custom_id_002',
        name: testName,
        hash: testHash,
        format: testFormat,
        createdAt: testCreatedAt,
        size: testSize,
        folder: testFolder,
        sourceText: testSourceText,
      );
    });

    // ──────────────────────────────────────────────
    // Constructor – default id
    // ──────────────────────────────────────────────
    test('constructor assigns default id starting with rec_', () {
      expect(defaultRecord.id, startsWith('rec_'));
    });

    test('default id is a valid UUID v4 (36 hex chars after prefix)', () {
      final suffix = defaultRecord.id.substring(4);
      expect(suffix.length, equals(36));
      expect(suffix.split('-').length, equals(5));
      expect(
        suffix,
        matches(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'),
      );
    });

    // ──────────────────────────────────────────────
    // Constructor – provided id
    // ──────────────────────────────────────────────
    test('constructor uses provided id', () {
      expect(fullRecord.id, equals('rec_custom_id_002'));
    });

    test('constructor stores all provided fields correctly', () {
      expect(fullRecord.name, equals(testName));
      expect(fullRecord.hash, equals(testHash));
      expect(fullRecord.format, equals(testFormat));
      expect(fullRecord.createdAt, equals(testCreatedAt));
      expect(fullRecord.size, equals(testSize));
      expect(fullRecord.folder, equals(testFolder));
      expect(fullRecord.sourceText, equals(testSourceText));
    });

    // ──────────────────────────────────────────────
    // Defaults
    // ──────────────────────────────────────────────
    test('folder defaults to empty string', () {
      expect(defaultRecord.folder, equals(''));
    });

    test('sourceText defaults to empty string', () {
      expect(defaultRecord.sourceText, equals(''));
    });

    // ──────────────────────────────────────────────
    // storagePath & textStoragePath
    // ──────────────────────────────────────────────
    test('storagePath is hash.format', () {
      expect(defaultRecord.storagePath, equals('$testHash.$testFormat'));
    });

    test('storageFileName is identical to storagePath', () {
      expect(defaultRecord.storageFileName, equals(defaultRecord.storagePath));
    });

    test('textStoragePath is hash.txt', () {
      expect(defaultRecord.textStoragePath, equals('$testHash.txt'));
    });

    // ──────────────────────────────────────────────
    // toMap / fromMap round-trip
    // ──────────────────────────────────────────────
    test('toMap produces correct keys and values (including sourceText)', () {
      final map = fullRecord.toMap();

      expect(map['id'], equals('rec_custom_id_002'));
      expect(map['name'], equals(testName));
      expect(map['hash'], equals(testHash));
      expect(map['format'], equals(testFormat));
      expect(map['createdAt'], equals(testCreatedAt.toIso8601String()));
      expect(map['size'], equals(testSize));
      expect(map['folder'], equals(testFolder));
      expect(map['sourceText'], equals(testSourceText));
    });

    test('toMap/fromMap round-trip preserves all fields', () {
      final map = fullRecord.toMap();
      final restored = AudioRecord.fromMap(map);

      expect(restored.id, equals(fullRecord.id));
      expect(restored.name, equals(fullRecord.name));
      expect(restored.hash, equals(fullRecord.hash));
      expect(restored.format, equals(fullRecord.format));
      expect(restored.createdAt, equals(fullRecord.createdAt));
      expect(restored.size, equals(fullRecord.size));
      expect(restored.folder, equals(fullRecord.folder));
      expect(restored.sourceText, equals(fullRecord.sourceText));
    });

    test(
        'toMap/fromMap round-trip works for record with default folder and sourceText',
        () {
      final map = defaultRecord.toMap();
      final restored = AudioRecord.fromMap(map);

      expect(restored.id, equals(defaultRecord.id));
      expect(restored.folder, equals(''));
      expect(restored.sourceText, equals(''));
    });

    // ──────────────────────────────────────────────
    // fromMap – missing / null field handling
    // ──────────────────────────────────────────────
    test('fromMap handles empty map with defaults', () {
      final record = AudioRecord.fromMap({});

      expect(record.id, startsWith('rec_'));
      expect(record.name, equals(''));
      expect(record.hash, equals(''));
      expect(record.format, equals('wav'));
      final now = DateTime.now();
      expect(record.createdAt.difference(now).inSeconds.abs(),
          lessThanOrEqualTo(1));
      expect(record.size, equals(0));
      expect(record.folder, equals(''));
      expect(record.sourceText, equals(''));
    });

    test('fromMap treats null id as absent (generates new default)', () {
      final record = AudioRecord.fromMap({
        'id': null,
        'name': 'noid_audio',
        'hash': 'abc',
        'format': 'mp3',
        'createdAt': '2025-01-01T00:00:00.000',
        'size': 100,
      });

      expect(record.id, startsWith('rec_'));
      expect(record.name, equals('noid_audio'));
    });

    test('fromMap treats null createdAt as absent (uses current time)', () {
      final now = DateTime.now();
      final record = AudioRecord.fromMap({
        'id': 'rec_x',
        'name': 'test',
        'hash': 'abc',
        'format': 'mp3',
        'createdAt': null,
        'size': 100,
      });

      expect(record.createdAt.difference(now).inSeconds.abs(),
          lessThanOrEqualTo(1));
    });

    test('fromMap gracefully handles missing format', () {
      final record = AudioRecord.fromMap({
        'id': 'rec_y',
        'name': 'test',
        'hash': 'xyz',
        'createdAt': '2025-06-01T12:00:00.000',
        'size': 50,
      });

      expect(record.format, equals('wav'));
    });

    test('fromMap gracefully handles missing sourceText', () {
      final record = AudioRecord.fromMap({
        'id': 'rec_z',
        'name': 'test',
        'hash': 'abc',
        'format': 'mp3',
        'createdAt': '2025-01-01T00:00:00.000',
        'size': 100,
      });

      expect(record.sourceText, equals(''));
    });

    test('fromMap converts numeric size from various num types', () {
      final record = AudioRecord.fromMap({
        'id': 'rec_sz',
        'name': 'sizes',
        'hash': 'def',
        'format': 'ogg',
        'createdAt': '2025-01-01T00:00:00.000',
        'size': 4096.0,
      });

      expect(record.size, equals(4096));
    });

    // ──────────────────────────────────────────────
    // copyWith
    // ──────────────────────────────────────────────
    test('copyWith overrides name', () {
      final copied = fullRecord.copyWith(name: 'renamed_audio');
      expect(copied.name, equals('renamed_audio'));
      expect(copied.id, equals(fullRecord.id));
      expect(copied.hash, equals(fullRecord.hash));
      expect(copied.size, equals(fullRecord.size));
      expect(copied.sourceText, equals(fullRecord.sourceText));
    });

    test('copyWith overrides folder', () {
      final copied = fullRecord.copyWith(folder: 'new_folder_audio');
      expect(copied.folder, equals('new_folder_audio'));
      expect(copied.id, equals(fullRecord.id));
      expect(copied.name, equals(fullRecord.name));
    });

    test('copyWith overrides sourceText', () {
      final copied = fullRecord.copyWith(sourceText: 'Updated transcript.');
      expect(copied.sourceText, equals('Updated transcript.'));
      expect(copied.id, equals(fullRecord.id));
      expect(copied.name, equals(fullRecord.name));
    });

    test('copyWith overrides size', () {
      final copied = fullRecord.copyWith(size: 512);
      expect(copied.size, equals(512));
      expect(copied.folder, equals(fullRecord.folder));
    });

    test('copyWith keeps unchanged fields when no overrides', () {
      final copied = fullRecord.copyWith();
      expect(copied.id, equals(fullRecord.id));
      expect(copied.name, equals(fullRecord.name));
      expect(copied.hash, equals(fullRecord.hash));
      expect(copied.format, equals(fullRecord.format));
      expect(copied.createdAt, equals(fullRecord.createdAt));
      expect(copied.size, equals(fullRecord.size));
      expect(copied.folder, equals(fullRecord.folder));
      expect(copied.sourceText, equals(fullRecord.sourceText));
    });

    test(
        'copyWith overrides only specified fields, preserves hash, format, createdAt, id',
        () {
      final copied = fullRecord.copyWith(
        name: 'n',
        folder: 'f',
        sourceText: 't',
        size: 99,
      );
      expect(copied.hash, equals(testHash));
      expect(copied.format, equals(testFormat));
      expect(copied.createdAt, equals(testCreatedAt));
      expect(copied.id, equals('rec_custom_id_002'));
    });

    // ──────────────────────────────────────────────
    // Equality  (identity-based; no == override)
    // ──────────────────────────────────────────────
    test('identical instance is equal to itself', () {
      expect(defaultRecord, equals(defaultRecord));
      expect(fullRecord, equals(fullRecord));
    });

    test('two separate instances with same fields are not == equal', () {
      final a = AudioRecord(
        id: 'rec_eq_1',
        name: testName,
        hash: testHash,
        format: testFormat,
        createdAt: testCreatedAt,
        size: testSize,
        folder: testFolder,
        sourceText: testSourceText,
      );
      final b = AudioRecord(
        id: 'rec_eq_1',
        name: testName,
        hash: testHash,
        format: testFormat,
        createdAt: testCreatedAt,
        size: testSize,
        folder: testFolder,
        sourceText: testSourceText,
      );

      // Dart default equality is identity-based
      expect(a == b, isFalse);
    });

    test('different instances with different ids are not equal', () {
      expect(defaultRecord == fullRecord, isFalse);
    });

    // ──────────────────────────────────────────────
    // hashCode consistency
    // ──────────────────────────────────────────────
    test('hashCode is consistent across multiple calls for same instance', () {
      final h1 = defaultRecord.hashCode;
      final h2 = defaultRecord.hashCode;
      final h3 = defaultRecord.hashCode;

      expect(h1, equals(h2));
      expect(h2, equals(h3));
    });

    test('different instances (even with same fields) have different hashCodes',
        () {
      final a = AudioRecord(
        id: 'rec_hash_a',
        name: testName,
        hash: testHash,
        format: testFormat,
        createdAt: testCreatedAt,
        size: testSize,
      );
      final b = AudioRecord(
        id: 'rec_hash_a',
        name: testName,
        hash: testHash,
        format: testFormat,
        createdAt: testCreatedAt,
        size: testSize,
      );

      // Identity-based hashCode
      expect(a.hashCode == b.hashCode, isFalse);
    });

    // ──────────────────────────────────────────────
    // Edge cases
    // ──────────────────────────────────────────────
    test('handles empty name, folder, and sourceText', () {
      final rec = AudioRecord(
        name: '',
        hash: 'h',
        format: 'mp3',
        createdAt: testCreatedAt,
        size: 0,
        folder: '',
        sourceText: '',
      );

      expect(rec.name, equals(''));
      expect(rec.folder, equals(''));
      expect(rec.sourceText, equals(''));
      expect(rec.size, equals(0));
    });

    test('storagePath and textStoragePath with unusual hash', () {
      final rec = AudioRecord(
        name: 'a',
        hash: 'hash-with-dashes',
        format: 'mp3',
        createdAt: testCreatedAt,
        size: 1,
      );

      expect(rec.storagePath, equals('hash-with-dashes.mp3'));
      expect(rec.textStoragePath, equals('hash-with-dashes.txt'));
    });

    test('sourceText can contain special characters', () {
      final rec = AudioRecord(
        id: 'rec_special',
        name: 'special',
        hash: 'abc',
        format: 'wav',
        createdAt: testCreatedAt,
        size: 100,
        sourceText: 'Line 1\nLine 2\nSpecial: áéíóú ñ 中文',
      );

      expect(rec.sourceText, contains('áéíóú'));
      expect(rec.sourceText, contains('中文'));
    });
  });
}
