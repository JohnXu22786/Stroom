import 'dart:convert';

/// 应用版本号（CD 构建时通过 --dart-define=APP_VERSION=... 注入，
/// 即发布时的 release 版本号）。
const String appVersion =
    String.fromEnvironment('APP_VERSION', defaultValue: '0.2.13');

/// CD 构建的发布时间（ISO 8601 UTC，如 `2026-08-08T09:30:00Z`），
/// 通过 --dart-define=APP_RELEASE_TIME=... 注入；本地构建时为空。
const String appReleaseTime =
    String.fromEnvironment('APP_RELEASE_TIME', defaultValue: '');

/// CD 构建的更新内容（GitHub Release 说明，Base64 编码后注入），
/// 通过 --dart-define=APP_RELEASE_NOTES_B64=... 注入；本地构建时为空。
const String appReleaseNotesEncoded =
    String.fromEnvironment('APP_RELEASE_NOTES_B64', defaultValue: '');

/// 解码后的更新内容；未注入或解码失败时返回空字符串。
String get appReleaseNotes => decodeReleaseNotes(appReleaseNotesEncoded);

/// 展示用的发布时间（UTC+0 `yyyy-MM-dd HH:mm`）；
/// 未注入或解析失败时返回空字符串。
String get appReleaseTimeFormatted => formatReleaseTime(appReleaseTime);

/// 将 Base64 编码的 UTF-8 文本解码；非法输入返回空字符串。
String decodeReleaseNotes(String encoded) {
  if (encoded.isEmpty) return '';
  try {
    return utf8.decode(base64Decode(encoded));
  } catch (_) {
    return '';
  }
}

/// 将 ISO 8601 时间字符串格式化为 UTC+0 的 `yyyy-MM-dd HH:mm`；
/// 空串或无法解析时返回空字符串。
///
/// CD 构建写入的发布时间一律是 UTC+0（`...Z`）。展示与更新检查比对
/// 统一以 UTC+0 为准，不做本地时区转换，避免「写入的时间」与用户
/// 系统时区不一致造成歧义。
String formatReleaseTime(String isoTime) {
  if (isoTime.isEmpty) return '';
  final dt = DateTime.tryParse(isoTime);
  if (dt == null) return '';
  final utc = dt.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)} '
      '${two(utc.hour)}:${two(utc.minute)}';
}
