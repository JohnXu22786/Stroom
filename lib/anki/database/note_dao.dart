import 'package:sqflite/sqflite.dart';
import '../models/note.dart';

class NoteDao {
  final Database _db;
  NoteDao(this._db);

  Future<Note?> get(int id) async {
    final rows = await _db.query('notes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Note.fromMap(rows.first);
  }

  Future<List<Note>> listByModel(int notetypeId) async {
    final rows =
        await _db.query('notes', where: 'mid = ?', whereArgs: [notetypeId]);
    return rows.map(Note.fromMap).toList();
  }

  Future<int> insert(Note note) async {
    await _db.insert('notes', note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return note.id;
  }

  Future<void> update(Note note) async {
    await _db
        .update('notes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
  }

  Future<void> delete(int id) async {
    await _db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Note>> all() async {
    final rows = await _db.query('notes');
    return rows.map(Note.fromMap).toList();
  }
}
