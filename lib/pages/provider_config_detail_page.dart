import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/provider_config.dart';
import 'llm_model_config_page.dart';
import 'model_config_page.dart';
import 'simple_model_config_page.dart';

class ProviderConfigDetailPage extends ConsumerStatefulWidget {
  final String entryId;
  final int configIndex; // -1 for new config

  const ProviderConfigDetailPage({
    super.key,
    required this.entryId,
    required this.configIndex,
  });

  @override
  ConsumerState<ProviderConfigDetailPage> createState() =>
      _ProviderConfigDetailPageState();
}

class _ProviderConfigDetailPageState
    extends ConsumerState<ProviderConfigDetailPage> {
  final _providerNameController = TextEditingController();
  final _hostController = TextEditingController();
  final _keyController = TextEditingController();

  bool _isSaving = false;
  bool _obscureKey = true;
  /// 编辑模式：true 时字段可编辑，false 时只读显示
  bool _isEditMode = false;
  /// 有未保存的更改
  bool _hasUnsavedChanges = false;
  /// 保存前的原始值，用于检测变更和放弃时恢复
  String _originalProviderName = '';
  String _originalHost = '';
  String _originalKey = '';
  bool get _isExistingConfig => widget.configIndex >= 0;
  final List<ModelConfig> _pendingModels = [];

  ProviderEntry? get _entry {
    final state = ref.read(providerEntriesProvider);
    try {
      return state.entries.firstWhere((e) => e.id == widget.entryId);
    } catch (_) {
      return null;
    }
  }

  ProviderConfigItem? get _config {
    final entry = _entry;
    if (entry == null) return null;
    if (_isExistingConfig &&
        widget.configIndex >= 0 &&
        widget.configIndex < entry.configs.length) {
      return entry.configs[widget.configIndex];
    }
    return null;
  }

  List<ModelConfig> get _models =>
      _isExistingConfig ? (_config?.models ?? []) : _pendingModels;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    // 新建配置直接从编辑模式开始
    if (!_isExistingConfig) {
      _isEditMode = true;
    }
  }

  void _loadConfig() {
    final config = _config;
    if (config != null) {
      _providerNameController.text = config.providerName;
      _hostController.text = config.host;
      _keyController.text = config.key;
      _originalProviderName = config.providerName;
      _originalHost = config.host;
      _originalKey = config.key;
    } else {
      final def = _entry != null
          ? ProviderTypeRegistry.get(_entry!.type)
          : null;
      if (def != null) {
        _hostController.text = def.defaultHost ?? '';
        _originalHost = _hostController.text;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          (_providerNameController.text.trim().isEmpty ||
              _hostController.text.trim().isEmpty ||
              _keyController.text.trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请填写完整的供应商配置信息（名称、API 地址 和 Key），否则该供应商不可在生成录音中使用'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _providerNameController.dispose();
    _hostController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  /// 检测当前表单与原始值是否有差异
  void _checkUnsavedChanges() {
    final changed = _providerNameController.text != _originalProviderName ||
        _hostController.text != _originalHost ||
        _keyController.text != _originalKey;
    setState(() => _hasUnsavedChanges = changed);
  }

  /// 进入编辑模式
  void _enterEditMode() {
    final config = _config;
    if (config != null) {
      _originalProviderName = config.providerName;
      _originalHost = config.host;
      _originalKey = config.key;
      _providerNameController.text = config.providerName;
      _hostController.text = config.host;
      _keyController.text = config.key;
    }
    setState(() {
      _isEditMode = true;
      _hasUnsavedChanges = false;
    });
  }

  /// 放弃编辑，恢复为原始值
  void _discardChanges() {
    _providerNameController.text = _originalProviderName;
    _hostController.text = _originalHost;
    _keyController.text = _originalKey;
    setState(() {
      _isEditMode = false;
      _hasUnsavedChanges = false;
    });
    // 新建配置放弃后返回上一页
    if (!_isExistingConfig) {
      Navigator.pop(context);
    }
  }

  /// 退出编辑模式（保存成功后调用）
  void _exitEditMode() {
    _originalProviderName = _providerNameController.text;
    _originalHost = _hostController.text;
    _originalKey = _keyController.text;
    setState(() {
      _isEditMode = false;
      _hasUnsavedChanges = false;
    });
  }

  // ----------------------------------------------------------------
  // 模型管理
  // ----------------------------------------------------------------

  Future<void> _addModel() async {
    final entry = _entry;
    if (entry == null) return;

    final style = ProviderTypeRegistry.get(entry.type)?.modelConfigStyle ??
        ModelConfigStyle.tts;

    switch (style) {
      case ModelConfigStyle.llm: {
        final result = await Navigator.push<ModelConfig>(
          context,
          MaterialPageRoute(
            builder: (_) => const LlmModelConfigPage(),
          ),
        );
        if (result != null && mounted) {
          await _insertModelResult(result);
        }
        break;
      }
      case ModelConfigStyle.simple: {
        final result = await Navigator.push<ModelConfig>(
          context,
          MaterialPageRoute(
            builder: (_) => const SimpleModelConfigPage(),
          ),
        );
        if (result != null && mounted) {
          await _insertModelResult(result);
        }
        break;
      }
      case ModelConfigStyle.tts: {
        final result = await Navigator.push<ModelConfig>(
          context,
          MaterialPageRoute(
            builder: (_) => ModelConfigPage(
              entryId: widget.entryId,
              configIndex: widget.configIndex >= 0 ? widget.configIndex : 0,
              modelIndex: -1,
            ),
          ),
        );
        if (mounted) {
          if (result is ModelConfig) {
            _pendingModels.insert(0, result);
          }
          ref.invalidate(providerEntriesProvider);
          setState(() {});
        }
        break;
      }
    }
  }

  /// 插入 LLM/Simple 类型的模型结果（共用逻辑）
  Future<void> _insertModelResult(ModelConfig result) async {
    final currentEntry = _entry;
    if (currentEntry == null) return;
    if (_isExistingConfig &&
        widget.configIndex < currentEntry.configs.length) {
      var configs = currentEntry.configs.map((c) => c.copy()).toList();
      configs[widget.configIndex] = ProviderConfigItem(
        providerName: configs[widget.configIndex].providerName,
        host: configs[widget.configIndex].host,
        key: configs[widget.configIndex].key,
        models: [
          ...configs[widget.configIndex].models,
          result,
        ],
      );
      final updated = ProviderEntry(
        id: currentEntry.id,
        type: currentEntry.type,
        name: currentEntry.name,
        configs: configs,
      );
      await ref
          .read(providerEntriesProvider.notifier)
          .update(currentEntry.id, updated);
    } else {
      _pendingModels.insert(0, result);
    }
    if (mounted) setState(() {});
  }

  Future<void> _editModel(int modelIndex) async {
    final entry = _entry;
    if (entry == null) return;

    final style = ProviderTypeRegistry.get(entry.type)?.modelConfigStyle ??
        ModelConfigStyle.tts;

    switch (style) {
      case ModelConfigStyle.llm: {
        if (widget.configIndex >= 0) {
          final config = _config;
          if (config == null ||
              modelIndex < 0 ||
              modelIndex >= config.models.length) return;

          final result = await Navigator.push<ModelConfig>(
            context,
            MaterialPageRoute(
              builder: (_) => LlmModelConfigPage(
                model: config.models[modelIndex].copy(),
              ),
            ),
          );
          if (result != null && mounted) {
            await _updateModelInConfig(modelIndex, result);
          }
        } else {
          if (modelIndex < 0 || modelIndex >= _pendingModels.length) return;
          final result = await Navigator.push<ModelConfig>(
            context,
            MaterialPageRoute(
              builder: (_) => LlmModelConfigPage(
                model: _pendingModels[modelIndex].copy(),
              ),
            ),
          );
          if (result != null && mounted) {
            _pendingModels[modelIndex] = result;
            if (mounted) setState(() {});
          }
        }
        break;
      }
      case ModelConfigStyle.simple: {
        if (widget.configIndex >= 0) {
          final config = _config;
          if (config == null ||
              modelIndex < 0 ||
              modelIndex >= config.models.length) return;

          final result = await Navigator.push<ModelConfig>(
            context,
            MaterialPageRoute(
              builder: (_) => SimpleModelConfigPage(
                model: config.models[modelIndex].copy(),
              ),
            ),
          );
          if (result != null && mounted) {
            await _updateModelInConfig(modelIndex, result);
          }
        } else {
          if (modelIndex < 0 || modelIndex >= _pendingModels.length) return;
          final result = await Navigator.push<ModelConfig>(
            context,
            MaterialPageRoute(
              builder: (_) => SimpleModelConfigPage(
                model: _pendingModels[modelIndex].copy(),
              ),
            ),
          );
          if (result != null && mounted) {
            _pendingModels[modelIndex] = result;
            if (mounted) setState(() {});
          }
        }
        break;
      }
      case ModelConfigStyle.tts: {
        if (widget.configIndex >= 0) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ModelConfigPage(
                entryId: widget.entryId,
                configIndex: widget.configIndex,
                modelIndex: modelIndex,
              ),
            ),
          );
          if (mounted) {
            ref.invalidate(providerEntriesProvider);
            setState(() {});
          }
        } else {
          if (modelIndex < 0 || modelIndex >= _pendingModels.length) return;
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ModelConfigPage(
                entryId: widget.entryId,
                configIndex: -1,
                modelIndex: -1,
                initialModel: _pendingModels[modelIndex].copy(),
              ),
            ),
          );
          if (result is ModelConfig && mounted) {
            _pendingModels[modelIndex] = result;
            if (mounted) setState(() {});
          }
        }
        break;
      }
    }
  }

  /// 更新 LLM/Simple 类型在已有配置中的模型（共用逻辑）
  Future<void> _updateModelInConfig(int modelIndex, ModelConfig result) async {
    final currentEntry = _entry;
    if (currentEntry == null) return;
    var configs = currentEntry.configs.map((c) => c.copy()).toList();
    if (widget.configIndex >= 0 && widget.configIndex < configs.length) {
      final models =
          List<ModelConfig>.from(configs[widget.configIndex].models);
      models[modelIndex] = result;
      configs[widget.configIndex] = ProviderConfigItem(
        providerName: configs[widget.configIndex].providerName,
        host: configs[widget.configIndex].host,
        key: configs[widget.configIndex].key,
        models: models,
      );
      final updated = ProviderEntry(
        id: currentEntry.id,
        type: currentEntry.type,
        name: currentEntry.name,
        configs: configs,
      );
      await ref
          .read(providerEntriesProvider.notifier)
          .update(currentEntry.id, updated);
      if (mounted) setState(() {});
    }
  }

  Future<void> _deleteModel(int modelIndex) async {
    final entry = _entry;
    if (entry == null) return;

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

    if (!_isExistingConfig) {
      if (modelIndex < 0 || modelIndex >= _pendingModels.length) return;
      _pendingModels.removeAt(modelIndex);
      if (mounted) setState(() {});
      return;
    }

    final config = _config;
    if (config == null) return;

    var configs = entry.configs.map((c) => c.copy()).toList();
    var models = List<ModelConfig>.from(config.models);
    models.removeAt(modelIndex);
    configs[widget.configIndex] = ProviderConfigItem(
      providerName: config.providerName,
      host: config.host,
      key: config.key,
      models: models,
    );

    final updated = ProviderEntry(
      id: entry.id,
      type: entry.type,
      name: entry.name,
      configs: configs,
    );
    await ref.read(providerEntriesProvider.notifier).update(entry.id, updated);
    if (!mounted) return;
    setState(() {});
  }

  // ----------------------------------------------------------------
  // 保存
  // ----------------------------------------------------------------

  Future<void> _save() async {
    final providerName = _providerNameController.text.trim();
    final host = _hostController.text.trim();
    final key = _keyController.text.trim();
    if (providerName.isEmpty || host.isEmpty || key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('供应商名称、API 地址 和 Key 均为必填项'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final entry = _entry;
    if (entry == null) return;

    setState(() => _isSaving = true);

    var configs = entry.configs.map((c) => c.copy()).toList();

    final def = ProviderTypeRegistry.get(entry.type);
    final newConfig = ProviderConfigItem(
      providerName: _providerNameController.text.trim(),
      host: host,
      key: key,
      models: _isExistingConfig
          ? (_config?.models.map((m) => m.copy()).toList() ??
              def?.defaultModels.map((m) => m.copy()).toList() ?? [])
          : _pendingModels.map((m) => m.copy()).toList(),
    );

    if (_isExistingConfig &&
        widget.configIndex >= 0 &&
        widget.configIndex < configs.length) {
      configs[widget.configIndex] = newConfig;
    } else {
      configs.insert(0, newConfig);
    }

    final updated = ProviderEntry(
      id: entry.id,
      type: entry.type,
      name: entry.name,
      configs: configs,
    );

    await ref.read(providerEntriesProvider.notifier).update(entry.id, updated);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (_isExistingConfig) {
      // 编辑已有配置：保存后退出编辑模式，留在页面
      _exitEditMode();
    } else {
      // 新建配置：保存后返回上一页
      Navigator.pop(context, true);
    }
  }

  // ----------------------------------------------------------------
  // Build
  // ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final entryName = _entry?.name ?? '';
    final title = _isExistingConfig
        ? (_providerNameController.text.isNotEmpty
            ? _providerNameController.text
            : '编辑配置')
        : '新建$entryName配置';

    final models = _models;

    return PopScope(
      canPop: !_isEditMode || !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // 有未保存的更改，弹出确认对话框
        final shouldDiscard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('未保存的更改'),
            content: const Text('有未保存的更改，确定要放弃吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('放弃'),
              ),
            ],
          ),
        );
        if (shouldDiscard == true && mounted) {
          setState(() {
            _isEditMode = false;
            _hasUnsavedChanges = false;
          });
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: _buildAppBarActions(),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ==========================================================
            // 供应商配置
            // ==========================================================
            _buildSectionHeader('供应商配置'),
            const SizedBox(height: 8),

            if (_isEditMode) ...[
              // 编辑模式：可编辑的输入框
              TextField(
                controller: _providerNameController,
                decoration: const InputDecoration(
                  labelText: '供应商名称',
                  hintText: '输入供应商名称',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label, color: Colors.teal),
                ),
                onChanged: (_) => _checkUnsavedChanges(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: 'API 地址',
                  hintText: 'https://api.openai.com/v1/chat/completions（填写完整 API 端点地址）',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link, color: Colors.orange),
                ),
                onChanged: (_) => _checkUnsavedChanges(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _keyController,
                decoration: InputDecoration(
                  labelText: 'Key',
                  hintText: '输入 API 密钥',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.key, color: Colors.amber),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureKey ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
                obscureText: _obscureKey,
                onChanged: (_) => _checkUnsavedChanges(),
              ),
            ] else ...[
              // 显示模式：只读展示
              _buildReadOnlyField(
                icon: Icons.label,
                iconColor: Colors.teal,
                label: '供应商名称',
                value: _providerNameController.text,
              ),
              const SizedBox(height: 12),
              _buildReadOnlyField(
                icon: Icons.link,
                iconColor: Colors.orange,
                label: 'API 地址',
                value: _hostController.text,
              ),
              const SizedBox(height: 12),
              _buildReadOnlyKeyField(),
            ],

            const SizedBox(height: 16),

            // ==========================================================
            // 模型列表（编辑模式下隐藏）
            // ==========================================================
            if (!_isEditMode) ...[
              _buildSectionHeader('模型列表'),
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('添加'),
                  onPressed: _addModel,
                ),
              ),

              const SizedBox(height: 8),

              if (models.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('暂无模型', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ...List.generate(models.length, (i) {
                  final model = models[i];
                  return ListTile(
                    leading: const Icon(Icons.smart_toy),
                    title: Text(model.name.isNotEmpty ? model.name : '（未命名）'),
                    subtitle: Text('ID: ${model.modelId}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteModel(i),
                          tooltip: '删除模型',
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    contentPadding: EdgeInsets.zero,
                    onTap: () => _editModel(i),
                  );
                }),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  /// 构建 AppBar 操作按钮
  List<Widget> _buildAppBarActions() {
    if (_isEditMode) {
      return [
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
        TextButton.icon(
          onPressed: _isSaving ? null : _discardChanges,
          icon: const Icon(Icons.close, size: 20),
          label: const Text('放弃'),
        ),
      ];
    }
    // 显示模式：编辑按钮
    return [
      if (_isExistingConfig)
        TextButton.icon(
          icon: const Icon(Icons.edit, size: 20),
          label: const Text('编辑'),
          onPressed: _enterEditMode,
        ),
    ];
  }

  /// 只读文本展示字段
  Widget _buildReadOnlyField({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isNotEmpty ? value : '（未设置）',
                  style: TextStyle(
                    fontSize: 15,
                    color: value.isNotEmpty
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 只读 Key 字段（可切换显隐）
  Widget _buildReadOnlyKeyField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.key, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Key',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _keyController.text.isNotEmpty
                      ? (_obscureKey
                          ? '•' * _keyController.text.length
                          : _keyController.text)
                      : '（未设置）',
                  style: TextStyle(
                    fontSize: 15,
                    color: _keyController.text.isNotEmpty
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _obscureKey ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
              size: 20,
            ),
            onPressed: () => setState(() => _obscureKey = !_obscureKey),
            tooltip: _obscureKey ? '显示 Key' : '隐藏 Key',
          ),
        ],
      ),
    );
  }
}
