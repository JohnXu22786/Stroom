import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/providers/tts_config_provider.dart';
import 'package:stroom/tts/providers/provider_config.dart';

/// TTS配置面板组件
///
/// 提供完整的TTS供应商配置界面，包括：
/// - 供应商选择
/// - API密钥输入
/// - 音色、语速、音量等参数配置
/// - 配置保存和重置功能
class TTSConfigPanel extends ConsumerWidget {
  final bool initiallyExpanded;
  final VoidCallback? onConfigSaved;

  const TTSConfigPanel({
    super.key,
    this.initiallyExpanded = false,
    this.onConfigSaved,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(ttsConfigProvider);
    final notifier = ref.read(ttsConfigProvider.notifier);

    return Card(
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Row(
          children: [
            Icon(Icons.settings, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            const Text(
              'TTS供应商配置',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Chip(
              label: Text(config.providerDisplayName),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              labelStyle: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProviderSelector(config, notifier),
                const SizedBox(height: 16),
                _buildApiKeyField(config, notifier, context),
                const SizedBox(height: 20),
                _buildVoiceSelector(config, notifier),
                const SizedBox(height: 20),
                _buildSpeedSlider(config, notifier),
                const SizedBox(height: 20),
                _buildVolumeSlider(config, notifier),
                const SizedBox(height: 20),
                _buildAdvancedSettings(config, notifier),
                const SizedBox(height: 24),
                _buildActionButtons(config, notifier, context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建供应商选择器
  Widget _buildProviderSelector(TTSConfigState config, TTSConfigNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '供应商',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<TTSProviderType>(
          initialValue: config.providerType,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: TTSProviderType.values.map((provider) {
            return DropdownMenuItem<TTSProviderType>(
              value: provider,
              child: Text(provider.displayName),
            );
          }).toList(),
          onChanged: (provider) {
            if (provider != null) {
              notifier.updateProviderType(provider);
            }
          },
        ),
      ],
    );
  }

  /// 构建API密钥输入字段
  Widget _buildApiKeyField(TTSConfigState config, TTSConfigNotifier notifier, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'API密钥',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: config.apiKey,
                obscureText: config.isApiKeyObscured,
                decoration: InputDecoration(
                  hintText: '输入API密钥...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  suffixIcon: IconButton(
                    icon: Icon(
                      config.isApiKeyObscured ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                    ),
                    onPressed: () {
                      notifier.toggleApiKeyObscured();
                    },
                    tooltip: config.isApiKeyObscured ? '显示密钥' : '隐藏密钥',
                  ),
                ),
                onChanged: (value) {
                  notifier.updateApiKey(value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'API密钥仅保存在本地，请确保安全',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// 构建音色选择器
  Widget _buildVoiceSelector(TTSConfigState config, TTSConfigNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '音色',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: config.voice,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: config.getSupportedVoices().map((voice) {
            return DropdownMenuItem<String>(
              value: voice,
              child: Text(voice),
            );
          }).toList(),
          onChanged: (voice) {
            if (voice != null) {
              notifier.updateVoice(voice);
            }
          },
        ),
      ],
    );
  }

  /// 构建语速滑块
  Widget _buildSpeedSlider(TTSConfigState config, TTSConfigNotifier notifier) {
    final paramRanges = config.getParamRanges();
    final minSpeed = paramRanges['speed']?['min'] as double? ?? 0.5;
    final maxSpeed = paramRanges['speed']?['max'] as double? ?? 2.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '语速',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              config.speed.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: config.speed,
          min: minSpeed,
          max: maxSpeed,
          divisions: 15,
          onChanged: (value) {
            notifier.updateSpeed(value);
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '慢',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              '快',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建音量滑块
  Widget _buildVolumeSlider(TTSConfigState config, TTSConfigNotifier notifier) {
    final paramRanges = config.getParamRanges();
    final minVolume = paramRanges['volume']?['min'] as double? ?? 0.0;
    final maxVolume = paramRanges['volume']?['max'] as double? ?? 2.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '音量',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              config.volume.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: config.volume,
          min: minVolume,
          max: maxVolume,
          divisions: 20,
          onChanged: (value) {
            notifier.updateVolume(value);
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '小',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              '大',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建高级设置
  Widget _buildAdvancedSettings(TTSConfigState config, TTSConfigNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '高级设置',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '音频格式',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: config.format,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: ['wav', 'mp3', 'ogg'].map((format) {
                      return DropdownMenuItem<String>(
                        value: format,
                        child: Text(format),
                      );
                    }).toList(),
                    onChanged: (format) {
                      if (format != null) {
                        notifier.updateFormat(format);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '采样率',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int>(
                    initialValue: config.sampleRate,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [16000, 24000, 44100, 48000].map((rate) {
                      return DropdownMenuItem<int>(
                        value: rate,
                        child: Text('$rate Hz'),
                      );
                    }).toList(),
                    onChanged: (rate) {
                      if (rate != null) {
                        notifier.updateSampleRate(rate);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建操作按钮
  Widget _buildActionButtons(TTSConfigState config, TTSConfigNotifier notifier, BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              notifier.resetToDefaults();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已重置为默认配置'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.restore, size: 18),
            label: const Text('恢复默认'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              onConfigSaved?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('配置已保存'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.save, size: 18),
            label: const Text('保存配置'),
          ),
        ),
      ],
    );
  }
}

/// TTS配置对话框
///
/// 独立对话框版本的TTS配置界面
class TTSConfigDialog extends ConsumerStatefulWidget {
  const TTSConfigDialog({super.key});

  @override
  ConsumerState<TTSConfigDialog> createState() => _TTSConfigDialogState();
}

class _TTSConfigDialogState extends ConsumerState<TTSConfigDialog> {
  TTSConfigState? _initialConfig;
  TTSConfigState? _currentConfig;

  @override
  void initState() {
    super.initState();
    _initialConfig = ref.read(ttsConfigProvider);
    _currentConfig = _initialConfig;
  }

  void _applyChanges() {
    if (_currentConfig != null) {
      final notifier = ref.read(ttsConfigProvider.notifier);
      notifier.updateProviderType(_currentConfig!.providerType);
      if (_currentConfig!.apiKey != null) {
        notifier.updateApiKey(_currentConfig!.apiKey!);
      }
      notifier.updateVoice(_currentConfig!.voice);
      notifier.updateSpeed(_currentConfig!.speed);
      notifier.updateVolume(_currentConfig!.volume);
      notifier.updateFormat(_currentConfig!.format);
      notifier.updateSampleRate(_currentConfig!.sampleRate);
    }
    Navigator.of(context).pop();
  }

  void _cancelChanges() {
    // 恢复到初始配置
    if (_initialConfig != null) {
      final notifier = ref.read(ttsConfigProvider.notifier);
      notifier.updateProviderType(_initialConfig!.providerType);
      if (_initialConfig!.apiKey != null) {
        notifier.updateApiKey(_initialConfig!.apiKey!);
      }
      notifier.updateVoice(_initialConfig!.voice);
      notifier.updateSpeed(_initialConfig!.speed);
      notifier.updateVolume(_initialConfig!.volume);
      notifier.updateFormat(_initialConfig!.format);
      notifier.updateSampleRate(_initialConfig!.sampleRate);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('TTS供应商配置'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TTSConfigPanel(
                initiallyExpanded: true,
              ),
              const SizedBox(height: 16),
              Text(
                '点击"保存"应用配置，点击"取消"恢复原设置',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _cancelChanges,
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _applyChanges,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
