import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/image_manifest.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('ImageManifest', () {
    setUp(() async {
      ImageManifest.invalidateCache();
      // Force loadRecords to initialize the cache (will fail SharedPrefs gracefully)
      await ImageManifest.loadRecords();
    });

    test('removeFolderFromCache removes folder and descendants from cache',
        () async {
      // Add folders
      await ImageManifest.addFolder('photos');
      await ImageManifest.addFolder('photos/vacation');
      await ImageManifest.addFolder('photos/vacation/beach');
      await ImageManifest.addFolder('documents');

      // Verify folders exist
      final before = await ImageManifest.getAllFolders();
      expect(before.contains('photos'), isTrue);
      expect(before.contains('photos/vacation'), isTrue);
      expect(before.contains('photos/vacation/beach'), isTrue);
      expect(before.contains('documents'), isTrue);

      // Remove 'photos' folder from cache
      await ImageManifest.removeFolderFromCache('photos');

      // Verify 'photos' and its descendants are gone, but 'documents' remains
      final after = await ImageManifest.getAllFolders();
      expect(after.contains('photos'), isFalse);
      expect(after.contains('photos/vacation'), isFalse);
      expect(after.contains('photos/vacation/beach'), isFalse);
      expect(after.contains('documents'), isTrue);
    });
  });

  group('ImageRecord', () {
    const testName = 'test_image';
    const testHash = 'a1b2c3d4e5f6';
    const testFormat = 'png';
    const testSize = 1024;
    const testFolder = 'photos';
    final testCreatedAt = DateTime(2025, 1, 15, 10, 30, 0);

    late ImageRecord defaultRecord;
    late ImageRecord fullRecord;

    setUp(() {
      defaultRecord = ImageRecord(
        name: testName,
        hash: testHash,
        format: testFormat,
        createdAt: testCreatedAt,
        size: testSize,
      );

      fullRecord = ImageRecord(
        id: 'img_custom_id_001',
        name: testName,
        hash: testHash,
        format: testFormat,
        createdAt: testCreatedAt,
        size: testSize,
        folder: testFolder,
      );
    });

    // ──────────────────────────────────────────────
    // Constructor – default id
    // ──────────────────────────────────────────────
    test('constructor assigns default id starting with img_', () {
      expect(defaultRecord.id, startsWith('img_'));
    });

    test('default id is a valid UUID v4 (hex, 36 chars after prefix)', () {
      final suffix = defaultRecord.id.substring(4);
      // UUID v4 format: 8-4-4-4-12 hex digits
      expect(suffix.length, equals(36));
      expect(suffix.split('-').length, equals(5));
      // Use dart:convert or just pattern check via regex
      expect(
          suffix,
          matches(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'));
    });

    // ──────────────────────────────────────────────
    // Constructor – provided id
    // ──────────────────────────────────────────────
    test('constructor uses provided id', () {
      expect(fullRecord.id, equals('img_custom_id_001'));
    });

    test('constructor stores all provided fields correctly', () {
      expect(fullRecord.name, equals(testName));
      expect(fullRecord.hash, equals(testHash));
      expect(fullRecord.format, equals(testFormat));
      expect(fullRecord.createdAt, equals(testCreatedAt));
      expect(fullRecord.size, equals(testSize));
      expect(fullRecord.folder, equals(testFolder));
    });

    // ──────────────────────────────────────────────
    // Default folder
    // ──────────────────────────────────────────────
    test('folder defaults to empty string', () {
      expect(defaultRecord.folder, equals(''));
    });

    // ──────────────────────────────────────────────
    // storagePath
    // ──────────────────────────────────────────────
    test('storagePath is hash.format', () {
      expect(defaultRecord.storagePath, equals('$testHash.$testFormat'));
    });

    test('storageFileName is identical to storagePath', () {
      expect(defaultRecord.storageFileName, equals(defaultRecord.storagePath));
    });

    // ──────────────────────────────────────────────
    // toMap / fromMap round-trip
    // ──────────────────────────────────────────────
    test('toMap produces correct keys and values', () {
      final map = fullRecord.toMap();

      expect(map['id'], equals('img_custom_id_001'));
      expect(map['name'], equals(testName));
      expect(map['hash'], equals(testHash));
      expect(map['format'], equals(testFormat));
      expect(map['createdAt'], equals(testCreatedAt.toIso8601String()));
      expect(map['size'], equals(testSize));
      expect(map['folder'], equals(testFolder));
    });

    test('toMap/fromMap round-trip preserves all fields', () {
      final map = fullRecord.toMap();
      final restored = ImageRecord.fromMap(map);

      expect(restored.id, equals(fullRecord.id));
      expect(restored.name, equals(fullRecord.name));
      expect(restored.hash, equals(fullRecord.hash));
      expect(restored.format, equals(fullRecord.format));
      expect(restored.createdAt, equals(fullRecord.createdAt));
      expect(restored.size, equals(fullRecord.size));
      expect(restored.folder, equals(fullRecord.folder));
    });

    test('toMap/fromMap round-trip works for record with default folder', () {
      final map = defaultRecord.toMap();
      final restored = ImageRecord.fromMap(map);

      expect(restored.id, equals(defaultRecord.id));
      expect(restored.folder, equals(''));
    });

    // ──────────────────────────────────────────────
    // fromMap – missing / null field handling
    // ──────────────────────────────────────────────
    test('fromMap handles empty map with defaults', () {
      final record = ImageRecord.fromMap({});

      expect(record.id, startsWith('img_'));
      expect(record.name, equals(''));
      expect(record.hash, equals(''));
      expect(record.format, equals('jpg'));
      // createdAt will be DateTime.now(); check it's within last second
      final now = DateTime.now();
      expect(record.createdAt.difference(now).inSeconds.abs(),
          lessThanOrEqualTo(1));
      expect(record.size, equals(0));
      expect(record.folder, equals(''));
    });

    test('fromMap treats null id as absent (generates default)', () {
      final record = ImageRecord.fromMap({
        'id': null,
        'name': 'noid',
        'hash': 'abc',
        'format': 'jpg',
        'createdAt': '2025-01-01T00:00:00.000',
        'size': 100,
      });

      expect(record.id, startsWith('img_'));
      expect(record.name, equals('noid'));
    });

    test('fromMap treats null createdAt as absent (uses current time)', () {
      final now = DateTime.now();
      final record = ImageRecord.fromMap({
        'id': 'img_x',
        'name': 'test',
        'hash': 'abc',
        'format': 'jpg',
        'createdAt': null,
        'size': 100,
      });

      expect(record.createdAt.difference(now).inSeconds.abs(),
          lessThanOrEqualTo(1));
    });

    test('fromMap gracefully handles missing format', () {
      final record = ImageRecord.fromMap({
        'id': 'img_y',
        'name': 'test',
        'hash': 'xyz',
        'createdAt': '2025-06-01T12:00:00.000',
        'size': 50,
      });

      expect(record.format, equals('jpg'));
    });

    test('fromMap converts numeric size from various num types', () {
      final record = ImageRecord.fromMap({
        'id': 'img_z',
        'name': 'sizes',
        'hash': 'def',
        'format': 'png',
        'createdAt': '2025-01-01T00:00:00.000',
        'size': 2048.0, // double
      });

      expect(record.size, equals(2048));
    });

    // ──────────────────────────────────────────────
    // copyWith
    // ──────────────────────────────────────────────
    test('copyWith overrides name', () {
      final copied = fullRecord.copyWith(name: 'renamed');
      expect(copied.name, equals('renamed'));
      expect(copied.id, equals(fullRecord.id));
      expect(copied.hash, equals(fullRecord.hash));
      expect(copied.size, equals(fullRecord.size));
    });

    test('copyWith overrides folder', () {
      final copied = fullRecord.copyWith(folder: 'new_folder');
      expect(copied.folder, equals('new_folder'));
      expect(copied.id, equals(fullRecord.id));
      expect(copied.name, equals(fullRecord.name));
    });

    test('copyWith overrides size', () {
      final copied = fullRecord.copyWith(size: 999);
      expect(copied.size, equals(999));
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
    });

    test(
        'copyWith overrides only specified fields, preserves hash, format, createdAt, id',
        () {
      final copied = fullRecord.copyWith(name: 'n', folder: 'f', size: 42);
      expect(copied.hash, equals(testHash));
      expect(copied.format, equals(testFormat));
      expect(copied.createdAt, equals(testCreatedAt));
      expect(copied.id, equals('img_custom_id_001'));
    });

    // ──────────────────────────────────────────────
    // Equality  (identity-based; no == override)
    // ──────────────────────────────────────────────
    test('identical instance is equal to itself', () {
      expect(defaultRecord, equals(defaultRecord));
      expect(fullRecord, equals(fullRecord));
    });

    test('two separate instances with same fields are not == equal', () {
      final a = ImageRecord(
        id: 'img_eq_1',
        name: testName,
        hash: testHash,
        format: testFormat,
        createdAt: testCreatedAt,
        size: testSize,
        folder: testFolder,
      );
      final b = ImageRecord(
        id: 'img_eq_1',
        name: testName,
        hash: testHash,
        format: testFormat,
        createdAt: testCreatedAt,
        size: testSize,
        folder: testFolder,
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
      final a = ImageRecord(
        id: 'img_hash_a',
        name: testName,
        hash: testHash,
        format: testFormat,
        createdAt: testCreatedAt,
        size: testSize,
      );
      final b = ImageRecord(
        id: 'img_hash_a',
        name: testName,
        hash: testHash,
        format: testFormat,
        createdAt: testCreatedAt,
        size: testSize,
      );

      // Identity-based hashCode — different instances, likely different
      expect(a.hashCode == b.hashCode, isFalse);
    });

    // ──────────────────────────────────────────────
    // Edge cases
    // ──────────────────────────────────────────────
    test('handles empty name and folder', () {
      final rec = ImageRecord(
        name: '',
        hash: 'h',
        format: 'jpg',
        createdAt: testCreatedAt,
        size: 0,
        folder: '',
      );

      expect(rec.name, equals(''));
      expect(rec.folder, equals(''));
      expect(rec.size, equals(0));
    });

    test('storagePath with unusual format values', () {
      final rec = ImageRecord(
        name: 'a',
        hash: 'my-hash-value',
        format: 'jpeg',
        createdAt: testCreatedAt,
        size: 1,
      );

      expect(rec.storagePath, equals('my-hash-value.jpeg'));
    });
  });
}
