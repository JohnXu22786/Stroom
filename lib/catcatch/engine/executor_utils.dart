import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart';
import '../models/catcatch_task.dart';

const String webDownloadHint = 'Web 端不支持直接下载媒体文件。\n'
    '请安装浏览器扩展「CatCatch（猫抓）」后再试。\n'
    '作者：笨笨猫（xifangczy），完全免费开源。\n'
    '注意：请认准作者，避免下载到付费版/山寨版。\n'
    'GitHub 地址: https://github.com/xifangczy/cat-catch';

String formatExecutorDuration(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  final ms = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
  return '$h:$m:$s.$ms';
}

int calcExecutorProgress(List<StepStatus> steps) {
  if (steps.isEmpty) return 0;
  int sum = 0;
  for (final s in steps) {
    if (s.completed || s.skipped) {
      sum += 100;
    } else if (s.running) {
      sum += s.progress;
    }
  }
  return (sum ~/ steps.length).clamp(0, 100);
}

void ensureExecutorSteps(List<StepStatus> steps) {
  final existing = {for (final s in steps) s.type};
  for (final type in StepType.values) {
    if (!existing.contains(type)) {
      final insertAt = StepType.values.indexOf(type);
      if (insertAt <= steps.length) {
        steps.insert(insertAt, StepStatus.pending(type));
      } else {
        steps.add(StepStatus.pending(type));
      }
    }
  }
}

void markExecutorStep(List<StepStatus> steps, int index,
    {bool done = false,
    bool running = false,
    bool failed = false,
    bool skipped = false,
    String? error,
    int progress = 0,
    String? detail}) {
  if (index >= steps.length) return;
  steps[index] = steps[index].copyWith(
      completed: done,
      running: running,
      failed: failed,
      skipped: skipped,
      error: error,
      progress: progress,
      detail: detail);
}

void markAllExecutorStepsDone(List<StepStatus> steps) {
  for (int i = 0; i < steps.length; i++) {
    steps[i] = steps[i].copyWith(
        completed: true, running: false, failed: false, progress: 100);
  }
}

Future<String> uniqueExecutorPath(String path) async {
  final file = File(path);
  if (!await file.exists()) return path;
  final dir = p.dirname(path);
  final name = p.basenameWithoutExtension(path);
  final ext = p.extension(path);
  for (int i = 1; i < 100; i++) {
    final newPath = p.join(dir, '$name ($i)$ext');
    if (!await File(newPath).exists()) return newPath;
  }
  return path;
}

String longestCommonPrefix(String a, String b) {
  final minLen = a.length < b.length ? a.length : b.length;
  int i = 0;
  while (i < minLen && a[i] == b[i]) {
    i++;
  }
  return a.substring(0, i);
}

double? parseDurationToSeconds(String duration) {
  final parts = duration.split(':');
  if (parts.length == 3) {
    final h = double.tryParse(parts[0]) ?? 0;
    final m = double.tryParse(parts[1]) ?? 0;
    final s = double.tryParse(parts[2]) ?? 0;
    return h * 3600 + m * 60 + s;
  }
  if (parts.length == 2) {
    final m = double.tryParse(parts[0]) ?? 0;
    final s = double.tryParse(parts[1]) ?? 0;
    return m * 60 + s;
  }
  return double.tryParse(duration);
}

String formatDioError(DioException e) {
  final String originalMsg = e.message ?? '';
  String extra;
  if (originalMsg.isNotEmpty) {
    extra = '\n原始错误: $originalMsg';
  } else {
    extra = '';
  }

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
      return '连接超时，请检查网络或服务器状态$extra';
    case DioExceptionType.sendTimeout:
      return '发送请求超时$extra';
    case DioExceptionType.receiveTimeout:
      return '接收响应超时，服务器响应过慢$extra';
    case DioExceptionType.connectionError:
      if (kIsWeb) {
        return '无法连接到服务器。\n\n$webDownloadHint';
      }
      return '无法连接到服务器，请检查URL是否正确$extra';
    case DioExceptionType.badCertificate:
      return '服务器证书验证失败$extra';
    case DioExceptionType.badResponse:
      final code = e.response?.statusCode ?? 0;
      final body = e.response?.data;
      String bodyStr;
      if (body is List<int>) {
        try {
          bodyStr = utf8.decode(body);
        } catch (_) {
          bodyStr = body.toString();
        }
      } else {
        bodyStr = body?.toString() ?? '';
      }
      return '服务器返回错误 (HTTP $code)${bodyStr.isNotEmpty ? ": $bodyStr" : ""}$extra';
    case DioExceptionType.cancel:
      return '请求已取消$extra';
    default:
      return '网络错误: ${e.message ?? "未知错误"}';
  }
}
