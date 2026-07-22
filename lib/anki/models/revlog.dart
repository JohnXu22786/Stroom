/// Anki RevlogEntry — exact mapping of the upstream Rust `RevlogEntry` struct
/// (ankitects/anki rslib/src/revlog/mod.rs, stats.proto).
///
/// ## Version reference
/// - AnkiDroid target release: **2.24.0** (May 2026)
/// - Upstream anki commit tracked at proto import time
///
/// ## Field mapping
///
/// | Rust field      | Dart field        | DB column | Proto field    |
/// |-----------------|-------------------|-----------|----------------|
/// | id              | id                | id        | id             |
/// | cid             | cid               | cid       | cid            |
/// | usn             | usn               | usn       | usn            |
/// | button_chosen   | button_chosen     | ease      | button_chosen  |
/// | interval        | interval          | ivl       | interval       |
/// | last_interval   | last_interval     | lastIvl   | last_interval  |
/// | ease_factor     | ease_factor       | factor    | ease_factor    |
/// | taken_millis    | taken_millis      | time      | taken_millis   |
/// | review_kind     | review_kind       | type      | review_kind    |

/// Review kind matching `RevlogReviewKind` in the upstream revlog/mod.rs.
///
/// | Value | Meaning       |
/// |-------|---------------|
/// | 0     | Learning      |
/// | 1     | Review        |
/// | 2     | Relearning    |
/// | 3     | Filtered/Cram |
/// | 4     | Manual        |
/// | 5     | Rescheduled   |
enum RevlogReviewKind {
  learning(0),
  review(1),
  relearning(2),
  filtered(3),
  manual(4),
  rescheduled(5);

  final int value;
  const RevlogReviewKind(this.value);

  static RevlogReviewKind fromValue(int v) => RevlogReviewKind.values
      .firstWhere((e) => e.value == v, orElse: () => RevlogReviewKind.review);
}

/// In-memory RevlogEntry matching the upstream Rust `RevlogEntry` struct.
class RevlogEntry {
  int id; // PRIMARY KEY — microsecond timestamp
  int cid; // cards.id
  int usn; // update sequence number
  int button_chosen; // rating: 1=again, 2=hard, 3=good, 4=easy (was: ease)
  int interval; // new interval in days (was: ivl)
  int last_interval; // previous interval in days (was: lastIvl)
  int ease_factor; // ease factor after review (was: factor)
  int taken_millis; // review duration in milliseconds (was: time)
  RevlogReviewKind review_kind; // 0=learning, 1=review, etc. (was: type)

  RevlogEntry({
    int? id,
    required this.cid,
    this.usn = -1,
    required this.button_chosen,
    required this.interval,
    this.last_interval = 0,
    this.ease_factor = 2500,
    this.taken_millis = 0,
    RevlogReviewKind? review_kind,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch,
        review_kind = review_kind ?? RevlogReviewKind.review;

  // ── Serialization ─────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'id': id,
        'cid': cid,
        'usn': usn,
        'ease': button_chosen,
        'ivl': interval,
        'lastIvl': last_interval,
        'factor': ease_factor,
        'time': taken_millis,
        'type': review_kind.value,
      };

  factory RevlogEntry.fromMap(Map<String, dynamic> m) => RevlogEntry(
        id: m['id'] as int?,
        cid: m['cid'] as int,
        usn: m['usn'] as int? ?? -1,
        button_chosen: m['ease'] as int,
        interval: m['ivl'] as int,
        last_interval: m['lastIvl'] as int? ?? 0,
        ease_factor: m['factor'] as int? ?? 2500,
        taken_millis: m['time'] as int? ?? 0,
        review_kind: RevlogReviewKind.fromValue(m['type'] as int? ?? 1),
      );

  @override
  String toString() =>
      'RevlogEntry(cid=$cid, button_chosen=$button_chosen, interval=$interval)';
}
