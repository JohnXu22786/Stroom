import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';

import '../providers/tts_state_provider.dart';
import '../providers/provider_config.dart';
import '../providers/tts_config.dart';
import '../providers/task_provider.dart';
import 'provider_config_page.dart';
import 'tts_create_shared.dart';

/// TTS创建页面 - 用于文本转语音转换
class TTSCreatePage extends ConsumerStatefulWidget {
  final String? initialText;
  final bool isOverwrite;
  final String? originalTitle;
  final SynthesisTask? retryTask;

  const TTSCreatePage(
      {super.key,
      this.initialText,
      this.isOverwrite = false,
      this.originalTitle,
      this.retryTask});

  @override
  ConsumerState<TTSCreatePage> createState() => _TTSCreatePageState();
}

class _TTSCreatePageState extends ConsumerState<TTSCreatePage> {
  final _textController = TextEditingController();
  final _titleController = TextEditingController();
  final _focusNode = FocusNode();

  // 当前选中的模型配置
  ModelConfig? _modelConfig;

  // 当前选中的模型索引（null 表示未选择）
  int? _selectedModelIndex;

  // TTS 条目 ID（用于导航到配置页面）
  String? _ttsEntryId;

  // 当前 TTS 供应商下所有可用的模型列表（含所属供应商名称）
  List<ModelOption> _availableModels = [];

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

  // 覆盖生成时是否使用原标题
  bool _useOriginalTitle = true;

  @override
  void initState() {
    super.initState();
    _initTaskData(); // 先处理 retryTask 再处理单独的 initialText/originalTitle（后者优先级更高）
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _textController.text = widget.initialText!;
    }
    if (widget.originalTitle != null &&
        widget.originalTitle!.isNotEmpty &&
        _useOriginalTitle) {
      _titleController.text = widget.originalTitle!;
    }
    _textController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(ttsStateProvider.notifier).clearError();
      }
    });
  }

  void _initTaskData() {
    final task = widget.retryTask;
    if (task == null) return;
    _textController.text = task.text;
    if (task.title.isNotEmpty) {
      _titleController.text = task.title;
    }
    // 预设 modelConfig 和 customParams，等 _refreshModels 加载后自动匹配选中
    _modelConfig = task.modelConfig;
    for (final p in task.modelConfig.customParams) {
      final override = task.customParams?[p.paramName];
      _customParamControllers[p.paramName] =
          TextEditingController(text: override ?? p.defaultValue);
    }
  }

  void _onTextChanged() {
    // 触发 UI 刷新字数统计
    setState(() {});
  }

  /// 根据最新的 providerEntriesState 刷新可用模型列表
  void _refreshModels(ProviderEntriesState entriesState) {
    final ttsEntry =
        entriesState.entries.where((e) => e.name == 'TTS供应商').firstOrNull;

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
    final allModels = <ModelOption>[];
    for (final configItem in ttsEntry.configs) {
      if (configItem.models.isEmpty) continue;
      for (final model in configItem.models) {
        allModels.add(ModelOption(model, configItem));
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
        final stillExists = prevModelId != null &&
            allModels.any((o) => o.config.modelId == prevModelId);
        if (!stillExists) {
          _modelConfig = null;
          _selectedModelIndex = null;
        } else {
          _selectedModelIndex =
              allModels.indexWhere((o) => o.config.modelId == prevModelId);
          if (_modelConfig!.voices.isNotEmpty) {
            _selectedVoice = _modelConfig!.voices.first.id;
          }
        }
        _availableModels = allModels;
        // 清理多余的 controller
        final keptKeys =
            _modelConfig?.customParams.map((p) => p.paramName).toSet() ?? {};
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

  void _generateSpeech() {
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

    // 保存当前配置
    final synthNotifier = ref.read(synthesisConfigProvider.notifier);
    if (_modelConfig!.voices.isNotEmpty) {
      // 异步保存，不等待
      synthNotifier.updateVoice(_selectedVoice);
    }
    synthNotifier.updateSpeed(_speed);
    synthNotifier.updateVolume(_volume);

    // 查找裁切预设
    Map<String, dynamic>? trimPreset;
    if (_modelConfig!.selectedTrimPresetId != null) {
      final customPresets = ref.read(customTrimPresetsProvider);
      trimPreset =
          getTrimPresetById(_modelConfig!.selectedTrimPresetId!, customPresets);
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

    // 添加到任务列表，在后台执行合成
    ref.read(taskListProvider.notifier).addTask(
          title: title.isNotEmpty
              ? title
              : (text.length > 20 ? text.substring(0, 20) : text),
          text: text,
          providerConfig: modelOption.providerConfig,
          modelConfig: modelOption.config,
          customParams: customParams,
          trimPreset: trimPreset,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已添加到任务列表，后台生成中…'),
        duration: Duration(seconds: 2),
      ),
    );

    // 返回上一页（录音文件页面）
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final entriesState = ref.watch(providerEntriesProvider);

    // 响应式刷新模型列表（每次 provider 数据变化时自动重建）
    _refreshModels(entriesState);

    return Scaffold(
      appBar: AppBar(
        title: const Text('生成录音'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 覆盖提示横幅
            if (widget.isOverwrite) _buildOverwriteBanner(),
            if (widget.isOverwrite) const SizedBox(height: 16),

            // 标题 + 文本输入区域（合并）
            _buildCombinedInputSection(),
            const SizedBox(height: 24),

            // 配置区域
            _buildConfigSection(),

            const SizedBox(height: 24),

            // 生成按钮
            _buildGenerateButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOverwriteBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        border: Border.all(color: Colors.orange.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 20, color: Colors.orange[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '将覆盖原音频文件。生成完成后，原录音将被替换。',
              style: TextStyle(
                color: Colors.orange[800],
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
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
            Row(
              children: [
                const Text(
                  '录音标题',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (widget.originalTitle != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 24,
                        child: Checkbox(
                          value: _useOriginalTitle,
                          onChanged: (v) {
                            setState(() {
                              _useOriginalTitle = v ?? true;
                              if (_useOriginalTitle) {
                                _titleController.text = widget.originalTitle!;
                              } else {
                                _titleController.clear();
                              }
                            });
                          },
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _useOriginalTitle = !_useOriginalTitle;
                            if (_useOriginalTitle) {
                              _titleController.text = widget.originalTitle!;
                            } else {
                              _titleController.clear();
                            }
                          });
                        },
                        child: Text(
                          '使用原标题',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: '输入录音标题（可选）',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                suffixIconConstraints:
                    const BoxConstraints(minWidth: 72, minHeight: 0),
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
                  limit > 0 ? '$textLen/$limit' : textLen.toString(),
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
      return SizedBox(
        width: double.infinity,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 48, color: Colors.orange),
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
          initialValue: _selectedModelIndex,
          key: ValueKey('model_$_selectedModelIndex'),
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
        _selectedVoice = model.voices.first.id;
      }
      // 初始化自定义参数控制器
      _customParamControllers.clear();
      for (final p in model.customParams) {
        _customParamControllers[p.paramName] =
            TextEditingController(text: p.defaultValue);
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
          initialValue: model.voices.any((v) => v.id == _selectedVoice)
              ? _selectedVoice
              : model.voices.first.id,
          key: ValueKey('voice_$_selectedVoice'),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '选择音色',
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: model.voices.map((v) {
            return DropdownMenuItem<String>(
              value: v.id,
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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: _speed,
          min: model.speedMin,
          max: model.speedMax,
          divisions:
              ((model.speedMax - model.speedMin) * 10).round().clamp(1, 100),
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
              _volume.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: _volume,
          min: model.volumeMin,
          max: model.volumeMax,
          divisions:
              ((model.volumeMax - model.volumeMin) * 10).round().clamp(1, 100),
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
        onPressed: _generateSpeech,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.audio_file),
            SizedBox(width: 12),
            Text('生成录音', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
