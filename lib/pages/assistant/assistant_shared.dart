import 'package:flutter/material.dart';

import '../../models/assistant.dart';
import '../../utils/emojis.dart';
import '../../widgets/llm/assistant_avatar.dart';

class AssistantCard extends StatelessWidget {
  final Assistant assistant;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const AssistantCard({
    super.key,
    required this.assistant,
    required this.onTap,
    required this.onLongPress,
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
          color: cs.outlineVariant.withOpacity(0.5),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
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
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  assistant.prompt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurfaceVariant.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
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
