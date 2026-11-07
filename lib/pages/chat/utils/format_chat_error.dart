import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:stroom/providers/locale_provider.dart'
    show appLocalizationsForLocale;

import '../../../utils/data_sanitizer.dart';

/// 格式化聊天错误信息，分类显示友好的提示并保留原始错误
String formatChatErrorMessage(Object error, {Locale? locale}) {
  final l10n = appLocalizationsForLocale(locale);
  final errorStr = error.toString();

  if (errorStr.contains('请先配置聊天供应商')) {
    final details = _detailsAfterKnownMessage(
      errorStr,
      '请先配置聊天供应商',
    );
    return '${l10n.chatErrorPrefix}${l10n.chatErrorProviderNotConfigured}'
        '$details';
  }

  if (errorStr.contains('API key not configured')) {
    final details = _detailsAfterKnownMessage(
      errorStr,
      'API key not configured',
    );
    return '${l10n.chatErrorPrefix}${l10n.chatErrorApiKeyNotConfigured}'
        '$details';
  }

  if (errorStr.contains('无法连接到服务器') || errorStr.contains('连接错误')) {
    return '${l10n.chatErrorPrefix}${l10n.chatErrorServerConnection}\n$errorStr';
  }

  if (errorStr.contains('SocketException') ||
      errorStr.contains('Connection refused') ||
      errorStr.contains('连接失败')) {
    return '${l10n.chatErrorPrefix}${l10n.chatErrorNetworkConnection}\n$errorStr';
  }

  if (errorStr.contains('timeout') || errorStr.contains('超时')) {
    return '${l10n.chatErrorPrefix}${l10n.chatErrorTimeout}\n$errorStr';
  }

  if (errorStr.contains('HTTP ')) {
    return '${l10n.chatErrorPrefix}$errorStr';
  }

  return '${l10n.chatErrorPrefix}$errorStr';
}

String _detailsAfterKnownMessage(String error, String knownMessage) {
  final messageEnd = error.indexOf(knownMessage) + knownMessage.length;
  final details =
      error.substring(messageEnd).replaceFirst(RegExp(r'^\s*[:：-]\s*'), '');
  return details.isEmpty ? '' : '\n$details';
}

/// 格式化 API 错误响应值（如响应体）用于错误气泡与详情弹窗展示。
///
/// - 流式错误捕获的 `{'raw': '<string>'}` 包装会被解开，直接展示真实响应体；
/// - 内容是 JSON 的字符串会被解析并按缩进美化输出，而不是显示成带
///   转义符的原始文本；
/// - Map/List 值渲染为带缩进的 JSON；
/// - 从不截断：始终返回完整内容（长 base64 内容按 [DataSanitizer]
///   规则隐藏，避免渲染超大字符串导致 UI 卡死）。
String formatErrorValueForDisplay(dynamic value) {
  // 流式请求出错时响应体被捕获为 {'raw': '<string>'} 的包装形态，
  // 解开包装让真实内容直接展示。
  if (value is Map && value.length == 1 && value['raw'] is String) {
    value = value['raw'];
  }

  if (value is String) {
    final trimmed = value.trim();
    // 字符串内容是 JSON 时按 JSON 美化输出（API 返回的错误体多为 JSON）。
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map || decoded is List) {
          return const JsonEncoder.withIndent('  ')
              .convert(DataSanitizer.sanitizeForDisplay(decoded));
        }
      } catch (_) {
        // 非 JSON 字符串，走普通文本展示。
      }
    }
    return DataSanitizer.sanitizeBase64String(value);
  }

  if (value is Map || value is List) {
    try {
      return const JsonEncoder.withIndent('  ')
          .convert(DataSanitizer.sanitizeForDisplay(value));
    } catch (_) {
      return value.toString();
    }
  }

  return value?.toString() ?? '';
}
