import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'home_shared.dart';

import '../main.dart' as main_lib;
import 'assistant_selection_page.dart';
import 'files_page_shared.dart';
import 'topic_selection_page.dart';
import 'catcatch_page.dart';
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
import 'anki_page.dart';

part 'home_page_navigation.dart';
part 'home_page_home_content.dart';
part 'home_page_media_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    // 备份由 Application._runPostStartupTasks 在启动后自动触发。
    // 生命周期取消备份由 Application.didChangeAppLifecycleState 统一处理。
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

  @override
  Widget build(BuildContext context) {
    // 在启动时消费 catcatchStartupProvider，触发 restoreUnfinishedTasks
    ref.watch(main_lib.catcatchStartupProvider);

    final isMobile = _isMobile(context);
    final selectedPage = ref.watch(selectedPageProvider);

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
            if (!isMobile) _buildNavigationRail(context),
            // Page content area. Widgets are rebuilt on navigation
            // (no IndexedStack keep-alive) because ChatStreamManager
            // now handles background streaming independently.
            Expanded(
              child: _buildPageContent(AppPage.values[selectedPage.index]),
            ),
          ],
        ),
        bottomNavigationBar:
            isMobile ? _buildBottomNavigationBar(context) : null,
      ),
    );
  }
}
