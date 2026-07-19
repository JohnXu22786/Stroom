import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'anki_schema.dart';
import 'card_dao.dart';
import 'note_dao.dart';
import 'revlog_dao.dart';
import 'grave_dao.dart';
import 'col_dao.dart';

/// Manages the SQLite connection to collection.anki2.
///
/// Opens the database at [basePath]/collection.anki2 (or the default
/// app documents directory if [basePath] is null). Creates tables
/// and seeds the initial col row on first run.
class AnkiDatabase {
  Database? _db;
  late final CardDao cards;
  late final NoteDao notes;
  late final RevlogDao revlog;
  late final GraveDao graves;
  late final ColDao col;

  final String? _overridePath;

  AnkiDatabase({String? basePath}) : _overridePath = basePath;

  /// Open (or create) the database.
  Future<void> open() async {
    if (_db != null) return;
    final dir =
        _overridePath ?? (await getApplicationDocumentsDirectory()).path;
    final dbPath = p.join(dir, 'collection.anki2');
    _db = await openDatabase(
      dbPath,
      version: AnkiSchema.schemaVersion,
      onCreate: (db, version) async {
        for (final sql in AnkiSchema.createStatements) {
          await db.execute(sql);
        }
        // Seed initial col row
        await ColDao.seed(db);
      },
    );
    cards = CardDao(_db!);
    notes = NoteDao(_db!);
    revlog = RevlogDao(_db!);
    graves = GraveDao(_db!);
    col = ColDao(_db!, cards, notes, revlog, graves);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Database get db {
    if (_db == null) throw StateError('AnkiDatabase not opened');
    return _db!;
  }
}
