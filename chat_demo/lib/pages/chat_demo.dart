import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:flutter_highlight/themes/dracula.dart';
import '../services/deepseek_service.dart';

class ChatDemoPage extends StatefulWidget {
  const ChatDemoPage({super.key});

  @override
  State<ChatDemoPage> createState() => _ChatDemoPageState();
}

class _ChatDemoPageState extends State<ChatDemoPage> {
  late final InMemoryChatController _controller;
  late final User _currentUser;
  late final User _aiUser;
  late final DeepSeekService _api;
  final List<Map<String, String>> _history = [];
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    _currentUser = User(id: 'user1', name: 'You');
    _aiUser = User(id: 'ai1', name: 'DeepSeek');
    _api = DeepSeekService();
    _controller = InMemoryChatController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onMessageSend(String text) async {
    if (_isStreaming) return;
    _isStreaming = true;

    final userMsgId = 'u${DateTime.now().millisecondsSinceEpoch}';
    final aiMsgId = 'a${DateTime.now().millisecondsSinceEpoch}';

    _history.add({'role': 'user', 'content': text});
    await _controller.insertMessage(Message.text(
      id: userMsgId,
      authorId: _currentUser.id,
      text: text,
      createdAt: DateTime.now(),
    ));

    final placeholder = Message.textStream(
      id: aiMsgId,
      authorId: _aiUser.id,
      createdAt: DateTime.now(),
      streamId: aiMsgId,
    );
    await _controller.insertMessage(placeholder);

    String fullReply = '';
    await for (final chunk in _api.chatStream(_history)) {
      fullReply += chunk;
      await _controller.updateMessage(
        placeholder,
        Message.text(
          id: aiMsgId,
          authorId: _aiUser.id,
          text: fullReply,
          createdAt: DateTime.now(),
        ),
      );
    }

    _history.add({'role': 'assistant', 'content': fullReply});
    _isStreaming = false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final markdownConfig = isDark
        ? MarkdownConfig.darkConfig
        : MarkdownConfig.defaultConfig;

    return Chat(
      currentUserId: _currentUser.id,
      resolveUser: (id) async {
        if (id == _currentUser.id) return _currentUser;
        if (id == _aiUser.id) return _aiUser;
        return null;
      },
      chatController: _controller,
      onMessageSend: _onMessageSend,
      theme: ChatTheme.light(),
      builders: Builders(
        textMessageBuilder: (context, message, index, {required bool isSentByMe, MessageGroupStatus? groupStatus}) {
          final isAi = message.authorId == _aiUser.id;

          if (isAi) {
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: MarkdownWidget(
                data: message.text,
                selectable: true,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                config: markdownConfig.copy(configs: [
                  PreConfig(theme: draculaTheme),
                ]),
              ),
            );
          }

          return SimpleTextMessage(message: message, index: index);
        },
        textStreamMessageBuilder: (context, message, index, {required bool isSentByMe, MessageGroupStatus? groupStatus}) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      ),
    );
  }
}
