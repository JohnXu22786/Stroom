import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart' as main_lib;
import 'catcatch_page.dart';
import 'unified_task_list_page.dart';
import '../catcatch/providers/catcatch_provider.dart';
import '../catcatch/models/catcatch_task.dart' as catcatch_task;
import '../catcatch/models/media_resource.dart';
import '../providers/task_provider.dart';
import 'chat_page.dart';
import 'files_page.dart';
import 'settings_page.dart';
import 'camera_page.dart';
import 'tts_create_page.dart';
import 'video_capture_page.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/camera_choice_dialog.dart';

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
    final selectedMedia = <String, MediaResource?>{};
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final mediaList = task.detectedMedia;
          MediaResource? current = selectedMedia[task.id];
          return AlertDialog(
            title: const Text('选择要下载的资源'),
            content: SizedBox(
              width: double.maxFinite,
              child: mediaList.length > 1
                  ? ListView.builder(
                      shrinkWrap: true,
                      itemCount: mediaList.length,
                      itemBuilder: (_, i) {
                        final media = mediaList[i];
                        final isSel = current?.url == media.url;
                        final isAudio = ['mp3', 'wav', 'm4a', 'aac', 'opus', 'weba'].contains(media.ext.toLowerCase());
                        return ListTile(
                          leading: Icon(isAudio ? Icons.audiotrack : Icons.videocam, color: isAudio ? Colors.purple : Colors.blue),
                          title: Text('${media.name}.${media.ext}'),
                          subtitle: media.duration != null ? Text('时长: ${media.duration}') : null,
                          trailing: Icon(isSel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              color: isSel ? Theme.of(ctx).colorScheme.primary : Colors.grey),
                          onTap: () {
                            setDlgState(() {
                              current = media;
                              selectedMedia[task.id] = media;
                            });
                          },
                        );
                      },
                    )
                  : Center(child: Text('检测到 ${mediaList.length} 个资源，自动选择')),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              FilledButton(
                onPressed: mediaList.length == 1
                    ? () {
                        Navigator.pop(ctx);
                        ref.read(catcatchTasksProvider.notifier).selectMedia(task.id, mediaList.first);
                      }
                    : (current != null
                        ? () {
                            Navigator.pop(ctx);
                            ref.read(catcatchTasksProvider.notifier).selectMedia(task.id, current!);
                          }
                        : null),
                child: const Text('确认下载'),
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
          showCameraChoiceDialog(context).then((choice) {
            if (choice == CameraChoice.app) {
              navigator.push(
                MaterialPageRoute(builder: (_) => const CameraPage()),
              );
            } else if (choice == CameraChoice.system) {
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
          navigator.push(
            MaterialPageRoute(builder: (_) => const VideoCapturePage()),
          );
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

  /// 构建页面内容
  Widget _buildPageContent(AppPage page) {
    switch (page) {
      case AppPage.home:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.home, size: 64, color: Colors.blue),
              SizedBox(height: 16),
              Text(
                '欢迎使用 Stroom',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '一个结合了 FlClash UI 架构和相机功能的示例应用',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      case AppPage.chat:
        return const ChatPage();
      case AppPage.files:
        return const FilesPage();
      case AppPage.settings:
        return const SettingsPage();
    }
  }

  /// 构建页面内容并附带 Key
  Widget _buildPageContentWithKey(AppPage page) {
    return KeyedSubtree(
      key: ValueKey('page_${page.name}'),
      child: _buildPageContent(page),
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
    final lastRead = ref.watch(taskListLastReadProvider);
    final activeTaskCount =
        catcatchTasks
            .where((t) => t.status.name != 'completed' && (t.statusChangedAt ?? t.createdAt).isAfter(lastRead))
            .length +
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
      body: Stack(
        children: [
          Row(
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
                    return _buildPageContentWithKey(page);
                  }).toList(),
                ),
              ),
            ],
          ),
          // 右上角任务列表入口（仅在首页显示）
          if (selectedPage == AppPage.home)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: IconButton(
                icon: Badge(
                  isLabelVisible: activeTaskCount > 0,
                  label: Text('$activeTaskCount'),
                  child: const Icon(Icons.pending_actions),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UnifiedTaskListPage()),
                  );
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildBottomNavigationBar(context, activeTaskCount) : null,
    );
  }
}
