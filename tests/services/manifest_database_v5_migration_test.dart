import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:stroom/services/manifest_database.dart';

class _V5MigrationDatabase extends Fake implements Database {
  _V5MigrationDatabase(this.failure);

  final String failure;
  var reachedTextTable = false;

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    if (sql.startsWith('ALTER TABLE audio_records') &&
        failure == 'column addition') {
      throw StateError('injected column addition failure');
    }
    if (sql.startsWith('UPDATE audio_records') && failure == 'backfill') {
      throw StateError('injected backfill failure');
    }
    if (sql.startsWith('UPDATE text_records')) reachedTextTable = true;
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    if (sql == 'PRAGMA table_info(audio_records)' &&
        failure == 'schema inspection') {
      throw StateError('injected schema inspection failure');
    }
    if (sql == 'PRAGMA table_info(audio_records)' &&
        failure == 'column addition') {
      return const [];
    }
    return const [
      {'name': 'modified_at'},
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final failure in [
    'schema inspection',
    'column addition',
    'backfill',
  ]) {
    test('native v5 migration propagates $failure failures', () async {
      final database = _V5MigrationDatabase(failure);

      await expectLater(
        ManifestDatabase.migrateModifiedAtV5ForTesting(database),
        throwsA(isA<StateError>()),
      );
      expect(
        database.reachedTextTable,
        isFalse,
        reason: 'a failed migration must stop before marking later tables done',
      );
    });
  }
}
