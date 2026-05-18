import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/chat_message.dart';
import '../services/sse_client.dart';

// ============================================================================
// 抽象基类 — BaseChatProvider
// ============================================================================

/// 聊天 API 供应商抽象基类
/// 采用策略模式，为不同的 LLM 聊天服务提供统一调用接口
abstract class BaseChatProvider {
  /// 供应商名称
  String get name;

  /// 支持的模型 ID 列表
  List<String> get supportedModelIds;

  /// 非流式对话，返回完整回复文本
  Future<String> chat(
    List<ChatMessage> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    CancelToken? cancelToken,
    Map<String, dynamic>? extraParams,
  });

  /// 流式对话，逐段 yield 回复文本
  Stream<String> chatStream(
    List<ChatMessage> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    Map<String, dynamic>? extraParams,
    CancelToken? cancelToken,
  });

  /// 获取默认参数配置
  Map<String, dynamic> get defaultParams;
}

// ============================================================================
// OpenAI Compatible 实现
// ============================================================================

/// OpenAI API 兼容的聊天供应商
///
/// 支持 OpenAI、Azure OpenAI、以及所有兼容 OpenAI API 格式的服务
/// （如 DeepSeek、Moonshot、Qwen 等）。
class OpenAICompatibleChatProvider extends BaseChatProvider {
  final String _apiKey;
  final String _baseUrl;
  final String _name;
  final Dio _dio;

  OpenAICompatibleChatProvider({
    required String baseUrl,
    required String apiKey,
    String name = 'OpenAI Compatible',
  })  : _baseUrl = baseUrl,
        _apiKey = apiKey,
        _name = name,
        _dio = Dio(BaseOptions(
          baseUrl: '',
          headers: {
            'Content-Type': 'application/json',
            if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
          },
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 60),
        ));

  @override
  String get name => _name;

  @override
  List<String> get supportedModelIds => [];

  /// 构建请求体
  Map<String, dynamic> _buildBody(
    List<ChatMessage> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    bool stream = false,
    Map<String, dynamic>? extraParams,
  }) {
    return {
      // extraParams 放在前面，显式参数放在后面覆盖，防止用户自定义参数
      // 意外覆盖 model/messages/max_tokens/temperature/stream 等关键字段
      if (extraParams != null) ...extraParams,
      'model': model ?? defaultParams['model'],
      'messages': messages
          .map((m) => {
                'role': m.role,
                'content': m.content,
              })
          .toList(),
      'max_tokens': maxTokens ?? defaultParams['max_tokens'],
      'temperature': temperature ?? defaultParams['temperature'],
      'stream': stream,
    };
  }

  @override
  Map<String, dynamic> get defaultParams => {
        'model': 'gpt-4o',
        'max_tokens': 4096,
        'temperature': 0.7,
      };

  // ── 非流式对话 ──────────────────────────────────────────────────

  @override
  Future<String> chat(
    List<ChatMessage> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    CancelToken? cancelToken,
    Map<String, dynamic>? extraParams,
  }) async {
    if (_apiKey.isEmpty) throw Exception('API 密钥未配置');

    final body = _buildBody(messages,
        model: model,
        maxTokens: maxTokens,
        temperature: temperature,
        extraParams: extraParams);

    debugPrint(
        'OpenAICompatibleChatProvider: POST $_baseUrl - 消息数: ${messages.length}');

    try {
      final response = await _dio.post(
        _baseUrl,
        cancelToken: cancelToken,
        data: body,
      );

      final choices = response.data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception('API 返回了空的 choices 列表');
      }
      final content = choices[0]['message']?['content'] as String?;
      if (content == null) {
        throw Exception('API 返回内容为空');
      }
      return content;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode ?? 0;
      final body = e.response?.data;
      String detail;
      if (body is Map) {
        detail = body['error'] is Map
            ? '${body['error']['message'] ?? body}'
            : '$body';
      } else if (body is String) {
        detail = body;
      } else {
        detail = '$body';
      }
      throw Exception('API 请求失败 (HTTP $statusCode): $detail');
    }
  }

  // ── 流式对话 ────────────────────────────────────────────────────

  @override
  Stream<String> chatStream(
    List<ChatMessage> messages, {
    String? model,
    int? maxTokens,
    double? temperature,
    Map<String, dynamic>? extraParams,
    CancelToken? cancelToken,
  }) async* {
    if (_apiKey.isEmpty) return;

    final body = _buildBody(messages,
        model: model,
        maxTokens: maxTokens,
        temperature: temperature,
        stream: true,
        extraParams: extraParams);

    debugPrint(
        'OpenAICompatibleChatProvider: 流式 POST $_baseUrl - 消息数: ${messages.length}');

    yield* sseStream(
      _baseUrl,
      {
        'Content-Type': 'application/json',
        if (_apiKey.isNotEmpty) 'Authorization': 'Bearer $_apiKey',
        'Accept': 'text/event-stream',
      },
      jsonEncode(body),
      cancelToken: cancelToken,
    );
  }
}

// ============================================================================
// 工厂函数
// ============================================================================

/// 根据配置创建聊天供应商实例
///
/// [providerName] 供应商名称
/// [baseUrl] API 基础 URL
/// [apiKey] API 密钥
/// [model] 可选，默认模型 ID
BaseChatProvider createChatProviderFromConfig({
  required String providerName,
  required String baseUrl,
  required String apiKey,
  String? model,
}) {
  // For now, always return OpenAICompatibleChatProvider
  // Future: support other provider types
  return OpenAICompatibleChatProvider(
    baseUrl: baseUrl,
    apiKey: apiKey,
    name: providerName,
  );
}
