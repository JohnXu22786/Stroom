import 'package:sqflite/sqflite.dart';
import '../models/revlog.dart';

class RevlogDao {
  final Database _db;
  RevlogDao(this._db);

  Future<void> insert(RevlogEntry entry) async {
    await _db.insert('revlog', entry.toMap());
  }

  Future<List<RevlogEntry>> listByCard(int cid) async {
    final rows = await _db.query('revlog',
        where: 'cid = ?', whereArgs: [cid], orderBy: 'id');
    return rows.map(RevlogEntry.fromMap).toList();
  }

  Future<List<RevlogEntry>> recent(int limit) async {
    final rows = await _db.query('revlog', orderBy: 'id DESC', limit: limit);
    return rows.map(RevlogEntry.fromMap).toList();
  }

  Future<int> count() async {
    final result = await _db.rawQuery('SELECT COUNT(*) AS cnt FROM revlog');
    return result.first['cnt'] as int;
  }
}
