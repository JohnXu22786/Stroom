/// 自然排序（数字感知）比较器。
///
/// 把名字中的连续数字段视为一个数值整体比较，而不是逐字符比较，
/// 例如 "25.2.6" < "25.12.6"、"file2" < "file10"。
/// 这正是 Windows 资源管理器 / macOS Finder 的文件名排序方式。
///
/// 规则（保证总序确定、稳定）：
/// - 两侧同一位置都是数字段 → 按数值比较（忽略前导零）；
/// - 其余情况（数字 vs 字母/符号、非数字 vs 非数字）→ 按原始码元
///   大小写不敏感比较，与改动前的字典序行为一致；
/// - 数值相等（如 "1" 与 "01"）时按原文（含前导零）比较兜底；
/// - 全部自然段相等时（如 "ABC" 与 "abc"）按原始字符串比较兜底。
int compareNatural(String a, String b) {
  final aLower = a.toLowerCase();
  final bLower = b.toLowerCase();

  var i = 0;
  var j = 0;
  while (i < aLower.length && j < bLower.length) {
    final aCode = aLower.codeUnitAt(i);
    final bCode = bLower.codeUnitAt(j);
    final aIsDigit = _isDigit(aCode);
    final bIsDigit = _isDigit(bCode);

    if (aIsDigit && bIsDigit) {
      // 数字段：截取完整数字串，按数值比较
      final aEnd = _digitRunEnd(aLower, i);
      final bEnd = _digitRunEnd(bLower, j);
      final cmp = _compareDigitRuns(
        aLower.substring(i, aEnd),
        bLower.substring(j, bEnd),
      );
      if (cmp != 0) return cmp;
      i = aEnd;
      j = bEnd;
    } else {
      if (aCode != bCode) return aCode < bCode ? -1 : 1;
      i++;
      j++;
    }
  }

  if (i < aLower.length) return 1; // a 更长 → a 大
  if (j < bLower.length) return -1;

  // 自然段全部相等：按原始字符串比较，保证全序确定
  return a.compareTo(b);
}

bool _isDigit(int code) => code >= 0x30 && code <= 0x39;

int _digitRunEnd(String s, int start) {
  var end = start;
  while (end < s.length && _isDigit(s.codeUnitAt(end))) {
    end++;
  }
  return end;
}

/// 比较两个数字串的数值大小：先比较去掉前导零后的长度（长的数值大），
/// 长度相同则按字典序；数值相等（如 "1" 与 "01"）按原文比较兜底。
int _compareDigitRuns(String x, String y) {
  final xTrimmed = _trimLeadingZeros(x);
  final yTrimmed = _trimLeadingZeros(y);
  if (xTrimmed.length != yTrimmed.length) {
    return xTrimmed.length - yTrimmed.length;
  }
  final cmp = xTrimmed.compareTo(yTrimmed);
  return cmp != 0 ? cmp : x.compareTo(y);
}

String _trimLeadingZeros(String s) {
  var i = 0;
  while (i < s.length - 1 && s.codeUnitAt(i) == 0x30) {
    i++;
  }
  return s.substring(i);
}
