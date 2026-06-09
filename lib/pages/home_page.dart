import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart' as main_lib;
import 'assistant_selection_page.dart';
import 'topic_selection_page.dart';
import 'catcatch_page.dart' hide showMediaPreview;
import 'unified_task_list_page.dart';
import '../catcatch/providers/catcatch_provider.dart';
import '../catcatch/models/catcatch_task.dart' as catcatch_task;
import '../providers/task_provider.dart';
import 'chat_page.dart';
import 'files_page.dart';
import 'settings_page.dart';
import 'camera_page.dart';
import 'tts_create_page.dart';
import 'video_capture_page.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/camera_choice_dialog.dart';
import '../widgets/folder_picker_dialog.dart';
import 'ocr_page.dart';
import 'asr_page.dart';

/// 页面枚举，定义应用中的主要页面（不含加号按钮）
enum AppPage {
  home,
  chat,
  files,
  settings,
}

/// 当前选中页面的状态提供器
final selectedPageProvider = StateProvider<AppPage>((ref) => AppPage.home);

/// 主页，采用 FlClash 风格的响应式布局：
/// - 移动端：底部导航栏（主页、对话、+、文件、设置）
/// - 桌面端：侧边栏导航
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late PageController _pageController;
  final _chatNavigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: AppPage.home.index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Resets the chat tab's nested navigator so it always shows
  /// [AssistantSelectionPage] when the chat tab is entered.
  void _resetChatNavigator() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatNavigatorKey.currentState != null) {
        _chatNavigatorKey.currentState!
            .popUntil((route) => route.isFirst);
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
  void _showMediaSelectionDialog(BuildContext context, catcatch_task.CatCatchTask task) {
    final selectedUrls = <String>{};
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final mediaList = task.detectedMedia;
          return AlertDialog(
            title: Text(selectedUrls.isNotEmpty
                ? '已选 ${selectedUrls.length}/${mediaList.length} 个资源'
                : '选择要下载的资源'),
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
                        final isAudio = ['mp3', 'wav', 'm4a', 'aac', 'opus', 'weba'].contains(media.ext.toLowerCase());
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSel ? Theme.of(ctx).colorScheme.primary : Theme.of(ctx).colorScheme.outlineVariant,
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    isAudio ? Icons.audiotrack : Icons.videocam,
                                    size: 18,
                                    color: isAudio ? Colors.purple : Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isSel ? Icons.check_box : Icons.check_box_outline_blank,
                                    color: isSel ? Theme.of(ctx).colorScheme.primary : Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${media.name}.${media.ext}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (media.duration != null)
                                          Text(
                                            '时长: ${_formatDurationShort(media.duration!)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        if (media.width != null && media.height != null)
                                          Text(
                                            '分辨率: ${media.width}x${media.height}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (media.isPlayable)
                                    IconButton(
                                      icon: Icon(
                                        Icons.play_circle_filled,
                                        color: Theme.of(ctx).colorScheme.primary,
                                        size: 22,
                                      ),
                                      tooltip: '预览',
                                      onPressed: () {
                                        showMediaPreview(
                                          ctx,
                                          media,
                                          task.title.isNotEmpty ? task.title : task.url,
                                        );
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              FilledButton(
                onPressed: selectedUrls.isNotEmpty || mediaList.length == 1
                    ? () {
                        final selectedMediaList = mediaList.length == 1
                            ? mediaList
                            : mediaList.where((m) => selectedUrls.contains(m.url)).toList();
                        Navigator.pop(ctx);
                        ref.read(catcatchTasksProvider.notifier).batchSelectMedia(
                          task.id,
                          selectedMediaList,
                        );
                      }
                    : null,
                child: Text(selectedUrls.isNotEmpty
                    ? '下载选中的 ${selectedUrls.length} 个资源'
                    : '确认下载'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 显示加号弹出的菜单
  void _showPlusMenu(BuildContext context) {
    final navigator = Navigator.of(context);
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final isMobile = _isMobile(context);
    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    RelativeRect position;

    if (isMobile) {
      // 底部导航栏：从"+"按钮位置向上弹出
      final centerX = screenSize.width / 2;
      const navBarHeight = 80.0;
      final navBarTop = screenSize.height - navBarHeight;

      position = RelativeRect.fromLTRB(
        centerX - 20,
        navBarTop - 10,
        centerX + 20,
        navBarTop + 10,
      );
    } else {
      // 侧边栏：从"+"按钮位置向右弹出
      const railWidth = 80.0;
      final availableHeight =
          screenSize.height - padding.top - padding.bottom;
      final itemHeight = availableHeight / 5;
      final plusCenterY = itemHeight * 2 + itemHeight / 2 + padding.top;

      position = RelativeRect.fromLTRB(
        railWidth,
        plusCenterY - 20,
        railWidth + 10,
        plusCenterY + 20,
      );
    }

    showMenu<String>(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          value: 'catcatch',
          child: SizedBox(
            width: 200,
            child: _buildMenuItem(
              icon: Icons.language,
              color: Colors.purple,
              title: '获取网页视频',
              subtitle: '下载网页中的视频资源',
            ),
          ),
        ),
        PopupMenuItem(
          value: 'record',
          child: SizedBox(
            width: 200,
            child: _buildMenuItem(
              icon: Icons.mic,
              color: Colors.blue,
              title: '录音',
              subtitle: '录制音频内容',
            ),
          ),
        ),
        PopupMenuItem(
          value: 'capture',
          child: SizedBox(
            width: 200,
            child: _buildMenuItem(
              icon: Icons.camera_alt,
              color: Colors.green,
              title: '拍摄',
              subtitle: '拍照记录精彩瞬间',
            ),
          ),
        ),
        PopupMenuItem(
          value: 'capture_video',
          child: SizedBox(
            width: 200,
            child: _buildMenuItem(
              icon: Icons.videocam,
              color: Colors.red,
              title: '录像',
              subtitle: '录制视频内容',
            ),
          ),
        ),
      ],
    ).then((value) {
      if (!mounted) return;
      if (value == null) return;

      switch (value) {
        case 'catcatch':
          navigator.push(
            MaterialPageRoute(builder: (_) => const CatCatchPage()),
          );
          break;
        case 'record':
          navigator.push(
            MaterialPageRoute(builder: (_) => const TTSCreatePage()),
          );
          break;
        case 'capture':
          showCameraChoiceDialog(context).then((result) {
            if (result == null) return;
            final folder = result.folder;
            if (result.choice == CameraChoice.app) {
              navigator.push(
                MaterialPageRoute(
                    builder: (_) => CameraPage(folder: folder)),
              );
            } else if (result.choice == CameraChoice.system) {
              ImagePicker().pickImage(source: ImageSource.camera).then((file) {
                if (file != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('照片已选择'), duration: Duration(seconds: 2)),
                  );
                }
              });
            }
          });
          break;
        case 'capture_video':
          FolderPickerDialog.show(
            context,
            title: '录像添加至文件夹',
          ).then((folder) {
            if (folder == null || !mounted) return;
            navigator.push(
              MaterialPageRoute(
                  builder: (_) => VideoCapturePage(folder: folder)),
            );
          });
          break;
      }
    });
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
  }) {
    return Row(
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
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 构建侧边栏导航（用于桌面端）
  Widget _buildNavigationRail(BuildContext context, int activeTaskCount) {
    final selectedPage = ref.watch(selectedPageProvider);

    int selectedIndex;
    if (selectedPage.index >= 2) {
      selectedIndex = selectedPage.index + 1;
    } else {
      selectedIndex = selectedPage.index;
    }

    return NavigationRail(
      groupAlignment: 0.0,
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        if (index == 2) {
          _showPlusMenu(context);
          return;
        }
        final pageIndex = index > 2 ? index - 1 : index;
        ref.read(selectedPageProvider.notifier).state =
            AppPage.values[pageIndex];
        _pageController.jumpToPage(pageIndex);
        if (AppPage.values[pageIndex] == AppPage.chat) {
          _resetChatNavigator();
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
            child: Icon(_getPageIcon(AppPage.home),
                color: Theme.of(context).colorScheme.primary),
          ),
          label: Text(_getPageTitle(AppPage.home)),
        ),
        NavigationRailDestination(
          icon: Icon(_getPageIcon(AppPage.chat)),
          selectedIcon: Icon(_getPageIcon(AppPage.chat),
              color: Theme.of(context).colorScheme.primary),
          label: Text(_getPageTitle(AppPage.chat)),
        ),
        NavigationRailDestination(
          icon: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.85),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 20),
          ),
          selectedIcon: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 20),
          ),
          label: const Text(''),
        ),
        NavigationRailDestination(
          icon: Icon(_getPageIcon(AppPage.files)),
          selectedIcon: Icon(_getPageIcon(AppPage.files),
              color: Theme.of(context).colorScheme.primary),
          label: Text(_getPageTitle(AppPage.files)),
        ),
        NavigationRailDestination(
          icon: Icon(_getPageIcon(AppPage.settings)),
          selectedIcon: Icon(_getPageIcon(AppPage.settings),
              color: Theme.of(context).colorScheme.primary),
          label: Text(_getPageTitle(AppPage.settings)),
        ),
      ],
    );
  }

  /// 构建底部导航栏（用于移动端）
  Widget _buildBottomNavigationBar(BuildContext context, int activeTaskCount) {
    final selectedPage = ref.watch(selectedPageProvider);

    int selectedIndex;
    if (selectedPage.index >= 2) {
      selectedIndex = selectedPage.index + 1;
    } else {
      selectedIndex = selectedPage.index;
    }

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        if (index == 2) {
          _showPlusMenu(context);
          return;
        }
        final pageIndex = index > 2 ? index - 1 : index;
        ref.read(selectedPageProvider.notifier).state =
            AppPage.values[pageIndex];
        _pageController.jumpToPage(pageIndex);
        if (AppPage.values[pageIndex] == AppPage.chat) {
          _resetChatNavigator();
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
          icon: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.85),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 16),
          ),
          selectedIcon: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 16),
          ),
          label: '',
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
  Widget _buildPageContent(AppPage page, int activeTaskCount) {
    switch (page) {
      case AppPage.home:
        return _buildHomeContent(activeTaskCount);
      case AppPage.chat:
        return _buildChatOrAssistantPage();
      case AppPage.files:
        return const FilesPage();
      case AppPage.settings:
        return const SettingsPage();
    }
  }

  /// 构建页面内容并附带 Key
  Widget _buildPageContentWithKey(AppPage page, int activeTaskCount) {
    return KeyedSubtree(
      key: ValueKey('page_${page.name}'),
      child: _buildPageContent(page, activeTaskCount),
    );
  }

  /// 构建模块化首页内容
  Widget _buildHomeContent(int activeTaskCount) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
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
                          builder: (_) => const UnifiedTaskListPage()),
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
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          // Module grid
          Expanded(
            child: GridView(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
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
                // Future modules can be added here
              ],
            ),
          ),
        ],
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
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
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
    ref.watch(selectedPageProvider);
    final catcatchTasks = ref.watch(catcatchTasksProvider);
    final synthesisTasks = ref.watch(taskListProvider);
    final lastRead = ref.watch(taskListLastReadProvider);
    final activeTaskCount =
        catcatchTasks
            .where((t) =>
              t.status.name != 'completed' && (
                (t.statusChangedAt ?? t.createdAt).isAfter(lastRead) ||
                (t.status.name == 'running' &&
                 t.steps.any((s) => s.type.name == 'userSelecting' && s.running))
              )
            ).length +
        synthesisTasks
            .where((t) => t.status.name != 'completed' && (t.statusChangedAt ?? t.createdAt).isAfter(lastRead))
            .length;

    ref.listen(catcatchTasksProvider, (prev, next) {
      if (!mounted) return;
      for (final task in next) {
        if (task.status.name == 'running' &&
            task.steps.any((s) => s.type.name == 'userSelecting' && s.running) &&
            task.detectedMedia.isNotEmpty &&
            task.selectedMedia == null) {
          _showMediaSelectionDialog(context, task);
          break;
        }
      }
    });

    return Scaffold(
      body: Row(
        children: [
          // 桌面端显示侧边栏导航
          if (!isMobile) _buildNavigationRail(context, activeTaskCount),
          // 页面内容区域，使用Expanded填充剩余空间
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                ref.read(selectedPageProvider.notifier).state =
                    AppPage.values[index];
              },
              children: AppPage.values.map((page) {
                return _buildPageContentWithKey(page, activeTaskCount);
              }).toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildBottomNavigationBar(context, activeTaskCount) : null,
    );
  }
}

String _formatDurationShort(String durationStr) {
  final parts = durationStr.split(':');
  if (parts.length != 3) return durationStr;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  final secPart = parts[2].split('.')[0];
  final s = int.tryParse(secPart) ?? 0;
  if (h > 0) return '${h}时${m}分${s}秒';
  if (m > 0) return '${m}分${s}秒';
  return '${s}秒';
}
