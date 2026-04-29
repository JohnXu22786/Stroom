import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../providers/provider_config.dart';

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
  final _streamUrlController = TextEditingController();

  List<VoiceEntry> _voices = [];
  List<CustomParam> _customParams = [];

  bool _isSaving = false;
  bool _supportStream = false;
  bool get _isEditing => widget.modelIndex >= 0;

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
      _volumeMinController.text = model.volumeMin.toString();
      _volumeMaxController.text = model.volumeMax.toString();
      _speedMinController.text = model.speedMin.toString();
      _speedMaxController.text = model.speedMax.toString();
      _customParams = model.customParams.map((p) => p.copy()).toList();
      _supportStream = model.supportStream;
      _streamUrlController.text = model.streamUrl;
    } else {
      _voices = [];
      _customParams = [];
      _supportStream = false;
      _streamUrlController.text = '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelIdController.dispose();
    _volumeMinController.dispose();
    _volumeMaxController.dispose();
    _speedMinController.dispose();
    _speedMaxController.dispose();
    _streamUrlController.dispose();
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
                labelText: '音色名称',
                hintText: '例如: 标准女生',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: idCtrl,
              decoration: const InputDecoration(
                labelText: '音色ID',
                hintText: '例如: female',
                border: OutlineInputBorder(),
              ),
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
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  _voices.add(VoiceEntry(name: name, id: idCtrl.text.trim()));
                });
              }
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
                labelText: '音色名称',
                hintText: '例如: 标准女生',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: idCtrl,
              decoration: const InputDecoration(
                labelText: '音色ID',
                hintText: '例如: female',
                border: OutlineInputBorder(),
              ),
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
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  _voices[index] = VoiceEntry(name: name, id: idCtrl.text.trim());
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
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
  // 信息提示
  // ----------------------------------------------------------------

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

    // 验证自定义参数：每个参数都必须有参数名和默认值
    for (int i = 0; i < _customParams.length; i++) {
      final param = _customParams[i];
      if (param.paramName.trim().isEmpty || param.defaultValue.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('自定义参数的参数名和默认值不能为空'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
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
      streamUrl: _streamUrlController.text.trim(),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: '删除模型',
              onPressed: _delete,
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
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: List.generate(_voices.length, (i) {
                final v = _voices[i];
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      label: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(v.name, style: const TextStyle(fontSize: 13)),
                          if (v.id.isNotEmpty)
                            Text(v.id,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[600])),
                        ],
                      ),
                      deleteIcon: const Icon(Icons.edit, size: 18),
                      onDeleted: () => _showEditVoiceDialog(i),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.red),
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() => _voices.removeAt(i));
                      },
                    ),
                  ],
                );
              }),
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
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: '参数名',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              controller: TextEditingController(
                                text: param.paramName,
                              ),
                              onChanged: (v) => param.paramName = v,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.red, size: 20),
                            onPressed: () => _removeCustomParam(i),
                            tooltip: '删除参数',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: '默认参数值',
                          hintText: '输入默认值',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        controller: TextEditingController(
                          text: param.defaultValue,
                        ),
                        onChanged: (v) => param.defaultValue = v,
                      ),
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: 24),

          // ==========================================================
          // 流式输出开关
          // ==========================================================
          Card(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('支持流式输出'),
                  subtitle: const Text('开启后将检测接口是否支持流式输出'),
                  value: _supportStream,
                  onChanged: (v) async {
                    if (v) {
                      final url = _streamUrlController.text.trim();
                      if (url.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('请先填写流式接口地址'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      setState(() => _supportStream = true);
                      try {
                        final dio = Dio(BaseOptions(
                          connectTimeout: const Duration(seconds: 10),
                          receiveTimeout: const Duration(seconds: 15),
                        ));
                        await dio.post(
                          url,
                          data: {
                            'model': _modelIdController.text.trim(),
                            'messages': [
                              {'role': 'user', 'content': 'hi'}
                            ],
                            'stream': true,
                          },
                        );
                      } catch (e) {
                        setState(() => _supportStream = false);
                        if (!mounted) return;
                        await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('检测失败'),
                            content: const Text('检测失败，该接口不支持流式输出'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('知道了'),
                              ),
                            ],
                          ),
                        );
                      }
                    } else {
                      setState(() => _supportStream = false);
                    }
                  },
                  secondary: const Icon(Icons.stream),
                ),
                if (_supportStream)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: _streamUrlController,
                      decoration: const InputDecoration(
                        labelText: '流式接口地址',
                        hintText: 'https://api.example.com/v1/chat/completions',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ==========================================================
          // 保存按钮
          // ==========================================================
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? '保存中...' : '保存模型'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
