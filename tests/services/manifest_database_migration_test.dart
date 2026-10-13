import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';
import 'package:stroom/services/manifest_database.dart';

class _MigrationDatabase extends Fake implements Database {
  final legacyPaths = ['audio/root', 'audio/child'];
  final perTypeFolders = <String, Set<String>>{};
  var hasLegacyFolders = true;
  var failAudioCopy = true;
  var legacyFoldersDropped = false;

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    if (sql == 'DROP TABLE IF EXISTS folders') {
      legacyFoldersDropped = true;
    }
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final path = values['path']! as String;
    if (failAudioCopy &&
        table == ManifestTables.audioFolders &&
        path == 'audio/child') {
      failAudioCopy = false;
      throw StateError('injected audio folder copy failure');
    }
    final folders = perTypeFolders.putIfAbsent(table, () => <String>{});
    return folders.add(path) ? 1 : 0;
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    expect(table, ManifestTables.folders);
    expect(hasLegacyFolders, isTrue);
    return [
      for (final path in legacyPaths) {'path': path},
    ];
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    expect(sql, "SELECT name FROM sqlite_master WHERE type='table' AND name=?");
    expect(arguments, [ManifestTables.folders]);
    return hasLegacyFolders
        ? [
            {'name': ManifestTables.folders},
          ]
        : [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native v4 folder migration keeps legacy paths available after a copy failure and retries',
    () async {
      final database = _MigrationDatabase();

      await expectLater(
        ManifestDatabase.migrateLegacyFoldersV4ForTesting(database),
        throwsA(isA<StateError>()),
      );

      expect(
        database.legacyFoldersDropped,
        isFalse,
        reason: 'the only remaining copy must survive a failed migration',
      );
      expect(
        database.perTypeFolders[ManifestTables.audioFolders],
        equals({'audio/root'}),
        reason: 'the injected failure occurs after one audio path was copied',
      );

      await ManifestDatabase.migrateLegacyFoldersV4ForTesting(database);

      expect(
        database.legacyFoldersDropped,
        isTrue,
        reason: 'the legacy table may be dropped after every copy succeeds',
      );
      for (final table in ManifestTables.allPerTypeFolderTables) {
        expect(
          database.perTypeFolders[table],
          equals(database.legacyPaths.toSet()),
          reason: '$table must contain every legacy path after retry',
        );
      }
    },
  );

  test(
    'native v4 folder migration accepts a database without legacy folders',
    () async {
      final database = _MigrationDatabase()..hasLegacyFolders = false;

      await ManifestDatabase.migrateLegacyFoldersV4ForTesting(database);

      expect(database.legacyFoldersDropped, isFalse);
      expect(database.perTypeFolders, isEmpty);
    },
  );
}
