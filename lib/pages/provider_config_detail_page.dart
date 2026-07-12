import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/provider_config.dart';
import 'llm_model_config_page.dart';
import 'model_config_page.dart';
import 'simple_model_config_page.dart';
import 'provider_settings_panel.dart';

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
    // For new configs, open the settings panel immediately
    if (!_isExistingConfig) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openSettingsPanel();
      });
    }
  }

  void _loadConfig() {
    final config = _config;
    if (config != null) {
      _providerNameController.text = config.providerName;
      _hostController.text = config.host;
      _keyController.text = config.key;
    }
  }

  @override
  void dispose() {
    _providerNameController.dispose();
    _hostController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  /// Open the provider settings panel for editing basic info + params
  Future<void> _openSettingsPanel() async {
    final entry = _entry;
    if (entry == null) return;

    // Build a ProviderConfigItem from current state (including pending models for new configs)
    final currentConfig = _isExistingConfig && _config != null
        ? _config!.copy()
        : ProviderConfigItem(
            providerName: _providerNameController.text,
            host: _hostController.text,
            key: _keyController.text,
            models: _pendingModels.map((m) => m.copy()).toList(),
          );

    final result = await showProviderSettingsPanel(
      context: context,
      config: currentConfig,
      providerType: entry.type,
    );

    if (result != null && mounted) {
      // Update local controllers with saved values
      _providerNameController.text = result.providerName;
      _hostController.text = result.host;
      _keyController.text = result.key;

      // If existing config, persist immediately
      if (_isExistingConfig) {
        final currentEntry = _entry;
        if (currentEntry != null) {
          var configs = currentEntry.configs.map((c) => c.copy()).toList();
          configs[widget.configIndex] = result;
          final updated = ProviderEntry(
            id: currentEntry.id,
            type: currentEntry.type,
            name: currentEntry.name,
            configs: configs,
          );
          await ref.read(providerEntriesProvider.notifier).update(
                currentEntry.id,
                updated,
              );
        }
      } else {
        // For new config, save to provider and navigate
        final currentEntry = _entry;
        if (currentEntry != null) {
          var configs = currentEntry.configs.map((c) => c.copy()).toList();
          // Use the models from pending or from the returned result
          final configWithModels = ProviderConfigItem(
            providerName: result.providerName,
            host: result.host,
            key: result.key,
            models: result.models.isNotEmpty
                ? result.models
                : _pendingModels.map((m) => m.copy()).toList(),
            typeConfig: result.typeConfig,
            customParams: result.customParams,
            reasoningParams: result.reasoningParams,
          );
          configs.insert(0, configWithModels);
          final updated = ProviderEntry(
            id: currentEntry.id,
            type: currentEntry.type,
            name: currentEntry.name,
            configs: configs,
          );
          await ref.read(providerEntriesProvider.notifier).update(
                currentEntry.id,
                updated,
              );
          if (mounted) Navigator.pop(context, true);
        }
      }
      if (mounted) setState(() {});
    }
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
      case ModelConfigStyle.llm:
        {
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
      case ModelConfigStyle.simple:
        {
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
      case ModelConfigStyle.tts:
        {
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
    if (_isExistingConfig && widget.configIndex < currentEntry.configs.length) {
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
      case ModelConfigStyle.llm:
        {
          if (widget.configIndex >= 0) {
            final config = _config;
            if (config == null ||
                modelIndex < 0 ||
                modelIndex >= config.models.length) {
              return;
            }

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
      case ModelConfigStyle.simple:
        {
          if (widget.configIndex >= 0) {
            final config = _config;
            if (config == null ||
                modelIndex < 0 ||
                modelIndex >= config.models.length) {
              return;
            }

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
      case ModelConfigStyle.tts:
        {
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
      final models = List<ModelConfig>.from(configs[widget.configIndex].models);
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ==========================================================
          // 供应商卡片（参照选择对话页面的顶部card样式）
          // ==========================================================
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.primaryContainer,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.dns, color: Colors.teal, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _providerNameController.text.isNotEmpty
                            ? _providerNameController.text
                            : '（未命名）',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      if (_hostController.text.isNotEmpty)
                        Text(
                          _hostController.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.tune, size: 20),
                  tooltip: '编辑供应商设置',
                  onPressed: () => _openSettingsPanel(),
                ),
              ],
            ),
          ),

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
