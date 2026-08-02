import 'dart:async';
import 'dart:html' as html;

import 'package:dio/dio.dart';

/// SSE 事件帧：事件名 + 数据。
///
/// 供需要区分事件名的协议使用（如 Anthropic Messages 流式接口的
/// message_start / content_block_delta / message_stop 等事件）。
class SseFrame {
  final String event;
  final String data;

  const SseFrame(this.event, this.data);

  @override
  String toString() => 'SseFrame(event: $event, data: ${data.length} chars)';
}

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
  // 连接阶段超时保护：30 秒内无任何响应视为失败。
  xhr.timeout = 30000;

  // 响应开始后（收到响应头）禁用活动超时：Anthropic 长思考期间
  // 可能数分钟无 SSE delta（思考期端点不推流），活动超时会掐断
  // 流并丢失已收的思考内容。
  final readyStateSub = xhr.onReadyStateChange.listen((_) {
    if (xhr.readyState >= html.HttpRequest.HEADERS_RECEIVED) {
      xhr.timeout = 0;
    }
  });

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
        // [DONE] 关闭后（订阅取消前的微任务窗口）可能再来 progress 事件：
        // 已关闭的 controller.add 会抛 StateError。
        if (!controller.isClosed) controller.add(line);
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

  // 取消轮询 Timer（声明提前：loadEnd 正常完成路径也需要清理它）
  Timer? cancelCheckTimer;

  final loadEndSub = xhr.onLoadEnd.listen((_) {
    // Capture response headers from the first response
    if (onResponseHeaders != null && xhr.status != 0) {
      final headerMap = <String, List<String>>{};
      final allHeaders = xhr.getAllResponseHeaders();
      if (allHeaders.isNotEmpty) {
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
    // HTTP 错误不能静默当"干净的空流结束"——否则 Web 端 API 错误
    // （401/404/500）在 UI 上毫无提示。IO 端 Dio 会抛
    // DioException，两端行为必须一致。
    // （连接阶段超时 status==0 由 onError 路径上抛，不在此处理）
    final status = xhr.status;
    if (status != null && status >= 400) {
      final statusText = xhr.statusText ?? '';
      if (!controller.isClosed) {
        controller.addError(Exception(
            '网络请求失败 (HTTP $status${statusText.isNotEmpty ? ': $statusText' : ''})'));
      }
      controller.close();
      progressSub.cancel();
      errorSub.cancel();
      xhr.abort();
      return;
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
          if (!controller.isClosed) controller.add(line);
        }
      }
    }
    if (!controller.isClosed) controller.close();
    progressSub.cancel();
    errorSub.cancel();
    // 正常完成路径显式清理（同 sseStream）：不依赖 onCancel 时序。
    cancelCheckTimer?.cancel();
    readyStateSub.cancel();
    xhr.abort();
  });

  void cleanupSubs() {
    progressSub.cancel();
    errorSub.cancel();
    loadEndSub.cancel();
    readyStateSub.cancel();
  }

  cancelToken?.whenCancel.then((_) {
    if (!controller.isClosed) {
      cleanupSubs();
      xhr.abort();
      controller.close();
    }
  });

  // Poll cancel token periodically
  if (cancelToken != null) {
    cancelCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (cancelToken.isCancelled && !controller.isClosed) {
        cancelCheckTimer?.cancel();
        cleanupSubs();
        xhr.abort();
        controller.close();
      }
    });
  }

  controller.onCancel = () {
    cancelCheckTimer?.cancel();
    cleanupSubs();
    xhr.abort();
  };

  xhr.send(body);

  yield* controller.stream;
}

/// Web 平台的 SSE 事件流式客户端（带事件名）。
///
/// 与 [sseStream] 相同的传输方式，但保留 `event:` 事件名，
/// 并以 [SseFrame] 为单位产出。用于 Anthropic 等按事件类型
/// 区分载荷的协议。
Stream<SseFrame> sseEventStream(
  String url,
  Map<String, String> headers,
  String body, {
  CancelToken? cancelToken,

  /// Callback invoked with the initial HTTP response headers, if available.
  void Function(Map<String, List<String>> headers)? onResponseHeaders,
}) async* {
  final controller = StreamController<SseFrame>();
  int processedLines = 0;
  String lastEvent = '';

  /// 处理 [fullText] 中的行。progress 阶段传 [explicitEnd]=null：
  /// 最后一行可能不完整（半截 token），跳过；loadEnd 阶段传完整行数：
  /// 无尾换行的最后一行也是完整数据，必须处理（否则 Anthropic 的
  /// 最终 message_delta / stop_reason 会丢失）。
  void processLines(String fullText, int? explicitEnd) {
    final lines = fullText.split('\n');
    final completeCount = explicitEnd ?? lines.length - 1;
    if (completeCount <= processedLines) return;
    for (var i = processedLines; i < completeCount; i++) {
      final line = lines[i];
      if (line.startsWith('event: ')) {
        lastEvent = line.substring(7).trim();
      } else if (line.startsWith('data: ')) {
        final data = line.substring(6).trim();
        if (!controller.isClosed) {
          controller.add(SseFrame(lastEvent, data));
        }
        lastEvent = '';
      } else if (line.isEmpty) {
        lastEvent = '';
      }
    }
    processedLines = completeCount;
  }

  final xhr = html.HttpRequest();
  xhr.open('POST', url);
  headers.forEach((k, v) => xhr.setRequestHeader(k, v));
  xhr.responseType = 'text';
  // 连接阶段超时保护：30 秒内无任何响应视为失败。
  xhr.timeout = 30000;

  // 响应开始后（收到响应头）禁用活动超时：Anthropic 长思考期间
  // 可能数分钟无 SSE delta（思考期端点不推流），活动超时会掐断
  // 流并丢失已收的思考内容。此函数被 Anthropic 端点（sseEventStream）
  // 使用，与 sseStream 必须对称。
  final readyStateSub = xhr.onReadyStateChange.listen((_) {
    if (xhr.readyState >= html.HttpRequest.HEADERS_RECEIVED) {
      xhr.timeout = 0;
    }
  });

  final progressSub = xhr.onProgress.listen((_) {
    final fullText = xhr.responseText ?? '';
    // 最后一行可能不完整，只处理前面完整的行
    processLines(fullText, null);
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

  // 取消轮询 Timer（声明提前：loadEnd 正常完成路径也需要清理它）
  Timer? cancelCheckTimer;

  final loadEndSub = xhr.onLoadEnd.listen((_) {
    // Capture response headers from the first response
    if (onResponseHeaders != null && xhr.status != 0) {
      final headerMap = <String, List<String>>{};
      final allHeaders = xhr.getAllResponseHeaders();
      if (allHeaders.isNotEmpty) {
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
    // HTTP 错误不能静默结束（同 sseStream）：Web 端 API 错误
    // 必须上抛，与 IO 端 DioException 行为一致。
    final status = xhr.status;
    if (status != null && status >= 400) {
      final statusText = xhr.statusText ?? '';
      if (!controller.isClosed) {
        controller.addError(Exception(
            '网络请求失败 (HTTP $status${statusText.isNotEmpty ? ': $statusText' : ''})'));
      }
      controller.close();
      progressSub.cancel();
      errorSub.cancel();
      xhr.abort();
      return;
    }
    // Process all remaining lines (don't drop the last complete line,
    // even when the response has no trailing newline)
    final remainingText = xhr.responseText ?? '';
    if (remainingText.isNotEmpty) {
      processLines(remainingText, remainingText.split('\n').length);
    }
    if (!controller.isClosed) controller.close();
    progressSub.cancel();
    errorSub.cancel();
    // 正常完成路径显式清理（不依赖 onCancel 时序）：500ms 轮询
    // Timer 与 readyStateSub 每次请求都会泄漏，会话期内无限累积。
    cancelCheckTimer?.cancel();
    readyStateSub.cancel();
    xhr.abort();
  });

  void cleanupSubs() {
    progressSub.cancel();
    errorSub.cancel();
    loadEndSub.cancel();
    readyStateSub.cancel();
  }

  cancelToken?.whenCancel.then((_) {
    if (!controller.isClosed) {
      cleanupSubs();
      xhr.abort();
      controller.close();
    }
  });

  // Poll cancel token periodically
  if (cancelToken != null) {
    cancelCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (cancelToken.isCancelled && !controller.isClosed) {
        cancelCheckTimer?.cancel();
        cleanupSubs();
        xhr.abort();
        controller.close();
      }
    });
  }

  controller.onCancel = () {
    cancelCheckTimer?.cancel();
    cleanupSubs();
    xhr.abort();
  };

  xhr.send(body);

  yield* controller.stream;
}

/// 建立持久的 SSE GET 连接（用于标准 MCP SSE 协议）。
/// 返回一个流，每一行都是一条 SSE 事件（完整行，含 event / data 前缀）。
Stream<String> sseConnect(
  String url,
  Map<String, String> headers, {
  CancelToken? cancelToken,

  /// Callback invoked with the initial HTTP response headers, if available.
  void Function(Map<String, List<String>> headers)? onResponseHeaders,
}) async* {
  final controller = StreamController<String>();
  int processedLines = 0;

  final xhr = html.HttpRequest();
  xhr.open('GET', url);
  headers.forEach((k, v) => xhr.setRequestHeader(k, v));
  xhr.responseType = 'text';

  final progressSub = xhr.onProgress.listen((_) {
    final fullText = xhr.responseText ?? '';
    final lines = fullText.split('\n');
    final completeCount = lines.length - 1;
    if (completeCount <= processedLines) return;

    for (var i = processedLines; i < completeCount; i++) {
      final line = lines[i];
      // Yield ALL lines for full SSE protocol parsing
      controller.add(line);
    }
    processedLines = completeCount;
  });

  final errorSub = xhr.onError.listen((event) {
    if (!controller.isClosed) {
      final statusCode = xhr.status;
      final statusText = xhr.statusText;
      final errorMsg = statusCode != 0
          ? 'SSE 连接失败 (HTTP $statusCode${(statusText ?? '').isNotEmpty ? ": $statusText" : ""})'
          : 'SSE 连接失败: 无法连接到服务器';
      controller.addError(Exception(errorMsg));
    }
  });

  // 取消轮询 Timer（声明提前：loadEnd 正常完成路径也需要清理它）
  Timer? cancelCheckTimer;

  final loadEndSub = xhr.onLoadEnd.listen((_) {
    if (onResponseHeaders != null && xhr.status != 0) {
      final headerMap = <String, List<String>>{};
      final allHeaders = xhr.getAllResponseHeaders();
      if (allHeaders.isNotEmpty) {
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
    // Yield remaining lines
    final remainingText = xhr.responseText ?? '';
    if (remainingText.isNotEmpty) {
      final allLines = remainingText.split('\n');
      for (var i = processedLines; i < allLines.length; i++) {
        if (!controller.isClosed) controller.add(allLines[i]);
      }
    }
    if (!controller.isClosed) controller.close();
    progressSub.cancel();
    errorSub.cancel();
    // 正常完成路径显式清理轮询 Timer（同 sseStream/sseEventStream）
    cancelCheckTimer?.cancel();
    xhr.abort();
  });

  void cleanupSubs() {
    progressSub.cancel();
    errorSub.cancel();
    loadEndSub.cancel();
  }

  cancelToken?.whenCancel.then((_) {
    if (!controller.isClosed) {
      cleanupSubs();
      xhr.abort();
      controller.close();
    }
  });

  controller.onCancel = () {
    cleanupSubs();
    xhr.abort();
  };

  xhr.send();

  yield* controller.stream;
}

/// 向 MCP 消息端点发送 JSON-RPC POST 请求。
Future<String> ssePost(
  String url,
  Map<String, String> headers,
  String body, {
  CancelToken? cancelToken,
}) async {
  final controller = Completer<String>();

  final xhr = html.HttpRequest();
  xhr.open('POST', url);
  headers.forEach((k, v) => xhr.setRequestHeader(k, v));
  xhr.responseType = 'text';
  xhr.timeout = 30000;

  xhr.onLoadEnd.listen((_) {
    if (controller.isCompleted) return;
    if (xhr.status != null && xhr.status! >= 200 && xhr.status! < 300) {
      final response = xhr.responseText ?? '';
      controller.complete(response);
    } else if (xhr.status != null && xhr.status! > 0) {
      controller
          .completeError(Exception('HTTP ${xhr.status}: ${xhr.statusText}'));
    } else {
      controller.completeError(Exception('请求失败'));
    }
  });

  xhr.onError.listen((_) {
    if (!controller.isCompleted) {
      controller.completeError(Exception('网络请求失败'));
    }
  });

  cancelToken?.whenCancel.then((_) {
    if (!controller.isCompleted) {
      xhr.abort();
      // 取消 = 失败：与 IO 端（Dio 抛 DioException）语义一致，
      // 避免调用方把取消当作成功响应（complete('') 会返回空串）。
      controller.completeError(Exception('请求已取消'));
    }
  });

  xhr.send(body);

  return controller.future;
}
