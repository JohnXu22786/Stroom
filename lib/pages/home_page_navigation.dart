part of 'home_page.dart';

extension _HomePageNavigationExt on _HomePageState {
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

  /// 构建侧边栏导航（用于较宽的横向屏幕）
  Widget _buildNavigationRail(BuildContext context) {
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
          icon: Icon(_getPageIcon(AppPage.home)),
          selectedIcon: Icon(
            _getPageIcon(AppPage.home),
            color: Theme.of(context).colorScheme.primary,
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

  /// 构建底部导航栏（用于较高的竖向屏幕）
  Widget _buildBottomNavigationBar(BuildContext context) {
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
          icon: Icon(_getPageIcon(AppPage.home)),
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

  /// 聊天标签页内容：嵌套导航器，以助手选择页为根路由。
  /// 用户流程：选择助手 → 选择话题 → 聊天页面。
  /// 切换其他标签页时该嵌套导航器及其中间路由栈保持不变（状态保留）；
  /// 再次点击对话标签（双击）时由 [_HomePageState._resetChatNavigator]
  /// 重置到根路由（助手选择页）。
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
}
