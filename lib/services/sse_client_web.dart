import 'dart:async';
import 'dart:html' as html;

import 'package:dio/dio.dart';

/// Web 平台的 SSE 流式客户端
/// 使用 dart:html HttpRequest.onProgress 实现真正的逐 token 流式
Stream<String> sseStream(
  String url,
  Map<String, String> headers,
  String body, {
  CancelToken? cancelToken,
  /// Callback invoked with the initial HTTP response headers, if available.
  void Function(Map<String, List<String>> headers)? onResponseHeaders,
}) async* {
  final controller = StreamController<String>();
  int processedLines = 0;

  final xhr = html.HttpRequest();
  xhr.open('POST', url);
  headers.forEach((k, v) => xhr.setRequestHeader(k, v));
  xhr.responseType = 'text';
  xhr.timeout = 30000; // 30 second timeout

  final progressSub = xhr.onProgress.listen((_) {
    final fullText = xhr.responseText ?? '';
    final lines = fullText.split('\n');
    // 最后一行可能不完整，只处理前面完整的行
    final completeCount = lines.length - 1;
    if (completeCount <= processedLines) return;

    for (var i = processedLines; i < completeCount; i++) {
      final line = lines[i];
      if (line.startsWith('data: ')) {
        final data = line.substring(6).trim();
        if (data == '[DONE]') {
          processedLines = completeCount;
          if (!controller.isClosed) controller.close();
          return;
        }
        // Yield the raw SSE line; the caller (chat_api_provider.dart)
        // strips the prefix, parses JSON, and handles content/reasoning/tool_calls.
        controller.add(line);
      }
    }
    processedLines = completeCount;
  });

  final errorSub = xhr.onError.listen((event) {
    if (!controller.isClosed) {
      final statusCode = xhr.status;
      final statusText = xhr.statusText;
      final errorMsg = statusCode != 0
          ? '网络请求失败 (HTTP $statusCode${(statusText ?? '').isNotEmpty ? ": $statusText" : ""})'
          : '网络请求失败: 无法连接到服务器';
      controller.addError(Exception(errorMsg));
    }
  });

  final loadEndSub = xhr.onLoadEnd.listen((_) {
    // Capture response headers from the first response
    if (onResponseHeaders != null && xhr.status != 0) {
      final headerMap = <String, List<String>>{};
      final allHeaders = xhr.getAllResponseHeaders();
      if (allHeaders != null && allHeaders.isNotEmpty) {
        for (final line in allHeaders.split('\n')) {
          final colonPos = line.indexOf(':');
          if (colonPos > 0) {
            final key = line.substring(0, colonPos).trim().toLowerCase();
            final value = line.substring(colonPos + 1).trim();
            headerMap.putIfAbsent(key, () => []).add(value);
          }
        }
      }
      onResponseHeaders(headerMap);
    }
    // Process all remaining lines (don't drop the last complete line)
    final remainingText = xhr.responseText ?? '';
    if (remainingText.isNotEmpty) {
      final allLines = remainingText.split('\n');
      for (var i = processedLines; i < allLines.length; i++) {
        final line = allLines[i];
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') break;
          // Yield raw SSE line (caller strips prefix, parses JSON)
          controller.add(line);
        }
      }
    }
    if (!controller.isClosed) controller.close();
    progressSub.cancel();
    errorSub.cancel();
    xhr.abort();
  });

  void _cleanupSubs() {
    progressSub.cancel();
    errorSub.cancel();
    loadEndSub.cancel();
  }

  cancelToken?.whenCancel.then((_) {
    if (!controller.isClosed) {
      _cleanupSubs();
      xhr.abort();
      controller.close();
    }
  });

  // Poll cancel token periodically
  Timer? cancelCheckTimer;
  if (cancelToken != null) {
    cancelCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (cancelToken.isCancelled && !controller.isClosed) {
        cancelCheckTimer?.cancel();
        _cleanupSubs();
        xhr.abort();
        controller.close();
      }
    });
  }

  controller.onCancel = () {
    cancelCheckTimer?.cancel();
    _cleanupSubs();
    xhr.abort();
  };

  xhr.send(body);

  yield* controller.stream;
}
