
import 'package:stroom/tts/providers/tts_provider.dart';
import 'package:stroom/tts/providers/provider_config.dart';
import 'package:stroom/tts/providers/implementations/glm_tts_provider.dart';
import 'package:stroom/tts/providers/implementations/aihubmix_tts_provider.dart';

/// TTS供应商工厂类
///
/// 采用工厂模式(Factory Pattern)设计，根据供应商名称动态创建供应商实例。
/// 支持实例缓存以提高性能，避免重复初始化开销。
class ProviderFactory {
  // 防止实例化
  ProviderFactory._();

  /// 供应商实例缓存
  ///
  /// 键：缓存键（由供应商类型和API密钥生成）
  /// 值：缓存的TTSProvider实例
  static final Map<String, TTSProvider> _providerCache = {};

  /// 获取TTS供应商实例
  ///
  /// [provider] 供应商类型（枚举）
  /// [apiKey] API密钥（可选，某些供应商可能需要）
  /// [kwargs] 其他供应商特定参数
  ///
  /// 返回对应的TTSProvider实例
  /// 如果供应商不可用或创建失败，抛出TTSProviderError异常
  static TTSProvider getProvider(
    TTSProviderType provider, {
    String? apiKey,
    Map<String, dynamic> kwargs = const {},
  }) {
    final cacheKey = _generateCacheKey(provider, apiKey, kwargs);

    // 尝试从缓存获取
    final cachedProvider = _providerCache[cacheKey];
    if (cachedProvider != null) {
      return cachedProvider;
    }

    // 创建新的供应商实例
    final instance = _createProviderInstance(provider, apiKey, kwargs);

    // 缓存实例
    _providerCache[cacheKey] = instance;

    return instance;
  }

  /// 根据供应商名称字符串获取TTS供应商实例
  ///
  /// [providerName] 供应商名称字符串（如 "glm_tts"）
  /// [apiKey] API密钥（可选）
  /// [kwargs] 其他供应商特定参数
  ///
  /// 返回对应的TTSProvider实例
  /// 如果供应商名称无效，抛出ArgumentError异常
  static TTSProvider getProviderByName(
    String providerName, {
    String? apiKey,
    Map<String, dynamic> kwargs = const {},
  }) {
    final providerEnum = TTSProviderType.fromValue(providerName);
    if (providerEnum == null) {
      throw ArgumentError('无效的TTS供应商名称: $providerName');
    }

    return getProvider(providerEnum, apiKey: apiKey, kwargs: kwargs);
  }

  /// 获取缓存的供应商实例
  ///
  /// [provider] 供应商类型
  /// [apiKey] API密钥（可选）
  /// [kwargs] 其他供应商特定参数
  ///
  /// 返回缓存的TTSProvider实例，如果不存在则返回null
  static TTSProvider? getCachedProvider(
    TTSProviderType provider, {
    String? apiKey,
    Map<String, dynamic> kwargs = const {},
  }) {
    final cacheKey = _generateCacheKey(provider, apiKey, kwargs);
    return _providerCache[cacheKey];
  }

  /// 清除所有缓存的供应商实例
  static void clearCache() {
    _providerCache.clear();
  }

  /// 清除指定供应商的缓存实例
  ///
  /// [provider] 供应商类型（如果为null，清除所有实例）
  /// [apiKey] API密钥（如果为null，清除该供应商的所有实例）
  static void clearProviderCache({
    TTSProviderType? provider,
    String? apiKey,
  }) {
    if (provider == null) {
      clearCache();
      return;
    }

    // 构建要删除的键列表
    final keysToRemove = <String>[];
    for (final key in _providerCache.keys) {
      if (_keyMatchesProvider(key, provider, apiKey)) {
        keysToRemove.add(key);
      }
    }

    // 删除匹配的键
    for (final key in keysToRemove) {
      _providerCache.remove(key);
    }
  }

  /// 获取缓存统计信息
  static Map<String, dynamic> getCacheStats() {
    return {
      'totalCachedInstances': _providerCache.length,
      'cachedProviders': _providerCache.keys.map((key) {
        final parts = key.split('|');
        return {
          'cacheKey': key,
          'provider': parts.isNotEmpty ? parts[0] : 'unknown',
          'hasApiKey': parts.length > 1 && parts[1].isNotEmpty,
        };
      }).toList(),
    };
  }

  /// 生成缓存键
  ///
  /// 格式: "provider|apiKey|kwargsHash"
  /// 其中kwargsHash是kwargs的简单哈希（仅用于区分不同配置）
  static String _generateCacheKey(
    TTSProviderType provider,
    String? apiKey,
    Map<String, dynamic> kwargs,
  ) {
    final providerStr = provider.value;
    final apiKeyStr = apiKey ?? '';

    // 为kwargs生成简单哈希（忽略值为null的键）
    final kwargsStr = _generateKwargsString(kwargs);

    return '$providerStr|$apiKeyStr|$kwargsStr';
  }

  /// 生成kwargs的字符串表示用于缓存键
  static String _generateKwargsString(Map<String, dynamic> kwargs) {
    if (kwargs.isEmpty) {
      return '';
    }

    // 排序键以确保一致性
    final sortedKeys = kwargs.keys.toList()..sort();
    final parts = <String>[];

    for (final key in sortedKeys) {
      final value = kwargs[key];
      if (value != null) {
        parts.add('$key:${value.toString()}');
      }
    }

    return parts.join(',');
  }

  /// 检查缓存键是否匹配指定的供应商和API密钥
  static bool _keyMatchesProvider(
    String cacheKey,
    TTSProviderType provider,
    String? apiKey,
  ) {
    final parts = cacheKey.split('|');
    if (parts.isEmpty) {
      return false;
    }

    final cachedProvider = parts[0];
    final cachedApiKey = parts.length > 1 ? parts[1] : '';

    // 检查供应商是否匹配
    if (cachedProvider != provider.value) {
      return false;
    }

    // 检查API密钥是否匹配（如果指定了apiKey）
    if (apiKey != null) {
      return cachedApiKey == apiKey;
    }

    return true;
  }

  /// 创建供应商实例
  ///
  /// 根据供应商类型创建具体的TTSProvider实例
  /// 这是工厂方法的核心实现
  static TTSProvider _createProviderInstance(
    TTSProviderType provider,
    String? apiKey,
    Map<String, dynamic> kwargs,
  ) {
    switch (provider) {
      case TTSProviderType.glmTTS:
        return _createGLMTTSProvider(apiKey, kwargs);
      case TTSProviderType.aihubmixTTS:
        return _createAIHUBMIXTTSProvider(apiKey, kwargs);
    }
  }

  /// 创建GLM-TTS供应商实例
  ///
  /// 注意：此实现需要GLMTTSProvider类和相应的依赖
  /// 如果依赖不可用，将抛出TTSProviderError异常
  static TTSProvider _createGLMTTSProvider(
    String? apiKey,
    Map<String, dynamic> kwargs,
  ) {
    try {
      // 创建具体的GLM-TTS供应商实例
      return GLMTTSProvider(
        apiKey: apiKey,
        kwargs: kwargs,
      );
    } catch (e) {
      throw TTSProviderError(
        '无法创建GLM-TTS供应商实例: $e',
        e,
      );
    }
  }

  /// 创建AIHUBMIX-TTS供应商实例
  ///
  /// 注意：此实现需要AIHUBMIXTTSProvider类和相应的依赖
  /// 如果依赖不可用，将抛出TTSProviderError异常
  static TTSProvider _createAIHUBMIXTTSProvider(
    String? apiKey,
    Map<String, dynamic> kwargs,
  ) {
    try {
      // 创建具体的AIHUBMIX-TTS供应商实例
      return AIHUBMIXTTSProvider(
        apiKey: apiKey,
        kwargs: kwargs,
      );
    } catch (e) {
      throw TTSProviderError(
        '无法创建AIHUBMIX-TTS供应商实例: $e',
        e,
      );
    }
  }


}

/// 基础TTSProvider实现（临时占位）
///


/// TTS供应商错误类型
class TTSProviderError implements Exception {
  final String message;
  final dynamic cause;

  const TTSProviderError(this.message, [this.cause]);

  @override
  String toString() {
    return 'TTSProviderError: $message${cause != null ? ' (Cause: $cause)' : ''}';
  }
}
