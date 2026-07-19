import 'card.dart';
import 'note.dart';
import 'deck.dart';
import 'revlog.dart';
import 'model.dart';

/// Statistics for a single deck.
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

/// Represents the entire Anki collection.
///
/// A collection is the top-level container that holds all decks, notes, cards,
/// review logs, and configuration. It is persisted as a JSON/serialized object.
class AnkiCollection {
  /// Collection ID (always 1 for the default collection)
  int id;

  /// Creation date (epoch seconds)
  int creationDate;

  /// Last modification time (epoch milliseconds)
  int modified;

  /// Schema modification time
  int schemaModified;

  /// Schema version
  int version;

  /// Whether a full sync is required
  int dirty;

  /// Update sequence number
  int usn;

  /// Last sync time
  int lastSync;

  /// Next available card ID (auto-increment)
  int nextCardId;

  /// Next available note ID (auto-increment)
  int nextNoteId;

  /// Next available deck ID (auto-increment)
  int nextDeckId;

  /// All decks in the collection (map: deckId -> deck)
  Map<int, AnkiDeck> decks;

  /// All notes in the collection (map: noteId -> note)
  Map<int, AnkiNote> notes;

  /// All cards in the collection (map: cardId -> card)
  Map<int, AnkiCard> cards;

  /// All review log entries
  List<AnkiRevlog> revlog;

  /// All models (note types)
  Map<int, AnkiModel> models;

  /// Configuration data (JSON string)
  String conf;

  /// Tags cache (for autocomplete)
  String tags;

  AnkiCollection({
    this.id = 1,
    int? creationDate,
    this.modified = 0,
    this.schemaModified = 0,
    this.version = 11,
    this.dirty = 0,
    this.usn = 0,
    this.lastSync = 0,
    int? nextCardId,
    int? nextNoteId,
    int? nextDeckId,
    Map<int, AnkiDeck>? decks,
    Map<int, AnkiNote>? notes,
    Map<int, AnkiCard>? cards,
    List<AnkiRevlog>? revlog,
    Map<int, AnkiModel>? models,
    this.conf = '{}',
    this.tags = '',
  })  : creationDate =
            creationDate ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        nextCardId = nextCardId ?? DateTime.now().microsecondsSinceEpoch,
        nextNoteId = nextNoteId ?? DateTime.now().microsecondsSinceEpoch,
        nextDeckId = nextDeckId ?? DateTime.now().microsecondsSinceEpoch,
        decks = decks ?? {},
        notes = notes ?? {},
        cards = cards ?? {},
        revlog = revlog ?? [],
        models = models ?? {};

  /// Creates a new empty collection.
  factory AnkiCollection.createNew() {
    return AnkiCollection();
  }

  // --- Model operations ---

  /// Adds a model (note type) to the collection.
  void addModel(AnkiModel model) {
    models[model.id] = model;
    modified = DateTime.now().millisecondsSinceEpoch;
  }

  /// Returns a model by ID.
  AnkiModel? getModel(int modelId) => models[modelId];

  // --- Deck operations ---

  /// Adds a new deck to the collection.
  AnkiDeck addDeck(String name, {String description = ''}) {
    final existing = decks.values.where((d) => d.name == name).toList();
    if (existing.isNotEmpty) {
      return existing.first;
    }
    final deck = AnkiDeck.createNew(name: name, description: description);
    decks[deck.id] = deck;
    modified = DateTime.now().millisecondsSinceEpoch;
    return deck;
  }

  /// Removes a deck and all its cards from the collection.
  void removeDeck(int deckId) {
    decks.remove(deckId);
    // Remove all cards in this deck
    cards.removeWhere((_, card) => card.deckId == deckId);
    // Remove all notes that no longer have any cards
    final usedNoteIds = cards.values.map((c) => c.noteId).toSet();
    notes.removeWhere((id, _) => !usedNoteIds.contains(id));
    modified = DateTime.now().millisecondsSinceEpoch;
  }

  /// Renames a deck.
  void renameDeck(int deckId, String newName) {
    final deck = decks[deckId];
    if (deck != null) {
      deck.name = newName;
      modified = DateTime.now().millisecondsSinceEpoch;
    }
  }

  /// Returns a deck by ID.
  AnkiDeck? getDeck(int deckId) => decks[deckId];

  /// Returns all deck names.
  List<String> get deckNames => decks.values.map((d) => d.name).toList();

  // --- Note operations ---

  /// Adds a note to the collection.
  int addNote(AnkiNote note) {
    notes[note.id] = note;
    modified = DateTime.now().millisecondsSinceEpoch;
    return note.id;
  }

  /// Removes a note and all its cards.
  void removeNote(int noteId) {
    notes.remove(noteId);
    cards.removeWhere((_, card) => card.noteId == noteId);
    modified = DateTime.now().millisecondsSinceEpoch;
  }

  /// Returns a note by ID.
  AnkiNote? getNote(int noteId) => notes[noteId];

  /// Gets all notes for a given model.
  List<AnkiNote> getNotesByModel(int modelId) {
    return notes.values.where((n) => n.modelId == modelId).toList();
  }

  // --- Card operations ---

  /// Adds a card to the collection.
  int addCard(AnkiCard card) {
    cards[card.id] = card;
    modified = DateTime.now().millisecondsSinceEpoch;
    return card.id;
  }

  /// Updates a card in the collection.
  void updateCard(AnkiCard card) {
    if (cards.containsKey(card.id)) {
      cards[card.id] = card;
      modified = DateTime.now().millisecondsSinceEpoch;
    }
  }

  /// Removes a card from the collection.
  void removeCard(int cardId) {
    cards.remove(cardId);
    modified = DateTime.now().millisecondsSinceEpoch;
  }

  /// Returns a card by ID.
  AnkiCard? getCard(int cardId) => cards[cardId];

  /// Gets all cards in a specific deck.
  List<AnkiCard> getCardsByDeck(int deckId) {
    return cards.values.where((c) => c.deckId == deckId).toList();
  }

  /// Gets all due cards in a deck.
  /// [nowSec] is the current time in epoch seconds. Defaults to DateTime.now().
  List<AnkiCard> getDueCards(int deckId, {int? nowSec}) {
    final now = nowSec ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return cards.values
        .where((c) => c.deckId == deckId && c.isDue(now))
        .toList();
  }

  // --- Review log ---

  /// Adds a review log entry.
  void addRevlogEntry(AnkiRevlog entry) {
    revlog.add(entry);
  }

  /// Gets review log entries for a specific card.
  List<AnkiRevlog> getRevlogForCard(int cardId) {
    return revlog.where((r) => r.cardId == cardId).toList();
  }

  // --- Statistics ---

  /// Gets statistics for a specific deck.
  DeckStats getDeckStats(int deckId) {
    final deckCards = getCardsByDeck(deckId);
    final deck = decks[deckId];

    int newCount = 0;
    int learningCount = 0;
    int reviewCount = 0;

    for (final card in deckCards) {
      switch (card.queue) {
        case CardQueue.newQueue:
          newCount++;
          break;
        case CardQueue.learningQueue:
        case CardQueue.dayLearningQueue:
          learningCount++;
          break;
        case CardQueue.reviewQueue:
          if (card.type == CardType.relearningCard) {
            learningCount++;
          } else {
            reviewCount++;
          }
          break;
        case CardQueue.suspended:
        case CardQueue.userBuried:
        case CardQueue.schedBuried:
          break;
      }
    }

    return DeckStats(
      deckName: deck?.name ?? 'Unknown',
      newCount: newCount,
      learningCount: learningCount,
      reviewCount: reviewCount,
      totalCount: deckCards.length,
    );
  }

  // --- JSON Serialization ---

  Map<String, dynamic> toJson() => {
        'id': id,
        'creationDate': creationDate,
        'modified': modified,
        'schemaModified': schemaModified,
        'version': version,
        'dirty': dirty,
        'usn': usn,
        'lastSync': lastSync,
        'nextCardId': nextCardId,
        'nextNoteId': nextNoteId,
        'nextDeckId': nextDeckId,
        'conf': conf,
        'tags': tags,
        'models': models.values.map((m) => m.toJson()).toList(),
        'decks': decks.values.map((d) => d.toJson()).toList(),
        'notes': notes.values.map((n) => n.toJson()).toList(),
        'cards': cards.values.map((c) => c.toJson()).toList(),
        'revlog': revlog.map((r) => r.toJson()).toList(),
      };

  factory AnkiCollection.fromJson(Map<String, dynamic> json) {
    final modelList = (json['models'] as List<dynamic>?)
            ?.map((m) => AnkiModel.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [];
    final deckList = (json['decks'] as List<dynamic>?)
            ?.map((d) => AnkiDeck.fromJson(d as Map<String, dynamic>))
            .toList() ??
        [];
    final noteList = (json['notes'] as List<dynamic>?)
            ?.map((n) => AnkiNote.fromJson(n as Map<String, dynamic>))
            .toList() ??
        [];
    final cardList = (json['cards'] as List<dynamic>?)
            ?.map((c) => AnkiCard.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [];
    final revlogList = (json['revlog'] as List<dynamic>?)
            ?.map((r) => AnkiRevlog.fromJson(r as Map<String, dynamic>))
            .toList() ??
        [];

    return AnkiCollection(
      id: json['id'] as int? ?? 1,
      creationDate: json['creationDate'] as int?,
      modified: json['modified'] as int? ?? 0,
      schemaModified: json['schemaModified'] as int? ?? 0,
      version: json['version'] as int? ?? 11,
      dirty: json['dirty'] as int? ?? 0,
      usn: json['usn'] as int? ?? 0,
      lastSync: json['lastSync'] as int? ?? 0,
      nextCardId: json['nextCardId'] as int?,
      nextNoteId: json['nextNoteId'] as int?,
      nextDeckId: json['nextDeckId'] as int?,
      models: {for (final m in modelList) m.id: m},
      decks: {for (final d in deckList) d.id: d},
      notes: {for (final n in noteList) n.id: n},
      cards: {for (final c in cardList) c.id: c},
      revlog: revlogList,
      conf: json['conf'] as String? ?? '{}',
      tags: json['tags'] as String? ?? '',
    );
  }
}
