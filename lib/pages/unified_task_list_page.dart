import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catcatch/models/catcatch_task.dart' as catcatch;
import '../catcatch/providers/catcatch_provider.dart';
import '../providers/task_provider.dart';
import '../providers/background_task_provider.dart';
import '../task_flow/providers/task_flow_execution_provider.dart';
import 'unified_task_list/catcatch_task_card.dart';
import 'unified_task_list/synthesis_task_card.dart';
import 'unified_task_list/background_task_card.dart';
import 'unified_task_list/task_flow_card.dart';
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

/// Task tab categories.
enum TaskTab { all, inProgress, completed, failed }

/// Map a [UnifiedTaskItem] to its [TaskTab] category.
TaskTab _taskTab(UnifiedTaskItem item) {
  if (item.isTaskFlow) {
    final status = item.taskFlowExecution!.taskStatus;
    switch (status) {
      case TaskStatus.running:
      case TaskStatus.paused:
      case TaskStatus.waiting:
        return TaskTab.inProgress;
      case TaskStatus.completed:
        return TaskTab.completed;
      case TaskStatus.failed:
        return TaskTab.failed;
    }
  } else if (item.isCatCatch) {
    final t = item.catCatchTask!;
    switch (t.status) {
      case catcatch.TaskStatus.running:
      case catcatch.TaskStatus.paused:
      case catcatch.TaskStatus.waiting:
        return TaskTab.inProgress;
      case catcatch.TaskStatus.completed:
        return TaskTab.completed;
      case catcatch.TaskStatus.failed:
        return TaskTab.failed;
    }
  } else {
    final TaskStatus status;
    if (item.isBackground) {
      status = item.backgroundTask!.status;
    } else {
      status = item.synthesisTask!.status;
    }
    switch (status) {
      case TaskStatus.running:
      case TaskStatus.paused:
      case TaskStatus.waiting:
        return TaskTab.inProgress;
      case TaskStatus.completed:
        return TaskTab.completed;
      case TaskStatus.failed:
        return TaskTab.failed;
    }
  }
}

/// Tab labels and their icons for the task list.
const _taskTabData = [
  _TabData('全部', Icons.list),
  _TabData('进行中', Icons.play_circle_outline),
  _TabData('已完成', Icons.check_circle_outline),
  _TabData('失败', Icons.error_outline),
];

class _TabData {
  final String label;
  final IconData icon;
  const _TabData(this.label, this.icon);
}

class UnifiedTaskListPage extends ConsumerStatefulWidget {
  final int initialTab;

  const UnifiedTaskListPage({super.key, this.initialTab = 0});

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
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
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
    final taskFlowExecutions = ref.watch(taskFlowExecutionsProvider);

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
      for (final t in taskFlowExecutions)
        UnifiedTaskItem(
          id: t.id,
          createdAt: t.createdAt,
          isTaskFlow: true,
          taskFlowExecution: t,
        ),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Filter out tasks that are already nested inside a task flow execution.
    // These tasks were created by the flow and should only be visible when
    // expanding the flow card, not as independent top-level items.
    final flowSubTaskIds = <String>{
      for (final exec in taskFlowExecutions)
        for (final st in exec.subTasks) st.subTaskId,
    };
    final filteredByFlow = allTasks.where((item) {
      if (item.isTaskFlow) return true; // always show flow cards
      return !flowSubTaskIds.contains(item.id);
    }).toList();

    // Filter tasks based on selected tab
    final filteredTasks = _filteredTasks(filteredByFlow, _tabController.index);

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务列表'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            tabs: [
              for (final tab in _taskTabData)
                Tab(text: tab.label, icon: Icon(tab.icon, size: 18)),
            ],
          ),
        ),
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
                  title: Text('清除失败任务', style: TextStyle(color: Colors.red)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: ListTile(
                  leading:
                      Icon(Icons.delete_sweep, size: 20, color: Colors.red),
                  title: Text('清除所有', style: TextStyle(color: Colors.red)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 任务列表
          Expanded(
            child: filteredTasks.isEmpty
                ? _buildEmptyState(context)
                : _buildTaskList(filteredTasks),
          ),
        ],
      ),
    );
  }

  /// Filter [allTasks] by the currently selected tab.
  List<UnifiedTaskItem> _filteredTasks(
      List<UnifiedTaskItem> allTasks, int tabIndex) {
    if (tabIndex == 0) return allTasks; // 全部 — no filter
    final targetTab = TaskTab.values[tabIndex];
    return allTasks.where((item) => _taskTab(item) == targetTab).toList();
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pending_actions,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无任务',
            style: TextStyle(
              fontSize: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(List<UnifiedTaskItem> tasks) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: tasks.length,
      itemBuilder: (_, i) {
        final item = tasks[i];
        final lastRead = ref.watch(taskListLastReadProvider);
        if (item.isTaskFlow) {
          final exec = item.taskFlowExecution!;
          return TaskFlowCard(
            key: ValueKey(item.id),
            execution: exec,
            isUnread: exec.createdAt.isAfter(lastRead),
          );
        }
        if (item.isCatCatch) {
          final t = item.catCatchTask!;
          final isUnread = (t.statusChangedAt ?? t.createdAt).isAfter(lastRead);
          return CatCatchTaskCard(
            key: ValueKey(item.id),
            task: t,
            isUnread: isUnread,
          );
        }
        if (item.isBackground) {
          final t = item.backgroundTask!;
          final isUnread = (t.statusChangedAt ?? t.createdAt).isAfter(lastRead);
          return BackgroundTaskCard(
            key: ValueKey(item.id),
            task: t,
            isUnread: isUnread,
          );
        }
        final t = item.synthesisTask!;
        final isUnread = (t.statusChangedAt ?? t.createdAt).isAfter(lastRead);
        return SynthesisTaskCard(
          key: ValueKey(item.id),
          task: t,
          isUnread: isUnread,
        );
      },
    );
  }
}
