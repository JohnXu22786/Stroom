import 'package:sqflite/sqflite.dart';
import '../models/card.dart';

/// Data access object for the `cards` table.
class CardDao {
  final Database _db;
  CardDao(this._db);

  Future<AnkiCard?> get(int id) async {
    final rows = await _db.query('cards', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return AnkiCard.fromMap(rows.first);
  }

  Future<List<AnkiCard>> listByDeck(int did) async {
    final rows = await _db.query('cards', where: 'did = ?', whereArgs: [did]);
    return rows.map(AnkiCard.fromMap).toList();
  }

  Future<List<AnkiCard>> listByNote(int nid) async {
    final rows = await _db.query('cards', where: 'nid = ?', whereArgs: [nid]);
    return rows.map(AnkiCard.fromMap).toList();
  }

  Future<List<AnkiCard>> listDue(int did, int nowSec) async {
    final rows = await _db.query(
      'cards',
      where: 'did = ? AND queue >= 0 AND due <= ?',
      whereArgs: [did, nowSec],
    );
    return rows.map(AnkiCard.fromMap).toList();
  }

  Future<List<AnkiCard>> listDueInDeck(int did, int nowSec) async {
    final rows = await _db.query(
      'cards',
      where: 'did = ? AND ((queue = 0) OR (queue > 0 AND due <= ?))',
      whereArgs: [did, nowSec],
    );
    return rows.map(AnkiCard.fromMap).toList();
  }

  Future<List<AnkiCard>> listByQueue(int did, int queue) async {
    final rows = await _db.query('cards',
        where: 'did = ? AND queue = ?', whereArgs: [did, queue]);
    return rows.map(AnkiCard.fromMap).toList();
  }

  Future<int> countByQueue(int did, int queue) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM cards WHERE did = ? AND queue = ?',
      [did, queue],
    );
    return result.first['cnt'] as int;
  }

  Future<int> countDue(int did, int nowSec) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM cards WHERE did = ? AND ((queue = 0) OR (queue > 0 AND due <= ?))',
      [did, nowSec],
    );
    return result.first['cnt'] as int;
  }

  Future<int> insert(AnkiCard card) async {
    await _db.insert('cards', card.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return card.id;
  }

  Future<void> update(AnkiCard card) async {
    await _db
        .update('cards', card.toMap(), where: 'id = ?', whereArgs: [card.id]);
  }

  Future<void> delete(int id) async {
    await _db.delete('cards', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> totalCount(int did) async {
    final result = await _db
        .rawQuery('SELECT COUNT(*) AS cnt FROM cards WHERE did = ?', [did]);
    return result.first['cnt'] as int;
  }

  Future<List<AnkiCard>> all() async {
    final rows = await _db.query('cards');
    return rows.map(AnkiCard.fromMap).toList();
  }
}
