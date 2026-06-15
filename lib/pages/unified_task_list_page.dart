import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catcatch/providers/catcatch_provider.dart';
import '../providers/task_provider.dart';
import '../providers/background_task_provider.dart';
import 'unified_task_list/catcatch_task_card.dart';
import 'unified_task_list/synthesis_task_card.dart';
import 'unified_task_list/background_task_card.dart';
import 'unified_task_list/task_utils.dart';

// Re-export public APIs for backward compatibility
export 'unified_task_list/media_preview_sheet.dart' show showMediaPreview;
export 'unified_task_list/task_utils.dart'
    show
        formatSize,
        openFile,
        truncateUrl,
        formatDurationSimple,
        parseDurationToSeconds,
        stepIcon,
        UnifiedTaskItem,
        taskListLastReadProvider,
        persistTaskListLastRead,
        loadTaskListLastRead,
        formatRelativeTime;

class UnifiedTaskListPage extends ConsumerStatefulWidget {
  const UnifiedTaskListPage({super.key});

  @override
  ConsumerState<UnifiedTaskListPage> createState() =>
      _UnifiedTaskListPageState();
}

class _UnifiedTaskListPageState extends ConsumerState<UnifiedTaskListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final now = DateTime.now();
        ref.read(taskListLastReadProvider.notifier).state = now;
        persistTaskListLastRead(now);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catcatchTasks = ref.watch(catcatchTasksProvider);
    final synthesisTasks = ref.watch(taskListProvider);
    final backgroundTasks = ref.watch(backgroundTasksProvider);

    final allTasks = <UnifiedTaskItem>[
      for (final t in catcatchTasks)
        UnifiedTaskItem(
          id: t.id,
          createdAt: t.createdAt,
          isCatCatch: true,
          isBackground: false,
          catCatchTask: t,
        ),
      for (final t in synthesisTasks)
        UnifiedTaskItem(
          id: t.id,
          createdAt: t.createdAt,
          isCatCatch: false,
          isBackground: false,
          synthesisTask: t,
        ),
      for (final t in backgroundTasks)
        UnifiedTaskItem(
          id: t.id,
          createdAt: t.createdAt,
          isCatCatch: false,
          isBackground: true,
          backgroundTask: t,
        ),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务列表'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'clear_completed') {
                for (final t in catcatchTasks) {
                  if (t.status.name == 'completed') {
                    ref.read(catcatchTasksProvider.notifier).removeTask(t.id);
                  }
                }
                for (final t in synthesisTasks) {
                  if (t.status.name == 'completed') {
                    ref.read(taskListProvider.notifier).removeTask(t.id);
                  }
                }
                for (final t in backgroundTasks) {
                  if (t.status == TaskStatus.completed) {
                    ref.read(backgroundTasksProvider.notifier).removeTask(t.id);
                  }
                }
              } else if (value == 'clear_failed') {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('确认清除'),
                    content: const Text('确定要清除所有失败任务吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          for (final t in catcatchTasks) {
                            if (t.status.name == 'failed') {
                              ref
                                  .read(catcatchTasksProvider.notifier)
                                  .removeTask(t.id);
                            }
                          }
                          for (final t in synthesisTasks) {
                            if (t.status.name == 'failed') {
                              ref
                                  .read(taskListProvider.notifier)
                                  .removeTask(t.id);
                            }
                          }
                          for (final t in backgroundTasks) {
                            if (t.status == TaskStatus.failed) {
                              ref
                                  .read(backgroundTasksProvider.notifier)
                                  .removeTask(t.id);
                            }
                          }
                        },
                        child: const Text('确定',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              } else if (value == 'clear_all') {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('确认清除'),
                    content: const Text('确定要清除所有任务吗？此操作不可撤销。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          for (final t in catcatchTasks) {
                            ref
                                .read(catcatchTasksProvider.notifier)
                                .removeTask(t.id);
                          }
                          for (final t in synthesisTasks) {
                            ref
                                .read(taskListProvider.notifier)
                                .removeTask(t.id);
                          }
                          for (final t in backgroundTasks) {
                            ref
                                .read(backgroundTasksProvider.notifier)
                                .removeTask(t.id);
                          }
                        },
                        child: const Text('确定',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'clear_completed',
                child: ListTile(
                  leading: Icon(Icons.cleaning_services, size: 20),
                  title: Text('清除已完成'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear_failed',
                child: ListTile(
                  leading:
                      Icon(Icons.error_outline, size: 20, color: Colors.red),
                  title: Text('清除失败任务',
                      style: TextStyle(color: Colors.red)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep, size: 20, color: Colors.red),
                  title: Text('清除所有',
                      style: TextStyle(color: Colors.red)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '全部'),
            Tab(text: '下载'),
            Tab(text: '合成'),
            Tab(text: '其他'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabContent(allTasks, '全部'),
          _buildTabContent(
            allTasks.where((t) => t.isCatCatch).toList(),
            '下载',
          ),
          _buildTabContent(
            allTasks.where((t) => !t.isCatCatch && !t.isBackground).toList(),
            '合成',
          ),
          _buildTabContent(
            allTasks.where((t) => t.isBackground).toList(),
            '其他',
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(List<UnifiedTaskItem> tasks, String tabLabel) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tabLabel == '下载'
                  ? Icons.cloud_download_outlined
                  : tabLabel == '合成'
                      ? Icons.graphic_eq
                      : tabLabel == '其他'
                          ? Icons.miscellaneous_services
                          : Icons.pending_actions,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无任务',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: tasks.length,
      itemBuilder: (_, i) {
        final item = tasks[i];
        final lastRead = ref.watch(taskListLastReadProvider);
        if (item.isCatCatch) {
          final t = item.catCatchTask!;
          final isUnread =
              (t.statusChangedAt ?? t.createdAt).isAfter(lastRead);
          return CatCatchTaskCard(task: t, isUnread: isUnread);
        }
        if (item.isBackground) {
          final t = item.backgroundTask!;
          final isUnread =
              (t.statusChangedAt ?? t.createdAt).isAfter(lastRead);
          return BackgroundTaskCard(task: t, isUnread: isUnread);
        }
        final t = item.synthesisTask!;
        final isUnread =
            (t.statusChangedAt ?? t.createdAt).isAfter(lastRead);
        return SynthesisTaskCard(task: t, isUnread: isUnread);
      },
    );
  }
}
