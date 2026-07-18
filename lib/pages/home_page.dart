import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'home_shared.dart';

import '../main.dart' as main_lib;
import '../services/auto_backup_service.dart';
import 'assistant_selection_page.dart';
import 'files_page_shared.dart';
import 'topic_selection_page.dart';
import 'catcatch_page.dart' hide showMediaPreview;
import 'unified_task_list_page.dart';
import '../catcatch/providers/catcatch_provider.dart';
import '../catcatch/models/catcatch_task.dart' as catcatch_task;
import '../providers/task_provider.dart';
import '../providers/background_task_provider.dart';
import 'chat_page.dart';
import 'files_page.dart';
import 'settings_page.dart';
import 'ocr_page.dart';
import 'asr_page.dart';
import 'audio_separation_page.dart';
import 'tts_create_page.dart';
import 'mermaid_chart_page.dart';
import 'math_drawing_page.dart';

/// 页面枚举，定义应用中的主要页面（不含加号按钮）
enum AppPage { home, chat, files, settings }

/// 当前选中页面的状态提供器
final selectedPageProvider = StateProvider<AppPage>((ref) => AppPage.home);

/// 主页，采用 FlClash 风格的响应式布局：
/// - 移动端：底部导航栏（主页、对话、文件、设置）
/// - 桌面端：侧边栏导航
/// 导航逻辑：切换页面时保留状态，再次点击同一项回到该页面的首页。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _chatNavigatorKey = GlobalKey<NavigatorState>();

  bool _autoBackupTriggered = false;

  @override
  void initState() {
    super.initState();
    // 在主页构建完成后触发一次后台自动备份
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAutoBackup();
    });
  }

  /// 触发后台自动备份（仅在非 Web 平台、非测试环境下执行一次）。
  Future<void> _triggerAutoBackup() async {
    if (_autoBackupTriggered) return;
    if (kIsWeb) return;
    _autoBackupTriggered = true;

    // 以最小占用在后台执行备份，不阻塞前台操作
    AutoBackupService.performAutoBackup().then((success) {
      debugPrint('[HomePage] 自动后台备份${success ? '完成' : '未完成（可能已在运行或被取消）'}');
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Resets the chat tab's nested navigator so it always shows
  /// [AssistantSelectionPage] when the chat tab is entered.
  void _resetChatNavigator() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatNavigatorKey.currentState != null) {
        _chatNavigatorKey.currentState!.popUntil((route) => route.isFirst);
      }
    });
  }

  /// 根据屏幕宽度判断是否为移动设备（宽度小于600像素）
  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  /// 获取页面对应的图标
  IconData _getPageIcon(AppPage page) {
    switch (page) {
      case AppPage.home:
        return Icons.home;
      case AppPage.chat:
        return Icons.chat_bubble_outline;
      case AppPage.files:
        return Icons.folder_outlined;
      case AppPage.settings:
        return Icons.settings;
    }
  }

  /// 获取页面对应的标题
  String _getPageTitle(AppPage page) {
    switch (page) {
      case AppPage.home:
        return '主页';
      case AppPage.chat:
        return '对话';
      case AppPage.files:
        return '文件';
      case AppPage.settings:
        return '设置';
    }
  }

  /// 显示媒体资源选择弹框（供 CatCatch userSelecting 步骤使用）
  void _showMediaSelectionDialog(
    BuildContext context,
    catcatch_task.CatCatchTask task,
  ) {
    final selectedUrls = <String>{};
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final mediaList = task.detectedMedia;
          return AlertDialog(
            title: Text(
              selectedUrls.isNotEmpty
                  ? '已选 ${selectedUrls.length}/${mediaList.length} 个资源'
                  : '选择要下载的资源',
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: mediaList.isEmpty
                  ? const Center(child: Text('检测到 0 个资源'))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: mediaList.length,
                      itemBuilder: (_, i) {
                        final media = mediaList[i];
                        final isSel = selectedUrls.contains(media.url);
                        final isAudio = [
                          'mp3',
                          'wav',
                          'm4a',
                          'aac',
                          'opus',
                          'weba',
                        ].contains(media.ext.toLowerCase());
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSel
                                  ? Theme.of(ctx).colorScheme.primary
                                  : Theme.of(ctx).colorScheme.outlineVariant,
                              width: isSel ? 1.5 : 0.5,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              setDlgState(() {
                                if (isSel) {
                                  selectedUrls.remove(media.url);
                                } else {
                                  selectedUrls.add(media.url);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isAudio ? Icons.audiotrack : Icons.videocam,
                                    size: 18,
                                    color:
                                        isAudio ? Colors.purple : Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isSel
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
                                    color: isSel
                                        ? Theme.of(ctx).colorScheme.primary
                                        : Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${media.name}.${media.ext}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: isSel
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (media.duration != null)
                                          Text(
                                            '时长: ${formatDurationShort(media.duration!)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(
                                                ctx,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        if (media.width != null &&
                                            media.height != null)
                                          Text(
                                            '分辨率: ${media.width}x${media.height}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(
                                                ctx,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (media.isPlayable)
                                    IconButton(
                                      icon: Icon(
                                        Icons.play_circle_filled,
                                        color: Theme.of(
                                          ctx,
                                        ).colorScheme.primary,
                                        size: 22,
                                      ),
                                      tooltip: '预览',
                                      onPressed: () {
                                        showMediaPreview(
                                          ctx,
                                          media,
                                          task.title.isNotEmpty
                                              ? task.title
                                              : task.url,
                                        );
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: selectedUrls.isNotEmpty || mediaList.length == 1
                    ? () {
                        final selectedMediaList = mediaList.length == 1
                            ? mediaList
                            : mediaList
                                .where((m) => selectedUrls.contains(m.url))
                                .toList();
                        Navigator.pop(ctx);
                        ref
                            .read(catcatchTasksProvider.notifier)
                            .batchSelectMedia(task.id, selectedMediaList);
                      }
                    : null,
                child: Text(
                  selectedUrls.isNotEmpty
                      ? '下载选中的 ${selectedUrls.length} 个资源'
                      : '确认下载',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 构建侧边栏导航（用于桌面端）
  Widget _buildNavigationRail(BuildContext context, int activeTaskCount) {
    final selectedPage = ref.watch(selectedPageProvider);

    return NavigationRail(
      groupAlignment: 0.0,
      selectedIndex: selectedPage.index,
      onDestinationSelected: (index) {
        final newPage = AppPage.values[index];
        final currentPage = ref.read(selectedPageProvider);
        if (newPage == currentPage) {
          // Double-tap on same page → go to page's home/main state
          if (newPage == AppPage.chat) {
            _resetChatNavigator();
          }
        } else {
          // Different page → switch, preserving state
          ref.read(selectedPageProvider.notifier).state = newPage;
          // Auto-refresh when entering files page
          if (newPage == AppPage.files) {
            ref.read(filesRefreshSignalProvider.notifier).state++;
          }
        }
      },
      labelType: NavigationRailLabelType.all,
      destinations: [
        NavigationRailDestination(
          icon: Badge(
            isLabelVisible: activeTaskCount > 0,
            label: Text('$activeTaskCount'),
            child: Icon(_getPageIcon(AppPage.home)),
          ),
          selectedIcon: Badge(
            isLabelVisible: activeTaskCount > 0,
            label: Text('$activeTaskCount'),
            child: Icon(
              _getPageIcon(AppPage.home),
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          label: Text(_getPageTitle(AppPage.home)),
        ),
        NavigationRailDestination(
          icon: Icon(_getPageIcon(AppPage.chat)),
          selectedIcon: Icon(
            _getPageIcon(AppPage.chat),
            color: Theme.of(context).colorScheme.primary,
          ),
          label: Text(_getPageTitle(AppPage.chat)),
        ),
        NavigationRailDestination(
          icon: Icon(_getPageIcon(AppPage.files)),
          selectedIcon: Icon(
            _getPageIcon(AppPage.files),
            color: Theme.of(context).colorScheme.primary,
          ),
          label: Text(_getPageTitle(AppPage.files)),
        ),
        NavigationRailDestination(
          icon: Icon(_getPageIcon(AppPage.settings)),
          selectedIcon: Icon(
            _getPageIcon(AppPage.settings),
            color: Theme.of(context).colorScheme.primary,
          ),
          label: Text(_getPageTitle(AppPage.settings)),
        ),
      ],
    );
  }

  /// 构建底部导航栏（用于移动端）
  Widget _buildBottomNavigationBar(BuildContext context, int activeTaskCount) {
    final selectedPage = ref.watch(selectedPageProvider);

    return NavigationBar(
      selectedIndex: selectedPage.index,
      onDestinationSelected: (index) {
        final newPage = AppPage.values[index];
        final currentPage = ref.read(selectedPageProvider);
        if (newPage == currentPage) {
          // Double-tap on same page → go to page's home/main state
          if (newPage == AppPage.chat) {
            _resetChatNavigator();
          }
        } else {
          // Different page → switch, preserving state
          ref.read(selectedPageProvider.notifier).state = newPage;
          // Auto-refresh when entering files page
          if (newPage == AppPage.files) {
            ref.read(filesRefreshSignalProvider.notifier).state++;
          }
        }
      },
      destinations: [
        NavigationDestination(
          icon: Badge(
            isLabelVisible: activeTaskCount > 0,
            label: Text('$activeTaskCount'),
            child: Icon(_getPageIcon(AppPage.home)),
          ),
          label: _getPageTitle(AppPage.home),
        ),
        NavigationDestination(
          icon: Icon(_getPageIcon(AppPage.chat)),
          label: _getPageTitle(AppPage.chat),
        ),
        NavigationDestination(
          icon: Icon(_getPageIcon(AppPage.files)),
          label: _getPageTitle(AppPage.files),
        ),
        NavigationDestination(
          icon: Icon(_getPageIcon(AppPage.settings)),
          label: _getPageTitle(AppPage.settings),
        ),
      ],
    );
  }

  /// 聊天标签页内容：嵌套导航器，始终以助手选择页为根路由。
  /// 用户流程：选择助手 → 选择话题 → 聊天页面。
  /// 每次进入聊天标签页时导航器会被重置到根路由（助手选择页）。
  Widget _buildChatOrAssistantPage() {
    return Navigator(
      key: _chatNavigatorKey,
      initialRoute: '/assistant-selection',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/assistant-selection':
            return MaterialPageRoute(
              builder: (_) => const AssistantSelectionPage(),
              settings: settings,
            );
          case '/topic-selection':
            return MaterialPageRoute(
              builder: (_) => const TopicSelectionPage(),
              settings: settings,
            );
          case '/chat':
            return MaterialPageRoute(
              builder: (_) => const ChatPage(),
              settings: settings,
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const AssistantSelectionPage(),
              settings: settings,
            );
        }
      },
    );
  }

  /// 构建页面内容
  Widget _buildPageContent(AppPage page) {
    switch (page) {
      case AppPage.home:
        return _buildHomeContent();
      case AppPage.chat:
        return _buildChatOrAssistantPage();
      case AppPage.files:
        return const FilesPage();
      case AppPage.settings:
        return const SettingsPage();
    }
  }

  /// 构建模块化首页内容
  Widget _buildHomeContent() {
    final cs = Theme.of(context).colorScheme;
    final catcatchTasks = ref.watch(catcatchTasksProvider);
    final synthesisTasks = ref.watch(taskListProvider);
    final backgroundTasks = ref.watch(backgroundTasksProvider);
    final lastRead = ref.watch(taskListLastReadProvider);
    final activeTaskCount = catcatchTasks
            .where(
              (t) =>
                  t.status.name != 'completed' &&
                  ((t.statusChangedAt ?? t.createdAt).isAfter(lastRead) ||
                      (t.status.name == 'running' &&
                          t.steps.any(
                            (s) => s.type.name == 'userSelecting' && s.running,
                          ))),
            )
            .length +
        synthesisTasks
            .where(
              (t) =>
                  t.status.name != 'completed' &&
                  (t.statusChangedAt ?? t.createdAt).isAfter(lastRead),
            )
            .length +
        backgroundTasks
            .where(
              (t) =>
                  t.status != TaskStatus.completed &&
                  (t.statusChangedAt ?? t.createdAt).isAfter(lastRead),
            )
            .length;

    return SafeArea(
      top: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — notification button integrated into the row
            // so it never overlaps or causes overflow on small screens.
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
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UnifiedTaskListPage(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Badge(
                        isLabelVisible: activeTaskCount > 0,
                        label: Text('$activeTaskCount'),
                        child: const Icon(Icons.pending_actions, size: 22),
                      ),
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
            const SizedBox(height: 24),
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

  @override
  Widget build(BuildContext context) {
    // 在启动时消费 catcatchStartupProvider，触发 restoreUnfinishedTasks
    ref.watch(main_lib.catcatchStartupProvider);

    final isMobile = _isMobile(context);
    final selectedPage = ref.watch(selectedPageProvider);
    final catcatchTasks = ref.watch(catcatchTasksProvider);
    final synthesisTasks = ref.watch(taskListProvider);
    final backgroundTasks = ref.watch(backgroundTasksProvider);
    final lastRead = ref.watch(taskListLastReadProvider);
    final activeTaskCount = catcatchTasks
            .where(
              (t) =>
                  t.status.name != 'completed' &&
                  ((t.statusChangedAt ?? t.createdAt).isAfter(lastRead) ||
                      (t.status.name == 'running' &&
                          t.steps.any(
                            (s) => s.type.name == 'userSelecting' && s.running,
                          ))),
            )
            .length +
        synthesisTasks
            .where(
              (t) =>
                  t.status.name != 'completed' &&
                  (t.statusChangedAt ?? t.createdAt).isAfter(lastRead),
            )
            .length +
        backgroundTasks
            .where(
              (t) =>
                  t.status != TaskStatus.completed &&
                  (t.statusChangedAt ?? t.createdAt).isAfter(lastRead),
            )
            .length;

    ref.listen(catcatchTasksProvider, (prev, next) {
      if (!mounted) return;
      for (final task in next) {
        if (task.status.name == 'running' &&
            task.steps.any(
              (s) => s.type.name == 'userSelecting' && s.running,
            ) &&
            task.detectedMedia.isNotEmpty &&
            task.selectedMedia == null) {
          _showMediaSelectionDialog(context, task);
          break;
        }
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // 返回键处理 — 层次导航（非历史导航）：
        // 1. 如果当前在聊天页且嵌套导航器有历史路由，先弹出嵌套路由（上一级页面）
        final currentPage = ref.read(selectedPageProvider);
        if (currentPage == AppPage.chat &&
            _chatNavigatorKey.currentState != null) {
          _chatNavigatorKey.currentState!.maybePop().then((popped) {
            if (!popped && mounted) {
              // 嵌套导航器已在根路由 → 跳转到主页
              ref.read(selectedPageProvider.notifier).state = AppPage.home;
            }
          });
          return;
        }
        // 2. 如果在文件页面，读取共享的文件夹状态：
        //    - 如果非空（在子文件夹中），通过信号通知文件管理器导航到父文件夹，
        //      然后不跳转到主页。
        //    - 如果为空（在根目录），跳转到主页。
        if (currentPage == AppPage.files) {
          final currentFolder = ref.read(filesPageCurrentFolderProvider);
          if (currentFolder.isNotEmpty) {
            // 在子文件夹中 → 发送导航到父文件夹的信号
            ref.read(filesPageNavigateToParentSignalProvider.notifier).state =
                ref.read(filesPageNavigateToParentSignalProvider) + 1;
            return;
          }
        }
        // 3. 如果在非主页标签页（对话根路由、文件、设置），跳转到主页（上一级页面）
        if (currentPage != AppPage.home) {
          ref.read(selectedPageProvider.notifier).state = AppPage.home;
          return;
        }
        // 4. 如果在主页，不做任何操作，不退出应用
      },
      child: Scaffold(
        body: Row(
          children: [
            // 桌面端显示侧边栏导航
            if (!isMobile) _buildNavigationRail(context, activeTaskCount),
            // 页面内容区域，使用IndexedStack保持各页面状态
            Expanded(
              child: IndexedStack(
                index: selectedPage.index,
                children: AppPage.values.map((page) {
                  return _buildPageContent(page);
                }).toList(),
              ),
            ),
          ],
        ),
        bottomNavigationBar: isMobile
            ? _buildBottomNavigationBar(context, activeTaskCount)
            : null,
      ),
    );
  }
}
