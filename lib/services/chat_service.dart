import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

// ====================================================================
// ChatService — AI 聊天服务抽象层
// ====================================================================
//
// 静态方法封装，提供流式/非流式两种聊天接口。
// 当前为 Mock 实现，模拟 AI 逐词输出 markdown 格式回复。
// TODO: Replace mock with actual API call
// ====================================================================

class ChatService {
  ChatService._(); // 私有构造，禁止实例化

  static StreamController<String>? _controller;

  /// 当前是否有活跃的流
  static bool get isStreamActive =>
      _controller != null && !_controller!.isClosed;

  /// 存放完整的 mock 回复（由 _buildMockResponse 生成）
  static String _lastMockResponse = '';

  // ==================================================================
  // Public API
  // ==================================================================

  /// 流式发送消息 — 逐词 yield 模拟 AI 打字效果
  ///
  /// 返回 [Stream<String>]，可通过 [cancelStream] 提前终止。
  // TODO: Replace mock with actual API call
  static Stream<String> sendStream(String text) {
    cancelStream();

    _controller = StreamController<String>(
      onCancel: () {
        debugPrint('ChatService.sendStream: stream cancelled by listener');
        _cleanUp();
      },
    );

    final input = text.trim();
    _lastMockResponse = _buildMockResponse(input);

    debugPrint('ChatService.sendStream: starting mock stream');
    _simulateTyping(_lastMockResponse, _controller!);

    return _controller!.stream;
  }

  /// 非流式发送消息 — 返回完整回复
  ///
  /// 内部通过流收集实现，确保两种接口行为一致。
  // TODO: Replace mock with actual API call
  static Future<String> send(String text) async {
    final chunks = <String>[];
    await for (final chunk in sendStream(text)) {
      chunks.add(chunk);
    }
    return chunks.join('');
  }

  /// 取消正在进行的流
  static void cancelStream() {
    if (_controller != null && !_controller!.isClosed) {
      debugPrint('ChatService.cancelStream: cancelling active stream');
      _controller!.close();
    }
    _cleanUp();
  }

  // ==================================================================
  // Mock implementation
  // ==================================================================

  /// 根据用户输入生成 mock 回复（中文 + Markdown 格式）
  // TODO: Replace mock with actual API call
  static String _buildMockResponse(String input) {
    // 根据输入内容做简单分流，让测试更有真实感
    final lower = input.toLowerCase();

    if (lower.contains('hello') ||
        lower.contains('hi') ||
        lower.contains('hey') ||
        lower.contains('你好')) {
      return '''# 👋 Hello! Great to hear from you!

I'm **Stroom AI**, your creative assistant. Here's what I can help you with:

- **Image generation** — Create stunning visuals from text prompts
- **Audio processing** — Convert speech to text and back
- **Project management** — Organise your media assets

> "Creativity is intelligence having fun." — Albert Einstein

Let me know what you'd like to work on today! 🚀''';
    }

    if (lower.contains('help') ||
        lower.contains('?') ||
        lower.contains('what')) {
      return '''# 💡 Help & Commands

Here are the things I can do:

| Command | Description |
|---------|-------------|
| `generate` | Create an image from a prompt |
| `transcribe` | Convert audio to text |
| `summarise` | Summarise a block of text |
| `analyse` | Analyse an image or file |

## Example usage

```dart
// Generate a futuristic cityscape
await ChatService.send('generate a cyberpunk city at night');
```

**Pro tip:** Try asking me to *analyse* an image or *transcribe* an audio file for best results.''';
    }

    // 默认回复
    return '''# ✅ Got it!

I've received your message and here's my analysis:

## Key points

1. Your input has been **processed** successfully
2. The system is ready for the next step
3. All checks passed with flying colours ✨

### Code snippet

```dart
// Processed input: "$input"
final result = await ChatService.send(input);
debugPrint('Response: \$result');
```

> **Note:** This is a mock response. The real implementation will connect to an AI service.

| Property | Value |
|----------|-------|
| Status | ✅ Complete |
| Length | ${input.length} chars |
| Format | Markdown |

*Feel free to ask me anything else!*''';
  }

  /// 模拟打字：按单词 yield，单词间约 80ms 延迟，起始 500ms 停顿
  static Future<void> _simulateTyping(
    String response,
    StreamController<String> controller,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));

    // 按空白符切分，保持原样输出（包含空格、换行等）
    final words = response.split(' ');

    try {
      for (int i = 0; i < words.length; i++) {
        if (controller.isClosed) return;

        final chunk = i == 0 ? words[i] : ' ${words[i]}';
        controller.add(chunk);

        // 遇到句尾、冒号、列表符号处额外停顿，模拟思考
        if (chunk.endsWith('.') || chunk.endsWith('!') || chunk.endsWith('?')) {
          await Future.delayed(const Duration(milliseconds: 200));
        } else if (chunk.endsWith(':') || chunk.endsWith('|')) {
          await Future.delayed(const Duration(milliseconds: 150));
        } else {
          await Future.delayed(const Duration(milliseconds: 80));
        }
      }

      if (!controller.isClosed) {
        await controller.close();
        debugPrint('ChatService._simulateTyping: stream completed');
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
        await controller.close();
      }
      debugPrint('ChatService._simulateTyping: error - $e');
    } finally {
      _cleanUp();
    }
  }

  // ==================================================================
  // Internal helpers
  // ==================================================================

  /// 清理 _controller 引用
  static void _cleanUp() {
    if (_controller?.isClosed ?? true) {
      _controller = null;
    }
  }
}
