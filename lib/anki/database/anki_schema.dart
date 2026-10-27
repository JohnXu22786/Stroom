/// Anki schema 11 collection tables plus Stroom's local settings tables.
///
/// Official tables: col, notes, cards, revlog, graves. Stroom adds local
/// deck_config and config tables for normalized sync bookkeeping.
class AnkiSchema {
  /// Current schema version (Anki 2.1 schema version 11).
  static const int schemaVersion = 11;

  /// Returns the complete CREATE TABLE SQL.
  static List<String> get createStatements => [
    _createCol,
    _createNotes,
    _createCards,
    _createRevlog,
    _createGraves,
    ...localSupportStatements,
  ];

  /// App-local tables that are not present in an official schema 11 download.
  /// They are created when a collection is opened by Stroom.
  static List<String> get localSupportStatements => [
    _createDeckConfig,
    _createConfig,
    syncDestinationStatement,
  ];

  // ─── col ─────────────────────────────────────────────────────
  // Stores collection-level metadata and JSON config blobs.
  static const String _createCol = '''
    CREATE TABLE IF NOT EXISTS col (
      id        INTEGER PRIMARY KEY,
      crt       INTEGER NOT NULL,
      mod       INTEGER NOT NULL,
      scm       INTEGER NOT NULL,
      ver       INTEGER NOT NULL,
      dty       INTEGER NOT NULL,
      usn       INTEGER NOT NULL,
      ls        INTEGER NOT NULL,
      conf      TEXT NOT NULL,
      models    TEXT NOT NULL,
      decks     TEXT NOT NULL,
      dconf     TEXT NOT NULL,
      tags      TEXT NOT NULL
    )
  ''';

  // ─── notes ───────────────────────────────────────────────────
  // Facts / notes. Fields separated by 0x1f (unit separator).
  static const String _createNotes = '''
    CREATE TABLE IF NOT EXISTS notes (
      id        INTEGER PRIMARY KEY,
      guid      TEXT NOT NULL,
      mid       INTEGER NOT NULL,
      mod       INTEGER NOT NULL,
      usn       INTEGER NOT NULL,
      tags      TEXT NOT NULL,
      flds      TEXT NOT NULL,
      sfld      INTEGER NOT NULL,
      csum      INTEGER NOT NULL,
      flags     INTEGER NOT NULL,
      data      TEXT NOT NULL
    )
  ''';

  // ─── cards ───────────────────────────────────────────────────
  // Individual reviewable cards. Scheduling state inline.
  static const String _createCards = '''
    CREATE TABLE IF NOT EXISTS cards (
      id        INTEGER PRIMARY KEY,
      nid       INTEGER NOT NULL,
      did       INTEGER NOT NULL,
      ord       INTEGER NOT NULL,
      mod       INTEGER NOT NULL,
      usn       INTEGER NOT NULL,
      type      INTEGER NOT NULL,
      queue     INTEGER NOT NULL,
      due       INTEGER NOT NULL,
      ivl       INTEGER NOT NULL,
      factor    INTEGER NOT NULL,
      reps      INTEGER NOT NULL,
      lapses    INTEGER NOT NULL,
      left      INTEGER NOT NULL,
      odue      INTEGER NOT NULL,
      odid      INTEGER NOT NULL,
      flags     INTEGER NOT NULL,
      data      TEXT NOT NULL
    )
  ''';

  // ─── revlog ──────────────────────────────────────────────────
  // Review history — one row per review.
  static const String _createRevlog = '''
    CREATE TABLE IF NOT EXISTS revlog (
      id        INTEGER PRIMARY KEY,
      cid       INTEGER NOT NULL,
      usn       INTEGER NOT NULL,
      ease      INTEGER NOT NULL,
      ivl       INTEGER NOT NULL,
      lastIvl   INTEGER NOT NULL,
      factor    INTEGER NOT NULL,
      time      INTEGER NOT NULL,
      type      INTEGER NOT NULL
    )
  ''';

  // ─── graves ──────────────────────────────────────────────────
  // Deleted objects pending sync deletion.
  static const String _createGraves = '''
    CREATE TABLE IF NOT EXISTS graves (
      usn       INTEGER NOT NULL,
      oid       INTEGER NOT NULL,
      type      INTEGER NOT NULL
    )
  ''';

  // ─── local deck_config mirror ────────────────────────────────
  // Normalized local index mirrored to col.dconf for sync.
  static const String _createDeckConfig = '''
    CREATE TABLE IF NOT EXISTS deck_config (
      id         INTEGER PRIMARY KEY,
      name       TEXT NOT NULL,
      mtime_secs INTEGER NOT NULL,
      usn        INTEGER NOT NULL,
      config     TEXT NOT NULL
    )
  ''';

  // ─── local config mirror ────────────────────────────────────
  // Normalized local settings index used by incremental sync.
  static const String _createConfig = '''
    CREATE TABLE IF NOT EXISTS config (
      key        TEXT PRIMARY KEY,
      usn        INTEGER NOT NULL,
      mtime_secs INTEGER NOT NULL,
      config     TEXT NOT NULL
    )
  ''';

  // ─── local sync destination guard ─────────────────────────────
  // Prevent incremental USNs from one destination being applied to another.
  static const String syncDestinationStatement = '''
    CREATE TABLE IF NOT EXISTS stroom_sync_destination (
      id         INTEGER PRIMARY KEY CHECK (id = 1),
      identity   TEXT NOT NULL
    )
  ''';
}
