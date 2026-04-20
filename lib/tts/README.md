# TTS供应商架构文档

## 概述

本TTS（Text-to-Speech）供应商架构是一个基于Dart/Flutter的多供应商语音合成系统，采用策略模式和工厂模式设计，支持多个TTS服务提供商的无缝集成和动态切换。该架构参考了Python版本的TTS供应商系统，并针对Flutter环境进行了优化和适配。

## 设计原则

- **统一抽象**：所有供应商实现相同的抽象接口
- **松耦合**：供应商实现与业务逻辑分离
- **可扩展**：支持新供应商的无缝集成
- **配置驱动**：通过配置管理供应商参数
- **异步友好**：完全支持Dart的异步编程模型
- **流式支持**：提供实时音频流传输能力

## 核心架构组件

### 1. 抽象基类 (TTSProvider)
`TTSProvider` 是所有具体供应商实现的抽象基类，定义了一致的接口规范：

```dart
abstract class TTSProvider {
  String get name;                           // 供应商名称
  List<String> get supportedModels;         // 支持的模型列表
  Map<String, dynamic> get defaultParams;   // 默认参数配置
  
  Future<Uint8List> synthesize(String text, [Map<String, dynamic>? kwargs]);
  Stream<Uint8List> streamSynthesize(String text, [Map<String, dynamic>? kwargs]);
  Map<String, dynamic> validateParams(Map<String, dynamic>? kwargs);
}
```

### 2. 配置管理 (ProviderConfig)
提供供应商枚举、模型映射和参数验证：

- **TTSProvider枚举**：定义系统支持的供应商类型（GLM-TTS, AIHUBMIX-TTS）
- **供应商配置**：默认参数、参数范围限制、支持的音色列表
- **参数验证**：统一的参数验证和范围检查

### 3. 工厂模式 (ProviderFactory)
采用工厂模式动态创建供应商实例，支持实例缓存以提高性能：

```dart
class ProviderFactory {
  static TTSProvider getProvider(
    TTSProvider provider, {
    String? apiKey,
    Map<String, dynamic> kwargs = const {},
  });
  
  static TTSProvider getProviderByName(
    String providerName, {
    String? apiKey,
    Map<String, dynamic> kwargs = const {},
  });
}
```

### 4. 音频处理工具 (AudioUtils)
提供音频格式转换、修剪、数据对齐等实用功能：

- **格式转换**：PCM ↔ WAV格式转换
- **音频修剪**：GLM-TTS特有的初始蜂鸣声移除
- **数据对齐**：16位PCM数据2字节对齐检查
- **流式处理**：实时音频流修剪包装器

### 5. 具体供应商实现

#### GLM-TTS供应商 (GLMTTSProvider)
- **特性**：GLM（智谱AI）TTS API集成
- **特殊处理**：自动修剪初始蜂鸣声（约0.629秒）
- **参数范围**：语速0.5-2.0，音量0.0-2.0
- **默认格式**：WAV格式，24000Hz采样率

#### AIHUBMIX-TTS供应商 (AIHUBMIXTTSProvider)
- **特性**：OpenAI兼容TTS API集成
- **特殊处理**：无音频修剪需求
- **参数范围**：语速0.25-4.0，音量0.0-2.0
- **默认格式**：MP3格式，24000Hz采样率

### 6. TTS服务集成 (TTSService)
新的TTS服务类，集成供应商架构并提供统一接口：

```dart
class TTSService {
  Future<void> initialize();
  Future<String?> synthesizeToFile(String text, {TTSParams? params, String? fileName});
  Stream<Uint8List> streamSynthesize(String text, {TTSParams? params});
  Future<Uint8List?> synthesizeToMemory(String text, {TTSParams? params});
  Future<void> speak(String text, {TTSParams? params});
}
```

## 设计模式

### 策略模式 (Strategy Pattern)
所有供应商实现相同的抽象接口，允许运行时动态切换供应商：

```dart
// 创建GLM-TTS供应商
final glmProvider = ProviderFactory.getProviderByName('glm_tts', apiKey: 'your_key');
final audio1 = await glmProvider.synthesize('Hello World', {'voice': 'tongtong'});

// 切换为AIHUBMIX-TTS供应商
final aihubmixProvider = ProviderFactory.getProviderByName('aihubmix_tts', apiKey: 'your_key');
final audio2 = await aihubmixProvider.synthesize('Hello World', {'voice': 'alloy'});
```

### 工厂模式 (Factory Pattern)
通过工厂类统一管理供应商实例创建和缓存：

```dart
// 使用工厂创建供应商实例（支持缓存）
final provider = ProviderFactory.getProvider(
  TTSProvider.glmTTS,
  apiKey: 'your_api_key',
  kwargs: {'forceTrim': true},
);
```

### 模板方法模式 (Template Method Pattern)
`TTSProvider` 基类提供可重用的模板方法，如参数验证逻辑：

```dart
class GLMTTSProvider extends TTSProvider {
  @override
  Map<String, dynamic> validateParams(Map<String, dynamic>? kwargs) {
    final params = super.validateParams(kwargs);  // 调用父类验证
    _validateGLMParams(params);                   // 添加供应商特定验证
    return params;
  }
}
```

## 项目结构

```
lib/tts/
├── README.md                           # 本文档
├── audio/
│   └── audio_utils.dart               # 音频处理工具类
├── providers/
│   ├── tts_provider.dart              # TTSProvider抽象基类
│   ├── provider_config.dart           # 供应商配置和枚举
│   ├── provider_factory.dart          # 供应商工厂类
│   └── implementations/
│       ├── glm_tts_provider.dart      # GLM-TTS供应商实现
│       └── aihubmix_tts_provider.dart # AIHUBMIX-TTS供应商实现
└── services/
    └── tts_service.dart               # 新的TTS服务类
```

## 与现有TTSService的集成

### 迁移路径
1. **逐步替换**：可以同时使用新旧两个TTSService实现
2. **接口兼容**：新的TTSService提供了类似的方法签名
3. **向后兼容**：原有代码可以继续使用旧的flutter_tts实现

### 集成示例
```dart
// 创建新的TTS服务实例
final ttsService = TTSService(
  config: TTSConfig(
    defaultProvider: TTSProvider.glmTTS,
    defaultApiKey: 'your_api_key',
    defaultVoice: 'female',
    enableStreaming: true,
  ),
);

// 初始化服务
await ttsService.initialize();

// 合成语音并保存到文件
final filePath = await ttsService.synthesizeToFile(
  '你好，这是TTS测试',
  params: TTSParams(
    text: '你好，这是TTS测试',
    voice: 'tongtong',
    speed: 1.2,
    format: 'wav',
  ),
);

// 流式合成（实时播放）
final stream = ttsService.streamSynthesize(
  '流式语音合成示例',
  params: TTSParams(
    text: '流式语音合成示例',
    voice: 'female',
    format: 'pcm',  // 流式推荐使用PCM格式
  ),
);

// 播放语音
await ttsService.speak('直接播放这段文本');
```

## 配置管理

### 供应商默认参数
每个供应商都有特定的默认参数配置：

```dart
// GLM-TTS默认参数
{
  'voice': 'female',
  'speed': 1.0,
  'volume': 1.0,
  'format': 'wav',
  'streamFormat': 'pcm',
  'sampleRate': 24000,
}

// AIHUBMIX-TTS默认参数
{
  'voice': 'alloy',
  'speed': 1.0,
  'volume': 1.0,
  'format': 'mp3',
  'streamFormat': 'pcm',
  'sampleRate': 24000,
  'model': 'tts-1',
}
```

### 参数验证
系统提供统一的参数验证机制：

```dart
// 验证参数范围
TTSProviderConfig.validateParamRange(
  TTSProvider.glmTTS,
  'speed',
  1.5,  // 值必须在0.5-2.0范围内
);

// 验证音色是否支持
final supportedVoices = TTSProviderConfig.getSupportedVoices(TTSProvider.glmTTS);
// ['female', 'tongtong', 'xiaochen', 'chuichui', 'jam', 'kazi', 'douji', 'luodo']
```

## 流式处理架构

### 流式合成特点
1. **实时性**：边生成边传输，低延迟播放
2. **格式优化**：流式模式下强制使用PCM格式保证实时性
3. **数据对齐**：自动检查和修复PCM数据块对齐
4. **格式转换**：支持流式结束后转换为目标格式

### 流式处理流程
```
1. 参数验证 → 2. 强制PCM格式 → 3. API流式调用 → 
4. 数据块对齐 → 5. 实时传输 → 6. 格式转换（可选）
```

### 流式使用示例
```dart
// 创建流式合成
final stream = provider.streamSynthesize(
  '流式语音合成示例',
  {
    'voice': 'female',
    'format': 'wav',  // 流式传输PCM，最后转换为WAV
  },
);

// 实时处理音频流
await for (final chunk in stream) {
  // 播放或处理音频数据块
  audioPlayer.addChunk(chunk);
}
```

## 音频处理特性

### GLM-TTS音频修剪
GLM-TTS生成的音频包含约0.629秒的初始蜂鸣声，系统提供自动修剪功能：

```dart
// 非流式音频修剪
final trimmedAudio = AudioUtils.trimGlmAudio(
  rawAudio,
  sampleRate: 24000,
  force: false,  // 是否强制修剪
);

// 流式音频修剪包装器
final trimmedStream = AudioUtils.createStreamTrimmingWrapper(
  rawStream,
  sampleRate: 24000,
  bytesPerSample: 2,  // 16-bit PCM
);
```

### 音频格式转换
支持多种音频格式转换：

```dart
// PCM转WAV
final wavData = AudioUtils.pcmToWav(
  pcmData,
  sampleRate: 24000,
  bitsPerSample: 16,
  numChannels: 1,
);

// 通用格式转换
final convertedData = AudioUtils.convertAudioFormat(
  pcmData: pcmData,
  targetFormat: 'mp3',  // 支持: pcm, wav, mp3, flac
  sampleRate: 24000,
);
```

## 错误处理

### 异常类型
系统定义了几种特定的异常类型：

1. **TTSConfigError**：配置相关错误
2. **TTSProviderError**：供应商创建或调用错误
3. **UnsupportedError**：不支持的功能或格式

### 错误处理示例
```dart
try {
  final provider = ProviderFactory.getProviderByName('glm_tts', apiKey: apiKey);
  final audio = await provider.synthesize(text, params);
} on TTSProviderError catch (e) {
  print('供应商错误: ${e.message}');
  // 尝试备用供应商
  final fallbackProvider = ProviderFactory.getProviderByName('aihubmix_tts');
} on ArgumentError catch (e) {
  print('参数错误: $e');
  // 提示用户检查参数
} catch (e) {
  print('未知错误: $e');
  // 通用错误处理
}
```

## 性能优化

### 实例缓存
工厂类提供供应商实例缓存，避免重复初始化开销：

```dart
// 获取缓存的供应商实例
final cachedProvider = ProviderFactory.getCachedProvider(
  TTSProvider.glmTTS,
  apiKey: apiKey,
);

// 清除缓存
ProviderFactory.clearCache();
ProviderFactory.clearProviderCache(provider: TTSProvider.glmTTS);

// 获取缓存统计
final stats = ProviderFactory.getCacheStats();
```

### 流式处理优化
- **增量处理**：避免一次性加载所有音频数据
- **内存优化**：及时释放已处理的数据块
- **网络优化**：边生成边传输，减少等待时间

## 扩展新供应商

### 添加新供应商步骤
1. **扩展枚举**：在 `TTSProvider` 枚举中添加新供应商
2. **配置管理**：在 `TTSProviderConfig` 中添加默认参数和验证规则
3. **实现类**：创建新的供应商类继承 `TTSProvider`
4. **工厂集成**：在 `ProviderFactory._createProviderInstance` 中添加分支
5. **测试验证**：编写单元测试和集成测试

### 示例：添加新供应商
```dart
// 1. 扩展枚举
enum TTSProvider {
  glmTTS('glm_tts'),
  aihubmixTTS('aihubmix_tts'),
  newTTS('new_tts');  // 新增
  
  // ... 现有代码
}

// 2. 添加配置
static const Map<TTSProvider, Map<String, dynamic>> providerDefaultParams = {
  TTSProvider.glmTTS: {...},
  TTSProvider.aihubmixTTS: {...},
  TTSProvider.newTTS: {  // 新增配置
    'voice': 'default',
    'speed': 1.0,
    'format': 'mp3',
  },
};

// 3. 实现供应商类
class NewTTSProvider extends TTSProvider {
  @override
  String get name => TTSProvider.newTTS.value;
  
  @override
  Future<Uint8List> synthesize(String text, [Map<String, dynamic>? kwargs]) {
    // 实现具体逻辑
  }
  
  @override
  Stream<Uint8List> streamSynthesize(String text, [Map<String, dynamic>? kwargs]) {
    // 实现流式逻辑
  }
}

// 4. 集成到工厂
static TTSProvider _createProviderInstance(...) {
  switch (provider) {
    case TTSProvider.glmTTS: return _createGLMTTSProvider(apiKey, kwargs);
    case TTSProvider.aihubmixTTS: return _createAIHUBMIXTTSProvider(apiKey, kwargs);
    case TTSProvider.newTTS: return _createNewTTSProvider(apiKey, kwargs); // 新增
  }
}
```

## 依赖管理

### 必需依赖
在 `pubspec.yaml` 中添加以下依赖：

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # 音频处理（如果使用高级格式转换）
  just_audio: ^0.10.5  # 音频播放
  audio_session: ^0.1.15  # 音频会话管理
  
  # HTTP客户端（用于API调用）
  http: ^1.1.0  # 或者使用dio
  
  # OpenAI客户端（如果使用AIHUBMIX-TTS）
  openai_dart: ^1.0.0  # 可选，如果需要OpenAI官方SDK
```

### 可选依赖
- **音频格式转换**：需要集成 `audioplayers` 或 `soundfile` 等库进行MP3/FLAC转换
- **高级音频处理**：可以使用 `ffmpeg` 或 `audio_service` 进行复杂处理

## 使用示例

### 基本使用
```dart
import 'package:stroom/tts/providers/provider_factory.dart';
import 'package:stroom/tts/services/tts_service.dart';

void main() async {
  // 方式1：直接使用供应商
  final glmProvider = ProviderFactory.getProviderByName(
    'glm_tts',
    apiKey: 'your_glm_api_key',
  );
  
  final audioData = await glmProvider.synthesize(
    '你好，世界！',
    {'voice': 'tongtong', 'speed': 1.2},
  );
  
  // 方式2：使用TTS服务
  final ttsService = TTSService();
  await ttsService.initialize();
  
  final filePath = await ttsService.synthesizeToFile(
    '语音合成测试',
    params: TTSParams(
      text: '语音合成测试',
      provider: TTSProvider.glmTTS,
      voice: 'female',
      format: 'wav',
    ),
  );
  
  print('音频文件已保存: $filePath');
}
```

### 供应商切换示例
```dart
class TTSManager {
  TTSProvider? _currentProvider;
  
  Future<void> switchProvider(String providerName, {String? apiKey}) async {
    _currentProvider = ProviderFactory.getProviderByName(
      providerName,
      apiKey: apiKey,
    );
    
    print('已切换供应商: $providerName');
  }
  
  Future<Uint8List> synthesizeWithCurrent(String text, Map<String, dynamic> params) async {
    if (_currentProvider == null) {
      throw StateError('请先选择供应商');
    }
    
    return await _currentProvider!.synthesize(text, params);
  }
}
```

### 流式处理示例
```dart
// 流式合成和播放
void streamAndPlay(String text) async {
  final provider = ProviderFactory.getProviderByName('glm_tts');
  
  final stream = provider.streamSynthesize(
    text,
    {'voice': 'female', 'format': 'pcm'},
  );
  
  final audioPlayer = AudioPlayer();  // 假设有音频播放器
  
  await for (final chunk in stream) {
    // 实时播放音频块
    audioPlayer.addChunk(chunk);
  }
}
```

## 注意事项

### 1. API密钥安全
- 不要将API密钥硬编码在代码中
- 使用环境变量或安全的配置管理
- 考虑使用后端代理中转API请求

### 2. 网络连接
- 处理网络中断和重连
- 设置合理的超时时间
- 提供离线后备方案

### 3. 资源管理
- 及时释放音频资源
- 管理供应商实例缓存
- 监控内存使用情况

### 4. 平台兼容性
- 测试不同平台（Android, iOS, Web）的兼容性
- 处理平台特定的音频格式限制
- 考虑不同平台的网络环境

## 故障排除

### 常见问题

1. **供应商初始化失败**
   - 检查API密钥是否正确
   - 验证网络连接
   - 确认依赖库是否已正确安装

2. **音频播放问题**
   - 检查音频格式是否受平台支持
   - 验证采样率和位深度
   - 确认音频数据是否完整

3. **流式处理中断**
   - 检查网络稳定性
   - 验证流式API兼容性
   - 调整数据块大小和缓冲区

### 调试建议
- 启用详细日志记录
- 使用性能监控工具
- 编写单元测试和集成测试

## 总结

本TTS供应商架构提供了一套完整、可扩展的语音合成解决方案，具有以下优势：

1. **灵活性**：支持多供应商动态切换
2. **可扩展性**：易于添加新的供应商
3. **性能优化**：实例缓存和流式处理优化
4. **健壮性**：完善的错误处理和参数验证
5. **标准化**：统一的接口和配置管理

通过采用策略模式和工厂模式，系统实现了高内聚、低耦合的架构设计，为Flutter应用提供了强大的TTS功能支持。

## 后续开发计划

1. **更多供应商支持**：集成更多TTS服务提供商
2. **高级音频处理**：添加更多音频效果和处理功能
3. **离线支持**：集成本地TTS引擎
4. **性能优化**：进一步优化流式处理和内存使用
5. **UI组件**：提供预构建的TTS UI组件

---

*文档版本：1.0.0*
*最后更新：2024年*
*对应代码版本：TTS供应商架构 v1.0*