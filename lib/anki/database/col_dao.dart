import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/deck.dart';
import '../models/model.dart';
import 'card_dao.dart';
import 'note_dao.dart';
import 'revlog_dao.dart';
import 'grave_dao.dart';

/// DAO for the `col` table — also acts as the high-level collection orchestrator.
///
/// The `col` row stores JSON blobs for decks, models, config, and tags.
/// This class parses them into in-memory Dart objects, mediates all
/// collection-level operations (deck/note/card CRUD), and serializes back.
class ColDao {
  final Database _db;
  final CardDao cards;
  final NoteDao notes;
  final RevlogDao revlog;
  final GraveDao graves;

  // ── In-memory state (loaded from col JSON blobs) ──────────
  int creationDate = 0;
  int modified = 0;
  int schemaModTime = 0;
  int version = 11;
  int dirty = 0;
  int usn = 0;
  int lastSync = 0;
  String confJson = '{}';
  String tagsJson = '{}';
  bool _loaded = false;

  // Decks parsed from JSON, keyed by deck id
  Map<int, Deck> _decks = {};
  // Models parsed from JSON, keyed by model id
  Map<int, Notetype> _models = {};

  ColDao(this._db, this.cards, this.notes, this.revlog, this.graves);

  /// Seed initial col row on fresh database.
  static Future<void> seed(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final deck = Deck.createNew(name: 'Default');
    // Default Basic model
    final basic = Notetype.createBasic();
    // Default deck preset
    final dconf = {
      '1': {
        'id': 1,
        'name': 'Default',
        'new': {
          'perDay': 20,
          'bury': true,
          'order': 1,
          'initialFactor': 2500,
          'intervals': [1, 10]
        },
        'rev': {
          'perDay': 200,
          'bury': true,
          'fuzz': 0.05,
          'ivlFct': 1.0,
          'maxIvl': 36500,
          'ease4': 1.3,
          'minSpace': 1
        },
        'lapse': {'leechAction': 0, 'leechFails': 8, 'minInt': 1, 'mult': 0.0},
        'maxTaken': 60,
      }
    };
    await db.insert('col', {
      'id': 1,
      'crt': now ~/ 1000,
      'mod': now,
      'scm': now,
      'ver': 11,
      'dty': 0,
      'usn': 0,
      'ls': 0,
      'conf': jsonEncode({
        'activeDecks': [deck.id],
        'curDeck': deck.id,
        'newSpread': 0,
        'timeLim': 0,
        'sortBackwards': false,
        'addToCur': true,
        'dayLearnFirst': false,
        'pastePNG': false,
        'nextPos': 1,
        'estTimes': true,
        'rollup': true,
        'collapseTime': 1200,
      }),
      'models': jsonEncode({basic.id.toString(): basic.toJson()}),
      'decks': jsonEncode({deck.id.toString(): deck.toJson()}),
      'dconf': jsonEncode(dconf),
      'tags': '{}',
    });
  }

  /// Load the col row from the database.
  Future<void> load() async {
    if (_loaded) return;
    final rows = await _db.query('col', where: 'id = 1');
    if (rows.isEmpty) return;
    final row = rows.first;
    creationDate = row['crt'] as int;
    modified = row['mod'] as int;
    schemaModTime = row['scm'] as int;
    version = row['ver'] as int;
    dirty = row['dty'] as int;
    usn = row['usn'] as int;
    lastSync = row['ls'] as int;
    confJson = row['conf'] as String;
    tagsJson = row['tags'] as String;

    _decks = _parseJsonMap<Deck>(row['decks'] as String, Deck.fromJson);
    _models =
        _parseJsonMap<Notetype>(row['models'] as String, Notetype.fromJson);
    _loaded = true;
  }

  /// Persist the JSON blobs back to the col row.
  Future<void> save() async {
    modified = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
        'col',
        {
          'mod': modified,
          'dty': dirty,
          'conf': confJson,
          'models': jsonEncode(_modelsToJson()),
          'decks': jsonEncode(_decksToJson()),
          'tags': tagsJson,
        },
        where: 'id = 1');
  }

  // ── Decks ────────────────────────────────────────────────

  List<Deck> get deckList =>
      _decks.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  Deck? getDeck(int id) => _decks[id];

  Deck addDeck(String name, {String desc = ''}) {
    final existing = _decks.values.where((d) => d.name == name).toList();
    if (existing.isNotEmpty) return existing.first;
    final deck = Deck.createNew(name: name, description: desc);
    _decks[deck.id] = deck;
    return deck;
  }

  void removeDeck(int id) {
    _decks.remove(id);
    // cards and notes for this deck stay in the DB but become orphaned
  }

  void renameDeck(int id, String name) {
    final d = _decks[id];
    if (d != null) d.name = name;
  }

  // ── Models ────────────────────────────────────────────────

  List<Notetype> get modelList => _models.values.toList();
  Notetype? getModel(int id) => _models[id];
  void addModel(Notetype m) => _models[m.id] = m;

  // ── High-level operations ─────────────────────────────────

  Future<DeckStats> getDeckStats(int did) async {
    final deck = _decks[did];
    final newCnt = await cards.countByQueue(did, 0);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final learnCnt = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM cards WHERE did = ? AND (queue = 1 OR queue = 3) AND due <= ?',
      [did, now],
    );
    final revCnt = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM cards WHERE did = ? AND queue = 2 AND due <= ?',
      [did, now],
    );
    final total = await cards.totalCount(did);
    return DeckStats(
      deckName: deck?.name ?? 'Unknown',
      newCount: newCnt,
      learningCount: learnCnt.first['cnt'] as int,
      reviewCount: revCnt.first['cnt'] as int,
      totalCount: total,
    );
  }

  // ── JSON helpers ──────────────────────────────────────────

  Map<int, T> _parseJsonMap<T>(
      String json, T Function(Map<String, dynamic>) fromJson) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return {
      for (final e in map.entries)
        int.parse(e.key): fromJson(e.value as Map<String, dynamic>)
    };
  }

  Map<String, dynamic> _decksToJson() =>
      {for (final e in _decks.entries) e.key.toString(): e.value.toJson()};

  Map<String, dynamic> _modelsToJson() =>
      {for (final e in _models.entries) e.key.toString(): e.value.toJson()};
}

/// Deck statistics.
class DeckStats {
  final String deckName;
  final int newCount;
  final int learningCount;
  final int reviewCount;
  final int totalCount;

  DeckStats({
    required this.deckName,
    this.newCount = 0,
    this.learningCount = 0,
    this.reviewCount = 0,
    this.totalCount = 0,
  });
}
