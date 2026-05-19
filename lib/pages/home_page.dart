import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart' as main_lib;
import 'catcatch_page.dart';
import '../catcatch/providers/catcatch_provider.dart';
import '../catcatch/models/catcatch_task.dart';
import 'chat_page.dart';
import 'files_page.dart';
import 'settings_page.dart';
import 'camera_page.dart';
import 'tts_create_page.dart';
import 'video_capture_page.dart';

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

  /// 显示加号弹出的菜单
  void _showPlusMenu(BuildContext context) {
    final navigator = Navigator.of(context);
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        Offset(renderBox.size.width / 2 - 100, renderBox.size.height - 200),
        Offset(renderBox.size.width / 2 + 100, renderBox.size.height),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem(
          value: 'catcatch',
          child: ListTile(
            leading: Icon(Icons.language, color: Colors.purple),
            title: Text('获取网页视频'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'record',
          child: ListTile(
            leading: Icon(Icons.mic, color: Colors.blue),
            title: Text('录音'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'capture',
          child: ListTile(
            leading: Icon(Icons.camera_alt, color: Colors.green),
            title: Text('拍摄'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'capture_video',
          child: ListTile(
            leading: Icon(Icons.videocam, color: Colors.red),
            title: Text('录像'),
            dense: true,
            contentPadding: EdgeInsets.zero,
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
          navigator.push(
            MaterialPageRoute(builder: (_) => const CameraPage()),
          );
          break;
        case 'capture_video':
          navigator.push(
            MaterialPageRoute(builder: (_) => const VideoCapturePage()),
          );
          break;
      }
    });
  }

  /// 构建侧边栏导航（用于桌面端）
  Widget _buildNavigationRail(BuildContext context) {
    final selectedPage = ref.watch(selectedPageProvider);

    int selectedIndex;
    if (selectedPage.index >= 2) {
      selectedIndex = selectedPage.index + 1;
    } else {
      selectedIndex = selectedPage.index;
    }

    return NavigationRail(
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
          icon: Icon(_getPageIcon(AppPage.home)),
          selectedIcon: Icon(_getPageIcon(AppPage.home),
              color: Theme.of(context).colorScheme.primary),
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
  Widget _buildBottomNavigationBar(BuildContext context) {
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
          icon: Icon(_getPageIcon(AppPage.home)),
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
    final runningTasksCount = ref
        .watch(catcatchTasksProvider)
        .where((t) => t.status == TaskStatus.running)
        .length;

    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              // 桌面端显示侧边栏导航
              if (!isMobile) _buildNavigationRail(context),
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
          // 右上角任务列表入口
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: IconButton(
              icon: Badge(
                isLabelVisible: runningTasksCount > 0,
                label: Text('$runningTasksCount'),
                child: const Icon(Icons.assignment_outlined),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CatCatchPage()),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildBottomNavigationBar(context) : null,
    );
  }
}
