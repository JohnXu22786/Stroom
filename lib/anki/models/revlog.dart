/// Represents a single review log entry in the Anki system.
///
/// Each time a card is reviewed, an entry is added to the review log.
/// This data is used for statistics and algorithm optimization.
class AnkiRevlog {
  /// Unique log entry ID
  int id;

  /// Card ID that was reviewed
  int cardId;

  /// Time of review (epoch seconds)
  int reviewTime;

  /// Rating: 1=Again, 2=Hard, 3=Good, 4=Easy
  int rating;

  /// New interval after review (days)
  int interval;

  /// Previous interval before review (days)
  int lastInterval;

  /// Ease factor after review
  int easeFactor;

  /// How long the review took (seconds)
  int reviewDuration;

  AnkiRevlog({
    int? id,
    required this.cardId,
    required this.reviewTime,
    required this.rating,
    required this.interval,
    required this.lastInterval,
    required this.easeFactor,
    this.reviewDuration = 0,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch;

  // --- JSON Serialization ---

  Map<String, dynamic> toJson() => {
    'id': id,
    'cardId': cardId,
    'reviewTime': reviewTime,
    'rating': rating,
    'interval': interval,
    'lastInterval': lastInterval,
    'easeFactor': easeFactor,
    'reviewDuration': reviewDuration,
  };

  factory AnkiRevlog.fromJson(Map<String, dynamic> json) => AnkiRevlog(
    id: json['id'] as int? ?? DateTime.now().microsecondsSinceEpoch,
    cardId: json['cardId'] as int,
    reviewTime: json['reviewTime'] as int,
    rating: json['rating'] as int,
    interval: json['interval'] as int,
    lastInterval: json['lastInterval'] as int,
    easeFactor: json['easeFactor'] as int,
    reviewDuration: json['reviewDuration'] as int? ?? 0,
  );

  @override
  String toString() =>
      'AnkiRevlog(cardId=$cardId, rating=$rating, interval=$interval)';
}
