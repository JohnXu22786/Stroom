import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'provider_config.dart';
import 'tts_config.dart';

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

/// GLM-TTS供应商实现
class GLMTTSProvider extends BaseTTSProvider {
  final String? _apiKey;
  final String _baseUrl;
  late final Dio _dio;

  GLMTTSProvider({String? apiKey, String? baseUrl})
      : _apiKey = apiKey,
        _baseUrl =
            baseUrl ?? 'https://open.bigmodel.cn/api/paas/v4/audio/speech' {
    _dio = Dio(BaseOptions(
      baseUrl: '',
      headers: {
        'Content-Type': 'application/json',
        if (_apiKey != null) 'Authorization': 'Bearer $_apiKey',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  @override
  String get name => 'glm_tts';

  @override
  List<String> get supportedModels => ['glm-tts'];

  @override
  Map<String, dynamic> get defaultParams {
    return {
      'voice': 'female',
      'speed': 1.0,
      'volume': 1.0,
      'format': 'wav',
      'sample_rate': 24000,
      'response_format': 'wav',
      'stream': false,
    };
  }

  @override
  Map<String, dynamic> validateParams(Map<String, dynamic> userParams) {
    final params = Map<String, dynamic>.from(defaultParams);
    params.addAll(userParams);

    // 语速范围验证：0.5 - 2.0
    if (params.containsKey('speed')) {
      final speed = (params['speed'] as num).toDouble();
      if (!validateSpeed('glm_tts', speed)) {
        final range = getSpeedRange('glm_tts');
        throw ArgumentError('语速必须在${range['min']}到${range['max']}之间');
      }
    }

    // 音量范围验证：0.0 - 2.0
    if (params.containsKey('volume')) {
      final volume = (params['volume'] as num).toDouble();
      if (!validateVolume('glm_tts', volume)) {
        final range = getVolumeRange('glm_tts');
        throw ArgumentError('音量必须在${range['min']}到${range['max']}之间');
      }
    }

    // 音频格式验证
    if (params.containsKey('format')) {
      final format = params['format'] as String;
      final supported = getSupportedFormats('glm_tts');
      if (!supported.contains(format.toLowerCase())) {
        throw ArgumentError('不支持的音频格式: $format，支持: $supported');
      }
    }

    // 音色验证
    if (params.containsKey('voice')) {
      final voice = params['voice'] as String;
      final voices = getSupportedVoices('glm_tts');
      if (!voices.contains(voice)) {
        debugPrint('警告: 音色 "$voice" 可能不受GLM-TTS支持，支持的音色: $voices');
      }
    }

    return params;
  }

  @override
  Future<Uint8List> synthesize(
    String text, {
    Map<String, dynamic>? params,
    CancelToken? cancelToken,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('GLM API密钥未配置，请在设置页面配置API密钥');
    }

    final validatedParams = validateParams(params ?? {});
    final format =
        (validatedParams['format'] as String?)?.toLowerCase() ?? 'wav';
    final responseFormat =
        (validatedParams['response_format'] as String?)?.toLowerCase() ??
            format;

    debugPrint('GLMTTSProvider: 开始非流式合成 - 文本长度: ${text.length} 字符');

    try {
      final startTime = DateTime.now();
      final response = await _dio.post(
        _baseUrl,
        options: Options(
          responseType: ResponseType.bytes,
        ),
        cancelToken: cancelToken,
        data: {
          'model': 'glm-tts',
          'input': text,
          'voice': validatedParams['voice'],
          'speed': validatedParams['speed'],
          'response_format': responseFormat,
          if (validatedParams.containsKey('instructions') &&
              (validatedParams['instructions'] as String).isNotEmpty)
            'instructions': validatedParams['instructions'],
        },
      );

      final audioData = Uint8List.fromList(response.data);
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;

      debugPrint(
          'GLMTTSProvider: 合成成功 - 音频大小: ${audioData.length} 字节, 耗时: ${elapsed}ms');

      if (audioData.isEmpty) {
        throw Exception('GLM-TTS返回了空的音频数据');
      }

      // 通用格式校验：API返回的实际数据可能不含有效头（如裸 PCM），自动修复
      final result = ensureValidAudioFormat(
        audioData,
        requestedFormat: format,
        sampleRate: (validatedParams['sample_rate'] as num?)?.toInt() ?? 24000,
      ).$1;

      return result;
    } on DioException catch (e) {
      final errorMsg = _parseDioError(e);
      debugPrint('GLMTTSProvider: API请求失败 - $errorMsg');
      throw Exception('GLM-TTS合成失败: $errorMsg');
    } catch (e) {
      debugPrint('GLMTTSProvider: 合成异常: $e');
      rethrow;
    }
  }

  @override
  Stream<Uint8List> streamSynthesize(
    String text, {
    Map<String, dynamic>? params,
  }) async* {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('GLM API密钥未配置');
    }

    final validatedParams = validateParams(params ?? {});
    final requestedFormat =
        (validatedParams['format'] as String?)?.toLowerCase() ?? 'wav';

    // 流式模式下强制使用pcm格式（GLM-TTS API限制）
    if (requestedFormat != 'pcm') {
      debugPrint(
          'GLMTTSProvider: 流式合成不支持直接输出"$requestedFormat"格式，已强制使用"pcm"格式');
      validatedParams['response_format'] = 'pcm';
    }

    final sampleRate =
        (validatedParams['sample_rate'] as num?)?.toInt() ?? 24000;
    final convertToTarget = requestedFormat != 'pcm';

    debugPrint('GLMTTSProvider: 开始流式合成 - 文本长度: ${text.length} 字符');

    try {
      final response = await _dio.post(
        _baseUrl,
        options: Options(
          responseType: ResponseType.stream,
        ),
        data: {
          'model': 'glm-tts',
          'input': text,
          'voice': validatedParams['voice'],
          'speed': validatedParams['speed'],
          'response_format': 'pcm',
          'stream': true,
          if (validatedParams.containsKey('instructions') &&
              (validatedParams['instructions'] as String).isNotEmpty)
            'instructions': validatedParams['instructions'],
        },
      );

      final audioStream = response.data.stream as Stream<Uint8List>;

      // 跟踪流处理
      var chunkCount = 0;
      var totalSize = 0;
      final pcmChunks = <Uint8List>[];
      final streamStartTime = DateTime.now();

      await for (final chunk in audioStream) {
        if (chunk.isEmpty) continue;

        chunkCount++;
        totalSize += chunk.length;

        // 检查数据块对齐（16位PCM需要2字节对齐）
        var alignedChunk = chunk;
        if (chunk.length % 2 != 0) {
          debugPrint(
              'GLMTTSProvider: 数据块 #$chunkCount 大小不对齐: ${chunk.length} 字节，已添加填充字节');
          alignedChunk = Uint8List.fromList([...chunk, 0x00]);
        }

        if (convertToTarget) {
          pcmChunks.add(alignedChunk);
        }

        yield alignedChunk;

        // 每5个数据块记录一次进度
        if (chunkCount % 5 == 0) {
          final elapsed =
              DateTime.now().difference(streamStartTime).inMilliseconds;
          final throughput = elapsed > 0 ? (totalSize / elapsed * 1000) : 0.0;
          debugPrint(
              'GLMTTSProvider: 流式进度 - 数据块: $chunkCount, 总大小: $totalSize 字节, '
              '耗时: ${elapsed}ms, 吞吐量: ${throughput.toStringAsFixed(1)} B/s');
        }
      }

      // 如果请求非PCM格式，进行格式转换
      if (convertToTarget && pcmChunks.isNotEmpty) {
        try {
          final pcmData =
              Uint8List(pcmChunks.fold<int>(0, (sum, c) => sum + c.length));
          var offset = 0;
          for (final chunk in pcmChunks) {
            pcmData.setRange(offset, offset + chunk.length, chunk);
            offset += chunk.length;
          }

          Uint8List convertedData;
          if (requestedFormat == 'wav') {
            convertedData = pcmToWav(pcmData, sampleRate: sampleRate);
          } else {
            // 其他格式暂不支持转换，返回原始PCM
            debugPrint('GLMTTSProvider: 格式"$requestedFormat"转换暂不支持，返回原始PCM数据');
            convertedData = pcmData;
          }

          yield convertedData;
        } catch (e) {
          debugPrint('GLMTTSProvider: 格式转换失败: $e，返回原始PCM数据');
          for (final chunk in pcmChunks) {
            yield chunk;
          }
        }
      }

      final totalTime =
          DateTime.now().difference(streamStartTime).inMilliseconds;
      debugPrint(
          'GLMTTSProvider: 流式合成完成 - 数据块: $chunkCount, 总大小: $totalSize 字节, '
          '总耗时: ${totalTime}ms');
    } on DioException catch (e) {
      final errorMsg = _parseDioError(e);
      debugPrint('GLMTTSProvider: 流式合成失败 - $errorMsg');
      throw Exception('GLM-TTS流式合成失败: $errorMsg');
    } catch (e) {
      debugPrint('GLMTTSProvider: 流式合成异常: $e');
      rethrow;
    }
  }

  /// 解析Dio错误为可读消息，保留原始错误详情
  String _parseDioError(DioException e) {
    final String origMsg = e.message ?? '';
    final String extra = origMsg.isNotEmpty ? '\n原始错误: $origMsg' : '';
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络$extra';
      case DioExceptionType.receiveTimeout:
        return '接收超时，服务器响应过慢$extra';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final body = e.response?.data;
        // 尝试将字节数组解码为字符串
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
          return 'API密钥无效或权限不足 (HTTP $statusCode): $bodyStr$extra';
        } else if (statusCode == 429) {
          return '请求过于频繁，请稍后重试 (HTTP $statusCode)$extra';
        } else if (statusCode == 500) {
          return '服务器内部错误 (HTTP $statusCode): $bodyStr$extra';
        } else if (statusCode == 404) {
          return 'API端点不存在 (HTTP 404): $bodyStr\n请检查API基础URL设置是否正确$extra';
        }
        return '服务器返回错误 (HTTP $statusCode): $bodyStr$extra';
      case DioExceptionType.cancel:
        return '请求已取消$extra';
      default:
        if (e.type == DioExceptionType.connectionError && kIsWeb) {
          return '无法连接到服务器。Web端常见原因：CORS跨域限制或API地址不正确。请检查：1) 供应商配置中的API地址是否正确 2) 服务器是否允许跨域请求$extra';
        }
        return '网络错误: ${e.message}';
    }
  }

  /// 获取底层Dio实例（用于调试或扩展）
  Dio get client => _dio;
}

/// AIHUBMIX-TTS供应商实现（OpenAI兼容API）
class AIHUBMIXTTSProvider extends BaseTTSProvider {
  final String? _apiKey;
  final String _baseUrl;
  final String? _model;
  late final Dio _dio;

  /// 初始化AIHUBMIX TTS供应商
  /// [apiKey] AIHUBMIX API密钥
  /// [baseUrl] API基础URL（可选，默认 https://aihubmix.com/v1/audio/speech）
  /// [model] 模型名称（可选，默认 gpt-4o-mini-tts）
  AIHUBMIXTTSProvider({
    String? apiKey,
    String? baseUrl,
    String? model,
  })  : _apiKey = apiKey,
        _baseUrl = baseUrl ?? 'https://aihubmix.com/v1/audio/speech',
        _model = model {
    _dio = Dio(BaseOptions(
      baseUrl: '',
      headers: {
        'Content-Type': 'application/json',
        if (_apiKey != null) 'Authorization': 'Bearer $_apiKey',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  @override
  String get name => 'aihubmix_tts';

  @override
  List<String> get supportedModels => [
        'gpt-4o-mini-tts',
        'tts-1',
        'gemini-2.5-flash-preview-tts',
      ];

  @override
  Map<String, dynamic> get defaultParams {
    return {
      'voice': 'alloy',
      'model': _model ?? 'gpt-4o-mini-tts',
      'speed': 1.0,
      'volume': 1.0,
      'format': 'mp3',
      'sample_rate': 24000,
      'response_format': 'mp3',
      'stream': false,
    };
  }

  @override
  Map<String, dynamic> validateParams(Map<String, dynamic> userParams) {
    final params = Map<String, dynamic>.from(defaultParams);
    params.addAll(userParams);

    // 语速范围验证：0.25 - 4.0
    if (params.containsKey('speed')) {
      final speed = (params['speed'] as num).toDouble();
      if (!validateSpeed('aihubmix_tts', speed)) {
        final range = getSpeedRange('aihubmix_tts');
        throw ArgumentError('语速必须在${range['min']}到${range['max']}之间');
      }
    }

    // 音量范围验证：0.0 - 2.0
    if (params.containsKey('volume')) {
      final volume = (params['volume'] as num).toDouble();
      if (!validateVolume('aihubmix_tts', volume)) {
        final range = getVolumeRange('aihubmix_tts');
        throw ArgumentError('音量必须在${range['min']}到${range['max']}之间');
      }
    }

    // 音频格式验证
    if (params.containsKey('format')) {
      final format = params['format'] as String;
      final supported = getSupportedFormats('aihubmix_tts');
      if (!supported.contains(format.toLowerCase())) {
        throw ArgumentError('不支持的音频格式: $format，支持: $supported');
      }
    }

    // 模型验证
    if (params.containsKey('model')) {
      final model = params['model'] as String;
      if (!supportedModels.contains(model)) {
        throw ArgumentError('不支持的模型: $model，支持: $supportedModels');
      }
    }

    // 音色验证
    if (params.containsKey('voice')) {
      final voice = params['voice'] as String;
      final voices = getSupportedVoices('aihubmix_tts');
      if (!voices.contains(voice)) {
        debugPrint('警告: 音色 "$voice" 可能不受AIHUBMIX-TTS支持，支持的音色: $voices');
      }
    }

    return params;
  }

  @override
  Future<Uint8List> synthesize(
    String text, {
    Map<String, dynamic>? params,
    CancelToken? cancelToken,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('AIHUBMIX API密钥未配置，请在设置页面配置API密钥');
    }

    final validatedParams = validateParams(params ?? {});
    final responseFormat =
        (validatedParams['response_format'] as String?)?.toLowerCase() ?? 'mp3';

    debugPrint('AIHUBMIXTTSProvider: 开始非流式合成 - 文本长度: ${text.length} 字符');

    try {
      final startTime = DateTime.now();
      final response = await _dio.post(
        _baseUrl,
        options: Options(
          responseType: ResponseType.bytes,
        ),
        cancelToken: cancelToken,
        data: {
          'model': validatedParams['model'],
          'input': text,
          'voice': validatedParams['voice'],
          'speed': validatedParams['speed'],
          'response_format': responseFormat,
          if (validatedParams.containsKey('instructions') &&
              (validatedParams['instructions'] as String).isNotEmpty)
            'instructions': validatedParams['instructions'],
        },
      );

      final audioData = Uint8List.fromList(response.data);
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;

      debugPrint(
          'AIHUBMIXTTSProvider: 合成成功 - 音频大小: ${audioData.length} 字节, 耗时: ${elapsed}ms');

      if (audioData.isEmpty) {
        throw Exception('AIHUBMIX-TTS返回了空的音频数据');
      }

      return audioData;
    } on DioException catch (e) {
      final errorMsg = _parseDioError(e);
      debugPrint('AIHUBMIXTTSProvider: API请求失败 - $errorMsg');
      throw Exception('AIHUBMIX-TTS合成失败: $errorMsg');
    } catch (e) {
      debugPrint('AIHUBMIXTTSProvider: 合成异常: $e');
      rethrow;
    }
  }

  @override
  Stream<Uint8List> streamSynthesize(
    String text, {
    Map<String, dynamic>? params,
  }) async* {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('AIHUBMIX API密钥未配置');
    }

    final validatedParams = validateParams(params ?? {});
    final requestedFormat =
        (validatedParams['response_format'] as String?)?.toLowerCase() ?? 'mp3';

    if (requestedFormat != 'pcm') {
      debugPrint(
          'AIHUBMIXTTSProvider: 流式合成不支持直接输出"$requestedFormat"格式，已强制使用"pcm"格式');
    }

    final sampleRate =
        (validatedParams['sample_rate'] as num?)?.toInt() ?? 24000;
    final convertToTarget = requestedFormat != 'pcm';

    debugPrint('AIHUBMIXTTSProvider: 开始流式合成 - 文本长度: ${text.length} 字符');

    try {
      final response = await _dio.post(
        _baseUrl,
        options: Options(
          responseType: ResponseType.stream,
        ),
        data: {
          'model': validatedParams['model'],
          'input': text,
          'voice': validatedParams['voice'],
          'speed': validatedParams['speed'],
          'response_format': 'pcm',
          'stream': true,
          if (validatedParams.containsKey('instructions') &&
              (validatedParams['instructions'] as String).isNotEmpty)
            'instructions': validatedParams['instructions'],
        },
      );

      final stream = response.data.stream as Stream<Uint8List>;

      // 跟踪流处理
      var chunkCount = 0;
      var totalSize = 0;
      final pcmChunks = <Uint8List>[];
      final streamStartTime = DateTime.now();

      await for (final chunk in stream) {
        if (chunk.isEmpty) continue;

        chunkCount++;
        totalSize += chunk.length;

        // 检查数据块对齐
        var alignedChunk = chunk;
        if (chunk.length % 2 != 0) {
          debugPrint('AIHUBMIXTTSProvider: 数据块 #$chunkCount 对齐修复');
          alignedChunk = Uint8List.fromList([...chunk, 0x00]);
        }

        if (convertToTarget) {
          pcmChunks.add(alignedChunk);
        }

        yield alignedChunk;

        if (chunkCount % 5 == 0) {
          final elapsed =
              DateTime.now().difference(streamStartTime).inMilliseconds;
          final throughput = elapsed > 0 ? (totalSize / elapsed * 1000) : 0.0;
          debugPrint(
              'AIHUBMIXTTSProvider: 流式进度 - 数据块: $chunkCount, 总大小: $totalSize 字节, '
              '耗时: ${elapsed}ms, 吞吐量: ${throughput.toStringAsFixed(1)} B/s');
        }
      }

      if (convertToTarget && pcmChunks.isNotEmpty) {
        try {
          final pcmData =
              Uint8List(pcmChunks.fold<int>(0, (sum, c) => sum + c.length));
          var offset = 0;
          for (final chunk in pcmChunks) {
            pcmData.setRange(offset, offset + chunk.length, chunk);
            offset += chunk.length;
          }

          Uint8List convertedData;
          if (requestedFormat == 'wav') {
            convertedData = pcmToWav(pcmData, sampleRate: sampleRate);
          } else {
            convertedData = pcmData;
          }

          yield convertedData;
        } catch (e) {
          debugPrint('AIHUBMIXTTSProvider: 格式转换失败: $e');
          for (final chunk in pcmChunks) {
            yield chunk;
          }
        }
      }

      final totalTime =
          DateTime.now().difference(streamStartTime).inMilliseconds;
      debugPrint(
          'AIHUBMIXTTSProvider: 流式合成完成 - 数据块: $chunkCount, 总大小: $totalSize 字节, '
          '总耗时: ${totalTime}ms');
    } on DioException catch (e) {
      final errorMsg = _parseDioError(e);
      debugPrint('AIHUBMIXTTSProvider: 流式合成失败 - $errorMsg');
      throw Exception('AIHUBMIX-TTS流式合成失败: $errorMsg');
    } catch (e) {
      debugPrint('AIHUBMIXTTSProvider: 流式合成异常: $e');
      rethrow;
    }
  }

  /// 解析Dio错误为可读消息
  String _parseDioError(DioException e) {
    final String origMsg = e.message ?? '';
    final String extra = origMsg.isNotEmpty ? '\n原始错误: $origMsg' : '';
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络$extra';
      case DioExceptionType.receiveTimeout:
        return '接收超时，服务器响应过慢$extra';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final body = e.response?.data;
        // 尝试将字节数组解码为字符串
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
          return 'API密钥无效或权限不足 (HTTP $statusCode): $bodyStr$extra';
        } else if (statusCode == 429) {
          return '请求过于频繁，请稍后重试 (HTTP $statusCode)$extra';
        } else if (statusCode == 500) {
          return '服务器内部错误 (HTTP $statusCode): $bodyStr$extra';
        } else if (statusCode == 404) {
          return 'API端点不存在 (HTTP 404): $bodyStr\n请检查API基础URL设置是否正确$extra';
        }
        return '服务器返回错误 (HTTP $statusCode): $bodyStr$extra';
      case DioExceptionType.cancel:
        return '请求已取消$extra';
      default:
        if (e.type == DioExceptionType.connectionError && kIsWeb) {
          return '无法连接到服务器。Web端常见原因：CORS跨域限制或API地址不正确。请检查：1) 供应商配置中的API地址是否正确 2) 服务器是否允许跨域请求$extra';
        }
        return '网络错误: ${e.message}';
    }
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
    final String origMsg = e.message ?? '';
    final String extra = origMsg.isNotEmpty ? '\n原始错误: $origMsg' : '';
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络$extra';
      case DioExceptionType.receiveTimeout:
        return '接收超时，服务器响应过慢$extra';
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
          return 'API密钥无效或权限不足 (HTTP $statusCode): $bodyStr$extra';
        if (statusCode == 429) return '请求过于频繁，请稍后重试 (HTTP $statusCode)$extra';
        if (statusCode == 404)
          return 'API端点不存在 (HTTP 404): $bodyStr\n请检查API基础URL设置是否正确$extra';
        if (statusCode == 500)
          return '服务器内部错误 (HTTP $statusCode): $bodyStr$extra';
        return '服务器返回错误 (HTTP $statusCode): $bodyStr$extra';
      case DioExceptionType.cancel:
        return '请求已取消$extra';
      default:
        if (e.type == DioExceptionType.connectionError && kIsWeb) {
          return '无法连接到服务器。Web端常见原因：CORS跨域限制或API地址不正确。请检查：1) 供应商配置中的API地址是否正确 2) 服务器是否允许跨域请求$extra';
        }
        return '网络错误: ${e.message}';
    }
  }
}

/// 工厂函数：根据供应商名称创建TTSProvider实例
BaseTTSProvider getTTSProvider({
  required String providerName,
  String? apiKey,
  Map<String, dynamic>? options,
}) {
  switch (providerName) {
    case 'glm_tts':
      return GLMTTSProvider(
        apiKey: apiKey,
        baseUrl: options?['base_url'] as String?,
      );
    case 'aihubmix_tts':
      return AIHUBMIXTTSProvider(
        apiKey: apiKey,
        baseUrl: options?['base_url'] as String?,
        model: options?['model'] as String?,
      );
    default:
      // 自定义供应商：从 options 中获取定义
      final baseUrl = options?['base_url'] as String?;
      if (baseUrl == null || baseUrl.isEmpty) {
        throw ArgumentError('不支持的供应商: $providerName');
      }
      return CustomTTSProvider(
        baseUrl: baseUrl,
        apiKey: apiKey ?? '',
        name: providerName,
      );
  }
}

/// 带缓存的工厂函数：减少重复初始化开销
BaseTTSProvider getCachedTTSProvider({
  required String providerName,
  String? apiKey,
  Map<String, dynamic>? options,
}) {
  // TODO: 实现实例缓存
  return getTTSProvider(
    providerName: providerName,
    apiKey: apiKey,
    options: options,
  );
}
