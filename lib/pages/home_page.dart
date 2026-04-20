import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import the pages (we'll create them next)
import 'camera_page.dart';
import 'gallery_page.dart';
import 'settings_page.dart';
import 'audio_page.dart';

/// 页面枚举，定义应用中的主要页面
enum AppPage {
  home,
  camera,
  gallery,
  settings,
  audio,
}

/// 当前选中页面的状态提供器
final selectedPageProvider = StateProvider<AppPage>((ref) => AppPage.home);

/// 主页，采用FlClash风格的响应式布局：
/// - 移动端：底部导航栏 + PageView
/// - 桌面端：侧边栏导航 + PageView
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  // 用于PageView的控制器，实现滑动切换页面
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
      case AppPage.camera:
        return Icons.camera_alt;
      case AppPage.gallery:
        return Icons.photo_library;
      case AppPage.settings:
        return Icons.settings;
      case AppPage.audio:
        return Icons.audiotrack;
    }
  }

  /// 获取页面对应的标题（后续可国际化）
  String _getPageTitle(AppPage page) {
    switch (page) {
      case AppPage.home:
        return '主页';
      case AppPage.camera:
        return '相机';
      case AppPage.gallery:
        return '相册';
      case AppPage.settings:
        return '设置';
      case AppPage.audio:
        return '录音';
    }
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
      case AppPage.camera:
        return const CameraPage();
      case AppPage.gallery:
        return const GalleryPage();
      case AppPage.settings:
        return const SettingsPage();
      case AppPage.audio:
        return const AudioPage();
    }
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
                return _buildPageContent(page);
              }).toList(),
            ),
          ),
        ],
      ),
      // 移动端显示底部导航栏
      bottomNavigationBar: isMobile ? _buildBottomNavigationBar(context) : null,
    );
  }
}
