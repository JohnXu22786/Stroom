import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../providers/tts_state_provider.dart';
import '../providers/tts_config.dart';

/// TTS创建页面 - 用于文本转语音转换
class TTSCreatePage extends ConsumerStatefulWidget {
  const TTSCreatePage({super.key});

  @override
  ConsumerState<TTSCreatePage> createState() => _TTSCreatePageState();
}

class _TTSCreatePageState extends ConsumerState<TTSCreatePage> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isGenerating = false;
  String? _lastGeneratedFilePath;

  @override
  void initState() {
    super.initState();
    // 加载保存的配置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedConfig();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSavedConfig() async {
    // 配置已通过provider自动加载
    // 这里可以添加额外的初始化逻辑
  }

  /// 检查TTS供应商是否已配置
  bool _isTTSConfigured() {
    final config = ref.read(ttsConfigProvider);
    return config.selectedProvider != null &&
           config.apiKey?.isNotEmpty == true;
  }

  /// 显示未配置警告
  void _showNotConfiguredWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('供应商未配置'),
        content: const Text('请先在设置页面配置TTS供应商和API密钥'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 导航到设置页面
              // 注意：这里需要根据实际导航结构调整
              Navigator.pushNamed(context, '/settings');
            },
            child: const Text('去配置'),
          ),
        ],
      ),
    );
  }

  /// 生成语音
  Future<void> _generateSpeech() async {
    if (!_isTTSConfigured()) {
      _showNotConfiguredWarning();
      return;
    }

    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入要转换的文本'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // 隐藏键盘
    _focusNode.unfocus();

    setState(() {
      _isGenerating = true;
    });

    try {
      final audioFile = await ref.read(ttsStateProvider.notifier).synthesize(text);

      if (audioFile != null) {
        _lastGeneratedFilePath = audioFile.path;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('语音生成成功'),
            action: SnackBarAction(
              label: '播放',
              onPressed: () {
                // TODO: 实现音频播放
                // _playAudio(audioFile.path);
              },
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('生成失败: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  /// 重置配置到默认值
  Future<void> _resetToDefaults() async {
    await ref.read(synthesisConfigProvider.notifier).resetToDefaults();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已重置为默认配置'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final synthesisConfig = ref.watch(synthesisConfigProvider);
    final ttsState = ref.watch(ttsStateProvider);
    final config = ref.watch(ttsConfigProvider);

    // 获取当前供应商支持的音色
    final supportedVoices = config.selectedProvider != null
        ? TTSConfig.getSupportedVoices(config.selectedProvider!)
        : <String>[];

    // 获取当前供应商的语速和音量范围
    final speedRange = config.selectedProvider != null
        ? TTSConfig.getSpeedRange(config.selectedProvider!)
        : {'min': 0.5, 'max': 2.0};
    final volumeRange = config.selectedProvider != null
        ? TTSConfig.getVolumeRange(config.selectedProvider!)
        : {'min': 0.0, 'max': 10.0};

    return Scaffold(
      appBar: AppBar(
        title: const Text('制作录音'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: '重置配置',
            onPressed: _resetToDefaults,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 文本输入区域
            _buildTextInputSection(),
            const SizedBox(height: 24),

            // 配置区域
            _buildConfigurationSection(
              synthesisConfig,
              supportedVoices,
              speedRange,
              volumeRange,
            ),
            const SizedBox(height: 24),

            // 生成按钮
            _buildGenerateButton(),
            const SizedBox(height: 16),

            // 状态显示
            if (ttsState.error != null) _buildErrorSection(ttsState.error!),
            if (_lastGeneratedFilePath != null) _buildSuccessSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInputSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '转换文本',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              focusNode: _focusNode,
              maxLines: 5,
              minLines: 3,
              decoration: InputDecoration(
                hintText: '请输入要转换为语音的文本...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _textController.clear(),
                ),
              ),
              inputFormatters: [
                LengthLimitingTextInputFormatter(1000),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${_textController.text.length}/1000',
                  style: TextStyle(
                    fontSize: 12,
                    color: _textController.text.length > 1000
                        ? Colors.red
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationSection(
    SynthesisConfig config,
    List<String> supportedVoices,
    Map<String, double> speedRange,
    Map<String, double> volumeRange,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '合成配置',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // 音色选择
            _buildVoiceSelector(config, supportedVoices),
            const SizedBox(height: 16),

            // 语速控制
            _buildSpeedSlider(config, speedRange),
            const SizedBox(height: 16),

            // 音量控制
            _buildVolumeSlider(config, volumeRange),
            const SizedBox(height: 16),

            // 格式选择
            _buildFormatSelector(config),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceSelector(
    SynthesisConfig config,
    List<String> supportedVoices,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '音色',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: config.voice,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '选择音色',
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: supportedVoices.map((voice) {
            return DropdownMenuItem<String>(
              value: voice,
              child: Text(voice),
            );
          }).toList(),
          onChanged: (newVoice) {
            if (newVoice != null) {
              ref.read(synthesisConfigProvider.notifier).updateVoice(newVoice);
            }
          },
        ),
      ],
    );
  }

  Widget _buildSpeedSlider(
    SynthesisConfig config,
    Map<String, double> speedRange,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '语速',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Text(
              '${config.speed.toStringAsFixed(1)}x',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: config.speed,
          min: speedRange['min']!,
          max: speedRange['max']!,
          divisions: 15, // 0.1的步进
          label: '${config.speed.toStringAsFixed(1)}x',
          onChanged: (value) {
            ref.read(synthesisConfigProvider.notifier).updateSpeed(value);
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${speedRange['min']!}x'),
            const Text('正常'),
            Text('${speedRange['max']!}x'),
          ],
        ),
      ],
    );
  }

  Widget _buildVolumeSlider(
    SynthesisConfig config,
    Map<String, double> volumeRange,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '音量',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Text(
              '${config.volume.toStringAsFixed(1)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: config.volume,
          min: volumeRange['min']!,
          max: volumeRange['max']!,
          divisions: 10,
          label: config.volume.toStringAsFixed(1),
          onChanged: (value) {
            ref.read(synthesisConfigProvider.notifier).updateVolume(value);
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(volumeRange['min']!.toStringAsFixed(1)),
            const Text('正常'),
            Text(volumeRange['max']!.toStringAsFixed(1)),
          ],
        ),
      ],
    );
  }

  Widget _buildFormatSelector(SynthesisConfig config) {
    const supportedFormats = ['mp3', 'wav', 'pcm'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '保存音频格式',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: supportedFormats.map((format) {
            final isSelected = config.format == format;
            return ChoiceChip(
              label: Text(format.toUpperCase()),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  ref.read(synthesisConfigProvider.notifier).updateFormat(format);
                }
              },
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        const Text(
          '应用将自动转换音频格式',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isGenerating ? null : _generateSpeech,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isGenerating
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('生成中...'),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.audio_file),
                  SizedBox(width: 12),
                  Text(
                    '制作录音',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorSection(String error) {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessSection() {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 12),
                const Text(
                  '语音生成成功',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '文件已保存: $_lastGeneratedFilePath',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
