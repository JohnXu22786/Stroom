# 音频修剪逻辑文档

## 概述

音频修剪是GLM-TTS供应商特有的处理逻辑，主要用于移除GLM-TTS API生成的音频文件开头的蜂鸣声。GLM-TTS在音频开头会插入约0.629秒的提示音（beep sound），这在某些应用场景中是不需要的。音频修剪模块提供了自动检测和移除这些初始蜂鸣声的功能。

## 设计原理

### 1. 修剪时机
- **固定时间点**: 0.629333秒（629.333毫秒）
- **采样率依赖**: 根据音频的实际采样率计算需要修剪的样本数
- **自动检测**: 先检测是否为GLM-TTS音频，再决定是否修剪

### 2. 核心常量
```python
# 固定修剪点（单位：秒）
GLM_CUT_POINT = 0.629333  # 629.333毫秒

# 默认采样率
DEFAULT_SAMPLE_RATE = 24000  # GLM-TTS默认采样率
```

## 主要函数

### 1. 音频检测函数
```python
def is_glm_audio(audio_bytes: bytes, sample_rate: int = DEFAULT_SAMPLE_RATE) -> bool:
    """
    检测音频是否来自GLM-TTS（通过分析开头是否有蜂鸣声）
    
    Args:
        audio_bytes: 音频数据字节
        sample_rate: 采样率，默认24000Hz
    
    Returns:
        bool: 是否为GLM-TTS音频
    """
```

**检测原理:**
1. 分析音频前1秒的能量变化
2. GLM-TTS蜂鸣声通常具有脉冲特性
3. 计算能量方差，超过阈值则认为是GLM-TTS音频

### 2. 非流式修剪函数
```python
def trim_glm_audio(
    audio_bytes: bytes, 
    sample_rate: int = DEFAULT_SAMPLE_RATE, 
    force: bool = False
) -> bytes:
    """
    从GLM-TTS音频中修剪前0.629333秒
    
    Args:
        audio_bytes: 音频数据字节
        sample_rate: 采样率，默认24000Hz
        force: 如果为True，无论检测结果如何都强制修剪
    
    Returns:
        bytes: 修剪后的音频数据
    """
```

**处理流程:**
1. 可选：检测是否为GLM-TTS音频（除非force=True）
2. 转换字节数据为numpy数组
3. 计算修剪样本数：`cut_samples = int(GLM_CUT_POINT * actual_sr)`
4. 移除前cut_samples个样本
5. 转换回字节数据，保持原格式（WAV或PCM）

### 3. 流式修剪包装器
```python
def create_stream_trimming_wrapper(
    stream_chunks, 
    sample_rate: int = DEFAULT_SAMPLE_RATE, 
    bytes_per_sample: int = 2
):
    """
    创建包装流并修剪初始GLM-TTS蜂鸣声的生成器
    
    Args:
        stream_chunks: 音频数据块迭代器
        sample_rate: 采样率
        bytes_per_sample: 每个样本的字节数（16位PCM为2）
    
    Yields:
        bytes: 修剪后的音频数据块
    """
```

**流式修剪特点:**
- **增量处理**: 边接收数据边处理，不等待完整音频
- **缓冲区管理**: 累积数据直到达到修剪阈值
- **实时性**: 修剪完成后立即开始输出有效音频数据

## 实现细节

### 1. 音频格式支持
```python
def bytes_to_audio(audio_bytes: bytes, sample_rate: int = DEFAULT_SAMPLE_RATE) -> Tuple[np.ndarray, int]:
    """
    转换音频字节为numpy数组
    
    支持格式:
    - WAV格式（自动检测RIFF或FORM头部）
    - 原始PCM（16位，单声道）
    """
```

**格式检测逻辑:**
1. 检查前4字节是否为"RIFF"或"FORM"（WAV格式）
2. 如果是WAV，使用librosa加载并获取实际采样率
3. 否则，假设为16位PCM，按指定采样率处理

### 2. 修剪计算
```python
# 计算需要修剪的字节数
samples_to_discard = int(GLM_CUT_POINT * sample_rate)
bytes_to_discard = samples_to_discard * bytes_per_sample  # bytes_per_sample=2（16位）
```

### 3. 流式包装器实现
```python
def create_stream_trimming_wrapper(stream_chunks, sample_rate, bytes_per_sample):
    buffer = b""
    bytes_discarded = 0
    trimming_done = False
    
    for chunk in stream_chunks:
        if not trimming_done:
            # 累积数据直到达到修剪阈值
            buffer += chunk
            if len(buffer) > bytes_to_discard:
                # 丢弃初始字节
                buffer = buffer[bytes_to_discard:]
                trimming_done = True
                if buffer:
                    yield buffer
                    buffer = b""
        else:
            # 修剪已完成，直接输出后续数据块
            yield chunk
```

## 在供应商中的集成

### GLMTTSProvider集成
```python
# 非流式合成中的修剪
def synthesize(self, text: str, **kwargs) -> bytes:
    # ... API调用获取音频数据
    if (_audio_trim_available and self.needs_trimming and result 
        and isinstance(result, bytes) and trim_glm_audio is not None):
        try:
            sample_rate = params.get("sample_rate", 24000)
            audio_bytes = trim_glm_audio(
                result, sample_rate=sample_rate, force=self.force_trim
            )
            result = audio_bytes
        except Exception as e:
            logger.warning(f"Failed to trim GLM-TTS audio: {e}")
```

### 流式合成中的集成
```python
def stream_synthesize(self, text: str, **kwargs) -> Iterator[bytes]:
    # ... 获取原始流式迭代器
    if (self.needs_trimming and _audio_trim_available 
        and create_stream_trimming_wrapper is not None):
        audio_stream = create_stream_trimming_wrapper(
            audio_stream,
            sample_rate=sample_rate,
            bytes_per_sample=2,  # 16-bit PCM
        )
```

## 配置参数

### 强制修剪选项
```python
# 创建供应商时指定force_trim参数
glm_provider = get_provider("glm_tts", api_key="xxx", force_trim=True)
```

**force_trim参数行为:**
- `force=True`: 无论检测结果如何都进行修剪
- `force=False`（默认）: 仅当检测到GLM-TTS音频时才修剪

### 采样率配置
```python
# 通过合成参数指定采样率
audio = provider.synthesize(text, sample_rate=16000)
```

## 错误处理

### 1. 依赖缺失
```python
try:
    from .audio_trim import trim_glm_audio, create_stream_trimming_wrapper
    _audio_trim_available = True
except ImportError:
    _audio_trim_available = False
    warnings.warn("Audio trimming module not available.")
```

### 2. 修剪失败
```python
try:
    audio_bytes = trim_glm_audio(result, sample_rate=sample_rate, force=self.force_trim)
    result = audio_bytes
except Exception as e:
    logger.warning(f"Failed to trim GLM-TTS audio: {e}, returning original audio")
```

### 3. 流式修剪异常
```python
except Exception as e:
    logger.error(f"Stream trimming failed: {e}")
    # 回退到未修剪的流
    for chunk in original_stream:
        yield chunk
```

## 性能考虑

### 1. 内存使用
- 非流式修剪：需要完整音频数据在内存中
- 流式修剪：仅缓冲到修剪阈值的数据（约15KB）

### 2. 计算开销
- 音频检测：分析前1秒音频，O(n)复杂度
- 修剪操作：简单的数组切片，O(n)复杂度

### 3. 延迟影响
- 非流式：增加约0.6秒处理时间
- 流式：初始延迟约0.6秒，之后实时

## 测试方法

### 1. 单元测试
```python
def test_trim_glm_audio():
    # 创建测试音频（1秒静音）
    sample_rate = 24000
    duration = 2.0
    audio_array = np.zeros(int(sample_rate * duration), dtype=np.float32)
    audio_bytes = audio_to_bytes(audio_array, sample_rate, "pcm")
    
    # 测试修剪
    trimmed = trim_glm_audio(audio_bytes, sample_rate, force=True)
    
    # 验证修剪结果
    expected_samples = int((duration - GLM_CUT_POINT) * sample_rate)
    assert len(trimmed) == expected_samples * 2  # 16位PCM
```

### 2. 集成测试
```python
def test_provider_with_trimming():
    provider = GLMTTSProvider(api_key="test", force_trim=True)
    audio = provider.synthesize("测试文本", sample_rate=24000)
    
    # 验证音频已被修剪
    audio_array, sr = bytes_to_audio(audio, 24000)
    expected_duration = (len(audio_array) / sr) + GLM_CUT_POINT
    # 应该有原始音频长度加上修剪时长的提示
```

## 与其他供应商的差异

| 特性 | GLM-TTS | AIHUBMIX-TTS | 说明 |
|------|---------|--------------|------|
| **音频修剪** | 需要修剪初始蜂鸣声 | 不需要修剪 | GLM-TTS特有需求 |
| **修剪时机** | 固定0.629秒 | 无 | 基于实测的蜂鸣声时长 |
| **流式支持** | 有流式修剪包装器 | 无 | 实时流也需要修剪 |
| **检测逻辑** | 自动检测GLM音频 | 无 | 避免误修剪非GLM音频 |

## 使用示例

### 1. 直接使用修剪模块
```python
from src.audio_trim import trim_glm_audio, is_glm_audio

# 读取音频文件
with open("audio.wav", "rb") as f:
    audio_bytes = f.read()

# 检测是否为GLM-TTS音频
if is_glm_audio(audio_bytes, sample_rate=24000):
    # 修剪音频
    trimmed_bytes = trim_glm_audio(audio_bytes, sample_rate=24000)
    
    # 保存修剪后的音频
    with open("audio_trimmed.wav", "wb") as f:
        f.write(trimmed_bytes)
```

### 2. 在供应商中使用
```python
from src.providers import get_provider

# 创建带修剪的供应商
provider = get_provider("glm_tts", api_key="your_key", force_trim=True)

# 合成语音（自动修剪）
audio = provider.synthesize(
    "需要修剪的GLM-TTS音频",
    voice="tongtong",
    sample_rate=24000
)

# 流式合成（自动流式修剪）
stream = provider.stream_synthesize(
    "流式音频也需要修剪",
    format="wav"
)
```

### 3. 自定义修剪参数
```python
# 自定义采样率
audio = provider.synthesize("文本", sample_rate=16000)

# 强制修剪（即使不是GLM音频）
audio = trim_glm_audio(some_audio_bytes, sample_rate=24000, force=True)
```

## 注意事项

### 1. 采样率匹配
- 确保修剪时使用的采样率与实际音频采样率一致
- WAV文件会自动检测采样率，PCM数据需要明确指定

### 2. 格式保持
- 修剪后保持原始音频格式（WAV保持WAV，PCM保持PCM）
- 自动处理格式特定的头部信息

### 3. 边界情况
- 音频长度小于修剪时长：跳过修剪，返回原始音频
- 数据不对齐：自动填充确保2字节对齐（16位PCM）

### 4. 依赖要求
- 必需：numpy
- 推荐：librosa, soundfile（用于WAV格式支持）
- 可选：pydub（用于高级音频处理）

## 扩展性

### 1. 添加新供应商的修剪逻辑
```python
class NewTTSAudioTrimmer:
    """新供应商的音频修剪器"""
    
    def trim_audio(self, audio_bytes: bytes, **kwargs) -> bytes:
        # 实现特定供应商的修剪逻辑
        pass
    
    def create_stream_trimmer(self, stream_chunks, **kwargs):
        # 实现流式修剪逻辑
        pass
```

### 2. 自定义修剪点
```python
# 扩展支持自定义修剪点
def trim_audio_with_custom_point(
    audio_bytes: bytes, 
    cut_point: float,  # 自定义修剪点（秒）
    sample_rate: int,
    **kwargs
) -> bytes:
    cut_samples = int(cut_point * sample_rate)
    # ... 实现修剪逻辑
```

### 3. 高级音频处理
```python
# 结合其他音频处理功能
def advanced_audio_processing(audio_bytes: bytes, **kwargs) -> bytes:
    # 1. 修剪初始噪音
    trimmed = trim_glm_audio(audio_bytes, **kwargs)
    
    # 2. 应用音频效果
    processed = apply_audio_effects(trimmed, **kwargs)
    
    # 3. 标准化音量
    normalized = normalize_volume(processed, **kwargs)
    
    return normalized
```

## 总结

音频修剪模块是GLM-TTS供应商的关键组件，专门处理GLM-TTS API特有的初始蜂鸣声问题。该模块提供了：

1. **自动检测**: 智能识别GLM-TTS音频，避免误修剪
2. **双模式支持**: 完整的非流式和流式修剪支持
3. **格式兼容**: 支持WAV和原始PCM格式
4. **健壮性**: 全面的错误处理和边界情况处理
5. **性能优化**: 最小化的内存和计算开销

通过该模块，GLM-TTS供应商可以提供与其他供应商一致的音频质量体验，消除特定API的特性差异，确保最终用户获得无蜂鸣声的高质量语音输出。