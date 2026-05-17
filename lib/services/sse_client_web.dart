import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

/// Web 平台的 SSE 流式客户端
/// 使用 dart:html HttpRequest.onProgress 实现真正的逐 token 流式
Stream<String> sseStream(
    String url, Map<String, String> headers, String body) async* {
  final controller = StreamController<String>();
  int processedLines = 0;

  final xhr = html.HttpRequest();
  xhr.open('POST', url);
  headers.forEach((k, v) => xhr.setRequestHeader(k, v));
  xhr.responseType = 'text';

  xhr.onProgress.listen((_) {
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
          if (!controller.isClosed) controller.close();
          return;
        }
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final choices = json['choices'] as List<dynamic>;
          if (choices.isNotEmpty) {
            final delta = choices[0]['delta'] as Map<String, dynamic>?;
            final content = delta?['content'] as String?;
            if (content != null && content.isNotEmpty) {
              controller.add(content);
            }
          }
        } catch (_) {
          // 跳过无法解析的行
        }
      }
    }
    processedLines = completeCount;
  });

  xhr.onError.listen((_) {
    if (!controller.isClosed) {
      controller.addError('网络请求失败');
    }
  });

  xhr.onLoadEnd.listen((_) {
    if (!controller.isClosed) controller.close();
  });

  xhr.send(body);

  yield* controller.stream;
}
