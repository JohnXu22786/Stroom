import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/conversation_provider.dart'
    show temporaryCountdownTickProvider;

/// 临时对话的黄色倒计时胶囊：显示剩余时间的 HH:MM（如 24:00、12:31）。
///
/// 只有本胶囊监听 [temporaryCountdownTickProvider]（每秒递增），因此
/// 倒计时刷新不会整秒重建对话列表/聊天页。颜色用低透明度的琥珀色，
/// 在浅色 / 深色模式下都保持低调，不突兀。
class TemporaryCountdownCapsule extends ConsumerWidget {
  const TemporaryCountdownCapsule({super.key, required this.expiresAt});

  /// 倒计时过期时间点（如 [kTemporaryConversationDuration] 之后）。
  final DateTime expiresAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(temporaryCountdownTickProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 向上取整到分钟：刚开启时显示完整的 24:00 而不是 23:59，
    // 归零（<60s）时显示 00:00，随后由过期清理删除。
    final remainingSeconds = expiresAt.difference(DateTime.now()).inSeconds;
    final totalMinutes =
        remainingSeconds <= 0 ? 0 : (remainingSeconds / 60).ceil();
    final hh = totalMinutes ~/ 60;
    final mm = totalMinutes % 60;
    final text =
        '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.amber.withValues(alpha: 0.20)
            : Colors.amber.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: isDark ? Colors.amber.shade100 : Colors.amber.shade800,
        ),
      ),
    );
  }
}
