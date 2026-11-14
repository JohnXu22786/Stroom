import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/stroom_menu_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../anki/providers/anki_provider.dart';
import '../anki/providers/anki_actions.dart';
import '../anki/models/deck.dart';
import '../anki/models/card.dart' as model;
import '../anki/models/note.dart';
import '../anki/models/model.dart';
import '../anki/pages/card_browser.dart';
import '../anki/pages/anki_stats_page.dart';
import 'anki_sync_page.dart';

import '../widgets/constrained_text.dart';

/// Main Anki page showing all decks and options.
class AnkiDroidPage extends ConsumerWidget {
  const AnkiDroidPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final decksAsync = ref.watch(ankiDeckListProvider);
    return Scaffold(
      appBar: AppBar(
        title: ConstrainedText(
          l10n.ankiPageTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: l10n.ankiStatsTooltip,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnkiStatsPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.ankiBrowseCardsTooltip,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnkiCardBrowser()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync),
            tooltip: l10n.ankiSyncTooltip,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnkiSyncSettingsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.ankiNewDeckTooltip,
            onPressed: () => _showCreateDeckDialog(context, ref),
          ),
        ],
      ),
      body: decksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            e is AnkiStatsUnsupportedException
                ? l10n.ankiWebDecksUnsupportedPlatform
                : l10n.ankiDeckLoadError(e.toString()),
          ),
        ),
        data: (decks) => decks.isEmpty
            ? _buildEmptyState(context, ref)
            : _buildDeckList(context, ref, decks),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories,
              size: 64,
              color: cs.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.ankiEmptyDecksTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.ankiEmptyDecksDescription,
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: ConstrainedText(
                l10n.ankiNewDeckTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () => _showCreateDeckDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeckList(BuildContext context, WidgetRef ref, List<Deck> decks) {
    // Sort hierarchically: top-level first, then children nested under parents
    final sorted = List<Deck>.from(decks)
      ..sort((a, b) {
        final aParts = a.name.split('::');
        final bParts = b.name.split('::');
        for (int i = 0; i < aParts.length && i < bParts.length; i++) {
          final cmp = aParts[i].compareTo(bParts[i]);
          if (cmp != 0) return cmp;
        }
        return aParts.length.compareTo(bParts.length);
      });
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final deck = sorted[i];
        final depth = '::'.allMatches(deck.name).length;
        return Padding(
          padding: EdgeInsets.only(left: depth * 24.0),
          child: _DeckCard(
            deck: deck,
            deckId: deck.id,
            onTap: () => _startStudy(context, ref, deck.id),
            onAddCard: () => _showAddCardDialog(context, ref, deck.id),
            onRename: () => _showRenameDialog(context, ref, deck.id, deck.name),
            onDelete: () =>
                _confirmDeleteDeck(context, ref, deck.id, deck.name),
          ),
        );
      },
    );
  }

  void _showCreateDeckDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: ConstrainedText(
          l10n.ankiNewDeckTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.ankiDeckNameHint,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: ConstrainedText(
              l10n.actionCancel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FilledButton(
            onPressed: () {
              if (c.text.trim().isNotEmpty) {
                ref.read(ankiActionsProvider).addDeck(c.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: ConstrainedText(
              l10n.ankiCreateDeck,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    int did,
    String name,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final c = TextEditingController(text: name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: ConstrainedText(
          l10n.ankiRenameDeck,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: ConstrainedText(
              l10n.actionCancel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FilledButton(
            onPressed: () {
              if (c.text.trim().isNotEmpty) {
                ref.read(ankiActionsProvider).renameDeck(did, c.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: ConstrainedText(
              l10n.ankiConfirm,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDeck(
    BuildContext context,
    WidgetRef ref,
    int did,
    String name,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: ConstrainedText(
          l10n.ankiDeleteDeckTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: Text(l10n.ankiDeleteDeckConfirmation(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: ConstrainedText(
              l10n.actionCancel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              ref.read(ankiActionsProvider).removeDeck(did);
              Navigator.pop(ctx);
            },
            child: ConstrainedText(
              l10n.actionDelete,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _startStudy(BuildContext context, WidgetRef ref, int did) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AnkiStudyPage(deckId: did)),
    );
  }

  void _showAddCardDialog(BuildContext context, WidgetRef ref, int did) {
    final l10n = AppLocalizations.of(context)!;
    final fc = TextEditingController();
    final bc = TextEditingController();
    final tc = TextEditingController();
    int selectedModelId = 1;
    String hintText = AppLocalizations.of(context)!.ankiFrontQuestionHint;

    // Load models synchronously from the last known value.
    // If not ready, fall back to Basic model id 1.
    final models = ref.read(ankiModelListProvider).value ?? <Notetype>[];
    if (models.isNotEmpty) selectedModelId = models.first.id;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: ConstrainedText(
              AppLocalizations.of(ctx)!.ankiAddCardTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (models.isNotEmpty)
                  DropdownButtonFormField<int>(
                    dropdownColor: StroomMenuStyle.surface(context),
                    borderRadius: StroomMenuStyle.borderRadius,
                    isExpanded: true,
                    value: selectedModelId,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(ctx)!.ankiNoteTypeLabel,
                      border: OutlineInputBorder(),
                    ),
                    items: models
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.id,
                            child: ConstrainedText(
                              m.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setDialogState(() {
                        selectedModelId = v;
                        final m = models.firstWhere((x) => x.id == v);
                        hintText = m.name == 'Cloze'
                            ? AppLocalizations.of(ctx)!
                                  .ankiClozeTextHint('{{c1::答案}}')
                            : AppLocalizations.of(ctx)!.ankiFrontQuestionHint;
                      });
                    },
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: fc,
                  maxLines: 3,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: hintText,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bc,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(ctx)!.ankiBackExtraLabel,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tc,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(ctx)!.ankiTagsLabel,
                    border: OutlineInputBorder(),
                    hintText: AppLocalizations.of(ctx)!.ankiTagsHint,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: ConstrainedText(
                  l10n.actionCancel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              FilledButton(
                onPressed: () {
                  if (fc.text.trim().isNotEmpty && bc.text.trim().isNotEmpty) {
                    ref
                        .read(ankiActionsProvider)
                        .addCard(
                          did,
                          fc.text.trim(),
                          bc.text.trim(),
                          modelId: selectedModelId,
                          tags: tc.text.trim(),
                        );
                    Navigator.pop(ctx);
                  }
                },
                child: ConstrainedText(
                  AppLocalizations.of(ctx)!.ankiAdd,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Deck card ─────────────────────────────────────────────

class _DeckCard extends ConsumerWidget {
  final Deck deck;
  final int deckId;
  final VoidCallback onTap, onAddCard, onRename, onDelete;

  const _DeckCard({
    required this.deck,
    required this.deckId,
    required this.onTap,
    required this.onAddCard,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final statsAsync = ref.watch(ankiDeckStatsProvider(deckId));

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.auto_stories,
                  color: cs.onPrimaryContainer,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    statsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (s) => Row(
                        children: [
                          _StatChip(
                            count: s.newCount,
                            label: l10n.ankiStatNew,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 6),
                          _StatChip(
                            count: s.learningCount,
                            label: l10n.ankiStatLearning,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          _StatChip(
                            count: s.reviewCount,
                            label: l10n.ankiStatReview,
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
                onSelected: (v) => switch (v) {
                  'add' => onAddCard(),
                  'rename' => onRename(),
                  'delete' => onDelete(),
                  _ => null,
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'add',
                    child: ConstrainedText(
                      l10n.ankiAddCardAction,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'rename',
                    child: ConstrainedText(
                      l10n.ankiRenameAction,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: ConstrainedText(
                      l10n.ankiDeleteAction,
                      style: const TextStyle(color: Colors.red),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _StatChip({
    required this.count,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

// ── Study page ────────────────────────────────────────────

class AnkiStudyPage extends ConsumerStatefulWidget {
  final int deckId;
  const AnkiStudyPage({super.key, required this.deckId});

  @override
  ConsumerState<AnkiStudyPage> createState() => _AnkiStudyPageState();
}

class _AnkiStudyPageState extends ConsumerState<AnkiStudyPage> {
  model.Card? _current;
  Note? _note;
  bool _showAnswer = false;
  bool _studying = true;
  bool _whiteboardOn = false;
  final List<_DrawingStroke> _strokes = [];
  Color _penColor = Colors.orange;
  double _penWidth = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final card = await ref.read(ankiActionsProvider).getNextCard(widget.deckId);
    Note? note;
    if (card != null) {
      try {
        final dao = ref.read(ankiNoteDaoProvider).requireValue;
        note = await dao.get(card.note_id);
      } catch (_) {}
    }
    if (mounted)
      setState(() {
        _current = card;
        _note = note;
        _showAnswer = false;
        _studying = card != null;
      });
  }

  Future<void> _answer(int rating) async {
    if (_current == null) return;
    await ref
        .read(ankiActionsProvider)
        .answerCard(_current!.id, rating, duration: 3);
    await _load();
  }

  String _frontText(String noCardContent) {
    if (_note == null || _note!.fields.isEmpty) return noCardContent;
    return _note!.fields[0];
  }

  String _backText(String noCardContent) {
    if (_note == null || _note!.fields.length < 2) return noCardContent;
    return _note!.fields[1];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final deckAsync = ref.watch(ankiDeckByIdProvider(widget.deckId));

    return Scaffold(
      appBar: AppBar(
        title: deckAsync.when(
          data: (d) => Text(d?.name ?? l10n.ankiStudy),
          loading: () => Text(l10n.ankiStudy),
          error: (_, __) => Text(l10n.ankiStudy),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _whiteboardOn ? Icons.brush : Icons.brush_outlined,
              color: _whiteboardOn ? Colors.orange : null,
            ),
            tooltip: l10n.ankiWhiteboardTooltip,
            onPressed: () => setState(() {
              _whiteboardOn = !_whiteboardOn;
              if (!_whiteboardOn) _strokes.clear();
            }),
          ),
        ],
      ),
      body: _studying && _current != null
          ? Stack(
              children: [
                _buildContent(context, cs),
                if (_whiteboardOn) _buildWhiteboard(),
              ],
            )
          : _buildDone(context, cs),
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: _showAnswer ? 1.0 : 0.5,
            backgroundColor: cs.surfaceContainerHighest,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: cs.outlineVariant, width: 0.5),
                  ),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 300),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.ankiFrontLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _frontText(
                            AppLocalizations.of(context)!.ankiNoCardContent,
                          ),
                          style: const TextStyle(fontSize: 22),
                          textAlign: TextAlign.center,
                        ),
                        if (_showAnswer) ...[
                          const Divider(height: 32),
                          Text(
                            AppLocalizations.of(context)!.ankiBackLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.tertiary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _backText(
                              AppLocalizations.of(context)!.ankiNoCardContent,
                            ),
                            style: const TextStyle(fontSize: 20),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!_showAnswer)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => setState(() => _showAnswer = true),
                child: ConstrainedText(
                  AppLocalizations.of(context)!.ankiShowAnswer,
                  style: const TextStyle(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _RatingBtn(
                    AppLocalizations.of(context)!.ankiRatingAgain,
                    Colors.red,
                    () => _answer(1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RatingBtn(
                    AppLocalizations.of(context)!.ankiRatingHard,
                    Colors.orange,
                    () => _answer(2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _RatingBtn(
                    AppLocalizations.of(context)!.ankiRatingGood,
                    Colors.green,
                    () => _answer(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RatingBtn(
                    AppLocalizations.of(context)!.ankiRatingEasy,
                    Colors.blue,
                    () => _answer(4),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDone(BuildContext context, ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.celebration, size: 72, color: cs.primary),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.ankiNoCardsToStudy,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.ankiNoCardsHint,
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: ConstrainedText(
                AppLocalizations.of(context)!.ankiBack,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // ── Whiteboard ────────────────────────────────────────

  Widget _buildWhiteboard() {
    return Positioned.fill(
      child: GestureDetector(
        onPanStart: (d) => setState(
          () => _strokes.add(
            _DrawingStroke([d.localPosition], _penColor, _penWidth),
          ),
        ),
        onPanUpdate: (d) =>
            setState(() => _strokes.last.points.add(d.localPosition)),
        onPanEnd: (_) {},
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _WhiteboardPainter(_strokes),
            child: Container(),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // No resources to clean up for whiteboard
    super.dispose();
  }
}

class _DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  _DrawingStroke(this.points, this.color, this.width);
}

class _WhiteboardPainter extends CustomPainter {
  final List<_DrawingStroke> strokes;
  _WhiteboardPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color.withValues(alpha: 0.6)
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < stroke.points.length - 1; i++) {
        canvas.drawLine(stroke.points[i], stroke.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(_WhiteboardPainter old) => true;
}

class _RatingBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _RatingBtn(this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color.withValues(alpha: 0.3)),
          ),
        ),
        onPressed: onTap,
        child: ConstrainedText(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
