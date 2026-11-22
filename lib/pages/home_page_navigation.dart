part of 'home_page.dart';

/// The Material NavigationBar only accepts String labels. This equivalent
/// destination layout keeps its Material 3 sizing, colors and selection
/// indicator while allowing the shared constrained label to reveal overflow.
class _HomeBottomNavigationBar extends StatelessWidget {
  const _HomeBottomNavigationBar({
    required this.selectedIndex,
    required this.labels,
    required this.icons,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final List<String> labels;
  final List<IconData> icons;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final labelStyle = theme.textTheme.labelMedium!;
    final localizations = MaterialLocalizations.of(context);
    final labelMetrics = TextPainter(
      text: TextSpan(text: 'M', style: labelStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final navigationBarHeight = math.max(80.0, 64.0 + labelMetrics.height);

    return Material(
      color: colors.surfaceContainer,
      elevation: 3,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        child: SizedBox(
          height: navigationBarHeight,
          child: Semantics(
            key: const ValueKey('home-bottom-navigation'),
            role: SemanticsRole.tabBar,
            explicitChildNodes: true,
            container: true,
            child: Row(
              children: [
                for (var index = 0; index < labels.length; index++)
                  Expanded(
                    child: MergeSemantics(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Semantics(
                            role: SemanticsRole.tab,
                            label: labels[index],
                            selected: selectedIndex == index,
                            button: true,
                            child: Tooltip(
                              message: labels[index],
                              excludeFromSemantics: true,
                              verticalOffset: 42,
                              preferBelow: false,
                              child: InkWell(
                                customBorder: const StadiumBorder(),
                                onTap: () => onDestinationSelected(index),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 500,
                                      ),
                                      width: 64,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: selectedIndex == index
                                            ? colors.secondaryContainer
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(
                                        icons[index],
                                        color: selectedIndex == index
                                            ? colors.onSecondaryContainer
                                            : colors.onSurfaceVariant,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ExcludeSemantics(
                                      child: ConstrainedText(
                                        labels[index],
                                        style: labelStyle.copyWith(
                                          color: selectedIndex == index
                                              ? colors.onSurface
                                              : colors.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Semantics(
                            label: localizations.tabLabel(
                              tabIndex: index + 1,
                              tabCount: labels.length,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
        return AppLocalizations.of(context)!.navHome;
      case AppPage.chat:
        return AppLocalizations.of(context)!.navChat;
      case AppPage.files:
        return AppLocalizations.of(context)!.navFiles;
      case AppPage.settings:
        return AppLocalizations.of(context)!.navSettings;
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
          label: _buildNavigationLabel(AppPage.home),
        ),
        NavigationRailDestination(
          icon: Icon(_getPageIcon(AppPage.chat)),
          selectedIcon: Icon(
            _getPageIcon(AppPage.chat),
            color: Theme.of(context).colorScheme.primary,
          ),
          label: _buildNavigationLabel(AppPage.chat),
        ),
        NavigationRailDestination(
          icon: Icon(_getPageIcon(AppPage.files)),
          selectedIcon: Icon(
            _getPageIcon(AppPage.files),
            color: Theme.of(context).colorScheme.primary,
          ),
          label: _buildNavigationLabel(AppPage.files),
        ),
        NavigationRailDestination(
          icon: Icon(_getPageIcon(AppPage.settings)),
          selectedIcon: Icon(
            _getPageIcon(AppPage.settings),
            color: Theme.of(context).colorScheme.primary,
          ),
          label: _buildNavigationLabel(AppPage.settings),
        ),
      ],
    );
  }

  /// 构建底部导航栏（用于较高的竖向屏幕）
  Widget _buildBottomNavigationBar(BuildContext context) {
    final selectedPage = ref.watch(selectedPageProvider);

    return _HomeBottomNavigationBar(
      selectedIndex: selectedPage.index,
      labels: AppPage.values.map(_getPageTitle).toList(),
      icons: AppPage.values.map(_getPageIcon).toList(),
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
    );
  }

  Widget _buildNavigationLabel(AppPage page) {
    final title = _getPageTitle(page);
    return Semantics(
      label: title,
      excludeSemantics: true,
      child: ConstrainedText(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
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
        return TickerMode(
          enabled: ref.read(selectedPageProvider) == AppPage.home &&
              TickerMode.of(context),
          child: _buildHomeContent(),
        );
      case AppPage.chat:
        return _buildChatOrAssistantPage();
      case AppPage.files:
        return const FilesPage();
      case AppPage.settings:
        return const SettingsPage();
    }
  }
}
