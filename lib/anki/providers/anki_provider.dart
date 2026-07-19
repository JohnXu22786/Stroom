import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/anki_database.dart';
import '../database/col_dao.dart';
import '../database/card_dao.dart';
import '../database/note_dao.dart';
import '../models/card.dart';
import '../models/deck.dart';
import '../models/model.dart';
import '../scheduler/scheduler.dart';

/// ── Database ─────────────────────────────────────────────

/// Opens the SQLite database once.
final ankiDatabaseProvider = FutureProvider<AnkiDatabase>((ref) async {
  final db = AnkiDatabase();
  await db.open();
  return db;
});

/// Derives ColDao from the database.
final ankiColDaoProvider = FutureProvider<ColDao>((ref) async {
  final db = await ref.watch(ankiDatabaseProvider.future);
  await db.col.load();
  return db.col;
});

/// Derives CardDao.
final ankiCardDaoProvider = FutureProvider<CardDao>((ref) async {
  final db = await ref.watch(ankiDatabaseProvider.future);
  return db.cards;
});

/// Derives NoteDao.
final ankiNoteDaoProvider = FutureProvider<NoteDao>((ref) async {
  final db = await ref.watch(ankiDatabaseProvider.future);
  return db.notes;
});

/// Scheduler.
final ankiSchedulerProvider = Provider<AnkiScheduler>((ref) {
  return AnkiScheduler();
});

/// ── Deck list ────────────────────────────────────────────

/// Watches ColDao and returns the deck list.  Rebuilds whenever
/// any deck-mutating notifier method is called (see [ankiRefreshProvider]).
final ankiDeckListProvider = FutureProvider<List<AnkiDeck>>((ref) async {
  ref.watch(ankiRefreshProvider); // trigger rebuild
  final col = await ref.watch(ankiColDaoProvider.future);
  return col.deckList;
});

/// A simple counter bumped to force deck-list refresh.
final ankiRefreshProvider = NotifierProvider<AnkiRefreshNotifier, int>(
  AnkiRefreshNotifier.new,
);

class AnkiRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void refresh() => state++;
}

/// ── Deck stats ───────────────────────────────────────────

final ankiDeckStatsProvider =
    FutureProvider.family<DeckStats, int>((ref, did) async {
  final col = await ref.watch(ankiColDaoProvider.future);
  return col.getDeckStats(did);
});

/// ── Cards by deck ────────────────────────────────────────

final ankiCardsByDeckProvider =
    FutureProvider.family<List<AnkiCard>, int>((ref, did) async {
  final dao = await ref.watch(ankiCardDaoProvider.future);
  return dao.listByDeck(did);
});

/// ── Single deck ──────────────────────────────────────────

final ankiDeckByIdProvider =
    FutureProvider.family<AnkiDeck?, int>((ref, did) async {
  final col = await ref.watch(ankiColDaoProvider.future);
  return col.getDeck(did);
});

/// ── Single card ──────────────────────────────────────────

final ankiCardByIdProvider =
    FutureProvider.family<AnkiCard?, int>((ref, cid) async {
  final dao = await ref.watch(ankiCardDaoProvider.future);
  return dao.get(cid);
});

/// ── Model list ───────────────────────────────────────────

final ankiModelListProvider = FutureProvider<List<AnkiModel>>((ref) async {
  final col = await ref.watch(ankiColDaoProvider.future);
  return col.modelList;
});
