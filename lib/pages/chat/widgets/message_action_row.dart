import 'package:flutter/material.dart';
import 'action_button.dart';

/// Action button row for chat messages (copy, retry/edit, raw data view,
/// JSON inspection, delete).
///
/// Builds children dynamically to avoid orphaned [SizedBox] spacers when
/// conditional buttons are hidden. Ensures consistent 2px gaps between
/// all consecutive visible buttons.
class MessageActionRow extends StatelessWidget {
  const MessageActionRow({
    super.key,
    required this.messageText,
    required this.isAi,
    required this.showRawData,
    required this.showJsonInspection,
    required this.onCopy,
    required this.onRetryOrEdit,
    this.onViewRawData,
    this.onJsonInspection,
    required this.onDelete,
  });

  /// Text content to copy.
  final String messageText;

  /// Whether this is an AI message (shows Retry instead of Edit).
  final bool isAi;

  /// Whether the raw data (查看请求数据/查看响应数据) button is visible.
  final bool showRawData;

  /// Whether the JSON inspection (developer mode) button is visible.
  final bool showJsonInspection;

  /// Called when the copy button is pressed.
  final VoidCallback onCopy;

  /// Called when the retry (AI) or edit (user) button is pressed.
  final VoidCallback onRetryOrEdit;

  /// Called when the raw data button is pressed. Ignored when [showRawData] is
  /// false.
  final VoidCallback? onViewRawData;

  /// Called when the JSON inspection button is pressed. Ignored when
  /// [showJsonInspection] is false.
  final VoidCallback? onJsonInspection;

  /// Called when the delete button is pressed.
  final VoidCallback onDelete;

  static const double _spacerWidth = 2;

  @override
  Widget build(BuildContext context) {
    // Assert that callbacks are provided when their corresponding buttons are
    // visible. This catches misconfigured callers at development time.
    assert(!showRawData || onViewRawData != null,
        'onViewRawData must be provided when showRawData is true');
    assert(!showJsonInspection || onJsonInspection != null,
        'onJsonInspection must be provided when showJsonInspection is true');

    // Build children dynamically so SizedBox spacers only appear between
    // consecutive visible buttons. This avoids orphaned spacers that create
    // uneven gaps when conditional buttons are hidden.
    final children = <Widget>[
      // [1] Copy — always visible
      ActionButton(
        icon: Icons.copy,
        tooltip: '复制',
        onPressed: onCopy,
      ),
    ];

    // [2] Retry (AI) / Edit (user) — always visible
    children.add(const SizedBox(width: _spacerWidth));
    children.add(
      ActionButton(
        icon: isAi ? Icons.refresh : Icons.edit_outlined,
        tooltip: isAi ? '重试' : '编辑',
        onPressed: onRetryOrEdit,
      ),
    );

    // [3] Raw data (查看请求数据 / 查看响应数据) — conditional
    if (showRawData) {
      children.add(const SizedBox(width: _spacerWidth));
      children.add(
        ActionButton(
          icon: Icons.data_exploration,
          tooltip: isAi ? '查看响应数据' : '查看请求数据',
          onPressed: onViewRawData!,
        ),
      );
    }

    // [4] JSON inspection — conditional (developer mode + AI)
    if (showJsonInspection) {
      children.add(const SizedBox(width: _spacerWidth));
      children.add(
        ActionButton(
          icon: Icons.code,
          tooltip: 'JSON 审查',
          onPressed: onJsonInspection!,
        ),
      );
    }

    // [5] Delete — always visible
    children.add(const SizedBox(width: _spacerWidth));
    children.add(
      ActionButton(
        icon: Icons.delete_outline,
        tooltip: '删除',
        onPressed: onDelete,
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
