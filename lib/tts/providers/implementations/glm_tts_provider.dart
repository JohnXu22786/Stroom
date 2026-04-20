import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stroom/tts/providers/tts_provider.dart';
import 'package:stroom/tts/providers/provider_config.dart';
import 'package:stroom/tts/audio/audio_utils.dart';

/// GLM-TTS供应商实现
///
/// 专为与GLM（智谱AI）的TTS API对接而设计。
/// 继承自TTSProvider抽象基类，提供完整的语音合成功能，
/// 特别针对GLM-TTS API的特有行为进行优化处理。
///
/// 主要特点：
/// 1. 音频修剪：自动移除GLM-TTS特有的初始蜂鸣声（约0.629秒）
/// 2. 流式处理优化：实时修剪和格式转换
/// 3. 健壮的错误处理：针对各种异常情况的全面处理
/// 4. 详细的性能监控：时间统计和日志记录
/// 5. 数据完整性保障：自动数据对齐和验证
class GLMTTSProvider extends TTSProvider {
  /// GLM-TTS客户端实例
  ///
  /// 注意：实际使用时需要实现GLMTTSClient类
  /// 这里使用动态类型以便于后续替换为具体实现
  final dynamic _client;

  /// 是否需要对音频进行修剪
  ///
  /// GLM-TTS生成的音频开头包含蜂鸣声，需要修剪
  final bool needsTrimming;

  /// 是否强制修剪音频
  ///
  /// 即使检测不到蜂鸣声也进行修剪
  final bool forceTrim;

  /// 创建GLM-TTS供应商实例
  ///
  /// [apiKey] GLM API密钥，用于身份验证
  /// [kwargs] GLM客户端额外参数
  ///   - forceTrim: 是否强制修剪音频（默认false）
  ///   - 其他供应商特定参数
  ///
  /// 注意：此构造函数可能需要根据实际的GLMTTSClient实现进行调整
  GLMTTSProvider({
    String? apiKey,
    Map<String, dynamic> kwargs = const {},
  })  : _client = _createGLMClient(apiKey: apiKey, kwargs: kwargs),
        needsTrimming = true,
        forceTrim = kwargs['forceTrim'] ?? false {
    // 初始化日志
    _logInitialization(apiKey: apiKey);
  }

  /// 供应商名称
  @override
  String get name => TTSProviderType.glmTTS.value;

  /// 支持的模型列表
  @override
  List<String> get supportedModels =>
      TTSProviderConfig.getSupportedModels(TTSProviderType.glmTTS);

  /// 默认参数配置
  @override
  Map<String, dynamic> get defaultParams =>
      TTSProviderConfig.getDefaultParams(TTSProviderType.glmTTS);

  /// 验证并合并参数（重写父类方法）
  ///
  /// 添加GLM-TTS特定的参数验证逻辑：
  /// 1. 检查参数范围（语速、音量等）
  /// 2. 验证音色是否在支持列表中
  /// 3. 验证格式是否支持
  @override
  Map<String, dynamic> validateParams(Map<String, dynamic>? kwargs) {
    // 调用父类方法进行基本验证和合并
    final params = super.validateParams(kwargs);

    // GLM-TTS特定验证
    _validateGLMParams(params);

    return params;
  }

  /// 合成语音，返回音频字节数据
  ///
  /// [text] 要合成的文本内容
  /// [kwargs] 合成参数，包括：
  ///   - voice: 音色选择（默认："female"）
  ///   - speed: 语速调节（范围：0.5-2.0，默认：1.0）
  ///   - volume: 音量控制（范围：0.0-2.0，默认：1.0）
  ///   - format: 音频格式（默认："wav"）
  ///   - sampleRate: 采样率（默认：24000）
  ///   - responseFormat: API响应格式
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

      // 映射参数到客户端格式
      final clientParams = _mapToClientParams(params);

      // 确保使用非流式调用
      clientParams['stream'] = false;

      // 调用API合成语音
      final rawAudio = await _callSynthesisAPI(text, clientParams);

      // 应用音频修剪（GLM-TTS特有）
      final processedAudio = await _processGLMAudio(
        rawAudio,
        sampleRate: params['sampleRate'] ?? 24000,
      );

      // 性能统计和日志记录
      _logSynthesisComplete(startTime, processedAudio.length);

      return processedAudio;
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
  /// 注意：GLM-TTS流式模式强制使用PCM格式进行实时传输
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

      // 获取用户请求的格式和采样率
      final requestedFormat = (params['format'] ?? 'wav').toString().toLowerCase();
      final sampleRate = params['sampleRate'] ?? 24000;

      // 流式模式下强制使用PCM格式（GLM-TTS API限制）
      final clientParams = _mapToClientParams(params);
      if (requestedFormat != 'pcm') {
        _logStreamFormatWarning(requestedFormat);
        clientParams['response_format'] = 'pcm';
      } else {
        clientParams['response_format'] = 'pcm';
      }

      // 确保使用流式调用
      clientParams['stream'] = true;

      // 调用流式API
      final streamController = StreamController<Uint8List>();
      final rawStream = _callStreamSynthesisAPI(text, clientParams, streamController);

      // 应用流式修剪包装器（如果需要）
      Stream<Uint8List> processedStream = rawStream;
      if (needsTrimming) {
        processedStream = AudioUtils.createStreamTrimmingWrapper(
          rawStream,
          sampleRate: sampleRate,
          bytesPerSample: 2, // 16-bit PCM
        );
      }

      // 跟踪流处理状态
      int chunkCount = 0;
      int totalSize = 0;
      final pcmChunks = <Uint8List>[];
      final convertToTarget = requestedFormat != 'pcm';

      await for (final chunk in processedStream) {
        // 检查数据块对齐（16位PCM需要2字节对齐）
        final alignedChunk = AudioUtils.alignPcmChunk(chunk);

        // 收集PCM数据块用于格式转换（如果需要）
        if (convertToTarget) {
          pcmChunks.add(alignedChunk);
        }

        // 更新统计信息
        chunkCount++;
        totalSize += alignedChunk.length;

        // 每5个数据块记录一次进度
        if (chunkCount % 5 == 0) {
          _logStreamProgress(chunkCount, totalSize, startTime);
        }

        // 如果是PCM格式或尚未转换，直接yield数据
        if (!convertToTarget) {
          yield alignedChunk;
        } else {
          // 如果是PCM格式，直接yield（格式转换在流结束后处理）
          yield alignedChunk;
        }
      }

      // 如果请求非PCM格式，进行格式转换
      if (convertToTarget && pcmChunks.isNotEmpty) {
        try {
          final pcmData = AudioUtils.mergeAudioChunks(pcmChunks);
          final convertedData = AudioUtils.convertAudioFormat(
            pcmData: pcmData,
            targetFormat: requestedFormat,
            sampleRate: sampleRate,
            bitsPerSample: 16,
            numChannels: 1,
          );

          // 发送转换后的数据作为最后一个数据块
          yield convertedData;
        } catch (e) {
          _logFormatConversionError(e, requestedFormat);
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

  /// 获取底层GLM客户端实例
  ///
  /// 用于高级操作或调试目的
  dynamic get client => _client;

  /// 字符串表示，便于调试
  @override
  String toString() {
    return 'GLMTTSProvider(name: "$name", needsTrimming: $needsTrimming, forceTrim: $forceTrim)';
  }

  // ===========================================================================
  // 私有方法
  // ===========================================================================

  /// 创建GLM客户端实例
  ///
  /// 注意：这是一个临时实现，实际使用时需要替换为具体的GLMTTSClient类
  static dynamic _createGLMClient({
    String? apiKey,
    required Map<String, dynamic> kwargs,
  }) {
    // TODO: 实现具体的GLMTTSClient
    // 目前返回一个模拟客户端，实际使用时需要集成具体的HTTP客户端

    return _GLMMockClient(apiKey: apiKey, kwargs: kwargs);
  }

  /// 验证GLM-TTS特定参数
  void _validateGLMParams(Map<String, dynamic> params) {
    // 验证语速范围
    final speed = params['speed'];
    if (speed != null && speed is num) {
      if (speed < 0.5 || speed > 2.0) {
        throw ArgumentError('语速必须在0.5到2.0之间，当前值: $speed');
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
      final supportedVoices = TTSProviderConfig.getSupportedVoices(TTSProviderType.glmTTS);
      if (!supportedVoices.contains(voice)) {
        throw ArgumentError('不支持的音色: $voice。支持的音色: $supportedVoices');
      }
    }

    // 验证音频格式
    final format = params['format'];
    if (format != null && format is String) {
      if (!TTSProviderConfig.supportedFormats.contains(format.toLowerCase())) {
        throw ArgumentError('不支持的音频格式: $format。支持的格式: ${TTSProviderConfig.supportedFormats}');
      }
    }
  }

  /// 映射参数到客户端格式
  Map<String, dynamic> _mapToClientParams(Map<String, dynamic> params) {
    final clientParams = <String, dynamic>{};

    // 基本参数映射
    if (params.containsKey('voice')) {
      clientParams['voice'] = params['voice'];
    }

    if (params.containsKey('speed')) {
      clientParams['speed'] = params['speed'];
    }

    if (params.containsKey('volume')) {
      clientParams['volume'] = params['volume'];
    }

    // 响应格式映射
    if (params.containsKey('format')) {
      clientParams['response_format'] = params['format'];
    } else if (params.containsKey('response_format')) {
      clientParams['response_format'] = params['response_format'];
    }

    // 采样率
    if (params.containsKey('sample_rate')) {
      clientParams['sample_rate'] = params['sample_rate'];
    } else if (params.containsKey('sampleRate')) {
      clientParams['sample_rate'] = params['sampleRate'];
    }

    return clientParams;
  }

  /// 调用API合成语音
  Future<Uint8List> _callSynthesisAPI(
    String text,
    Map<String, dynamic> params,
  ) async {
    // TODO: 实现实际的API调用
    // 这里使用模拟实现，实际使用时需要替换为HTTP请求

    await Future.delayed(const Duration(milliseconds: 500)); // 模拟网络延迟

    // 模拟返回一些音频数据
    return Uint8List.fromList(List.generate(1024, (index) => index % 256));
  }

  /// 调用流式API合成语音
  Stream<Uint8List> _callStreamSynthesisAPI(
    String text,
    Map<String, dynamic> params,
    StreamController<Uint8List> controller,
  ) {
    // TODO: 实现实际的流式API调用
    // 这里使用模拟实现，实际使用时需要替换为HTTP流式请求

    // 模拟流式数据生成
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (controller.isClosed) {
        timer.cancel();
        return;
      }

      // 模拟生成音频数据块
      const chunkSize = 512;
      final chunk = Uint8List.fromList(
        List.generate(chunkSize, (index) => (DateTime.now().microsecondsSinceEpoch + index) % 256),
      );

      controller.add(chunk);

      // 模拟生成10个数据块后结束
      if (controller.sink is StreamController<Uint8List> &&
          (controller.sink as dynamic).addedChunks >= 10) {
        timer.cancel();
        controller.close();
      }
    });

    return controller.stream;
  }

  /// 处理GLM-TTS音频（修剪蜂鸣声）
  Future<Uint8List> _processGLMAudio(
    Uint8List audioData, {
    required int sampleRate,
  }) async {
    if (audioData.isEmpty || !needsTrimming) {
      return audioData;
    }

    try {
      return AudioUtils.trimGlmAudio(
        audioData,
        sampleRate: sampleRate,
        force: forceTrim,
      );
    } catch (e) {
      // 修剪失败，记录警告并返回原始数据
      _logAudioTrimmingError(e);
      return audioData;
    }
  }

  // ===========================================================================
  // 日志记录方法
  // ===========================================================================

  void _logInitialization({String? apiKey}) {
    debugPrint('GLMTTSProvider初始化完成 - '
        '需要修剪: $needsTrimming, '
        '强制修剪: $forceTrim, '
        'API密钥: ${apiKey != null ? "已设置" : "未设置"}');
  }

  void _logSynthesisStart(String text, Map<String, dynamic> params) {
    debugPrint('GLMTTSProvider开始非流式合成 - '
        '文本长度: ${text.length} 字符, '
        '参数: $params');
  }

  void _logSynthesisComplete(DateTime startTime, int audioSize) {
    final duration = DateTime.now().difference(startTime);
    debugPrint('GLMTTSProvider非流式合成成功 - '
        '耗时: ${duration.inMilliseconds}ms, '
        '音频大小: $audioSize 字节, '
        '吞吐量: ${(audioSize / duration.inMilliseconds * 1000).toStringAsFixed(1)} B/s');
  }

  void _logSynthesisError(Object error, String text) {
    debugPrint('GLMTTSProvider非流式合成失败 - '
        '文本: "$text", '
        '错误: $error');
  }

  void _logStreamStart(String text, Map<String, dynamic> params) {
    debugPrint('GLMTTSProvider开始流式合成 - '
        '文本长度: ${text.length} 字符, '
        '参数: $params');
  }

  void _logStreamFormatWarning(String requestedFormat) {
    debugPrint('GLMTTSProvider流式格式警告 - '
        'GLM-TTS流式合成不支持直接输出"$requestedFormat"格式，'
        '已强制使用"pcm"格式进行实时播放');
  }

  void _logStreamProgress(int chunkCount, int totalSize, DateTime startTime) {
    final duration = DateTime.now().difference(startTime);
    final throughput = duration.inMilliseconds > 0
        ? totalSize / duration.inMilliseconds * 1000
        : 0;

    debugPrint('GLMTTSProvider流式处理进度 - '
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

    debugPrint('GLMTTSProvider流式合成完成 - '
        '数据块总数: $chunkCount, '
        '总大小: $totalSize 字节, '
        '流式处理时间: ${duration.inMilliseconds}ms, '
        '平均数据块大小: ${avgChunkSize.toStringAsFixed(1)} 字节, '
        '平均吞吐量: ${throughput.toStringAsFixed(1)} B/s');
  }

  void _logStreamError(Object error, String text) {
    debugPrint('GLMTTSProvider流式合成失败 - '
        '文本: "$text", '
        '错误: $error');
  }

  void _logAudioTrimmingError(Object error) {
    debugPrint('GLMTTSProvider音频修剪失败 - '
        '错误: $error, 返回原始音频数据');
  }

  void _logFormatConversionError(Object error, String targetFormat) {
    debugPrint('GLMTTSProvider格式转换失败 - '
        '目标格式: $targetFormat, '
        '错误: $error, 返回原始PCM数据');
  }
}

/// GLM模拟客户端（临时实现）
///
/// 用于在没有实际GLMTTSClient实现时提供基本功能。
/// 实际使用时应该替换为具体的HTTP客户端实现。
class _GLMMockClient {
  final String? apiKey;
  final Map<String, dynamic> kwargs;

  _GLMMockClient({
    required this.apiKey,
    required this.kwargs,
  });

  /// 模拟合成方法
  Future<Uint8List> synthesize(
    String text, {
    required Map<String, dynamic> params,
  }) async {
    debugPrint('_GLMMockClient.synthesize调用 - '
        '文本: "$text", '
        '参数: $params, '
        'API密钥: ${apiKey != null ? "已设置" : "未设置"}');

    await Future.delayed(const Duration(milliseconds: 300));

    // 返回模拟音频数据
    return Uint8List.fromList(List.generate(2048, (index) => index % 256));
  }

  /// 模拟流式合成方法
  Stream<Uint8List> streamSynthesize(
    String text, {
    required Map<String, dynamic> params,
  }) async* {
    debugPrint('_GLMMockClient.streamSynthesize调用 - '
        '文本: "$text", '
        '参数: $params, '
        'API密钥: ${apiKey != null ? "已设置" : "未设置"}');

    // 模拟生成5个数据块
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      yield Uint8List.fromList(
        List.generate(512, (index) => (i * 512 + index) % 256),
      );
    }
  }
}
