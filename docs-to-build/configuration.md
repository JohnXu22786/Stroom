# TTS配置系统文档

## 概述

TTS配置系统提供了一套完整的供应商参数管理机制，支持多供应商、多模型的灵活配置。该系统采用集中式配置管理，通过统一的接口提供供应商特定的参数、验证规则和默认值，确保代码的一致性和可维护性。

## 核心组件

### 1. 供应商枚举 (Provider Enum)

```python
from enum import Enum

class Provider(str, Enum):
    """TTS供应商枚举"""
    GLM_TTS = "glm_tts"
    AIHUBMIX_TTS = "aihubmix_tts"
    # 未来可扩展其他供应商:
    # OPENAI_TTS = "openai_tts"
    # AZURE_TTS = "azure_tts"
    # BAIDU_TTS = "baidu_tts"
```

**设计特点:**
- 继承自 `str` 和 `Enum`，同时具备枚举和字符串特性
- 字符串值用于配置文件、数据库存储和API传输
- 易于扩展新供应商

### 2. 模型映射 (MODELS_BY_PROVIDER)

```python
# 供应商到可用模型的映射
MODELS_BY_PROVIDER: Dict[Provider, List[str]] = {
    Provider.GLM_TTS: ["glm-tts"],
    Provider.AIHUBMIX_TTS: ["gpt-4o-mini-tts", "tts-1", "gemini-2.5-flash-preview-tts"],
    # 示例: 其他供应商的模型映射
    # Provider.OPENAI_TTS: ["tts-1", "tts-1-hd"],
    # Provider.AZURE_TTS: ["zh-CN-XiaoxiaoNeural", "zh-CN-YunxiNeural"],
}
```

**用途:**
- 动态查询供应商支持的模型
- UI中的模型选择下拉菜单
- 参数验证时的模型检查

## GLM-TTS特定配置

### 支持的音色列表
```python
GLM_SUPPORTED_VOICES: List[str] = [
    "female",   # 默认，对应彤彤
    "tongtong", # 彤彤
    "xiaochen", # 小陈
    "chuichui", # 锤锤
    "jam",      # jam
    "kazi",     # kazi
    "douji",    # douji
    "luodo",    # luodo
]
```

### 支持的音频格式
```python
GLM_SUPPORTED_FORMATS: List[str] = ["wav", "mp3", "pcm", "flac"]
```

### 参数范围限制
```python
GLM_SPEED_RANGE: tuple[float, float] = (0.5, 2.0)   # 语速范围
GLM_VOLUME_RANGE: tuple[float, float] = (0.0, 2.0)  # 音量范围
GLM_DEFAULT_SAMPLE_RATE: int = 24000               # 默认采样率
```

## AIHUBMIX-TTS特定配置

### 支持的音色列表
```python
AIHUBMIX_SUPPORTED_VOICES: List[str] = [
    "alloy",    # 默认音色
    "echo",     # 回声
    "fable",    # 寓言
    "onyx",     # 玛瑙
    "nova",     # 新星
    "shimmer",  # 闪烁
]
```

### 支持的音频格式
```python
AIHUBMIX_SUPPORTED_FORMATS: List[str] = ["mp3", "wav", "pcm", "flac"]
```

### 参数范围限制
```python
AIHUBMIX_SPEED_RANGE: tuple[float, float] = (0.25, 4.0)  # 语速范围
AIHUBMIX_VOLUME_RANGE: tuple[float, float] = (0.0, 2.0)  # 音量范围
AIHUBMIX_DEFAULT_SAMPLE_RATE: int = 24000               # 默认采样率
AIHUBMIX_DEFAULT_BASE_URL: str = "https://aihubmix.com/v1"  # 默认API基础URL
```

## 全局默认参数

```python
# 通用默认参数
DEFAULT_VOICE: str = "female"        # GLM-TTS默认音色
DEFAULT_SPEED: float = 1.0          # 正常速度
DEFAULT_VOLUME: float = 1.0         # 正常音量
DEFAULT_FORMAT: str = "wav"         # 默认音频格式（非流式）
DEFAULT_STREAM_FORMAT: str = "pcm"  # 流式默认格式
DEFAULT_ENCODE_FORMAT: str = "base64"  # 流式编码格式
```

## 供应商特定默认参数

```python
# 供应商特定默认参数配置
PROVIDER_DEFAULT_PARAMS: Dict[Provider, Dict[str, Any]] = {
    Provider.GLM_TTS: {
        "voice": DEFAULT_VOICE,           # "female"
        "speed": DEFAULT_SPEED,           # 1.0
        "volume": DEFAULT_VOLUME,         # 1.0
        "format": DEFAULT_FORMAT,         # "wav"
        "stream_format": DEFAULT_STREAM_FORMAT,  # "pcm"
        "encode_format": DEFAULT_ENCODE_FORMAT,  # "base64"
        "sample_rate": GLM_DEFAULT_SAMPLE_RATE,  # 24000
    },
    Provider.AIHUBMIX_TTS: {
        "voice": "alloy",                 # OpenAI兼容默认音色
        "model": "gpt-4o-mini-tts",       # 默认模型
        "speed": 1.0,                     # 正常速度
        "volume": 1.0,                    # 正常音量
        "format": "mp3",                  # 默认格式
        "stream_format": "pcm",           # 流式格式
        "encode_format": "base64",        # 编码格式
        "sample_rate": AIHUBMIX_DEFAULT_SAMPLE_RATE,  # 24000
        "base_url": AIHUBMIX_DEFAULT_BASE_URL,        # API基础URL
        "api_key": "sk-jju5w22vNQHN0wy21f8eB0244f5047909bF4A3B387C37dB6",  # 默认API密钥
    },
}
```

## 配置获取函数

### 1. 获取默认参数
```python
def get_default_params(provider: Provider) -> Dict[str, Any]:
    """获取指定供应商的默认参数"""
    return PROVIDER_DEFAULT_PARAMS.get(provider, {}).copy()
```

### 2. 获取支持的模型
```python
def get_supported_models(provider: Provider) -> List[str]:
    """获取指定供应商支持的模型列表"""
    return MODELS_BY_PROVIDER.get(provider, []).copy()
```

### 3. 验证供应商支持
```python
def is_provider_supported(provider_name: str) -> bool:
    """检查供应商名称是否受支持"""
    try:
        Provider(provider_name)
        return True
    except ValueError:
        return False
```

### 4. 获取支持的音色列表
```python
def get_supported_voices(provider: Provider) -> List[str]:
    """获取指定供应商支持的音色列表"""
    if provider == Provider.GLM_TTS:
        return get_glm_supported_voices()
    elif provider == Provider.AIHUBMIX_TTS:
        return get_aihubmix_supported_voices()
    else:
        return []
```

### 5. 获取支持的格式列表
```python
def get_supported_formats(provider: Provider) -> List[str]:
    """获取指定供应商支持的格式列表"""
    if provider == Provider.GLM_TTS:
        return get_glm_supported_formats()
    elif provider == Provider.AIHUBMIX_TTS:
        return get_aihubmix_supported_formats()
    else:
        return []
```

## 参数验证函数

### 1. 语速验证
```python
def validate_speed(provider: Provider, speed: float) -> bool:
    """验证指定供应商的语速是否在有效范围内"""
    if provider == Provider.GLM_TTS:
        return validate_glm_speed(speed)
    elif provider == Provider.AIHUBMIX_TTS:
        return validate_aihubmix_speed(speed)
    else:
        # 对于未知供应商，假设任何正数都有效
        return speed > 0
```

### 2. 音量验证
```python
def validate_volume(provider: Provider, volume: float) -> bool:
    """验证指定供应商的音量是否在有效范围内"""
    if provider == Provider.GLM_TTS:
        return validate_glm_volume(volume)
    elif provider == Provider.AIHUBMIX_TTS:
        return validate_aihubmix_volume(volume)
    else:
        # 对于未知供应商，假设任何正数都有效
        return volume >= 0
```

### 3. 供应商特定验证函数
```python
def validate_glm_speed(speed: float) -> bool:
    """验证GLM-TTS语速是否在有效范围内"""
    return GLM_SPEED_RANGE[0] <= speed <= GLM_SPEED_RANGE[1]

def validate_aihubmix_speed(speed: float) -> bool:
    """验证AIHUBMIX-TTS语速是否在有效范围内"""
    return AIHUBMIX_SPEED_RANGE[0] <= speed <= AIHUBMIX_SPEED_RANGE[1]
```

## 参数范围获取函数

### 1. 获取语速范围
```python
def get_speed_range(provider: Provider) -> tuple[float, float]:
    """获取指定供应商的语速范围"""
    if provider == Provider.GLM_TTS:
        return GLM_SPEED_RANGE
    elif provider == Provider.AIHUBMIX_TTS:
        return AIHUBMIX_SPEED_RANGE
    else:
        # 对于未知供应商，返回默认范围
        return (0.5, 2.0)
```

### 2. 获取音量范围
```python
def get_volume_range(provider: Provider) -> tuple[float, float]:
    """获取指定供应商的音量范围"""
    if provider == Provider.GLM_TTS:
        return GLM_VOLUME_RANGE
    elif provider == Provider.AIHUBMIX_TTS:
        return AIHUBMIX_VOLUME_RANGE
    else:
        # 对于未知供应商，返回默认范围
        return (0.0, 2.0)
```

### 3. 获取支持的编码格式
```python
def get_supported_encodings(provider: Provider) -> List[str]:
    """获取指定供应商支持的编码格式列表"""
    # 目前所有供应商都支持相同的编码格式
    return ["base64", "raw"]
```

## 使用示例

### 1. 基本配置查询
```python
from src.config import Provider, get_default_params, get_supported_models

# 获取GLM-TTS的默认参数
glm_params = get_default_params(Provider.GLM_TTS)
print(f"GLM默认参数: {glm_params}")

# 获取AIHUBMIX-TTS支持的模型
aihubmix_models = get_supported_models(Provider.AIHUBMIX_TTS)
print(f"AIHUBMIX支持模型: {aihubmix_models}")

# 验证供应商支持
is_supported = is_provider_supported("glm_tts")
print(f"GLM-TTS是否支持: {is_supported}")
```

### 2. 参数验证示例
```python
from src.config import validate_speed, get_speed_range

# 验证语速参数
provider = Provider.GLM_TTS
speed = 1.5

if validate_speed(provider, speed):
    print(f"语速 {speed} 在有效范围内")
else:
    speed_range = get_speed_range(provider)
    print(f"语速 {speed} 无效，有效范围: {speed_range[0]} - {speed_range[1]}")
```

### 3. 供应商特定配置
```python
from src.config import get_glm_supported_voices, get_aihubmix_supported_voices

# 获取GLM-TTS支持的音色
glm_voices = get_glm_supported_voices()
print(f"GLM-TTS音色: {glm_voices}")

# 获取AIHUBMIX-TTS支持的音色
aihubmix_voices = get_aihubmix_supported_voices()
print(f"AIHUBMIX-TTS音色: {aihubmix_voices}")
```

### 4. 完整供应商配置
```python
from src.config import Provider, get_default_params, get_supported_models, get_supported_voices

def get_provider_config(provider_name: str):
    """获取完整供应商配置信息"""
    try:
        provider = Provider(provider_name)
    except ValueError:
        return None
    
    config = {
        "name": provider.value,
        "default_params": get_default_params(provider),
        "supported_models": get_supported_models(provider),
        "supported_voices": get_supported_voices(provider),
        "supported_formats": get_supported_formats(provider),
        "speed_range": get_speed_range(provider),
        "volume_range": get_volume_range(provider),
    }
    
    return config

# 获取GLM-TTS完整配置
glm_config = get_provider_config("glm_tts")
print(f"GLM-TTS配置: {glm_config}")
```

## 扩展新供应商

### 1. 添加新供应商枚举
```python
# 在Provider枚举中添加
class Provider(str, Enum):
    # ... 现有供应商
    NEW_TTS = "new_tts"  # 新增供应商
```

### 2. 添加模型映射
```python
# 在MODELS_BY_PROVIDER中添加
MODELS_BY_PROVIDER: Dict[Provider, List[str]] = {
    # ... 现有映射
    Provider.NEW_TTS: ["model-a", "model-b"],
}
```

### 3. 添加供应商特定配置
```python
# 添加音色列表
NEW_SUPPORTED_VOICES: List[str] = ["voice1", "voice2", "voice3"]

# 添加参数范围
NEW_SPEED_RANGE: tuple[float, float] = (0.3, 3.0)
NEW_VOLUME_RANGE: tuple[float, float] = (0.1, 3.0)
NEW_DEFAULT_SAMPLE_RATE: int = 22050
```

### 4. 添加默认参数
```python
# 在PROVIDER_DEFAULT_PARAMS中添加
PROVIDER_DEFAULT_PARAMS: Dict[Provider, Dict[str, Any]] = {
    # ... 现有配置
    Provider.NEW_TTS: {
        "voice": "voice1",
        "model": "model-a",
        "speed": 1.0,
        "volume": 1.0,
        "format": "mp3",
        "stream_format": "pcm",
        "encode_format": "base64",
        "sample_rate": NEW_DEFAULT_SAMPLE_RATE,
        "api_key": "",  # 留空，需要用户配置
    },
}
```

### 5. 添加验证函数
```python
def validate_new_speed(speed: float) -> bool:
    return NEW_SPEED_RANGE[0] <= speed <= NEW_SPEED_RANGE[1]

def validate_new_volume(volume: float) -> bool:
    return NEW_VOLUME_RANGE[0] <= volume <= NEW_VOLUME_RANGE[1]

# 更新通用验证函数
def validate_speed(provider: Provider, speed: float) -> bool:
    if provider == Provider.NEW_TTS:
        return validate_new_speed(speed)
    # ... 现有逻辑
```

## 最佳实践

### 1. 参数合并策略
```python
# 推荐：使用配置系统的默认参数
from src.config import get_default_params

def synthesize(self, text: str, **kwargs):
    # 获取默认参数
    default_params = get_default_params(Provider.GLM_TTS)
    
    # 合并参数：用户参数覆盖默认参数
    params = default_params.copy()
    params.update(kwargs)
    
    # 使用合并后的参数
    return self._synthesize_with_params(text, params)
```

### 2. 参数验证
```python
# 在关键操作前验证参数
from src.config import validate_speed, validate_volume, get_speed_range

def validate_synthesis_params(self, params: Dict[str, Any]) -> bool:
    """验证合成参数"""
    provider = Provider(self.name)
    
    # 验证语速
    if "speed" in params and not validate_speed(provider, params["speed"]):
        speed_range = get_speed_range(provider)
        raise ValueError(f"语速 {params['speed']} 超出范围 {speed_range}")
    
    # 验证音量
    if "volume" in params and not validate_volume(provider, params["volume"]):
        volume_range = get_volume_range(provider)
        raise ValueError(f"音量 {params['volume']} 超出范围 {volume_range}")
    
    return True
```

### 3. 动态配置更新
```python
# 支持运行时配置更新
class ConfigManager:
    def __init__(self):
        self._config_cache = {}
    
    def get_provider_config(self, provider_name: str, force_reload=False):
        """获取供应商配置，支持缓存"""
        if force_reload or provider_name not in self._config_cache:
            config = self._load_provider_config(provider_name)
            self._config_cache[provider_name] = config
        
        return self._config_cache[provider_name]
    
    def update_provider_config(self, provider_name: str, updates: Dict[str, Any]):
        """更新供应商配置"""
        if provider_name in self._config_cache:
            self._config_cache[provider_name].update(updates)
        # 同时更新配置文件或数据库
```

## 配置源扩展

### 1. 文件配置支持
```python
import json
from pathlib import Path

def load_config_from_file(file_path: str) -> Dict[str, Any]:
    """从JSON文件加载配置"""
    with open(file_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_config_to_file(config: Dict[str, Any], file_path: str):
    """保存配置到JSON文件"""
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
```

### 2. 环境变量支持
```python
import os

def load_config_from_env() -> Dict[str, Any]:
    """从环境变量加载配置"""
    config = {}
    
    # 从环境变量读取供应商配置
    for key, value in os.environ.items():
        if key.startswith('TTS_'):
            config_key = key[4:].lower()  # 移除'TTS_'前缀
            config[config_key] = value
    
    return config
```

### 3. 数据库配置支持
```python
# 伪代码示例
class DatabaseConfigStore:
    def __init__(self, db_connection):
        self.db = db_connection
    
    def get_provider_config(self, provider_name: str) -> Dict[str, Any]:
        """从数据库获取供应商配置"""
        query = "SELECT config FROM tts_config WHERE provider = %s"
        result = self.db.execute(query, (provider_name,))
        if result:
            return json.loads(result[0]['config'])
        return {}
```

## 总结

TTS配置系统提供了一套完整、灵活的配置管理方案，具有以下特点：

1. **集中管理**：所有供应商配置集中在一个文件中，便于维护
2. **类型安全**：使用枚举和类型注解，减少运行时错误
3. **易于扩展**：添加新供应商只需扩展几个字典和函数
4. **参数验证**：内置参数范围验证，提高系统健壮性
5. **多格式支持**：支持多种音频格式和编码格式
6. **供应商特定**：允许每个供应商有不同的默认值和范围限制

通过这套配置系统，TTS应用可以轻松支持多个供应商，同时保持代码的清晰和可维护性。配置与业务逻辑分离的设计也使得系统更容易测试和调试。