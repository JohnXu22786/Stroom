import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/conversation_provider.dart'
    show temporaryCountdownTickProvider;

String formatTemporaryCountdown(Duration remaining) {
  final totalSeconds = remaining <= Duration.zero
      ? 0
      : (remaining.inMicroseconds / const Duration(seconds: 1).inMicroseconds)
            .ceil();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  final minuteText = minutes.toString().padLeft(2, '0');
  final secondText = seconds.toString().padLeft(2, '0');
  return '$minuteText:$secondText';
}

/// 临时对话的黄色倒计时胶囊：显示剩余时间的 MM:SS（如 60:00、12:31）。
///
/// 只有本胶囊监听 [temporaryCountdownTickProvider]（每秒递增），因此
/// 倒计时刷新不会整秒重建对话列表/聊天页。颜色用低透明度的琥珀色，
/// 在浅色 / 深色模式下都保持低调，不突兀。
class TemporaryCountdownCapsule extends ConsumerStatefulWidget {
  const TemporaryCountdownCapsule({
    super.key,
    required this.expiresAt,
    this.pausedRemainingMilliseconds,
    this.animationKey = 0,
    this.animateOnMount = false,
    this.animateOnChange = false,
  });

  /// 倒计时过期时间点（如 [kTemporaryConversationDuration] 之后）。
  final DateTime expiresAt;
  final int? pausedRemainingMilliseconds;
  final int animationKey;
  final bool animateOnMount;
  final bool animateOnChange;

  @override
  ConsumerState<TemporaryCountdownCapsule> createState() =>
      _TemporaryCountdownCapsuleState();
}

class _TemporaryCountdownCapsuleState
    extends ConsumerState<TemporaryCountdownCapsule>
    with SingleTickerProviderStateMixin {
  late final AnimationController _highlightController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animateOnMount) _highlightController.forward();
  }

  @override
  void didUpdateWidget(covariant TemporaryCountdownCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateOnChange &&
        widget.animationKey != oldWidget.animationKey) {
      _highlightController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    ref.watch(temporaryCountdownTickProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 向上取整到秒：刚开启时显示完整的 60:00，归零后显示 00:00，
    // 随后由过期清理删除。
    final remaining = widget.pausedRemainingMilliseconds == null
        ? widget.expiresAt.difference(DateTime.now())
        : Duration(milliseconds: widget.pausedRemainingMilliseconds!);
    final text = formatTemporaryCountdown(remaining);
    final isNearExpiry = remaining <= const Duration(minutes: 5);
    final accent = isNearExpiry
        ? Theme.of(context).colorScheme.error
        : Colors.amber;

    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: _highlightController,
      builder: (context, child) {
        final glowOpacity = _highlightController.isAnimating
            ? (1 - _highlightController.value) * 0.42
            : 0.0;
        return Semantics(
          label: [
            l10n.conversationTemporary,
            text,
            if (isNearExpiry) l10n.conversationTemporaryWarning,
          ].join(', '),
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.20 : 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accent.withValues(alpha: 0.45)),
              boxShadow: glowOpacity <= 0
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: glowOpacity),
                        blurRadius: 12 * glowOpacity,
                        spreadRadius: 2 * glowOpacity,
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, size: 12, color: accent),
                const SizedBox(width: 4),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: isNearExpiry
                        ? Theme.of(context).colorScheme.error
                        : (isDark
                              ? Colors.amber.shade100
                              : Colors.amber.shade800),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
