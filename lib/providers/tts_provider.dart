import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// TTS供应商抽象基类
/// 采用策略模式，为不同的语音合成服务提供统一的调用接口
abstract class TTSProvider {
  /// 供应商名称
  String get name;

  /// 支持的模型列表
  List<String> get supportedModels;

  /// 合成语音，返回完整的音频数据
  /// [text] 要合成的文本
  /// [params] 合成参数（语音、速度、音量、格式等）
  Future<Uint8List> synthesize(
    String text, {
    Map<String, dynamic>? params,
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
class GLMTTSProvider extends TTSProvider {
  final String? _apiKey;
  final bool _forceTrim;
  late final dynamic _client; // 实际应为GLM客户端实例

  /// 初始化GLM TTS供应商
  /// [apiKey] GLM API密钥
  /// [forceTrim] 是否强制修剪音频（GLM特有：用于移除初始蜂鸣声）
  GLMTTSProvider({String? apiKey, bool forceTrim = false})
      : _apiKey = apiKey,
        _forceTrim = forceTrim {
    // TODO: 初始化GLM客户端
    // _client = GLMClient(apiKey: apiKey);
  }

  @override
  String get name => 'glm_tts';

  @override
  List<String> get supportedModels => ['glm-tts'];

  @override
  Map<String, dynamic> get defaultParams {
    return {
      'voice': 'female', // GLM-TTS默认音色
      'speed': 1.0, // 正常速度
      'volume': 1.0, // 正常音量
      'format': 'wav', // 默认音频格式
      'sample_rate': 24000, // 默认采样率
      'response_format': 'wav', // 响应格式
      'stream': false, // 非流式
    };
  }

  @override
  Map<String, dynamic> validateParams(Map<String, dynamic> userParams) {
    final params = Map<String, dynamic>.from(defaultParams);
    params.addAll(userParams);

    // GLM-TTS特定参数验证
    // 语速范围验证：0.5 - 2.0
    if (params.containsKey('speed')) {
      final speed = (params['speed'] as num).toDouble();
      if (speed < 0.5 || speed > 2.0) {
        throw ArgumentError('语速必须在0.5到2.0之间');
      }
    }

    // 音量范围验证：0.0 - 2.0
    if (params.containsKey('volume')) {
      final volume = (params['volume'] as num).toDouble();
      if (volume < 0.0 || volume > 2.0) {
        throw ArgumentError('音量必须在0.0到2.0之间');
      }
    }

    // 音频格式验证
    if (params.containsKey('format')) {
      final format = params['format'] as String;
      const supportedFormats = ['wav', 'mp3', 'pcm', 'flac'];
      if (!supportedFormats.contains(format.toLowerCase())) {
        throw ArgumentError('不支持的音频格式: $format');
      }
    }

    return params;
  }

  @override
  Future<Uint8List> synthesize(
    String text, {
    Map<String, dynamic>? params,
  }) async {
    // 验证参数
    final validatedParams = validateParams(params ?? {});

    // TODO: 实现GLM-TTS API调用
    // final response = await _client.synthesize(text, **validatedParams);

    // TODO: 音频修剪处理（GLM特有）
    // if (_forceTrim || needsTrimming) {
    //   response = _trimAudio(response, validatedParams['sample_rate']);
    // }

    // 模拟返回
    await Future.delayed(const Duration(milliseconds: 500));
    return Uint8List(0);
  }

  @override
  Stream<Uint8List> streamSynthesize(
    String text, {
    Map<String, dynamic>? params,
  }) async* {
    // 验证参数
    final validatedParams = validateParams(params ?? {});

    // 流式模式下强制使用pcm格式（GLM-TTS API限制）
    final requestedFormat = validatedParams['format'] as String?;
    if (requestedFormat != null && requestedFormat.toLowerCase() != 'pcm') {
      validatedParams['format'] = 'pcm';
    }

    // TODO: 实现GLM-TTS流式API调用
    // final stream = _client.streamSynthesize(text, **validatedParams);

    // TODO: 应用流式修剪（GLM特有）
    // if (_forceTrim) {
    //   stream = _wrapStreamWithTrimming(stream);
    // }

    // 模拟流式返回
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      yield Uint8List(1024); // 模拟音频数据块
    }
  }

  /// 音频修剪方法（GLM特有）
  Uint8List _trimAudio(Uint8List audioBytes, int sampleRate) {
    // TODO: 实现音频修剪逻辑
    // GLM-TTS音频开头有约0.629秒的蜂鸣声需要移除
    return audioBytes;
  }

  /// 获取底层客户端实例（用于调试或扩展）
  dynamic get client => _client;
}

/// AIHUBMIX-TTS供应商实现（OpenAI兼容API）
class AIHUBMIXTTSProvider extends TTSProvider {
  final String? _apiKey;
  final String? _baseUrl;
  final String? _model;
  late final dynamic _client; // 实际应为OpenAI兼容客户端实例

  /// 初始化AIHUBMIX TTS供应商
  /// [apiKey] AIHUBMIX API密钥
  /// [baseUrl] API基础URL（可选）
  /// [model] 模型名称（可选）
  AIHUBMIXTTSProvider({
    String? apiKey,
    String? baseUrl,
    String? model,
  })  : _apiKey = apiKey,
        _baseUrl = baseUrl,
        _model = model {
    // TODO: 初始化OpenAI兼容客户端
    // _client = OpenAIClient(apiKey: apiKey, baseUrl: baseUrl);
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
      'voice': 'alloy', // AIHUBMIX-TTS默认音色
      'model': _model ?? 'gpt-4o-mini-tts', // 默认模型
      'speed': 1.0, // 正常速度
      'volume': 1.0, // 正常音量
      'format': 'mp3', // 默认音频格式
      'sample_rate': 24000, // 默认采样率
      'response_format': 'mp3', // 响应格式
      'stream': false, // 非流式
      'base_url': _baseUrl ?? 'https://aihubmix.com/v1',
      'api_key': _apiKey,
    };
  }

  @override
  Map<String, dynamic> validateParams(Map<String, dynamic> userParams) {
    final params = Map<String, dynamic>.from(defaultParams);
    params.addAll(userParams);

    // AIHUBMIX-TTS特定参数验证
    // 语速范围验证：0.25 - 4.0
    if (params.containsKey('speed')) {
      final speed = (params['speed'] as num).toDouble();
      if (speed < 0.25 || speed > 4.0) {
        throw ArgumentError('语速必须在0.25到4.0之间');
      }
    }

    // 音量范围验证：0.0 - 2.0
    if (params.containsKey('volume')) {
      final volume = (params['volume'] as num).toDouble();
      if (volume < 0.0 || volume > 2.0) {
        throw ArgumentError('音量必须在0.0到2.0之间');
      }
    }

    // 音频格式验证
    if (params.containsKey('format')) {
      final format = params['format'] as String;
      const supportedFormats = ['mp3', 'wav', 'pcm', 'flac'];
      if (!supportedFormats.contains(format.toLowerCase())) {
        throw ArgumentError('不支持的音频格式: $format');
      }
    }

    // 模型验证
    if (params.containsKey('model')) {
      final model = params['model'] as String;
      if (!supportedModels.contains(model)) {
        throw ArgumentError('不支持的模型: $model');
      }
    }

    return params;
  }

  @override
  Future<Uint8List> synthesize(
    String text, {
    Map<String, dynamic>? params,
  }) async {
    // 验证参数
    final validatedParams = validateParams(params ?? {});

    // TODO: 实现AIHUBMIX-TTS API调用
    // final response = await _client.synthesize(text, **validatedParams);

    // AIHUBMIX-TTS不需要音频修剪

    // 模拟返回
    await Future.delayed(const Duration(milliseconds: 500));
    return Uint8List(0);
  }

  @override
  Stream<Uint8List> streamSynthesize(
    String text, {
    Map<String, dynamic>? params,
  }) async* {
    // 验证参数
    final validatedParams = validateParams(params ?? {});

    // TODO: 实现AIHUBMIX-TTS流式API调用
    // final stream = _client.streamSynthesize(text, **validatedParams);

    // 模拟流式返回
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      yield Uint8List(1024); // 模拟音频数据块
    }
  }

  /// 获取底层客户端实例（用于调试或扩展）
  dynamic get client => _client;
}

/// 工厂函数：根据供应商名称创建TTSProvider实例
TTSProvider getTTSProvider({
  required String providerName,
  String? apiKey,
  Map<String, dynamic>? options,
}) {
  switch (providerName) {
    case 'glm_tts':
      return GLMTTSProvider(
        apiKey: apiKey,
        forceTrim: options?['force_trim'] as bool? ?? false,
      );
    case 'aihubmix_tts':
      return AIHUBMIXTTSProvider(
        apiKey: apiKey,
        baseUrl: options?['base_url'] as String?,
        model: options?['model'] as String?,
      );
    default:
      throw ArgumentError('不支持的供应商: $providerName');
  }
}

/// 带缓存的工厂函数：减少重复初始化开销
TTSProvider getCachedTTSProvider({
  required String providerName,
  String? apiKey,
  Map<String, dynamic>? options,
}) {
  // 基于供应商名称和API密钥的缓存键
  final cacheKey = '${providerName}_${apiKey ?? "default"}';

  // TODO: 实现实例缓存
  // 目前直接创建新实例，实际应用中应使用缓存
  return getTTSProvider(
    providerName: providerName,
    apiKey: apiKey,
    options: options,
  );
}
