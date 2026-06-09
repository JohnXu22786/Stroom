import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/assistant.dart' show CustomParameter;
import '../models/chat_event.dart';
import '../models/chat_message.dart';
import '../models/tool_call.dart';
import '../providers/provider_config.dart';
import 'chat_service.dart';
import '../providers/chat_api_provider.dart';

/// 表示一个可选的模型项
class AvailableModel {
  /// 显示名："[model.name ?? model.modelId] | [providerName]"
  final String displayName;

  /// 指向 llmEntry.configs[configIndex]
  final int configIndex;

  /// 指向 configs[configIndex].models[modelIndex]
  final int modelIndex;

  const AvailableModel({
    required this.displayName,
    required this.configIndex,
    required this.modelIndex,
  });
}

/// 桥接层：将我们的供应商/模型配置系统适配到 flutter_chat_ui 的流式调用
class ChatAdapter {
  ChatService? _chatService;

  /// 当前选中的配置索引（指向 llmEntry.configs）
  int currentConfigIndex = -1;

  /// 当前选中的模型索引（指向 configs[currentConfigIndex].models）
  int currentModelIndex = -1;

  bool get isConfigured => _chatService != null;

  /// 从 ProviderEntriesState 解析出所有可选的模型列表
  List<AvailableModel> availableModels(ProviderEntriesState entriesState) {
    final llmEntry =
        entriesState.entries.where((e) => e.type == 'llm').firstOrNull;
    if (llmEntry == null || llmEntry.configs.isEmpty) return const [];

    final result = <AvailableModel>[];
    for (var ci = 0; ci < llmEntry.configs.length; ci++) {
      final config = llmEntry.configs[ci];
      for (var mi = 0; mi < config.models.length; mi++) {
        final model = config.models[mi];
        final displayName =
            '${model.name.isNotEmpty ? model.name : model.modelId} | ${config.providerName}';
        result.add(AvailableModel(
          displayName: displayName,
          configIndex: ci,
          modelIndex: mi,
        ));
      }
    }
    return result;
  }

  /// 从 ProviderEntriesState 读取 LLM 配置并初始化 ChatService
  void configure(ProviderEntriesState entriesState) {
    final llmEntry =
        entriesState.entries.where((e) => e.type == 'llm').firstOrNull;
    if (llmEntry == null || llmEntry.configs.isEmpty) {
      debugPrint('ChatAdapter.configure: no LLM entry or configs');
      _chatService = null;
      currentConfigIndex = -1;
      currentModelIndex = -1;
      return;
    }
    final config = llmEntry.configs.first;
    if (config.host.isEmpty || config.key.isEmpty) {
      debugPrint('ChatAdapter.configure: first config host or key empty');
      _chatService = null;
      currentConfigIndex = -1;
      currentModelIndex = -1;
      return;
    }
    final modelConfig = config.models.isNotEmpty ? config.models.first : null;
    if (modelConfig == null) {
      debugPrint('ChatAdapter.configure: no models in first config');
      _chatService = null;
      currentConfigIndex = -1;
      currentModelIndex = -1;
      return;
    }
    debugPrint('ChatAdapter.configure: host=${config.host} model=${modelConfig.modelId}');
    final provider = createChatProviderFromConfig(
      providerName: config.providerName,
      baseUrl: config.host,
      apiKey: config.key,
    );
    _chatService = ChatService(provider: provider, modelConfig: modelConfig);
    currentConfigIndex = 0;
    currentModelIndex = 0;
  }

  /// 根据 configIndex / modelIndex 重新创建 ChatService
  void selectModel(
      ProviderEntriesState entriesState, int configIndex, int modelIndex) {
    final llmEntry =
        entriesState.entries.where((e) => e.type == 'llm').firstOrNull;
    if (llmEntry == null ||
        configIndex < 0 ||
        configIndex >= llmEntry.configs.length) {
      debugPrint('ChatAdapter.selectModel: invalid configIndex=$configIndex');
      _chatService = null;
      currentConfigIndex = -1;
      currentModelIndex = -1;
      return;
    }
    final config = llmEntry.configs[configIndex];
    if (config.host.isEmpty || config.key.isEmpty) {
      debugPrint('ChatAdapter.selectModel: config[$configIndex] host or key empty');
      _chatService = null;
      currentConfigIndex = -1;
      currentModelIndex = -1;
      return;
    }
    if (modelIndex < 0 || modelIndex >= config.models.length) {
      debugPrint('ChatAdapter.selectModel: invalid modelIndex=$modelIndex');
      _chatService = null;
      currentConfigIndex = -1;
      currentModelIndex = -1;
      return;
    }
    final modelConfig = config.models[modelIndex];
    debugPrint('ChatAdapter.selectModel: using config[$configIndex] host=${config.host} model=${modelConfig.modelId}');
    final provider = createChatProviderFromConfig(
      providerName: config.providerName,
      baseUrl: config.host,
      apiKey: config.key,
    );
    _chatService = ChatService(provider: provider, modelConfig: modelConfig);
    currentConfigIndex = configIndex;
    currentModelIndex = modelIndex;
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
    currentConfigIndex = -1;
    currentModelIndex = -1;
  }

  /// Pass assistant-level custom parameters to the underlying ChatService.
  /// These will be merged into the API request body alongside model-level params.
  void setAssistantCustomParams(List<CustomParameter>? params) {
    _chatService?.setAssistantCustomParams(params);
  }

  Stream<String> sendStream(String text, {required List<ChatMessage> history, bool reasoning = false}) {
    if (_chatService == null) {
      return Stream.error('请先配置聊天供应商');
    }
    return _chatService!.sendStream(text, history: history, reasoning: reasoning);
  }

  /// Send a message with tool call support.
  /// Returns a stream of [ChatEvent] (text chunks and tool call events).
  Stream<ChatEvent> sendStreamWithTools(
    String text, {
    required List<ChatMessage> history,
    bool reasoning = false,
    List<ToolDefinition> tools = const [],
  }) {
    if (_chatService == null) {
      return Stream.error('请先配置聊天供应商');
    }
    return _chatService!.sendStreamWithTools(
      text,
      history: history,
      reasoning: reasoning,
      tools: tools,
    );
  }

  String get reasoningContent => _chatService?.reasoningContent ?? '';

  Map<String, dynamic>? get lastRequestBody => _chatService?.lastRequestBody;
  Map<String, dynamic>? get lastResponseData => _chatService?.lastResponseData;
  Map<String, String>? get lastRequestHeaders => _chatService?.lastRequestHeaders;
  String? get lastRequestUrl => _chatService?.lastRequestUrl;
  int? get lastResponseStatusCode => _chatService?.lastResponseStatusCode;
  Map<String, List<String>>? get lastResponseHeaders => _chatService?.lastResponseHeaders;
}
