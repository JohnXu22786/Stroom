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
          onChanged: (value) {
            if (value != null) {
              notifier.updateProviderType(value);
            }
          },
        ),
      ],
    );
  }

  /// 构建API密钥输入字段（增强版）
  Widget _buildApiKeyField(TTSConfigState config, TTSConfigNotifier notifier, BuildContext context) {
    final hasApiKey = notifier.hasApiKey();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'API密钥',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            if (hasApiKey)
              Text(
                '已配置',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: notifier.getDisplayApiKey(),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: '输入API密钥...',
                  suffixIcon: IconButton(
                    icon: Icon(
                      config.isApiKeyObscured
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 20,
                    ),
                    onPressed: notifier.toggleApiKeyObscured,
                  ),
                ),
                onChanged: (value) {
                  // 如果API密钥被隐藏，只有在显示时才更新
                  if (!config.isApiKeyObscured || value == notifier.getDisplayApiKey()) {
                    notifier.updateApiKey(value);
                  }
                },
                obscureText: config.isApiKeyObscured,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'API密钥用于访问TTS服务，请从供应商处获取',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),

        // API密钥缺失警告区域
        if (!hasApiKey) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.amber.shade700, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'API密钥未配置',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '当前TTS功能可能受限，部分功能无法使用。',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                _buildApiKeyInstructions(config.providerType),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    _showApiKeyHelpDialog(context, config.providerType);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade100,
                    foregroundColor: Colors.amber.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.help_outline, size: 16),
                      SizedBox(width: 6),
                      Text('如何获取API密钥？'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// 构建API密钥获取说明
  Widget _buildApiKeyInstructions(TTSProviderType providerType) {
    switch (providerType) {
      case TTSProviderType.glmTTS:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '• 访问智谱AI开放平台注册账号',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            Text(
              '• 创建应用并获取API Key',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            Text(
              '• 将API Key复制到上方输入框',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        );
      case TTSProviderType.aihubmixTTS:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '• 访问AIHUBMIX平台获取API密钥',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            Text(
              '• 支持OpenAI兼容API',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            Text(
              '• 将API Key复制到上方输入框',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        );

    }
  }

  /// 显示API密钥帮助对话框
  void _showApiKeyHelpDialog(BuildContext context, TTSProviderType providerType) {
    String providerName = providerType.displayName;
    String helpUrl = '';
    String helpDescription = '';

    switch (providerType) {
      case TTSProviderType.glmTTS:
        helpUrl = 'https://open.bigmodel.cn/';
        helpDescription = '智谱AI开放平台提供全面的AI能力，包括TTS语音合成服务。';
        break;
      case TTSProviderType.aihubmixTTS:
        helpUrl = 'https://aihubmix.com/';
        helpDescription = 'AIHUBMIX提供OpenAI兼容的API服务，包括TTS功能。';
        break;

    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.vpn_key, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text('$providerName - API密钥获取指南'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(helpDescription),
              const SizedBox(height: 16),
              const Text(
                '获取步骤：',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text('1. 访问供应商平台: $helpUrl'),
              const Text('2. 注册账号并完成认证'),
              const Text('3. 创建应用或获取API密钥'),
              const Text('4. 复制API密钥到本应用'),
              const SizedBox(height: 16),
              const Text(
                '注意：',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text('• API密钥是访问TTS服务的凭证，请妥善保管'),
              const Text('• 不要将API密钥分享给他人'),
              const Text('• 定期检查API密钥使用情况'),
              const Text('• 旧版TTS服务仍可作为后备选项'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
          if (helpUrl.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                // 在真实应用中这里应该打开浏览器
                // 这里只关闭对话框并提示
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('请访问: $helpUrl'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              child: const Text('访问网站'),
            ),
        ],
      ),
    );
  }

  /// 构建音色选择器
  Widget _buildVoiceSelector(TTSConfigState config, TTSConfigNotifier notifier) {
    final supportedVoices = config.getSupportedVoices();

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
          items: supportedVoices.map((voice) {
            return DropdownMenuItem<String>(
              value: voice,
              child: Text(voice),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              notifier.updateVoice(value);
            }
          },
        ),
      ],
    );
  }

  /// 构建语速滑块
  Widget _buildSpeedSlider(TTSConfigState config, TTSConfigNotifier notifier) {
    final ranges = config.getParamRanges();
    final speedRange = ranges['speed'] as Map<String, dynamic>?;
    final min = speedRange?['min'] as double? ?? 0.25;
    final max = speedRange?['max'] as double? ?? 4.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '语速',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              '${config.speed.toStringAsFixed(1)}x',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: config.speed,
          min: min,
          max: max,
          divisions: ((max - min) / 0.25).round(),
          label: '${config.speed.toStringAsFixed(1)}x',
          onChanged: (value) {
            notifier.updateSpeed(value);
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${min}x',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              '${max}x',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建音量滑块
  Widget _buildVolumeSlider(TTSConfigState config, TTSConfigNotifier notifier) {
    final ranges = config.getParamRanges();
    final volumeRange = ranges['volume'] as Map<String, dynamic>?;
    final min = volumeRange?['min'] as double? ?? 0.0;
    final max = volumeRange?['max'] as double? ?? 2.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '音量',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              '${(config.volume * 100).toInt()}%',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: config.volume,
          min: min,
          max: max,
          divisions: ((max - min) / 0.1).round(),
          label: '${(config.volume * 100).toInt()}%',
          onChanged: (value) {
            notifier.updateVolume(value);
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(min * 100).toInt()}%',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              '${(max * 100).toInt()}%',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建高级设置
  Widget _buildAdvancedSettings(TTSConfigState config, TTSConfigNotifier notifier) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text(
        '高级设置',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      children: [
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 音频格式选择
            const Text(
              '音频格式',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: config.format,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              items: TTSProviderConfig.supportedFormats.map((format) {
                return DropdownMenuItem<String>(
                  value: format,
                  child: Text(format.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  notifier.updateFormat(value);
                }
              },
            ),
            const SizedBox(height: 16),
            // 采样率选择
            const Text(
              '采样率',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: config.sampleRate,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              items: [8000, 16000, 24000, 32000, 44100, 48000].map((rate) {
                return DropdownMenuItem<int>(
                  value: rate,
                  child: Text('$rate Hz'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  notifier.updateSampleRate(value);
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  /// 构建操作按钮
  Widget _buildActionButtons(
    TTSConfigState config,
    TTSConfigNotifier notifier,
    BuildContext context,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('重置为默认'),
            onPressed: () {
              notifier.resetToDefaults();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('配置已重置为默认值'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.save, size: 18),
            label: const Text('保存配置'),
            onPressed: () {
              if (onConfigSaved != null) {
                onConfigSaved!();
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'TTS配置已保存 - ${config.providerDisplayName}',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// TTS配置对话框
///
/// 独立对话框版本的TTS配置界面
class TTSConfigDialog extends ConsumerWidget {
  const TTSConfigDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                '配置将自动保存，下次生成语音时生效',
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  /// 显示配置对话框
  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const TTSConfigDialog(),
    );
  }
}
