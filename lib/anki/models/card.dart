/// AnkiDroid card database schema — exact 1:1 mapping.
///
/// Column names (nid, did, ord, ivl, factor, …) match collection.anki2.
class AnkiCard {
  int id; // PRIMARY KEY — microsecond timestamp
  int nid; // notes.id
  int did; // deck id
  int ord; // ordinal within note (0-based)
  int mod; // last modified (epoch seconds)
  int usn; // update sequence number (-1 = local change)
  int type; // 0=new, 1=learning, 2=review, 3=relearning
  int queue; // 0=new, 1=learn, 2=review, 3=day-learn, -1=susp, -2=u-buried, -3=s-buried
  int due; // new→position, learn→epoch ms, review→day ordinal
  int ivl; // interval (days)
  int factor; // ease factor (2500 = 250%)
  int reps; // correct reviews
  int lapses; // times forgotten
  int left; // learning step tracking (high byte=current step, low byte=remaining)
  int odue; // original due (filtered decks)
  int odid; // original deck id (filtered decks)
  int flags; // flag (0-7)
  String data; // JSON string (unused by core)

  AnkiCard({
    int? id,
    required this.nid,
    required this.did,
    this.ord = 0,
    this.mod = 0,
    this.usn = -1,
    this.type = 0,
    this.queue = 0,
    this.due = 0,
    this.ivl = 0,
    this.factor = 2500,
    this.reps = 0,
    this.lapses = 0,
    this.left = 0,
    this.odue = 0,
    this.odid = 0,
    this.flags = 0,
    this.data = '',
  }) : id = id ?? _nextId();

  /// Creates a new card linked to [nid] in deck [did].
  factory AnkiCard.createNew(
      {required int nid, required int did, int ord = 0}) {
    final now = DateTime.now().microsecondsSinceEpoch;
    return AnkiCard(
      id: now,
      nid: nid,
      did: did,
      ord: ord,
      mod: now ~/ 1000,
    );
  }

  // ── helpers ─────────────────────────────────────────────

  bool get isNew => queue == 0;
  bool get isLearning => queue == 1 || queue == 3;
  bool get isReview => queue == 2;
  bool get isSuspended => queue < 0;
  bool isDue(int nowSec) {
    if (isSuspended) return false;
    if (isNew) return true;
    return due <= nowSec;
  }

  // ── learning/review scheduling ──────────────────────────

  /// Start learning (new → learning).
  /// [nowMs] is current time in milliseconds (for compatibility with Anki's API).
  /// [due] is stored as epoch seconds (same as Anki's learning due encoding).
  void startLearning(int nowMs, {List<int> steps = const [1, 10]}) {
    if (queue != 0) return;
    queue = 1;
    type = 1;
    left = steps.length;
    // due in epoch seconds
    due = (nowMs ~/ 1000) + (steps[0] * 60);
  }

  /// Answer during learning. [answerIdx]: 0=again, 1=hard, 2=good, 3=easy.
  void answerLearning(int nowMs,
      {required List<int> steps, int answerIdx = 2, int graduatingIvl = 1}) {
    if (queue != 1) return;
    final nowSec = nowMs ~/ 1000;
    final stepIdx = left >> 8; // high byte

    if (answerIdx == 0) {
      // Again — reset to first step
      left = steps.length;
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
      queue = 2;
      type = 2;
      ivl = (graduatingIvl * 1.3).round();
      due = nowSec + (ivl * 86400);
      reps = 1;
      left = 0;
      return;
    }
    // Good (idx 2) — advance one step
    final next = stepIdx + 1;
    if (next >= steps.length) {
      // Graduate to review (Anki uses graduating interval directly)
      queue = 2;
      type = 2;
      ivl = graduatingIvl;
      due = nowSec + (ivl * 86400);
      reps = 1;
      left = 0;
    } else {
      left = (next << 8) | (steps.length - next);
      due = nowSec + (steps[next] * 60);
    }
  }

  /// Answer during review. [rating]: 1=again, 2=hard, 3=good, 4=easy.
  void answerReview(int nowMs,
      {int rating = 3,
      double hardMult = 1.2,
      int relearnSteps = 2,
      int relearnMin = 1}) {
    if (queue != 2 && queue != 3) return;
    final nowSec = nowMs ~/ 1000;
    if (rating == 1) {
      // Lapse
      lapses++;
      queue = 1;
      type = 3;
      left = relearnSteps;
      due = nowSec + (relearnMin * 60);
      factor = (factor - 200).clamp(1300, 9999);
      return;
    }
    reps++;
    switch (rating) {
      case 2:
        factor = (factor - 150).clamp(1300, 9999);
        ivl = (ivl * hardMult).round().clamp(1, 36500);
        break;
      case 3:
        ivl = _nextIvl(ivl, factor);
        break;
      case 4:
        factor = (factor + 150).clamp(1300, 9999);
        // Anki easyBonus: max(ivl * factor/1000 * 1.3, ivl * 1.3)
        final base = _nextIvl(ivl, factor);
        ivl = (base * 1.3).round().clamp(1, 36500);
        break;
    }
    due = nowSec + (ivl * 86400);
  }

  int _nextIvl(int cur, int fac) {
    if (cur == 0) return 1;
    return (cur * fac / 1000).round().clamp(1, 36500);
  }

  // ── serialization (for the col row JSON / in-memory) ─────

  Map<String, dynamic> toMap() => {
        'id': id,
        'nid': nid,
        'did': did,
        'ord': ord,
        'mod': mod,
        'usn': usn,
        'type': type,
        'queue': queue,
        'due': due,
        'ivl': ivl,
        'factor': factor,
        'reps': reps,
        'lapses': lapses,
        'left': left,
        'odue': odue,
        'odid': odid,
        'flags': flags,
        'data': data,
      };

  factory AnkiCard.fromMap(Map<String, dynamic> m) => AnkiCard(
        id: m['id'] as int,
        nid: m['nid'] as int,
        did: m['did'] as int,
        ord: m['ord'] as int? ?? 0,
        mod: m['mod'] as int? ?? 0,
        usn: m['usn'] as int? ?? -1,
        type: m['type'] as int? ?? 0,
        queue: m['queue'] as int? ?? 0,
        due: m['due'] as int? ?? 0,
        ivl: m['ivl'] as int? ?? 0,
        factor: m['factor'] as int? ?? 2500,
        reps: m['reps'] as int? ?? 0,
        lapses: m['lapses'] as int? ?? 0,
        left: m['left'] as int? ?? 0,
        odue: m['odue'] as int? ?? 0,
        odid: m['odid'] as int? ?? 0,
        flags: m['flags'] as int? ?? 0,
        data: m['data'] as String? ?? '',
      );

  static int _counter = 0;
  static int _nextId() {
    _counter++;
    return DateTime.now().microsecondsSinceEpoch + _counter;
  }

  @override
  String toString() => 'AnkiCard(id=$id, did=$did, type=$type, queue=$queue)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AnkiCard && id == other.id;
  @override
  int get hashCode => id.hashCode;
}
