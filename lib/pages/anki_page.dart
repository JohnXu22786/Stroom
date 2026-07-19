import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../anki/providers/anki_provider.dart';
import '../anki/models/deck.dart';
import '../anki/models/collection.dart';
import '../anki/models/card.dart';
import '../anki/scheduler/scheduler.dart';

/// Main Anki page showing all decks and options to manage them.
class AnkiDroidPage extends ConsumerStatefulWidget {
  const AnkiDroidPage({super.key});

  @override
  ConsumerState<AnkiDroidPage> createState() => _AnkiDroidPageState();
}

class _AnkiDroidPageState extends ConsumerState<AnkiDroidPage> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final decks = ref.watch(ankiDeckListProvider);
    final collection = ref.watch(ankiCollectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('闪卡'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建牌组',
            onPressed: () => _showCreateDeckDialog(context),
          ),
        ],
      ),
      body: decks.isEmpty
          ? _buildEmptyState(context)
          : _buildDeckList(context, cs, collection, decks),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
            Text(
              '还没有牌组',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '创建一个牌组开始你的学习之旅',
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('新建牌组'),
              onPressed: () => _showCreateDeckDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeckList(
    BuildContext context,
    ColorScheme cs,
    AnkiCollection collection,
    List<AnkiDeck> decks,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: decks.length,
      itemBuilder: (context, index) {
        final deck = decks[index];
        final stats = collection.getDeckStats(deck.id);
        return _DeckCard(
          deck: deck,
          stats: stats,
          onTap: () => _startStudy(context, deck.id),
          onAddCard: () => _showAddCardDialog(context, deck.id),
          onRename: () => _showRenameDialog(context, deck.id, deck.name),
          onDelete: () => _confirmDeleteDeck(context, deck.id, deck.name),
        );
      },
    );
  }

  void _showCreateDeckDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建牌组'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '牌组名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(ankiCollectionProvider.notifier).addDeck(
                      controller.text.trim(),
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, int deckId, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名牌组'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(ankiCollectionProvider.notifier).renameDeck(
                      deckId,
                      controller.text.trim(),
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('重命名'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDeck(BuildContext context, int deckId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除牌组'),
        content: Text('确定要删除"$name"及其所有卡片吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              ref.read(ankiCollectionProvider.notifier).removeDeck(deckId);
              Navigator.pop(ctx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _startStudy(BuildContext context, int deckId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AnkiStudyPage(deckId: deckId),
      ),
    );
  }

  void _showAddCardDialog(BuildContext context, int deckId) {
    final frontController = TextEditingController();
    final backController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加卡片'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: frontController,
              decoration: const InputDecoration(
                labelText: '正面 (问题)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: backController,
              decoration: const InputDecoration(
                labelText: '背面 (答案)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (frontController.text.trim().isNotEmpty &&
                  backController.text.trim().isNotEmpty) {
                ref.read(ankiCollectionProvider.notifier).addNote(
                      1, // Basic model
                      [frontController.text.trim(), backController.text.trim()],
                      deckId: deckId,
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}

/// A single deck card widget for the list.
class _DeckCard extends StatelessWidget {
  final AnkiDeck deck;
  final DeckStats stats;
  final VoidCallback onTap;
  final VoidCallback onAddCard;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _DeckCard({
    required this.deck,
    required this.stats,
    required this.onTap,
    required this.onAddCard,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalDue = stats.newCount + stats.learningCount + stats.reviewCount;

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
                  borderRadius: BorderRadius.circular(12),
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
                    Row(
                      children: [
                        _StatChip(
                          count: stats.newCount,
                          label: '新',
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 6),
                        _StatChip(
                          count: stats.learningCount,
                          label: '学',
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        _StatChip(
                          count: stats.reviewCount,
                          label: '复习',
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (totalDue > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$totalDue',
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
                onSelected: (value) {
                  switch (value) {
                    case 'add':
                      onAddCard();
                      break;
                    case 'rename':
                      onRename();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'add', child: Text('添加卡片')),
                  const PopupMenuItem(value: 'rename', child: Text('重命名')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('删除', style: TextStyle(color: Colors.red)),
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

// ============================================================================
// Study Page
// ============================================================================

/// The card study/review page.
class _AnkiStudyPage extends ConsumerStatefulWidget {
  final int deckId;

  const _AnkiStudyPage({required this.deckId});

  @override
  ConsumerState<_AnkiStudyPage> createState() => _AnkiStudyPageState();
}

class _AnkiStudyPageState extends ConsumerState<_AnkiStudyPage> {
  AnkiCard? _currentCard;
  bool _showAnswer = false;
  bool _studying = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNextCard();
    });
  }

  void _loadNextCard() {
    final collection = ref.read(ankiCollectionProvider);
    final scheduler = AnkiScheduler();
    final card = scheduler.getNextCard(collection, widget.deckId);
    setState(() {
      _currentCard = card;
      _showAnswer = false;
      _studying = card != null;
    });
  }

  void _answerCard(int rating) {
    if (_currentCard == null) return;
    ref.read(ankiCollectionProvider.notifier).answerCard(
          _currentCard!.id,
          rating,
          reviewDuration: 3, // simplified
        );
    _loadNextCard();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final deck = ref.watch(ankiDeckByIdProvider(widget.deckId));

    return Scaffold(
      appBar: AppBar(
        title: Text(deck?.name ?? '学习'),
        centerTitle: true,
      ),
      body: _studying && _currentCard != null
          ? _buildStudyContent(cs, _currentCard!)
          : _buildSessionComplete(cs),
    );
  }

  Widget _buildStudyContent(ColorScheme cs, AnkiCard card) {
    final note = ref.read(ankiCollectionProvider).getNote(card.noteId);
    final frontText = note?.fields.isNotEmpty == true ? note!.fields[0] : '';
    final backText = note?.fields.length != null && note!.fields.length > 1
        ? note.fields[1]
        : '';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: _showAnswer ? 1.0 : 0.5,
            backgroundColor: cs.surfaceContainerHighest,
          ),
          const SizedBox(height: 24),

          // Card content area
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 300),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '正面',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          frontText,
                          style: const TextStyle(fontSize: 22),
                          textAlign: TextAlign.center,
                        ),
                        if (_showAnswer) ...[
                          const Divider(height: 32),
                          Text(
                            '背面',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.tertiary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            backText,
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

          // Show Answer / Rating buttons
          if (!_showAnswer)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => setState(() => _showAnswer = true),
                child: const Text('显示答案', style: TextStyle(fontSize: 16)),
              ),
            )
          else
            _buildRatingButtons(cs),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildRatingButtons(ColorScheme cs) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _RatingButton(
                label: '忘记',
                color: Colors.red,
                onTap: () => _answerCard(1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RatingButton(
                label: '困难',
                color: Colors.orange,
                onTap: () => _answerCard(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _RatingButton(
                label: '良好',
                color: Colors.green,
                onTap: () => _answerCard(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RatingButton(
                label: '简单',
                color: Colors.blue,
                onTap: () => _answerCard(4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSessionComplete(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.celebration, size: 72, color: cs.primary),
            const SizedBox(height: 16),
            Text(
              '当前没有待学习的卡片',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '你可以添加新卡片或稍后再来复习',
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('返回牌组列表'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _RatingButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

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
            side: BorderSide(color: color.withValues(alpha: 0.3)),
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
