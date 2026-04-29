import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tts_config.dart';
import '../providers/tts_state_provider.dart';

class TTSModelConfigPage extends ConsumerStatefulWidget {
  final String providerId;
  final int modelIndex; // -1 for new model
  const TTSModelConfigPage({
    super.key,
    required this.providerId,
    required this.modelIndex,
  });

  @override
  ConsumerState<TTSModelConfigPage> createState() =>
      _TTSModelConfigPageState();
}

class _TTSModelConfigPageState extends ConsumerState<TTSModelConfigPage> {
  final _nameController = TextEditingController();
  final _voicesController = TextEditingController();
  final _speedMinController = TextEditingController();
  final _speedMaxController = TextEditingController();
  final _volumeMinController = TextEditingController();
  final _volumeMaxController = TextEditingController();

  bool _isSaving = false;

  bool get _isBuiltIn =>
      widget.providerId == 'glm_tts' || widget.providerId == 'aihubmix_tts';
  bool get _isCustom => !_isBuiltIn;
  bool get _isEditing => widget.modelIndex >= 0;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  void _loadModel() {
    if (_isBuiltIn) {
      // Read from registry — built-in models are always read-only
      final def = TTSProviderRegistry.get(widget.providerId);
      if (def != null && widget.modelIndex >= 0 && widget.modelIndex < def.supportedModels.length) {
        final model = def.supportedModels[widget.modelIndex];
        _nameController.text = model.name;
        _voicesController.text = model.voices.join(', ');
        _speedMinController.text = '${model.speedMin}';
        _speedMaxController.text = '${model.speedMax}';
        _volumeMinController.text = '${model.volumeMin}';
        _volumeMaxController.text = '${model.volumeMax}';
      }
    } else {
      // Read from persisted config
      final config = ref.read(ttsConfigProvider);
      final providerConfig = config.providerConfigs[widget.providerId];
      final modelsList = (providerConfig?['models'] as List?) ?? [];
      if (widget.modelIndex >= 0 && widget.modelIndex < modelsList.length) {
        final modelMap = modelsList[widget.modelIndex] as Map;
        _nameController.text = modelMap['name'] as String? ?? '';
        _voicesController.text = (modelMap['voices'] as List?)?.join(', ') ?? '';
        _speedMinController.text = '${modelMap['speedMin'] ?? 0.25}';
        _speedMaxController.text = '${modelMap['speedMax'] ?? 4.0}';
        _volumeMinController.text = '${modelMap['volumeMin'] ?? 0.0}';
        _volumeMaxController.text = '${modelMap['volumeMax'] ?? 2.0}';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _voicesController.dispose();
    _speedMinController.dispose();
    _speedMaxController.dispose();
    _volumeMinController.dispose();
    _volumeMaxController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------
  // Save
  // ----------------------------------------------------------------

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(ttsConfigProvider.notifier);
      final config = ref.read(ttsConfigProvider);
      var providerConfig = Map<String, dynamic>.from(
        config.providerConfigs[widget.providerId] ?? {},
      );
      var modelsList = (providerConfig['models'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];

      final modelMap = {
        'name': _nameController.text.trim(),
        'voices': _voicesController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'speedMin': double.tryParse(_speedMinController.text) ?? 0.25,
        'speedMax': double.tryParse(_speedMaxController.text) ?? 4.0,
        'volumeMin': double.tryParse(_volumeMinController.text) ?? 0.0,
        'volumeMax': double.tryParse(_volumeMaxController.text) ?? 2.0,
      };

      if (widget.modelIndex >= 0 && widget.modelIndex < modelsList.length) {
        modelsList[widget.modelIndex] = modelMap;
      } else {
        modelsList.add(modelMap);
      }

      providerConfig['models'] = modelsList;
      await notifier.saveProviderConfig(widget.providerId, providerConfig);

      // Also update the registry definition's supportedModels
      final def = TTSProviderRegistry.get(widget.providerId);
      if (def != null) {
        TTSProviderRegistry.register(TTSProviderDefinition(
          id: def.id,
          label: def.label,
          defaultBaseUrl: def.defaultBaseUrl,
          supportedVoices:
              modelsList.expand((m) => (m['voices'] as List).cast<String>()).toList(),
          supportedModels: modelsList.map((m) => ModelInfo(
            name: m['name'] as String,
            voices: (m['voices'] as List).cast<String>(),
            speedMin: (m['speedMin'] as num).toDouble(),
            speedMax: (m['speedMax'] as num).toDouble(),
            volumeMin: (m['volumeMin'] as num).toDouble(),
            volumeMax: (m['volumeMax'] as num).toDouble(),
          )).toList(),
          speedMin: def.speedMin,
          speedMax: def.speedMax,
          volumeMin: def.volumeMin,
          volumeMax: def.volumeMax,
          defaultSampleRate: def.defaultSampleRate,
          defaultConfig: def.defaultConfig,
        ));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('模型已保存'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存失败: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ----------------------------------------------------------------
  // Delete
  // ----------------------------------------------------------------

  Future<void> _delete() async {
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

    if (confirmed != true || !mounted) return;

    final notifier = ref.read(ttsConfigProvider.notifier);
    final config = ref.read(ttsConfigProvider);
    var providerConfig = Map<String, dynamic>.from(
      config.providerConfigs[widget.providerId] ?? {},
    );
    var modelsList = (providerConfig['models'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    if (widget.modelIndex >= 0 && widget.modelIndex < modelsList.length) {
      modelsList.removeAt(widget.modelIndex);
    }

    providerConfig['models'] = modelsList;
    await notifier.saveProviderConfig(widget.providerId, providerConfig);

    // Update registry
    final def = TTSProviderRegistry.get(widget.providerId);
    if (def != null) {
      TTSProviderRegistry.register(TTSProviderDefinition(
        id: def.id,
        label: def.label,
        defaultBaseUrl: def.defaultBaseUrl,
        supportedVoices:
            modelsList.expand((m) => (m['voices'] as List).cast<String>()).toList(),
        supportedModels: modelsList.map((m) => ModelInfo(
          name: m['name'] as String,
          voices: (m['voices'] as List).cast<String>(),
          speedMin: (m['speedMin'] as num).toDouble(),
          speedMax: (m['speedMax'] as num).toDouble(),
          volumeMin: (m['volumeMin'] as num).toDouble(),
          volumeMax: (m['volumeMax'] as num).toDouble(),
        )).toList(),
        speedMin: def.speedMin,
        speedMax: def.speedMax,
        volumeMin: def.volumeMin,
        volumeMax: def.volumeMax,
        defaultSampleRate: def.defaultSampleRate,
        defaultConfig: def.defaultConfig,
      ));
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  // ----------------------------------------------------------------
  // Build
  // ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? _nameController.text : '新建模型';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_isCustom && _isEditing)
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
          // Model name
          if (_isCustom)
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '模型名称',
                border: OutlineInputBorder(),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const Text('模型名称：',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_nameController.text)),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Voices
          if (_isCustom) ...[
            TextField(
              controller: _voicesController,
              decoration: const InputDecoration(
                labelText: '音色列表',
                hintText: 'voice1, voice2, voice3',
                helperText: '用逗号分隔多个音色',
                border: OutlineInputBorder(),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('音色列表：',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_voicesController.text)),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Speed range
          const Text('语速范围', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _isCustom
                    ? TextField(
                        controller: _speedMinController,
                        decoration: const InputDecoration(
                          labelText: '最小语速',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('最小语速',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(_speedMinController.text),
                        ],
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _isCustom
                    ? TextField(
                        controller: _speedMaxController,
                        decoration: const InputDecoration(
                          labelText: '最大语速',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('最大语速',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(_speedMaxController.text),
                        ],
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Volume range
          const Text('音量范围', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _isCustom
                    ? TextField(
                        controller: _volumeMinController,
                        decoration: const InputDecoration(
                          labelText: '最小音量',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('最小音量',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(_volumeMinController.text),
                        ],
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _isCustom
                    ? TextField(
                        controller: _volumeMaxController,
                        decoration: const InputDecoration(
                          labelText: '最大音量',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('最大音量',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(_volumeMaxController.text),
                        ],
                      ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Save button (custom only)
          if (_isCustom)
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
              ),
            ),
        ],
      ),
    );
  }
}
