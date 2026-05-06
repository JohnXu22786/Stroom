import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/provider_config.dart';
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

  List<ModelConfig> get _models => _config?.models ?? [];

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
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          (_providerNameController.text.trim().isEmpty ||
              _hostController.text.trim().isEmpty ||
              _keyController.text.trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请填写完整的供应商配置信息（名称、Host 和 Key），否则该供应商不可在生成录音中使用'),
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
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _editModel(int modelIndex) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ModelConfigPage(
          entryId: widget.entryId,
          configIndex: widget.configIndex >= 0 ? widget.configIndex : 0,
          modelIndex: modelIndex,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
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
          content: Text('供应商名称、Host 和 Key 均为必填项'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final entry = _entry;
    if (entry == null) return;

    setState(() => _isSaving = true);

    var configs = entry.configs.map((c) => c.copy()).toList();

    final newConfig = ProviderConfigItem(
      providerName: _providerNameController.text.trim(),
      host: host,
      key: key,
      models: _config?.models.map((m) => m.copy()).toList() ?? [],
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
    final title = _isEditing
        ? (_providerNameController.text.isNotEmpty
            ? _providerNameController.text
            : '编辑配置')
        : '新建供应商配置';

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
              labelText: 'Host',
              hintText: 'https://api.example.com',
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
                title:
                    Text(model.name.isNotEmpty ? model.name : '（未命名）'),
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
