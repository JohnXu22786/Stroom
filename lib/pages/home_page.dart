import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// - 移动端：底部导航栏（主页、对话、文件、设置）+ 浮动加号按钮
/// - 桌面端：侧边栏导航
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _plusAnimationController;
  late Animation<double> _plusRotation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: AppPage.home.index);
    _plusAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _plusRotation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(
          parent: _plusAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _plusAnimationController.dispose();
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
      // 关闭菜单后复位加号旋转
      _plusAnimationController.reverse();
      if (value == null) return;

      switch (value) {
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

    return NavigationRail(
      selectedIndex: selectedPage.index,
      onDestinationSelected: (index) {
        ref.read(selectedPageProvider.notifier).state = AppPage.values[index];
        _pageController.jumpToPage(index);
      },
      labelType: NavigationRailLabelType.all,
      destinations: AppPage.values.map((page) {
        return NavigationRailDestination(
          icon: Icon(_getPageIcon(page)),
          selectedIcon: Icon(_getPageIcon(page),
              color: Theme.of(context).colorScheme.primary),
          label: Text(_getPageTitle(page)),
        );
      }).toList(),
    );
  }

  /// 构建底部导航栏（用于移动端）
  Widget _buildBottomNavigationBar(BuildContext context) {
    final selectedPage = ref.watch(selectedPageProvider);

    return NavigationBar(
      selectedIndex: selectedPage.index,
      onDestinationSelected: (index) {
        ref.read(selectedPageProvider.notifier).state = AppPage.values[index];
        _pageController.jumpToPage(index);
      },
      destinations: AppPage.values.map((page) {
        return NavigationDestination(
          icon: Icon(_getPageIcon(page)),
          label: _getPageTitle(page),
        );
      }).toList(),
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

  Widget _buildPlusButton(BuildContext context) {
    return AnimatedBuilder(
      animation: _plusRotation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _plusRotation.value * 2 * pi,
          child: child,
        );
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primary,
          boxShadow: [
            BoxShadow(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IconButton(
          key: const Key('plus_action_button'),
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: () {
            _plusAnimationController.forward();
            _showPlusMenu(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = _isMobile(context);

    return Scaffold(
      body: Row(
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
      // 桌面端：浮动加号按钮
      floatingActionButton: !isMobile
          ? FloatingActionButton(
              key: const Key('desktop_plus_fab'),
              onPressed: () {
                _plusAnimationController.forward();
                _showPlusMenu(context);
              },
              child: AnimatedBuilder(
                animation: _plusRotation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _plusRotation.value * 2 * pi,
                    child: child,
                  );
                },
                child: const Icon(Icons.add),
              ),
            )
          : null,
      // 移动端：底部导航栏 + 浮动加号按钮
      bottomNavigationBar: isMobile
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                _buildBottomNavigationBar(context),
                // 加号按钮 - 定位在导航栏上方中央
                Positioned(
                  top: -16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _buildPlusButton(context),
                  ),
                ),
              ],
            )
          : null,
    );
  }
}
