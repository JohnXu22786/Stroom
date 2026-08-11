import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/provider_config.dart';
import '../utils/model_order.dart';
import 'asr_model_config_page.dart';
import 'llm_model_config_page.dart';
import 'model_config_page.dart';
import 'ocr_model_config_page.dart';
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

  /// 新建配置保存后指向的已持久化配置索引。新建配置会插入到
  /// `configs[0]`，保存后将其设为 0，让页面从"新建"模式切换到
  /// 该供应商的模型列表视图——而不是返回供应商列表页。
  int? _savedConfigIndex;

  /// 当前生效的配置索引：新建配置保存前为 [ProviderConfigDetailPage.configIndex]
  /// （-1），保存后为新配置的索引（0）。
  int get _configIndex => _savedConfigIndex ?? widget.configIndex;

  bool get _isExistingConfig => _configIndex >= 0;
  final List<ModelConfig> _pendingModels = [];

  /// 保存的全局模型顺序（SharedPreferences `model_order`，全部 LLM 模型
  /// 显示名的合并顺序）。对话页面模型选择面板与这里共享同一份顺序：
  /// 本页显示"去掉其它供应商后的剩余顺序"，拖动排序时写回全局顺序。
  List<String>? _savedModelOrder;

  /// 模型显示名与聊天面板一致："模型名 | 供应商名"。
  String _modelDisplayName(ModelConfig model, String providerName) {
    return '${model.name.isNotEmpty ? model.name : model.modelId}'
        ' | $providerName';
  }

  /// 是否启用模型拖动排序（仅 LLM 已有配置：聊天面板的模型选择只展示
  /// LLM 模型，其它类型没有可同步的全局顺序，保持普通列表）。
  bool get _enableModelReorder => _isExistingConfig && _entry?.type == 'llm';

  /// 模型列表的显示顺序：LLM 配置按全局保存顺序过滤出本配置的子序列，
  /// 未保存过顺序时与存储顺序一致。
  List<ModelConfig> get _displayModels {
    final models = _models;
    if (!_enableModelReorder) return models;
    final config = _config;
    if (config == null) return models;

    final names =
        models.map((m) => _modelDisplayName(m, config.providerName)).toList();
    final orderedNames = applySavedOrder(names, _savedModelOrder);
    // 按名字逐个配对回模型对象（处理重名：每个名字按出现顺序消费）
    final remaining = List<ModelConfig>.of(models);
    final ordered = <ModelConfig>[];
    for (final name in orderedNames) {
      final i = remaining
          .indexWhere((m) => _modelDisplayName(m, config.providerName) == name);
      if (i >= 0) ordered.add(remaining.removeAt(i));
    }
    ordered.addAll(remaining);
    return ordered;
  }

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
    if (_configIndex >= 0 && _configIndex < entry.configs.length) {
      return entry.configs[_configIndex];
    }
    return null;
  }

  List<ModelConfig> get _models =>
      _isExistingConfig ? (_config?.models ?? []) : _pendingModels;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadSavedModelOrder();
    // For new configs, open the settings panel immediately
    if (!_isExistingConfig) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openSettingsPanel();
      });
    }
  }

  /// 加载对话页面保存的全局模型顺序（拖动排序的持久化数据）。
  Future<void> _loadSavedModelOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      // 若用户已在加载完成前拖动过（_savedModelOrder 已被拖动写入），
      // 不要用旧的持久化值覆盖内存中的新顺序。
      if (_savedModelOrder != null) return;
      setState(() => _savedModelOrder = prefs.getStringList('model_order'));
    } catch (e) {
      debugPrint('Failed to load model_order: $e');
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
          configs[_configIndex] = result;
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
        // For new config, save to provider and stay on this page
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
          // 新建配置保存后不返回供应商列表，而是留在本页：切换到新配置
          // （configs[0]）的模型列表视图，方便继续添加模型。
          if (mounted) {
            setState(() => _savedConfigIndex = 0);
          }
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
              builder: (_) => LlmModelConfigPage(provider: _config),
            ),
          );
          if (result != null && mounted) {
            await _insertModelResult(result);
          }
          break;
        }
      case ModelConfigStyle.asr:
        {
          final result = await Navigator.push<ModelConfig>(
            context,
            MaterialPageRoute(
              builder: (_) => const AsrModelConfigPage(),
            ),
          );
          if (result != null && mounted) {
            await _insertModelResult(result);
          }
          break;
        }
      case ModelConfigStyle.ocr:
        {
          final result = await Navigator.push<ModelConfig>(
            context,
            MaterialPageRoute(
              builder: (_) => const OcrModelConfigPage(),
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
                configIndex: _configIndex >= 0 ? _configIndex : 0,
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
    if (_isExistingConfig && _configIndex < currentEntry.configs.length) {
      var configs = currentEntry.configs.map((c) => c.copy()).toList();
      // 在完整副本上追加模型：保留供应商的 typeConfig / customParams /
      // reasoningParams / endpointType（重建会丢配置，推理参数继承
      // 视图与请求构建都依赖供应商级参数）。
      final base = configs[_configIndex];
      configs[_configIndex] = ProviderConfigItem(
        providerName: base.providerName,
        host: base.host,
        key: base.key,
        models: [
          ...base.models,
          result,
        ],
        typeConfig: base.typeConfig,
        customParams: base.customParams,
        reasoningParams: base.reasoningParams,
        endpointType: base.endpointType,
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
          if (_isExistingConfig) {
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
                  provider: config,
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
                  provider: _config,
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
      case ModelConfigStyle.asr:
        {
          if (_isExistingConfig) {
            final config = _config;
            if (config == null ||
                modelIndex < 0 ||
                modelIndex >= config.models.length) {
              return;
            }

            final result = await Navigator.push<ModelConfig>(
              context,
              MaterialPageRoute(
                builder: (_) => AsrModelConfigPage(
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
                builder: (_) => AsrModelConfigPage(
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
      case ModelConfigStyle.ocr:
        {
          if (_isExistingConfig) {
            final config = _config;
            if (config == null ||
                modelIndex < 0 ||
                modelIndex >= config.models.length) {
              return;
            }

            final result = await Navigator.push<ModelConfig>(
              context,
              MaterialPageRoute(
                builder: (_) => OcrModelConfigPage(
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
                builder: (_) => OcrModelConfigPage(
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
          if (_isExistingConfig) {
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
          if (_isExistingConfig) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ModelConfigPage(
                  entryId: widget.entryId,
                  configIndex: _configIndex,
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
    if (_configIndex >= 0 && _configIndex < configs.length) {
      // 在完整副本上更新模型：保留供应商的 typeConfig / customParams /
      // reasoningParams / endpointType（重建会丢配置，推理参数继承
      // 视图与请求构建都依赖供应商级参数）。
      final base = configs[_configIndex];
      final models = List<ModelConfig>.from(base.models);
      models[modelIndex] = result;
      configs[_configIndex] = ProviderConfigItem(
        providerName: base.providerName,
        host: base.host,
        key: base.key,
        models: models,
        typeConfig: base.typeConfig,
        customParams: base.customParams,
        reasoningParams: base.reasoningParams,
        endpointType: base.endpointType,
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

  /// 拖动排序模型：把本配置在全局顺序中的子序列替换为拖动后的新顺序，
  /// 其它供应商的模型保持原位，并写回 SharedPreferences `model_order`
  /// （与对话页面模型选择面板共享的同一份顺序）。
  Future<void> _reorderModels(int oldIndex, int newIndex) async {
    // onReorderItem 的 newIndex 已是移除后的索引，直接使用
    final config = _config;
    if (config == null) return;

    final models = _displayModels;
    if (oldIndex < 0 ||
        oldIndex >= models.length ||
        newIndex < 0 ||
        newIndex > models.length) {
      return;
    }
    final reordered = List<ModelConfig>.of(models);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);

    // 计算新的全局顺序：以全部 LLM 模型的当前合并顺序为基准
    final entriesState = ref.read(providerEntriesProvider);
    final llmEntry =
        entriesState.entries.where((e) => e.type == 'llm').firstOrNull;
    final allNames = <String>[];
    if (llmEntry != null) {
      for (final c in llmEntry.configs) {
        for (final m in c.models) {
          allNames.add(_modelDisplayName(m, c.providerName));
        }
      }
    }
    final currentGlobal = applySavedOrder(allNames, _savedModelOrder);
    final thisProviderSet = config.models
        .map((m) => _modelDisplayName(m, config.providerName))
        .toSet();
    final newThisOrder = reordered
        .map((m) => _modelDisplayName(m, config.providerName))
        .toList();
    final newGlobal = rebuildGlobalOrder(
      currentGlobal: currentGlobal,
      inProvider: thisProviderSet,
      newProviderOrder: newThisOrder,
    );

    setState(() => _savedModelOrder = newGlobal);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('model_order', newGlobal);
    } catch (e) {
      debugPrint('Failed to persist model_order: $e');
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
    // 在完整副本上删除模型：保留供应商的 typeConfig / customParams /
    // reasoningParams / endpointType（重建会丢配置，推理参数继承
    // 视图与请求构建都依赖供应商级参数）。
    configs[_configIndex] = ProviderConfigItem(
      providerName: config.providerName,
      host: config.host,
      key: config.key,
      models: models,
      typeConfig: config.typeConfig,
      customParams: config.customParams,
      reasoningParams: config.reasoningParams,
      endpointType: config.endpointType,
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

    final models = _displayModels;
    final reorderable = _enableModelReorder;
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
          else if (reorderable)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: models.length,
              onReorderItem: _reorderModels,
              proxyDecorator: (child, index, animation) => Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(8),
                child: child,
              ),
              itemBuilder: (context, i) => _buildModelTile(i),
            )
          else
            ...List.generate(models.length, (i) => _buildModelTile(i)),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 构建单个模型条目。显示顺序与存储顺序可能不同（LLM 拖动排序后），
  /// 编辑/删除时必须使用存储索引而不是显示索引。
  Widget _buildModelTile(int displayIndex) {
    final displayModels = _displayModels;
    final model = displayModels[displayIndex];
    final config = _config;
    final storageIndex =
        config != null ? config.models.indexOf(model) : displayIndex;
    final reorderable = _enableModelReorder;

    return ListTile(
      key: reorderable
          ? ValueKey(
              'model_${widget.entryId}_${_configIndex}_$displayIndex')
          : null,
      leading: reorderable
          ? ReorderableDragStartListener(
              index: displayIndex,
              child: Icon(Icons.drag_handle, color: Colors.grey),
            )
          : const Icon(Icons.smart_toy),
      title: Text(model.name.isNotEmpty ? model.name : '（未命名）'),
      subtitle: Text('ID: ${model.modelId}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteModel(storageIndex),
            tooltip: '删除模型',
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
      contentPadding: EdgeInsets.zero,
      onTap: () => _editModel(storageIndex),
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
