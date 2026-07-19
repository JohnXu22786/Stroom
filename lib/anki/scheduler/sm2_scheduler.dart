import '../models/card.dart';

/// Implements Anki's SM-2-based spaced repetition scheduling algorithm.
///
/// This scheduler handles:
/// - Learning step progression (in minutes)
/// - Review interval calculation based on ease factor
/// - Ease factor adjustments based on answer quality
/// - Lapse handling (when cards are forgotten)
///
/// Key differences from pure SM-2 (as implemented in Anki):
/// - Uses 4 answer ratings: Again(1), Hard(2), Good(3), Easy(4) instead of 0-5
/// - Learning steps before card graduates to review
/// - Ease factor is stored as integer (2500 = 250%)
/// - Minimum ease factor is 130% (1300)
class SM2Scheduler {
  /// Learning steps in minutes (default: 1 min, 10 min)
  final List<int> learningSteps;

  /// Graduating interval (days) - first interval after graduating from learning
  final int graduatingInterval;

  /// Easy interval (days) - bonus for answering Easy during learning
  final int easyInterval;

  /// Hard interval multiplier (for review cards)
  final double hardMultiplier;

  /// New interval multiplier when card is lapsed (Again on review)
  final double lapseIntervalMultiplier;

  /// Minimum ease factor (130%)
  static const int minEaseFactor = 1300;

  /// Maximum ease factor
  static const int maxEaseFactor = 9999;

  /// Maximum interval (100 years in days)
  static const int maxInterval = 36500;

  SM2Scheduler({
    this.learningSteps = const [1, 10],
    this.graduatingInterval = 1,
    this.easyInterval = 4,
    this.hardMultiplier = 1.2,
    this.lapseIntervalMultiplier = 0.0,
  });

  /// Computes the next review interval for a review card.
  ///
  /// Based on Anki's SM-2 algorithm:
  /// - If reps == 0: return graduating interval (1 day)
  /// - If reps == 1: return 6 days
  /// - Otherwise: interval = current_interval * ease_factor / 1000
  int nextReviewInterval({
    required int easeFactor,
    required int currentInterval,
    required int reps,
  }) {
    if (currentInterval == 0 || reps == 0) {
      return graduatingInterval.clamp(1, maxInterval);
    }
    if (reps == 1) {
      return 6.clamp(1, maxInterval);
    }
    final next = (currentInterval * easeFactor / 1000).round();
    return next.clamp(1, maxInterval);
  }

  /// Adjusts the ease factor based on the answer rating.
  ///
  /// - Again (1): decrease by 200 (20 percentage points)
  /// - Hard (2): decrease by 150 (15 percentage points)
  /// - Good (3): no change
  /// - Easy (4): increase by 150 (15 percentage points)
  int adjustEaseFactor(int currentEaseFactor, int answerRating) {
    int delta;
    switch (answerRating) {
      case 1: // Again
        delta = -200;
        break;
      case 2: // Hard
        delta = -150;
        break;
      case 3: // Good
        delta = 0;
        break;
      case 4: // Easy
        delta = 150;
        break;
      default:
        delta = 0;
    }
    return (currentEaseFactor + delta).clamp(minEaseFactor, maxEaseFactor);
  }

  /// Computes the due date (epoch seconds) for a card.
  int computeDueDate(DateTime now, int intervalDays) {
    final dueDateTime = now.add(Duration(days: intervalDays));
    return dueDateTime.millisecondsSinceEpoch ~/ 1000;
  }

  /// Starts learning for a new card, placing it in the learning queue.
  void scheduleLearning(AnkiCard card, int nowMs) {
    card.startLearning(nowMs, steps: learningSteps);
  }

  /// Schedules a review card after answering.
  /// Passes scheduler configuration to the card's answerReview method.
  void scheduleReview(AnkiCard card, int nowMs, {required int rating}) {
    card.answerReview(nowMs,
        rating: rating,
        hardMult: hardMultiplier,
        relearnSteps: learningSteps.length,
        relearnMin: learningSteps.isNotEmpty ? learningSteps[0] : 1);
  }

  /// Renders a card template by replacing {{FieldName}} with field values.
  ///
  /// [template] is the template string (e.g., "{{Front}}").
  /// [fieldValues] is a map of field name -> field value.
  String renderTemplate(String template, Map<String, String> fieldValues) {
    String result = template;
    for (final entry in fieldValues.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }
}
