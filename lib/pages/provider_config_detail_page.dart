import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/provider_config.dart';
import 'llm_model_config_page.dart';
import 'model_config_page.dart';

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
  bool get _isEditing => widget.configIndex >= 0;
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
    if (_isEditing &&
        widget.configIndex >= 0 &&
        widget.configIndex < entry.configs.length) {
      return entry.configs[widget.configIndex];
    }
    return null;
  }

  List<ModelConfig> get _models =>
      _isEditing ? (_config?.models ?? []) : _pendingModels;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    final config = _config;
    if (config != null) {
      _providerNameController.text = config.providerName;
      _hostController.text = config.host;
      _keyController.text = config.key;
    } else {
      final def = _entry != null
          ? ProviderTypeRegistry.get(_entry!.type)
          : null;
      if (def != null) {
        _hostController.text = def.defaultHost ?? '';
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

  // ----------------------------------------------------------------
  // 模型管理
  // ----------------------------------------------------------------

  Future<void> _addModel() async {
    final entry = _entry;
    if (entry == null) return;

    final useLlmModel = ProviderTypeRegistry.get(entry.type)?.useLlmModelConfig ?? false;
    if (useLlmModel) {
      final result = await Navigator.push<ModelConfig>(
        context,
        MaterialPageRoute(
          builder: (_) => const LlmModelConfigPage(),
        ),
      );
      if (result != null && mounted) {
        final currentEntry = _entry;
        if (currentEntry == null) return;
        if (widget.configIndex >= 0 && widget.configIndex < currentEntry.configs.length) {
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
    } else {
      await Navigator.push(
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
        // Force re-read entry from provider to reflect newly saved models
        ref.invalidate(providerEntriesProvider);
        setState(() {});
      }
    }
  }

  Future<void> _editModel(int modelIndex) async {
    final entry = _entry;
    if (entry == null) return;

    final useLlmModel = ProviderTypeRegistry.get(entry.type)?.useLlmModelConfig ?? false;
    if (useLlmModel) {
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
    } else {
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

    if (!_isEditing) {
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
      models: _isEditing
          ? (_config?.models.map((m) => m.copy()).toList() ??
              def?.defaultModels.map((m) => m.copy()).toList() ?? [])
          : _pendingModels.map((m) => m.copy()).toList(),
    );

    if (_isEditing &&
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
    Navigator.pop(context, true);
  }

  // ----------------------------------------------------------------
  // Build
  // ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final entryName = _entry?.name ?? '';
    final title = _isEditing
        ? (_providerNameController.text.isNotEmpty
            ? _providerNameController.text
            : '编辑配置')
        : '新建$entryName配置';

    final models = _models;

    return Scaffold(
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
          // 供应商配置
          // ==========================================================
          _buildSectionHeader('供应商配置'),
          const SizedBox(height: 8),

          TextField(
            controller: _providerNameController,
            decoration: const InputDecoration(
              labelText: '供应商名称',
              hintText: '输入供应商名称',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label, color: Colors.teal),
            ),
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
          ),
          const SizedBox(height: 16),

          // ==========================================================
          // 模型列表
          // ==========================================================
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

          const SizedBox(height: 16),
        ],
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
}
