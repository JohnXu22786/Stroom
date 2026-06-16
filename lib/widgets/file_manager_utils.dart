/// File size formatting
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// Date formatting with relative labels (today, yesterday)
String formatDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final fileDay = DateTime(date.year, date.month, date.day);
  final diffDays = today.difference(fileDay).inDays;
  final time =
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  if (diffDays == 0) {
    return '今天 $time';
  }
  if (diffDays == 1) {
    return '昨天 $time';
  }
  if (diffDays < 7) return '$diffDays天前 $time';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $time';
}
