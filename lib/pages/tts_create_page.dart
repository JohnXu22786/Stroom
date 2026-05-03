import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';

import '../providers/tts_state_provider.dart';
import '../providers/provider_config.dart';
import '../providers/tts_config.dart';
import 'provider_config_page.dart';

/// 模型选项：模型配置 + 所属供应商配置（含 host/key）
class _ModelOption {
  final ModelConfig config;
  final ProviderConfigItem providerConfig;

  const _ModelOption(this.config, this.providerConfig);
}

/// TTS创建页面 - 用于文本转语音转换
class TTSCreatePage extends ConsumerStatefulWidget {
  final String? initialText;

  const TTSCreatePage({super.key, this.initialText});

  @override
  ConsumerState<TTSCreatePage> createState() => _TTSCreatePageState();
}

class _TTSCreatePageState extends ConsumerState<TTSCreatePage> {
  final _textController = TextEditingController();
  final _titleController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isGenerating = false;
  String? _lastGeneratedFilePath;

  // 当前选中的模型配置
  ModelConfig? _modelConfig;

  // 当前选中的模型索引（null 表示未选择）
  int? _selectedModelIndex;

  // TTS 条目 ID（用于导航到配置页面）
  String? _ttsEntryId;

  // 当前 TTS 供应商下所有可用的模型列表（含所属供应商名称）
  List<_ModelOption> _availableModels = [];

  // instruction 参数控制器
  final _instructionController = TextEditingController();

  // 自定义参数值覆盖
  final Map<String, TextEditingController> _customParamControllers = {};

  // 当前选中的音色、语速、音量
  String _selectedVoice = '';
  double _speed = 1.0;
  double _volume = 1.0;

  // 当前模型的最大字数限制（0 表示未设置）
  int _maxWordsLimit = 0;

  @override
  void initState() {
    super.initState();
    // 如果传入了初始文本，填充到文本输入框
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _textController.text = widget.initialText!;
    }
    // 监听文本变化以刷新字数提示
    _textController.addListener(_onTextChanged);
    // 进入页面时清除上次残留的合成错误，避免旧错误持续显示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(ttsStateProvider.notifier).clearError();
      }
    });
  }

  void _onTextChanged() {
    // 触发 UI 刷新字数统计
    setState(() {});
  }

  /// 根据最新的 providerEntriesState 刷新可用模型列表
  void _refreshModels(ProviderEntriesState entriesState) {
    final ttsEntry = entriesState.entries.where((e) => e.name == 'TTS供应商').firstOrNull;

    // 未找到 TTS 条目时不做任何事（UI 会显示未配置提示）
    if (ttsEntry == null) {
      setState(() {
        _ttsEntryId = null;
        _modelConfig = null;
        _selectedModelIndex = null;
        _availableModels = [];
      });
      return;
    }

    // 聚合所有配置项中的模型
    final allModels = <_ModelOption>[];
    for (final configItem in ttsEntry.configs) {
      if (configItem.models.isEmpty) continue;
      for (final model in configItem.models) {
        allModels.add(_ModelOption(model, configItem));
      }
    }

    // 如果数据没变化就不触发重建
    final oldIds = _availableModels.map((e) => e.config.modelId).toList();
    final newIds = allModels.map((e) => e.config.modelId).toList();
    if (_listEquals(oldIds, newIds) && _ttsEntryId == ttsEntry.id) return;

    setState(() {
      _ttsEntryId = ttsEntry.id;
      if (allModels.isEmpty) {
        // 模型列表变空 → 清空当前选择
        _modelConfig = null;
        _selectedModelIndex = null;
        _availableModels = [];
        _customParamControllers.clear();
      } else {
        // 如果之前选的模型在列表中，保留选择
        final prevModelId = _modelConfig?.modelId;
        final stillExists = prevModelId != null && allModels.any((o) => o.config.modelId == prevModelId);
        if (!stillExists) {
          _modelConfig = null;
          _selectedModelIndex = null;
        } else {
          _selectedModelIndex = allModels.indexWhere((o) => o.config.modelId == prevModelId);
        }
        _availableModels = allModels;
        // 清理多余的 controller
        final keptKeys = _modelConfig?.customParams.map((p) => p.paramName).toSet() ?? {};
        _customParamControllers.removeWhere((k, _) => !keptKeys.contains(k));
        // 如果切换了模型，清空 instruction 输入
        _instructionController.clear();
      }
    });
  }

  bool _listEquals(List a, List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 跳转到 TTS 供应商配置页
  void _navigateToProviderConfig() {
    if (_ttsEntryId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProviderConfigPage(entryId: _ttsEntryId!),
        ),
      );
    } else {
      Navigator.pushNamed(context, '/settings');
    }
  }

  @override
  void dispose() {
    // 退出页面时清除合成错误
    ref.read(ttsStateProvider.notifier).clearError();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _titleController.dispose();
    _focusNode.dispose();
    _instructionController.dispose();
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
              _navigateToProviderConfig();
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

    // 清除上次的合成错误
    ref.read(ttsStateProvider.notifier).clearError();

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

      // 查找裁切预设
      Map<String, dynamic>? trimPreset;
      if (_modelConfig!.selectedTrimPresetId != null) {
        final customPresets = ref.read(customTrimPresetsProvider);
        trimPreset = getTrimPresetById(
            _modelConfig!.selectedTrimPresetId!, customPresets);
      }

      // 获取选中的供应商配置
      final modelOption = _availableModels[_selectedModelIndex!];

      // 收集自定义参数值
      final customParams = <String, String>{};
      for (final entry in _customParamControllers.entries) {
        customParams[entry.key] = entry.value.text;
      }
      // instruction 参数
      final instruction = _instructionController.text.trim();
      if (instruction.isNotEmpty) {
        customParams['instructions'] = instruction;
      }

      final title = _titleController.text.trim();

      final audioFile = await ref
          .read(ttsStateProvider.notifier)
          .synthesize(
            text,
            providerConfig: modelOption.providerConfig,
            modelConfig: modelOption.config,
            customParams: customParams,
            trimPreset: trimPreset,
            title: title,
          );

      if (audioFile != null) {
        _lastGeneratedFilePath = audioFile.storagePath;
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
    final entriesState = ref.watch(providerEntriesProvider);
    final ttsState = ref.watch(ttsStateProvider);

    // 响应式刷新模型列表（每次 provider 数据变化时自动重建）
    _refreshModels(entriesState);

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
            // 标题 + 文本输入区域（合并）
            _buildCombinedInputSection(),
            const SizedBox(height: 24),

            // 配置区域
            _buildConfigSection(),

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

  Widget _buildCombinedInputSection() {
    final limit = _maxWordsLimit;
    final textLen = _textController.text.length;
    final isOverLimit = limit > 0 && textLen > limit;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '录音标题',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: '输入录音标题（可选）',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const Divider(height: 24),
            const Text(
              '转换文本',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              focusNode: _focusNode,
              maxLines: 5,
              minLines: 3,
              decoration: InputDecoration(
                hintText: '请输入要转换为语音的文本...',
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.fullscreen, size: 20),
                      tooltip: '全屏编辑',
                      onPressed: _showFullscreenEditor,
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _textController.clear(),
                    ),
                  ],
                ),
                suffixIconConstraints: const BoxConstraints(minWidth: 72, minHeight: 0),
              ),
            ),
            const SizedBox(height: 8),
            // 字数统计与超出警告
            Row(
              children: [
                if (isOverLimit)
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 14, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          '文字超出限制（最多 $limit 字）',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Spacer(),
                Text(
                  limit > 0
                      ? '$textLen/$limit'
                      : textLen.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: isOverLimit ? Colors.red : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigSection() {
    final model = _modelConfig;

    // 没有可用模型 → 显示引导卡片
    if (_availableModels.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                '未检测到可用模型',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                '请先在供应商设置中添加模型，然后再返回此处选择。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _navigateToProviderConfig,
                icon: const Icon(Icons.settings),
                label: const Text('去配置供应商'),
              ),
            ],
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

            // 模型选择下拉列表
            _buildModelSelector(),
            const SizedBox(height: 16),

            // 选择了模型后才显示该模型的参数
            if (model != null) ...[
              // 音色选择（有条件）
              if (model.voices.isNotEmpty) ...[
                _buildVoiceSelector(model),
                const SizedBox(height: 16),
              ],

              // 语速控制（有条件）
              if (model.hasSpeed) ...[
                _buildSpeedSlider(model),
                const SizedBox(height: 16),
              ],

              // 音量控制（有条件）
              if (model.hasVolume) ...[
                _buildVolumeSlider(model),
                const SizedBox(height: 16),
              ],

              // instruction 参数（有条件）
              if (model.supportInstruction) ...[
                _buildInstructionField(),
                const SizedBox(height: 16),
              ],

              // 自定义参数（有条件）
              if (model.customParams.isNotEmpty) ...[
                _buildCustomParamsSection(model),
                const SizedBox(height: 16),
              ],

              // 跳转到供应商配置页面
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      children: [
                        const TextSpan(text: '在'),
                        TextSpan(
                          text: 'TTS供应商设置',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: (TapGestureRecognizer()
                            ..onTap = _navigateToProviderConfig),
                        ),
                        const TextSpan(text: '页面设置更多参数'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModelSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '选择模型',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: _selectedModelIndex,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '请选择一个模型',
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: List.generate(_availableModels.length, (i) {
            final opt = _availableModels[i];
            final label = opt.providerConfig.providerName.isNotEmpty
                ? opt.providerConfig.providerName
                : '供应商';
            return DropdownMenuItem<int>(
              value: i,
              child: Text('${opt.config.name} | $label'),
            );
          }),
          onChanged: (index) {
            if (index != null) {
              _onModelSelected(index);
            }
          },
        ),
      ],
    );
  }

  /// 打开全屏文本编辑对话框
  void _showFullscreenEditor() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    '编辑文本',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                    tooltip: '关闭',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: '请输入要转换为语音的文本...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onModelSelected(int index) {
    final opt = _availableModels[index];
    final model = opt.config;
    setState(() {
      _selectedModelIndex = index;
      _modelConfig = model;
      _maxWordsLimit = model.maxWordsPerRequest;
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

  Widget _buildInstructionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '语气指令（instruction）',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _instructionController,
          maxLines: 3,
          minLines: 2,
          decoration: const InputDecoration(
            hintText: '例如: Speak in a cheerful and excited tone',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '通过自然语言描述语气、情绪、语速、口音等，模型将据此调整合成语音的风格',
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
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
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.red),
              onPressed: () {
                ref.read(ttsStateProvider.notifier).clearError();
              },
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
