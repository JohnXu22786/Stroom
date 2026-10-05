import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tool_call.dart';
import '../providers/provider_config.dart';
import '../services/connectivity_test_service.dart';
import '../services/http_tool_service.dart';
import '../services/todo_tool_service.dart';
import '../services/web_search_service.dart';
import 'connectivity_test_dialog.dart';
import 'provider_config_detail_page.dart';
import 'mcp_server_config_page.dart';
import 'provider_config_tool_dialogs.dart';
import 'provider_settings_panel.dart';

final _builtinToolDefinitions = [
  ...TodoToolService.toolDefinitions,
  ...WebSearchService.toolDefinitions,
];

ToolDefinition? _httpToolDefinition(String providerName) {
  final toolName = switch (providerName) {
    'Brave Search' => 'brave_web_search',
    'Bocha' => 'bocha_web_search',
    'Querit' => 'querit_search',
    'Searxng' => 'searxng_search',
    _ => null,
  };
  if (toolName == null) return null;
  for (final definition in HttpToolService.toolDefinitions) {
    if (definition.name == toolName) return definition;
  }
  return null;
}

class ProviderConfigPage extends ConsumerStatefulWidget {
  final String entryId;
  const ProviderConfigPage({super.key, required this.entryId});

  @override
  ConsumerState<ProviderConfigPage> createState() => _ProviderConfigPageState();
}

class _ProviderConfigPageState extends ConsumerState<ProviderConfigPage> {
  ProviderEntry? get _entry {
    if (widget.entryId == kBuiltinWebSearchEntryId) {
      return createBuiltinWebSearchEntry();
    }
    final state = ref.read(providerEntriesProvider);
    try {
      return state.entries.firstWhere((e) => e.id == widget.entryId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _addConfig({String? groupId}) async {
    final entry = _entry;
    if (entry == null || entry.id == kBuiltinWebSearchEntryId) return;

    if (entry.type == 'mcp') {
      await showMcpServerConfigDialog(
        context: context,
        entryId: widget.entryId,
        configIndex: -1,
        groupId: groupId,
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
    if (entry == null ||
        entry.id == kBuiltinWebSearchEntryId ||
        configIndex < 0 ||
        configIndex >= entry.configs.length) {
      return;
    }

    if (entry.type == 'mcp') {
      final config = entry.configs[configIndex];
      final typeConfig =
          config.models.isNotEmpty ? config.models[0].typeConfig : null;
      if (typeConfig?['isHttpTool'] == true) {
        await _editHttpToolConfig(configIndex);
        return;
      }

      await showMcpServerConfigDialog(
        context: context,
        entryId: widget.entryId,
        configIndex: configIndex,
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

  Future<void> _editHttpToolConfig(int configIndex) async {
    final entry = _entry;
    if (entry == null ||
        configIndex < 0 ||
        configIndex >= entry.configs.length) {
      return;
    }

    final config = entry.configs[configIndex];
    final definition = _httpToolDefinition(config.providerName);
    final updatedConfig = await showDialog<ProviderConfigItem>(
      context: context,
      builder: (_) =>
          HttpToolConfigDialog(config: config, definition: definition),
    );
    if (updatedConfig == null || !mounted) return;

    final configs = entry.configs.map((c) => c.copy()).toList();
    configs[configIndex] = updatedConfig;
    final updatedEntry = ProviderEntry(
      id: entry.id,
      type: entry.type,
      name: entry.name,
      configs: configs,
      enabled: entry.enabled,
    );
    await ref
        .read(providerEntriesProvider.notifier)
        .update(entry.id, updatedEntry);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _showBuiltinToolDetails(ToolDefinition definition) async {
    await showDialog<void>(
      context: context,
      builder: (_) => BuiltinToolDetailsDialog(definition: definition),
    );
  }

  Future<void> _testProviderConnectivity(int configIndex) async {
    final entry = _entry;
    if (entry == null ||
        configIndex < 0 ||
        configIndex >= entry.configs.length) {
      return;
    }

    final config = entry.configs[configIndex];
    final typeConfig = config.models.isNotEmpty
        ? config.models[0].typeConfig
        : config.typeConfig;
    final isHttpTool = typeConfig['isHttpTool'] == true;
    await showDialog<void>(
      context: context,
      builder: (_) => ConnectivityTestDialog(
        title: config.providerName,
        initialContent: ConnectivityTestService.configuredTestContent(
          config,
          isHttpTool: isHttpTool,
        ),
        note: _connectivityTestNote,
        onSave: (content) => _saveProviderConnectivityTest(
          configIndex,
          content,
        ),
        onRun: (content) => ConnectivityTestService.runProviderTest(
          config: config,
          testContent: content,
        ),
      ),
    );
  }

  Future<void> _saveProviderConnectivityTest(
    int configIndex,
    Map<String, dynamic> content,
  ) async {
    final entry = _entry;
    if (entry == null ||
        configIndex < 0 ||
        configIndex >= entry.configs.length) {
      return;
    }

    final configs = entry.configs.map((config) => config.copy()).toList();
    final config = configs[configIndex];
    if (config.models.isNotEmpty) {
      final model = config.models[0];
      model.typeConfig = Map<String, dynamic>.from(model.typeConfig)
        ..['connectivityTest'] = content;
    } else {
      config.typeConfig = Map<String, dynamic>.from(config.typeConfig)
        ..['connectivityTest'] = content;
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
          requirePersistence: true,
        );
  }

  Future<void> _testBuiltinTool(ToolDefinition definition) async {
    final initialContent = await ConnectivityTestService.loadBuiltinTestContent(
      definition.name,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => ConnectivityTestDialog(
        title: definition.name,
        initialContent: initialContent,
        note: _connectivityTestNote,
        onSave: (content) => ConnectivityTestService.saveBuiltinTestContent(
          definition.name,
          content,
        ),
        onRun: (content) => ConnectivityTestService.runBuiltinTest(
          toolName: definition.name,
          testContent: content,
        ),
      ),
    );
  }

  static const _connectivityTestNote =
      '测试会向对应服务发出真实请求。MCP 仅调用只读 tools/list，HTTP/网页搜索会执行一次查询；'
      'Todo 默认读取清单；为保护当前数据，todos 参数必须省略或设置为 null。';

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
    if (entry == null ||
        entry.type != 'mcp' ||
        entry.id == kBuiltinWebSearchEntryId) {
      return;
    }

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
    final integrationType = isHttpTool
        ? 'HTTP 搜索'
        : 'MCP · ${transport == 'stdio' ? 'stdio' : 'SSE'}';
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
      // The full entry index stays unique across groups and preserves the
      // stable key used by existing card finders.
      key: ValueKey('config_${widget.entryId}_$fullIndex'),
      isMcp: true,
      isVendor: isVendor,
      integrationType: integrationType,
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
      onSettings: null,
      onDelete: isVendor ? null : () => _deleteConfig(fullIndex),
      onTest: () => _testProviderConnectivity(fullIndex),
      onMove: isVendor ? null : () => _moveMcpConfig(config),
      onTap: () => _editConfig(fullIndex),
    );
  }

  Widget _buildMcpGroupsPage(
    ProviderEntry entry,
    List<McpProviderGroup> groups,
  ) {
    final webSearchDefinition = _builtinToolDefinitions.firstWhere(
      (definition) => definition.name == 'web_search',
    );
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverToBoxAdapter(
              child: _McpPageIntro(colorScheme: Theme.of(context).colorScheme),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _McpMasterSwitchCard(
                    enabled: entry.enabled,
                    onChanged: _toggleMcpEnabled,
                  ),
                  const SizedBox(height: 24),
                  _McpSectionHeader(
                    title: '服务配置',
                    description: '按组管理远程连接、本地 stdio 与 HTTP 搜索',
                    count: entry.configs.length,
                    action: FilledButton.tonalIcon(
                      onPressed: _createMcpGroup,
                      icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                      label: const Text('新建组别'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (entry.configs.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _McpEmptyState(
                  onAdd: () => _addConfig(groupId: builtinMcpServicesGroupId),
                ),
              ),
            ),
          for (final group in groups) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: _buildBuiltinToolCard(webSearchDefinition),
                ),
              ),
            if (configsByGroup[group.id]?.isEmpty ?? true)
              if (group.id != builtinSearchMcpGroupId)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            sliver: SliverToBoxAdapter(
              child: _McpSectionHeader(
                title: '内置工具',
                description: 'Stroom 提供的本地工具接口；网页搜索归入对应服务组。',
                count: _builtinToolDefinitions.length - 1,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final definition = _builtinToolDefinitions
                      .where((definition) => definition.name != 'web_search')
                      .elementAt(index);
                  return _buildBuiltinToolCard(definition);
                },
                childCount: _builtinToolDefinitions.length - 1,
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.all(20)),
        ],
      ),
    );
  }

  Widget _buildBuiltinToolCard(ToolDefinition definition) {
    return _McpConfigCard(
      key: ValueKey('builtin_tool_${definition.name}'),
      isMcp: true,
      isVendor: false,
      integrationType: '内置工具',
      providerName: definition.name,
      leadIcon: Icons.build_outlined,
      iconColor: Colors.deepPurple,
      subtitle: 'Stroom 工具接口',
      apiKeyHint: null,
      mcpDescription: definition.description,
      dragHandle: const SizedBox(width: 32),
      settingsIcon: Icons.info_outline,
      settingsTooltip: '查看接口',
      onSettings: () => _showBuiltinToolDetails(definition),
      onDelete: null,
      onTest: () => _testBuiltinTool(definition),
      onTap: () => _showBuiltinToolDetails(definition),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entriesState = ref.watch(providerEntriesProvider);
    final entry = widget.entryId == kBuiltinWebSearchEntryId
        ? createBuiltinWebSearchEntry()
        : entriesState.entries.where((e) => e.id == widget.entryId).firstOrNull;
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('配置')),
        body: const Center(child: Text('供应商未找到')),
      );
    }
    if (entry.type == 'mcp') {
      return _buildMcpGroupsPage(entry, entriesState.mcpGroups);
    }
    final isBuiltinWebSearch = entry.id == kBuiltinWebSearchEntryId;
    final cs = Theme.of(context).colorScheme;

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
                      isBuiltinWebSearch ? '内置工具' : '供应商配置',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                    const Spacer(),
                    if (!isBuiltinWebSearch)
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('添加'),
                        onPressed: _addConfig,
                      ),
                  ],
                ),
              ]),
            ),
          ),
          if (entry.configs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    isBuiltinWebSearch
                        ? '内置网络搜索支持 Google、Bing 和百度，模型调用名为 web_search。'
                        : '暂无供应商配置，请点击"添加"创建',
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
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
                itemBuilder: (context, index) {
                  final config = entry.configs[index];
                  final providerName = config.providerName.isNotEmpty
                      ? config.providerName
                      : '（未命名）';
                  return _McpConfigCard(
                    key: ValueKey('config_${widget.entryId}_$index'),
                    isMcp: false,
                    isVendor: false,
                    integrationType: '',
                    providerName: providerName,
                    leadIcon: Icons.dns,
                    iconColor: Colors.teal,
                    subtitle: config.host.isNotEmpty
                        ? config.host
                        : '(未设置 Host)',
                    apiKeyHint: null,
                    mcpDescription: null,
                    dragHandle: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                    onSettings: () => _openSettingsPanel(index),
                    onDelete: () => _deleteConfig(index),
                    onTap: () => _editConfig(index),
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

class _McpPageIntro extends StatelessWidget {
  final ColorScheme colorScheme;

  const _McpPageIntro({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child:
              Icon(Icons.hub_outlined, color: colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '服务与工具',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '管理 MCP 服务器、HTTP 搜索和 Stroom 内置工具。',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _McpSectionHeader extends StatelessWidget {
  final String title;
  final String description;
  final int count;
  final Widget? action;

  const _McpSectionHeader({
    required this.title,
    required this.description,
    required this.count,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 12),
          action!,
        ],
      ],
    );
  }
}

class _McpEmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _McpEmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Column(
        children: [
          Icon(Icons.hub_outlined, size: 30, color: cs.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            '还没有服务配置',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '添加一个 MCP 服务或 HTTP 搜索接口，连接后即可在助手中使用。',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('添加服务'),
          ),
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
  final bool isMcp;
  final bool isVendor;
  final String integrationType;
  final String providerName;
  final IconData leadIcon;
  final Color iconColor;
  final String subtitle;
  final String? apiKeyHint;
  final String? mcpDescription;
  final Widget dragHandle;
  final VoidCallback? onSettings;
  final IconData settingsIcon;
  final String settingsTooltip;
  final VoidCallback? onDelete;
  final VoidCallback? onTest;
  final VoidCallback? onMove;
  final VoidCallback onTap;

  const _McpConfigCard({
    super.key,
    required this.isMcp,
    required this.isVendor,
    required this.integrationType,
    required this.providerName,
    required this.leadIcon,
    required this.iconColor,
    required this.subtitle,
    required this.apiKeyHint,
    required this.mcpDescription,
    required this.dragHandle,
    required this.onSettings,
    this.settingsIcon = Icons.tune,
    this.settingsTooltip = '设置',
    required this.onDelete,
    this.onTest,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMcp ? 14 : 12,
                vertical: isMcp ? 12 : 10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  dragHandle,
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isMcp
                          ? cs.primaryContainer
                          : cs.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      leadIcon,
                      color: isMcp ? cs.onPrimaryContainer : iconColor,
                      size: 22,
                    ),
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
                                  color: isMcp
                                      ? cs.surfaceContainerHighest
                                      : cs.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '内置',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMcp
                                        ? cs.onSurfaceVariant
                                        : cs.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                            if (integrationType.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isMcp
                                      ? cs.secondaryContainer
                                      : cs.tertiaryContainer.withValues(
                                          alpha: 0.55,
                                        ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  integrationType,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMcp
                                        ? cs.onSecondaryContainer
                                        : cs.onTertiaryContainer,
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
                  if (onSettings != null)
                    IconButton(
                      icon: Icon(
                        settingsIcon,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                      onPressed: onSettings,
                      tooltip: settingsTooltip,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  if (onTest != null)
                    IconButton(
                      icon: const Icon(Icons.network_check, size: 20),
                      onPressed: onTest,
                      tooltip: '连通性测试',
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
                      icon:
                          Icon(Icons.delete_outline, size: 20, color: cs.error),
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

// ====================================================================
// _McpMasterSwitchCard — MCP 总开关卡片（MCP 列表页顶部）。
//
// 与下方配置卡片同风格（中性背景 + 柔和描边）。关闭后 MCP 服务器和
// 内置搜索工具都不再提供给助手页面或对话页。
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
          child: InkWell(
            onTap: () => onChanged(!enabled),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.power_settings_new,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'MCP 服务器',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _McpStatusLabel(enabled: enabled),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '控制 MCP 服务器与内置搜索工具在助手和对话中的可用性。',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(value: enabled, onChanged: onChanged),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _McpStatusLabel extends StatelessWidget {
  final bool enabled;

  const _McpStatusLabel({required this.enabled});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: enabled ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        enabled ? '已启用' : '已停用',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: enabled ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
