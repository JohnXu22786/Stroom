import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../anki/providers/anki_provider.dart';
import '../anki/providers/anki_actions.dart';
import '../anki/models/deck.dart';
import '../anki/models/card.dart';
import '../anki/models/note.dart';
import '../anki/models/model.dart';
import '../anki/pages/card_browser.dart';
import 'anki_sync_page.dart';

/// Main Anki page showing all decks and options.
class AnkiDroidPage extends ConsumerWidget {
  const AnkiDroidPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decksAsync = ref.watch(ankiDeckListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('闪卡'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '浏览卡片',
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AnkiCardBrowser()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync),
            tooltip: 'AnkiWeb 同步',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnkiSyncSettingsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建牌组',
            onPressed: () => _showCreateDeckDialog(context, ref),
          ),
        ],
      ),
      body: decksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (decks) => decks.isEmpty
            ? _buildEmptyState(context, ref)
            : _buildDeckList(context, ref, decks),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories,
                size: 64, color: cs.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('还没有牌组',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface)),
            const SizedBox(height: 8),
            Text('创建一个牌组开始学习',
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('新建牌组'),
              onPressed: () => _showCreateDeckDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeckList(
      BuildContext context, WidgetRef ref, List<AnkiDeck> decks) {
    // Sort hierarchically: top-level first, then children nested under parents
    final sorted = List<AnkiDeck>.from(decks)
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
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建牌组'),
        content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(
                hintText: '牌组名称', border: OutlineInputBorder())),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (c.text.trim().isNotEmpty) {
                ref.read(ankiActionsProvider).addDeck(c.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(
      BuildContext context, WidgetRef ref, int did, String name) {
    final c = TextEditingController(text: name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (c.text.trim().isNotEmpty) {
                ref.read(ankiActionsProvider).renameDeck(did, c.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDeck(
      BuildContext context, WidgetRef ref, int did, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除牌组'),
        content: Text('确定删除"$name"及其所有卡片吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              ref.read(ankiActionsProvider).removeDeck(did);
              Navigator.pop(ctx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _startStudy(BuildContext context, WidgetRef ref, int did) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => AnkiStudyPage(deckId: did)));
  }

  void _showAddCardDialog(BuildContext context, WidgetRef ref, int did) {
    final fc = TextEditingController();
    final bc = TextEditingController();
    final tc = TextEditingController();
    int selectedModelId = 1;
    String hintText = '正面 (问题)';

    // Load models synchronously from the last known value.
    // If not ready, fall back to Basic model id 1.
    final models = ref.read(ankiModelListProvider).value ?? <AnkiModel>[];
    if (models.isNotEmpty) selectedModelId = models.first.id;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('添加卡片'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (models.isNotEmpty)
                  DropdownButtonFormField<int>(
                    value: selectedModelId,
                    decoration: const InputDecoration(
                        labelText: '笔记类型', border: OutlineInputBorder()),
                    items: models
                        .map((m) =>
                            DropdownMenuItem(value: m.id, child: Text(m.name)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setDialogState(() {
                        selectedModelId = v;
                        final m = models.firstWhere((x) => x.id == v);
                        hintText = m.name == 'Cloze'
                            ? '正文 (用 {{c1::答案}} 标记挖空)'
                            : '正面 (问题)';
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
                        border: const OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: bc,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: '背面/额外', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: tc,
                    decoration: const InputDecoration(
                        labelText: '标签 (空格分隔)',
                        border: OutlineInputBorder(),
                        hintText: '例如: 数学 物理')),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              FilledButton(
                onPressed: () {
                  if (fc.text.trim().isNotEmpty && bc.text.trim().isNotEmpty) {
                    ref.read(ankiActionsProvider).addCard(
                        did, fc.text.trim(), bc.text.trim(),
                        modelId: selectedModelId, tags: tc.text.trim());
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('添加'),
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
  final AnkiDeck deck;
  final int deckId;
  final VoidCallback onTap, onAddCard, onRename, onDelete;

  const _DeckCard(
      {required this.deck,
      required this.deckId,
      required this.onTap,
      required this.onAddCard,
      required this.onRename,
      required this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final statsAsync = ref.watch(ankiDeckStatsProvider(deckId));

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant, width: 0.5)),
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
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.auto_stories,
                      color: cs.onPrimaryContainer, size: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deck.name,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface)),
                    const SizedBox(height: 4),
                    statsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (s) => Row(children: [
                        _StatChip(
                            count: s.newCount, label: '新', color: Colors.blue),
                        const SizedBox(width: 6),
                        _StatChip(
                            count: s.learningCount,
                            label: '学',
                            color: Colors.orange),
                        const SizedBox(width: 6),
                        _StatChip(
                            count: s.reviewCount,
                            label: '复习',
                            color: Colors.green),
                      ]),
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
                  _ => null
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'add', child: Text('添加卡片')),
                  const PopupMenuItem(value: 'rename', child: Text('重命名')),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text('删除', style: TextStyle(color: Colors.red))),
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
  const _StatChip(
      {required this.count, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$count',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(width: 2),
        Text(label,
            style:
                TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
      ]),
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
  AnkiCard? _current;
  AnkiNote? _note;
  bool _showAnswer = false;
  bool _studying = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final card = await ref.read(ankiActionsProvider).getNextCard(widget.deckId);
    AnkiNote? note;
    if (card != null) {
      try {
        final dao = ref.read(ankiNoteDaoProvider).requireValue;
        note = await dao.get(card.nid);
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

  String get _frontText {
    if (_note == null || _note!.fieldList.isEmpty) return '(无内容)';
    return _note!.fieldList[0];
  }

  String get _backText {
    if (_note == null || _note!.fieldList.length < 2) return '(无内容)';
    return _note!.fieldList[1];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final deckAsync = ref.watch(ankiDeckByIdProvider(widget.deckId));

    return Scaffold(
      appBar: AppBar(
        title: deckAsync.when(
            data: (d) => Text(d?.name ?? '学习'),
            loading: () => const Text('学习'),
            error: (_, __) => const Text('学习')),
        centerTitle: true,
      ),
      body: _studying && _current != null ? _buildContent(cs) : _buildDone(cs),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LinearProgressIndicator(
              value: _showAnswer ? 1.0 : 0.5,
              backgroundColor: cs.surfaceContainerHighest),
          const SizedBox(height: 24),
          Expanded(
              child: Center(
                  child: SingleChildScrollView(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 300),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('正面',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1)),
                    const SizedBox(height: 16),
                    Text(_frontText,
                        style: const TextStyle(fontSize: 22),
                        textAlign: TextAlign.center),
                    if (_showAnswer) ...[
                      const Divider(height: 32),
                      Text('背面',
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.tertiary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1)),
                      const SizedBox(height: 16),
                      Text(_backText,
                          style: const TextStyle(fontSize: 20),
                          textAlign: TextAlign.center),
                    ],
                  ],
                ),
              ),
            ),
          ))),
          const SizedBox(height: 16),
          if (!_showAnswer)
            SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () => setState(() => _showAnswer = true),
                  child: const Text('显示答案', style: TextStyle(fontSize: 16)),
                ))
          else ...[
            Row(children: [
              Expanded(child: _RatingBtn('忘记', Colors.red, () => _answer(1))),
              const SizedBox(width: 8),
              Expanded(
                  child: _RatingBtn('困难', Colors.orange, () => _answer(2))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _RatingBtn('良好', Colors.green, () => _answer(3))),
              const SizedBox(width: 8),
              Expanded(child: _RatingBtn('简单', Colors.blue, () => _answer(4))),
            ]),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDone(ColorScheme cs) {
    return Center(
        child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.celebration, size: 72, color: cs.primary),
        const SizedBox(height: 16),
        Text('当前没有待学习的卡片',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: cs.onSurface)),
        const SizedBox(height: 8),
        Text('你可以添加新卡片或稍后再来',
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center),
        const SizedBox(height: 32),
        FilledButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: const Text('返回'),
            onPressed: () => Navigator.pop(context)),
      ]),
    ));
  }
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
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: color.withValues(alpha: 0.3))),
        ),
        onPressed: onTap,
        child: Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
