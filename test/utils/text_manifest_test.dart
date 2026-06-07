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
}
