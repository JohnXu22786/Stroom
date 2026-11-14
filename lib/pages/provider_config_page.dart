import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tool_call.dart';
import '../providers/provider_config.dart';
import '../providers/provider_config_display_names.dart';
import '../providers/provider_preset_localizations.dart';
import '../services/connectivity_test_service.dart';
import '../services/http_tool_service.dart';
import '../services/todo_tool_service.dart';
import '../services/web_search_service.dart';
import 'connectivity_test_dialog.dart';
import 'provider_config_detail_page.dart';
import 'mcp_server_config_page.dart';
import 'provider_config_tool_dialogs.dart';
import 'provider_settings_panel.dart';

import '../widgets/constrained_text.dart';

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
    final localizations = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (_) => ConnectivityTestDialog(
        title: config.providerName,
        initialContent: ConnectivityTestService.configuredTestContent(
          config,
          isHttpTool: isHttpTool,
        ),
        note: localizations.providerTestSafetyNote,
        onSave: (content) =>
            _saveProviderConnectivityTest(configIndex, content),
        onRun: (content) => ConnectivityTestService.runProviderTest(
          config: config,
          testContent: content,
          localizations: localizations,
          locale: Localizations.localeOf(context),
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
    final localizations = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (_) => ConnectivityTestDialog(
        title: definition.name,
        initialContent: initialContent,
        note: localizations.providerTestSafetyNote,
        onSave: (content) => ConnectivityTestService.saveBuiltinTestContent(
          definition.name,
          content,
        ),
        onRun: (content) => ConnectivityTestService.runBuiltinTest(
          toolName: definition.name,
          testContent: content,
          localizations: localizations,
          locale: Localizations.localeOf(context),
        ),
      ),
    );
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
        title: ConstrainedText(
          AppLocalizations.of(context)!.providerDeleteConfigTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: Text(
          AppLocalizations.of(context)!.providerDeleteConfigConfirm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: ConstrainedText(
              AppLocalizations.of(context)!.batchDlgCancel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: ConstrainedText(
              AppLocalizations.of(context)!.fileManagerDelete,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
        title: ConstrainedText(
          initialName == null
              ? AppLocalizations.of(context)!.providerCreateGroup
              : AppLocalizations.of(context)!.providerEditGroup,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.providerGroupName,
          ),
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: ConstrainedText(
              AppLocalizations.of(context)!.batchDlgCancel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: ConstrainedText(
              AppLocalizations.of(context)!.mermaidSaveButton,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.providerGroupNameExists),
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.providerGroupNameExists),
        ),
      );
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
        title: ConstrainedText(
          AppLocalizations.of(context)!.providerDeleteGroup,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: Text(
          AppLocalizations.of(context)!.providerDeleteGroupConfirm(group.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: ConstrainedText(
              AppLocalizations.of(context)!.batchDlgCancel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: ConstrainedText(
              AppLocalizations.of(context)!.providerDeleteGroup,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
        title: Text(AppLocalizations.of(context)!.providerMoveToGroup),
        children: [
          for (final group in groups.where((g) => g.id != currentGroupId))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, group.id),
              child: Text(
                mcpGroupDisplayName(group, AppLocalizations.of(context)!),
              ),
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
    final providerName = config.providerName.isNotEmpty
        ? config.providerName
        : AppLocalizations.of(context)!.providerUnnamed;
    final typeConfig =
        config.models.isNotEmpty ? config.models[0].typeConfig : null;
    final isVendor = typeConfig?['isVendor'] as bool? ?? false;
    final isHttpTool = typeConfig?['isHttpTool'] as bool? ?? false;
    final transport = typeConfig?['transport'] as String? ?? 'sse';
    final integrationType = isHttpTool
        ? AppLocalizations.of(context)!.providerHttpSearch
        : 'MCP · ${transport == 'stdio' ? 'stdio' : 'SSE'}';
    late final String subtitle;
    late final IconData leadIcon;
    late final Color iconColor;
    if (isHttpTool) {
      final url = typeConfig?['url'] as String? ?? '';
      leadIcon = Icons.http;
      iconColor = Colors.orange;
      subtitle = AppLocalizations.of(context)!.providerHttpToolSubtitle(
        url.isNotEmpty
            ? url
            : AppLocalizations.of(context)!.providerValueNotSet,
      );
    } else if (transport == 'stdio') {
      leadIcon = Icons.desktop_windows;
      iconColor = Colors.purple;
      subtitle = AppLocalizations.of(context)!
          .providerLocalStdioSubtitle(typeConfig?['command'] as String? ?? '');
    } else {
      final url = typeConfig?['url'] as String? ?? config.host;
      leadIcon = Icons.cloud;
      iconColor = Colors.blue;
      subtitle = AppLocalizations.of(context)!.providerRemoteSseSubtitle(
        url.isNotEmpty
            ? url
            : AppLocalizations.of(context)!.providerValueNotSet,
      );
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
      apiKeyHint: localizedProviderPresetApiKeyHint(
        AppLocalizations.of(context)!,
        providerName,
        typeConfig?['apiKeyHint'] as String?,
        isVendor: isVendor,
      ),
      mcpDescription: localizedProviderPresetDescription(
        AppLocalizations.of(context)!,
        providerName,
        typeConfig?['description'] as String?,
        isVendor: isVendor,
      ),
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
      appBar: AppBar(
        title: ConstrainedText(
          providerEntryDisplayName(entry, AppLocalizations.of(context)!),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
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
                    title: AppLocalizations.of(context)!.providerServices,
                    description: AppLocalizations.of(context)!
                        .providerServicesDescription,
                    count: entry.configs.length,
                    action: FilledButton.tonalIcon(
                      onPressed: _createMcpGroup,
                      icon: const Icon(
                        Icons.create_new_folder_outlined,
                        size: 18,
                      ),
                      label: Text(
                        AppLocalizations.of(context)!.providerCreateGroupAction,
                      ),
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
                      AppLocalizations.of(context)!.providerGroupEmpty,
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
                    borderRadius: BorderRadius.circular(16),
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
                title: AppLocalizations.of(context)!.providerBuiltinTools,
                description: AppLocalizations.of(context)!
                    .providerBuiltinToolsDescription,
                count: _builtinToolDefinitions.length - 1,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final definition = _builtinToolDefinitions
                    .where((definition) => definition.name != 'web_search')
                    .elementAt(index);
                return _buildBuiltinToolCard(definition);
              }, childCount: _builtinToolDefinitions.length - 1),
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
      integrationType: AppLocalizations.of(context)!.providerBuiltinTools,
      providerName: definition.name,
      leadIcon: Icons.build_outlined,
      iconColor: Colors.deepPurple,
      subtitle: AppLocalizations.of(context)!.providerBuiltinToolInterface,
      apiKeyHint: null,
      mcpDescription: definition.description,
      dragHandle: const SizedBox(width: 32),
      settingsIcon: Icons.info_outline,
      settingsTooltip: AppLocalizations.of(context)!.providerViewInterface,
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
        appBar: AppBar(
          title: ConstrainedText(
            AppLocalizations.of(context)!.providerConfigTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: Center(
          child: Text(AppLocalizations.of(context)!.providerNotFound),
        ),
      );
    }
    if (entry.type == 'mcp') {
      return _buildMcpGroupsPage(entry, entriesState.mcpGroups);
    }
    final isBuiltinWebSearch = entry.id == kBuiltinWebSearchEntryId;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: ConstrainedText(
          providerEntryDisplayName(entry, AppLocalizations.of(context)!),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    Text(
                      isBuiltinWebSearch
                          ? AppLocalizations.of(context)!.providerBuiltinTools
                          : AppLocalizations.of(context)!
                              .providerConfigurationHeading,
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
                        label: ConstrainedText(
                          AppLocalizations.of(context)!.builtInPromptAdd,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                        ? AppLocalizations.of(context)!
                            .providerBuiltinWebSearchEmpty
                        : AppLocalizations.of(context)!.providerNoConfigsAdd,
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
                  borderRadius: BorderRadius.circular(16),
                  child: child,
                ),
                itemBuilder: (context, index) {
                  final config = entry.configs[index];
                  final providerName = config.providerName.isNotEmpty
                      ? config.providerName
                      : AppLocalizations.of(context)!.providerUnnamed;
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
                        : AppLocalizations.of(context)!.providerNoHost,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.providerServicesAndTools,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: colorScheme.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          AppLocalizations.of(context)!.providerManageServicesDescription,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
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
        if (action != null) ...[const SizedBox(width: 12), action!],
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
            AppLocalizations.of(context)!.providerNoServices,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.providerAddServiceDescription,
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
            label: Text(AppLocalizations.of(context)!.providerAddService),
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
  final String? settingsTooltip;
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
    this.settingsTooltip,
    required this.onDelete,
    this.onTest,
    this.onMove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Keep provider rows neutral and consistent with the rest of settings.
    final Color backgroundColor =
        isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
                  Icon(
                    leadIcon,
                    color: isMcp ? cs.primary : iconColor,
                    size: 22,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: ConstrainedText(
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
                              Text(
                                AppLocalizations.of(context)!
                                    .providerBuiltinBadge,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                            if (integrationType.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                integrationType,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        ConstrainedText(
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
                            AppLocalizations.of(context)!
                                .providerApiKeyHint(apiKeyHint!),
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                              fontStyle: FontStyle.italic,
                            ),
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
                      tooltip: settingsTooltip ??
                          AppLocalizations.of(context)!.appSettings,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  if (onTest != null)
                    IconButton(
                      icon: const Icon(Icons.network_check, size: 20),
                      onPressed: onTest,
                      tooltip: AppLocalizations.of(context)!
                          .providerConnectivityTest,
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
                      tooltip: AppLocalizations.of(context)!
                          .providerMoveGroupTooltip,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                  if (onDelete != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: cs.error,
                      ),
                      onPressed: onDelete,
                      tooltip:
                          AppLocalizations.of(context)!.providerDeleteTooltip,
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
        borderRadius: BorderRadius.circular(16),
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
                        child: ConstrainedText(
                          mcpGroupDisplayName(
                            group,
                            AppLocalizations.of(context)!,
                          ),
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
                          AppLocalizations.of(context)!.providerBuiltinBadge,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(context)!
                        .providerGroupItemCount(itemCount),
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (onEdit != null || onDelete != null)
              PopupMenuButton<String>(
                tooltip: AppLocalizations.of(context)!.providerGroupActions,
                onSelected: (action) {
                  if (action == 'edit') {
                    onEdit?.call();
                  } else {
                    onDelete?.call();
                  }
                },
                itemBuilder: (context) => [
                  if (onEdit != null)
                    PopupMenuItem(
                      value: 'edit',
                      child: ConstrainedText(
                        AppLocalizations.of(context)!.providerEditGroupAction,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (onEdit != null && onDelete != null)
                    const PopupMenuDivider(),
                  if (onDelete != null)
                    PopupMenuItem(
                      value: 'delete',
                      child: ConstrainedText(
                        AppLocalizations.of(context)!.providerDeleteGroupAction,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            IconButton(
              onPressed: onAdd,
              tooltip: AppLocalizations.of(context)!.providerAddItem,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      // 裁剪到圆角：SwitchListTile 的 ink 涟漪是矩形，不裁剪会画出方角。
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => onChanged(!enabled),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.power_settings_new,
                    color: cs.onSurfaceVariant,
                    size: 22,
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
                                AppLocalizations.of(context)!
                                    .providerMcpMasterLabel,
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
                          AppLocalizations.of(context)!
                              .providerMcpMasterDescription,
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
    return Text(
      enabled
          ? AppLocalizations.of(context)!.providerEnabled
          : AppLocalizations.of(context)!.providerDisabled,
      style: Theme.of(context)
          .textTheme
          .labelSmall
          ?.copyWith(color: cs.onSurfaceVariant),
    );
  }
}
