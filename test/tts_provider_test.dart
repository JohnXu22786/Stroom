import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/tts/providers/tts_provider.dart';
import 'package:stroom/tts/providers/provider_factory.dart';
import 'package:stroom/tts/providers/provider_config.dart';
import 'package:stroom/tts/providers/implementations/glm_tts_provider.dart';
import 'package:stroom/tts/providers/implementations/aihubmix_tts_provider.dart';
import 'package:stroom/tts/audio/audio_utils.dart';

/// 测试TTS供应商系统
void main() {
  group('TTSProvider抽象类测试', () {
    test('TTSProvider接口定义', () {
      expect(TTSProvider, isNotNull);
      expect(TTSProvider, isA<Type>());
    });

    test('供应商名称和属性', () {
      final mockProvider = _MockTTSProvider();
      expect(mockProvider.name, equals('mock_provider'));
      expect(mockProvider.supportedModels, equals(['mock_model']));
      expect(mockProvider.defaultParams, equals({}));
    });
  });

  group('ProviderFactory测试', () {
    setUp(() {
      // 清理缓存，确保每个测试独立
      ProviderFactory.clearCache();
    });

    test('获取GLM-TTS供应商实例', () {
      final provider = ProviderFactory.getProvider(TTSProviderType.glmTTS);
      expect(provider, isNotNull);
      expect(provider, isA<TTSProvider>());
      expect(provider.name, equals('glm_tts'));
    });

    test('获取AIHUBMIX-TTS供应商实例', () {
      final provider = ProviderFactory.getProvider(TTSProviderType.aihubmixTTS);
      expect(provider, isNotNull);
      expect(provider, isA<TTSProvider>());
      expect(provider.name, equals('aihubmix_tts'));
    });

    test('通过名称获取供应商实例', () {
      final glmProvider = ProviderFactory.getProviderByName('glm_tts');
      expect(glmProvider, isNotNull);
      expect(glmProvider.name, equals('glm_tts'));

      final aihubmixProvider = ProviderFactory.getProviderByName('aihubmix_tts');
      expect(aihubmixProvider, isNotNull);
      expect(aihubmixProvider.name, equals('aihubmix_tts'));
    });

    test('无效供应商名称应抛出异常', () {
      expect(
        () => ProviderFactory.getProviderByName('invalid_provider'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('供应商实例缓存功能', () {
      final provider1 = ProviderFactory.getProvider(TTSProviderType.glmTTS);
      final provider2 = ProviderFactory.getProvider(TTSProviderType.glmTTS);

      // 同一类型的供应商应该返回相同的实例（缓存）
      expect(identical(provider1, provider2), isTrue);

      // 清除缓存后应该返回新实例
      ProviderFactory.clearProviderCache(provider: TTSProviderType.glmTTS);
      final provider3 = ProviderFactory.getProvider(TTSProviderType.glmTTS);
      expect(identical(provider1, provider3), isFalse);
    });

    test('缓存统计信息', () {
      // 获取两个供应商实例
      ProviderFactory.getProvider(TTSProviderType.glmTTS);
      ProviderFactory.getProvider(TTSProviderType.aihubmixTTS);

      final stats = ProviderFactory.getCacheStats();
      expect(stats['totalCachedInstances'], equals(2));
      expect(stats['cachedProviders'], isA<List>());
      expect((stats['cachedProviders'] as List).length, equals(2));
    });
  });

  group('TTSProviderConfig测试', () {
    test('供应商类型枚举', () {
      expect(TTSProviderType.glmTTS.value, equals('glm_tts'));
      expect(TTSProviderType.aihubmixTTS.value, equals('aihubmix_tts'));

      final glmType = TTSProviderType.fromValue('glm_tts');
      expect(glmType, equals(TTSProviderType.glmTTS));

      final aihubmixType = TTSProviderType.fromValue('aihubmix_tts');
      expect(aihubmixType, equals(TTSProviderType.aihubmixTTS));

      final invalidType = TTSProviderType.fromValue('invalid');
      expect(invalidType, isNull);
    });

    test('获取支持的模型列表', () {
      final glmModels = TTSProviderConfig.getSupportedModels(TTSProviderType.glmTTS);
      expect(glmModels, equals(['glm-tts']));

      final aihubmixModels = TTSProviderConfig.getSupportedModels(TTSProviderType.aihubmixTTS);
      expect(aihubmixModels, equals(['tts-1', 'tts-1-hd']));
    });

    test('获取默认参数', () {
      final glmParams = TTSProviderConfig.getDefaultParams(TTSProviderType.glmTTS);
      expect(glmParams, isA<Map<String, dynamic>>());
      expect(glmParams['voice'], equals('female'));
      expect(glmParams['speed'], equals(1.0));
      expect(glmParams['format'], equals('wav'));

      final aihubmixParams = TTSProviderConfig.getDefaultParams(TTSProviderType.aihubmixTTS);
      expect(aihubmixParams, isA<Map<String, dynamic>>());
      expect(aihubmixParams['voice'], equals('alloy'));
      expect(aihubmixParams['speed'], equals(1.0));
      expect(aihubmixParams['format'], equals('mp3'));
    });

    test('获取支持的音色列表', () {
      final glmVoices = TTSProviderConfig.getSupportedVoices(TTSProviderType.glmTTS);
      expect(glmVoices, isA<List<String>>());
      expect(glmVoices.length, greaterThan(0));

      final aihubmixVoices = TTSProviderConfig.getSupportedVoices(TTSProviderType.aihubmixTTS);
      expect(aihubmixVoices, isA<List<String>>());
      expect(aihubmixVoices.length, greaterThan(0));
    });
  });

  group('供应商具体实现测试', () {
    test('GLM-TTS供应商基础功能', () async {
      final provider = GLMTTSProvider();
      expect(provider.name, equals('glm_tts'));
      expect(provider.supportedModels, equals(['glm-tts']));

      // 测试参数验证
      final params = provider.validateParams({'voice': 'female', 'speed': 1.0});
      expect(params['voice'], equals('female'));
      expect(params['speed'], equals(1.0));

      // 测试无效参数
      expect(
        () => provider.validateParams({'speed': 3.0}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('AIHUBMIX-TTS供应商基础功能', () async {
      final provider = AIHUBMIXTTSProvider();
      expect(provider.name, equals('aihubmix_tts'));
      expect(provider.supportedModels, equals(['tts-1', 'tts-1-hd']));

      // 测试参数验证
      final params = provider.validateParams({'voice': 'alloy', 'speed': 1.0});
      expect(params['voice'], equals('alloy'));
      expect(params['speed'], equals(1.0));

      // 测试无效参数
      expect(
        () => provider.validateParams({'speed': 5.0}),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('AudioUtils测试', () {
    test('PCM到WAV格式转换', () {
      // 创建模拟PCM数据
      final pcmData = Uint8List.fromList(List.generate(1024, (index) => index % 256));

      final wavData = AudioUtils.pcmToWav(
        pcmData,
        sampleRate: 24000,
        bitsPerSample: 16,
        numChannels: 1,
      );

      expect(wavData, isNotNull);
      expect(wavData.length, greaterThan(pcmData.length)); // WAV文件包含头信息

      // 检查WAV文件头
      expect(wavData[0], 0x52); // 'R'
      expect(wavData[1], 0x49); // 'I'
      expect(wavData[2], 0x46); // 'F'
      expect(wavData[3], 0x46); // 'F'
      expect(wavData[8], 0x57); // 'W'
      expect(wavData[9], 0x41); // 'A'
      expect(wavData[10], 0x56); // 'V'
      expect(wavData[11], 0x45); // 'E'
    });

    test('音频格式枚举', () {
      expect(AudioFormat.pcm.value, equals('pcm'));
      expect(AudioFormat.wav.value, equals('wav'));
      expect(AudioFormat.mp3.value, equals('mp3'));
      expect(AudioFormat.flac.value, equals('flac'));

      final pcmFormat = AudioFormat.fromValue('pcm');
      expect(pcmFormat, equals(AudioFormat.pcm));

      final wavFormat = AudioFormat.fromValue('wav');
      expect(wavFormat, equals(AudioFormat.wav));

      final invalidFormat = AudioFormat.fromValue('invalid');
      expect(invalidFormat, isNull);
    });
  });

  group('供应商方法测试', () {
    test('合成方法调用', () async {
      final provider = _MockTTSProvider();

      // 测试非流式合成
      final audioData = await provider.synthesize('测试文本');
      expect(audioData, isA<Uint8List>());
      expect(audioData.length, greaterThan(0));

      // 测试流式合成
      final stream = provider.streamSynthesize('测试文本');
      expect(stream, isA<Stream<Uint8List>>());

      int chunkCount = 0;
      await for (final chunk in stream) {
        expect(chunk, isA<Uint8List>());
        chunkCount++;
      }
      expect(chunkCount, greaterThan(0));
    });

    test('参数验证和合并', () {
      final provider = _MockTTSProvider();

      // 测试默认参数
      final defaultParams = provider.defaultParams;
      expect(defaultParams, equals({}));

      // 测试参数验证和合并
      final validatedParams = provider.validateParams({'custom': 'value'});
      expect(validatedParams['custom'], equals('value'));

      // 测试重写的验证逻辑
      final providerWithCustom = _MockTTSProviderWithValidation();
      final customParams = providerWithCustom.validateParams({'test': 'data'});
      expect(customParams['test'], equals('data'));
      expect(customParams['validated'], isTrue);
    });
  });

  group('集成测试', () {
    test('完整的TTS供应商流程', () async {
      // 1. 获取供应商实例
      final provider = ProviderFactory.getProvider(TTSProviderType.glmTTS);

      // 2. 验证供应商属性
      expect(provider.name, equals('glm_tts'));
      expect(provider.supportedModels, isNotEmpty);

      // 3. 准备合成参数
      final params = {
        'voice': 'female',
        'speed': 1.0,
        'format': 'wav',
      };

      // 4. 合成语音（模拟）
      try {
        final audioData = await provider.synthesize('集成测试文本', params);
        expect(audioData, isA<Uint8List>());
        expect(audioData.length, greaterThan(0));
      } catch (e) {
        // 如果供应商尚未完全实现，允许抛出UnimplementedError
        expect(e, isA<UnimplementedError>());
      }
    });

    test('多个供应商切换', () {
      final glmProvider = ProviderFactory.getProvider(TTSProviderType.glmTTS);
      final aihubmixProvider = ProviderFactory.getProvider(TTSProviderType.aihubmixTTS);

      expect(glmProvider.name, equals('glm_tts'));
      expect(aihubmixProvider.name, equals('aihubmix_tts'));
      expect(glmProvider, isNot(equals(aihubmixProvider)));

      // 检查供应商属性差异
      final glmVoices = TTSProviderConfig.getSupportedVoices(TTSProviderType.glmTTS);
      final aihubmixVoices = TTSProviderConfig.getSupportedVoices(TTSProviderType.aihubmixTTS);
      expect(glmVoices, isNot(equals(aihubmixVoices)));
    });
  });
}

/// 模拟TTSProvider用于测试
class _MockTTSProvider extends TTSProvider {
  @override
  String get name => 'mock_provider';

  @override
  List<String> get supportedModels => ['mock_model'];

  @override
  Map<String, dynamic> get defaultParams => {};

  @override
  Future<Uint8List> synthesize(String text, [Map<String, dynamic>? kwargs]) async {
    // 返回模拟音频数据
    return Uint8List.fromList(List.generate(1024, (index) => index % 256));
  }

  @override
  Stream<Uint8List> streamSynthesize(String text, [Map<String, dynamic>? kwargs]) async* {
    // 模拟流式音频数据
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 10));
      yield Uint8List.fromList(List.generate(256, (index) => (i * 256 + index) % 256));
    }
  }
}

/// 带有自定义验证逻辑的模拟TTSProvider
class _MockTTSProviderWithValidation extends _MockTTSProvider {
  @override
  Map<String, dynamic> validateParams(Map<String, dynamic>? kwargs) {
    final params = super.validateParams(kwargs);
    // 添加自定义验证标记
    params['validated'] = true;
    return params;
  }
}
