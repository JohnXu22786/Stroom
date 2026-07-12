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
