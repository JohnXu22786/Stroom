import 'dart:async';
import '../models/chat_message.dart';
import '../providers/provider_config.dart';
import 'chat_service.dart';
import '../providers/chat_api_provider.dart';

/// 桥接层：将我们的供应商/模型配置系统适配到 flutter_chat_ui 的流式调用
class ChatAdapter {
  ChatService? _chatService;

  bool get isConfigured => _chatService != null;

  /// 从 ProviderEntriesState 读取 LLM 配置并初始化 ChatService
  void configure(ProviderEntriesState entriesState) {
    final llmEntry =
        entriesState.entries.where((e) => e.type == 'llm').firstOrNull;
    if (llmEntry == null || llmEntry.configs.isEmpty) {
      _chatService = null;
      return;
    }
    final config = llmEntry.configs.first;
    if (config.host.isEmpty || config.key.isEmpty) {
      _chatService = null;
      return;
    }
    final modelConfig = config.models.isNotEmpty ? config.models.first : null;
    if (modelConfig == null) {
      _chatService = null;
      return;
    }
    final provider = createChatProviderFromConfig(
      providerName: config.providerName,
      baseUrl: config.host,
      apiKey: config.key,
    );
    _chatService = ChatService(provider: provider, modelConfig: modelConfig);
  }

  /// 取消当前流
  void cancel() {
    _chatService?.cancel();
  }

  /// 释放资源
  void dispose() {
    cancel();
    _chatService?.dispose();
    _chatService = null;
  }

  /// 流式发送消息，返回文本块流
  /// [text] 用户输入的消息
  /// [history] 对话历史（用于 API context）
  Stream<String> sendStream(String text, {required List<ChatMessage> history}) {
    if (_chatService == null) {
      return Stream.error('请先配置聊天供应商');
    }
    return _chatService!.sendStream(text, history: history);
  }
}
