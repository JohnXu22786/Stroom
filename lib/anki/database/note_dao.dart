import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/note.dart';

class NoteDao {
  static const _mediaReferenceSearchBatchSize = 100;

  final Database _db;
  NoteDao(this._db);

  Future<Note?> get(int id) async {
    final rows = await _db.query('notes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Note.fromMap(rows.first);
  }

  Future<List<Note>> listByModel(int notetypeId) async {
    final rows = await _db.query(
      'notes',
      where: 'mid = ?',
      whereArgs: [notetypeId],
    );
    return rows.map(Note.fromMap).toList();
  }

  Future<int> insert(Note note) async {
    await _refreshDerivedFields(note);
    note
      ..mtime = DateTime.now().millisecondsSinceEpoch ~/ 1000
      ..usn = -1;
    await _db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _touchCollection();
    return note.id;
  }

  Future<void> update(Note note) async {
    await _refreshDerivedFields(note);
    note
      ..mtime = DateTime.now().millisecondsSinceEpoch ~/ 1000
      ..usn = -1;
    await _db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
    await _touchCollection();
  }

  /// Updates collection references after a remote media filename has been
  /// normalized to a path safe for this platform. Changed notes remain pending
  /// so the replacement name is propagated during the next collection sync.
  Future<int> replaceMediaReferences(Map<String, String> replacements) async {
    if (replacements.isEmpty) return 0;

    final replacementNames = replacements.keys
        .where((filename) => filename.isNotEmpty)
        .toList();
    final matchingIds = <int>{};
    for (
      var offset = 0;
      offset < replacementNames.length;
      offset += _mediaReferenceSearchBatchSize
    ) {
      final batch = replacementNames
          .skip(offset)
          .take(_mediaReferenceSearchBatchSize);
      final searchableValues = <String>{};
      for (final filename in batch) {
        searchableValues
          ..add(filename)
          ..add(const HtmlEscape(HtmlEscapeMode.element).convert(filename));
      }
      final values = searchableValues.toList();
      final predicates = List.filled(values.length, 'instr(flds, ?) > 0');
      final matching = await _db.query(
        'notes',
        columns: ['id'],
        where: predicates.join(' OR '),
        whereArgs: values,
      );
      matchingIds.addAll(matching.map((row) => (row['id'] as num).toInt()));
    }

    var updated = 0;
    for (final noteId in matchingIds) {
      final note = await get(noteId);
      if (note == null) continue;
      final fields = note.fields
          .map((field) => Note.rewriteMediaReferences(field, replacements))
          .toList();
      var changed = false;
      for (var index = 0; index < fields.length; index++) {
        if (fields[index] != note.fields[index]) {
          changed = true;
          break;
        }
      }
      if (!changed) continue;
      note.fields = fields;
      await update(note);
      updated++;
    }
    return updated;
  }

  Future<void> _refreshDerivedFields(Note note) async {
    final rows = await _db.query('col', columns: ['models'], where: 'id = 1');
    if (rows.isEmpty || rows.first['models'] is! String) {
      throw StateError('The collection note types are unavailable.');
    }

    final models = jsonDecode(rows.first['models'] as String);
    if (models is! Map) {
      throw StateError('The collection note types are invalid.');
    }
    final notetype = models[note.notetype_id.toString()];
    if (notetype is! Map) {
      throw StateError('The note type ${note.notetype_id} is unavailable.');
    }

    final rawIndex = notetype['sortf'];
    final sortFieldIndex = rawIndex is num ? rawIndex.toInt() : 0;
    note
      ..sort_field = sortFieldIndex >= 0 && sortFieldIndex < note.fields.length
          ? note.fields[sortFieldIndex]
          : ''
      ..checksum = null;
  }

  Future<void> delete(int id) async {
    await _db.transaction((txn) async {
      final cards = await txn.query(
        'cards',
        columns: ['id'],
        where: 'nid = ?',
        whereArgs: [id],
      );
      for (final card in cards) {
        await txn.delete('revlog', where: 'cid = ?', whereArgs: [card['id']]);
        await txn.insert('graves', {'usn': -1, 'oid': card['id'], 'type': 0});
      }
      if (cards.isNotEmpty) {
        await txn.delete('cards', where: 'nid = ?', whereArgs: [id]);
      }
      final removed = await txn.delete(
        'notes',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (removed > 0) {
        await txn.insert('graves', {'usn': -1, 'oid': id, 'type': 1});
      }
      if (removed > 0 || cards.isNotEmpty) {
        await txn.rawUpdate('UPDATE col SET mod = ? WHERE id = 1', [
          DateTime.now().millisecondsSinceEpoch,
        ]);
      }
    });
  }

  Future<void> _touchCollection() => _db.rawUpdate(
    'UPDATE col SET mod = ? WHERE id = 1',
    [DateTime.now().millisecondsSinceEpoch],
  );

  Future<List<Note>> all() async {
    final rows = await _db.query('notes');
    return rows.map(Note.fromMap).toList();
  }
}
