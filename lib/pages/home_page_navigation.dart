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
      // Flutter 默认的 defaultGenerateInitialRoutes 会把带多段路径的
      // initialRoute 拆成祖先路由：'/' + '/assistant-selection'。而下面
      // onGenerateRoute 的 default 分支会把 '/' 也渲染成
      // AssistantSelectionPage，导致根路由之下还压着一个"幽灵"助手选择页。
      // 此时在助手选择页按返回键/双击对话标签会先弹掉顶层页面（带返回
      // 动画）却仍停在助手选择页（弹到了幽灵页），看起来返回无效；只有
      // 再按一次才会真正回到主页。这里只生成真正的根路由，保持路由栈为
      // 单根，返回/双击行为恢复预期。
      onGenerateInitialRoutes: (navigator, initialRoute) {
        // onGenerateRoute 的 switch 含 default 分支，对任意名称（含 null）
        // 都返回非空路由，因此这里不会返回 null。
        final route = navigator.widget.onGenerateRoute!(
          RouteSettings(name: initialRoute),
        );
        return [route!];
      },
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
              // Keep this const: whenever HomePage rebuilds (tab switch,
              // rotation, window resize, ...) this route builder re-runs
              // (Navigator.didUpdateWidget → changedExternalState → page
              // cache cleared). The const lets the framework's identical-
              // instance fast path skip rebuilding the whole chat page —
              // which would otherwise re-parse every visible markdown
              // message, a heavy cost on every rebuild. (HomePage itself
              // no longer rebuilds per keyboard frame — see home_page.dart
              // _isPortrait.)
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
