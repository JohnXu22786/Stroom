import 'package:flutter/material.dart';

import '../../models/assistant.dart';
import '../../utils/emojis.dart';
import '../../widgets/llm/assistant_avatar.dart';

class AssistantCard extends StatelessWidget {
  final Assistant assistant;
  final VoidCallback onTap;

  /// 卡片右上角 ⋮ 按钮按下回调：打开编辑/删除菜单。
  /// （长按手势已让给拖拽排序，见 AssistantSelectionPage。）
  final VoidCallback onMenu;

  const AssistantCard({
    super.key,
    required this.assistant,
    required this.onTap,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AssistantAvatar(assistant: assistant, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    assistant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (assistant.description.isNotEmpty)
                    Text(
                      assistant.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            // 右上角菜单按钮：内部的点击优先于卡片 InkWell 的 onTap
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: Icon(Icons.more_vert, size: 18, color: cs.onSurfaceVariant),
                tooltip: '更多操作',
                onPressed: onMenu,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small square showing the current emoji. Tapping it opens the emoji
/// picker panel ([CategorizedEmojiPicker] in a dialog). Replaces the
/// always-visible inline picker in the assistant editors so the dialog can
/// give more space to the system prompt field.
class EmojiAvatarButton extends StatelessWidget {
  final String selectedEmoji;
  final ValueChanged<String> onEmojiSelected;
  final double size;

  const EmojiAvatarButton({
    super.key,
    required this.selectedEmoji,
    required this.onEmojiSelected,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      message: '选择表情',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showPickerPanel(context),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                selectedEmoji,
                style: TextStyle(fontSize: size * 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPickerPanel(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择表情'),
        content: CategorizedEmojiPicker(
          selectedEmoji: selectedEmoji,
          onEmojiSelected: (e) {
            onEmojiSelected(e);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
}

/// Shared form for the assistant create/edit dialogs: emoji square + name
/// row, description, and the system prompt editor.
///
/// When the window is tall enough the system prompt expands to fill all
/// remaining space. On very short windows the fixed rows above the prompt
/// would overflow the dialog (an [Expanded] shrinks to zero but never
/// reflows its fixed siblings), so a scrollable layout with a fixed-height
/// prompt is used instead — the dialog can never overflow.
class AssistantEditorFields extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController promptController;
  final String selectedEmoji;
  final ValueChanged<String> onEmojiSelected;
  final bool autofocusName;
  final String? nameHint;
  final String? descriptionHint;

  const AssistantEditorFields({
    super.key,
    required this.nameController,
    required this.descriptionController,
    required this.promptController,
    required this.selectedEmoji,
    required this.onEmojiSelected,
    this.autofocusName = false,
    this.nameHint,
    this.descriptionHint,
  });

  /// Windows below this height use the scrollable fallback layout.
  /// Scaled by the text scale factor: the fixed rows above the prompt grow
  /// with font scaling, so the fill layout needs proportionally more height
  /// to avoid overflowing (e.g. accessibility text scaling on short windows).
  static const double minFillWindowHeight = 540;

  Widget _promptField() => TextField(
        controller: promptController,
        decoration: const InputDecoration(
          labelText: '系统提示词',
          border: OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
      );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final fillPrompt =
        media.size.height >= minFillWindowHeight * media.textScaler.scale(1.0);

    final fields = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          EmojiAvatarButton(
            selectedEmoji: selectedEmoji,
            onEmojiSelected: onEmojiSelected,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: '助手名称',
                hintText: nameHint,
                border: const OutlineInputBorder(),
              ),
              autofocus: autofocusName,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      TextField(
        controller: descriptionController,
        decoration: InputDecoration(
          labelText: '描述（可选）',
          hintText: descriptionHint,
          border: const OutlineInputBorder(),
        ),
        maxLines: 2,
      ),
      const SizedBox(height: 12),
    ];

    if (fillPrompt) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...fields,
          Expanded(child: _promptField()),
        ],
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...fields,
          SizedBox(height: 180, child: _promptField()),
        ],
      ),
    );
  }
}

class CategorizedEmojiPicker extends StatelessWidget {
  final String selectedEmoji;
  final ValueChanged<String> onEmojiSelected;

  const CategorizedEmojiPicker({
    super.key,
    required this.selectedEmoji,
    required this.onEmojiSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final categories = EmojiCategories.categories;

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 320,
          child: DefaultTabController(
            length: categories.length,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 36,
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: categories.map((cat) {
                      return Tab(
                        child: Text(
                          cat.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(
                  height: 180,
                  child: TabBarView(
                    children: categories.map((cat) {
                      return GridView.builder(
                        padding: const EdgeInsets.only(top: 4),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                          childAspectRatio: 1,
                        ),
                        itemCount: cat.emojis.length,
                        itemBuilder: (ctx, index) {
                          final e = cat.emojis[index];
                          final isSelected = e == selectedEmoji;
                          return GestureDetector(
                            onTap: () => onEmojiSelected(e),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? cs.primaryContainer : null,
                                borderRadius: BorderRadius.circular(6),
                                border: isSelected
                                    ? Border.all(color: cs.primary)
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  e,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
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
