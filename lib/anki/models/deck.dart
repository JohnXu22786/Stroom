/// Represents a deck in the Anki system.
///
/// Decks are containers for cards. They can be nested using `::` as a separator
/// (e.g., "Parent::Child"). Each deck has its own configuration and statistics.
class AnkiDeck {
  /// Unique deck ID
  int id;

  /// Deck name (may include :: for subdecks)
  String name;

  /// Deck description (may include HTML)
  String description;

  /// Last modification time (epoch seconds)
  int modified;

  /// Update sequence number
  int usn;

  /// Whether this is a dynamic (filtered) deck
  bool isDynamic;

  /// Configuration preset ID
  int configId;

  /// The time when the deck was created (epoch seconds)
  int creationDate;

  AnkiDeck({
    required this.id,
    required this.name,
    this.description = '',
    this.modified = 0,
    this.usn = -1,
    this.isDynamic = false,
    this.configId = 1,
    this.creationDate = 0,
  });

  /// Creates a new deck with a unique ID (guaranteed unique via a static counter).
  factory AnkiDeck.createNew({
    required String name,
    String description = '',
  }) {
    // Combine timestamp with a counter for guaranteed uniqueness
    _idCounter++;
    final now = DateTime.now().microsecondsSinceEpoch;
    final uniqueId = now + _idCounter;
    return AnkiDeck(
      id: uniqueId,
      name: name,
      description: description,
      modified: now ~/ 1000,
      creationDate: now ~/ 1000,
    );
  }

  static int _idCounter = 0;

  /// Returns the parent deck name, or null if this is a top-level deck.
  String? get parentName {
    final idx = name.lastIndexOf('::');
    if (idx < 0) return null;
    return name.substring(0, idx);
  }

  /// Returns the child portion of a nested deck name.
  String get childName {
    final idx = name.lastIndexOf('::');
    if (idx < 0) return name;
    return name.substring(idx + 2);
  }

  /// Returns true if this deck is the parent of the given deck name.
  bool isParentOf(String childDeckName) {
    return childDeckName.startsWith('$name::');
  }

  // --- JSON Serialization ---

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'modified': modified,
    'usn': usn,
    'isDynamic': isDynamic,
    'configId': configId,
    'creationDate': creationDate,
  };

  factory AnkiDeck.fromJson(Map<String, dynamic> json) => AnkiDeck(
    id: json['id'] as int,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    modified: json['modified'] as int? ?? 0,
    usn: json['usn'] as int? ?? -1,
    isDynamic: json['isDynamic'] as bool? ?? false,
    configId: json['configId'] as int? ?? 1,
    creationDate: json['creationDate'] as int? ?? 0,
  );

  @override
  String toString() => 'AnkiDeck(id=$id, name=$name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnkiDeck && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
