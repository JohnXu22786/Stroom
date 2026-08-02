part of 'home_page.dart';

extension _HomePageHomeContentExt on _HomePageState {
  /// 构建模块化首页内容
  Widget _buildHomeContent() {
    final cs = Theme.of(context).colorScheme;
    final catcatchTasks = ref.watch(catcatchTasksProvider);
    final synthesisTasks = ref.watch(taskListProvider);
    // Project to (id, status) so the home page ONLY rebuilds when a
    // background task's id/status actually changes — not on every
    // intermediate step update (e.g. updateStep from running → running
    // on a different step index).  This keeps the GUI responsive during
    // CPU-bound extraction pipelines.
    final bgTasks = ref.watch(backgroundTasksProvider.select((tasks) => [
          for (final t in tasks) (id: t.id, status: t.status.name),
        ]));
    final flowExecutions = ref.watch(taskFlowExecutionsProvider);

    // Flow sub-tasks are rendered inside their flow card in the unified
    // task list — they must not be counted as standalone items here.
    final flowSubTaskIds = <String>{
      for (final e in flowExecutions)
        for (final st in e.subTasks) st.subTaskId,
    };

    // --- Compute status counts for the status card ---
    int inProgressCount = 0;
    int completedCount = 0;
    int failedCount = 0;

    void countStatusName(String statusName) {
      if (statusName == 'running' ||
          statusName == 'paused' ||
          statusName == 'waiting') {
        inProgressCount++;
      } else if (statusName == 'completed') {
        completedCount++;
      } else if (statusName == 'failed') {
        failedCount++;
      }
    }

    void countTaskIfStandalone(String id, String statusName) {
      if (flowSubTaskIds.contains(id)) return;
      countStatusName(statusName);
    }

    for (final t in bgTasks) {
      countTaskIfStandalone(t.id, t.status);
    }
    for (final t in catcatchTasks) {
      countTaskIfStandalone(t.id, t.status.name);
    }
    for (final t in synthesisTasks) {
      countTaskIfStandalone(t.id, t.status.name);
    }
    // Each flow execution is exactly one card in the unified task list —
    // count it once, matching what the user sees there.
    for (final e in flowExecutions) {
      countStatusName(e.status.name);
    }

    return SafeArea(
      top: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — no notification button (replaced by status card)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 24, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '欢迎使用 Stroom',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '选择一个功能模块开始使用',
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            // Status card — shows task counts by status
            _buildStatusCard(
                context, inProgressCount, completedCount, failedCount),
            const SizedBox(height: 16),
            // Module grid
            Expanded(
              child: GridView(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                children: [
                  _buildModuleCard(
                    icon: Icons.text_snippet,
                    label: 'OCR',
                    subtitle: '文字识别',
                    color: Colors.teal,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OcrPage()),
                      );
                    },
                  ),
                  _buildModuleCard(
                    icon: Icons.multitrack_audio,
                    label: '语音识别',
                    subtitle: '语音转文字',
                    color: Colors.deepPurple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AsrPage()),
                      );
                    },
                  ),
                  _buildModuleCard(
                    icon: Icons.language,
                    label: '下载网页资源',
                    subtitle: '下载网页中的音视频',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CatCatchPage()),
                      );
                    },
                  ),
                  _buildModuleCard(
                    icon: Icons.music_note,
                    label: '音频分离',
                    subtitle: '从视频中提取音频',
                    color: Colors.indigo,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AudioSeparationPage(),
                        ),
                      );
                    },
                  ),
                  _buildModuleCard(
                    icon: Icons.record_voice_over,
                    label: '语音合成',
                    subtitle: '文字转语音',
                    color: Colors.cyan,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TTSCreatePage(),
                        ),
                      );
                    },
                  ),
                  _buildModuleCard(
                    icon: Icons.account_tree,
                    label: '图表制作',
                    subtitle: 'Mermaid图表编辑',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MermaidChartPage(),
                        ),
                      );
                    },
                  ),
                  _buildModuleCard(
                    icon: Icons.functions,
                    label: '数学绘图',
                    subtitle: '函数绘图',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MathDrawingPage(),
                        ),
                      );
                    },
                  ),
                  _buildModuleCard(
                    icon: Icons.account_tree,
                    label: '任务流',
                    subtitle: '功能块编排流水线',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TaskFlowListPage(),
                        ),
                      );
                    },
                  ),
                  _buildModuleCard(
                    icon: Icons.auto_stories,
                    label: 'Anki闪卡',
                    subtitle: '记忆辅助系统',
                    color: Colors.teal,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AnkiDroidPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建模块卡片
  Widget _buildModuleCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建扁平圆角框状态卡片
  Widget _buildStatusCard(
    BuildContext context,
    int inProgressCount,
    int completedCount,
    int failedCount,
  ) {
    final cs = Theme.of(context).colorScheme;

    Widget _statusItem({
      required int count,
      required String label,
      required Color dotColor,
      required int tabIndex,
    }) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UnifiedTaskListPage(initialTab: tabIndex),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
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

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          children: [
            // Header row: "最近任务" on left, "查看全部 >" on right
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 6),
              child: Row(
                children: [
                  Text(
                    '最近任务',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const UnifiedTaskListPage(initialTab: 0),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '查看全部',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 1),
                          Text(
                            '>',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.primary,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Status items row — 等分三列
            Row(
              children: [
                _statusItem(
                  count: inProgressCount,
                  label: '进行中',
                  dotColor: const Color(0xFFFF9800), // orange
                  tabIndex: 1,
                ),
                _statusItem(
                  count: completedCount,
                  label: '已完成',
                  dotColor: const Color(0xFF4CAF50), // green
                  tabIndex: 2,
                ),
                _statusItem(
                  count: failedCount,
                  label: '失败',
                  dotColor: const Color(0xFFF44336), // red
                  tabIndex: 3,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
