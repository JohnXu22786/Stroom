import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/anki_provider.dart';
import '../database/anki_database.dart';
import '../database/col_dao.dart';
import '../database/card_dao.dart';

/// Statistics page — queries SQLite directly for aggregate numbers.
class AnkiStatsPage extends ConsumerWidget {
  const AnkiStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbAsync = ref.watch(ankiDatabaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('学习统计'), centerTitle: true),
      body: dbAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (db) => _buildStats(context, db),
      ),
    );
  }

  Widget _buildStats(BuildContext context, AnkiDatabase db) {
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/ 1000;

    // Run all queries in parallel
    return FutureBuilder(
      future: Future.wait([
        db.cards.totalCountAll(),
        db.cards.countByQueueAll(0), // new
        db.cards.countByQueueAll(1), // learning
        db.cards.countByQueueAll(2), // review
        db.revlog.count(),
      ]),
      builder: (ctx, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final data = snap.data as List<int>;
        final total = data[0];
        final newCount = data[1];
        final learning = data[2];
        final review = data[3];
        final revlogCount = data[4];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatCard(
                icon: Icons.auto_stories,
                color: Colors.teal,
                title: '总卡片数',
                value: '$total'),
            const SizedBox(height: 12),
            _StatCard(
                icon: Icons.fiber_new,
                color: Colors.blue,
                title: '待学习',
                value: '$newCount'),
            const SizedBox(height: 12),
            _StatCard(
                icon: Icons.timelapse,
                color: Colors.orange,
                title: '学习中',
                value: '$learning'),
            const SizedBox(height: 12),
            _StatCard(
                icon: Icons.replay,
                color: Colors.green,
                title: '待复习',
                value: '$review'),
            const SizedBox(height: 12),
            _StatCard(
                icon: Icons.history,
                color: Colors.purple,
                title: '历史复习次数',
                value: '$revlogCount'),
            const SizedBox(height: 12),
            if (total > 0)
              _ProgressBar(
                label: '学习进度',
                value: (review + learning) / total,
                color: Colors.teal,
              ),
            const SizedBox(height: 12),
            if (total > 0)
              _ProgressBar(
                label: '复习率',
                value: revlogCount > 0
                    ? (revlogCount / (revlogCount + total)).clamp(0, 1)
                    : 0,
                color: Colors.green,
              ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  const _StatCard(
      {required this.icon,
      required this.color,
      required this.title,
      required this.value});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: TextStyle(fontSize: 15, color: cs.onSurface))),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _ProgressBar(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 14, color: cs.onSurface)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                  value: value,
                  minHeight: 12,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(color)),
            ),
            const SizedBox(height: 4),
            Text('${(value * 100).round()}%',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
