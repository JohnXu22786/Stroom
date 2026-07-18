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
      );
      await ref
          .read(providerEntriesProvider.notifier)
          .update(entry.id, updated);
      if (!mounted) return;
      setState(() {});
    }
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
                            child: const Icon(Icons.drag_handle,
                                color: Colors.grey),
                          )
                        : const SizedBox(width: 32),
                    onSettings: () => _openSettingsPanel(i),
                    onDelete: isVendor ? null : () => _deleteConfig(i),
                    onTap: () => _editConfig(i),
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

// ====================================================================
// _McpConfigCard — MCP / provider entry card.
//
// 卡片样式与 LLM 供应商页 (`provider_config_detail_page.dart` 中
// 的"参照选择对话页面的顶部card样式") 保持一致：
// - 使用 Container + BoxDecoration，统一圆角 (12) 与 0.5 边框；
// - 背景使用 primaryContainer.withValues(alpha: 0.3)（内置 MCP）
//   或 surfaceContainerHigh/Low（用户添加的 MCP），使深浅色模式下都清晰可辨。
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
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 内置：使用 primaryContainer 突出；用户添加：根据主题选择中性背景
    final Color backgroundColor = isVendor
        ? cs.primaryContainer.withValues(alpha: 0.3)
        : (isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow);
    final Color borderColor = isVendor
        ? cs.primaryContainer
        : cs.outlineVariant.withValues(alpha: 0.5);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: isVendor ? 1.0 : 0.5,
        ),
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
                    color: isVendor
                        ? cs.primaryContainer.withValues(alpha: 0.5)
                        : cs.primaryContainer.withValues(alpha: 0.3),
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
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    cs.primary.withValues(alpha: 0.15),
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
                if (onDelete != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 20, color: cs.error),
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
