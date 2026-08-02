export '../utils/format_file_size.dart';

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

/// 文件名清洗：将路径分隔符等非法字符替换为下划线，
/// 超长名称截断到 [_maxNameLength] 字符以内并尽量保留扩展名。
///
/// 扩展名本身超过上限时整体截断，保证返回结果不会因 substring 越界抛异常。
const int _maxNameLength = 110;

String sanitizeFileName(String rawName) {
  var clean = rawName.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
  if (clean.length <= _maxNameLength) return clean;
  final extIdx = clean.lastIndexOf('.');
  if (extIdx == -1) return clean.substring(0, _maxNameLength);
  final ext = clean.substring(extIdx); // includes the dot
  final baseLen = _maxNameLength - ext.length;
  if (baseLen <= 0) {
    // 扩展名本身超过上限：直接整体截断
    return clean.substring(0, _maxNameLength);
  }
  // 截断时保证 baseLen < extIdx（clean.length > 上限 ⇒ extIdx > baseLen），
  // 因此不会把扩展名截掉一半。
  return '${clean.substring(0, baseLen)}$ext';
}
