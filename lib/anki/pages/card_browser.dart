import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/anki_provider.dart';
import '../providers/anki_actions.dart';
import '../models/card.dart';
import '../models/note.dart';
import '../models/deck.dart';

/// Simple card browser / search page.
class AnkiCardBrowser extends ConsumerStatefulWidget {
  final int? deckId; // null = all decks
  const AnkiCardBrowser({super.key, this.deckId});

  @override
  ConsumerState<AnkiCardBrowser> createState() => _AnkiCardBrowserState();
}

class _AnkiCardBrowserState extends ConsumerState<AnkiCardBrowser> {
  final _searchCtl = TextEditingController();
  List<AnkiCard> _allCards = [];
  List<AnkiCard> _filtered = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final cardDao = ref.read(ankiCardDaoProvider).value;
    if (cardDao == null) return;
    List<AnkiCard> cards;
    if (widget.deckId != null) {
      cards = await cardDao.listByDeck(widget.deckId!);
    } else {
      cards = await cardDao.all();
    }
    if (mounted)
      setState(() {
        _allCards = cards;
        _filtered = cards;
        _loaded = true;
      });
  }

  void _search(String q) {
    final query = q.toLowerCase();
    setState(() {
      _filtered = _allCards.where((c) {
        if (c.id.toString().contains(query)) return true;
        // We could also search note text but that requires joining
        return false;
      }).toList();
    });
  }

  Future<AnkiNote?> _loadNote(int nid) async {
    final noteDao = ref.read(ankiNoteDaoProvider).value;
    if (noteDao == null) return null;
    return noteDao.get(nid);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('卡片浏览'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtl,
              decoration: InputDecoration(
                hintText: '搜索卡片...',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _searchCtl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtl.clear();
                          _search('');
                        })
                    : null,
              ),
              onChanged: _search,
            ),
          ),
          Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Text('无卡片',
                            style: TextStyle(color: cs.onSurfaceVariant)))
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final card = _filtered[i];
                          return FutureBuilder<AnkiNote?>(
                            future: _loadNote(card.nid),
                            builder: (ctx, snap) {
                              final note = snap.data;
                              final front = note?.fieldList.isNotEmpty == true
                                  ? note!.fieldList[0]
                                  : '(无内容)';
                              return ListTile(
                                leading: _queueIcon(card.queue),
                                title: Text(front,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text(
                                  'ivl=${card.ivl}d  factor=${(card.factor / 10).round()}%  reps=${card.reps}',
                                  style: TextStyle(
                                      fontSize: 12, color: cs.onSurfaceVariant),
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      color: cs.error),
                                  onPressed: () {
                                    ref
                                        .read(ankiActionsProvider)
                                        .removeNote(card.nid);
                                    _load();
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _queueIcon(int queue) {
    switch (queue) {
      case 0:
        return const Icon(Icons.fiber_new, color: Colors.blue, size: 20);
      case 1:
      case 3:
        return const Icon(Icons.timelapse, color: Colors.orange, size: 20);
      case 2:
        return const Icon(Icons.replay, color: Colors.green, size: 20);
      default:
        return const Icon(Icons.block, color: Colors.grey, size: 20);
    }
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }
}
