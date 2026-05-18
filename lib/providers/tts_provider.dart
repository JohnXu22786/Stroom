import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'provider_config.dart';

import '../utils/audio_utils.dart';

/// TTS供应商抽象基类
/// 采用策略模式，为不同的语音合成服务提供统一的调用接口
abstract class BaseTTSProvider {
  /// 供应商名称
  String get name;

  /// 支持的模型列表
  List<String> get supportedModels;

  /// 合成语音，返回完整的音频数据
  /// [text] 要合成的文本
  /// [params] 合成参数（语音、速度、音量、格式等）
  /// [cancelToken] 可选的取消令牌
  Future<Uint8List> synthesize(
    String text, {
    Map<String, dynamic>? params,
    CancelToken? cancelToken,
  });

  /// 流式合成语音，返回音频数据流
  /// [text] 要合成的文本
  /// [params] 合成参数
  Stream<Uint8List> streamSynthesize(
    String text, {
    Map<String, dynamic>? params,
  });

  /// 验证并合并参数
  /// [userParams] 用户提供的参数
  /// 返回验证后的完整参数集
  Map<String, dynamic> validateParams(Map<String, dynamic> userParams);

  /// 获取默认参数配置
  Map<String, dynamic> get defaultParams;

  @override
  String toString() {
    return '$runtimeType(name: "$name", models: $supportedModels)';
  }
}

/// 根据 ProviderConfigItem 创建 TTS provider 实例
///
/// 所有供应商统一走 CustomTTSProvider，不依赖字符串猜测类型。
BaseTTSProvider createProviderFromConfig(ProviderConfigItem config) {
  return CustomTTSProvider(
    baseUrl: config.host,
    apiKey: config.key,
    name: config.providerName,
  );
}

/// 自定义 TTS 供应商 — 通用 HTTP 壳子
///
/// POST 到配置的 baseUrl，自动构建请求体，
/// 并将完整 HTTP 响应体作为原始音频数据返回。
class CustomTTSProvider extends BaseTTSProvider {
  final String _apiKey;
  final String _baseUrl;
  final String _name;
  final Dio _dio;

  CustomTTSProvider({
    required String baseUrl,
    String apiKey = '',
    String name = 'custom',
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
          receiveTimeout: const Duration(seconds: 30),
        ));

  @override
  String get name => _name;

  @override
  List<String> get supportedModels => [];

  /// 内部参数名列表（这些不会发送到 API）
  static const _internalParamKeys = {
    'format',
    'response_format',
    'sample_rate',
    'stream',
    'volume',
  };

  Map<String, dynamic> _buildBody(String input, Map<String, dynamic> params) {
    final body = <String, dynamic>{};
    // 始终包含 input
    body['input'] = input;
    // 将 params 中所有非内部参数传递给 API
    for (final entry in params.entries) {
      if (!_internalParamKeys.contains(entry.key)) {
        body[entry.key] = entry.value;
      }
    }
    return body;
  }

  @override
  Map<String, dynamic> get defaultParams => {
        'voice': 'alloy',
        'speed': 1.0,
        'volume': 1.0,
        'format': 'wav',
        'sample_rate': 24000,
        'response_format': 'wav',
      };

  @override
  Map<String, dynamic> validateParams(Map<String, dynamic> userParams) {
    final params = Map<String, dynamic>.from(defaultParams);
    params.addAll(userParams);
    // 语速/音量范围由模型配置管理，此处不做 provider 级校验
    return params;
  }

  @override
  Future<Uint8List> synthesize(String text,
      {Map<String, dynamic>? params, CancelToken? cancelToken}) async {
    if (_apiKey.isEmpty) throw Exception('API 密钥未配置');
    final validated = validateParams(params ?? {});
    final body = _buildBody(text, validated);

    debugPrint('CustomTTSProvider: POST $_baseUrl - 文本长度: ${text.length}');
    try {
      final response = await _dio.post(
        _baseUrl,
        options: Options(responseType: ResponseType.bytes),
        cancelToken: cancelToken,
        data: body,
      );
      var data = Uint8List.fromList(response.data);
      if (data.isEmpty) throw Exception('供应商返回了空的音频数据');
      // 将 API 返回的 PCM 转为 WAV
      if (data.isNotEmpty) {
        final fixed = ensureValidAudioFormat(
          data,
          requestedFormat: 'wav',
          sampleRate: (validated['sample_rate'] as num?)?.toInt() ?? 24000,
        );
        data = fixed.$1;
      }
      return data;
    } on DioException catch (e) {
      throw Exception('合成失败: ${_parseDioError(e)}');
    }
  }

  @override
  Stream<Uint8List> streamSynthesize(String text,
      {Map<String, dynamic>? params}) async* {
    if (_apiKey.isEmpty) throw Exception('API 密钥未配置');
    final validated = validateParams(params ?? {});
    final body = _buildBody(text, validated);
    body['stream'] = true;

    try {
      final response = await _dio.post(
        _baseUrl,
        options: Options(responseType: ResponseType.stream),
        data: body,
      );
      final stream = response.data.stream as Stream<Uint8List>;
      await for (final chunk in stream) {
        if (chunk.isNotEmpty) yield chunk;
      }
    } on DioException catch (e) {
      debugPrint('CustomTTSProvider: 流式失败，回退到非流式: ${_parseDioError(e)}');
      // 移除 stream 参数，避免非流式请求中包含 stream: true
      final sanitizedParams = params != null
          ? Map<String, dynamic>.from(params)
          : <String, dynamic>{};
      sanitizedParams.remove('stream');
      yield await synthesize(text, params: sanitizedParams);
    }
  }

  String _parseDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络';
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
        if (statusCode == 401 || statusCode == 403)
          return 'API密钥无效或权限不足 (HTTP $statusCode): $bodyStr';
        if (statusCode == 429) return '请求过于频繁，请稍后重试 (HTTP $statusCode)';
        if (statusCode == 404)
          return 'API端点不存在 (HTTP 404): $bodyStr\n请检查API基础URL设置是否正确';
        if (statusCode == 500) return '服务器内部错误 (HTTP $statusCode): $bodyStr';
        return '服务器返回错误 (HTTP $statusCode): $bodyStr';
      case DioExceptionType.cancel:
        return '请求已取消';
      default:
        return '网络错误: ${e.message}';
    }
  }
}
