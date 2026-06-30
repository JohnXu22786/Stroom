import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mcp.dart';
import '../providers/provider_config.dart';
import 'mcp_server_config_shared.dart';

/// MCP 服务器配置页面
/// 用于添加或编辑 MCP 服务器的连接信息
class McpServerConfigPage extends ConsumerStatefulWidget {
  final String entryId;
  final int configIndex; // -1 for new config

  const McpServerConfigPage({
    super.key,
    required this.entryId,
    required this.configIndex,
  });

  @override
  ConsumerState<McpServerConfigPage> createState() =>
      _McpServerConfigPageState();
}

class _McpServerConfigPageState extends ConsumerState<McpServerConfigPage> {
  final _nameController = TextEditingController();
  final _commandController = TextEditingController();
  final _argsController = TextEditingController();
  final _urlController = TextEditingController();

  McpTransportType _transportType = McpTransportType.sse;
  bool _isSaving = false;
  bool _isEditMode = false;
  bool _hasUnsavedChanges = false;

  String _originalName = '';
  McpTransportType _originalTransport = McpTransportType.sse;
  String _originalCommand = '';
  String _originalArgs = '';
  String _originalUrl = '';
  bool _isVendor = false;

  bool get _isExistingConfig => widget.configIndex >= 0;

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
    if (_isExistingConfig) {
      _loadExistingConfig();
      _isEditMode = false;
    } else {
      _isEditMode = true;
    }
  }

  void _loadExistingConfig() {
    final entry = _entry;
    if (entry == null) return;
    if (widget.configIndex < 0 || widget.configIndex >= entry.configs.length) {
      return;
    }
    final config = entry.configs[widget.configIndex];
    final mcpConfig =
        config.models.isNotEmpty ? config.models[0].typeConfig : null;
    final serverConfig = McpServerConfig.fromProviderConfig(
      providerName: config.providerName,
      typeConfig: mcpConfig,
    );

    if (serverConfig != null) {
      _nameController.text = serverConfig.name;
      _transportType = serverConfig.transportType;
      _commandController.text = serverConfig.command ?? '';
      _argsController.text = (serverConfig.args ?? []).join(', ');
      _urlController.text = serverConfig.url ?? '';
      _isVendor = serverConfig.isVendor;

      _originalName = serverConfig.name;
      _originalTransport = serverConfig.transportType;
      _originalCommand = _commandController.text;
      _originalArgs = _argsController.text;
      _originalUrl = _urlController.text;
    } else {
      // Legacy: use providerName and host
      _nameController.text = config.providerName;
      _urlController.text = config.host;
      _originalName = config.providerName;
      _originalUrl = config.host;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commandController.dispose();
    _argsController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _checkUnsavedChanges() {
    // Vendor configs should not be edited in detail
    if (_isVendor) return;

    final changed = _nameController.text != _originalName ||
        _transportType != _originalTransport ||
        _commandController.text != _originalCommand ||
        _argsController.text != _originalArgs ||
        _urlController.text != _originalUrl;
    setState(() => _hasUnsavedChanges = changed);
  }

  void _enterEditMode() {
    setState(() {
      _isEditMode = true;
      _hasUnsavedChanges = false;
    });
  }

  void _discardChanges() {
    _nameController.text = _originalName;
    _transportType = _originalTransport;
    _commandController.text = _originalCommand;
    _argsController.text = _originalArgs;
    _urlController.text = _originalUrl;
    setState(() {
      _isEditMode = false;
      _hasUnsavedChanges = false;
    });
    if (!_isExistingConfig) {
      Navigator.pop(context);
    }
  }

  void _exitEditMode() {
    _originalName = _nameController.text;
    _originalTransport = _transportType;
    _originalCommand = _commandController.text;
    _originalArgs = _argsController.text;
    _originalUrl = _urlController.text;
    setState(() {
      _isEditMode = false;
      _hasUnsavedChanges = false;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 MCP 服务器名称')),
      );
      return;
    }

    // Validate transport-specific fields
    if (_transportType == McpTransportType.stdio &&
        _commandController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('stdio 模式需要指定命令')),
      );
      return;
    }
    if (_transportType == McpTransportType.sse &&
        _urlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SSE 模式需要指定 URL')),
      );
      return;
    }

    final entry = _entry;
    if (entry == null) return;

    setState(() => _isSaving = true);

    // Build MCP server config
    final argsStr = _argsController.text.trim();
    final args = argsStr.isNotEmpty
        ? argsStr
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
        : <String>[];

    McpServerConfig serverConfig;
    if (_transportType == McpTransportType.stdio) {
      serverConfig = McpServerConfig.stdio(
        name: name,
        command: _commandController.text.trim(),
        args: args,
      );
    } else {
      serverConfig = McpServerConfig.sse(
        name: name,
        url: _urlController.text.trim(),
      );
    }

    // Store in ProviderConfigItem with typeConfig in models[0]
    final modelConfig = ModelConfig(
      name: name,
      modelId: _transportType.value,
      typeConfig: serverConfig.toMap(),
    );

    var configs = entry.configs.map((c) => c.copy()).toList();
    final newConfig = ProviderConfigItem(
      providerName: name,
      host: _transportType == McpTransportType.sse
          ? _urlController.text.trim()
          : '',
      key: '',
      models: [modelConfig],
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
      _exitEditMode();
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = _isExistingConfig
        ? (_nameController.text.isNotEmpty ? _nameController.text : '编辑MCP服务器')
        : '新建MCP服务器';

    return PopScope(
      canPop: !_isEditMode || !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
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
            // Transport type
            const SectionHeader(title: '传输方式'),
            const SizedBox(height: 8),
            if (_isEditMode)
              _buildTransportSelector()
            else
              _buildReadOnlyTransport(),

            const SizedBox(height: 16),

            // Server name
            const SectionHeader(title: '服务器名称'),
            const SizedBox(height: 8),
            if (_isEditMode)
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: '输入 MCP 服务器名称',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label, color: Colors.teal),
                ),
                onChanged: (_) => _checkUnsavedChanges(),
              )
            else
              ReadOnlyField(
                icon: Icons.label,
                iconColor: Colors.teal,
                label: '名称',
                value: _nameController.text,
              ),

            const SizedBox(height: 16),

            // Transport-specific fields
            if (_transportType == McpTransportType.stdio) ...[
              const SectionHeader(title: '命令'),
              const SizedBox(height: 8),
              if (_isEditMode)
                TextField(
                  controller: _commandController,
                  decoration: const InputDecoration(
                    hintText: '例如: npx',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.terminal, color: Colors.orange),
                  ),
                  onChanged: (_) => _checkUnsavedChanges(),
                )
              else
                ReadOnlyField(
                  icon: Icons.terminal,
                  iconColor: Colors.orange,
                  label: '命令',
                  value: _commandController.text,
                ),
              const SizedBox(height: 12),
              const SectionHeader(title: '参数'),
              const SizedBox(height: 8),
              if (_isEditMode)
                TextField(
                  controller: _argsController,
                  decoration: const InputDecoration(
                    hintText:
                        '用逗号分隔，例如: -y, @modelcontextprotocol/server-filesystem, /tmp',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.list, color: Colors.purple),
                  ),
                  onChanged: (_) => _checkUnsavedChanges(),
                )
              else
                ReadOnlyField(
                  icon: Icons.list,
                  iconColor: Colors.purple,
                  label: '参数',
                  value: _argsController.text,
                ),
            ] else ...[
              const SectionHeader(title: 'SSE URL'),
              const SizedBox(height: 8),
              if (_isEditMode)
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    hintText: '例如: http://localhost:3001/sse',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link, color: Colors.blue),
                  ),
                  onChanged: (_) => _checkUnsavedChanges(),
                )
              else
                ReadOnlyField(
                  icon: Icons.link,
                  iconColor: Colors.blue,
                  label: 'URL',
                  value: _urlController.text,
                ),
            ],

            const SizedBox(height: 16),

            // Description
            Card(
              color: cs.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _transportType == McpTransportType.stdio
                            ? 'stdio 模式：在本地启动一个子进程作为 MCP 服务器，通过标准输入/输出通信。推荐用于本地工具。'
                            : 'SSE 模式：连接到一个远程 MCP 服务器，通过 HTTP SSE 通信。推荐用于远程服务。',
                        style:
                            TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransportSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildTransportOption(
            McpTransportType.stdio,
            Icons.desktop_windows,
            '本地 (stdio)',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTransportOption(
            McpTransportType.sse,
            Icons.cloud,
            '远程 (SSE)',
          ),
        ),
      ],
    );
  }

  Widget _buildTransportOption(
      McpTransportType type, IconData icon, String label) {
    final selected = _transportType == type;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        setState(() {
          _transportType = type;
          _checkUnsavedChanges();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyTransport() {
    final cs = Theme.of(context).colorScheme;
    final icon = _transportType == McpTransportType.stdio
        ? Icons.desktop_windows
        : Icons.cloud;
    final label =
        _transportType == McpTransportType.stdio ? '本地 (stdio)' : '远程 (SSE)';
    return ReadOnlyField(
      icon: icon,
      iconColor: cs.primary,
      label: '传输方式',
      value: label,
    );
  }

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
    return [
      if (_isExistingConfig && !_isVendor)
        TextButton.icon(
          icon: const Icon(Icons.edit, size: 20),
          label: const Text('编辑'),
          onPressed: _enterEditMode,
        ),
    ];
  }
}
