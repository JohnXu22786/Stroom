import 'package:flutter/material.dart';
import '../models/tool_call.dart';

/// Shows the Chat Attachment Panel — a modal bottom sheet that consolidates
/// file attachment options, MCP tool toggles, and reasoning settings.
///
/// [tools] — list of available MCP tool definitions to display.
/// [reasoningEnabled] — current reasoning toggle state.
/// [reasoningEffort] — current reasoning effort level ('low', 'medium', 'high').
/// [enabledTools] — set of tool names that are currently enabled.
/// [onReasoningToggle] — called when the reasoning switch is toggled (new value).
/// [onReasoningEffortChange] — called when an effort level chip is tapped.
/// [onToolToggle] — called when a tool's switch is toggled (tool name, new enabled state).
/// [onPickFromCamera] — called when the camera option is tapped.
/// [onPickFromGallery] — called when the gallery option is tapped.
/// [onPickFromFilePicker] — called when the file picker option is tapped.
void showChatAttachmentPanel({
  required BuildContext context,
  required List<ToolDefinition> tools,
  required bool reasoningEnabled,
  required String reasoningEffort,
  required Set<String> enabledTools,
  required ValueChanged<bool> onReasoningToggle,
  required ValueChanged<String> onReasoningEffortChange,
  required void Function(String toolName, bool enabled) onToolToggle,
  required VoidCallback onPickFromCamera,
  required VoidCallback onPickFromGallery,
  required VoidCallback onPickFromFilePicker,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final cs = theme.colorScheme;

      // Local mutable state that persists across StatefulBuilder rebuilds.
      // These must be OUTSIDE the StatefulBuilder's builder function so they
      // are not re-initialized on every setSheetState call.
      var localReasoningEnabled = reasoningEnabled;
      var localReasoningEffort = reasoningEffort;
      var localEnabledTools = Set<String>.from(enabledTools);

      return StatefulBuilder(
        builder: (context, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            expand: false,
            builder: (context, scrollController) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      // ── Drag handle ──
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[350],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // ── Title ──
                      Text(
                        'Chat 设置',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ═══════════════════════════════════════════
                      // SECTION: 文件
                      // ═══════════════════════════════════════════
                      _SectionHeader(
                        icon: Icons.attach_file_outlined,
                        title: '文件',
                        color: cs.primary,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _FileActionButton(
                            icon: Icons.camera_alt_outlined,
                            label: '拍照',
                            color: Colors.orange,
                            onTap: () {
                              Navigator.pop(context);
                              onPickFromCamera();
                            },
                          ),
                          _FileActionButton(
                            icon: Icons.photo_library_outlined,
                            label: '相册',
                            color: Colors.blue,
                            onTap: () {
                              Navigator.pop(context);
                              onPickFromGallery();
                            },
                          ),
                          _FileActionButton(
                            icon: Icons.insert_drive_file_outlined,
                            label: '文件',
                            color: Colors.green,
                            onTap: () {
                              Navigator.pop(context);
                              onPickFromFilePicker();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ═══════════════════════════════════════════
                      // SECTION: 工具
                      // ═══════════════════════════════════════════
                      _SectionHeader(
                        icon: Icons.build_outlined,
                        title: '工具',
                        color: cs.tertiary,
                      ),
                      const SizedBox(height: 8),
                      if (tools.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text(
                              '暂无可用工具',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      else
                        ...tools.map((tool) => _ToolToggleTile(
                              tool: tool,
                              isEnabled: localEnabledTools.contains(tool.name),
                              onToggle: (enabled) {
                                setSheetState(() {
                                  if (enabled) {
                                    localEnabledTools.add(tool.name);
                                  } else {
                                    localEnabledTools.remove(tool.name);
                                  }
                                  onToolToggle(tool.name, enabled);
                                });
                              },
                            )),
                      const SizedBox(height: 24),

                      // ═══════════════════════════════════════════
                      // SECTION: 推理设置
                      // ═══════════════════════════════════════════
                      _SectionHeader(
                        icon: Icons.psychology_outlined,
                        title: '推理设置',
                        color: Colors.purple,
                      ),
                      const SizedBox(height: 8),
                      // Reasoning toggle row
                      Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '推理',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            Switch(
                              value: localReasoningEnabled,
                              activeColor: cs.primary,
                              onChanged: (value) {
                                setSheetState(() {
                                  localReasoningEnabled = value;
                                  onReasoningToggle(value);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      // Reasoning effort level chips
                      if (localReasoningEnabled) ...[
                        const SizedBox(height: 12),
                        Text(
                          '推理强度',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _EffortChip(
                              label: '低',
                              value: 'low',
                              selected: localReasoningEffort == 'low',
                              onSelected: () {
                                setSheetState(() {
                                  localReasoningEffort = 'low';
                                  onReasoningEffortChange('low');
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            _EffortChip(
                              label: '中',
                              value: 'medium',
                              selected: localReasoningEffort == 'medium',
                              onSelected: () {
                                setSheetState(() {
                                  localReasoningEffort = 'medium';
                                  onReasoningEffortChange('medium');
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            _EffortChip(
                              label: '高',
                              value: 'high',
                              selected: localReasoningEffort == 'high',
                              onSelected: () {
                                setSheetState(() {
                                  localReasoningEffort = 'high';
                                  onReasoningEffortChange('high');
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}

// ═══════════════════════════════════════════════════════════════
// Private helper widgets
// ═══════════════════════════════════════════════════════════════

/// Section header with leading icon and title text.
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

/// A large icon button for file actions (camera, gallery, file).
class _FileActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FileActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 26, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A toggle tile for an MCP tool with name and switch.
class _ToolToggleTile extends StatelessWidget {
  final ToolDefinition tool;
  final bool isEnabled;
  final ValueChanged<bool> onToggle;

  const _ToolToggleTile({
    required this.tool,
    required this.isEnabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: SwitchListTile(
          dense: true,
          value: isEnabled,
          onChanged: onToggle,
          activeColor: cs.primary,
          title: Text(
            tool.name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          subtitle: tool.description.isNotEmpty
              ? Text(
                  tool.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// A chip/button for selecting reasoning effort level.
class _EffortChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onSelected;

  const _EffortChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onSelected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected
                      ? cs.onPrimaryContainer
                      : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _effortDescription(value),
                style: TextStyle(
                  fontSize: 10,
                  color: selected
                      ? cs.onPrimaryContainer.withOpacity(0.7)
                      : cs.onSurfaceVariant.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _effortDescription(String level) {
    switch (level) {
      case 'low':
        return '快速响应';
      case 'medium':
        return '平衡';
      case 'high':
        return '深度思考';
      default:
        return '';
    }
  }
}
