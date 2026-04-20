# TTS服务迁移指南

## 概述

本迁移指南旨在帮助您从原有的基于`flutter_tts`的TTSService迁移到新的基于供应商架构的TTSService。新的架构提供了更强大的功能、更好的可扩展性和多供应商支持。

### 迁移的好处

1. **多供应商支持**：支持GLM-TTS、AIHUBMIX-TTS等多个TTS供应商，可动态切换
2. **统一抽象接口**：所有供应商提供一致的API，便于代码维护
3. **流式处理支持**：提供实时音频流传输，支持低延迟播放
4. **音频处理功能**：内置音频格式转换、修剪、数据对齐等功能
5. **配置管理**：统一的参数验证和配置管理系统
6. **性能优化**：实例缓存机制减少重复初始化开销

### 兼容性说明

新架构设计为向后兼容，您可以选择：
1. **渐进式迁移**：逐步替换旧代码，新旧实现可以共存
2. **一次性迁移**：完全替换旧的TTSService
3. **混合使用**：根据需求同时使用新旧两种实现

## 架构差异

### 旧架构 (lib/services/tts_service.dart)
```dart
class TTSService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  
  Future<void> initialize();
  Future<String?> synthesizeToFile(String text, {String? fileName});
  Future<void> speak(String text);
  Future<void> stop();
  // ... 其他flutter_tts包装方法
}
```

**特点**：
- 基于`flutter_tts`包的简单包装
- 仅支持设备本地TTS引擎
- 功能有限，无流式处理支持
- 无多供应商支持

### 新架构 (lib/tts/services/tts_service.dart)
```dart
class TTSService {
  final TTSConfig _config;
  TTSProvider? _currentProvider;
  
  Future<void> initialize();
  Future<String?> synthesizeToFile(String text, {TTSParams? params, String? fileName});
  Stream<Uint8List> streamSynthesize(String text, {TTSParams? params});
  Future<Uint8List?> synthesizeToMemory(String text, {TTSParams? params});
  Future<void> speak(String text, {TTSParams? params});
  Future<void> switchProvider(TTSProvider provider, {String? apiKey, Map<String, dynamic>? kwargs});
  // ... 丰富的配置和管理功能
}
```

**特点**：
- 基于策略模式和工厂模式的供应商架构
- 支持多个云端TTS供应商
- 完整的流式处理支持
- 丰富的音频处理功能
- 统一的配置和参数管理

## 迁移步骤

### 步骤1：添加依赖（如需）

新架构可能需要额外的依赖，检查`pubspec.yaml`：

```yaml
dependencies:
  # 如果使用HTTP API调用
  http: ^1.1.0
  
  # 如果使用高级音频格式转换
  just_audio: ^0.10.5
  audio_session: ^0.1.15
```

### 步骤2：导入新TTS服务

更新导入语句：

```dart
// 旧导入
import 'package:stroom/services/tts_service.dart';

// 新导入
import 'package:stroom/tts/services/tts_service.dart';
import 'package:stroom/tts/providers/provider_config.dart';
```

### 步骤3：更新TTS服务实例化

```dart
// 旧方式
final ttsService = TTSService();

// 新方式
final ttsService = TTSService(
  config: TTSConfig(
    defaultProvider: TTSProvider.glmTTS,
    defaultApiKey: 'your_api_key', // 可选
    defaultVoice: 'female',
    enableStreaming: true,
  ),
);
```

### 步骤4：初始化TTS服务

```dart
// 旧方式
await ttsService.initialize();

// 新方式 - 初始化可能需要API密钥验证
try {
  await ttsService.initialize();
  print('TTS服务初始化成功');
} catch (e) {
  print('TTS服务初始化失败: $e');
  // 可以考虑使用后备供应商或本地TTS
}
```

### 步骤5：更新方法调用

#### 5.1 合成语音并保存到文件

```dart
// 旧方式
final filePath = await ttsService.synthesizeToFile('你好，世界！');

// 新方式 - 基础用法（使用默认配置）
final filePath = await ttsService.synthesizeToFile('你好，世界！');

// 新方式 - 高级用法（自定义参数）
final filePath = await ttsService.synthesizeToFile(
  '你好，世界！',
  params: TTSParams(
    text: '你好，世界！',
    provider: TTSProvider.glmTTS,
    voice: 'tongtong',
    speed: 1.2,
    format: 'wav',
    apiKey: 'your_glm_api_key',
  ),
  fileName: 'custom_filename',
);
```

#### 5.2 播放语音

```dart
// 旧方式
await ttsService.speak('直接播放这段文本');

// 新方式
await ttsService.speak(
  '直接播放这段文本',
  params: TTSParams(
    text: '直接播放这段文本',
    voice: 'female',
    speed: 1.0,
  ),
);
```

### 步骤6：处理供应商切换

新架构支持动态供应商切换：

```dart
// 切换到GLM-TTS
await ttsService.switchProvider(
  TTSProvider.glmTTS,
  apiKey: 'your_glm_api_key',
  kwargs: {'forceTrim': true},
);

// 切换到AIHUBMIX-TTS
await ttsService.switchProvider(
  TTSProvider.aihubmixTTS,
  apiKey: 'your_aihubmix_api_key',
  kwargs: {'model': 'tts-1-hd'},
);
```

### 步骤7：利用新功能

#### 流式合成
```dart
// 获取音频流
final stream = ttsService.streamSynthesize(
  '流式语音合成示例',
  params: TTSParams(
    text: '流式语音合成示例',
    voice: 'female',
    format: 'pcm', // 流式推荐使用PCM格式
  ),
);

// 实时处理音频流
await for (final chunk in stream) {
  // 播放或处理音频数据块
  audioPlayer.addChunk(chunk);
}
```

#### 合成到内存
```dart
// 获取音频数据（不保存文件）
final audioData = await ttsService.synthesizeToMemory(
  '保存到内存的文本',
  params: TTSParams(
    text: '保存到内存的文本',
    format: 'wav',
  ),
);

// 直接使用音频数据
if (audioData != null) {
  audioPlayer.playBytes(audioData);
}
```

## API变化对比

### 方法签名变化

| 方法 | 旧签名 | 新签名 | 说明 |
|------|--------|--------|------|
| `initialize()` | `Future<void> initialize()` | `Future<void> initialize()` | 签名相同，但实现不同 |
| `synthesizeToFile()` | `Future<String?> synthesizeToFile(String text, {String? fileName})` | `Future<String?> synthesizeToFile(String text, {TTSParams? params, String? fileName})` | 新增`params`参数 |
| `speak()` | `Future<void> speak(String text)` | `Future<void> speak(String text, {TTSParams? params})` | 新增`params`参数 |
| `stop()` | `Future<void> stop()` | `void stop()` | 改为同步方法 |
| `dispose()` | `void dispose()` | `void dispose()` | 方法相同 |

### 新增方法

| 方法 | 说明 |
|------|------|
| `streamSynthesize()` | 流式合成语音，返回音频数据流 |
| `synthesizeToMemory()` | 合成语音并返回音频数据（不保存文件） |
| `switchProvider()` | 动态切换TTS供应商 |
| `getSupportedProviders()` | 获取支持的供应商列表 |
| `getSupportedVoices()` | 获取供应商支持的音色列表 |
| `getSupportedFormats()` | 获取支持的音频格式列表 |
| `clearCache()` | 清除供应商实例缓存 |

### 移除的方法

旧TTSService中的以下方法在新架构中已移除或替换：

| 移除的方法 | 替代方案 | 说明 |
|------------|----------|------|
| `getAvailableVoices()` | `getSupportedVoices()` | 使用新方法获取音色列表 |
| `getAvailableLanguages()` | 通过`params`设置语言 | 语言通常由音色决定 |
| `setLanguage()` | 通过`TTSParams`设置 | 语言参数在合成时指定 |
| `setSpeechRate()` | 通过`TTSParams`设置 | 语速参数在合成时指定 |
| `setPitch()` | 通过`TTSParams`设置 | 音调参数在合成时指定（某些供应商可能不支持） |
| `setVolume()` | 通过`TTSParams`设置 | 音量参数在合成时指定 |

## 完整迁移示例

### 迁移前代码

```dart
import 'package:flutter/material.dart';
import 'package:stroom/services/tts_service.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({super.key});

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  final TTSService _ttsService = TTSService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeTTS();
  }

  Future<void> _initializeTTS() async {
    try {
      await _ttsService.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('TTS初始化失败: $e');
    }
  }

  Future<void> _synthesizeText(String text) async {
    if (!_isInitialized) return;
    
    final filePath = await _ttsService.synthesizeToFile(text);
    if (filePath != null) {
      print('音频文件已保存: $filePath');
    }
  }

  Future<void> _speakText(String text) async {
    if (!_isInitialized) return;
    await _ttsService.speak(text);
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('音频页面')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _synthesizeText('这是测试文本'),
              child: const Text('合成语音'),
            ),
            ElevatedButton(
              onPressed: () => _speakText('直接播放文本'),
              child: const Text('播放语音'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 迁移后代码

```dart
import 'package:flutter/material.dart';
import 'package:stroom/tts/services/tts_service.dart';
import 'package:stroom/tts/providers/provider_config.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({super.key});

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  late TTSService _ttsService;
  bool _isInitialized = false;
  String? _currentProvider;
  List<String> _availableVoices = [];

  @override
  void initState() {
    super.initState();
    _initializeTTS();
  }

  Future<void> _initializeTTS() async {
    try {
      // 创建新的TTS服务实例
      _ttsService = TTSService(
        config: TTSConfig(
          defaultProvider: TTSProvider.glmTTS,
          defaultVoice: 'female',
          enableStreaming: true,
        ),
      );
      
      await _ttsService.initialize();
      
      // 获取当前供应商和支持的音色
      _currentProvider = _ttsService.currentProvider?.name;
      _availableVoices = _ttsService.getSupportedVoices();
      
      setState(() {
        _isInitialized = true;
      });
      
      print('TTS服务初始化成功，当前供应商: $_currentProvider');
    } catch (e) {
      print('TTS服务初始化失败: $e');
      // 可以添加后备方案，如使用本地TTS
    }
  }

  Future<void> _synthesizeText(String text) async {
    if (!_isInitialized) return;
    
    try {
      final filePath = await _ttsService.synthesizeToFile(
        text,
        params: TTSParams(
          text: text,
          voice: 'tongtong', // 使用特定音色
          speed: 1.2,
          format: 'wav',
        ),
      );
      
      if (filePath != null) {
        print('音频文件已保存: $filePath');
        // 可以在这里更新UI或通知用户
      }
    } catch (e) {
      print('语音合成失败: $e');
      // 可以在这里添加错误处理，如切换到备用供应商
    }
  }

  Future<void> _speakText(String text) async {
    if (!_isInitialized) return;
    
    try {
      await _ttsService.speak(
        text,
        params: TTSParams(
          text: text,
          voice: 'female',
          speed: 1.0,
        ),
      );
    } catch (e) {
      print('语音播放失败: $e');
    }
  }

  Future<void> _switchToAIHUBMIX() async {
    try {
      await _ttsService.switchProvider(
        TTSProvider.aihubmixTTS,
        apiKey: 'your_aihubmix_api_key',
      );
      
      setState(() {
        _currentProvider = 'aihubmix_tts';
        _availableVoices = _ttsService.getSupportedVoices();
      });
      
      print('已切换到AIHUBMIX-TTS');
    } catch (e) {
      print('切换供应商失败: $e');
    }
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('音频页面')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isInitialized) ...[
              Text('当前供应商: $_currentProvider'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _synthesizeText('这是新架构的测试文本'),
                child: const Text('合成语音'),
              ),
              ElevatedButton(
                onPressed: () => _speakText('直接播放文本'),
                child: const Text('播放语音'),
              ),
              ElevatedButton(
                onPressed: _switchToAIHUBMIX,
                child: const Text('切换到AIHUBMIX'),
              ),
              if (_availableVoices.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('可用音色:'),
                ..._availableVoices.take(3).map((voice) => Text(voice)),
              ],
            ] else
              const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
```

## 与现有项目的集成

### 与AudioProvider集成

新的TTSService可以与现有的`AudioProvider`（位于`lib/providers/audio_provider.dart`）配合使用：

```dart
class AudioPageWithProvider extends ConsumerWidget {
  const AudioPageWithProvider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioProvider);
    
    return Scaffold(
      appBar: AppBar(title: const Text('音频页面')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                // 使用新的TTSService
                final ttsService = TTSService();
                await ttsService.initialize();
                
                // 合成语音
                final filePath = await ttsService.synthesizeToFile(
                  '使用新TTS服务合成的文本',
                );
                
                if (filePath != null) {
                  // 通过AudioProvider添加录音
                  ref.read(audioProvider.notifier).addRecording(
                    text: '使用新TTS服务合成的文本',
                    filePath: filePath,
                    duration: 5, // 实际时长需要计算
                    language: 'zh-CN',
                  );
                }
                
                ttsService.dispose();
              },
              child: const Text('使用新TTS服务合成'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 逐步迁移策略

如果您不想一次性迁移所有代码，可以采用以下策略：

1. **并行使用**：在代码中同时保留新旧两个TTSService实例
2. **功能逐步迁移**：先迁移合成功能，再迁移播放功能
3. **条件使用**：根据网络状况或用户选择使用不同的TTS服务

```dart
class HybridTTSService {
  final TTSService _newTtsService;
  final OldTTSService _oldTtsService;
  bool _useNewService = true;
  
  Future<String?> synthesizeToFile(String text, {String? fileName}) async {
    if (_useNewService) {
      try {
        return await _newTtsService.synthesizeToFile(text);
      } catch (e) {
        // 新服务失败，回退到旧服务
        print('新TTS服务失败，使用旧服务: $e');
        return await _oldTtsService.synthesizeToFile(text, fileName: fileName);
      }
    } else {
      return await _oldTtsService.synthesizeToFile(text, fileName: fileName);
    }
  }
  
  // 其他方法类似...
}
```

## 配置管理

### API密钥管理

新的架构需要API密钥来访问TTS供应商服务。建议：

1. **环境变量**：在开发环境中使用环境变量
2. **配置文件**：在生产环境中使用加密的配置文件
3. **用户输入**：允许用户输入自己的API密钥

```dart
// 从环境变量获取API密钥
final apiKey = const String.fromEnvironment('GLM_TTS_API_KEY');

// 或从配置文件读取
final apiKey = await _loadApiKeyFromConfig();

// 创建TTS服务
final ttsService = TTSService(
  config: TTSConfig(
    defaultProvider: TTSProvider.glmTTS,
    defaultApiKey: apiKey,
  ),
);
```

### 参数配置

新架构提供了丰富的参数配置选项：

```dart
final config = TTSConfig(
  defaultProvider: TTSProvider.glmTTS,
  defaultApiKey: 'your_api_key',
  defaultVoice: 'female',
  defaultSpeed: 1.0,
  defaultVolume: 1.0,
  defaultFormat: 'wav',
  defaultSampleRate: 24000,
  enableStreaming: true,
  enableCache: true,
  audioSaveDirectory: 'tts_audio',
);

final ttsService = TTSService(config: config);
```

## 注意事项

### 1. 网络依赖
新架构依赖网络连接来访问TTS供应商API，需要：
- 处理网络连接中断
- 提供适当的用户反馈
- 考虑离线后备方案

### 2. API限制
不同的TTS供应商可能有不同的API限制：
- 请求频率限制
- 文本长度限制
- 并发请求限制
- 每日使用配额

### 3. 音频格式兼容性
确保目标平台支持所使用的音频格式：
- **Android/iOS**：支持WAV、MP3、PCM
- **Web**：可能需要特定格式，注意浏览器兼容性

### 4. 性能考虑
- 大文本合成可能需要较长时间
- 流式处理需要稳定的网络连接
- 音频文件可能占用较多存储空间

### 5. 错误处理
新架构可能抛出更多类型的异常，需要完善错误处理：

```dart
try {
  final audio = await ttsService.synthesizeToMemory(text);
} on TTSProviderError catch (e) {
  // 供应商特定错误
  showErrorMessage('TTS服务错误: ${e.message}');
} on ArgumentError catch (e) {
  // 参数错误
  showErrorMessage('参数错误: $e');
} on SocketException catch (e) {
  // 网络错误
  showErrorMessage('网络连接失败，请检查网络设置');
} catch (e) {
  // 其他错误
  showErrorMessage('未知错误: $e');
}
```

## 故障排除

### 常见问题及解决方案

#### 1. TTS服务初始化失败
**问题**：`initialize()`方法抛出异常
**可能原因**：
- API密钥无效或过期
- 网络连接问题
- 供应商服务不可用
**解决方案**：
- 验证API密钥是否正确
- 检查网络连接
- 尝试使用不同的供应商

#### 2. 音频合成失败
**问题**：`synthesizeToFile()`返回`null`
**可能原因**：
- 文本过长或包含特殊字符
- 参数超出范围
- 供应商API限制
**解决方案**：
- 检查文本长度和内容
- 验证参数是否在有效范围内
- 查看供应商API文档了解限制

#### 3. 流式处理中断
**问题**：流式合成中途断开
**可能原因**：
- 网络不稳定
- 服务器端中断
- 客户端缓冲区溢出
**解决方案**：
- 检查网络稳定性
- 实现重连逻辑
- 调整缓冲区大小

#### 4. 音频播放问题
**问题**：合成的音频无法播放
**可能原因**：
- 音频格式不受支持
- 音频数据损坏
- 播放器兼容性问题
**解决方案**：
- 尝试不同的音频格式
- 检查音频数据完整性
- 使用兼容的音频播放器

### 调试建议

1. **启用详细日志**：
```dart
// 在开发环境中启用详细日志
final ttsService = TTSService(
  config: TTSConfig(
    // ... 其他配置
    enableDebugLogging: true, // 如果支持此选项
  ),
);
```

2. **监控性能**：
```dart
final startTime = DateTime.now();
final result = await ttsService.synthesizeToMemory(text);
final duration = DateTime.now().difference(startTime);
print('合成耗时: ${duration.inMilliseconds}ms, 音频大小: ${result?.length ?? 0}字节');
```

3. **测试不同供应商**：
```dart
// 测试所有可用供应商
for (final provider in ttsService.getSupportedProviders()) {
  try {
    await ttsService.switchProvider(provider);
    final audio = await ttsService.synthesizeToMemory('测试文本');
    print('$provider 测试成功，音频大小: ${audio?.length ?? 0}字节');
  } catch (e) {
    print('$provider 测试失败: $e');
  }
}
```

## 迁移检查清单

完成迁移前，请检查以下项目：

- [ ] 更新了导入语句
- [ ] 更新了TTS服务实例化代码
- [ ] 更新了初始化逻辑
- [ ] 更新了方法调用，添加了必要的参数
- [ ] 处理了新的异常类型
- [ ] 测试了基本功能（合成、播放）
- [ ] 测试了供应商切换功能
- [ ] 测试了流式处理功能（如需要）
- [ ] 验证了音频文件保存和播放
- [ ] 更新了相关文档和注释
- [ ] 通知了团队成员架构变化

## 支持与反馈

如果在迁移过程中遇到问题：

1. **查看文档**：参考`lib/tts/README.md`中的详细文档
2. **检查示例**：查看示例代码和测试用例
3. **查阅源码**：直接查看供应商实现了解详细逻辑
4. **提交问题**：在项目仓库中提交issue

## 总结

迁移到新的TTS供应商架构虽然需要一些工作，但带来了显著的优势：

1. **功能增强**：多供应商支持、流式处理、音频处理等
2. **可扩展性**：易于添加新的供应商和功能
3. **维护性**：统一的接口和配置管理
4. **性能优化**：实例缓存、流式优化等

建议采用渐进式迁移策略，先在小范围内测试，再逐步推广到整个应用。确保在迁移过程中保持功能的可用性，并提供适当的用户反馈。

---
*迁移指南版本：1.0.0*
*最后更新：2024年*
*对应TTS架构版本：v1.0*