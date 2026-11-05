import 'package:flutter/widgets.dart';

/// Carries whether the retained chat tab is currently visible to its routes.
/// Offstage routes stay mounted, so loading animations must pause in the
/// background to let the surrounding UI settle.
class ChatTabVisibility extends InheritedWidget {
  const ChatTabVisibility({
    required this.isVisible,
    required super.child,
    super.key,
  });

  final bool isVisible;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ChatTabVisibility>()
          ?.isVisible ??
      true;

  @override
  bool updateShouldNotify(ChatTabVisibility oldWidget) =>
      isVisible != oldWidget.isVisible;
}

String formatDurationShort(String durationStr) {
  final parts = durationStr.split(':');
  if (parts.length != 3) return durationStr;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  final secPart = parts[2].split('.')[0];
  final s = int.tryParse(secPart) ?? 0;
  if (h > 0) return '$h时$m分$s秒';
  if (m > 0) return '$m分$s秒';
  return '$s秒';
}
