import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';

import '../tts/providers/provider_config.dart';

/// TTS配置状态类
class TTSConfigState {
  final TTSProviderType providerType;
  final String? apiKey;
  final String voice;
  final double speed;
  final double volume;
  final String format;
  final int sampleRate;
  final bool isApiKeyObscured;

  const TTSConfigState({
    required this.providerType,
    this.apiKey,
    required this.voice,
    required this.speed,
    required this.volume,
    required this.format,
    required this.sampleRate,
    this.isApiKeyObscured = true,
  });

  TTSConfigState copyWith({
    TTSProviderType? providerType,
    String? apiKey,
    String? voice,
    double? speed,
    double? volume,
    String? format,
    int? sampleRate,
    bool? isApiKeyObscured,
  }) {
    return TTSConfigState(
      providerType: providerType ?? this.providerType,
      apiKey: apiKey ?? this.apiKey,
      voice: voice ?? this.voice,
      speed: speed ?? this.speed,
      volume: volume ?? this.volume,
      format: format ?? this.format,
      sampleRate: sampleRate ?? this.sampleRate,
      isApiKeyObscured: isApiKeyObscured ?? this.isApiKeyObscured,
    );
  }

  /// 转换为Map用于持久化
  Map<String, dynamic> toJson() {
    return {
      'providerType': providerType.value,
      'apiKey': apiKey,
      'voice': voice,
      'speed': speed,
      'volume': volume,
      'format': format,
      'sampleRate': sampleRate,
      'isApiKeyObscured': isApiKeyObscured,
    };
  }

  /// 从Map创建配置状态
  factory TTSConfigState.fromJson(Map<String, dynamic> json) {
    final providerStr = json['providerType'] as String?;
    final provider = providerStr != null
        ? TTSProviderType.fromValue(providerStr)
        : TTSProviderType.glmTTS;

    return TTSConfigState(
      providerType: provider ?? TTSProviderType.glmTTS,
      apiKey: json['apiKey'] as String?,
      voice: json['voice'] as String? ?? 'female',
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      format: json['format'] as String? ?? 'wav',
      sampleRate: json['sampleRate'] as int? ?? 24000,
      isApiKeyObscured: json['isApiKeyObscured'] as bool? ?? true,
    );
  }

  /// 获取默认配置状态
  static TTSConfigState get defaultConfig {
    return const TTSConfigState(
      providerType: TTSProviderType.glmTTS,
      apiKey: null,
      voice: 'female',
      speed: 1.0,
      volume: 1.0,
      format: 'wav',
      sampleRate: 24000,
      isApiKeyObscured: true,
    );
  }

  /// 获取当前供应商支持的音色列表
  List<String> getSupportedVoices() {
    return TTSProviderConfig.getSupportedVoices(providerType);
  }

  /// 获取参数范围限制
  Map<String, dynamic> getParamRanges() {
    return TTSProviderConfig.getParamRanges(providerType);
  }

  /// 验证参数是否在有效范围内
  bool validateParam(String paramName, dynamic value) {
    return TTSProviderConfig.validateParamRange(providerType, paramName, value);
  }

  /// 获取供应商显示名称
  String get providerDisplayName => providerType.displayName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TTSConfigState &&
          runtimeType == other.runtimeType &&
          providerType == other.providerType &&
          apiKey == other.apiKey &&
          voice == other.voice &&
          speed == other.speed &&
          volume == other.volume &&
          format == other.format &&
          sampleRate == other.sampleRate &&
          isApiKeyObscured == other.isApiKeyObscured;

  @override
  int get hashCode =>
      providerType.hashCode ^
      apiKey.hashCode ^
      voice.hashCode ^
      speed.hashCode ^
      volume.hashCode ^
      format.hashCode ^
      sampleRate.hashCode ^
      isApiKeyObscured.hashCode;
}

/// TTS配置通知器
class TTSConfigNotifier extends StateNotifier<TTSConfigState> {
  static const String _configFileName = 'tts_config.json';

  TTSConfigNotifier() : super(TTSConfigState.defaultConfig) {
    _loadConfig();
  }

  /// 加载配置
  Future<void> _loadConfig() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final configFile = File('${appDir.path}/$_configFileName');

      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        final jsonData = jsonDecode(content);
        final loadedConfig = TTSConfigState.fromJson(jsonData);
        state = loadedConfig;
      }
    } catch (e) {
      // 加载失败时使用默认配置
      debugPrint('加载TTS配置失败: $e');
    }
  }

  /// 保存配置
  Future<void> _saveConfig() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final configFile = File('${appDir.path}/$_configFileName');
      await configFile.writeAsString(jsonEncode(state.toJson()));
    } catch (e) {
      debugPrint('保存TTS配置失败: $e');
    }
  }

  /// 更新供应商类型
  void updateProviderType(TTSProviderType providerType) {
    // 切换供应商时重置音色为第一个支持的音色
    final supportedVoices = TTSProviderConfig.getSupportedVoices(providerType);
    final newVoice = supportedVoices.isNotEmpty ? supportedVoices[0] : 'female';

    final newState = state.copyWith(
      providerType: providerType,
      voice: newVoice,
    );

    state = newState;
    _saveConfig();
  }

  /// 更新API密钥
  void updateApiKey(String apiKey) {
    state = state.copyWith(apiKey: apiKey);
    _saveConfig();
  }

  /// 切换API密钥显示/隐藏状态
  void toggleApiKeyObscured() {
    state = state.copyWith(isApiKeyObscured: !state.isApiKeyObscured);
  }

  /// 更新音色
  void updateVoice(String voice) {
    // 验证音色是否在当前供应商支持列表中
    final supportedVoices = state.getSupportedVoices();
    if (supportedVoices.contains(voice)) {
      state = state.copyWith(voice: voice);
      _saveConfig();
    }
  }

  /// 更新语速
  void updateSpeed(double speed) {
    if (state.validateParam('speed', speed)) {
      state = state.copyWith(speed: speed);
      _saveConfig();
    }
  }

  /// 更新音量
  void updateVolume(double volume) {
    if (state.validateParam('volume', volume)) {
      state = state.copyWith(volume: volume);
      _saveConfig();
    }
  }

  /// 更新音频格式
  void updateFormat(String format) {
    state = state.copyWith(format: format);
    _saveConfig();
  }

  /// 更新采样率
  void updateSampleRate(int sampleRate) {
    if (state.validateParam('sampleRate', sampleRate)) {
      state = state.copyWith(sampleRate: sampleRate);
      _saveConfig();
    }
  }

  /// 重置为默认配置
  void resetToDefaults() {
    state = TTSConfigState.defaultConfig;
    _saveConfig();
  }

  /// 获取当前配置的API密钥（处理显示/隐藏）
  String getDisplayApiKey() {
    if (state.apiKey == null || state.apiKey!.isEmpty) {
      return '';
    }

    if (state.isApiKeyObscured) {
      return '•' * 16; // 显示16个圆点
    }

    return state.apiKey!;
  }

  /// 检查是否已配置API密钥
  bool hasApiKey() {
    return state.apiKey != null && state.apiKey!.isNotEmpty;
  }
}

/// TTS配置Provider
final ttsConfigProvider = StateNotifierProvider<TTSConfigNotifier, TTSConfigState>(
  (ref) => TTSConfigNotifier(),
);

/// 辅助方法：获取TTS参数Map
Map<String, dynamic> getTTSParamsFromConfig(TTSConfigState config) {
  return {
    'provider': config.providerType,
    'apiKey': config.apiKey,
    'voice': config.voice,
    'speed': config.speed,
    'volume': config.volume,
    'format': config.format,
    'sampleRate': config.sampleRate,
  };
}
