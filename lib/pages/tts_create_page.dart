import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';

import '../providers/tts_state_provider.dart';
import '../providers/provider_config.dart';
import '../providers/tts_config.dart';
import '../providers/task_provider.dart';
import '../utils/file_manifest.dart';
import '../widgets/folder_picker_dialog.dart';
import 'provider_config_page.dart';
import 'tts_create_shared.dart';

/// TTS创建页面 - 用于文本转语音转换
///
/// 布局与 OCR / 音频转写（ASR）页面保持一致：
/// 顶部模型选择器、中间滚动输入/配置区、底部保存位置选择器 + 生成按钮。
class TTSCreatePage extends ConsumerStatefulWidget {
  final String? initialText;
  final bool isOverwrite;
  final String? originalTitle;
  final String? initialFolder;
  final SynthesisTask? retryTask;

  const TTSCreatePage(
      {super.key,
      this.initialText,
      this.isOverwrite = false,
      this.originalTitle,
      this.initialFolder,
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

  /// 表单校验错误（显示在底部错误横幅中，样式与 OCR/ASR 页面一致）
  String? _errorMessage;

  /// "请输入要转换的文本" 错误横幅是否正在显示。用标志位而不是
  /// 字符串比较，避免文案改动后自动收起逻辑静默失效。
  bool _textErrorShown = false;

  /// 生成的音频保存到的文件夹路径（空字符串表示根目录）
  String _saveFolder = '';

  /// 重试任务预设的模型 ID。provider 异步加载完成前，_refreshModels
  /// 可能先以空条目集运行 —— 保留该 ID 以便加载完成后仍能匹配到
  /// 重试任务的模型（否则会静默回退到第一个模型）。
  String? _retryModelId;

  /// 重试任务预设的 instruction 文本。_refreshModels 会在模型列表
  /// 刷新时清空输入框，需在首次刷新后重新恢复。
  String? _retryInstruction;

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
    // 覆盖生成时沿用原音频所在的文件夹（重试任务在 _initTaskData 中恢复）
    if (widget.initialFolder != null && widget.initialFolder!.isNotEmpty) {
      _saveFolder = widget.initialFolder!;
    }
    _textController.addListener(_onTextChanged);
    _titleController.addListener(_onTextChanged);
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
    _retryModelId = task.modelConfig.modelId;
    // 语速/音量限制随模型变化，越界值会导致 Slider 断言失败
    _clampSpeedVolume(task.modelConfig);
    for (final p in task.modelConfig.customParams) {
      final override = task.customParams?[p.paramName];
      _customParamControllers[p.paramName] =
          TextEditingController(text: override ?? p.defaultValue);
    }
    // 重试时沿用原任务选择的保存文件夹
    if (task.folder.isNotEmpty) {
      _saveFolder = task.folder;
    }
    // 恢复 instruction（生成时保存在 customParams['instructions'] 中）
    final instruction = task.customParams?['instructions'];
    if (instruction != null && instruction.trim().isNotEmpty) {
      _instructionController.text = instruction;
      _retryInstruction = instruction;
    }
  }

  void _onTextChanged() {
    // 触发 UI 刷新字数统计；文本已非空时收起"请输入要转换的文本"横幅
    if (_textErrorShown && _textController.text.trim().isNotEmpty) {
      _textErrorShown = false;
      _errorMessage = null;
    }
    setState(() {});
  }

  /// 根据最新的 providerEntriesState 刷新可用模型列表
  void _refreshModels(ProviderEntriesState entriesState) {
    final ttsEntry =
        entriesState.entries.where((e) => e.name == 'TTS供应商').firstOrNull;

    // 未找到 TTS 条目时不做任何事（UI 会显示未配置提示）。
    // 重试预设的 _modelConfig 保留，避免 provider 异步加载期间（条目
    // 暂时为空）丢失重试任务的模型选择。
    if (ttsEntry == null) {
      setState(() {
        _ttsEntryId = null;
        _availableModels = [];
        if (_retryModelId == null) {
          _modelConfig = null;
          _selectedModelIndex = null;
        }
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
        // 模型列表变空 → 清空当前选择。重试预设期间保留自定义参数
        // 控制器（其中保存着重试任务的参数覆盖值），等模型恢复后沿用
        _modelConfig = null;
        _selectedModelIndex = null;
        _availableModels = [];
        if (_retryModelId == null) {
          _disposeCustomParamControllers();
        }
      } else {
        // 如果之前选的模型在列表中，保留选择
        final prevSelectedModelId = _modelConfig?.modelId;
        final prevModelId = _modelConfig?.modelId ?? _retryModelId;
        final stillExists = prevModelId != null &&
            allModels.any((o) => o.config.modelId == prevModelId);
        if (!stillExists) {
          // 自动选中第一个模型（与 OCR/ASR 页面行为一致）
          _applyModelSelection(allModels.first, 0);
        } else {
          final matched = allModels[
              allModels.indexWhere((o) => o.config.modelId == prevModelId)];
          _selectedModelIndex =
              allModels.indexWhere((o) => o.config.modelId == prevModelId);
          _maxWordsLimit = matched.config.maxWordsPerRequest;
          // _modelConfig 可能在模型列表为空的分支被清空（重试预设
          // 期间），此时按匹配到的模型重建，避免空解引用崩溃
          final mc = _modelConfig ?? matched.config;
          if (mc.voices.isNotEmpty) {
            _selectedVoice = mc.voices.first.id;
          }
          _modelConfig = mc;
          // 以 Slider 实际渲染所用实例（mc）为基准限制语速/音量
          _clampSpeedVolume(mc);
        }
        final retryInstruction = _retryInstruction;
        _retryModelId = null;
        // 首次成功同步后不再保留重试指令：文本要么未经过清空（保留在
        // 输入框中），要么已在下方分支恢复 —— 避免后续模型列表变化时
        // 重新注入原始指令覆盖用户后续输入
        _retryInstruction = null;
        _availableModels = allModels;
        // 清理多余的 controller（释放被移除的）
        final keptKeys =
            _modelConfig?.customParams.map((p) => p.paramName).toSet() ?? {};
        final removed =
            _customParamControllers.keys.where((k) => !keptKeys.contains(k));
        for (final k in removed) {
          _customParamControllers.remove(k)?.dispose();
        }
        // 仅在选中模型确实发生变化时清空 instruction（重试恢复的除外）
        if (_modelConfig?.modelId != prevSelectedModelId) {
          _instructionController.clear();
          if (retryInstruction != null) {
            _instructionController.text = retryInstruction;
          }
        }
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
    _titleController.removeListener(_onTextChanged);
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

  void _generateSpeech() {
    if (!_isTTSConfigured() ||
        _availableModels.isEmpty ||
        _selectedModelIndex == null ||
        _selectedModelIndex! >= _availableModels.length) {
      setState(() {
        _errorMessage = '请先在设置中配置语音合成供应商和模型';
        _textErrorShown = false;
      });
      return;
    }

    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorMessage = '请输入要转换的文本';
        _textErrorShown = true;
      });
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
          folder: _saveFolder,
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

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('语音合成'),
        centerTitle: true,
        actions: [
          if (_textController.text.isNotEmpty ||
              _titleController.text.isNotEmpty)
            TextButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('清空'),
            ),
        ],
      ),
      body: Column(
        children: [
          // 模型选择器（样式与 OCR/ASR 页面一致）
          _buildModelSelector(cs),

          // 滚动区：输入 + 合成配置
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 覆盖提示横幅
                  if (widget.isOverwrite) _buildOverwriteBanner(),
                  if (widget.isOverwrite) const SizedBox(height: 16),

                  // 标题 + 文本输入区域（合并）
                  _buildCombinedInputSection(),
                  const SizedBox(height: 16),

                  // 配置区域
                  _buildConfigSection(),
                ],
              ),
            ),
          ),

          // 表单校验错误
          if (_errorMessage != null) _buildErrorBanner(cs),

          // 底部：保存位置选择 + 生成按钮
          _buildBottomBar(cs),
        ],
      ),
    );
  }

  void _clearAll() {
    // 重置重试预设与指令输入：清空后不再把重试的模型/指令/自定义参数
    // 重新套用（模型本身的选择保留，仅不再回退到重试预设）
    _retryModelId = null;
    _retryInstruction = null;
    _instructionController.clear();
    _textController.clear();
    _titleController.clear();
    setState(() {
      _errorMessage = null;
      _textErrorShown = false;
    });
  }

  // ==================================================================
  // 模型选择器 — 与 OCR/ASR 页面一致的胶囊式下拉框
  // ==================================================================

  Widget _buildModelSelector(ColorScheme cs) {
    // 未配置任何模型 → 显示去配置提示（与 OCR/ASR 页面一致）
    if (_availableModels.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cs.errorContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cs.error.withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 20, color: cs.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '合成模型',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: _navigateToProviderConfig,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: cs.error,
                ),
                child: const Text(
                  '去配置',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final clampedIndex =
        (_selectedModelIndex ?? 0).clamp(0, _availableModels.length - 1);
    if (clampedIndex != _selectedModelIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedModelIndex = clampedIndex;
          });
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              // 机器人图标，与对话页面输入框的模型标识一致（同 OCR 页面）
              child: Icon(Icons.smart_toy_outlined, size: 16, color: cs.primary),
            ),
            const SizedBox(width: 10),
            Text(
              '合成模型',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 34,
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: clampedIndex,
                    isDense: true,
                    isExpanded: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: cs.primary,
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                    onChanged: (idx) {
                      if (idx == null || idx >= _availableModels.length) return;
                      _onModelSelected(idx);
                    },
                    items: List.generate(_availableModels.length, (i) {
                      final opt = _availableModels[i];
                      final modelName = opt.config.name.isNotEmpty
                          ? opt.config.name
                          : opt.config.modelId;
                      final displayText = opt
                              .providerConfig.providerName.isNotEmpty
                          ? '$modelName | ${opt.providerConfig.providerName}'
                          : modelName;
                      return DropdownMenuItem<int>(
                        value: i,
                        child: Text(
                          displayText,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 应用某个模型的选中状态（初始化音色、字数限制与自定义参数控制器）
  void _applyModelSelection(ModelOption opt, int index) {
    final model = opt.config;
    _modelConfig = model;
    _selectedModelIndex = index;
    _maxWordsLimit = model.maxWordsPerRequest;
    if (model.voices.isNotEmpty) {
      _selectedVoice = model.voices.first.id;
    }
    // 语速/音量限制随模型变化，越界值会导致 Slider 断言失败
    _clampSpeedVolume(model);
    _disposeCustomParamControllers();
    for (final p in model.customParams) {
      _customParamControllers[p.paramName] =
          TextEditingController(text: p.defaultValue);
    }
  }

  /// 将当前语速/音量限制在模型的允许范围内
  void _clampSpeedVolume(ModelConfig model) {
    _speed = _speed.clamp(model.speedMin, model.speedMax);
    _volume = _volume.clamp(model.volumeMin, model.volumeMax);
  }

  /// 释放并清空所有自定义参数控制器，避免页面存活期间累积泄漏
  void _disposeCustomParamControllers() {
    for (final c in _customParamControllers.values) {
      c.dispose();
    }
    _customParamControllers.clear();
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

    // 未配置模型时由顶部"合成模型"选择器显示配置引导，这里不再重复提示
    if (_availableModels.isEmpty || model == null) {
      return const SizedBox.shrink();
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
        ),
      ),
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
    setState(() {
      _applyModelSelection(opt, index);
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

  // ==================================================================
  // 底部：保存位置选择 + 生成按钮（与 OCR/ASR 页面一致）
  // ==================================================================

  Widget _buildBottomBar(ColorScheme cs) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 保存位置选择器（生成按钮上方）
            _buildSaveToSelector(cs),
            const SizedBox(height: 4),
            // 生成文件的路径预览（标题/文本非空时显示完整路径）
            if (_textController.text.trim().isNotEmpty ||
                _titleController.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _filePathPreview(),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _generateSpeech,
                icon: const Icon(Icons.audio_file, size: 20),
                label: const Text(
                  '生成录音',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 生成文件的保存路径预览：{文件夹}/{标题或文本摘要}.{格式}
  /// 文件夹为应用内音频库（tts_audio）中的 manifest 分组路径。
  String _filePathPreview() {
    final folder = _saveFolder.isEmpty ? '根目录' : _saveFolder;
    final title = _titleController.text.trim();
    final text = _textController.text.trim();
    final name = title.isNotEmpty
        ? title
        : (text.isEmpty
            ? '录音'
            : (text.length > 20 ? text.substring(0, 20) : text));
    final format = ref.read(synthesisConfigProvider).format;
    return '将保存为: $folder/$name.$format';
  }

  Widget _buildSaveToSelector(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _pickSaveFolder,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.folder_outlined, size: 16, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                '保存至',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _saveFolder.isEmpty ? '根目录' : _saveFolder,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.primary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickSaveFolder() async {
    final folders = await FileManifest.getAllFolders();
    if (!mounted) return;
    final result = await FolderPickerDialog.show(
      context,
      currentFolder: _saveFolder,
      availableFolders: folders,
      title: '选择保存文件夹',
      onCreateFolder: (name) async {
        await FileManifest.addFolder(name);
        return null;
      },
      onRefreshFolders: () async => FileManifest.getAllFolders(),
    );
    if (result != null && mounted) {
      setState(() => _saveFolder = result);
    }
  }

  // ==================================================================
  // 错误横幅（与 OCR/ASR 页面一致）
  // ==================================================================

  Widget _buildErrorBanner(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: cs.errorContainer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.error_outline,
              color: cs.onErrorContainer,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: cs.onErrorContainer, size: 18),
            onPressed: () => setState(() {
              _errorMessage = null;
              _textErrorShown = false;
            }),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
