import 'batch_rename_config.dart';

export 'batch_rename_regex_native.dart'
    if (dart.library.html) 'batch_rename_regex_web.dart';

class BatchRenameRegexResult {
  final String? name;
  final String? error;
  const BatchRenameRegexResult({this.name, this.error});
}

class BatchRenameRegexCancelled implements Exception {}

/// Shared by the synchronous planner and the native background worker.
String replaceBatchRenameText(String name, BatchReplaceOp op) {
  final pattern = RegExp(op.useRegex ? op.find : RegExp.escape(op.find),
      caseSensitive: op.caseSensitive, unicode: true);
  String replacement(Match match) {
    if (!op.useRegex) return op.replace;
    return op.replace.replaceAllMapped(RegExp(r'\$\$|\$(\d+)'), (ref) {
      if (ref[0] == r'$$') return r'$';
      final group = int.tryParse(ref[1]!);
      if (group == null || group > match.groupCount)
        throw FormatException('捕获组 \$${ref[1]} 不存在');
      return match[group] ?? '';
    });
  }

  final result = op.firstOnly
      ? name.replaceFirstMapped(pattern, replacement)
      : name.replaceAllMapped(pattern, replacement);
  if (result.length > 4096) throw const FormatException('中间名称过长，请调整规则');
  return result;
}
