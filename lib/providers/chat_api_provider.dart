import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/chat_message.dart';

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

    final url = '$_baseUrl/chat/completions';
    debugPrint(
        'OpenAICompatibleChatProvider: POST $url - 消息数: ${messages.length}');

    try {
      final response = await _dio.post(
        url,
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
      throw Exception('对话失败: ${_parseDioError(e)}');
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
  }) async* {
    if (_apiKey.isEmpty) {
      yield '**[错误: API 密钥未配置]**';
      return;
    }

    final body = _buildBody(messages,
        model: model,
        maxTokens: maxTokens,
        temperature: temperature,
        stream: true,
        extraParams: extraParams);

    final url = '$_baseUrl/chat/completions';
    debugPrint(
        'OpenAICompatibleChatProvider: 流式 POST $url - 消息数: ${messages.length}');

    try {
      final response = await _dio.post(
        url,
        options: Options(responseType: ResponseType.stream),
        data: body,
      );

      final rawStream = response.data.stream as Stream<Uint8List>;
      final lineStream = rawStream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lineStream) {
        // SSE 格式: "data: {json}"
        if (line.startsWith('data: ')) {
          final dataStr = line.substring(6).trim();

          // 结束信号
          if (dataStr == '[DONE]') break;

          try {
            final data = jsonDecode(dataStr) as Map<String, dynamic>;
            final choices = data['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices[0]['delta'] as Map<String, dynamic>?;
              if (delta != null) {
                final content = delta['content'] as String?;
                if (content != null && content.isNotEmpty) {
                  yield content;
                }
              }
            }
          } catch (e) {
            debugPrint('OpenAICompatibleChatProvider: 解析 SSE 数据失败: $e');
            // 跳过无法解析的行，继续处理后续数据
          }
        }
      }
    } on DioException catch (e) {
      debugPrint('OpenAICompatibleChatProvider: 流式失败: ${_parseDioError(e)}');
      yield '**[流式响应错误: ${_parseDioError(e)}]**';
    } catch (e) {
      debugPrint('OpenAICompatibleChatProvider: 流式异常: $e');
      yield '**[流式响应错误: $e]**';
    }
  }

  // ── Dio 错误解析 ────────────────────────────────────────────────

  String _parseDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时';
      case DioExceptionType.receiveTimeout:
        return '接收超时，服务器响应过慢';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final body = e.response?.data;
        String bodyStr;
        if (body is List<int>) {
          try {
            bodyStr = utf8.decode(body);
          } catch (_) {
            bodyStr = body.toString();
          }
        } else {
          bodyStr = body?.toString() ?? '无响应体';
        }
        if (statusCode == 401 || statusCode == 403) {
          return 'API密钥无效或权限不足';
        }
        if (statusCode == 429) return '请求过于频繁';
        if (statusCode == 404) return 'API端点不存在';
        if (statusCode == 500) return '服务器内部错误 (HTTP $statusCode): $bodyStr';
        return '服务器返回错误 (HTTP $statusCode): $bodyStr';
      case DioExceptionType.cancel:
        return '请求已取消';
      default:
        return '网络错误';
    }
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
