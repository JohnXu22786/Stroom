// ============================================================================
// Token 估算工具 — 用于上下文管理（工具 prune / 上下文压缩）的粗略估算
// ============================================================================
//
// 这不是真正的 tokenizer。估算值刻意偏向"高估"而非低估：
// 宁可多留保留区，也不要因为低估而把上下文塞爆。
//
// 估算规则（经验值，参考常见的 1 token ≈ 4 字符规则，并对 CJK 加权）：
// - ASCII 字符：每 4 个字符约 1 token
// - CJK 字符（中日韩统一表意文字等）：每 1.5 个字符约 1 token
// - 空白与标点按 ASCII 计
//
// 调用方应把这些值视为"排序/决策用的相对大小"，而不是精确计费值。

/// 粗略估算 [text] 的 token 数。
///
/// 逐字符扫描，CJK 区段按 1.5 字符/token，其余按 4 字符/token。
/// 空字符串返回 0。
int estimateTokens(String text) {
  if (text.isEmpty) return 0;
  var asciiChars = 0;
  var cjkChars = 0;
  for (final rune in text.runes) {
    if (_isCjkRune(rune)) {
      cjkChars++;
    } else {
      asciiChars++;
    }
  }
  // ceil 保证至少 1 token（非空文本）
  final tokens = (asciiChars / 4).ceil() + (cjkChars * 2 / 3).ceil();
  return tokens < 1 ? 1 : tokens;
}

/// 粗略估算 JSON 结构（Map/List/String/num/bool）序列化后的 token 数。
/// 用于工具结果、请求体等结构化数据的估算。
int estimateJsonTokens(Object? value) {
  if (value == null) return 0;
  if (value is String) return estimateTokens(value);
  if (value is num || value is bool) return 1;
  if (value is Map) {
    var sum = 0;
    for (final e in value.entries) {
      sum += estimateTokens(e.key.toString());
      sum += estimateJsonTokens(e.value);
    }
    return sum;
  }
  if (value is List) {
    var sum = 0;
    for (final e in value) {
      sum += estimateJsonTokens(e);
    }
    return sum;
  }
  return estimateTokens(value.toString());
}

/// 判断一个 Unicode 码点是否属于 CJK（中日韩）字符区段。
///
/// 覆盖常用区段：
/// - 0x2E80–0x9FFF  （CJK 部首/统一表意文字，含扩展 A）
/// - 0x3400–0x4DBF  （扩展 A）
/// - 0xF900–0xFAFF  （兼容表意文字）
/// - 0xFF00–0xFFEF  （全角形式）
/// - 0x20000–0x2FA1F（扩展 B 及之后）
bool _isCjkRune(int rune) {
  return (rune >= 0x2E80 && rune <= 0x9FFF) ||
      (rune >= 0x3400 && rune <= 0x4DBF) ||
      (rune >= 0xF900 && rune <= 0xFAFF) ||
      (rune >= 0xFF00 && rune <= 0xFFEF) ||
      (rune >= 0x20000 && rune <= 0x2FA1F);
}
