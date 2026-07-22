import 'package:sqflite/sqflite.dart';
import '../models/card.dart';

/// Data access object for the `cards` table.
class CardDao {
  final Database _db;
  CardDao(this._db);

  Future<Card?> get(int id) async {
    final rows = await _db.query('cards', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Card.fromMap(rows.first);
  }

  Future<List<Card>> listByDeck(int deckId) async {
    final rows =
        await _db.query('cards', where: 'did = ?', whereArgs: [deckId]);
    return rows.map(Card.fromMap).toList();
  }

  Future<List<Card>> listByNote(int noteId) async {
    final rows =
        await _db.query('cards', where: 'nid = ?', whereArgs: [noteId]);
    return rows.map(Card.fromMap).toList();
  }

  Future<List<Card>> listDue(int deckId, int nowSec) async {
    final rows = await _db.query(
      'cards',
      where: 'did = ? AND queue >= 0 AND due <= ?',
      whereArgs: [deckId, nowSec],
    );
    return rows.map(Card.fromMap).toList();
  }

  Future<List<Card>> listDueInDeck(int deckId, int nowSec) async {
    final rows = await _db.query(
      'cards',
      where: 'did = ? AND ((queue = 0) OR (queue > 0 AND due <= ?))',
      whereArgs: [deckId, nowSec],
    );
    return rows.map(Card.fromMap).toList();
  }

  Future<List<Card>> listByQueue(int deckId, int queueValue) async {
    final rows = await _db.query('cards',
        where: 'did = ? AND queue = ?', whereArgs: [deckId, queueValue]);
    return rows.map(Card.fromMap).toList();
  }

  Future<int> countByQueue(int deckId, int queueValue) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM cards WHERE did = ? AND queue = ?',
      [deckId, queueValue],
    );
    return result.first['cnt'] as int;
  }

  Future<int> countDue(int deckId, int nowSec) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM cards WHERE did = ? AND ((queue = 0) OR (queue > 0 AND due <= ?))',
      [deckId, nowSec],
    );
    return result.first['cnt'] as int;
  }

  Future<int> insert(Card card) async {
    await _db.insert('cards', card.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return card.id;
  }

  Future<void> update(Card card) async {
    await _db
        .update('cards', card.toMap(), where: 'id = ?', whereArgs: [card.id]);
  }

  Future<void> delete(int id) async {
    await _db.delete('cards', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> totalCount(int deckId) async {
    final result = await _db
        .rawQuery('SELECT COUNT(*) AS cnt FROM cards WHERE did = ?', [deckId]);
    return result.first['cnt'] as int;
  }

  Future<int> totalCountAll() async {
    final result = await _db.rawQuery('SELECT COUNT(*) AS cnt FROM cards');
    return result.first['cnt'] as int;
  }

  Future<int> countByQueueAll(int queueValue) async {
    final result = await _db.rawQuery(
        'SELECT COUNT(*) AS cnt FROM cards WHERE queue = ?', [queueValue]);
    return result.first['cnt'] as int;
  }

  Future<List<Card>> all() async {
    final rows = await _db.query('cards');
    return rows.map(Card.fromMap).toList();
  }
}
