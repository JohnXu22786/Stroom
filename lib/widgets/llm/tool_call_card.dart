import 'package:flutter/material.dart';
import '../../models/tool_call.dart';
import '../../services/context_manager.dart'
    show kCompactedToolResultPlaceholder;

/// 工具调用卡片。
///
/// 折叠交互：
/// - 调用进行中（[ToolCallStatus.pending] / [ToolCallStatus.running]）：
///   始终展开显示参数与结果，不可折叠；
/// - 调用完成（[ToolCallStatus.completed] / [ToolCallStatus.error]）：
///   自动收起为一行（仅工具名称），失败时名称为红色，点击可展开/收起。
class ToolCallCard extends StatefulWidget {
  final ToolCallData data;

  const ToolCallCard({super.key, required this.data});

  @override
  State<ToolCallCard> createState() => _ToolCallCardState();
}

class _ToolCallCardState extends State<ToolCallCard> {
  bool _expanded = false;

  /// 调用结束后才可折叠。进行中时点击为 no-op（见 [_toggle]），
  /// 且状态退回进行中时 [didUpdateWidget] 会重置 _expanded，
  /// 因此状态一转为 completed/error 即自动收起。
  bool get _collapsible =>
      widget.data.status == ToolCallStatus.completed ||
      widget.data.status == ToolCallStatus.error;

  bool get _showDetails => _expanded || !_collapsible;

  @override
  void didUpdateWidget(ToolCallCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 重置展开状态：
    // - 新工具调用复用同一 element（例如列表原地替换）时；
    // - 状态从可折叠（completed/error）退回进行中（pending/running）时
    //   （同 id 重跑场景），保证"完成后自动收起"的不变量始终成立。
    final oldCollapsible = oldWidget.data.status == ToolCallStatus.completed ||
        oldWidget.data.status == ToolCallStatus.error;
    if (oldWidget.data.id != widget.data.id ||
        (oldCollapsible && !_collapsible)) {
      _expanded = false;
    }
  }

  void _toggle() {
    // onTap 无条件挂载，由此处统一决定是否可折叠：
    // 进行中（pending/running）卡片点击为 no-op，绝不收起。
    if (!_collapsible) return;
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;

    final statusColor = switch (data.status) {
      ToolCallStatus.running => Colors.orange,
      ToolCallStatus.completed => Colors.green,
      ToolCallStatus.error => Colors.red,
      ToolCallStatus.pending => Colors.grey,
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      // 收起态也保持整卡全宽：展开态的结果容器（width: double.infinity）
      // 恒为全宽，若收起态收缩为内容宽，切换时会水平跳动。
      width: double.infinity,
      child: GestureDetector(
        // opaque：让整张卡片（含参数/结果之间的空白区域）都可点击，
        // 否则点击落在空白处会命中测试穿透而不触发切换。
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        // GestureDetector 包在装饰外层，使含 10px 内边距环带在内的
        // 整张卡片都可点击。
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.troubleshoot, size: 16, color: statusColor),
                  const SizedBox(width: 6),
                  // Flexible + ellipsis：长工具名（如 MCP 工具）在收起态
                  // 单行省略、不溢出、不换行；展开态允许换行完整显示。
                  Flexible(
                    child: Text(
                      data.name,
                      maxLines: _showDetails ? null : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        // 失败的调用名称显示为红色（收起与展开时一致）。
                        color: data.status == ToolCallStatus.error
                            ? Colors.red
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (data.compactedAt != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '已压缩',
                        style: TextStyle(fontSize: 10, color: Colors.blueGrey),
                      ),
                    ),
                  if (data.status == ToolCallStatus.running)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: statusColor,
                      ),
                    ),
                  // 可折叠卡片才显示展开/收起箭头，提示可点击。
                  if (_collapsible) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _showDetails ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ],
                ],
              ),
              if (_showDetails) ...[
                if (data.arguments.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatArgs(data.arguments),
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
                if (data.result != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border:
                          Border.all(color: borderColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      // 软删除语义：compacted 后渲染占位符（数据仍保留，
                      // 对齐 opencode TUI 的 [Old tool result content cleared]）
                      data.compactedAt != null
                          ? kCompactedToolResultPlaceholder
                          : data.result!,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: data.status == ToolCallStatus.error
                            ? Colors.red
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatArgs(Map<String, dynamic> args) {
    return args.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }
}
