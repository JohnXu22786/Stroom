import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'files_page_shared.dart';
import 'gallery_page.dart';
import 'text_storage_page.dart';
import 'tts_page.dart';
import 'video_gallery_page.dart';

/// Tab order provider - allows reordering the tabs
final fileTabOrderProvider = StateProvider<List<int>>((ref) => [0, 1, 2, 3]);

/// 文件页面 - 包含文本、图片、视频和音频四个标签页，支持标签排序
/// 使用 IndexedStack 保持各标签页的导航状态（如已打开的文件夹）在切换时不变。
class FilesPage extends ConsumerStatefulWidget {
  const FilesPage({super.key});

  @override
  ConsumerState<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends ConsumerState<FilesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Track the last tapped logical tab index for double-tap detection.
  /// Uses the logical tab ID (0-3) instead of physical position, so tab
  /// reordering does not cause false resets.
  /// Initialized to -1 so the first tap never triggers a reset.
  int _lastTappedLogicalTabIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabControllerChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabControllerChanged);
    _tabController.dispose();
    super.dispose();
  }

  /// Trigger a rebuild when the tab index changes so [IndexedStack] shows
  /// the correct child. Without this listener the build method would not be
  /// called on tab switch, leaving [IndexedStack] stuck on the old index.
  void _onTabControllerChanged() {
    setState(() {});
  }

  static const _tabLabels = ['文本', '音频', '图片', '视频'];

  void _onTabTapped(int physicalIndex) {
    // Map physical position → logical tab index via the current order.
    final tabOrder = ref.read(fileTabOrderProvider);
    final logicalIndex = tabOrder[physicalIndex];
    if (logicalIndex == _lastTappedLogicalTabIndex) {
      // Same tab tapped again → reset to root (home).
      ref.read(fileTabFolderResetSignalProvider(logicalIndex).notifier).state++;
    }
    _lastTappedLogicalTabIndex = logicalIndex;
  }

  @override
  Widget build(BuildContext context) {
    final tabOrder = ref.watch(fileTabOrderProvider);

    return SafeArea(
      top: true,
      child: Column(
        key: const Key('files_page'),
        children: [
          // Tab bar for switching between file type sections
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: GestureDetector(
              key: const Key('files_tab_bar_gesture'),
              onLongPress: () => _showReorderDialog(context, tabOrder),
              child: TabBar(
                controller: _tabController,
                onTap: _onTabTapped,
                tabs: tabOrder.map((i) => Tab(text: _tabLabels[i])).toList(),
              ),
            ),
          ),
          // Content area - each page handles its own Scaffold
          // Uses IndexedStack instead of TabBarView to keep all tab children
          // alive in the widget tree, preserving their navigation state (e.g.
          // open subfolders) when the user switches between tabs. Only the
          // visible tab is rendered, but inactive tabs retain their State.
          Expanded(
            child: IndexedStack(
              index: _tabController.index,
              children: tabOrder.map((i) {
                final isActiveTab = tabOrder[_tabController.index] == i;
                // 按键仅包含逻辑标签索引（不含 filesRefreshSignalProvider）：
                // 标签排序后各页面的 State（如已打开的文件夹）按逻辑标签保留，
                // 重新进入文件页时的自动刷新只重载数据（由各子页面监听
                // filesRefreshSignalProvider 完成），不重建页面，因此
                // 已打开的文件夹层级在切换底部导航后保持不变。
                switch (i) {
                  case 0:
                    return TextStoragePage(
                      key: ValueKey('text_storage_$i'),
                      tabIndex: 0,
                      isActiveTab: isActiveTab,
                    );
                  case 1:
                    return TtsPage(
                      key: ValueKey('tts_$i'),
                      tabIndex: 1,
                      isActiveTab: isActiveTab,
                    );
                  case 2:
                    return GalleryPage(
                      key: ValueKey('gallery_$i'),
                      tabIndex: 2,
                      isActiveTab: isActiveTab,
                    );
                  case 3:
                    return VideoGalleryPage(
                      key: ValueKey('video_gallery_$i'),
                      tabIndex: 3,
                      isActiveTab: isActiveTab,
                    );
                  default:
                    return const SizedBox.shrink();
                }
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showReorderDialog(BuildContext context, List<int> currentOrder) {
    // 保存当前正在查看的逻辑标签 ID，以便排序后保持选中状态
    final currentLogicalTab = currentOrder[_tabController.index];

    showDialog(
      context: context,
      builder: (ctx) {
        final order = List<int>.from(currentOrder);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              key: const Key('files_reorder_dialog'),
              title: const Text('排序标签'),
              // 内容可滚动：短屏（如横屏手机）上不会溢出
              scrollable: true,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 给 ReorderableListView 一个有界尺寸：
                  // shrinkWrap 视口在 AlertDialog 的 intrinsic 测量下会崩溃
                  SizedBox(
                    width: double.maxFinite,
                    height: 280,
                    child: ReorderableListView(
                      onReorderItem: (oldIndex, newIndex) {
                        // 注意：onReorderItem 的 newIndex 已经是
                        // 移除 oldIndex 项之后调整过的索引，
                        // 不能再做 `if (newIndex > oldIndex) newIndex--;`
                        // （那是旧 onReorder 回调的写法，双重调整会导致
                        // 向下拖一格无效）
                        setDialogState(() {
                          final item = order.removeAt(oldIndex);
                          order.insert(newIndex, item);
                        });
                      },
                      children: order.map((i) {
                        return ListTile(
                          key: Key('files_tab_order_$i'),
                          leading: const Icon(Icons.drag_handle),
                          title: Text(_tabLabels[i]),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  key: const Key('files_reorder_cancel_btn'),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                TextButton(
                  key: const Key('files_reorder_confirm_btn'),
                  onPressed: () {
                    // 更新顺序
                    ref.read(fileTabOrderProvider.notifier).state = order;
                    // 重新映射 TabController 索引，保持当前查看的标签不变
                    final newIndex = order.indexOf(currentLogicalTab);
                    if (newIndex >= 0 && newIndex != _tabController.index) {
                      _tabController.index = newIndex;
                    }
                    // 重置双击检测状态，避免排序后第一次点按当前标签
                    // 触发误判的「双击重置到根目录」
                    _lastTappedLogicalTabIndex = -1;
                    Navigator.pop(ctx);
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
