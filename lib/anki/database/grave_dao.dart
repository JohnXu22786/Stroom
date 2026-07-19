import 'package:sqflite/sqflite.dart';
import '../models/grave.dart';

class GraveDao {
  final Database _db;
  GraveDao(this._db);

  Future<void> insert(AnkiGrave grave) async {
    await _db.insert('graves', grave.toMap());
  }

  Future<List<AnkiGrave>> all() async {
    final rows = await _db.query('graves');
    return rows.map(AnkiGrave.fromMap).toList();
  }

  Future<void> clear() async {
    await _db.delete('graves');
  }
}
