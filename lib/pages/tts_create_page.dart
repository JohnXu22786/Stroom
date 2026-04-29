import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../providers/tts_state_provider.dart';
import '../providers/tts_config.dart';
import '../providers/provider_config.dart';

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

  // 当前选中的模型配置（取 TTS 供应商第一个模型）
  ModelConfig? _modelConfig;

  // 自定义参数值覆盖
  final Map<String, TextEditingController> _customParamControllers = {};

  // 当前选中的音色、语速、音量
  String _selectedVoice = '';
  double _speed = 1.0;
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadModelConfig();
    });
  }

  void _loadModelConfig() {
    final entriesState = ref.read(providerEntriesProvider);
    // 找 TTS 供应商条目
    final ttsEntry = entriesState.entries.where((e) => e.name == 'TTS供应商').firstOrNull;
    if (ttsEntry == null || ttsEntry.configs.isEmpty || ttsEntry.configs.first.models.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showNotConfiguredWarning();
        }
      });
      return;
    }

    final configItem = ttsEntry.configs.first;
    // 检查 host 和 key 是否已填写
    if (configItem.host.trim().isEmpty || configItem.key.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('供应商配置不完整'),
              content: const Text('TTS供应商的 Host 和 Key 未填写完整，请在设置页面中补充配置后再使用语音生成功能。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('知道了'),
                ),
              ],
            ),
          );
        }
      });
      return;
    }

    final model = ttsEntry.configs.first.models.first;
    setState(() {
      _modelConfig = model;
      if (model.voices.isNotEmpty) {
        _selectedVoice = model.voices.first.name;
      }
      // 初始化自定义参数控制器
      _customParamControllers.clear();
      for (final p in model.customParams) {
        _customParamControllers[p.paramName] = TextEditingController(text: p.defaultValue);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    for (final c in _customParamControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isTTSConfigured() {
    return _modelConfig != null;
  }

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
              Navigator.pushNamed(context, '/settings');
            },
            child: const Text('去配置'),
          ),
        ],
      ),
    );
  }

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

    _focusNode.unfocus();

    setState(() {
      _isGenerating = true;
    });

    try {
      // 更新 synthesisConfig 以使用当前值
      final synthNotifier = ref.read(synthesisConfigProvider.notifier);
      if (_modelConfig!.voices.isNotEmpty) {
        await synthNotifier.updateVoice(_selectedVoice);
      }
      await synthNotifier.updateSpeed(_speed);
      await synthNotifier.updateVolume(_volume);

      final audioFile = await ref.read(ttsStateProvider.notifier).synthesize(text);

      if (audioFile != null) {
        _lastGeneratedFilePath = audioFile.path;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('语音生成成功，可前往"录音"页面播放'),
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

  @override
  Widget build(BuildContext context) {
    final ttsState = ref.watch(ttsStateProvider);
    final model = _modelConfig;

    return Scaffold(
      appBar: AppBar(
        title: const Text('制作录音'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 文本输入区域
            _buildTextInputSection(),
            const SizedBox(height: 24),

            // 配置区域（按模型配置条件显示）
            if (model != null) _buildConfigSection(model),
            if (model == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text('请先在设置中配置 TTS 供应商和模型',
                        style: TextStyle(color: Colors.grey[600])),
                  ),
                ),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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

  Widget _buildConfigSection(ModelConfig model) {
    final hasVoices = model.voices.isNotEmpty;
    final hasSpeed = model.hasSpeed;
    final hasVolume = model.hasVolume;
    final hasCustomParams = model.customParams.isNotEmpty;

    // 如果什么都没配置，就不显示配置卡片
    if (!hasVoices && !hasSpeed && !hasVolume && !hasCustomParams) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text('请在设置页面配置模型参数',
                style: TextStyle(color: Colors.grey[600])),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '合成配置',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            // 音色选择（有条件）
            if (hasVoices) ...[
              _buildVoiceSelector(model),
              const SizedBox(height: 16),
            ],

            // 语速控制（有条件）
            if (hasSpeed) ...[
              _buildSpeedSlider(model),
              const SizedBox(height: 16),
            ],

            // 音量控制（有条件）
            if (hasVolume) ...[
              _buildVolumeSlider(model),
              const SizedBox(height: 16),
            ],

            // 自定义参数（有条件）
            if (hasCustomParams) ...[
              _buildCustomParamsSection(model),
              const SizedBox(height: 16),
            ],

            // 底部提示
            Text(
              '在TTS供应商设置页面设置更多参数',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceSelector(ModelConfig model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '音色',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: model.voices.any((v) => v.name == _selectedVoice) ? _selectedVoice : model.voices.first.name,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '选择音色',
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: model.voices.map((v) {
            return DropdownMenuItem<String>(
              value: v.name,
              child: Text(v.name),
            );
          }).toList(),
          onChanged: (newVoice) {
            if (newVoice != null) {
              setState(() => _selectedVoice = newVoice);
            }
          },
        ),
      ],
    );
  }

  Widget _buildSpeedSlider(ModelConfig model) {
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
              '${_speed.toStringAsFixed(1)}x',
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
          value: _speed,
          min: model.speedMin,
          max: model.speedMax,
          divisions: ((model.speedMax - model.speedMin) * 10).round().clamp(1, 100),
          label: '${_speed.toStringAsFixed(1)}x',
          onChanged: (value) {
            setState(() => _speed = value);
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${model.speedMin}x'),
            const Text('正常'),
            Text('${model.speedMax}x'),
          ],
        ),
      ],
    );
  }

  Widget _buildVolumeSlider(ModelConfig model) {
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
              '${_volume.toStringAsFixed(1)}',
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
          value: _volume,
          min: model.volumeMin,
          max: model.volumeMax,
          divisions: ((model.volumeMax - model.volumeMin) * 10).round().clamp(1, 100),
          label: _volume.toStringAsFixed(1),
          onChanged: (value) {
            setState(() => _volume = value);
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(model.volumeMin.toStringAsFixed(1)),
            const Text('正常'),
            Text(model.volumeMax.toStringAsFixed(1)),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomParamsSection(ModelConfig model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '自定义参数',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        ...model.customParams.map((param) {
          final ctrl = _customParamControllers[param.paramName] ??
              TextEditingController(text: param.defaultValue);
          // Ensure controller is stored
          if (!_customParamControllers.containsKey(param.paramName)) {
            _customParamControllers[param.paramName] = ctrl;
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(param.paramName,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    decoration: InputDecoration(
                      hintText: '默认: ${param.defaultValue}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
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
                  Text('制作录音', style: TextStyle(fontSize: 18)),
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
              child: Text(error, style: const TextStyle(color: Colors.red)),
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
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
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
