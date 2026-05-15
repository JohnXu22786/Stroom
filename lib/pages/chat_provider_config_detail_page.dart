import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../providers/chat_provider_config.dart';

class ChatProviderConfigDetailPage extends ConsumerStatefulWidget {
  final int configIndex; // -1 for new config

  const ChatProviderConfigDetailPage({
    super.key,
    required this.configIndex,
  });

  @override
  ConsumerState<ChatProviderConfigDetailPage> createState() =>
      _ChatProviderConfigDetailPageState();
}

class _ChatProviderConfigDetailPageState
    extends ConsumerState<ChatProviderConfigDetailPage> {
  final _hostController = TextEditingController();
  final _keyController = TextEditingController();

  bool _isSaving = false;
  bool _obscureKey = true;
  bool get _isEditing => widget.configIndex >= 0;

  String? _selectedProviderId;
  late List<ChatModelConfig> _models;
  String _selectedModelId = '';

  ChatProviderConfigItem? get _config {
    final configs = ref.read(chatConfigsProvider);
    if (_isEditing &&
        widget.configIndex >= 0 &&
        widget.configIndex < configs.length) {
      return configs[widget.configIndex];
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _models = [];
    _loadConfig();
  }

  void _loadConfig() {
    final config = _config;
    if (config != null) {
      _selectedProviderId = config.providerName;
      _hostController.text = config.host;
      _keyController.text = config.key;
      _models = config.models.map((m) => m.copy()).toList();
      _selectedModelId = config.selectedModelId;
    } else {
      // New config: pick first registered provider as default
      final providers = ChatProviderRegistry.getAll();
      if (providers.isNotEmpty) {
        _onProviderSelected(providers.first);
      }
    }
  }

  void _onProviderSelected(ChatProviderDefinition def) {
    setState(() {
      _selectedProviderId = def.id;
      if (_hostController.text.trim().isEmpty) {
        _hostController.text = def.defaultBaseUrl ?? '';
      }
      if (_models.isEmpty) {
        _models = def.defaultModels.map((m) => m.copy()).toList();
        if (_models.isNotEmpty && _selectedModelId.isEmpty) {
          _selectedModelId = _models.first.modelId;
        }
      }
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------
  // 模型管理
  // ----------------------------------------------------------------

  Future<void> _addModel() async {
    final result = await showDialog<ChatModelConfig>(
      context: context,
      builder: (ctx) => const _ModelEditDialog(),
    );
    if (result != null) {
      setState(() {
        _models.add(result);
      });
    }
  }

  Future<void> _editModel(int modelIndex) async {
    if (modelIndex < 0 || modelIndex >= _models.length) return;
    final result = await showDialog<ChatModelConfig>(
      context: context,
      builder: (ctx) => _ModelEditDialog(model: _models[modelIndex].copy()),
    );
    if (result != null) {
      setState(() {
        _models[modelIndex] = result;
      });
    }
  }

  Future<void> _deleteModel(int modelIndex) async {
    if (modelIndex < 0 || modelIndex >= _models.length) return;

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

    setState(() {
      _models.removeAt(modelIndex);
      if (_selectedModelId.isNotEmpty &&
          _models.every((m) => m.modelId != _selectedModelId)) {
        _selectedModelId = _models.isNotEmpty ? _models.first.modelId : '';
      }
    });
  }

  // ----------------------------------------------------------------
  // 保存
  // ----------------------------------------------------------------

  Future<void> _save() async {
    final providerName = _selectedProviderId;
    final host = _hostController.text.trim();
    final key = _keyController.text.trim();

    if (providerName == null || providerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请选择供应商'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Host 为必填项'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Key 为必填项'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final newConfig = ChatProviderConfigItem(
      id: _config?.id,
      providerName: providerName,
      host: host,
      key: key,
      models: _models.map((m) => m.copy()).toList(),
      selectedModelId: _selectedModelId,
    );

    final notifier = ref.read(chatConfigsProvider.notifier);

    if (_isEditing && _config != null) {
      await notifier.update(_config!.id, newConfig);
    } else {
      await notifier.add(newConfig);
    }

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
        ? (_selectedProviderId != null
            ? ChatProviderRegistry.get(_selectedProviderId!)?.label ??
                _selectedProviderId!
            : '编辑配置')
        : '新建供应商配置';

    final providers = ChatProviderRegistry.getAll();

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
          // 供应商选择
          // ==========================================================
          _buildSectionHeader('供应商选择'),
          const SizedBox(height: 8),

          DropdownButtonFormField<String>(
            value: _selectedProviderId,
            decoration: const InputDecoration(
              labelText: '供应商',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.dns, color: Colors.teal),
            ),
            hint: const Text('选择供应商'),
            items: providers.map((p) {
              return DropdownMenuItem(
                value: p.id,
                child: Text(p.label),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              final def = providers.where((p) => p.id == value).firstOrNull;
              if (def != null) {
                _onProviderSelected(def);
              }
            },
          ),
          const SizedBox(height: 12),

          // ==========================================================
          // Host
          // ==========================================================
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: 'Host',
              hintText: 'https://api.example.com/v1',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link, color: Colors.orange),
            ),
          ),
          const SizedBox(height: 12),

          // ==========================================================
          // Key
          // ==========================================================
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

          if (_models.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('暂无模型', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...List.generate(_models.length, (i) {
              final model = _models[i];
              final isActive = model.modelId == _selectedModelId;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Radio<String>(
                    value: model.modelId,
                    groupValue: _selectedModelId,
                    onChanged: (value) {
                      setState(() => _selectedModelId = value ?? '');
                    },
                  ),
                  title: Text(
                    model.modelId,
                    style: TextStyle(
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    'maxTokens: ${model.maxTokens}, temperature: ${model.temperature.toStringAsFixed(1)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
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
                  contentPadding: const EdgeInsets.only(left: 4, right: 4),
                  onTap: () => _editModel(i),
                ),
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

// ============================================================================
// 模型编辑对话框
// ============================================================================

class _ModelEditDialog extends StatefulWidget {
  final ChatModelConfig? model;

  const _ModelEditDialog({this.model});

  @override
  State<_ModelEditDialog> createState() => _ModelEditDialogState();
}

class _ModelEditDialogState extends State<_ModelEditDialog> {
  late final TextEditingController _modelIdController;
  late final TextEditingController _maxTokensController;
  late final TextEditingController _systemPromptController;
  late double _temperature;
  late bool _supportStream;
  bool get _isEditing => widget.model != null;

  @override
  void initState() {
    super.initState();
    final m = widget.model;
    _modelIdController = TextEditingController(text: m?.modelId ?? '');
    _maxTokensController =
        TextEditingController(text: (m?.maxTokens ?? 4096).toString());
    _systemPromptController =
        TextEditingController(text: m?.systemPrompt ?? '你是一个有帮助的助手。');
    _temperature = m?.temperature ?? 0.7;
    _supportStream = m?.supportStream ?? true;
  }

  @override
  void dispose() {
    _modelIdController.dispose();
    _maxTokensController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? '编辑模型' : '添加模型'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _modelIdController,
              decoration: const InputDecoration(
                labelText: '模型 ID',
                hintText: '如 gpt-4o',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _maxTokensController,
              decoration: const InputDecoration(
                labelText: '最大 Token 数',
                hintText: '4096',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Temperature: '),
                Expanded(
                  child: Slider(
                    value: _temperature,
                    min: 0.0,
                    max: 2.0,
                    divisions: 40,
                    label: _temperature.toStringAsFixed(1),
                    onChanged: (v) => setState(() => _temperature = v),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    _temperature.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _systemPromptController,
              decoration: const InputDecoration(
                labelText: '系统提示词',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('支持流式响应'),
              value: _supportStream,
              onChanged: (v) => setState(() => _supportStream = v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final modelId = _modelIdController.text.trim();
            if (modelId.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('请输入模型 ID'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }
            final maxTokensStr = _maxTokensController.text.trim();
            final maxTokens = int.tryParse(maxTokensStr);
            if (maxTokensStr.isNotEmpty &&
                (maxTokens == null || maxTokens <= 0)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('最大 Token 数必须为正整数'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }
            final result = ChatModelConfig(
              modelId: modelId,
              maxTokens: maxTokens ?? 4096,
              temperature: _temperature,
              systemPrompt: _systemPromptController.text,
              supportStream: _supportStream,
            );
            Navigator.pop(context, result);
          },
          child: Text(_isEditing ? '保存' : '添加'),
        ),
      ],
    );
  }
}
