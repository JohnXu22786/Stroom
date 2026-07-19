import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/collection.dart';
import '../models/card.dart';
import '../models/note.dart';
import '../models/deck.dart';
import '../models/model.dart';
import '../scheduler/scheduler.dart';
import '../utils/anki_storage_service.dart';

/// Provider for the AnkiStorageService.
final ankiStorageServiceProvider = Provider<AnkiStorageService>((ref) {
  return AnkiStorageService();
});

/// Provider for the AnkiScheduler.
final ankiSchedulerProvider = Provider<AnkiScheduler>((ref) {
  return AnkiScheduler();
});

/// Provider for the AnkiCollection state.
final ankiCollectionProvider =
    NotifierProvider<AnkiCollectionNotifier, AnkiCollection>(
  AnkiCollectionNotifier.new,
);

/// Notifier that manages the AnkiCollection.
class AnkiCollectionNotifier extends Notifier<AnkiCollection> {
  bool _modelsInitialized = false;

  @override
  AnkiCollection build() {
    _load();
    return AnkiCollection.createNew();
  }

  AnkiStorageService get _storage => ref.read(ankiStorageServiceProvider);
  AnkiScheduler get _scheduler => ref.read(ankiSchedulerProvider);

  /// Loads the collection from storage.
  Future<void> _load() async {
    final loaded = await _storage.loadCollection();
    if (loaded != null) {
      state = loaded;
    }
    _initializeDefaultModels();
  }

  /// Ensures at least the Basic model exists.
  void _initializeDefaultModels() {
    if (_modelsInitialized) return;
    _modelsInitialized = true;
    // Already have models? skip.
    if (state.models.isNotEmpty) return;
    state.addModel(AnkiModel.createBasic());
    _save();
  }

  /// Saves the current collection to storage (fire-and-forget:
  /// state changes are synchronous, persistence is async).
  void _save() {
    unawaited(_storage.saveCollection(state));
  }

  // --- Deck management ---

  /// Adds a new deck.
  AnkiDeck addDeck(String name, {String description = ''}) {
    final deck = state.addDeck(name, description: description);
    _save();
    state = AnkiCollection.fromJson(state.toJson());
    return deck;
  }

  /// Removes a deck and all its cards.
  void removeDeck(int deckId) {
    state.removeDeck(deckId);
    _save();
    state = AnkiCollection.fromJson(state.toJson());
  }

  /// Renames a deck.
  void renameDeck(int deckId, String newName) {
    state.renameDeck(deckId, newName);
    _save();
    state = AnkiCollection.fromJson(state.toJson());
  }

  // --- Note management ---

  /// Adds a new note (and optionally creates cards for it).
  int addNote(
    int modelId,
    List<String> fields, {
    List<String> tags = const [],
    int? deckId,
  }) {
    final note = AnkiNote.createNew(
      modelId: modelId,
      fields: fields,
      tags: tags,
    );
    state.addNote(note);

    // Create a card for this note (Basic model generates 1 card)
    if (deckId != null) {
      final card = AnkiCard.createNew(
        deckId: deckId,
        noteId: note.id,
        ordinal: 0,
      );
      state.addCard(card);
    }

    _save();
    state = AnkiCollection.fromJson(state.toJson());
    return note.id;
  }

  /// Removes a note and its cards.
  void removeNote(int noteId) {
    state.removeNote(noteId);
    _save();
    state = AnkiCollection.fromJson(state.toJson());
  }

  // --- Card management ---

  /// Adds a card to the collection.
  void addCard(AnkiCard card) {
    state.addCard(card);
    _save();
    state = AnkiCollection.fromJson(state.toJson());
  }

  /// Updates a card.
  void updateCard(AnkiCard card) {
    state.updateCard(card);
    _save();
    state = AnkiCollection.fromJson(state.toJson());
  }

  /// Answers a card with the given rating.
  void answerCard(int cardId, int answerRating, {int reviewDuration = 0}) {
    _scheduler.answerCard(state, cardId, DateTime.now(),
        answerRating: answerRating, reviewDuration: reviewDuration);
    _save();
    state = AnkiCollection.fromJson(state.toJson());
  }

  /// Gets statistics for a deck.
  DeckStats getDeckStats(int deckId) {
    return state.getDeckStats(deckId);
  }

  /// Gets the next card to study in a deck.
  AnkiCard? getNextCard(int deckId) {
    return _scheduler.getNextCard(state, deckId);
  }
}

/// Provider that exposes deck-level statistics.
final ankiDeckStatsProvider = Provider.family<DeckStats, int>((ref, deckId) {
  final collection = ref.watch(ankiCollectionProvider);
  return collection.getDeckStats(deckId);
});

/// Provider that lists all deck names and IDs.
final ankiDeckListProvider = Provider<List<AnkiDeck>>((ref) {
  final collection = ref.watch(ankiCollectionProvider);
  return collection.decks.values.toList()
    ..sort((a, b) => a.name.compareTo(b.name));
});

/// Provider that returns all cards for a given deck.
final ankiCardsByDeckProvider =
    Provider.family<List<AnkiCard>, int>((ref, deckId) {
  final collection = ref.watch(ankiCollectionProvider);
  return collection.getCardsByDeck(deckId);
});

/// Provider that returns a single card by ID.
final ankiCardByIdProvider = Provider.family<AnkiCard?, int>((ref, cardId) {
  final collection = ref.watch(ankiCollectionProvider);
  return collection.getCard(cardId);
});

/// Provider that returns a single deck by ID.
final ankiDeckByIdProvider = Provider.family<AnkiDeck?, int>((ref, deckId) {
  final collection = ref.watch(ankiCollectionProvider);
  return collection.getDeck(deckId);
});
