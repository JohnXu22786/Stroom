import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/provider_config.dart';
import 'provider_config_detail_page.dart';
import 'mcp_server_config_page.dart';

class ProviderConfigPage extends ConsumerStatefulWidget {
  final String entryId;
  const ProviderConfigPage({super.key, required this.entryId});

  @override
  ConsumerState<ProviderConfigPage> createState() => _ProviderConfigPageState();
}

class _ProviderConfigPageState extends ConsumerState<ProviderConfigPage> {
  ProviderEntry? get _entry {
    final state = ref.read(providerEntriesProvider);
    try {
      return state.entries.firstWhere((e) => e.id == widget.entryId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _addConfig() async {
    final entry = _entry;
    if (entry == null) return;

    if (entry.type == 'mcp') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => McpServerConfigPage(
            entryId: widget.entryId,
            configIndex: -1,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProviderConfigDetailPage(
            entryId: widget.entryId,
            configIndex: -1,
          ),
        ),
      );
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _editConfig(int configIndex) async {
    final entry = _entry;
    if (entry == null) return;

    if (entry.type == 'mcp') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => McpServerConfigPage(
            entryId: widget.entryId,
            configIndex: configIndex,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProviderConfigDetailPage(
            entryId: widget.entryId,
            configIndex: configIndex,
          ),
        ),
      );
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _reorderConfigs(int oldIndex, int newIndex) async {
    final entry = _entry;
    if (entry == null) return;

    if (oldIndex < newIndex) newIndex -= 1;

    var configs = entry.configs.map((c) => c.copy()).toList();
    final item = configs.removeAt(oldIndex);
    configs.insert(newIndex, item);

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

  Future<void> _deleteConfig(int configIndex) async {
    final entry = _entry;
    if (entry == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除配置'),
        content: const Text('确定要删除此供应商配置及其所有模型吗？'),
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

    var configs = entry.configs.map((c) => c.copy()).toList();
    configs.removeAt(configIndex);

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

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('配置')),
        body: const Center(child: Text('供应商未找到')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(entry.name),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 供应商配置列表
                Row(
                  children: [
                    Text(
                      '供应商配置',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('添加'),
                      onPressed: _addConfig,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ]),
            ),
          ),
          if (entry.configs.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('暂无供应商配置，请点击"添加"创建',
                      style: TextStyle(color: Colors.grey)),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverReorderableList(
                itemCount: entry.configs.length,
                onReorder: _reorderConfigs,
                proxyDecorator: (child, index, animation) => Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                ),
                itemBuilder: (context, i) {
                  final config = entry.configs[i];
                  final providerName = config.providerName.isNotEmpty
                      ? config.providerName
                      : '（未命名）';

                  // For MCP entries, show transport details
                  String subtitle;
                  IconData leadIcon;
                  Color iconColor;

                  if (entry.type == 'mcp') {
                    final mcpTypeConfig =
                        config.models.isNotEmpty ? config.models[0].typeConfig : null;
                    final transport = mcpTypeConfig?['transport'] as String? ?? 'sse';
                    if (transport == 'stdio') {
                      final cmd = mcpTypeConfig?['command'] as String? ?? '';
                      leadIcon = Icons.desktop_windows;
                      iconColor = Colors.purple;
                      subtitle = '本地(stdio): $cmd';
                    } else {
                      final url = mcpTypeConfig?['url'] as String? ?? config.host;
                      leadIcon = Icons.cloud;
                      iconColor = Colors.blue;
                      subtitle = '远程(SSE): ${url.isNotEmpty ? url : '(未设置 URL)'}';
                    }
                  } else {
                    leadIcon = Icons.dns;
                    iconColor = Colors.teal;
                    subtitle = config.host.isNotEmpty ? config.host : '(未设置 Host)';
                  }

                  return Card(
                    key: ValueKey('config_${widget.entryId}_$i'),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: const Icon(Icons.drag_handle,
                                color: Colors.grey),
                          ),
                          const SizedBox(width: 8),
                          Icon(leadIcon, color: iconColor),
                        ],
                      ),
                      title: Text(providerName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(subtitle,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteConfig(i),
                            tooltip: '删除配置',
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      contentPadding: const EdgeInsets.only(left: 8, right: 4),
                      onTap: () => _editConfig(i),
                    ),
                  );
                },
              ),
            ),
          const SliverPadding(
            padding: EdgeInsets.all(16),
          ),
        ],
      ),
    );
  }
}
