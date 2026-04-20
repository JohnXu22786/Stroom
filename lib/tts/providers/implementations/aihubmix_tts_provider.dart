import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stroom/tts/providers/tts_provider.dart';
import 'package:stroom/tts/providers/provider_config.dart';
import 'package:stroom/tts/audio/audio_utils.dart';

/// AIHUBMIX-TTS供应商实现
///
/// 专为与AIHUBMIX的OpenAI兼容TTS API对接而设计。
/// 继承自TTSProvider抽象基类，提供完整的语音合成功能，
/// 利用OpenAI兼容API的标准化接口。
///
/// 主要特点：
/// 1. OpenAI兼容API：使用标准化的OpenAI API接口
/// 2. 多模型支持：支持tts-1和tts-1-hd等多种模型
/// 3. 配置灵活性：支持自定义基础URL和API端点
/// 4. 无音频修剪需求：AIHUBMIX-TTS不产生初始蜂鸣声
/// 5. 开发便利性：使用成熟的OpenAI客户端库
class AIHUBMIXTTSProvider extends TTSProvider {
  /// OpenAI兼容客户端实例
  ///
  /// 注意：实际使用时需要集成OpenAI Dart客户端库
  /// 这里使用动态类型以便于后续替换为具体实现
  final dynamic _client;

  /// 基础API URL
  final String? _baseUrl;

  /// 默认模型名称
  final String _defaultModel;

  /// 创建AIHUBMIX-TTS供应商实例
  ///
  /// [apiKey] AIHUBMIX API密钥，用于身份验证
  /// [kwargs] 客户端额外参数：
  ///   - baseUrl: 自定义API基础URL（可选）
  ///   - model: 默认模型名称（默认："tts-1"）
  ///   - 其他OpenAI客户端参数
  ///
  /// 注意：如果未提供apiKey，将尝试使用配置中的默认密钥
  AIHUBMIXTTSProvider({
    String? apiKey,
    Map<String, dynamic> kwargs = const {},
  })  : _baseUrl = kwargs['baseUrl'],
        _defaultModel = kwargs['model'] ?? 'tts-1',
        _client = _createOpenAIClient(
          apiKey: apiKey,
          baseUrl: kwargs['baseUrl'],
          kwargs: kwargs,
        ) {
    // 初始化日志
    _logInitialization(apiKey: apiKey, baseUrl: _baseUrl, model: _defaultModel);
  }

  /// 供应商名称
  @override
  String get name => TTSProviderType.aihubmixTTS.value;

  /// 支持的模型列表
  @override
  List<String> get supportedModels =>
      TTSProviderConfig.getSupportedModels(TTSProviderType.aihubmixTTS);

  /// 默认参数配置
  @override
  Map<String, dynamic> get defaultParams {
    final params = TTSProviderConfig.getDefaultParams(TTSProviderType.aihubmixTTS);

    // 添加实例特定的默认参数
    return Map<String, dynamic>.from(params)
      ..['model'] = _defaultModel
      ..addAll(_baseUrl != null ? {'base_url': _baseUrl} : {});
  }

  /// 验证并合并参数（重写父类方法）
  ///
  /// 添加AIHUBMIX-TTS特定的参数验证逻辑：
  /// 1. 检查参数范围（语速、音量等）
  /// 2. 验证音色是否在支持列表中
  /// 3. 验证模型是否支持
  /// 4. 验证格式是否支持
  @override
  Map<String, dynamic> validateParams(Map<String, dynamic>? kwargs) {
    // 调用父类方法进行基本验证和合并
    final params = super.validateParams(kwargs);

    // AIHUBMIX-TTS特定验证
    _validateAIHUBMIXParams(params);

    return params;
  }

  /// 合成语音，返回音频字节数据
  ///
  /// [text] 要合成的文本内容
  /// [kwargs] 合成参数，包括：
  ///   - voice: 音色选择（默认："alloy"）
  ///   - speed: 语速调节（范围：0.25-4.0，默认：1.0）
  ///   - volume: 音量控制（范围：0.0-2.0，默认：1.0）
  ///   - format: 音频格式（默认："mp3"）
  ///   - model: 模型选择（"tts-1"或"tts-1-hd"，默认："tts-1"）
  ///   - response_format: API响应格式
  ///
  /// 返回包含完整音频数据的Future
  @override
  Future<Uint8List> synthesize(
    String text, [
    Map<String, dynamic>? kwargs,
  ]) async {
    // 记录开始时间用于性能统计
    final startTime = DateTime.now();

    try {
      // 参数验证和合并
      final params = validateParams(kwargs);

      // 日志记录
      _logSynthesisStart(text, params);

      // 映射参数到OpenAI API格式
      final apiParams = _mapToOpenAIParams(params);

      // 调用OpenAI兼容API合成语音
      final audioData = await _callOpenAISynthesisAPI(text, apiParams);

      // AIHUBMIX-TTS不需要音频修剪
      // 直接使用原始音频数据

      // 性能统计和日志记录
      _logSynthesisComplete(startTime, audioData.length);

      return audioData;
    } catch (e) {
      // 错误处理
      _logSynthesisError(e, text);
      rethrow;
    }
  }

  /// 流式合成语音，返回音频数据流
  ///
  /// [text] 要合成的文本内容
  /// [kwargs] 合成参数，与非流式方法相同
  ///
  /// 返回音频数据块的Stream，支持实时播放
  /// 注意：OpenAI API流式模式支持多种格式
  @override
  Stream<Uint8List> streamSynthesize(
    String text, [
    Map<String, dynamic>? kwargs,
  ]) async* {
    final startTime = DateTime.now();

    try {
      // 参数验证和合并
      final params = validateParams(kwargs);

      // 日志记录
      _logStreamStart(text, params);

      // 映射参数到OpenAI API格式
      final apiParams = _mapToOpenAIParams(params);

      // 设置流式模式
      apiParams['stream'] = true;

      // 检查多个可能的格式参数名
      final requestedFormat = _getRequestedFormat(params);

      // OpenAI API流式模式支持直接输出多种格式
      // 不需要像GLM-TTS那样强制使用PCM格式
      if (requestedFormat != null) {
        apiParams['response_format'] = requestedFormat;
      }

      // 调用OpenAI流式API
      final rawStream = _callOpenAIStreamAPI(text, apiParams);

      // 跟踪流处理状态
      int chunkCount = 0;
      int totalSize = 0;
      final pcmChunks = <Uint8List>[];
      final isPcmFormat = requestedFormat?.toLowerCase() == 'pcm';

      await for (final chunk in rawStream) {
        // OpenAI API返回的数据块通常已经对齐
        // 但对于PCM格式，仍然检查对齐
        final processedChunk = isPcmFormat
            ? AudioUtils.alignPcmChunk(chunk)
            : chunk;

        // 更新统计信息
        chunkCount++;
        totalSize += processedChunk.length;

        // 收集PCM数据块用于格式转换（如果需要）
        if (isPcmFormat && requestedFormat != 'pcm') {
          pcmChunks.add(processedChunk);
        }

        // 每5个数据块记录一次进度
        if (chunkCount % 5 == 0) {
          _logStreamProgress(chunkCount, totalSize, startTime);
        }

        // Yield处理后的数据块
        yield processedChunk;
      }

      // 如果请求PCM格式但需要转换为其他格式
      if (isPcmFormat && requestedFormat != 'pcm' && pcmChunks.isNotEmpty) {
        try {
          final pcmData = AudioUtils.mergeAudioChunks(pcmChunks);
          final convertedData = AudioUtils.convertAudioFormat(
            pcmData: pcmData,
            targetFormat: requestedFormat ?? 'wav',
            sampleRate: params['sample_rate'] ?? params['sampleRate'] ?? 24000,
            bitsPerSample: 16,
            numChannels: 1,
          );

          // 发送转换后的数据作为最后一个数据块
          yield convertedData;
        } catch (e) {
          _logFormatConversionError(e, requestedFormat ?? 'unknown');
          // 转换失败，返回原始PCM数据块
          for (final chunk in pcmChunks) {
            yield chunk;
          }
        }
      }

      // 流处理完成日志
      _logStreamComplete(chunkCount, totalSize, startTime);

    } catch (e) {
      _logStreamError(e, text);
      rethrow;
    }
  }

  /// 获取底层OpenAI客户端实例
  ///
  /// 用于高级操作或调试目的
  dynamic get client => _client;

  /// 获取基础API URL
  String? get baseUrl => _baseUrl;

  /// 字符串表示，便于调试
  @override
  String toString() {
    return 'AIHUBMIXTTSProvider(name: "$name", model: "$_defaultModel", baseUrl: ${_baseUrl ?? "default"})';
  }

  // ===========================================================================
  // 私有方法
  // ===========================================================================

  /// 创建OpenAI兼容客户端实例
  ///
  /// 注意：这是一个临时实现，实际使用时需要集成OpenAI Dart客户端库
  static dynamic _createOpenAIClient({
    String? apiKey,
    String? baseUrl,
    required Map<String, dynamic> kwargs,
  }) {
    // TODO: 实现具体的OpenAI客户端
    // 目前返回一个模拟客户端，实际使用时需要集成openai_dart_api等库

    // 使用配置中的默认API密钥（如果未提供）
    final effectiveApiKey = apiKey ?? _getDefaultAPIKey();

    return _OpenAIMockClient(
      apiKey: effectiveApiKey,
      baseUrl: baseUrl,
      kwargs: kwargs,
    );
  }

  /// 获取默认API密钥
  static String? _getDefaultAPIKey() {
    // TODO: 从配置或环境变量获取默认API密钥
    // 实际使用时应该从安全的配置源获取
    return null;
  }

  /// 验证AIHUBMIX-TTS特定参数
  void _validateAIHUBMIXParams(Map<String, dynamic> params) {
    // 验证语速范围
    final speed = params['speed'];
    if (speed != null && speed is num) {
      if (speed < 0.25 || speed > 4.0) {
        throw ArgumentError('语速必须在0.25到4.0之间，当前值: $speed');
      }
    }

    // 验证音量范围
    final volume = params['volume'];
    if (volume != null && volume is num) {
      if (volume < 0.0 || volume > 2.0) {
        throw ArgumentError('音量必须在0.0到2.0之间，当前值: $volume');
      }
    }

    // 验证音色是否在支持列表中
    final voice = params['voice'];
    if (voice != null && voice is String) {
      final supportedVoices = TTSProviderConfig.getSupportedVoices(TTSProviderType.aihubmixTTS);
      if (!supportedVoices.contains(voice)) {
        throw ArgumentError('不支持的音色: $voice。支持的音色: $supportedVoices');
      }
    }

    // 验证模型是否支持
    final model = params['model'];
    if (model != null && model is String) {
      if (!supportedModels.contains(model)) {
        throw ArgumentError('不支持的模型: $model。支持的模型: $supportedModels');
      }
    }

    // 验证音频格式
    final format = _getRequestedFormat(params);
    if (format != null) {
      if (!TTSProviderConfig.supportedFormats.contains(format.toLowerCase())) {
        throw ArgumentError('不支持的音频格式: $format。支持的格式: ${TTSProviderConfig.supportedFormats}');
      }
    }
  }

  /// 获取请求的格式
  String? _getRequestedFormat(Map<String, dynamic> params) {
    // 检查多个可能的格式参数名（OpenAI API使用不同的参数名）
    final formatKeys = ['response_format', 'format', 'stream_format'];

    for (final key in formatKeys) {
      if (params.containsKey(key) && params[key] is String) {
        return params[key] as String;
      }
    }

    return null;
  }

  /// 映射参数到OpenAI API格式
  Map<String, dynamic> _mapToOpenAIParams(Map<String, dynamic> params) {
    final apiParams = <String, dynamic>{};

    // 基本参数映射
    if (params.containsKey('model')) {
      apiParams['model'] = params['model'];
    }

    if (params.containsKey('voice')) {
      apiParams['voice'] = params['voice'];
    }

    // OpenAI API使用不同的参数名
    if (params.containsKey('speed')) {
      apiParams['speed'] = params['speed'];
    }

    // 响应格式映射
    final format = _getRequestedFormat(params);
    if (format != null) {
      apiParams['response_format'] = format;
    }

    return apiParams;
  }

  /// 调用OpenAI API合成语音
  Future<Uint8List> _callOpenAISynthesisAPI(
    String text,
    Map<String, dynamic> params,
  ) async {
    // TODO: 实现实际的OpenAI API调用
    // 这里使用模拟实现，实际使用时需要替换为HTTP请求

    debugPrint('_callOpenAISynthesisAPI模拟调用 - '
        '文本: "$text", '
        '参数: $params, '
        '基础URL: ${_baseUrl ?? "默认"}');

    await Future.delayed(const Duration(milliseconds: 400)); // 模拟网络延迟

    // 模拟返回MP3格式的音频数据
    // 实际实现应该调用OpenAI的audio.speech.create端点
    return Uint8List.fromList(List.generate(2048, (index) => index % 256));
  }

  /// 调用OpenAI流式API合成语音
  Stream<Uint8List> _callOpenAIStreamAPI(
    String text,
    Map<String, dynamic> params,
  ) async* {
    // TODO: 实现实际的OpenAI流式API调用
    // 这里使用模拟实现，实际使用时需要替换为HTTP流式请求

    debugPrint('_callOpenAIStreamAPI模拟调用 - '
        '文本: "$text", '
        '参数: $params, '
        '基础URL: ${_baseUrl ?? "默认"}');

    // 模拟流式数据生成
    for (int i = 0; i < 8; i++) {
      await Future.delayed(const Duration(milliseconds: 60));

      // 根据请求的格式生成不同大小的数据块
      final format = params['response_format']?.toString().toLowerCase() ?? 'mp3';
      final chunkSize = format == 'pcm' ? 512 : 1024;

      yield Uint8List.fromList(
        List.generate(chunkSize, (index) => (i * chunkSize + index) % 256),
      );
    }
  }

  // ===========================================================================
  // 日志记录方法
  // ===========================================================================

  void _logInitialization({
    String? apiKey,
    String? baseUrl,
    required String model,
  }) {
    debugPrint('AIHUBMIXTTSProvider初始化完成 - '
        '模型: $model, '
        '基础URL: ${baseUrl ?? "默认"}, '
        'API密钥: ${apiKey != null ? "已设置" : "使用默认配置"}');
  }

  void _logSynthesisStart(String text, Map<String, dynamic> params) {
    debugPrint('AIHUBMIXTTSProvider开始非流式合成 - '
        '文本长度: ${text.length} 字符, '
        '模型: ${params['model'] ?? _defaultModel}, '
        '参数: $params');
  }

  void _logSynthesisComplete(DateTime startTime, int audioSize) {
    final duration = DateTime.now().difference(startTime);
    debugPrint('AIHUBMIXTTSProvider非流式合成成功 - '
        '耗时: ${duration.inMilliseconds}ms, '
        '音频大小: $audioSize 字节, '
        '吞吐量: ${(audioSize / duration.inMilliseconds * 1000).toStringAsFixed(1)} B/s');
  }

  void _logSynthesisError(Object error, String text) {
    debugPrint('AIHUBMIXTTSProvider非流式合成失败 - '
        '文本: "$text", '
        '错误: $error');
  }

  void _logStreamStart(String text, Map<String, dynamic> params) {
    debugPrint('AIHUBMIXTTSProvider开始流式合成 - '
        '文本长度: ${text.length} 字符, '
        '模型: ${params['model'] ?? _defaultModel}, '
        '格式: ${_getRequestedFormat(params) ?? "默认"}, '
        '参数: $params');
  }

  void _logStreamProgress(int chunkCount, int totalSize, DateTime startTime) {
    final duration = DateTime.now().difference(startTime);
    final throughput = duration.inMilliseconds > 0
        ? totalSize / duration.inMilliseconds * 1000
        : 0;

    debugPrint('AIHUBMIXTTSProvider流式处理进度 - '
        '数据块: $chunkCount, '
        '总大小: $totalSize 字节, '
        '运行时间: ${duration.inMilliseconds}ms, '
        '吞吐量: ${throughput.toStringAsFixed(1)} B/s');
  }

  void _logStreamComplete(int chunkCount, int totalSize, DateTime startTime) {
    final duration = DateTime.now().difference(startTime);
    final avgChunkSize = chunkCount > 0 ? totalSize / chunkCount : 0;
    final throughput = duration.inMilliseconds > 0
        ? totalSize / duration.inMilliseconds * 1000
        : 0;

    debugPrint('AIHUBMIXTTSProvider流式合成完成 - '
        '数据块总数: $chunkCount, '
        '总大小: $totalSize 字节, '
        '流式处理时间: ${duration.inMilliseconds}ms, '
        '平均数据块大小: ${avgChunkSize.toStringAsFixed(1)} 字节, '
        '平均吞吐量: ${throughput.toStringAsFixed(1)} B/s');
  }

  void _logStreamError(Object error, String text) {
    debugPrint('AIHUBMIXTTSProvider流式合成失败 - '
        '文本: "$text", '
        '错误: $error');
  }

  void _logFormatConversionError(Object error, String targetFormat) {
    debugPrint('AIHUBMIXTTSProvider格式转换失败 - '
        '目标格式: $targetFormat, '
        '错误: $error, 返回原始PCM数据');
  }
}

/// OpenAI模拟客户端（临时实现）
///
/// 用于在没有实际OpenAI客户端实现时提供基本功能。
/// 实际使用时应该集成openai_dart_api等库。
class _OpenAIMockClient {
  final String? apiKey;
  final String? baseUrl;
  final Map<String, dynamic> kwargs;

  _OpenAIMockClient({
    required this.apiKey,
    required this.baseUrl,
    required this.kwargs,
  });

  /// 模拟OpenAI音频合成方法
  Future<Uint8List> createSpeech({
    required String model,
    required String input,
    required String voice,
    String? responseFormat,
    double? speed,
  }) async {
    debugPrint('_OpenAIMockClient.createSpeech调用 - '
        '模型: $model, '
        '输入: "$input", '
        '音色: $voice, '
        '格式: $responseFormat, '
        '语速: $speed, '
        '基础URL: ${baseUrl ?? "默认"}, '
        'API密钥: ${apiKey != null ? "已设置" : "未设置"}');

    await Future.delayed(const Duration(milliseconds: 350));

    // 返回模拟音频数据
    return Uint8List.fromList(List.generate(3072, (index) => index % 256));
  }

  /// 模拟OpenAI流式音频合成方法
  Stream<Uint8List> createSpeechStream({
    required String model,
    required String input,
    required String voice,
    String? responseFormat,
    double? speed,
  }) async* {
    debugPrint('_OpenAIMockClient.createSpeechStream调用 - '
        '模型: $model, '
        '输入: "$input", '
        '音色: $voice, '
        '格式: $responseFormat, '
        '语速: $speed, '
        '基础URL: ${baseUrl ?? "默认"}, '
        'API密钥: ${apiKey != null ? "已设置" : "未设置"}');

    // 模拟生成6个数据块
    for (int i = 0; i < 6; i++) {
      await Future.delayed(const Duration(milliseconds: 80));

      // 根据响应格式调整数据块大小
      final chunkSize = responseFormat?.toLowerCase() == 'pcm' ? 768 : 1536;

      yield Uint8List.fromList(
        List.generate(chunkSize, (index) => (i * chunkSize + index) % 256),
      );
    }
  }
}
