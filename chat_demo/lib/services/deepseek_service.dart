import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

class DeepSeekService {
  static const _baseUrl = 'https://api.deepseek.com';
  static const _model = 'deepseek-v4-flash';
  static const _apiKey = 'sk-9377402d779d4d3192d37b09dc7a1cbf';

  Stream<String> chatStream(List<Map<String, String>> messages) async* {
    final controller = StreamController<String>();
    int processedLines = 0;

    final xhr = html.HttpRequest();
    xhr.open('POST', '$_baseUrl/chat/completions');
    xhr.setRequestHeader('Authorization', 'Bearer $_apiKey');
    xhr.setRequestHeader('Content-Type', 'application/json');
    xhr.setRequestHeader('Accept', 'text/event-stream');
    xhr.responseType = 'text';

    xhr.onProgress.listen((_) {
      final fullText = xhr.responseText ?? '';
      final lines = fullText.split('\n');
      // Last index after split is always the incomplete tail (or empty)
      final completeCount = lines.length - 1;
      if (completeCount <= processedLines) return;

      for (var i = processedLines; i < completeCount; i++) {
        final line = lines[i];
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') {
            controller.close();
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
          } catch (_) {}
        }
      }
      processedLines = completeCount;
    });

    xhr.onError.listen((_) {
      if (!controller.isClosed) controller.addError('网络请求失败');
    });

    xhr.onLoadEnd.listen((_) {
      if (!controller.isClosed) controller.close();
    });

    xhr.send(jsonEncode({
      'model': _model,
      'messages': messages,
      'stream': true,
    }));

    yield* controller.stream;
  }
}
