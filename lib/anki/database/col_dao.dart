import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/deck.dart';
import '../models/model.dart';
import '../models/note.dart';
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
  Map<int, Map<String, dynamic>> _savedDecks = {};
  Map<int, Map<String, dynamic>> _savedModels = {};

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
          'intervals': [1, 10],
        },
        'rev': {
          'perDay': 200,
          'bury': true,
          'fuzz': 0.05,
          'ivlFct': 1.0,
          'maxIvl': 36500,
          'ease4': 1.3,
          'minSpace': 1,
        },
        'lapse': {'leechAction': 0, 'leechFails': 8, 'minInt': 1, 'mult': 0.0},
        'maxTaken': 60,
      },
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
    final defaultDeckConfig = Map<String, dynamic>.from(dconf['1']!)
      ..remove('id')
      ..remove('name');
    await db.insert('deck_config', {
      'id': 1,
      'name': 'Default',
      'mtime_secs': now ~/ 1000,
      'usn': 0,
      'config': jsonEncode(defaultDeckConfig),
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
    _models = _parseJsonMap<Notetype>(
      row['models'] as String,
      Notetype.fromJson,
    );
    _savedDecks = _decks.map((id, value) => MapEntry(id, value.toJson()));
    _savedModels = _snapshotModels();
    _loaded = true;
  }

  /// Drop cached JSON maps after sync code updates the collection row through
  /// SQLite and reload the committed deck/notetype state.
  Future<void> reload() async {
    _loaded = false;
    _decks = {};
    _models = {};
    await load();
  }

  /// Persist the JSON blobs back to the col row.
  Future<void> save() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final nowSecs = nowMs ~/ 1000;
    modified = nowMs;
    for (final entry in _decks.entries) {
      final current = entry.value.toJson();
      if (_savedDecks[entry.key] == null ||
          jsonEncode(_savedDecks[entry.key]) != jsonEncode(current)) {
        entry.value
          ..mtimeSecs = nowSecs
          ..usn = -1;
      }
    }
    for (final entry in _models.entries) {
      final current = entry.value.toJson();
      if (_savedModels[entry.key] == null ||
          jsonEncode(_savedModels[entry.key]) != jsonEncode(current)) {
        entry.value
          ..mtime = nowSecs
          ..usn = -1;
      }
    }
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
    _savedDecks = _decks.map((id, value) => MapEntry(id, value.toJson()));
    _savedModels = _snapshotModels();
  }

  /// Rewrites local references when a remote media filename is made safe for
  /// this platform, and marks changed notes and note types for collection sync.
  Future<int> replaceMediaReferences(Map<String, String> replacements) async {
    if (replacements.isEmpty) return 0;
    await load();

    final updatedNotes = await notes.replaceMediaReferences(replacements);
    final nowSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    var modelsChanged = false;
    for (final notetype in _models.values) {
      var changed = false;
      for (final template in notetype.templates) {
        final qfmt = Note.rewriteMediaReferences(template.qfmt, replacements);
        final afmt = Note.rewriteMediaReferences(template.afmt, replacements);
        final bqfmt = Note.rewriteMediaReferences(template.bqfmt, replacements);
        final bafmt = Note.rewriteMediaReferences(template.bafmt, replacements);
        if (qfmt != template.qfmt ||
            afmt != template.afmt ||
            bqfmt != template.bqfmt ||
            bafmt != template.bafmt) {
          template
            ..qfmt = qfmt
            ..afmt = afmt
            ..bqfmt = bqfmt
            ..bafmt = bafmt;
          changed = true;
        }
      }
      final css = Note.rewriteCssMediaReferences(notetype.css, replacements);
      if (css != notetype.css) {
        notetype.css = css;
        changed = true;
      }
      if (changed) {
        notetype
          ..mtime = nowSecs
          ..usn = -1;
        modelsChanged = true;
      }
    }

    if (modelsChanged) {
      modified = DateTime.now().millisecondsSinceEpoch;
      await _db.update(
          'col',
          {
            'mod': modified,
            'models': jsonEncode(_modelsToJson()),
          },
          where: 'id = 1');
      _savedModels = _snapshotModels();
    }
    return updatedNotes;
  }

  Map<int, Map<String, dynamic>> _snapshotModels() => _models.map(
        (id, value) => MapEntry(
          id,
          jsonDecode(jsonEncode(value.toJson())) as Map<String, dynamic>,
        ),
      );

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

  Future<void> removeDeck(int id) async {
    await load();
    if (!_decks.containsKey(id)) return;
    final deck = _decks[id]!;

    final decksJson = {
      for (final entry in _decks.entries)
        if (entry.key != id) entry.key.toString(): entry.value.toJson(),
    };
    final survivingDecks =
        _decks.entries.where((entry) => entry.key != id).toList();
    final survivingDeckIds = survivingDecks.map((entry) => entry.key).toSet();
    MapEntry<int, Deck>? fallbackDeck;
    for (final entry in survivingDecks) {
      if (entry.value.kind != DeckKind.filtered) {
        fallbackDeck = entry;
        break;
      }
    }
    fallbackDeck ??= survivingDecks.isEmpty ? null : survivingDecks.first;

    final decodedConfig = jsonDecode(confJson);
    if (decodedConfig is! Map) {
      throw const FormatException('Collection config must be a JSON object.');
    }
    final nextConfig = Map<String, dynamic>.from(decodedConfig);
    int? deckIdFrom(Object? value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    final activeDecks = <int>[];
    final configuredActiveDecks = nextConfig['activeDecks'];
    if (configuredActiveDecks is List) {
      for (final value in configuredActiveDecks) {
        final activeDeckId = deckIdFrom(value);
        if (activeDeckId != null &&
            survivingDeckIds.contains(activeDeckId) &&
            !activeDecks.contains(activeDeckId)) {
          activeDecks.add(activeDeckId);
        }
      }
    }
    final currentDeckId = deckIdFrom(nextConfig['curDeck']);
    final selectedDeckId =
        currentDeckId != null && survivingDeckIds.contains(currentDeckId)
            ? currentDeckId
            : activeDecks.isNotEmpty
                ? activeDecks.first
                : fallbackDeck?.key;
    if (selectedDeckId != null && !activeDecks.contains(selectedDeckId)) {
      activeDecks.add(selectedDeckId);
    }
    nextConfig['curDeck'] = selectedDeckId ?? 0;
    nextConfig['activeDecks'] = activeDecks;
    final nextConfJson = jsonEncode(nextConfig);

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final nowSecs = nowMs ~/ 1000;
    final cardDeckWhere = deck.kind == DeckKind.filtered
        ? 'did = ?'
        : 'did = ? OR (odid != 0 AND odid = ?)';
    final cardDeckWhereArgs = deck.kind == DeckKind.filtered ? [id] : [id, id];
    await _db.transaction((txn) async {
      final cards = await txn.query(
        'cards',
        columns: ['id', 'nid', 'type', 'queue', 'due', 'odue', 'odid'],
        where: cardDeckWhere,
        whereArgs: cardDeckWhereArgs,
      );
      if (deck.kind == DeckKind.filtered) {
        for (final card in cards) {
          final originalDeckId = card['odid'] as int? ?? 0;
          final originalDeck = _decks[originalDeckId];
          if (originalDeckId <= 0 ||
              originalDeck == null ||
              originalDeck.kind == DeckKind.filtered) {
            throw StateError(
              'Filtered deck card ${card['id']} has no valid home deck.',
            );
          }

          final currentQueue = card['queue'] as int? ?? 0;
          final cardType = card['type'] as int? ?? 0;
          final originalDue = card['odue'] as int? ?? 0;
          final restoredDue =
              originalDue != 0 ? originalDue : card['due'] as int? ?? 0;
          final restoredQueue = currentQueue < 0
              ? currentQueue
              : switch (cardType) {
                  1 || 3 => restoredDue > 1000000000 ? 1 : 3,
                  2 => 2,
                  _ => 0,
                };

          await txn.update(
            'cards',
            {
              'did': originalDeckId,
              'odid': 0,
              'odue': 0,
              'due': restoredDue,
              'queue': restoredQueue,
              'mod': nowSecs,
              'usn': -1,
            },
            where: 'id = ?',
            whereArgs: [card['id']],
          );
        }
      } else {
        final noteIds = cards.map((card) => card['nid'] as int).toSet();
        for (final card in cards) {
          await txn.delete('revlog', where: 'cid = ?', whereArgs: [card['id']]);
          await txn.delete('cards', where: 'id = ?', whereArgs: [card['id']]);
          await txn.insert('graves', {'usn': -1, 'oid': card['id'], 'type': 0});
        }
        for (final noteId in noteIds) {
          final remainingCards = await txn.query(
            'cards',
            columns: ['id'],
            where: 'nid = ?',
            whereArgs: [noteId],
            limit: 1,
          );
          if (remainingCards.isEmpty) {
            final removed = await txn.delete(
              'notes',
              where: 'id = ?',
              whereArgs: [noteId],
            );
            if (removed > 0) {
              await txn.insert('graves', {'usn': -1, 'oid': noteId, 'type': 1});
            }
          }
        }
      }
      await txn.insert('graves', {'usn': -1, 'oid': id, 'type': 2});
      await txn.update(
          'col',
          {
            'decks': jsonEncode(decksJson),
            'conf': nextConfJson,
            'mod': nowMs,
          },
          where: 'id = 1');
    });

    _decks.remove(id);
    confJson = nextConfJson;
    modified = nowMs;
    _savedDecks = _decks.map((key, value) => MapEntry(key, value.toJson()));
  }

  void renameDeck(int id, String name) {
    final d = _decks[id];
    if (d != null) {
      d
        ..name = name
        ..mtimeSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000
        ..usn = -1;
    }
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
    String json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return {
      for (final e in map.entries)
        int.parse(e.key): fromJson(e.value as Map<String, dynamic>),
    };
  }

  Map<String, dynamic> _decksToJson() => {
        for (final e in _decks.entries) e.key.toString(): e.value.toJson(),
      };

  Map<String, dynamic> _modelsToJson() => {
        for (final e in _models.entries) e.key.toString(): e.value.toJson(),
      };
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
