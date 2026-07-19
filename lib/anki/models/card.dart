/// Represents the type of a card in the Anki system.
///
/// Maps to Anki's internal `card.type` field:
/// - `newCard` (0): A card that has never been reviewed
/// - `learningCard` (1): A card currently in the learning phase
/// - `reviewCard` (2): A card that has graduated to review phase
/// - `relearningCard` (3): A review card that was forgotten and is being relearned
enum CardType {
  newCard(0),
  learningCard(1),
  reviewCard(2),
  relearningCard(3);

  final int value;
  const CardType(this.value);

  static CardType fromValue(int value) {
    return CardType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => CardType.newCard,
    );
  }
}

/// Represents the queue state of a card.
///
/// Maps to Anki's internal `card.queue` field:
/// - `newQueue` (0): New cards waiting to be reviewed
/// - `learningQueue` (1): Cards in learning (due within minutes/hours)
/// - `reviewQueue` (2): Review cards due for review
/// - `dayLearningQueue` (3): Learning cards that crossed day boundary
/// - `suspended` (-1): Manually suspended cards
/// - `userBuried` (-2): Cards buried by user
/// - `schedBuried` (-3): Cards buried by scheduler
enum CardQueue {
  newQueue(0),
  learningQueue(1),
  reviewQueue(2),
  dayLearningQueue(3),
  suspended(-1),
  userBuried(-2),
  schedBuried(-3);

  final int value;
  const CardQueue(this.value);

  static CardQueue fromValue(int value) {
    return CardQueue.values.firstWhere(
      (q) => q.value == value,
      orElse: () => CardQueue.newQueue,
    );
  }
}

/// Represents a single flashcard in the Anki system.
///
/// Each card belongs to a deck and is generated from a note.
/// The card tracks its scheduling state (interval, ease factor, etc.)
/// and its current position in the learning/review process.
class AnkiCard {
  /// Unique card ID (millisecond timestamp at creation)
  int id;

  /// Note ID that this card was generated from
  int noteId;

  /// Deck ID that this card belongs to
  int deckId;

  /// Ordinal of this card within its note (for multiple templates)
  int ordinal;

  /// Last modification time (epoch seconds)
  int modified;

  /// Update sequence number (used for syncing, -1 = local changes)
  int usn;

  /// Card type (new, learning, review, relearning)
  CardType type;

  /// Queue state (new, learning, review, suspended, buried)
  CardQueue queue;

  /// Due date/position (always epoch seconds):
  /// - For new cards: due position in new card queue
  /// - For learning cards: due timestamp (epoch seconds)
  /// - For review cards: due day (epoch seconds)
  int due;

  /// Interval (days) - the space between reviews
  int interval;

  /// Ease factor (in percentage * 10, e.g. 2500 = 250%)
  int easeFactor;

  /// Number of times card has been reviewed correctly
  int reps;

  /// Number of times card was forgotten/lapsed
  int lapses;

  /// Remaining learning steps (encoded: low byte = steps left, high byte = step index)
  int left;

  /// Original due date (used when card is in filtered deck)
  int originalDue;

  /// Original deck ID (used when card is in filtered deck)
  int originalDeckId;

  /// Flags (0-7, user-assigned)
  int flags;

  /// Extra data (JSON string, for add-ons)
  String data;

  AnkiCard({
    required this.id,
    required this.noteId,
    required this.deckId,
    this.ordinal = 0,
    this.modified = 0,
    this.usn = -1,
    this.type = CardType.newCard,
    this.queue = CardQueue.newQueue,
    this.due = 0,
    this.interval = 0,
    this.easeFactor = 2500,
    this.reps = 0,
    this.lapses = 0,
    this.left = 0,
    this.originalDue = 0,
    this.originalDeckId = 0,
    this.flags = 0,
    this.data = '',
  });

  /// Creates a new card with default values and a unique ID.
  factory AnkiCard.createNew({
    required int deckId,
    required int noteId,
    int ordinal = 0,
  }) {
    _idCounter++;
    final now = DateTime.now().microsecondsSinceEpoch;
    return AnkiCard(
      id: now + _idCounter,
      noteId: noteId,
      deckId: deckId,
      ordinal: ordinal,
      modified: now ~/ 1000,
      easeFactor: 2500,
    );
  }

  static int _idCounter = 0;

  /// Whether this card is due for review at the given timestamp.
  bool isDue(int currentTimestampSec) {
    if (queue == CardQueue.suspended ||
        queue == CardQueue.userBuried ||
        queue == CardQueue.schedBuried) {
      return false;
    }
    if (queue == CardQueue.newQueue) return true; // New cards are always "due"
    return due <= currentTimestampSec;
  }

  /// Starts the learning process for this new card.
  /// [nowMs] current time in milliseconds. [learningSteps] in minutes.
  void startLearning(int nowMs, {List<int> learningSteps = const [1, 10]}) {
    if (queue != CardQueue.newQueue) return;

    queue = CardQueue.learningQueue;
    type = CardType.learningCard;
    left = learningSteps.length;
    // Store due as epoch seconds
    due = (nowMs / 1000).round() + (learningSteps[0] * 60);
  }

  /// Answers a card during learning phase.
  /// [learningSteps] in minutes.
  /// [answerIdx]: 0=Again, 1=Hard, 2=Good, 3=Easy (maps to Anki ratings -1 for learning)
  /// [graduatingInterval] is the first review interval in days after graduating.
  void answerLearning(int nowMs,
      {required List<int> learningSteps,
      int answerIdx = 1,
      int graduatingInterval = 1}) {
    if (queue != CardQueue.learningQueue) return;

    final currentStep = left >> 8; // High byte = current step index
    final nowSec = (nowMs / 1000).round();

    if (answerIdx == 0) {
      // Again - reset learning steps to first step
      left = learningSteps.length;
      due = nowSec + (learningSteps[0] * 60);
      return;
    }

    if (answerIdx == 1) {
      // Hard - repeat the current step
      final stepMin = currentStep < learningSteps.length
          ? learningSteps[currentStep]
          : learningSteps.last;
      due = nowSec + (stepMin * 60);
      // left unchanged - we don't advance
      return;
    }

    if (answerIdx == 3) {
      // Easy - graduate immediately with a bonus interval
      queue = CardQueue.reviewQueue;
      type = CardType.reviewCard;
      interval =
          graduatingInterval * 2; // Double the graduating interval for Easy
      due = nowSec + (interval * 86400);
      reps = 1;
      left = 0;
      return;
    }

    // Good (answerIdx == 2) - advance to next step
    final nextStep = currentStep + 1;
    if (nextStep >= learningSteps.length) {
      // Graduate to review
      queue = CardQueue.reviewQueue;
      type = CardType.reviewCard;
      interval = graduatingInterval;
      due = nowSec + (interval * 86400);
      reps = 1;
      left = 0;
    } else {
      // Advance to next learning step
      left = (nextStep << 8) | (learningSteps.length - nextStep);
      due = nowSec + (learningSteps[nextStep] * 60);
    }
  }

  /// Answers a card during review phase.
  /// [answerRating]: 1=Again, 2=Hard, 3=Good, 4=Easy
  /// [hardMultiplier] is the multiplier for Hard answer interval (default 1.2).
  /// [relearningSteps] is the number of relearning steps after a lapse (default 2).
  /// [relearningStepMinutes] is the duration of the first relearning step in minutes (default 1).
  void answerReview(int nowMs,
      {int answerRating = 3,
      double hardMultiplier = 1.2,
      int relearningSteps = 2,
      int relearningStepMinutes = 1}) {
    if (queue != CardQueue.reviewQueue && queue != CardQueue.dayLearningQueue) {
      return;
    }

    final nowSec = (nowMs / 1000).round();

    if (answerRating == 1) {
      // Again - card was forgotten
      lapses++;
      // Reset to learning/relearning
      queue = CardQueue.learningQueue;
      type = CardType.relearningCard;
      left = relearningSteps;
      due = nowSec + (relearningStepMinutes * 60);
      // Decrease ease factor by 20 percentage points
      easeFactor = (easeFactor - 200).clamp(1300, 9999);
      return;
    }

    // Successful review
    reps++;

    // Adjust ease factor
    switch (answerRating) {
      case 2: // Hard
        easeFactor = (easeFactor - 150).clamp(1300, 9999);
        interval =
            (_applyHardInterval(interval, hardMultiplier)).clamp(1, 36500);
        break;
      case 3: // Good
        interval = _nextInterval(interval, easeFactor);
        break;
      case 4: // Easy
        easeFactor = (easeFactor + 150).clamp(1300, 9999);
        interval = _nextInterval(interval, easeFactor) * 2;
        break;
    }

    due = nowSec + (interval * 86400);
  }

  /// Applies the hard interval multiplier.
  int _applyHardInterval(int currentInterval, double hardMultiplier) {
    return (currentInterval * hardMultiplier).round();
  }

  /// Calculates the next review interval based on current interval and ease factor.
  int _nextInterval(int currentInterval, int ease) {
    if (currentInterval == 0) return 1;
    final next = (currentInterval * ease / 1000).round();
    return next.clamp(1, 36500);
  }

  // --- JSON Serialization ---

  Map<String, dynamic> toJson() => {
        'id': id,
        'noteId': noteId,
        'deckId': deckId,
        'ordinal': ordinal,
        'modified': modified,
        'usn': usn,
        'type': type.value,
        'queue': queue.value,
        'due': due,
        'interval': interval,
        'easeFactor': easeFactor,
        'reps': reps,
        'lapses': lapses,
        'left': left,
        'originalDue': originalDue,
        'originalDeckId': originalDeckId,
        'flags': flags,
        'data': data,
      };

  factory AnkiCard.fromJson(Map<String, dynamic> json) => AnkiCard(
        id: json['id'] as int,
        noteId: json['noteId'] as int,
        deckId: json['deckId'] as int,
        ordinal: json['ordinal'] as int? ?? 0,
        modified: json['modified'] as int? ?? 0,
        usn: json['usn'] as int? ?? -1,
        type: CardType.fromValue(json['type'] as int? ?? 0),
        queue: CardQueue.fromValue(json['queue'] as int? ?? 0),
        due: json['due'] as int? ?? 0,
        interval: json['interval'] as int? ?? 0,
        easeFactor: json['easeFactor'] as int? ?? 2500,
        reps: json['reps'] as int? ?? 0,
        lapses: json['lapses'] as int? ?? 0,
        left: json['left'] as int? ?? 0,
        originalDue: json['originalDue'] as int? ?? 0,
        originalDeckId: json['originalDeckId'] as int? ?? 0,
        flags: json['flags'] as int? ?? 0,
        data: json['data'] as String? ?? '',
      );

  @override
  String toString() =>
      'AnkiCard(id=$id, deckId=$deckId, type=$type, queue=$queue)';
}
