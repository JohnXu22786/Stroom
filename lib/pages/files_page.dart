import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'gallery_page.dart';
import 'text_storage_page.dart';
import 'tts_page.dart';
import 'video_gallery_page.dart';

/// Tab order provider - allows reordering the tabs
final fileTabOrderProvider = StateProvider<List<int>>((ref) => [0, 1, 2, 3]);

/// Refresh signal provider - increment to trigger refresh of files sub-pages
final filesRefreshSignalProvider = StateProvider<int>((ref) => 0);

/// 文件页面 - 包含文本、图片、视频和音频四个标签页，支持左右滑动切换和标签排序
class FilesPage extends ConsumerStatefulWidget {
  const FilesPage({super.key});

  @override
  ConsumerState<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends ConsumerState<FilesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static const _tabLabels = ['文本', '音频', '图片', '视频'];

  @override
  Widget build(BuildContext context) {
    final tabOrder = ref.watch(fileTabOrderProvider);
    final refreshSignal = ref.watch(filesRefreshSignalProvider);

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
                tabs: tabOrder.map((i) => Tab(text: _tabLabels[i])).toList(),
              ),
            ),
          ),
          // Content area - each page handles its own Scaffold
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: tabOrder.map((i) {
                switch (i) {
                  case 0:
                    return TextStoragePage(
                        key: ValueKey('text_storage_$refreshSignal'));
                  case 1:
                    return TtsPage(key: ValueKey('tts_$refreshSignal'));
                  case 2:
                    return GalleryPage(key: ValueKey('gallery_$refreshSignal'));
                  case 3:
                    return VideoGalleryPage(
                        key: ValueKey('video_gallery_$refreshSignal'));
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
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ReorderableListView(
                    shrinkWrap: true,
                    onReorder: (oldIndex, newIndex) {
                      setDialogState(() {
                        if (newIndex > oldIndex) newIndex--;
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
