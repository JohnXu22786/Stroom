import 'dart:async';
import 'dart:html' as html;

import 'package:dio/dio.dart';

/// Web 平台的 SSE 流式客户端
/// 使用 dart:html HttpRequest.onProgress 实现真正的逐 token 流式
Stream<String> sseStream(String url, Map<String, String> headers, String body,
    {CancelToken? cancelToken}) async* {
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
