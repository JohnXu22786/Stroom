import 'dart:async';

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:stroom/tts/providers/tts_provider.dart';
import 'package:stroom/tts/providers/provider_config.dart';
import 'package:stroom/tts/providers/provider_factory.dart';
import 'package:stroom/tts/audio/audio_utils.dart';

/// TTS配置选项
class TTSConfig {
  /// 默认供应商类型
  final TTSProviderType defaultProvider;

  /// 默认API密钥（可选）
  final String? defaultApiKey;

  /// 默认音色
  final String defaultVoice;

  /// 默认语速 (0.25-4.0)
  final double defaultSpeed;

  /// 默认音量 (0.0-2.0)
  final double defaultVolume;

  /// 默认音频格式
  final String defaultFormat;

  /// 默认采样率
  final int defaultSampleRate;

  /// 是否启用流式合成（默认启用）
  final bool enableStreaming;

  /// 是否启用音频缓存
  final bool enableCache;

  /// 音频文件保存目录
  final String audioSaveDirectory;

  const TTSConfig({
    this.defaultProvider = TTSProviderType.glmTTS,
    this.defaultApiKey,
    this.defaultVoice = 'female',
    this.defaultSpeed = 1.0,
    this.defaultVolume = 1.0,
    this.defaultFormat = 'wav',
    this.defaultSampleRate = 24000,
    this.enableStreaming = true,
    this.enableCache = true,
    this.audioSaveDirectory = 'audio',
  });

  /// 默认配置
  static const TTSConfig defaultConfig = TTSConfig();

  /// 从Map创建配置
  factory TTSConfig.fromMap(Map<String, dynamic> map) {
    final providerStr = map['defaultProvider'] as String?;
    final provider = providerStr != null
        ? TTSProviderType.fromValue(providerStr)
        : TTSProviderType.glmTTS;

    return TTSConfig(
      defaultProvider: provider ?? TTSProviderType.glmTTS,
      defaultApiKey: map['defaultApiKey'] as String?,
      defaultVoice: map['defaultVoice'] as String? ?? 'female',
      defaultSpeed: (map['defaultSpeed'] as num?)?.toDouble() ?? 1.0,
      defaultVolume: (map['defaultVolume'] as num?)?.toDouble() ?? 1.0,
      defaultFormat: map['defaultFormat'] as String? ?? 'wav',
      defaultSampleRate: map['defaultSampleRate'] as int? ?? 24000,
      enableStreaming: map['enableStreaming'] as bool? ?? true,
      enableCache: map['enableCache'] as bool? ?? true,
      audioSaveDirectory: map['audioSaveDirectory'] as String? ?? 'audio',
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'defaultProvider': defaultProvider.value,
      'defaultApiKey': defaultApiKey,
      'defaultVoice': defaultVoice,
      'defaultSpeed': defaultSpeed,
      'defaultVolume': defaultVolume,
      'defaultFormat': defaultFormat,
      'defaultSampleRate': defaultSampleRate,
      'enableStreaming': enableStreaming,
      'enableCache': enableCache,
      'audioSaveDirectory': audioSaveDirectory,
    };
  }
}

/// TTS合成参数
class TTSParams {
  /// 要合成的文本
  final String text;

  /// 供应商类型（可选，使用默认值）
  final TTSProviderType? provider;

  /// API密钥（可选）
  final String? apiKey;

  /// 音色
  final String? voice;

  /// 语速 (0.25-4.0)
  final double? speed;

  /// 音量 (0.0-2.0)
  final double? volume;

  /// 音频格式
  final String? format;

  /// 采样率
  final int? sampleRate;

  /// 模型（某些供应商需要）
  final String? model;

  /// 是否使用流式合成
  final bool? stream;

  /// 其他供应商特定参数
  final Map<String, dynamic>? additionalParams;

  const TTSParams({
    required this.text,
    this.provider,
    this.apiKey,
    this.voice,
    this.speed,
    this.volume,
    this.format,
    this.sampleRate,
    this.model,
    this.stream,
    this.additionalParams,
  });

  /// 转换为供应商参数Map
  Map<String, dynamic> toProviderParams() {
    final params = <String, dynamic>{};

    if (voice != null) params['voice'] = voice;
    if (speed != null) params['speed'] = speed;
    if (volume != null) params['volume'] = volume;
    if (format != null) params['format'] = format;
    if (sampleRate != null) params['sampleRate'] = sampleRate;
    if (model != null) params['model'] = model;
    if (stream != null) params['stream'] = stream;

    if (additionalParams != null) {
      params.addAll(additionalParams!);
    }

    return params;
  }
}

/// TTS合成结果
class TTSResult {
  /// 音频数据
  final Uint8List audioData;

  /// 音频格式
  final String format;

  /// 采样率
  final int sampleRate;

  /// 音频时长（秒）
  final double duration;

  /// 供应商类型
  final TTSProviderType provider;

  /// 使用的参数
  final Map<String, dynamic> params;

  /// 合成耗时（毫秒）
  final int synthesisTimeMs;

  const TTSResult({
    required this.audioData,
    required this.format,
    required this.sampleRate,
    required this.duration,
    required this.provider,
    required this.params,
    required this.synthesisTimeMs,
  });

  /// 获取文件扩展名
  String get fileExtension {
    switch (format.toLowerCase()) {
      case 'wav':
        return 'wav';
      case 'mp3':
        return 'mp3';
      case 'flac':
        return 'flac';
      case 'pcm':
      default:
        return 'pcm';
    }
  }

  /// 获取MIME类型
  String get mimeType {
    switch (format.toLowerCase()) {
      case 'wav':
        return 'audio/wav';
      case 'mp3':
        return 'audio/mpeg';
      case 'flac':
        return 'audio/flac';
      case 'pcm':
      default:
        return 'audio/pcm';
    }
  }
}

/// 基于供应商架构的新TTS服务
///
/// 该服务集成了TTS供应商架构，提供统一的语音合成接口。
/// 支持多个供应商、参数配置、音频文件保存等功能。
class TTSService {
  final TTSConfig _config;
  TTSProvider? _currentProvider;
  String? _currentApiKey;
  bool _isInitialized = false;

  /// 构造函数
  TTSService({TTSConfig? config})
      : _config = config ?? TTSConfig.defaultConfig;

  /// 初始化TTS服务
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      // 初始化默认供应商
      await _initializeDefaultProvider();

      _isInitialized = true;
      debugPrint('TTS服务初始化成功 - 默认供应商: ${_config.defaultProvider.displayName}');
    } catch (e) {
      debugPrint('TTS服务初始化失败: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// 检查TTS服务是否可用
  Future<bool> isAvailable() async {
    if (!_isInitialized) {
      try {
        await initialize();
      } catch (e) {
        return false;
      }
    }
    return _isInitialized;
  }

  /// 获取当前供应商
  TTSProvider? get currentProvider => _currentProvider;

  /// 获取当前配置
  TTSConfig get config => _config;

  /// 切换供应商
  Future<void> switchProvider(
    TTSProviderType provider, {
    String? apiKey,
    Map<String, dynamic>? kwargs,
  }) async {
    try {
      _currentProvider = ProviderFactory.getProvider(
        provider,
        apiKey: apiKey ?? _config.defaultApiKey,
        kwargs: kwargs ?? {},
      );
      _currentApiKey = apiKey ?? _config.defaultApiKey;

      debugPrint('已切换供应商: ${provider.displayName}');
    } catch (e) {
      debugPrint('切换供应商失败: $e');
      rethrow;
    }
  }

  /// 合成语音并保存到文件
  ///
  /// [text] 要合成的文本
  /// [params] 合成参数（可选）
  /// [fileName] 自定义文件名（可选）
  ///
  /// 返回保存的文件路径，如果失败返回null
  Future<String?> synthesizeToFile(
    String text, {
    TTSParams? params,
    String? fileName,
  }) async {
    try {
      await _ensureInitialized();

      // 准备合成参数
      final synthesisParams = params ?? TTSParams(text: text);
      final providerParams = _prepareProviderParams(synthesisParams);

      // 合成语音
      final result = await _synthesizeInternal(text, providerParams);

      // 保存到文件
      final filePath = await _saveAudioToFile(result, fileName: fileName);

      debugPrint('TTS合成成功 - 文件已保存: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('TTS合成失败: $e');
      return null;
    }
  }

  /// 流式合成语音
  ///
  /// [text] 要合成的文本
  /// [params] 合成参数（可选）
  ///
  /// 返回音频数据流
  Stream<Uint8List> streamSynthesize(
    String text, {
    TTSParams? params,
  }) {
    _ensureInitializedSync();

    // 准备合成参数
    final synthesisParams = params ?? TTSParams(text: text);
    final providerParams = _prepareProviderParams(synthesisParams);

    // 确保使用流式模式
    providerParams['stream'] = true;

    // 使用当前供应商进行流式合成
    if (_currentProvider == null) {
      throw StateError('TTS服务未初始化或供应商不可用');
    }

    return _currentProvider!.streamSynthesize(text, providerParams).map((chunk) => Uint8List.fromList(chunk));
  }

  /// 合成语音并返回音频数据（不保存文件）
  ///
  /// [text] 要合成的文本
  /// [params] 合成参数（可选）
  ///
  /// 返回音频数据，如果失败返回null
  Future<Uint8List?> synthesizeToMemory(
    String text, {
    TTSParams? params,
  }) async {
    try {
      await _ensureInitialized();

      // 准备合成参数
      final synthesisParams = params ?? TTSParams(text: text);
      final providerParams = _prepareProviderParams(synthesisParams);

      // 合成语音
      final result = await _synthesizeInternal(text, providerParams);

      return result.audioData;
    } catch (e) {
      debugPrint('TTS合成失败: $e');
      return null;
    }
  }

  /// 播放文本（不保存文件）
  ///
  /// 注意：此方法需要集成音频播放器
  /// 目前仅合成并保存到临时文件，然后通知外部播放
  Future<void> speak(
    String text, {
    TTSParams? params,
  }) async {
    try {
      await _ensureInitialized();

      // 准备合成参数
      final synthesisParams = params ?? TTSParams(text: text);
      final providerParams = _prepareProviderParams(synthesisParams);

      // 合成语音
      final result = await _synthesizeInternal(text, providerParams);

      // 保存到临时文件
      final tempFilePath = await _saveAudioToFile(result, isTemporary: true);

      debugPrint('TTS播放准备完成 - 临时文件: $tempFilePath');

      // 这里应该通知音频播放器播放文件
      // 实际实现需要与AudioPlayerService集成
      _notifyAudioPlayback(tempFilePath);
    } catch (e) {
      debugPrint('TTS播放失败: $e');
      rethrow;
    }
  }

  /// 停止播放
  ///
  /// 注意：此方法需要与音频播放器集成
  void stop() {
    // 这里应该通知音频播放器停止播放
    // 实际实现需要与AudioPlayerService集成
    _notifyAudioStop();
  }

  /// 获取支持的供应商列表
  List<TTSProviderType> getSupportedProviders() {
    return TTSProviderType.values;
  }

  /// 获取供应商支持的音色列表
  List<String> getSupportedVoices([TTSProvider? provider]) {
    final providerName = provider?.name ?? _currentProvider?.name;
    if (providerName == null) {
      return [];
    }

    final providerEnum = TTSProviderType.fromValue(providerName);
    if (providerEnum == null) {
      return [];
    }

    return TTSProviderConfig.getSupportedVoices(providerEnum);
  }

  /// 获取供应商支持的音频格式
  List<String> getSupportedFormats() {
    return TTSProviderConfig.supportedFormats;
  }

  /// 设置语言
  ///
  /// 注意：对于供应商API，语言通常由音色决定
  /// 此方法主要用于兼容性
  Future<void> setLanguage(String languageCode) async {
    await _ensureInitialized();
    debugPrint('设置语言: $languageCode');
  }

  /// 设置语速
  Future<void> setSpeechRate(double rate) async {
    await _ensureInitialized();
    debugPrint('设置语速: $rate');
    // 参数将在合成时应用
  }

  /// 设置音调
  Future<void> setPitch(double pitch) async {
    await _ensureInitialized();
    debugPrint('设置音调: $pitch');
    // 注意：某些供应商API可能不支持音调参数
  }

  /// 设置音量
  Future<void> setVolume(double volume) async {
    await _ensureInitialized();
    debugPrint('设置音量: $volume');
    // 参数将在合成时应用
  }

  /// 获取音频保存目录
  Future<Directory> getAudioSaveDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final audioDir = Directory(path.join(appDir.path, _config.audioSaveDirectory));

    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }

    return audioDir;
  }

  /// 清除所有缓存的供应商实例
  void clearCache() {
    ProviderFactory.clearCache();
    debugPrint('已清除所有TTS供应商缓存');
  }

  /// 释放资源
  void dispose() {
    stop();
    clearCache();
    _isInitialized = false;
    debugPrint('TTS服务已释放');
  }

  // ===========================================================================
  // 私有方法
  // ===========================================================================

  /// 确保服务已初始化
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// 同步确保服务已初始化
  void _ensureInitializedSync() {
    if (!_isInitialized) {
      throw StateError('TTS服务未初始化，请先调用initialize()方法');
    }
  }

  /// 初始化默认供应商
  Future<void> _initializeDefaultProvider() async {
    try {
      _currentProvider = ProviderFactory.getProvider(
        _config.defaultProvider,
        apiKey: _config.defaultApiKey,
        kwargs: {},
      );
      _currentApiKey = _config.defaultApiKey;

      debugPrint('默认供应商初始化成功: ${_config.defaultProvider.displayName}');
    } catch (e) {
      debugPrint('默认供应商初始化失败: $e');
      // 尝试使用其他供应商作为后备
      await _tryFallbackProvider();
    }
  }

  /// 尝试使用后备供应商
  Future<void> _tryFallbackProvider() async {
    for (final provider in TTSProviderType.values) {
      if (provider == _config.defaultProvider) {
        continue; // 跳过默认供应商（已失败）
      }

      try {
        _currentProvider = ProviderFactory.getProvider(
          provider,
          apiKey: _config.defaultApiKey,
          kwargs: {},
        );
        _currentApiKey = _config.defaultApiKey;

        debugPrint('使用后备供应商: ${provider.displayName}');
        return;
      } catch (e) {
        debugPrint('后备供应商 ${provider.displayName} 初始化失败: $e');
      }
    }

    throw StateError('所有TTS供应商初始化失败，请检查网络连接和API配置');
  }

  /// 准备供应商参数
  Map<String, dynamic> _prepareProviderParams(TTSParams params) {
    final providerParams = <String, dynamic>{};

    // 应用配置默认值
    providerParams['voice'] = params.voice ?? _config.defaultVoice;
    providerParams['speed'] = params.speed ?? _config.defaultSpeed;
    providerParams['volume'] = params.volume ?? _config.defaultVolume;
    providerParams['format'] = params.format ?? _config.defaultFormat;
    providerParams['sampleRate'] = params.sampleRate ?? _config.defaultSampleRate;

    if (params.model != null) {
      providerParams['model'] = params.model;
    }

    // 应用流式配置
    if (params.stream != null) {
      providerParams['stream'] = params.stream;
    } else if (_config.enableStreaming) {
      providerParams['stream'] = false; // 非流式合成默认
    }

    // 添加额外参数
    if (params.additionalParams != null) {
      providerParams.addAll(params.additionalParams!);
    }

    return providerParams;
  }

  /// 内部合成方法
  Future<TTSResult> _synthesizeInternal(
    String text,
    Map<String, dynamic> providerParams,
  ) async {
    final startTime = DateTime.now();

    // 确定使用的供应商
    final TTSProviderType targetProvider;
    final String? targetApiKey;

    if (providerParams.containsKey('_provider')) {
      // 使用指定的供应商
      final providerName = providerParams['_provider'] as String;
      final provider = TTSProviderType.fromValue(providerName);
      if (provider == null) {
        throw ArgumentError('无效的供应商名称: $providerName');
      }
      targetProvider = provider;
      targetApiKey = providerParams['_apiKey'] as String? ?? _currentApiKey;
    } else {
      // 使用当前供应商
      if (_currentProvider == null) {
        throw StateError('TTS服务未初始化或供应商不可用');
      }
      targetProvider = _config.defaultProvider;
      targetApiKey = _currentApiKey;
    }

    // 获取供应商实例
    final providerInstance = ProviderFactory.getProvider(
      targetProvider,
      apiKey: targetApiKey,
      kwargs: providerParams,
    );

    // 合成语音
    final audioData = await providerInstance.synthesize(text, providerParams);

    // 计算合成耗时
    final synthesisTimeMs = DateTime.now().difference(startTime).inMilliseconds;

    // 计算音频时长
    final sampleRate = providerParams['sampleRate'] ?? _config.defaultSampleRate;
    final duration = AudioUtils.calculateAudioDuration(
      audioData,
      sampleRate: sampleRate,
    );

    return TTSResult(
      audioData: audioData,
      format: providerParams['format'] ?? _config.defaultFormat,
      sampleRate: sampleRate,
      duration: duration,
      provider: targetProvider,
      params: providerParams,
      synthesisTimeMs: synthesisTimeMs,
    );
  }

  /// 保存音频到文件
  Future<String> _saveAudioToFile(
    TTSResult result, {
    String? fileName,
    bool isTemporary = false,
  }) async {
    final audioDir = await getAudioSaveDirectory();

    // 生成文件名
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeFileName = fileName ?? 'tts_${timestamp}_${result.provider.value}';
    final fileExtension = result.fileExtension;

    String filePath;
    if (isTemporary) {
      // 临时文件保存在临时目录
      final tempDir = await getTemporaryDirectory();
      filePath = path.join(tempDir.path, '$safeFileName.$fileExtension');
    } else {
      // 永久文件保存在音频目录
      filePath = path.join(audioDir.path, '$safeFileName.$fileExtension');
    }

    // 写入文件
    final file = File(filePath);
    await file.writeAsBytes(result.audioData);

    return filePath;
  }

  /// 通知音频播放（需要与AudioPlayerService集成）
  void _notifyAudioPlayback(String filePath) {
    // TODO: 实现与AudioPlayerService的集成
    // 这里可以发送通知或调用回调函数
    debugPrint('TTS音频播放通知 - 文件路径: $filePath');
  }

  /// 通知音频停止（需要与AudioPlayerService集成）
  void _notifyAudioStop() {
    // TODO: 实现与AudioPlayerService的集成
    debugPrint('TTS音频停止通知');
  }
}
