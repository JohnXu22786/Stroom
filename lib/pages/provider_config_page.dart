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
      await showMcpServerConfigDialog(
        context: context,
        entryId: widget.entryId,
        configIndex: -1,
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
      'Todo 默认读取清单，非空 todos 参数会被拒绝以保护当前数据。';

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

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('配置')),
        body: const Center(child: Text('供应商未找到')),
      );
    }
    final isMcp = entry.type == 'mcp';
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(entry.name), centerTitle: true),
      body: CustomScrollView(
        slivers: [
          if (isMcp) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _McpPageIntro(colorScheme: cs),
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
                      description: '远程连接、本地 stdio 与 HTTP 搜索',
                      count: entry.configs.length,
                      action: FilledButton.tonalIcon(
                        onPressed: _addConfig,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('添加'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    children: [
                      Text(
                        '供应商配置',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
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
                ]),
              ),
            ),
          if (entry.configs.isEmpty && isMcp)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _McpEmptyState(onAdd: _addConfig),
              ),
            )
          else if (entry.configs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    '暂无供应商配置，请点击"添加"创建',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  isMcp ? 20 : 16, isMcp ? 12 : 0, isMcp ? 20 : 16, 0),
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
                  final transport =
                      mcpTypeConfig?['transport'] as String? ?? 'sse';
                  final integrationType = entry.type == 'mcp'
                      ? isHttpTool
                          ? 'HTTP 搜索'
                          : 'MCP · ${transport == 'stdio' ? 'stdio' : 'SSE'}'
                      : '';

                  if (entry.type == 'mcp') {
                    if (isHttpTool) {
                      // HTTP 工具（纯 Dart 实现，非 MCP 协议）
                      final url = mcpTypeConfig?['url'] as String? ?? '';
                      leadIcon = Icons.http;
                      iconColor = cs.primary;
                      subtitle = 'HTTP 工具: ${url.isNotEmpty ? url : '(未设置)'}';
                    } else if (transport == 'stdio') {
                      final cmd = mcpTypeConfig?['command'] as String? ?? '';
                      leadIcon = Icons.desktop_windows;
                      iconColor = cs.primary;
                      subtitle = '本地(stdio): $cmd';
                    } else {
                      final url =
                          mcpTypeConfig?['url'] as String? ?? config.host;
                      leadIcon = Icons.cloud;
                      iconColor = cs.primary;
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
                    isMcp: isMcp,
                    isVendor: isVendor,
                    integrationType: integrationType,
                    providerName: providerName,
                    leadIcon: leadIcon,
                    iconColor: iconColor,
                    subtitle: subtitle,
                    apiKeyHint: apiKeyHint,
                    mcpDescription: mcpDescription,
                    dragHandle: !isVendor
                        ? ReorderableDragStartListener(
                            index: i,
                            child: Icon(
                              Icons.drag_handle,
                              color: isMcp ? cs.onSurfaceVariant : Colors.grey,
                            ),
                          )
                        : const SizedBox(width: 32),
                    onSettings: entry.type == 'mcp'
                        ? null
                        : () => _openSettingsPanel(i),
                    onDelete: isVendor ? null : () => _deleteConfig(i),
                    onTest: entry.type == 'mcp'
                        ? () => _testProviderConnectivity(i)
                        : null,
                    onTap: () => _editConfig(i),
                  );
                },
              ),
            ),
          if (isMcp) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _McpSectionHeader(
                  title: '内置工具',
                  description: 'Stroom 提供的搜索与通用工具',
                  count: _builtinToolDefinitions.length,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final definition = _builtinToolDefinitions[index];
                    return _McpConfigCard(
                      key: ValueKey('builtin_tool_${definition.name}'),
                      isMcp: true,
                      isVendor: false,
                      integrationType: '内置工具',
                      providerName: definition.name,
                      leadIcon: Icons.build_outlined,
                      iconColor: cs.primary,
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
                  },
                  childCount: _builtinToolDefinitions.length,
                ),
              ),
            ),
          ],
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
                          '控制远程和本地服务器工具；内置 HTTP 搜索不受影响。',
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
