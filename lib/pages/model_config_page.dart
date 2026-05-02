import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/provider_config.dart';
import '../providers/tts_config.dart';

class ModelConfigPage extends ConsumerStatefulWidget {
  final String entryId;
  final int configIndex;
  final int modelIndex; // -1 for new model
  const ModelConfigPage({
    super.key,
    required this.entryId,
    required this.configIndex,
    required this.modelIndex,
  });

  @override
  ConsumerState<ModelConfigPage> createState() => _ModelConfigPageState();
}

class _ModelConfigPageState extends ConsumerState<ModelConfigPage> {
  final _nameController = TextEditingController();
  final _modelIdController = TextEditingController();
  final _volumeMinController = TextEditingController();
  final _volumeMaxController = TextEditingController();
  final _speedMinController = TextEditingController();
  final _speedMaxController = TextEditingController();


  List<VoiceEntry> _voices = [];
  List<CustomParam> _customParams = [];
  List<VoiceEntry> _initialVoices = [];
  List<CustomParam> _initialCustomParams = [];
  String _initialName = '';
  String _initialModelId = '';
  String _initialVolumeMin = '';
  String _initialVolumeMax = '';
  String _initialSpeedMin = '';
  String _initialSpeedMax = '';
  bool _initialSupportStream = false;
  String? _initialTrimPresetId;

  bool _isSaving = false;
  bool _supportStream = false;
  String? _selectedTrimPresetId;
  bool get _isEditing => widget.modelIndex >= 0;

  bool get _hasUnsavedChanges {
    if (_nameController.text.trim() != _initialName) return true;
    if (_modelIdController.text.trim() != _initialModelId) return true;
    if (_volumeMinController.text.trim() != _initialVolumeMin) return true;
    if (_volumeMaxController.text.trim() != _initialVolumeMax) return true;
    if (_speedMinController.text.trim() != _initialSpeedMin) return true;
    if (_speedMaxController.text.trim() != _initialSpeedMax) return true;
    if (_supportStream != _initialSupportStream) return true;
    if (_selectedTrimPresetId != _initialTrimPresetId) return true;
    if (_voices.length != _initialVoices.length) return true;
    for (int i = 0; i < _voices.length; i++) {
      if (i >= _initialVoices.length) return true;
      if (_voices[i].name != _initialVoices[i].name) return true;
      if (_voices[i].id != _initialVoices[i].id) return true;
    }
    if (_customParams.length != _initialCustomParams.length) return true;
    for (int i = 0; i < _customParams.length; i++) {
      if (i >= _initialCustomParams.length) return true;
      if (_customParams[i].paramName != _initialCustomParams[i].paramName) return true;
      if (_customParams[i].defaultValue != _initialCustomParams[i].defaultValue) return true;
    }
    return false;
  }

  ProviderEntry? get _entry {
    final state = ref.read(providerEntriesProvider);
    try {
      return state.entries.firstWhere((e) => e.id == widget.entryId);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  void _loadModel() {
    final entry = _entry;
    if (entry == null) return;

    if (widget.configIndex < 0 || widget.configIndex >= entry.configs.length) {
      _voices = [];
      _customParams = [];
      return;
    }
    final configModels = entry.configs[widget.configIndex].models;
    if (_isEditing && widget.modelIndex >= 0 && widget.modelIndex < configModels.length) {
      final model = configModels[widget.modelIndex];
      _nameController.text = model.name;
      _modelIdController.text = model.modelId;
      _voices = model.voices.map((v) => v.copy()).toList();
      _volumeMinController.text = model.hasVolume ? model.volumeMin.toString() : '';
      _volumeMaxController.text = model.hasVolume ? model.volumeMax.toString() : '';
      _speedMinController.text = model.hasSpeed ? model.speedMin.toString() : '';
      _speedMaxController.text = model.hasSpeed ? model.speedMax.toString() : '';
      _customParams = model.customParams.map((p) => p.copy()).toList();
      _supportStream = model.supportStream;
      _selectedTrimPresetId = model.selectedTrimPresetId;
    } else {
      _voices = [];
      _customParams = [];
      _supportStream = false;
      _selectedTrimPresetId = null;
    }
    _initialVoices = _voices.map((v) => v.copy()).toList();
    _initialCustomParams = _customParams.map((p) => p.copy()).toList();
    _initialName = _nameController.text.trim();
    _initialModelId = _modelIdController.text.trim();
    _initialVolumeMin = _volumeMinController.text.trim();
    _initialVolumeMax = _volumeMaxController.text.trim();
    _initialSpeedMin = _speedMinController.text.trim();
    _initialSpeedMax = _speedMaxController.text.trim();
    _initialSupportStream = _supportStream;
    _initialTrimPresetId = _selectedTrimPresetId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelIdController.dispose();
    _volumeMinController.dispose();
    _volumeMaxController.dispose();
    _speedMinController.dispose();
    _speedMaxController.dispose();

    super.dispose();
  }

  // ----------------------------------------------------------------
  // 音色管理
  // ----------------------------------------------------------------

  void _showAddVoiceDialog() {
    final nameCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加音色'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: '音色名称（选填）',
                hintText: '例如: 标准女生，不填则使用ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: idCtrl,
              decoration: const InputDecoration(
                labelText: '音色ID *',
                hintText: '例如: female',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final id = idCtrl.text.trim();
              if (id.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('音色ID为必填项'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              final name = nameCtrl.text.trim();
              setState(() {
                _voices.add(VoiceEntry(
                  name: name.isNotEmpty ? name : id,
                  id: id,
                ));
              });
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showEditVoiceDialog(int index) {
    final entry = _voices[index];
    final nameCtrl = TextEditingController(text: entry.name);
    final idCtrl = TextEditingController(text: entry.id);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑音色'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: '音色名称（选填）',
                hintText: '例如: 标准女生，不填则使用ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: idCtrl,
              decoration: const InputDecoration(
                labelText: '音色ID *',
                hintText: '例如: female',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final id = idCtrl.text.trim();
              if (id.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('音色ID为必填项'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              final name = nameCtrl.text.trim();
              setState(() {
                _voices[index] = VoiceEntry(
                  name: name.isNotEmpty ? name : id,
                  id: id,
                );
              });
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // 裁切预设管理
  // ----------------------------------------------------------------

  void _showAddTrimPresetDialog() {
    final nameCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    String direction = 'head';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('添加自定义裁切'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '切割方式名称 *',
                  hintText: '例如: 静音裁切',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationCtrl,
                decoration: const InputDecoration(
                  labelText: '切割时长（秒） *',
                  hintText: '例如: 0.123',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('开头'),
                    selected: direction == 'head',
                    onSelected: (_) => setDlgState(() => direction = 'head'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('结尾'),
                    selected: direction == 'tail',
                    onSelected: (_) => setDlgState(() => direction = 'tail'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final durationText = durationCtrl.text.trim();
                if (name.isEmpty || durationText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('名称和时长为必填项'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                final duration = double.tryParse(durationText);
                if (duration == null || duration <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('请输入有效的时长（正数）'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                final preset = TrimPreset(
                  name: name,
                  durationSeconds: duration,
                  direction: direction,
                );
                await ref.read(customTrimPresetsProvider.notifier).add(preset);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTrimPresetDialog(TrimPreset preset) {
    final nameCtrl = TextEditingController(text: preset.name);
    final durationCtrl = TextEditingController(
      text: preset.durationSeconds.toString(),
    );
    String direction = preset.direction;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('编辑自定义裁切'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '切割方式名称 *',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationCtrl,
                decoration: const InputDecoration(
                  labelText: '切割时长（秒） *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('开头'),
                    selected: direction == 'head',
                    onSelected: (_) => setDlgState(() => direction = 'head'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('结尾'),
                    selected: direction == 'tail',
                    onSelected: (_) => setDlgState(() => direction = 'tail'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final durationText = durationCtrl.text.trim();
                if (name.isEmpty || durationText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('名称和时长为必填项'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                final duration = double.tryParse(durationText);
                if (duration == null || duration <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('请输入有效的时长（正数）'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                final updated = TrimPreset(
                  id: preset.id,
                  name: name,
                  durationSeconds: duration,
                  direction: direction,
                );
                await ref.read(customTrimPresetsProvider.notifier).update(preset.id, updated);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  /// 获取当前选中的裁切预设名称（用于显示）
  String _getTrimPresetLabel(String? presetId, List<TrimPreset> customPresets) {
    if (presetId == null) {
      // 默认显示内置的 "不裁切"
      final nonePreset = getBuiltinTrimPresets().firstWhere(
        (p) => p['id'] == BuiltinTrimPresetIds.none,
      );
      return nonePreset['name'] as String;
    }
    final all = getAllTrimPresets(customPresets);
    for (final p in all) {
      if (p['id'] == presetId) {
        final direction = p['direction'] as String;
        final dirLabel = direction == 'head' ? '开头' : '结尾';
        final name = p['name'] as String;
        final duration = p['durationSeconds'] as double;
        return '$name（${dirLabel}，${duration.toStringAsFixed(3)}s）';
      }
    }
    return '不裁切';
  }

  // ----------------------------------------------------------------
  // 自定义参数管理
  // ----------------------------------------------------------------

  void _addCustomParam() {
    setState(() {
      _customParams.insert(0, CustomParam(paramName: '', defaultValue: ''));
    });
  }

  void _removeCustomParam(int index) {
    setState(() {
      _customParams.removeAt(index);
    });
  }

  // ----------------------------------------------------------------
  // 音色管理工具
  // ----------------------------------------------------------------

  Future<void> _confirmDeleteVoice(int index) async {
    final voice = _voices[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除音色'),
        content: Text('确定要删除音色"${voice.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _voices.removeAt(index));
    }
  }


  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // 保存
  // ----------------------------------------------------------------

  Future<void> _save() async {
    final entry = _entry;
    if (entry == null) return;

    // 验证模型ID必填
    final modelId = _modelIdController.text.trim();
    if (modelId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('模型ID为必填项'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 验证自定义参数：每个参数都必须有参数名和默认值，且参数名不能重复
    final seenNames = <String>{};
    for (int i = 0; i < _customParams.length; i++) {
      final param = _customParams[i];
      final name = param.paramName.trim();
      if (name.isEmpty || param.defaultValue.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('自定义参数的参数名和默认值不能为空'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (!seenNames.add(name)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已存在该参数: $name'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    // 验证音量范围：必须成对填写或同时留空
    final volMinText = _volumeMinController.text.trim();
    final volMaxText = _volumeMaxController.text.trim();
    if (volMinText.isNotEmpty != volMaxText.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('音量范围必须成对填写（最小音量和最大音量），或者同时留空'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isSaving = false);
      return;
    }

    // 验证语速范围：必须成对填写或同时留空
    final spdMinText = _speedMinController.text.trim();
    final spdMaxText = _speedMaxController.text.trim();
    if (spdMinText.isNotEmpty != spdMaxText.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('语速范围必须成对填写（最小语速和最大语速），或者同时留空'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isSaving = false);
      return;
    }

    setState(() => _isSaving = true);

    // 自动填充：如果模型名称为空，使用模型ID
    var name = _nameController.text.trim();
    if (name.isEmpty && modelId.isNotEmpty) {
      name = modelId;
    }

    final hasVolume = _volumeMinController.text.trim().isNotEmpty ||
        _volumeMaxController.text.trim().isNotEmpty;
    final hasSpeed = _speedMinController.text.trim().isNotEmpty ||
        _speedMaxController.text.trim().isNotEmpty;

    final modelConfig = ModelConfig(
      name: name,
      modelId: modelId,
      voices: _voices.map((v) => v.copy()).toList(),
      volumeMin: double.tryParse(_volumeMinController.text) ?? 0.1,
      volumeMax: double.tryParse(_volumeMaxController.text) ?? 2.0,
      speedMin: double.tryParse(_speedMinController.text) ?? 0.5,
      speedMax: double.tryParse(_speedMaxController.text) ?? 2.0,
      hasVolume: hasVolume,
      hasSpeed: hasSpeed,
      customParams: _customParams.map((p) => p.copy()).toList(),
      supportStream: _supportStream,
      selectedTrimPresetId: _selectedTrimPresetId,
    );

    var configs = entry.configs.map((c) => c.copy()).toList();
    var models = List<ModelConfig>.from(configs[widget.configIndex].models);

    if (_isEditing && widget.modelIndex >= 0 && widget.modelIndex < models.length) {
      models[widget.modelIndex] = modelConfig;
    } else {
      models.insert(0, modelConfig);
    }

    configs[widget.configIndex] = ProviderConfigItem(
      providerName: configs[widget.configIndex].providerName,
      host: configs[widget.configIndex].host,
      key: configs[widget.configIndex].key,
      models: models,
    );

    final updated = ProviderEntry(
      id: entry.id,
      name: entry.name,
      configs: configs,
    );

    await ref.read(providerEntriesProvider.notifier).update(entry.id, updated);

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('模型已保存'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    if (!_isEditing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除模型'),
        content: const Text('确定要删除此模型吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final entry = _entry;
    if (entry == null) return;

    var configs = entry.configs.map((c) => c.copy()).toList();
    if (widget.configIndex < 0 || widget.configIndex >= configs.length) return;
    var models = List<ModelConfig>.from(configs[widget.configIndex].models);
    if (widget.modelIndex >= 0 && widget.modelIndex < models.length) {
      models.removeAt(widget.modelIndex);
    }
    configs[widget.configIndex] = ProviderConfigItem(
      providerName: configs[widget.configIndex].providerName,
      host: configs[widget.configIndex].host,
      key: configs[widget.configIndex].key,
      models: models,
    );

    final updated = ProviderEntry(
      id: entry.id,
      name: entry.name,
      configs: configs,
    );

    await ref.read(providerEntriesProvider.notifier).update(entry.id, updated);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing
        ? (_nameController.text.isNotEmpty ? _nameController.text : '编辑模型')
        : '新建模型';

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('放弃修改？'),
            content: const Text('当前有未保存的修改，确定要放弃吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('继续编辑'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('放弃'),
              ),
            ],
          ),
        );
        if (discard == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save, size: 20),
            label: Text(_isSaving ? '保存中...' : '保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ==========================================================
          // 模型名称
          // ==========================================================
          Row(
            children: [
              const Text('模型名称', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showInfoDialog(
                  '模型名称',
                  '模型名称是用于显示和识别的友好名称，例如"GPT-4o Mini TTS"。\n\n同一个供应商下多个模型时，通过名称可以快速区分它们。',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: '输入模型名称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================================
          // 模型ID
          // ==========================================================
          Row(
            children: [
              const Text('模型ID *', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showInfoDialog(
                  '模型ID',
                  '模型ID是调用API时使用的唯一标识符，例如"gpt-4o-mini-tts"。\n\nAPI请求时以此ID指定要使用的模型，必须与供应商提供的模型ID一致。',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _modelIdController,
            decoration: const InputDecoration(
              hintText: '输入模型ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================================
          // 音量范围
          // ==========================================================
          const Text('音量范围', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _volumeMinController,
                  decoration: const InputDecoration(
                    labelText: '最小音量',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              const Text('~'),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _volumeMaxController,
                  decoration: const InputDecoration(
                    labelText: '最大音量',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ==========================================================
          // 语速范围
          // ==========================================================
          const Text('语速范围', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _speedMinController,
                  decoration: const InputDecoration(
                    labelText: '最小语速',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              const Text('~'),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _speedMaxController,
                  decoration: const InputDecoration(
                    labelText: '最大语速',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ==========================================================
          // 音色列表
          // ==========================================================
          Row(
            children: [
              const Text('音色', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showInfoDialog(
                  '音色',
                  '音色名称是给用户看的人名，如"标准女生"。\n\n音色ID是调用API时使用的标识符，如"female"。\n\n添加音色时两项都需要填写。',
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加音色'),
                onPressed: _showAddVoiceDialog,
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_voices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('暂无音色',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) newIndex -= 1;
                setState(() {
                  final item = _voices.removeAt(oldIndex);
                  _voices.insert(newIndex, item);
                });
              },
              proxyDecorator: (child, index, animation) => Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(8),
                child: child,
              ),
              children: List.generate(_voices.length, (i) {
                final v = _voices[i];
                return Padding(
                  key: ValueKey('voice_$i'),
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.drag_indicator,
                              color: Colors.grey, size: 22),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Text(v.name,
                                style: const TextStyle(fontSize: 13)),
                            if (v.id.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(v.id,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600])),
                            ],
                          ],
                        ),
                      ),
                      // 编辑按钮
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                        onPressed: () => _showEditVoiceDialog(i),
                        tooltip: '编辑音色',
                      ),
                      // 删除按钮
                      IconButton(
                        icon: const Icon(Icons.close,
                            size: 18, color: Colors.red),
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                        onPressed: () => _confirmDeleteVoice(i),
                        tooltip: '删除音色',
                      ),
                    ],
                  ),
                );
              }),
            ),
          const SizedBox(height: 16),

          // ==========================================================
          // 自定义参数
          // ==========================================================
          Row(
            children: [
              const Text('自定义参数',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加参数'),
                onPressed: _addCustomParam,
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_customParams.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('暂无自定义参数',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...List.generate(_customParams.length, (i) {
              final param = _customParams[i];
              // 检查当前参数名是否与其他参数重复
              final name = param.paramName.trim();
              final isDuplicate = name.isNotEmpty &&
                  _customParams.indexWhere(
                          (p) => p.paramName.trim() == name) !=
                      i;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                                  initialValue: param.paramName,
                                  decoration: InputDecoration(
                                    labelText: '参数名',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    errorText: isDuplicate ? '已存在该参数' : null,
                                    errorStyle: const TextStyle(fontSize: 11),
                                  ),
                                  onChanged: (v) {
                                    param.paramName = v;
                                    setState(() {});
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                          // 类型选择
                          Container(
                            width: 110,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: param.type,
                                isDense: true,
                                items: ParamType.values
                                    .map((t) => DropdownMenuItem(
                                          value: t.value,
                                          child: Text(t.label,
                                              style:
                                                  const TextStyle(fontSize: 13)),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => param.type = v);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.red, size: 20),
                            onPressed: () => _removeCustomParam(i),
                            tooltip: '删除参数',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: param.defaultValue,
                        decoration: InputDecoration(
                          labelText: '默认参数值',
                          hintText: param.paramType.defaultValueHint,
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) => param.defaultValue = v,
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          param.paramType.needsQuotes
                              ? '在请求格式中生成: "{{${param.paramName}}}"'
                              : '在请求格式中生成: {{${param.paramName}}}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: 16),

          // ==========================================================
          // 流式输出开关
          // ==========================================================
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.stream, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('模型是否支持流式输出'),
                        Text(
                          '开启后部分需要流式输出的场景将可以使用该模型，请确认模型支持流式输出再开启',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildToggleButton('是', true),
                  const SizedBox(width: 8),
                  _buildToggleButton('否', false),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ==========================================================
          // 裁切设置
          // ==========================================================
          _buildTrimSection(),
          const SizedBox(height: 8),

          const SizedBox(height: 16),
        ],
      ),
    ),
  );
  }

  Widget _buildTrimSection() {
    final customPresets = ref.watch(customTrimPresetsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.content_cut, size: 20),
                const SizedBox(width: 8),
                const Text('裁切设置',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16)),
                const Spacer(),
                if (_selectedTrimPresetId != null &&
                    _selectedTrimPresetId != BuiltinTrimPresetIds.none)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getTrimPresetLabel(
                          _selectedTrimPresetId, customPresets),
                      style: TextStyle(
                          fontSize: 11, color: Colors.orange[800]),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('选择对音频进行裁切的方式',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),

            // 内置预设
            ...getBuiltinTrimPresets().map((preset) {
              final presetId = preset['id'] as String;
              return RadioListTile<String?>(
                title: Text(preset['name'] as String),
                subtitle: Text(
                  presetId == BuiltinTrimPresetIds.none
                      ? '不对音频做任何裁切'
                      : '裁切开头 ${preset['durationSeconds']}s',
                  style: const TextStyle(fontSize: 12),
                ),
                value: preset['id'] as String,
                groupValue:
                    _selectedTrimPresetId ?? BuiltinTrimPresetIds.none,
                onChanged: (v) => setState(() => _selectedTrimPresetId = v),
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            }),

            // 分割线
            if (customPresets.isNotEmpty) const Divider(),

            // 自定义预设
            if (customPresets.isNotEmpty)
              ...customPresets.asMap().entries.map((entry) {
                final preset = entry.value;
                final dirLabel = preset.direction == 'head' ? '开头' : '结尾';
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Radio<String?>(
                    value: preset.id,
                    groupValue: _selectedTrimPresetId ?? BuiltinTrimPresetIds.none,
                    onChanged: (v) =>
                        setState(() => _selectedTrimPresetId = v),
                  ),
                  title: Text(preset.name, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '裁切$dirLabel ${preset.durationSeconds.toStringAsFixed(3)}s',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => _showEditTrimPresetDialog(preset),
                        tooltip: '编辑',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            size: 18, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('删除裁切预设'),
                              content: Text(
                                  '确定要删除裁切预设"${preset.name}"吗？'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: TextButton.styleFrom(
                                      foregroundColor: Colors.red),
                                  child: const Text('删除'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ref
                                .read(customTrimPresetsProvider.notifier)
                                .remove(preset.id);
                            // 如果当前选中的是这个预设，重置为不裁切
                            if (_selectedTrimPresetId == preset.id) {
                              setState(() => _selectedTrimPresetId = null);
                            }
                          }
                        },
                        tooltip: '删除',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                );
              }),

            // 添加按钮
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加自定义裁切'),
                onPressed: _showAddTrimPresetDialog,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(String label, bool value) {
    final isSelected = _supportStream == value;
    return GestureDetector(
      onTap: () => setState(() => _supportStream = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
