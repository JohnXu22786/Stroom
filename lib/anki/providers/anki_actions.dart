import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/col_dao.dart';
import '../database/card_dao.dart';
import '../database/note_dao.dart';
import '../models/card.dart';
import '../models/note.dart';
import '../models/deck.dart';
import '../models/model.dart';
import '../scheduler/scheduler.dart';
import 'anki_provider.dart';

/// Provides mutation methods for the Anki collection.
///
/// Call these from UI callbacks; they persist to SQLite and bump
/// [ankiRefreshProvider] to trigger provider rebuilds.
final ankiActionsProvider = Provider<AnkiActions>((ref) {
  return AnkiActions(ref);
});

class AnkiActions {
  final Ref _ref;
  AnkiActions(this._ref);

  Future<ColDao> get _col => _ref.read(ankiColDaoProvider.future);
  Future<CardDao> get _cardDao => _ref.read(ankiCardDaoProvider.future);
  Future<NoteDao> get _noteDao => _ref.read(ankiNoteDaoProvider.future);
  AnkiScheduler get _scheduler => _ref.read(ankiSchedulerProvider);

  void _refresh() {
    _ref.read(ankiRefreshProvider.notifier).refresh();
  }

  // ── Decks ──────────────────────────────────────────────

  Future<AnkiDeck> addDeck(String name, {String desc = ''}) async {
    final col = await _col;
    final deck = col.addDeck(name, desc: desc);
    await col.save();
    _refresh();
    return deck;
  }

  Future<void> removeDeck(int did) async {
    final col = await _col;
    col.removeDeck(did);
    await col.save();
    _refresh();
  }

  Future<void> renameDeck(int did, String name) async {
    final col = await _col;
    col.renameDeck(did, name);
    await col.save();
    _refresh();
  }

  // ── Notes / Cards ──────────────────────────────────────

  Future<int> addCard(int did, String front, String back) async {
    final col = await _col;
    final models = col.modelList;
    final mid = models.isNotEmpty ? models.first.id : 1;
    if (!col.modelList.any((m) => m.id == mid)) {
      col.addModel(AnkiModel.createBasic());
    }
    final flds = [front, back].join(String.fromCharCode(0x1f));
    final note = AnkiNote.createNew(mid: mid, flds: flds);
    await col.notes.insert(note);
    final card = AnkiCard.createNew(nid: note.id, did: did);
    await col.cards.insert(card);
    await col.save();
    _refresh();
    return note.id;
  }

  Future<void> removeNote(int nid) async {
    final noteDao = await _noteDao;
    final cardDao = await _cardDao;
    final cards = await cardDao.listByNote(nid);
    for (final c in cards) {
      await cardDao.delete(c.id);
    }
    await noteDao.delete(nid);
    _refresh();
  }

  // ── Study ──────────────────────────────────────────────

  Future<void> answerCard(int cid, int rating, {int duration = 0}) async {
    final col = await _col;
    final cardDao = await _cardDao;
    await _scheduler.answerCard(col, cardDao, cid, rating,
        reviewDuration: duration);
    _refresh();
  }

  Future<AnkiCard?> getNextCard(int did) async {
    final col = await _col;
    final cardDao = await _cardDao;
    return _scheduler.getNextCard(col, cardDao, did);
  }
}
