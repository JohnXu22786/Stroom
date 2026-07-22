/// Anki Card — exact 1:1 mapping of the upstream Rust `Card` struct
/// (ankitects/anki rslib/src/card/mod.rs).
///
/// Field naming follows the upstream Rust source / protobuf definition
/// (`cards.proto`), NOT the DB column short names.
///
/// ## Version reference
/// - AnkiDroid target release: **2.24.0** (May 2026)
/// - Upstream anki commit tracked at proto import time
/// - Upstream Rust workspace: `rslib/src/card/mod.rs`
///
/// ## Notes
/// - `toMap()` / `fromMap()` use DB column short names for SQLite storage.
/// - New fields added upstream since our initial implementation:
///   `original_position`, `memory_state`, `desired_retention`, `decay`,
///   `last_review_time`.

// ─── Enums ────────────────────────────────────────────────────────────────
// Match CardType and CardQueue from the Rust `card/mod.rs`.

/// Card type mirroring `CardType` in anki rslib.
///
/// | Value | Meaning     |
/// |-------|-------------|
/// | 0     | New         |
/// | 1     | Learn       |
/// | 2     | Review      |
/// | 3     | Relearn     |
enum CardType {
  new_(0),
  learn(1),
  review(2),
  relearn(3);

  final int value;
  const CardType(this.value);

  static CardType fromValue(int v) => CardType.values
      .firstWhere((e) => e.value == v, orElse: () => CardType.new_);
}

/// Card queue mirroring `CardQueue` in anki rslib.
///
/// | Value | Meaning       |
/// |-------|---------------|
/// | -3    | UserBuried    |
/// | -2    | SchedBuried   |
/// | -1    | Suspended     |
/// | 0     | New           |
/// | 1     | Learn         |
/// | 2     | Review        |
/// | 3     | DayLearn      |
/// | 4     | PreviewRepeat |
enum CardQueue {
  new_(0),
  learn(1),
  review(2),
  dayLearn(3),
  previewRepeat(4),
  suspended(-1),
  schedBuried(-2),
  userBuried(-3);

  final int value;
  const CardQueue(this.value);

  static CardQueue fromValue(int v) => CardQueue.values
      .firstWhere((e) => e.value == v, orElse: () => CardQueue.new_);
}

// ─── FSRS memory state ────────────────────────────────────────────────────

/// FSRS memory state, matching `FsrsMemoryState` in cards.proto.
class FsrsMemoryState {
  /// Expected memory stability in days.
  double stability;

  /// A number in the range 1.0–10.0.
  double difficulty;

  FsrsMemoryState({required this.stability, required this.difficulty});

  /// Normalized difficulty in 0.0–1.0 range.
  double get normalizedDifficulty => (difficulty - 1.0) / 9.0;

  Map<String, dynamic> toJson() => {
        'stability': stability,
        'difficulty': difficulty,
      };

  factory FsrsMemoryState.fromJson(Map<String, dynamic> j) => FsrsMemoryState(
        stability: (j['stability'] as num).toDouble(),
        difficulty: (j['difficulty'] as num).toDouble(),
      );
}

// ─── Card ─────────────────────────────────────────────────────────────────

/// In-memory Card matching the upstream Rust `Card` struct.
///
/// ## Rust → Dart field mapping
///
/// | Rust field           | Dart field                | DB column |
/// |----------------------|---------------------------|-----------|
/// | id                   | id                        | id        |
/// | note_id              | note_id                   | nid       |
/// | deck_id              | deck_id                   | did       |
/// | template_idx         | template_idx              | ord       |
/// | mtime                | mtime                     | mod       |
/// | usn                  | usn                       | usn       |
/// | ctype                | ctype (CardType enum)     | type      |
/// | queue                | queue (CardQueue enum)    | queue     |
/// | due                  | due                       | due       |
/// | interval             | interval                  | ivl       |
/// | ease_factor          | ease_factor               | factor    |
/// | reps                 | reps                      | reps      |
/// | lapses               | lapses                    | lapses    |
/// | remaining_steps      | remaining_steps           | left      |
/// | original_due         | original_due              | odue      |
/// | original_deck_id     | original_deck_id          | odid      |
/// | flags                | flags                     | flags     |
/// | original_position    | original_position (opt)   | —         |
/// | memory_state         | memory_state (opt)        | —         |
/// | desired_retention    | desired_retention (opt)   | —         |
/// | decay                | decay (opt)               | —         |
/// | last_review_time     | last_review_time (opt)    | —         |
/// | custom_data          | custom_data               | data      |
class Card {
  // ── Core fields ────────────────────────────────────────────────────────
  int id; // PRIMARY KEY — microsecond timestamp
  int note_id; // notes.id (was: nid)
  int deck_id; // deck id (was: did)
  int template_idx; // ordinal within note (was: ord)
  int mtime; // last modified epoch seconds (was: mod)
  int usn; // update sequence number (-1 = local change)
  CardType ctype; // 0=new, 1=learn, 2=review, 3=relearn (was: type)
  CardQueue queue;
  int due; // new→position, learn→epoch ms, review→day ordinal
  int interval; // interval in days (was: ivl)
  int ease_factor; // ease factor in permille, 2500 = 250% (was: factor)
  int reps; // correct reviews
  int lapses; // times forgotten
  int remaining_steps; // learning step tracking (was: left)
  int original_due; // original due for filtered decks (was: odue)
  int original_deck_id; // original deck id for filtered decks (was: odid)
  int flags; // flag (0-7)

  // ── New upstream fields (not stored in anc. DB columns) ────────────────
  int? original_position; // position in new queue before leaving
  FsrsMemoryState? memory_state; // FSRS memory state
  double? desired_retention; // FSRS desired retention
  double? decay; // FSRS decay
  int? last_review_time; // epoch seconds of last review

  // ── JSON custom data ──────────────────────────────────────────────────
  String custom_data; // JSON string (was: data)

  Card({
    int? id,
    required this.note_id,
    required this.deck_id,
    this.template_idx = 0,
    this.mtime = 0,
    this.usn = -1,
    CardType? ctype,
    CardQueue? queue,
    this.due = 0,
    this.interval = 0,
    this.ease_factor = 2500,
    this.reps = 0,
    this.lapses = 0,
    this.remaining_steps = 0,
    this.original_due = 0,
    this.original_deck_id = 0,
    this.flags = 0,
    this.original_position,
    this.memory_state,
    this.desired_retention,
    this.decay,
    this.last_review_time,
    this.custom_data = '',
  })  : id = id ?? _nextId(),
        ctype = ctype ?? CardType.new_,
        queue = queue ?? CardQueue.new_;

  /// Creates a new card linked to [noteId] in deck [deckId].
  factory Card.createNew(
      {required int note_id, required int deck_id, int template_idx = 0}) {
    final now = DateTime.now().microsecondsSinceEpoch;
    return Card(
      id: now,
      note_id: note_id,
      deck_id: deck_id,
      template_idx: template_idx,
      mtime: now ~/ 1000,
    );
  }

  // ── Computed helpers ──────────────────────────────────────────────────

  /// Shorthand getter for backward compat — returns `note_id`.
  @Deprecated('Use note_id instead')
  int get nid => note_id;

  /// Shorthand getter for backward compat — returns `deck_id`.
  @Deprecated('Use deck_id instead')
  int get did => deck_id;

  /// Shorthand getter for backward compat — returns `template_idx`.
  @Deprecated('Use template_idx instead')
  int get ord => template_idx;

  /// Shorthand getter for backward compat — returns `mtime`.
  @Deprecated('Use mtime instead')
  int get mod => mtime;

  /// Shorthand getter for backward compat — returns `ctype`.
  @Deprecated('Use ctype instead')
  int get type => ctype.value;

  /// Shorthand getter for backward compat — returns `queue` as int.
  @Deprecated('Use queue instead')
  int get queueRaw => queue.value;

  /// Shorthand getter for backward compat — returns `interval`.
  @Deprecated('Use interval instead')
  int get ivl => interval;

  /// Shorthand getter for backward compat — returns `ease_factor`.
  @Deprecated('Use ease_factor instead')
  int get factor => ease_factor;

  /// Shorthand getter for backward compat — returns `remaining_steps`.
  @Deprecated('Use remaining_steps instead')
  int get left => remaining_steps;

  /// Shorthand getter for backward compat — returns `original_due`.
  @Deprecated('Use original_due instead')
  int get odue => original_due;

  /// Shorthand getter for backward compat — returns `original_deck_id`.
  @Deprecated('Use original_deck_id instead')
  int get odid => original_deck_id;

  /// Shorthand getter for backward compat — returns `custom_data`.
  @Deprecated('Use custom_data instead')
  String get data => custom_data;

  bool get isNew => queue == CardQueue.new_;
  bool get isLearning =>
      queue == CardQueue.learn || queue == CardQueue.dayLearn;
  bool get isReview => queue == CardQueue.review;
  bool get isSuspended => queue.value < 0;

  bool isDue(int nowSec) {
    if (isSuspended) return false;
    if (isNew) return true;
    return due <= nowSec;
  }

  /// Return the total number of steps left, ignoring the "steps today" part
  /// packed into the DB representation. Mirrors `remaining_steps()` in Rust.
  int get remainingStepsOnly => remaining_steps % 1000;

  /// Return ease factor as a multiplier (e.g. 2.5).
  double get easeFactorMultiplier => ease_factor / 1000.0;

  // ── Learning / review scheduling ──────────────────────────────────────

  /// Start learning (new → learning).
  /// [nowMs] is current time in milliseconds.
  void startLearning(int nowMs, {List<int> steps = const [1, 10]}) {
    if (queue != CardQueue.new_) return;
    queue = CardQueue.learn;
    ctype = CardType.learn;
    remaining_steps = steps.length;
    due = (nowMs ~/ 1000) + (steps[0] * 60);
  }

  /// Answer during learning. [answerIdx]: 0=again, 1=hard, 2=good, 3=easy.
  void answerLearning(int nowMs,
      {required List<int> steps, int answerIdx = 2, int graduatingIvl = 1}) {
    if (queue != CardQueue.learn) return;
    final nowSec = nowMs ~/ 1000;
    final stepIdx = remaining_steps >> 8; // high byte

    if (answerIdx == 0) {
      // Again — reset to first step
      remaining_steps = steps.length;
      due = nowSec + (steps[0] * 60);
      return;
    }
    if (answerIdx == 1) {
      // Hard — repeat current step
      final min = stepIdx < steps.length ? steps[stepIdx] : steps.last;
      due = nowSec + (min * 60);
      return;
    }
    if (answerIdx == 3) {
      // Easy — graduate immediately with bonus (Anki easyBonus=1.3)
      queue = CardQueue.review;
      ctype = CardType.review;
      interval = (graduatingIvl * 1.3).round();
      due = nowSec + (interval * 86400);
      reps = 1;
      remaining_steps = 0;
      return;
    }
    // Good (idx 2) — advance one step
    final next = stepIdx + 1;
    if (next >= steps.length) {
      // Graduate to review
      queue = CardQueue.review;
      ctype = CardType.review;
      interval = graduatingIvl;
      due = nowSec + (interval * 86400);
      reps = 1;
      remaining_steps = 0;
    } else {
      remaining_steps = (next << 8) | (steps.length - next);
      due = nowSec + (steps[next] * 60);
    }
  }

  /// Answer during review. [rating]: 1=again, 2=hard, 3=good, 4=easy.
  void answerReview(int nowMs,
      {int rating = 3,
      double hardMult = 1.2,
      int relearnSteps = 2,
      int relearnMin = 1}) {
    if (queue != CardQueue.review && queue != CardQueue.dayLearn) return;
    final nowSec = nowMs ~/ 1000;
    if (rating == 1) {
      // Lapse
      lapses++;
      queue = CardQueue.learn;
      ctype = CardType.relearn;
      remaining_steps = relearnSteps;
      due = nowSec + (relearnMin * 60);
      ease_factor = (ease_factor - 200).clamp(1300, 9999);
      return;
    }
    reps++;
    switch (rating) {
      case 2:
        ease_factor = (ease_factor - 150).clamp(1300, 9999);
        interval = (interval * hardMult).round().clamp(1, 36500);
        break;
      case 3:
        interval = _nextIvl(interval, ease_factor);
        break;
      case 4:
        ease_factor = (ease_factor + 150).clamp(1300, 9999);
        final base = _nextIvl(interval, ease_factor);
        interval = (base * 1.3).round().clamp(1, 36500);
        break;
    }
    due = nowSec + (interval * 86400);
  }

  int _nextIvl(int cur, int fac) {
    if (cur == 0) return 1;
    return (cur * fac / 1000).round().clamp(1, 36500);
  }

  // ── Serialization (DB ↔ in-memory) ────────────────────────────────────

  /// Serialize to DB column map (short names).
  Map<String, dynamic> toMap() => {
        'id': id,
        'nid': note_id,
        'did': deck_id,
        'ord': template_idx,
        'mod': mtime,
        'usn': usn,
        'type': ctype.value,
        'queue': queue.value,
        'due': due,
        'ivl': interval,
        'factor': ease_factor,
        'reps': reps,
        'lapses': lapses,
        'left': remaining_steps,
        'odue': original_due,
        'odid': original_deck_id,
        'flags': flags,
        'data': custom_data,
      };

  /// Deserialize from DB column map (short names).
  factory Card.fromMap(Map<String, dynamic> m) => Card(
        id: m['id'] as int,
        note_id: m['nid'] as int,
        deck_id: m['did'] as int,
        template_idx: m['ord'] as int? ?? 0,
        mtime: m['mod'] as int? ?? 0,
        usn: m['usn'] as int? ?? -1,
        ctype: CardType.fromValue(m['type'] as int? ?? 0),
        queue: CardQueue.fromValue(m['queue'] as int? ?? 0),
        due: m['due'] as int? ?? 0,
        interval: m['ivl'] as int? ?? 0,
        ease_factor: m['factor'] as int? ?? 2500,
        reps: m['reps'] as int? ?? 0,
        lapses: m['lapses'] as int? ?? 0,
        remaining_steps: m['left'] as int? ?? 0,
        original_due: m['odue'] as int? ?? 0,
        original_deck_id: m['odid'] as int? ?? 0,
        flags: m['flags'] as int? ?? 0,
        custom_data: m['data'] as String? ?? '',
      );

  static int _counter = 0;
  static int _nextId() {
    _counter++;
    return DateTime.now().microsecondsSinceEpoch + _counter;
  }

  @override
  String toString() =>
      'Card(id=$id, deck_id=$deck_id, ctype=$ctype, queue=$queue)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Card && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
