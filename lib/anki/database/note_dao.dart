import 'package:sqflite/sqflite.dart';
import '../models/note.dart';

class NoteDao {
  final Database _db;
  NoteDao(this._db);

  Future<AnkiNote?> get(int id) async {
    final rows = await _db.query('notes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return AnkiNote.fromMap(rows.first);
  }

  Future<List<AnkiNote>> listByModel(int mid) async {
    final rows = await _db.query('notes', where: 'mid = ?', whereArgs: [mid]);
    return rows.map(AnkiNote.fromMap).toList();
  }

  Future<int> insert(AnkiNote note) async {
    await _db.insert('notes', note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return note.id;
  }

  Future<void> update(AnkiNote note) async {
    await _db
        .update('notes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
  }

  Future<void> delete(int id) async {
    await _db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<AnkiNote>> all() async {
    final rows = await _db.query('notes');
    return rows.map(AnkiNote.fromMap).toList();
  }
}
