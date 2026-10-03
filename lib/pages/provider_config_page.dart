import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/provider_config.dart';
import 'provider_config_detail_page.dart';
import 'mcp_server_config_page.dart';
import 'provider_settings_panel.dart';

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

  Future<void> _addConfig({String? groupId}) async {
    final entry = _entry;
    if (entry == null) return;

    if (entry.type == 'mcp') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => McpServerConfigPage(
            entryId: widget.entryId,
            configIndex: -1,
            groupId: groupId,
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

    // onReorderItem 的 newIndex 已是移除后的索引，直接使用
    var configs = entry.configs.map((c) => c.copy()).toList();
    final item = configs.removeAt(oldIndex);
    configs.insert(newIndex, item);

    final updated = ProviderEntry(
      id: entry.id,
      type: entry.type,
      name: entry.name,
      configs: configs,
      enabled: entry.enabled,
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
      enabled: entry.enabled,
    );

    await ref.read(providerEntriesProvider.notifier).update(entry.id, updated);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openSettingsPanel(int configIndex) async {
    final entry = _entry;
    if (entry == null ||
        configIndex < 0 ||
        configIndex >= entry.configs.length) {
      return;
    }

    final result = await showProviderSettingsPanel(
      context: context,
      config: entry.configs[configIndex],
      providerType: entry.type,
    );

    if (result != null && mounted) {
      var configs = entry.configs.map((c) => c.copy()).toList();
      configs[configIndex] = result;
      final updated = ProviderEntry(
        id: entry.id,
        type: entry.type,
        name: entry.name,
        configs: configs,
        enabled: entry.enabled,
      );
      await ref
          .read(providerEntriesProvider.notifier)
          .update(entry.id, updated);
      if (!mounted) return;
      setState(() {});
    }
  }

  /// 切换 MCP 总开关。关闭后 MCP 工具不再发布，助手页面与对话页
  /// 都不再显示这些工具。
  Future<void> _toggleMcpEnabled(bool value) async {
    final entry = _entry;
    if (entry == null || entry.type != 'mcp') return;

    final updated = ProviderEntry(
      id: entry.id,
      type: entry.type,
      name: entry.name,
      configs: entry.configs,
      enabled: value,
    );
    await ref.read(providerEntriesProvider.notifier).update(entry.id, updated);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _setMcpGroupEnabled(McpProviderGroup group, bool value) async {
    await ref
        .read(providerEntriesProvider.notifier)
        .setMcpGroupEnabled(group.id, value);
    if (mounted) setState(() {});
  }

  Future<String?> _showGroupNameDialog({String? initialName}) async {
    final controller = TextEditingController(text: initialName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(initialName == null ? '新建组别' : '编辑组别'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(labelText: '组别名称'),
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _createMcpGroup() async {
    final name = await _showGroupNameDialog();
    if (name == null || name.isEmpty || !mounted) return;
    final groups = ref.read(providerEntriesProvider).mcpGroups;
    if (groups.any((group) => group.name.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('组别名称已存在')));
      return;
    }
    await ref
        .read(providerEntriesProvider.notifier)
        .addMcpGroup(McpProviderGroup.custom(name));
    if (mounted) setState(() {});
  }

  Future<void> _editMcpGroup(McpProviderGroup group) async {
    if (group.isBuiltin) return;
    final name = await _showGroupNameDialog(initialName: group.name);
    if (name == null || name.isEmpty || !mounted) return;
    final groups = ref.read(providerEntriesProvider).mcpGroups;
    if (groups.any(
      (item) =>
          item.id != group.id && item.name.toLowerCase() == name.toLowerCase(),
    )) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('组别名称已存在')));
      return;
    }
    await ref
        .read(providerEntriesProvider.notifier)
        .updateMcpGroup(group.copyWith(name: name));
    if (mounted) setState(() {});
  }

  Future<void> _deleteMcpGroup(McpProviderGroup group) async {
    if (group.isBuiltin) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除组别'),
        content: Text('删除“${group.name}”后，其中的配置会移到“其他 MCP 服务”。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除组别'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(providerEntriesProvider.notifier).removeMcpGroup(group.id);
    if (mounted) setState(() {});
  }

  Future<void> _moveMcpConfig(ProviderConfigItem config) async {
    final groups = ref.read(providerEntriesProvider).mcpGroups;
    final currentGroupId =
        config.groupId ?? defaultMcpGroupIdForProvider(config.providerName);
    final targetGroupId = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('移动到组别'),
        children: [
          for (final group in groups.where((g) => g.id != currentGroupId))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, group.id),
              child: Text(group.name),
            ),
        ],
      ),
    );
    if (targetGroupId == null) return;
    await ref
        .read(providerEntriesProvider.notifier)
        .moveMcpConfigToGroup(config.id, targetGroupId);
    if (mounted) setState(() {});
  }

  Future<void> _reorderMcpGroupConfigs(
    ProviderEntry entry,
    String groupId,
    int oldIndex,
    int newIndex,
  ) async {
    final configs = entry.configs.map((config) => config.copy()).toList();
    final groupIndices = [
      for (var i = 0; i < configs.length; i++)
        if ((configs[i].groupId ??
                defaultMcpGroupIdForProvider(configs[i].providerName)) ==
            groupId)
          i,
    ];
    if (oldIndex < 0 ||
        oldIndex >= groupIndices.length ||
        newIndex < 0 ||
        newIndex >= groupIndices.length) {
      return;
    }
    final groupConfigs = groupIndices.map((index) => configs[index]).toList();
    final moved = groupConfigs.removeAt(oldIndex);
    groupConfigs.insert(newIndex, moved);
    for (var i = 0; i < groupIndices.length; i++) {
      configs[groupIndices[i]] = groupConfigs[i];
    }
    await ref.read(providerEntriesProvider.notifier).update(
          entry.id,
          ProviderEntry(
            id: entry.id,
            type: entry.type,
            name: entry.name,
            configs: configs,
            enabled: entry.enabled,
          ),
        );
    if (mounted) setState(() {});
  }

  Widget _buildMcpConfigCard(
    ProviderEntry entry,
    ProviderConfigItem config,
    int groupIndex,
  ) {
    final fullIndex = entry.configs.indexOf(config);
    final providerName =
        config.providerName.isNotEmpty ? config.providerName : '（未命名）';
    final typeConfig =
        config.models.isNotEmpty ? config.models[0].typeConfig : null;
    final isVendor = typeConfig?['isVendor'] as bool? ?? false;
    final isHttpTool = typeConfig?['isHttpTool'] as bool? ?? false;
    final transport = typeConfig?['transport'] as String? ?? 'sse';
    late final String subtitle;
    late final IconData leadIcon;
    late final Color iconColor;
    if (isHttpTool) {
      final url = typeConfig?['url'] as String? ?? '';
      leadIcon = Icons.http;
      iconColor = Colors.orange;
      subtitle = 'HTTP 工具: ${url.isNotEmpty ? url : '(未设置)'}';
    } else if (transport == 'stdio') {
      leadIcon = Icons.desktop_windows;
      iconColor = Colors.purple;
      subtitle = '本地(stdio): ${typeConfig?['command'] as String? ?? ''}';
    } else {
      final url = typeConfig?['url'] as String? ?? config.host;
      leadIcon = Icons.cloud;
      iconColor = Colors.blue;
      subtitle = '远程(SSE): ${url.isNotEmpty ? url : '(未设置 URL)'}';
    }
    return _McpConfigCard(
      key: ValueKey('config_${widget.entryId}_${config.id}'),
      isVendor: isVendor,
      providerName: providerName,
      leadIcon: leadIcon,
      iconColor: iconColor,
      subtitle: subtitle,
      apiKeyHint: typeConfig?['apiKeyHint'] as String?,
      mcpDescription: typeConfig?['description'] as String?,
      dragHandle: ReorderableDragStartListener(
        index: groupIndex,
        child: const Icon(Icons.drag_handle, color: Colors.grey),
      ),
      onSettings: () => _openSettingsPanel(fullIndex),
      onDelete: isVendor ? null : () => _deleteConfig(fullIndex),
      onMove: isVendor ? null : () => _moveMcpConfig(config),
      onTap: () => _editConfig(fullIndex),
    );
  }

  Widget _buildMcpGroupsPage(
    ProviderEntry entry,
    List<McpProviderGroup> groups,
  ) {
    final configsByGroup = <String, List<ProviderConfigItem>>{
      for (final group in groups)
        group.id: entry.configs.where((config) {
          final groupId = config.groupId ??
              defaultMcpGroupIdForProvider(config.providerName);
          return groupId == group.id;
        }).toList(),
    };
    return Scaffold(
      appBar: AppBar(title: Text(entry.name), centerTitle: true),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    Text(
                      '供应商组别',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(
                        Icons.create_new_folder_outlined,
                        size: 18,
                      ),
                      label: const Text('新建组别'),
                      onPressed: _createMcpGroup,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _McpMasterSwitchCard(
                  enabled: entry.enabled,
                  onChanged: _toggleMcpEnabled,
                ),
              ]),
            ),
          ),
          for (final group in groups) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _McpGroupHeaderCard(
                  group: group,
                  itemCount: (configsByGroup[group.id]?.length ?? 0) +
                      (group.id == builtinSearchMcpGroupId ? 1 : 0),
                  onEnabledChanged: (value) =>
                      _setMcpGroupEnabled(group, value),
                  onAdd: () => _addConfig(groupId: group.id),
                  onEdit: group.isBuiltin ? null : () => _editMcpGroup(group),
                  onDelete:
                      group.isBuiltin ? null : () => _deleteMcpGroup(group),
                ),
              ),
            ),
            if (group.id == builtinSearchMcpGroupId)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: const SliverToBoxAdapter(
                  child: _BuiltinWebSearchCard(),
                ),
              ),
            if (configsByGroup[group.id]?.isEmpty ?? true)
              if (group.id != builtinSearchMcpGroupId)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      '此组暂无配置，点击“添加”加入内容。',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            if (configsByGroup[group.id]?.isNotEmpty ?? false)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverReorderableList(
                  itemCount: configsByGroup[group.id]!.length,
                  onReorderItem: (oldIndex, newIndex) =>
                      _reorderMcpGroupConfigs(
                    entry,
                    group.id,
                    oldIndex,
                    newIndex,
                  ),
                  proxyDecorator: (child, index, animation) => Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(12),
                    child: child,
                  ),
                  itemBuilder: (context, index) => _buildMcpConfigCard(
                    entry,
                    configsByGroup[group.id]![index],
                    index,
                  ),
                ),
              ),
          ],
          const SliverPadding(padding: EdgeInsets.all(16)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entriesState = ref.watch(providerEntriesProvider);
    final entry =
        entriesState.entries.where((e) => e.id == widget.entryId).firstOrNull;
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('配置')),
        body: const Center(child: Text('供应商未找到')),
      );
    }

    if (entry.type == 'mcp') {
      return _buildMcpGroupsPage(entry, entriesState.mcpGroups);
    }

    return Scaffold(
      appBar: AppBar(title: Text(entry.name), centerTitle: true),
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
                // MCP 总开关：仅 MCP 条目显示。关闭后 MCP 服务器工具
                // 不在助手页面显示，也无法在对话页使用。
                if (entry.type == 'mcp') ...[
                  _McpMasterSwitchCard(
                    enabled: entry.enabled,
                    onChanged: _toggleMcpEnabled,
                  ),
                  const SizedBox(height: 8),
                ],
              ]),
            ),
          ),
          if (entry.configs.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    '暂无供应商配置，请点击"添加"创建',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverReorderableList(
                itemCount: entry.configs.length,
                onReorderItem: _reorderConfigs,
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

                  // Determine if this is a built-in (vendor) MCP config
                  final mcpTypeConfig =
                      entry.type == 'mcp' && config.models.isNotEmpty
                          ? config.models[0].typeConfig
                          : null;
                  final isVendor = mcpTypeConfig?['isVendor'] as bool? ?? false;

                  // For MCP entries, show transport details
                  String subtitle;
                  IconData leadIcon;
                  Color iconColor;
                  final isHttpTool = entry.type == 'mcp'
                      ? (mcpTypeConfig?['isHttpTool'] as bool? ?? false)
                      : false;

                  if (entry.type == 'mcp') {
                    final transport =
                        mcpTypeConfig?['transport'] as String? ?? 'sse';

                    if (isHttpTool) {
                      // HTTP 工具（纯 Dart 实现，非 MCP 协议）
                      final url = mcpTypeConfig?['url'] as String? ?? '';
                      leadIcon = Icons.http;
                      iconColor = Colors.orange;
                      subtitle = 'HTTP 工具: ${url.isNotEmpty ? url : '(未设置)'}';
                    } else if (transport == 'stdio') {
                      final cmd = mcpTypeConfig?['command'] as String? ?? '';
                      leadIcon = Icons.desktop_windows;
                      iconColor = Colors.purple;
                      subtitle = '本地(stdio): $cmd';
                    } else {
                      final url =
                          mcpTypeConfig?['url'] as String? ?? config.host;
                      leadIcon = Icons.cloud;
                      iconColor = Colors.blue;
                      subtitle =
                          '远程(SSE): ${url.isNotEmpty ? url : '(未设置 URL)'}';
                    }
                  } else {
                    leadIcon = Icons.dns;
                    iconColor = Colors.teal;
                    subtitle =
                        config.host.isNotEmpty ? config.host : '(未设置 Host)';
                  }

                  // Show API key hint if available
                  final apiKeyHint = mcpTypeConfig?['apiKeyHint'] as String?;

                  // Description text (replaces platform badges)
                  final mcpDescription = entry.type == 'mcp'
                      ? (mcpTypeConfig?['description'] as String?)
                      : null;

                  return _McpConfigCard(
                    key: ValueKey('config_${widget.entryId}_$i'),
                    isVendor: isVendor,
                    providerName: providerName,
                    leadIcon: leadIcon,
                    iconColor: iconColor,
                    subtitle: subtitle,
                    apiKeyHint: apiKeyHint,
                    mcpDescription: mcpDescription,
                    dragHandle: !isVendor
                        ? ReorderableDragStartListener(
                            index: i,
                            child: const Icon(
                              Icons.drag_handle,
                              color: Colors.grey,
                            ),
                          )
                        : const SizedBox(width: 32),
                    onSettings: () => _openSettingsPanel(i),
                    onDelete: isVendor ? null : () => _deleteConfig(i),
                    onTap: () => _editConfig(i),
                  );
                },
              ),
            ),
          const SliverPadding(padding: EdgeInsets.all(16)),
        ],
      ),
    );
  }
}

// ====================================================================
// _McpConfigCard — MCP / provider entry card.
//
// 卡片样式与 LLM 供应商页等其它设置条目的卡片保持一致：所有卡片
// （内置/用户添加、stdio/SSE/HTTP）统一使用主题自适应的中性背景
// （浅色模式 surfaceContainerLow / 深色模式 surfaceContainerHigh）
// 与柔和的 outlineVariant 描边，不再区分内置供应商配色——深浅色
// 模式下都清晰可辨，页面整体观感一致。
// ====================================================================

class _McpConfigCard extends StatelessWidget {
  final bool isVendor;
  final String providerName;
  final IconData leadIcon;
  final Color iconColor;
  final String subtitle;
  final String? apiKeyHint;
  final String? mcpDescription;
  final Widget dragHandle;
  final VoidCallback onSettings;
  final VoidCallback? onDelete;
  final VoidCallback? onMove;
  final VoidCallback onTap;

  const _McpConfigCard({
    super.key,
    required this.isVendor,
    required this.providerName,
    required this.leadIcon,
    required this.iconColor,
    required this.subtitle,
    required this.apiKeyHint,
    required this.mcpDescription,
    required this.dragHandle,
    required this.onSettings,
    required this.onDelete,
    this.onMove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 统一卡片配色（对齐 LLM 供应商页）：中性背景 + 柔和描边。
    final Color backgroundColor =
        isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow;
    final Color borderColor = cs.outlineVariant.withValues(alpha: 0.5);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                dragHandle,
                const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(leadIcon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              providerName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isVendor) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '内置',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: cs.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (apiKeyHint != null && apiKeyHint!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '提示: $apiKeyHint',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (mcpDescription != null &&
                          mcpDescription!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          mcpDescription!,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.tune, size: 20, color: cs.onSurfaceVariant),
                  onPressed: onSettings,
                  tooltip: '设置',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                if (onMove != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.drive_file_move_outline,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                    onPressed: onMove,
                    tooltip: '移动到组别',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
                if (onDelete != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 20, color: cs.error),
                    onPressed: onDelete,
                    tooltip: '删除配置',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _McpGroupHeaderCard extends StatelessWidget {
  final McpProviderGroup group;
  final int itemCount;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onAdd;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _McpGroupHeaderCard({
    required this.group,
    required this.itemCount,
    required this.onEnabledChanged,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (group.isBuiltin) ...[
                        const SizedBox(width: 6),
                        Text(
                          '内置',
                          style: TextStyle(
                            fontSize: 10,
                            color: cs.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$itemCount 项内容',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (onEdit != null || onDelete != null)
              PopupMenuButton<String>(
                tooltip: '组别操作',
                onSelected: (action) {
                  if (action == 'edit') {
                    onEdit?.call();
                  } else {
                    onDelete?.call();
                  }
                },
                itemBuilder: (context) => [
                  if (onEdit != null)
                    const PopupMenuItem(value: 'edit', child: Text('编辑组别')),
                  if (onDelete != null)
                    const PopupMenuItem(value: 'delete', child: Text('删除组别')),
                ],
              ),
            IconButton(
              onPressed: onAdd,
              tooltip: '添加内容',
              icon: const Icon(Icons.add_circle_outline),
            ),
            Switch(value: group.enabled, onChanged: onEnabledChanged),
          ],
        ),
      ),
    );
  }
}

class _BuiltinWebSearchCard extends StatelessWidget {
  const _BuiltinWebSearchCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: ListTile(
        leading: Icon(Icons.travel_explore, color: cs.primary),
        title: const Text('网页搜索'),
        subtitle: const Text('Google、Bing、百度，使用 web_search 工具'),
        trailing: Text(
          '内置',
          style: TextStyle(
            color: cs.primary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// _McpMasterSwitchCard — MCP 总开关卡片（MCP 列表页顶部）。
//
// 与下方配置卡片同风格（中性背景 + 柔和描边）。关闭后 MCP 服务器工具
// 不再发布：助手页面的"默认设置"tab 与对话页的工具列表都看不到 MCP
// 服务器工具，也无法使用（内置 HTTP 工具不受此开关影响）。
// ====================================================================

class _McpMasterSwitchCard extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _McpMasterSwitchCard({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor =
        isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      // 裁剪到圆角：SwitchListTile 的 ink 涟漪是矩形，不裁剪会画出方角。
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
            value: enabled,
            onChanged: onChanged,
            activeThumbColor: cs.primary,
            title: Text(
              'MCP 总开关',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              enabled ? '已开启：MCP 服务器工具可用。' : '已关闭：MCP 服务器工具不在助手页面与对话页中显示。',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }
}
